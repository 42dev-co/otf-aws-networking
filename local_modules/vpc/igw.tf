# Creates an internet gateway if `create_internet_gateway` is set to true
resource "aws_internet_gateway" "this" {
  count = try(var.config.create, true) && try(var.config.create_internet_gateway, false) ? 1 : 0
  
  tags   = merge(var.default_tags, 
    {
      Name: format("%s-igw", var.name),
      vpc_id: aws_vpc.this[0].id, 
    },
    try(var.config.tags, {}))

  depends_on = [aws_vpc.this]
}

# Creates an egress only internet gateway if `create_egress_internet_gateway` is set to true
resource "aws_egress_only_internet_gateway" "this" {
  count = try(var.config.create, true) && try(var.config.create_egress_internet_gateway, false) ? 1 : 0
  
  vpc_id = aws_vpc.this[0].id
  tags   = merge(var.default_tags, try(var.config.tags, {}))
}

# Attaches the internet gateway to the VPC if `attached_internet_gateway_to_vpc` and `create_internet_gateway` are set to true
resource "aws_internet_gateway_attachment" "this" {
  count = try(var.config.create, true) && try(var.config.create_internet_gateway, false) && try(var.config.attached_internet_gateway_to_vpc, false) ? 1 : 0
  
  internet_gateway_id = aws_internet_gateway.this[0].id
  vpc_id              = aws_vpc.this[0].id
  depends_on = [aws_vpc.this, aws_internet_gateway.this]
}