locals {
  ecr_url   = aws_ecr_repository.this.repository_url
  ecr_token = data.aws_ecr_authorization_token.this
}

data "aws_ecr_authorization_token" "this" {}

resource "aws_ecr_repository" "this" {
  name         = var.ecr_repository_name
  force_delete = true
}

resource "terraform_data" "login" {
  provisioner "local-exec" {
    command = <<EOT
    docker login ${local.ecr_url} \
    --username ${local.ecr_token.user_name} \
    --password ${local.ecr_token.password}
    EOT
  }
}

resource "terraform_data" "build" {
  depends_on = [terraform_data.login]
  provisioner "local-exec" {
    command = <<EOT
    docker build -t ${local.ecr_url} ${path.module}/apps/${var.app_path}
    EOT
  }
}

resource "terraform_data" "push" {
  triggers_replace = [var.image_version]

  depends_on = [terraform_data.login, terraform_data.build]
  provisioner "local-exec" {
    command = <<EOT
    docker tag ${local.ecr_url} ${local.ecr_url}:${var.image_version}
    docker tag ${local.ecr_url} ${local.ecr_url}:latest
    docker push ${local.ecr_url}:${var.image_version}
    docker push ${local.ecr_url}:latest
    EOT
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.app_name}-td"
  cpu                      = 1024
  memory                   = 2048
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = var.execution_role_arn
  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = "${local.ecr_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = var.port
          hostPort      = var.port
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "this" {
  name            = "${var.app_name}-service"
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = 1

  network_configuration {
    security_groups  = [var.app_security_group_id]
    subnets          = var.subnets
    assign_public_ip = var.is_public
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.id
    container_name   = var.app_name
    container_port   = var.port
  }
}

resource "aws_lb_target_group" "this" {
  name        = "ecs-tg"
  port        = var.port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    healthy_threshold   = "3"
    interval            = "5"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = var.alb_arn
  port              = var.port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.this.arn
    type             = "forward"
  }
}

resource "aws_alb_listener_rule" "http_rule" {
  listener_arn = aws_lb_listener.this.arn
  condition {
    path_pattern {
      values = [var.path_pattern]
    }
  }
  action {
    target_group_arn = aws_lb_target_group.this.arn
    type             = "forward"
  }
}



