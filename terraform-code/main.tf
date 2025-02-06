# Root main.tf
module "infra" {
  source      = "./modules/infra"
  vpc_cidr    = "10.0.0.0/16"
  num_subnets = 2
  allowed_ips = ["0.0.0.0/0", "78.137.209.174/32"]
}

module "app" {
  source                = "./modules/app"
  ecr_repository_name   = "ui"
  app_path              = "ui"
  image_version         = "1.0.0"
  app_name              = "ui"
  port                  = 80
  execution_role_arn    = module.infra.execution_role_arn
  app_security_group_id = module.infra.app_security_group_id
  vpc_id                = module.infra.vpc_id
  subnets               = module.infra.public_subnets
  alb_arn               = module.infra.alb_arn
  cluster_arn           = module.infra.cluster_arn
  is_public             = true
  path_pattern          = "/*"
}