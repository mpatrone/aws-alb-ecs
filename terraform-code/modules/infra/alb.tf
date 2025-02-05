resource "aws_lb" "this" {
  name               = "ecs-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  tags = {
    Name        = "ecs-alb"
    Environment = "prod"
  }
}

resource "aws_lb_target_group" "this" {
  name        = "ecs-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"


  #  default_action {
  #     type = "fixed-response"
  #     fixed_response {
  #       content_type = "text/html"
  #       message_body = "<body><h1>Hello Terraform!</h1><h2>The Application Load Balancer is working but the ECS tasks are not</h2></bosy>"
  #       status_code  = 200
  #     }
  #  }

  default_action {
    target_group_arn = aws_lb_target_group.this.arn
    type             = "forward"
  }
}