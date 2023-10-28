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
  region = "eu-central-1"
}


// VPC and subnets


resource "aws_vpc" "demo_vpc" {
  cidr_block = local.vpc_cidr

  tags = { Name = "demo_vpc" }
}

resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = { Name = "demo_igw" }
}

resource "aws_subnet" "demo_subnet" {
  for_each = local.subnet_cidrs

  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = each.value
  availability_zone = "${local.region}${each.key}"

  tags = { Name = "demo_subnet_${each.key}" }
}

resource "aws_route_table" "demo_route_table" {
  vpc_id = aws_vpc.demo_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.demo_igw.id
  }

  tags = { Name = "demo_route_table" }
}

resource "aws_route_table_association" "demo_route_table_association" {
  for_each = local.subnet_cidrs

  route_table_id = aws_route_table.demo_route_table.id
  subnet_id      = aws_subnet.demo_subnet[each.key].id
}


// Database


resource "aws_security_group" "db_security_group" {
  name   = "db_security_group"
  vpc_id = aws_vpc.demo_vpc.id

  ingress {
    from_port       = 3306
    protocol        = "TCP"
    to_port         = 3306
    security_groups = [aws_security_group.ec2_security_group.id]
  }

  egress {
    from_port   = 0
    protocol    = "ALL"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "wordpress_db_subnet_group" {
  subnet_ids = [for k, v in aws_subnet.demo_subnet : v.id]
}

resource "aws_db_instance" "demo_db" {
  identifier             = "wordpress"
  db_subnet_group_name   = aws_db_subnet_group.wordpress_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_security_group.id]

  allocated_storage    = 10
  db_name              = "wordpress"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  username             = local.database_username
  password             = local.database_password
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
}


// Default SSH key


resource "random_pet" "demo_key_identifier" {
  count = (local.key_name == null) ? 1 : 0
}

resource "tls_private_key" "demo_key" {
  count = (local.key_name == null) ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "demo_key" {
  count = (local.key_name == null) ? 1 : 0

  key_name   = "terraform-demo-key-${random_pet.demo_key_identifier[0].id}"
  public_key = tls_private_key.demo_key[0].public_key_openssh
}


// EC2 instance


resource "aws_security_group" "ec2_security_group" {
  name   = "ec2_security_group"
  vpc_id = aws_vpc.demo_vpc.id

  ingress {
    from_port   = 22
    protocol    = "TCP"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 0
    protocol        = "ALL"
    to_port         = 0
    security_groups = [aws_security_group.alb_security_group.id]
  }

  egress {
    from_port   = 0
    protocol    = "ALL"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "wordpress_instance" {
  ami                         = local.ami
  instance_type               = local.instance_type
  key_name                    = local.key_name == null ? aws_key_pair.demo_key[0].key_name : local.key_name
  subnet_id                   = aws_subnet.demo_subnet[keys(local.subnet_cidrs)[0]].id
  vpc_security_group_ids      = [aws_security_group.ec2_security_group.id]
  associate_public_ip_address = true # for ssh

  user_data = templatefile("setup.sh.tpl", {
    database_host     = aws_db_instance.demo_db.endpoint
    database_name     = local.database_name
    database_username = local.database_username
    database_password = local.database_password
  })

  tags = {
    Name = "wordpress_instance"
  }
}


// Load balancer


resource "aws_security_group" "alb_security_group" {
  name   = "alb_security_group"
  vpc_id = aws_vpc.demo_vpc.id

  ingress {
    from_port   = 80
    protocol    = "TCP"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "ALL"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_alb_target_group" "demo_tg" {
  name        = "demotg"
  vpc_id      = aws_vpc.demo_vpc.id
  target_type = "instance"
  protocol    = "HTTP"
  port        = 80
}

resource "aws_alb_target_group_attachment" "demo_tg_attachment" {
  target_group_arn = aws_alb_target_group.demo_tg.arn
  target_id        = aws_instance.wordpress_instance.id
}

resource "aws_alb" "demo_alb" {
  name               = "demoalb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_security_group.id]
  subnets            = [for k, v in aws_subnet.demo_subnet : v.id]
}

resource "aws_alb_listener" "demo_alb_listener" {
  load_balancer_arn = aws_alb.demo_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.demo_tg.arn
    forward {
      target_group { arn = aws_alb_target_group.demo_tg.arn }
    }
  }
}

output "alb_public_dns" {
  value = aws_alb.demo_alb.dns_name
}
