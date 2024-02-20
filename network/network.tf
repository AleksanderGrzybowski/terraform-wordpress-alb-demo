variable "vpc_cidr" { type = string }
variable "subnet_cidrs" { type = map(string) }
variable "region" { type = string }

resource "aws_vpc" "demo_vpc" {
  cidr_block = var.vpc_cidr

  tags = { Name = "demo_vpc" }
}

resource "aws_internet_gateway" "demo_igw" {
  vpc_id = aws_vpc.demo_vpc.id

  tags = { Name = "demo_igw" }
}

resource "aws_subnet" "demo_subnet" {
  for_each = var.subnet_cidrs

  vpc_id            = aws_vpc.demo_vpc.id
  cidr_block        = each.value
  availability_zone = "${var.region}${each.key}"

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
  for_each = var.subnet_cidrs

  route_table_id = aws_route_table.demo_route_table.id
  subnet_id      = aws_subnet.demo_subnet[each.key].id
}

output "vpc_id" {
  value = aws_vpc.demo_vpc.id
}

output "subnet_ids" {
  value = [for k, v in aws_subnet.demo_subnet : v.id]
}