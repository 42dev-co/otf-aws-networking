### Network ACLs

locals {
  # Network ACLs (Per VPCs)
  vpc_nacls = merge([ for vpc, vpc_config  in local.vpcs: { 
    for nacl, nacl_config in vpc_config.nacls: "${vpc}-${nacl}" =>  
      merge(nacl_config, 
      { nacl = nacl, vpc = vpc , subnets = [for subnet, subnet_config in vpc_config.subnets: "${vpc}-${subnet}" if subnet_config.nacl == nacl] }
    ) } ]...)

  vpc_nacls_egress_rules = merge([ for nacl, nacl_config in local.vpc_nacls: {
    for rule, rule_config in nacl_config.egress: 
      "${nacl}-${rule}" => merge(rule_config, { nacl_name = nacl, rule_number = rule })
  }]...)

  vpc_nacls_ingress_rules = merge([ for nacl, nacl_config in local.vpc_nacls: {
    for rule, rule_config in nacl_config.ingress: 
      "${nacl}-${rule}" => merge(rule_config, { nacl_name = nacl, rule_number = rule })
  }]...)
}


# Default Network ACL
resource "aws_default_network_acl" "this" {

  for_each = local.vpcs
  
  default_network_acl_id = aws_vpc.this[each.key].default_network_acl_id

  # IPv4 Ingress rule
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # IPv6 Ingress rule (conditionally added)
  dynamic "ingress" {
    for_each = try(each.value.assign_generated_ipv6_cidr_block, false) ? [1] : []
    content {
      protocol       = -1
      rule_no        = 110
      action         = "allow"
      ipv6_cidr_block = "::/0"
      from_port      = 0
      to_port        = 0
    }
  }

  # IPv4 Egress rule
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # IPv6 Egress rule (conditionally added)
  dynamic "egress" {
    for_each = try(each.value.assign_generated_ipv6_cidr_block, false) ? [1] : []
    content {
      protocol       = -1
      rule_no        = 110
      action         = "allow"
      ipv6_cidr_block = "::/0"
      from_port      = 0
      to_port        = 0
    }
  }

  # Associate with subnets tagged to use the default NACL
  subnet_ids = try(
    [
      for subnet in [for k, v in each.value.subnets : k if try(v.nacl, "default") == "default" ] : 
      aws_subnet.this["${each.key}-${subnet}"].id
    ], 
    []
  )

  depends_on = [ aws_vpc.this, aws_subnet.this ]
}

resource "aws_network_acl" "this" {
  for_each =  local.vpc_nacls

  vpc_id = aws_vpc.this[each.value.vpc].id 
  
  subnet_ids = [for subnet in each.value.subnets: aws_subnet.this[subnet].id ]

  tags =  merge(
    var.default_tags,
    { 
      Name = format("%s_nacl",each.key),
      vpc_name = each.value.vpc,
      vpc_id = aws_vpc.this[each.value.vpc].id, 
    },
    try(each.value.tags, {}),
  )

  depends_on = [ aws_vpc.this, aws_subnet.this ]  
}

resource "aws_network_acl_rule" "ingress" {
  for_each = local.vpc_nacls_ingress_rules

  network_acl_id   = aws_network_acl.this[each.value.nacl_name].id
  rule_number      = each.value.rule_number
  egress           = false
  protocol         = each.value.protocol
  rule_action      = each.value.rule_action
  cidr_block       = try(each.value.cidr_block, null)
  ipv6_cidr_block  = try(each.value.ipv6_cidr_block, null)
  from_port        = try(each.value.from_port, null)
  to_port          = try(each.value.to_port, null) 
  icmp_type        = try(each.value.icmp_type, null) 
  icmp_code        = try(each.value.icmp_code, null)   
}

resource "aws_network_acl_rule" "egress" {
  for_each = local.vpc_nacls_egress_rules

  network_acl_id   = aws_network_acl.this[each.value.nacl_name].id
  rule_number      = each.value.rule_number
  egress           = true
  protocol         = each.value.protocol
  rule_action      = each.value.rule_action
  cidr_block       = try(each.value.cidr_block, null)
  ipv6_cidr_block  = try(each.value.ipv6_cidr_block, null)
  from_port        = try(each.value.from_port, null)
  to_port          = try(each.value.to_port, null) 
  icmp_type        = try(each.value.icmp_type, null) 
  icmp_code        = try(each.value.icmp_code, null) 
}
