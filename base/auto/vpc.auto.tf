### VPC and IGW
locals {

  ### VPCs (Per Definition)
  # 1. we decode the yaml files and return null with the filename if yaml has an error
  # 2. we filter out vpcs that have errors
  # 3. we create boolean if there are errors
  # 4. we create an array of vpcs, if there are no errors
  # 5. we create a set of vpc names, unique vpc names
  # 6. we group vpcs by vpc name
  # 7. we filter out vpcs that are set to be created
  vpcs_config_tuple = [ for f in fileset(path.module, "./resources/vpcs/*/*.yaml"): ["${split("/", f)[2]}", try(yamldecode(file(f)), null), f] ]
  vpc_config_tuple_with_err = [ for vpc in local.vpcs_config_tuple: vpc[2] if vpc[1] == null ]
  vpc_config_tuple_has_err = length(local.vpc_config_tuple_with_err) > 0 
  array_of_vpcs = [ for tuple in  local.vpcs_config_tuple :  merge({ vpc = "${tuple[0]}"}, tuple[1]) if local.vpc_config_tuple_has_err == false ]
  vpc_names = toset([ for vpc in local.array_of_vpcs: vpc.vpc ])
  grouped_vpcs = { 
    for vpc in local.vpc_names: vpc => merge([ 
      for v in local.array_of_vpcs: 
        v if v.vpc == vpc 
    ]...)
  }
  vpcs = { for k, v in local.grouped_vpcs: k => v if try(v.create, true) }
}

resource "aws_vpc" "this" {
  for_each = local.vpcs

  cidr_block                            = each.value.cidr_block
  instance_tenancy                      = try(each.value.instance_tenancy, "default")
  ipv4_ipam_pool_id                     = try(each.value.ipv4_ipam_pool_id, null)
  ipv4_netmask_length                   = try(each.value.ipv4_netmask_length, null)
  ipv6_cidr_block                       = try(each.value.ipv6_cidr_block, null)
  ipv6_ipam_pool_id                     = try(each.value.ipv6_ipam_pool_id, null)
  ipv6_netmask_length                   = try(each.value.ipv6_netmask_length, null)
  ipv6_cidr_block_network_border_group  = try(each.value.ipv6_cidr_block_network_border_group, null)
  enable_dns_support                    = try(each.value.enable_dns_support, true)
  enable_network_address_usage_metrics  = try(each.value.enable_network_address_usage_metrics, false)
  enable_dns_hostnames                  = try(each.value.enable_dns_hostnames, false)
  assign_generated_ipv6_cidr_block      = try(each.value.assign_generated_ipv6_cidr_block, false)
  
  tags = merge(
    {
      Name: each.key,
      ipv6_enabled: try(each.value.assign_generated_ipv6_cidr_block, false)
    },
    var.default_tags, 
    try(each.value.tags, {})
  )
}


