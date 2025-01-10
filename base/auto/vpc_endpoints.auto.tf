
### VPC ENDPOINTS

locals {
  # Common Gateway Endpoints
  common_gateway_endpoints = merge(flatten([ for vpc, vpc_config in local.vpcs: [
    for endpoint, endpoint_config in try(vpc_config.common_endpoints.gateway_endpoints, {}): {
      "${vpc}-${endpoint}" = merge(endpoint_config, { vpc = vpc, name = endpoint })
    } 
  ]])...)

  # Common Interface Endpoints
  common_interface_endpoints = merge(flatten([ for vpc, vpc_config in local.vpcs: [
    for endpoint, endpoint_config in try(vpc_config.common_endpoints.interface_endpoints, {}): {
      "${vpc}-${endpoint}" = merge(endpoint_config, { vpc = vpc, name = endpoint })
    }  if try(endpoint_config.create, false)
  ]])...)
}

# VPC GATEWAY ENDPOINT

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "gateway_endpoint" {
  for_each = local.common_gateway_endpoints

  vpc_id            = aws_vpc.this[each.value.vpc].id
  service_name      = replace(each.value.service_name, "{{region}}", data.aws_region.current.name)
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for route_table_id in try(each.value.route_table_ids, []): try(aws_route_table.this["${each.value.vpc}-${route_table_id}"].id, route_table_id)]

  tags = merge(
    {
      Name = each.key
      vpc_id = aws_vpc.this[each.value.vpc].id
      vpc_name = each.value.vpc
    },
    var.default_tags
  )

  lifecycle {
    ignore_changes = [ service_name ]
  }

  depends_on = [ aws_vpc.this, aws_route_table.this ]
}

# VPC INTERFACE ENDPOINT

resource "aws_vpc_endpoint" "interface_endpoint" {
  for_each = local.common_interface_endpoints

  vpc_id             = aws_vpc.this[each.value.vpc].id
  service_name       = replace(each.value.service_name, "{{region}}", data.aws_region.current.name)
  vpc_endpoint_type  = "Interface"
  subnet_ids         = [for subnet_id in try(each.value.subnet_ids, []): try(aws_subnet.this["${each.value.vpc}-${subnet_id}"].id, subnet_id)]
  security_group_ids = [for sgid in try(each.value.security_group_ids, []): try(module.security_group["${each.value.vpc}-${sgid}"].security_group_id, sgid)]

  private_dns_enabled = true

  tags = merge(
    {
      Name = each.value.name
      vpc_id = aws_vpc.this[each.value.vpc].id
      vpc_name = each.value.vpc
    },
    var.default_tags
  )

  lifecycle {
    ignore_changes = [ service_name ]
  }
  depends_on = [ aws_vpc.this, aws_subnet.this, module.security_group ]
}