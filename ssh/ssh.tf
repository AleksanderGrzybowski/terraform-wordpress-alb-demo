variable "key_name" { type = string }

resource "random_pet" "demo_key_identifier" {}

resource "tls_private_key" "demo_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "demo_key" {
  key_name   = "terraform-demo-key-${random_pet.demo_key_identifier.id}"
  public_key = tls_private_key.demo_key.public_key_openssh
}

output "key_name" {
  value = aws_key_pair.demo_key.key_name
}