### Transit Gateways
locals {
  ### Transit Gateways (Per Definition) 
  # 1. we decode the yaml files and return n  ull with the filename if yaml has an error
  # 2. we filter out tgws that have errors
  # 3. we create boolean if there are errors
  # 4. if there are no errors, we filter the tgws into a map to 
  tgws_arrays = [for f in fileset(path.module, "./resources/tgws/*.yaml"): [try(yamldecode(file(f)), null), f]]
  tgws_with_err = [ for tgw in local.tgws_arrays: tgw[1] if tgw[0] == null ]
  tgws_has_err = length(local.tgws_with_err) > 0
  tgws = local.tgws_has_err ? {} : { for k, v in merge([ for tgw in local.tgws_arrays: tgw[0]]...): k => v  if try(v.create, false) }

  # TGW Principals
  tgw_principals = merge([ for tgw, tgw_config in local.tgws: {
    for principal in try(tgw_config.principals, []): "${tgw}-${principal}" => { tgw = tgw, principal = principal }
  }]...)

  # TGW  VPC Attachments
  tgw_vpc_attachments = merge([ for tgw, tgw_config in local.tgws: {
    for attachment, attachment_config in tgw_config.vpc_attachments: 
      "${tgw}-${attachment}" => merge(attachment_config, { tgw = tgw, name = attachment }) if try(attachment_config.create, false)
  }]...)

  # TGW VPC Attachment Accepters
  tgw_vpc_attachment_accepters = merge([ for tgw, tgw_config in local.tgws: {
    for attachment, attachment_config in try(tgw_config.vpc_attachment_accepters, {}): 
      "${tgw}-${attachment}" => merge(attachment_config, { tgw = tgw, name = attachment }) if try(attachment_config.accept, false)
  }]...)

  # TGW Peering Attachments
  tgw_peering_attachments = merge([ for tgw, tgw_config in local.tgws: {
    for attachment, attachment_config in try(tgw_config.peering_attachments, {}): 
      "${tgw}-${attachment}" => merge(attachment_config, { tgw = tgw, name = attachment }) if try(attachment_config.create, false)
  }]...)

  tgw_peering_attachments_accepters = merge([ for tgw, tgw_config in local.tgws: {
    for attachment, attachment_config in try(tgw_config.peering_attachment_accepters, {}): 
      "${tgw}-${attachment}" => merge(attachment_config, { tgw = tgw, name = attachment }) if try(attachment_config.accept, false)
  }]...)
}

resource "aws_ec2_transit_gateway" "this" {
  for_each = local.tgws

  description                     = try(each.value.description, "")
  amazon_side_asn                 = try(each.value.amazon_side_asn, 64512)
  auto_accept_shared_attachments  = try(each.value.auto_accept_shared_attachments, "disable")
  default_route_table_association = try(each.value.default_route_table_association, "enable")
  default_route_table_propagation = try(each.value.default_route_table_propagation, "enable")
  dns_support                     = try(each.value.dns_support, "enable")
  multicast_support               = try(each.value.multicast_support, "disable")
  transit_gateway_cidr_blocks     = try(each.value.transit_gateway_cidr_blocks, [])
  vpn_ecmp_support                = try(each.value.vpn_ecmp_support, "enable")
  
  tags = merge(
    { Name = each.key },
    var.default_tags,
    try(each.value.tags, {})
  )
}

### TGW RAM Share 

# Resource Share (Per TGW)
resource "aws_ram_resource_share" "this" {
  for_each = { for k, v in local.tgws: k => v if length(v.principals) > 0 }
  
  name = "${each.key}-tgw_rs"

  allow_external_principals = true

  tags = merge(
    var.default_tags,
    { 
      Name = "${each.key}-tgw_rs"
      tgw = each.key
    },
    try(each.value.tags, {})
  )
  depends_on = [ aws_ec2_transit_gateway.this ]
}

# This associate the TGW to the resource share
resource "aws_ram_resource_association" "this" {
  for_each = { for k, v in local.tgws: k => v if length(v.principals) > 0 }

  resource_arn = aws_ec2_transit_gateway.this[each.key].arn
  resource_share_arn = aws_ram_resource_share.this[each.key].arn
}

# This associate the principals to the resource share
resource "aws_ram_principal_association" "this" {
  for_each =  local.tgw_principals

  resource_share_arn = aws_ram_resource_share.this[each.value.tgw].arn
  principal          = each.value.principal

  depends_on = [ aws_ram_resource_share.this ]
}



### TGW VPC Attachments

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  for_each = local.tgw_vpc_attachments

  subnet_ids                                      = [for subnet in each.value.subnet_ids: try(aws_subnet.this[subnet].id, subnet)]
  transit_gateway_id                              = aws_ec2_transit_gateway.this[each.value.tgw].id
  vpc_id                                          = try(aws_vpc.this[each.value.vpc_id].id, each.value.vpc_id)
  dns_support                                     = try(each.value.dns_support, "enable")
  ipv6_support                                    = try(each.value.ipv6_support, "enable")
  transit_gateway_default_route_table_association = try(each.value.transit_gateway_default_route_table_association, false)
  transit_gateway_default_route_table_propagation = try(each.value.transit_gateway_default_route_table_propagation, false)

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

  depends_on = [ aws_ec2_transit_gateway.this, aws_vpc.this, aws_subnet.this ]
}

### TGW VPC Attachment Accepters

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "this"{

  for_each = local.tgw_vpc_attachment_accepters

  transit_gateway_attachment_id = each.value.transit_gateway_attachment_id
  transit_gateway_default_route_table_association = try(each.value.transit_gateway_default_route_table_association, false)
  transit_gateway_default_route_table_propagation = try(each.value.transit_gateway_default_route_table_propagation, false)
  
  tags = merge(
    var.default_tags,
    { Name = each.key },
    try(each.value.tags, {})
  )

  depends_on = [aws_ec2_transit_gateway.this]
}

# TGW PEERING ATTACHMENTS
resource "aws_ec2_transit_gateway_peering_attachment" "this" {

  for_each = local.tgw_peering_attachments

  peer_region             = each.value.peer_region
  peer_transit_gateway_id = each.value.peer_transit_gateway_id
  transit_gateway_id      = aws_ec2_transit_gateway.this[each.value.tgw].id

  tags = merge(
    { Name = each.key },
    var.default_tags,
    try(each.value.tags, {})
  )

  depends_on = [ aws_ec2_transit_gateway.this ]
}

### TGW PEERING ATTACHMENT ACCEPTER

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "this" {
  for_each = local.tgw_peering_attachments_accepters

  transit_gateway_attachment_id = each.value.transit_gateway_attachment_id

  tags = merge(
    var.default_tags,
    { Name = each.key },
    try(each.value.tags, {})
  )

  depends_on = [aws_ec2_transit_gateway.this]
}