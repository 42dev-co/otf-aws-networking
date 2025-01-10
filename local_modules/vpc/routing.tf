resource "aws_route_table" "this" {
  for_each = try(var.config.create, true) ? try(var.config.route_tables, {}) : {}

  vpc_id = aws_vpc.this[0].id 

  tags =  merge(
    var.default_tags,
    { Name = format("%s_route-table-%s", var.name, each.key) },
    { region = var.config.region },
    try(each.value.tags, {})
  )

  depends_on = [ aws_subnet.this ]
}

resource "aws_route_table_association" "this" {
  for_each = try(var.config.create, true) ? merge(
    flatten([ for rt_key, rt_attr in try(var.config.route_tables,{}): 
      [ for subnet in rt_attr.subnets: { "${rt_key}_${subnet}" = { subnet = subnet,   rt_key = rt_key } }  ] 
    ])...
  ) : {}

  subnet_id    = aws_subnet.this[each.value.subnet].id
  route_table_id = aws_route_table.this[each.value.rt_key].id

  depends_on = [  aws_subnet.this, aws_route_table.this ]
}

resource "aws_route" "route" {
  for_each =   try(var.config.create, true) ? merge(flatten(
              [ for rt_key, rt_attr in try(var.config.route_tables,{}):
                [ for route_name, route in try(rt_attr.routes, {}):  
                  {  "${rt_key}_${route_name}" = merge( {rt_key = rt_key} , route) } 
                ]
              ])...) : {}

  route_table_id                = aws_route_table.this[each.value.rt_key].id
  destination_cidr_block        = try(each.value.destination_cidr_block, null)
  destination_ipv6_cidr_block   = try(each.value.destination_ipv6_cidr_block, null)
  destination_prefix_list_id    = try(each.value.destination_prefix_list_id, null)
  carrier_gateway_id            = try(each.value.carrier_gateway_id , null)
  egress_only_gateway_id        = try(each.value.egress_only_gateway_id, null)
  gateway_id                    = try(
                                    each.value.gateway_id == "default"? aws_internet_gateway.this[0].id : each.value.gateway_id, 
                                    null
                                  )
  nat_gateway_id                = try(try(aws_nat_gateway.this[each.value.nat_gateway_id].id, each.value.nat_gateway_id), null)
  local_gateway_id              = try(each.value.local_gateway_id , null)
  network_interface_id          = try(each.value.network_interface_id, null)
  transit_gateway_id            = try(var.tgws[each.value.transit_gateway_id].id, try(each.value.transit_gateway_id, null))
  vpc_endpoint_id               = try(each.value.vpc_endpoint_id, null)
  vpc_peering_connection_id     = try(try(local.peering_connections[each.value.vpc_peering_connection_id], each.value.vpc_peering_connection_id), null)

  depends_on = [ aws_route_table.this, aws_internet_gateway.this, aws_nat_gateway.this ]
}



