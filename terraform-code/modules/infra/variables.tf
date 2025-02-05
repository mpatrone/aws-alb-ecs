variable "vpc_cidr" {
  type = string
}

variable "num_subnets_private" {
  type = number
}

variable "num_subnets_public" {
  type = number
}

variable "allowed_ips" {
  type = set(string)
}