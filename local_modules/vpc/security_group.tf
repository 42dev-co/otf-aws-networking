
locals {
  security_groups = { for k, v in var.security_groups: k => v  if try(var.config.create, true) }
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  for_each = local.security_groups

  create                                = try(each.value.create, true)     
  name                                  = each.key
  description                           = try(each.value.description, "Security Group managed by Terraform")
  vpc_id                                = aws_vpc.this[0].id

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
      vpc_name = var.name,
      vpc_id   = aws_vpc.this[0].id
    },
    try(each.value.tags, {})
  )

  depends_on = [ aws_vpc.this ]
}