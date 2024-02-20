locals {
  region = "eu-central-1"

  vpc_cidr     = "192.168.69.0/24"
  subnet_cidrs = {
    a = "192.168.69.0/25"
    b = "192.168.69.128/25"
  }

  instance_type = "t3a.nano"
  ami           = "ami-0d1ddd83282187d18"
  key_name      = "id_rsa"

  database_name     = "wordpress"
  database_username = "wordpress"
  database_password = "wordpress"
}

provider "aws" {
  region = local.region
}

module "network" {
  source       = "./network"
  vpc_cidr     = local.vpc_cidr
  subnet_cidrs = local.subnet_cidrs
  region       = local.region
}

module "security" {
  source = "./security"
  vpc_id = module.network.vpc_id
}

module "database" {
  source               = "./database"
  vpc_id               = module.network.vpc_id
  db_security_group_id = module.security.db_security_group_id
  subnet_ids           = module.network.subnet_ids
  database_name        = local.database_name
  database_username    = local.database_username
  database_password    = local.database_password
}

module "ssh" {
  source   = "./ssh"
  count    = (local.key_name == null) ? 1 : 0
  key_name = local.key_name
}

resource "aws_instance" "wordpress_instance" {
  ami                         = local.ami
  instance_type               = local.instance_type
  key_name                    = local.key_name == null ? module.ssh[0].key_name : local.key_name
  subnet_id                   = module.network.subnet_ids[0]
  vpc_security_group_ids      = [module.security.ec2_security_group_id]
  associate_public_ip_address = true # for ssh

  user_data = templatefile("setup.sh.tpl", {
    database_host     = module.database.endpoint
    database_name     = local.database_name
    database_username = local.database_username
    database_password = local.database_password
  })

  tags = { Name = "wordpress_instance" }
}

module "loadbalancer" {
  source                = "./loadbalancer"
  vpc_id                = module.network.vpc_id
  ec2_instance_id       = aws_instance.wordpress_instance.id
  alb_security_group_id = module.security.alb_security_group_id
  subnet_ids            = module.network.subnet_ids
}

output "alb_public_dns" {
  value = module.loadbalancer.public_dns_endpoint
}
