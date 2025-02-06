data "aws_caller_identity" "current" {}


output "user-info" {
  value = data.aws_caller_identity.current
}

