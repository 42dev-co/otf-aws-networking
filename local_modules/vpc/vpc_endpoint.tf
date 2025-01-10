








# data "aws_region" "current" {}

# resource "aws_vpc_endpoint" "this" {
  
#   for_each = try(var.config.create, true) && try(var.config.vpc_endpoints.create, false) ? var.config.vpc_endpoints.endpoints : {}

#   vpc_id            = aws_vpc.this[0].id
  
#   service_name      = replace(each.value.service_name, "{{region}}", data.aws_region.current.name)
#   vpc_endpoint_type = try(each.value.vpc_endpoint_type, "Interface")
#   auto_accept       = try(each.value.auto_accept, null)

#   security_group_ids  = try(each.value.vpc_endpoint_type, "Interface") == "Interface" ? ( length(try(each.value.security_group_ids, [])) > 0 ? try(each.value.security_group_ids, []) : null ): null 
#   subnet_ids          = try(each.value.vpc_endpoint_type, "Interface") == "Interface" ? try(each.value.subnet_ids, []) : null
#   route_table_ids     = try(each.value.vpc_endpoint_type, "Interface") == "Gateway" ? try([for route_table_id in each.value.route_table_ids: aws_route_table.this[route_table_id].id], null) : null
#   policy              = try(each.value.policy, null)
#   private_dns_enabled = try(each.value.vpc_endpoint_type, "Interface") == "Interface" ? try(each.value.private_dns_enabled, null) : null

# #   dns_options {
# #     dns_record_ip_type = try(each.value.dns_options.dns_record_ip_type, null)
# #     private_dns_only_for_inbound_resolver_endpoint = try(each.value.dns_options.private_dns_only_for_inbound_resolver_endpoint, null)
# #   }

#   ip_address_type = try(each.value.ip_address_type, null)

#   tags = merge(
#     { Name = each.key }, 
#     var.default_tags, 
#     try(each.value.tags, {}) 
#   )

#   timeouts {
#     create = try(each.value.timeouts.create, null)
#     update = try(each.value.timeouts.update, null )
#     delete = try(each.value.timeouts.delete, null)
#   }

#   depends_on = [ aws_route_table.this, aws_subnet.this ]
# }

# locals {
#   enable_endpoint_on_rt_tables =  try(var.config.create, true) ? [for route_table, config in try(var.config.route_tables, {}): route_table if try(config.enable_builtin_endpoint, false) ] : []
# }

# output "tables" {
#   value = local.enable_endpoint_on_rt_tables
# }


# resource "aws_vpc_endpoint" "s3" {
#   count = try(var.config.create, true) && length(local.enable_endpoint_on_rt_tables) > 0 ? 1 : 0

#   vpc_id            = aws_vpc.this[0].id

#   service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
#   vpc_endpoint_type = "Gateway"
#   route_table_ids   = [for route_table_name in local.enable_endpoint_on_rt_tables: aws_route_table.this[route_table_name].id]
  
#   tags = merge(
#     {
#       Name = "s3-vpc-endpoint"
#       vpc_id = aws_vpc.this[0].id
#       vpc_name = var.name
#     },
#     var.default_tags
#   )
# }

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "gateway_endpoint" {
  for_each = try(var.config.create, true) &&  try(var.config.recommended_endpoints.create, true) ? try(var.config.recommended_endpoints.gateway_endpoints, {}) : {}

  vpc_id            = aws_vpc.this[0].id
  service_name      = replace(each.value.service_name, "{{region}}", data.aws_region.current.name)
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for route_table_id in try(each.value.route_table_ids, []): try(aws_route_table.this[route_table_id].id, route_table_id)]

  tags = merge(
    {
      Name = each.key
      vpc_id = aws_vpc.this[0].id
      vpc_name = var.name
    },
    var.default_tags
  )

  lifecycle {
    ignore_changes = [ service_name ]
  }

  depends_on = [ aws_vpc.this, aws_route_table.this ]
}

resource "aws_vpc_endpoint" "interface_endpoint" {
  for_each = try(var.config.create, true) &&  try(var.config.recommended_endpoints.create, true) ? try({ for k, v in var.config.recommended_endpoints.interface_endpoints: k => v if try(v.create, false)}, {}) : {}

  vpc_id             = aws_vpc.this[0].id
  service_name       = replace(each.value.service_name, "{{region}}", data.aws_region.current.name)
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [for subnet_id in try(each.value.subnet_ids, []): try(aws_subnet.this[subnet_id].id, subnet_id)]
  security_group_ids = try([for sg_id in each.value.security_group_ids: try(module.security_group[sg_id].security_group_id, sg_id)], [])

  private_dns_enabled = true

  tags = merge(
    {
      Name = each.key
      vpc_id = aws_vpc.this[0].id
      vpc_name = var.name
    },
    var.default_tags
  )

  lifecycle {
    ignore_changes = [ service_name ]
  }
  depends_on = [ aws_vpc.this, aws_subnet.this, module.security_group ]
}



