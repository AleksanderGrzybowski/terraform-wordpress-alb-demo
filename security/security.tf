variable "vpc_id" { type = string }

resource "aws_security_group" "ec2_security_group" {
  name   = "ec2_security_group"
  vpc_id = var.vpc_id

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

resource "aws_security_group" "db_security_group" {
  name   = "db_security_group"
  vpc_id = var.vpc_id

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

resource "aws_security_group" "alb_security_group" {
  name   = "alb_security_group"
  vpc_id = var.vpc_id

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

output "ec2_security_group_id" {
  value = aws_security_group.ec2_security_group.id
}

output "db_security_group_id" {
  value = aws_security_group.db_security_group.id
}
output "alb_security_group_id" {
  value = aws_security_group.alb_security_group.id
}
