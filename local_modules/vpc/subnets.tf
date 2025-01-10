resource "aws_subnet" "this" {
  for_each = try(var.config.create, true) ? try(var.config.subnets, {}) : {}

  vpc_id                                         = aws_vpc.this[0].id
  cidr_block                                     = each.value.cidr_block
  availability_zone                              = var.config.azs[each.value.az]
  map_public_ip_on_launch                        = try(each.value.map_public_ip_on_launch, false)

  # Optional attributes
  ## IPv6
  assign_ipv6_address_on_creation                = try(var.config.assign_generated_ipv6_cidr_block, false) ? true: try(each.value.assign_ipv6_address_on_creation, false)
  ipv6_cidr_block                                = try(var.config.assign_generated_ipv6_cidr_block, false) ? cidrsubnet(aws_vpc.this[0].ipv6_cidr_block, 8, index(keys(var.config.subnets), each.key)) :try(each.value.ipv6_cidr_block, null) 

  availability_zone_id                           = try(each.value.availability_zone_id, null)
  customer_owned_ipv4_pool                       = try(each.value.customer_owned_ipv4_pool, null)
  enable_dns64                                   = try(each.value.enable_dns64, false)
  enable_lni_at_device_index                     = try(each.value.enable_lni_at_device_index, null)
  enable_resource_name_dns_aaaa_record_on_launch = try(each.value.enable_resource_name_dns_aaaa_record_on_launch, false)
  enable_resource_name_dns_a_record_on_launch    = try(each.value.enable_resource_name_dns_a_record_on_launch, false)
  ipv6_native                                    = try(each.value.ipv6_native, false)
  map_customer_owned_ip_on_launch                = try(each.value.map_customer_owned_ip_on_launch, null)
  outpost_arn                                    = try(each.value.outpost_arn, null)
  private_dns_hostname_type_on_launch            = try(each.value.private_dns_hostname_type_on_launch, null)

  tags = merge(var.default_tags, 
    { 
      Name: each.key,
      vpc_name: var.name,
      vpc_id: aws_vpc.this[0].id,
      ipv4_cidr_block: each.value.cidr_block,
      ipv6_cidr_block: try(var.config.assign_generated_ipv6_cidr_block, false) ? cidrsubnet(aws_vpc.this[0].ipv6_cidr_block, 8, index(keys(var.config.subnets), each.key)) : try(each.value.ipv6_cidr_block, "None"),
      availability_zone: var.config.azs[each.value.az],
     },
    try(each.value.tags, {}))

  depends_on = [aws_vpc.this]
}

resource "aws_vpc_block_public_access_exclusion" "this_subnet" {
  for_each = try(var.config.create, true) && try(var.config.enable_vpc_bpa, true) ? try({for k, v in var.config.subnets: k => v if can(v.internet_gateway_exclusion_mode)}, {}) : {}

  subnet_id = aws_subnet.this[each.key].id

  internet_gateway_exclusion_mode = each.value.internet_gateway_exclusion_mode

  depends_on = [aws_vpc.this, aws_subnet.this]
}

# output "subnets" {
#   value = { for k, v in var.config.subnets : k => v if can(v.internet_gateway_exclusion_mode) }
# }