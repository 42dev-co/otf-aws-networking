resource "aws_ec2_transit_gateway" "this" {
  count = try(var.config.create, true) ? 1 : 0

  description                     = try(var.config.description, "")
  amazon_side_asn                 = try(var.config.amazon_side_asn, 64512)
  auto_accept_shared_attachments  = try(var.config.auto_accept_shared_attachments, "disable")
  default_route_table_association = try(var.config.default_route_table_association, "enable")
  default_route_table_propagation = try(var.config.default_route_table_propagation, "enable")
  dns_support                     = try(var.config.dns_support, "enable")
  multicast_support               = try(var.config.multicast_support, "disable")
  transit_gateway_cidr_blocks     = try(var.config.transit_gateway_cidr_blocks, [])
  vpn_ecmp_support                = try(var.config.vpn_ecmp_support, "enable")
  
  tags = merge(
    { Name = var.name },
    var.default_tags,
    try(var.config.tags, {})
  )
}

### Resource Share
resource "aws_ram_resource_share" "tgw" {
  count = try(var.config.create, true) && try(length(var.config.principals) > 0, false) ? 1 : 0
  
  name = "${var.name}-resource-share"

  allow_external_principals = true

  tags = merge(
    { 
      Name = "${var.name}-resource-share"
      tgw = var.name 
    },
    var.default_tags,
    try(var.config.tags, {})
  )

  depends_on = [ aws_ec2_transit_gateway.this ]
}

resource "aws_ram_principal_association" "this" {
  for_each =  try(var.config.create, true) && try(length(var.config.principals) > 0, false) ? try(toset(var.config.principals),[]) : []

  resource_share_arn = aws_ram_resource_share.tgw[0].arn
  principal          = each.key

  depends_on = [ aws_ram_resource_share.tgw ]
}

resource "aws_ram_resource_association" "this" {
  count =  try(var.config.create, true) && try(length(var.config.principals) > 0, false) ? 1 : 0
  resource_arn = aws_ec2_transit_gateway.this[0].arn
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

# Attach this tgw to the subnets in the VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = try(var.config.create, true) ? try({for k, v in var.config.vpc_attachments: k => v if try(v.create, false) },{}) : {}

  subnet_ids                                      = each.value.subnet_ids
  transit_gateway_id                              = aws_ec2_transit_gateway.this[0].id
  vpc_id                                          = each.value.vpc_id
  dns_support                                     = try(each.value.dns_support, "enable")
  ipv6_support                                    = try(each.value.ipv6_support, "enable")
  transit_gateway_default_route_table_association = try(each.value.transit_gateway_default_route_table_association, true)
  transit_gateway_default_route_table_propagation = try(each.value.transit_gateway_default_route_table_propagation, true)

  tags = merge(
    { Name = each.key },
    var.default_tags,
    try(each.value.tags, {})
  )

  lifecycle {
    ignore_changes = [ 
      transit_gateway_default_route_table_association,
      transit_gateway_default_route_table_propagation
    ]
  }

  depends_on = [ aws_ec2_transit_gateway.this ]
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "this"{

  for_each = try(var.config.create, true) ?try({for k, v in var.config.vpc_attachment_accepters: k => v if try(v.create, false) },{}) : {}

  transit_gateway_attachment_id = each.value.transit_gateway_attachment_id
  transit_gateway_default_route_table_association = try(each.value.transit_gateway_default_route_table_association, true)
  transit_gateway_default_route_table_propagation = try(each.value.transit_gateway_default_route_table_propagation, true)
  
  tags = merge(
    { Name = each.key },
    var.default_tags,
    try(each.value.tags, {})
  )

  depends_on = [aws_ec2_transit_gateway.this]
}

# For tgw peering
resource "aws_ec2_transit_gateway_peering_attachment" "this" {

  for_each = try(var.config.create, true) ?try({for k, v in var.config.peering_attachments: k => v if try(v.create, false) },{}) : {}

  peer_account_id         = each.value.peer_account_id
  peer_region             = each.value.peer_region
  peer_transit_gateway_id = each.value.peer_transit_gateway_id
  transit_gateway_id      = aws_ec2_transit_gateway.this[0].id

  tags = merge(
    { Name = each.key },
    var.default_tags,
    try(each.value.tags, {})
  )

  depends_on = [ aws_ec2_transit_gateway.this ]
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "this" {
  for_each = try(var.config.create, true) ?try({for k, v in var.config.peering_attachment_accepters: k => v if try(v.create, false) },{}) : {}

  transit_gateway_attachment_id = each.value.transit_gateway_attachment_id

  tags = merge(
    { Name = each.key },
    var.default_tags,
    try(each.value.tags, {})
  )

  depends_on = [aws_ec2_transit_gateway.this]
}