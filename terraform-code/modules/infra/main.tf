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

# resource "aws_subnet" "this" {
#   for_each          = { for i in range(var.num_subnets) : "public${i}" => i }
#   vpc_id            = aws_vpc.this.id
#   cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, each.value)
#   availability_zone = local.azs[each.value % length(local.azs)]

#   tags = {
#     Name = "ecs-subnet-${each.key}"
#   }
# }

# Create var.num_subnets_private private subnets, each in a different AZ
resource "aws_subnet" "private" {
  count             = var.num_subnets_private
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 8, count.index)
  availability_zone = local.azs[count.index % length(local.azs)]
  vpc_id            = aws_vpc.this.id

  tags = {
    Name = "ecs-subnet-private-${count.index}"
  }

}

# Create var.num_subnets_public public subnets, each in a different AZ
resource "aws_subnet" "public" {
  count                   = var.num_subnets_public
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 8, var.num_subnets_private + count.index)
  availability_zone       = local.azs[count.index % length(local.azs)]
  vpc_id                  = aws_vpc.this.id
  map_public_ip_on_launch = true
  tags = {
    Name = "ecs-subnet-public-${count.index}"
  }
}

resource "aws_route_table_association" "this" {
  count          = var.num_subnets_public
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.this.id
}

data "aws_availability_zones" "azsonly" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
