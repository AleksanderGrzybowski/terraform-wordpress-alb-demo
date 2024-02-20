variable "vpc_id" { type = string }
variable "ec2_instance_id" { type = string }
variable "alb_security_group_id" { type = string }
variable "subnet_ids" { type = list(string) }

resource "aws_alb_target_group" "demo_tg" {
  name        = "demotg"
  vpc_id      = var.vpc_id
  target_type = "instance"
  protocol    = "HTTP"
  port        = 80
}

resource "aws_alb_target_group_attachment" "demo_tg_attachment" {
  target_group_arn = aws_alb_target_group.demo_tg.arn
  target_id        = var.ec2_instance_id
}

resource "aws_alb" "demo_alb" {
  name               = "demoalb"
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.subnet_ids
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

output "public_dns_endpoint" {
  value = aws_alb.demo_alb.dns_name
}
