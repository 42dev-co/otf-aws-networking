### Internet Gateway

# Creates an internet gateway if `create_internet_gateway` is set to true
resource "aws_internet_gateway" "this" {
  for_each = local.vpcs
  
  tags   = merge(var.default_tags, 
    {
      Name: format("%s-igw", each.key),
      vpc_id: aws_vpc.this[each.key].id, 
    },
    try(each.value.tags, {}))

  depends_on = [aws_vpc.this]
}

# Creates an egress only internet gateway if `create_egress_internet_gateway` is set to true
resource "aws_egress_only_internet_gateway" "this" {
  for_each = { for k , v in local.vpcs: k => v if try(v.create_egress_internet_gateway, false) }
  
  vpc_id = aws_vpc.this[each.key].id
  tags   = merge(
    var.default_tags, 
    try(each.value.tags, {})
  )
}

# Attaches the internet gateway to the VPC if `attached_internet_gateway_to_vpc` and `create_internet_gateway` are set to true
resource "aws_internet_gateway_attachment" "this" {
  for_each = { for k , v in local.vpcs: k => v if try(v.create_internet_gateway, false) && try(v.attached_internet_gateway_to_vpc, false) }

  internet_gateway_id = aws_internet_gateway.this[each.key].id
  vpc_id              = aws_vpc.this[each.key].id

  depends_on = [aws_vpc.this, aws_internet_gateway.this]
}

