# Root main.tf



module "infra" {
  source              = "./modules/infra"
  vpc_cidr            = "10.0.0.0/16"
  num_subnets_public  = 2
  num_subnets_private = 2
  allowed_ips         = ["0.0.0.0/0", "78.137.209.174/32"]
}

