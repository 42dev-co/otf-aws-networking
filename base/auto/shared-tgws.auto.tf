# For TGW that are shared from another account
locals {
  shared_tgws_arr = [for f in fileset(path.module, "./resources/shared-tgws/*.yaml"): [try(yamldecode(file(f)), null), f]]
  shared_tgws_with_err = [ for tgw in local.shared_tgws_arr: tgw[1] if tgw[0] == null ]
  shared_tgws_has_err = length(local.shared_tgws_with_err) > 0
  shared_tgws = local.shared_tgws_has_err ? {} : { for k, v in merge([ for tgw in local.shared_tgws_arr: tgw[0]]...): k => v  if try(v.accept, false) }

  shared_tgw_vpc_attachments = merge([ for tgw, tgw_config in local.shared_tgws: {
    for attachment, attachment_config in tgw_config.vpc_attachments: 
      "${tgw}-${attachment}" => merge(attachment_config, { tgw = tgw, name = attachment }) if try(attachment_config.create, false)
  }]...)
}


resource "aws_ram_resource_share_accepter" "this" {
  for_each = local.shared_tgws
  share_arn = each.value.share_arn
}

data "aws_ec2_transit_gateway" "shared_tgw" {
  for_each = local.shared_tgws
  id = each.value.tgw_id
  depends_on = [ aws_ram_resource_share_accepter.this ]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "shared_tgw" {
  for_each = local.shared_tgw_vpc_attachments

  subnet_ids                                      = [for subnet in each.value.subnet_ids: try(aws_subnet.this[subnet].id, subnet)]
  transit_gateway_id                              = data.aws_ec2_transit_gateway.shared_tgw[each.value.tgw].id
  vpc_id                                          = try(aws_vpc.this[each.value.vpc_id].id, each.value.vpc_id)
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

  depends_on = [ 
                 aws_ram_resource_share_accepter.this, 
                 data.aws_ec2_transit_gateway.shared_tgw, 
                 aws_vpc.this, 
                 aws_subnet.this 
              ]
}