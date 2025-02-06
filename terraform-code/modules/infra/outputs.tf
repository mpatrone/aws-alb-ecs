output "execution_role_arn" {
  value = aws_iam_role.ecs-execution-role.arn
}

output "public_subnets" {
  value = [for i in aws_subnet.this : i.id]
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn

}

output "app_security_group_id" {
  value = aws_security_group.app.id
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "alb_arn" {
  value = aws_lb.this.arn
}