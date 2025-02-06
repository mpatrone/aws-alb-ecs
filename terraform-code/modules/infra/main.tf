locals {
  azs = data.aws_availability_zones.azsonly.names
}


resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "ecs-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  tags = {
    Name = "ecs-igw"
  }
}

resource "aws_internet_gateway_attachment" "this" {
  internet_gateway_id = aws_internet_gateway.this.id
  vpc_id              = aws_vpc.this.id
}

resource "aws_subnet" "this" {
  for_each          = { for i in range(var.num_subnets) : "public${i}" => i }
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, each.value)
  availability_zone = local.azs[each.value % length(local.azs)]

  tags = {
    Name = "ecs-subnet-${each.key}"
  }
}

# Create var.num_subnets_private private subnets, each in a different AZ
# resource "aws_subnet" "private" {
#   count             = var.num_subnets_private
#   cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
#   availability_zone = local.azs[count.index % length(local.azs)]
#   vpc_id            = aws_vpc.this.id

#   tags = {
#     Name = "ecs-subnet-private-${count.index}"
#   }

# }

# # Create var.num_subnets_public public subnets, each in a different AZ
# resource "aws_subnet" "public" {
#   count                   = var.num_subnets_public
#   cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, var.num_subnets_private + count.index)
#   availability_zone       = local.azs[count.index % length(local.azs)]
#   vpc_id                  = aws_vpc.this.id
#   map_public_ip_on_launch = true
#   tags = {
#     Name = "ecs-subnet-public-${count.index}"
#   }
# }

resource "aws_route_table" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "ecs-rt"
  }
}

resource "aws_route" "this" {
  route_table_id         = aws_route_table.this.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "this" {
  for_each       = aws_subnet.this
  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this.id
}

data "aws_availability_zones" "azsonly" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "aws_iam_role" "ecs-execution-role" {
  name               = "ecsExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs-instance-policy.json
}

data "aws_iam_policy_document" "ecs-instance-policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs-instance-role-attachment" {
  role       = aws_iam_role.ecs-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_lb" "this" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for i in aws_subnet.this : i.id]

  tags = {
    Name = "ecs-alb"
  }
}

resource "aws_ecs_cluster" "this" {
  name = "ecs-tf"
  tags = {
    Name = "mp-ecs-tf"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

