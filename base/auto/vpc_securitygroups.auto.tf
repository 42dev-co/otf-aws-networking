### Security Groups

locals {
  # Security Groups (Per VPCs)
  array_of_security_groups  = [for f in fileset(path.module, "./resources/vpcs/*/security_groups/**/*.yaml"): {"${split("/", f)[2]}" = yamldecode(file(f))} if try(local.vpcs[split("/", f)[2]].create, false) ]
  vpc_security_groups = merge(flatten([ for m in local.array_of_security_groups: 
    [ for vpc, data in m: {
      for sg, sg_data in data: 
        "${vpc}-${sg}" => merge(sg_data, { vpc = vpc, name = sg })
      } if try(local.vpcs[vpc].create, true)
    ]
  ])...)
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  for_each = local.vpc_security_groups

  create                                = try(each.value.create, true)     
  name                                  = each.value.name
  description                           = try(each.value.description, "Security Group managed by Terraform")
  vpc_id                                = aws_vpc.this[each.value.vpc].id

  ingress_cidr_blocks                   = try(each.value.ingress_cidr_blocks, [])
  ingress_rules                         = try(each.value.ingress_rules, [])
  ingress_with_cidr_blocks              = try(each.value.ingress_with_cidr_blocks, [])
  ingress_with_ipv6_cidr_blocks         = try(each.value.ingress_with_ipv6_cidr_blocks, [])
  ingress_with_prefix_list_ids          = try(each.value.ingress_with_prefix_list_ids, [])
  ingress_with_self                     = try(each.value.ingress_with_self, [])
  ingress_with_source_security_group_id = try(each.value.ingress_with_source_security_group_id, [])

  egress_cidr_blocks                    = try(each.value.egress_cidr_blocks, [])
  egress_rules                          = try(each.value.egress_rules, [])
  egress_with_cidr_blocks               = try(each.value.egress_with_cidr_blocks, [])
  egress_with_ipv6_cidr_blocks          = try(each.value.egress_with_ipv6_cidr_blocks, [])
  egress_with_prefix_list_ids           = try(each.value.egress_with_prefix_list_ids, [])
  egress_with_self                      = try(each.value.egress_with_self, [])
  egress_with_source_security_group_id  = try(each.value.egress_with_source_security_group_id, [])

  tags = merge(
    var.default_tags, 
    { 
      Name     = each.key,
      vpc_name = each.value.vpc,
      vpc_id   = aws_vpc.this[each.value.vpc].id
    },
    try(each.value.tags, {})
  )

  depends_on = [ aws_vpc.this ]
}
