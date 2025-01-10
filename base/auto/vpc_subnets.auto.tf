### Subnets
locals {
  # Subnets (Per VPCs)
  vpc_subnets     = merge([ for vpc, vpc_config in local.vpcs: {
    for subnet, subnet_config in vpc_config.subnets: 
      "${vpc}-${subnet}" => merge(subnet_config, { vpc = vpc, azs_map = vpc_config.azs, name = subnet })
  }]...)
}

resource "aws_subnet" "this" {
  
  for_each = local.vpc_subnets

  vpc_id                                         = aws_vpc.this[each.value.vpc].id
  cidr_block                                     = each.value.cidr_block
  availability_zone                              = each.value.azs_map[each.value.az]
  map_public_ip_on_launch                        = try(each.value.map_public_ip_on_launch, false)

  # Optional attributes
  ## IPv6
  assign_ipv6_address_on_creation                = try(local.vpcs[each.value.vpc].assign_generated_ipv6_cidr_block, false) ? true: try(each.value.assign_ipv6_address_on_creation, false)
  ipv6_cidr_block                                = try(local.vpcs[each.value.vpc].assign_generated_ipv6_cidr_block, false) ? cidrsubnet(aws_vpc.this[each.value.vpc].ipv6_cidr_block, 8, index(keys(local.vpcs[each.value.vpc].subnets), each.value.name)) : null 

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
      vpc_name: each.value.vpc,
      vpc_id: aws_vpc.this[each.value.vpc].id,
      ipv4_cidr_block: each.value.cidr_block,
      ipv6_cidr_block: try(local.vpcs[each.value.vpc].assign_generated_ipv6_cidr_block, false) ? cidrsubnet(aws_vpc.this[each.value.vpc].ipv6_cidr_block, 8, index(keys(local.vpcs[each.value.vpc].subnets), each.value.name)) : null
      availability_zone: each.value.azs_map[each.value.az]
     },
    try(each.value.tags, {}))

  depends_on = [aws_vpc.this]
}

resource "aws_vpc_block_public_access_exclusion" "this" {
  for_each = { for k, v in local.vpc_subnets: k => v if can(v.internet_gateway_exclusion_mode) }

  subnet_id = aws_subnet.this[each.key].id

  internet_gateway_exclusion_mode = each.value.internet_gateway_exclusion_mode

  depends_on = [aws_vpc.this, aws_subnet.this]
}
