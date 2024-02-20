variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "db_security_group_id" { type = string }
variable "database_name" { type = string }
variable "database_username" { type = string }
variable "database_password" { type = string }

resource "aws_db_subnet_group" "wordpress_db_subnet_group" {
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "demo_db" {
  identifier             = "wordpress"
  db_subnet_group_name   = aws_db_subnet_group.wordpress_db_subnet_group.name
  vpc_security_group_ids = [var.db_security_group_id]
  allocated_storage      = 10
  db_name                = var.database_name
  engine                 = "mysql"
  engine_version         = "5.7"
  parameter_group_name   = "default.mysql5.7"
  instance_class         = "db.t3.micro"
  username               = var.database_username
  password               = var.database_password
  skip_final_snapshot    = true
}

output "endpoint" {
  value = aws_db_instance.demo_db.endpoint
}
