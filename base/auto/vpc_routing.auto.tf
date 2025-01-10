### Route Tables
locals {
  # Route Tables (Per VPCs)
  vpc_route_tables = merge([ for vpc, vpc_config in local.vpcs: {
    for rt, rt_config in vpc_config.route_tables: 
      "${vpc}-${rt}" => merge(rt_config, { vpc = vpc, name = rt })
  }]...)

  # Route Table Associations (Per VPCs)
  vpc_route_tables_associations = merge([ for table, table_config in local.vpc_route_tables: {
    for subnet in table_config.subnets: 
      "${table}-${subnet}" => { subnet = "${table_config.vpc}-${subnet}", rt_key = table }
  }]...)

  # VPC routes 
  vpc_routes = merge(flatten([ for vpc, vpc_config in local.vpcs: [
    for route_table, route_table_config in try(vpc_config.route_tables, {}): [
      for route, route_config in try(route_table_config.routes, {}): {
        "${vpc}-${route_table}-${route}" = merge(route_config, { vpc = vpc, route_table = route_table, name = route })
      }
    ]
  ]])...)
}

# Route Table 
resource "aws_route_table" "this" {
  for_each = local.vpc_route_tables

  vpc_id = aws_vpc.this[each.value.vpc].id 

  tags =  merge(
    var.default_tags,
    { Name = format("%s_route-table", each.key) },
    { region = local.vpcs[each.value.vpc].region },
    try(each.value.tags, {})
  )

  depends_on = [ aws_subnet.this ]
}

# Route Table Association to Subnets
resource "aws_route_table_association" "this" {
  for_each = local.vpc_route_tables_associations

  subnet_id      = aws_subnet.this[each.value.subnet].id
  route_table_id = aws_route_table.this[each.value.rt_key].id

  depends_on = [  aws_subnet.this, aws_route_table.this ]
}



# VPC Routes 

resource "aws_route" "route" {
  for_each =  local.vpc_routes

  route_table_id                = aws_route_table.this["${each.value.vpc}-${each.value.route_table}"].id
  destination_cidr_block        = try(each.value.destination_cidr_block, null)
  destination_ipv6_cidr_block   = try(each.value.destination_ipv6_cidr_block, null)
  destination_prefix_list_id    = try(each.value.destination_prefix_list_id, null)
  carrier_gateway_id            = try(each.value.carrier_gateway_id , null)
  egress_only_gateway_id        = try(each.value.egress_only_gateway_id, null)
  gateway_id                    = try(
                                    each.value.gateway_id == "default"? aws_internet_gateway.this[each.value.vpc].id : each.value.gateway_id, 
                                    null
                                  )
  nat_gateway_id                = try(try(aws_nat_gateway.this[format("%s-%s",each.value.vpc, each.value.nat_gateway_id)].id, each.value.nat_gateway_id), null)
  local_gateway_id              = try(each.value.local_gateway_id , null)
  network_interface_id          = try(each.value.network_interface_id, null)
  transit_gateway_id            = try( 
                                    aws_ec2_transit_gateway.this[each.value.transit_gateway_id].id, 
                                    try( 
                                      data.aws_ec2_transit_gateway.shared_tgw[each.value.transit_gateway_id].id, 
                                      try(each.value.transit_gateway_id, null)) 
                                    )
  vpc_endpoint_id               = try(each.value.vpc_endpoint_id, null)
  vpc_peering_connection_id     = try(
                                    aws_vpc_peering_connection.requester[format("%s-%s",each.value.vpc, each.value.vpc_peering_connection_id)].id, 
                                    try(
                                      aws_vpc_peering_connection_accepter.accepter[format("%s-%s",each.value.vpc, each.value.vpc_peering_connection_id)].id, 
                                      try(each.value.vpc_peering_connection_id, null))
                                    )

  depends_on = [ 
                aws_route_table.this, 
                aws_internet_gateway.this, 
                aws_ec2_transit_gateway.this,
                data.aws_ec2_transit_gateway.shared_tgw,
                aws_vpc_peering_connection.requester,
                data.aws_vpc_peering_connection.pc
              ]

}


