resource "aws_vpc" "this" {
  count = try(var.config.create, true) ? 1 : 0

  cidr_block                            = var.config.cidr_block
  instance_tenancy                      = try(var.config.instance_tenancy, "default")
  ipv4_ipam_pool_id                     = try(var.config.ipv4_ipam_pool_id, null)
  ipv4_netmask_length                   = try(var.config.ipv4_netmask_length, null)
  ipv6_cidr_block                       = try(var.config.ipv6_cidr_block, null)
  ipv6_ipam_pool_id                     = try(var.config.ipv6_ipam_pool_id, null)
  ipv6_netmask_length                   = try(var.config.ipv6_netmask_length, null)
  ipv6_cidr_block_network_border_group  = try(var.config.ipv6_cidr_block_network_border_group, null)
  enable_dns_support                    = try(var.config.enable_dns_support, true)
  enable_network_address_usage_metrics  = try(var.config.enable_network_address_usage_metrics, false)
  enable_dns_hostnames                  = try(var.config.enable_dns_hostnames, false)
  assign_generated_ipv6_cidr_block      = try(var.config.assign_generated_ipv6_cidr_block, false)
  
  tags = merge(
    {
      Name: var.name,
      ipv6_enabled: try(var.config.assign_generated_ipv6_cidr_block, false)
    },
    var.default_tags, 
    try(var.config.tags, {})
  )
}

resource "aws_vpc_block_public_access_options" "this_vpc" {
  count = try(var.config.create, true) && try(var.config.enable_vpc_bpa, true) ? 1 : 0
  internet_gateway_block_mode = var.config.internet_gateway_block_mode
}