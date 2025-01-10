locals {
  tgw_route_tables_arr = [ for f in fileset(path.module, "./resources/tgw-rtbs/**/*.yaml") : [try(yamldecode(file(f)), null), f] ]
  tgw_route_tables_with_err = [ for tgw in local.tgw_route_tables_arr: tgw[1] if tgw[0] == null ]
  tgw_route_tables_has_err = length(local.tgw_route_tables_with_err) > 0
  tgw_route_tables = local.tgw_route_tables_has_err ? {} : { for k, v in merge([ for tgw in local.tgw_route_tables_arr: tgw[0]]...): k => v  if try(v.create, true) }

  tgw_route_tables_assocs = merge(flatten([ 
                              for rtb, rtb_config in local.tgw_route_tables: 
                                 [ for attachment in concat([ for vpc_attachment in try(rtb_config.vpc_attachments, []): try(aws_ec2_transit_gateway_vpc_attachment.this[vpc_attachment].id, null) ],
                                    [ for peering_attachment in try(rtb_config.peering_attachments, []): try(aws_ec2_transit_gateway_peering_attachment.this[peering_attachment].id, null) ]): { 
                                      "${rtb}-${attachment}" = { transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[rtb].id,  transit_gateway_attachment_id = attachment } 
                                    } if attachment != null ]
                            ])...)

  tgw_route_tables_routes = merge([ for rtb, rtb_config in local.tgw_route_tables:
    {  
      for route, route_config in try(rtb_config.routes, {}): 
      "${rtb}-${route}" => merge(route_config, { transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.this[rtb].id, name = route })
    }
  ]...)
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  for_each = local.tgw_route_tables

  transit_gateway_id = try(aws_ec2_transit_gateway.this[each.value.transit_gateway_id].id, each.value.transit_gateway_id)

  tags = merge(
    var.default_tags,
    { Name = each.key },
    try(each.value.tags, {})
  )
  depends_on = [ aws_ec2_transit_gateway.this ]
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  for_each = local.tgw_route_tables_assocs

  transit_gateway_attachment_id  = each.value.transit_gateway_attachment_id
  transit_gateway_route_table_id = each.value.transit_gateway_route_table_id

  depends_on = [ 
    aws_ec2_transit_gateway.this, 
    aws_ec2_transit_gateway_route_table.this, 
    aws_ec2_transit_gateway_vpc_attachment.this, 
    aws_ec2_transit_gateway_peering_attachment.this 
  ]
}

resource "aws_ec2_transit_gateway_route" "example" {
  for_each = local.tgw_route_tables_routes

  destination_cidr_block         = each.value.destination_cidr_block
  transit_gateway_attachment_id  = try(each.value.transit_gateway_attachment_id, null)
  blackhole                      = try(each.value.blackhole, false) 
  transit_gateway_route_table_id = each.value.transit_gateway_route_table_id
}