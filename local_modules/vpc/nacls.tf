resource "aws_network_acl" "this" {
  for_each =  try(var.config.create, true) ? try(var.config.nacls, {}) : {}

  vpc_id = aws_vpc.this[0].id 
  
  subnet_ids = [for subnet in [ for k, v in var.config.subnets: k if v.nacl == each.key ]: aws_subnet.this[subnet].id ]

  tags =  merge(
    var.default_tags,
    { 
      Name = format("%s_nacl-%s", var.name, each.key),
      vpc_name = var.name,
      vpc_id = aws_vpc.this[0].id, 
    },
    try(each.value.tags, {}),
  )

  depends_on = [ aws_vpc.this, aws_subnet.this ]  
}

resource "aws_default_network_acl" "this" {

  count =  try(var.config.create, true) ? 1 : 0
  
  default_network_acl_id = aws_vpc.this[0].default_network_acl_id

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
    for_each = try(var.config.assign_generated_ipv6_cidr_block, false) ? [1] : []
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
    for_each = try(var.config.assign_generated_ipv6_cidr_block, false) ? [1] : []
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
      for subnet in [for k, v in var.config.subnets : k if try(v.nacl, "default") == "default" ] : 
      aws_subnet.this[subnet].id
    ], 
    []
  )

  depends_on = [ aws_vpc.this, aws_subnet.this ]
}

resource "aws_network_acl_rule" "ingress" {
  for_each =   try(var.config.create, true) ? try(merge(
    flatten(
      [ for nacl_name, nacl_attr in var.config.nacls: 
        [ for rule_index, rule_attr in nacl_attr.ingress:  
          { "${nacl_name}_ingress_${rule_index}" = merge(rule_attr, { nacl_name = nacl_name, rule_number = rule_index}) } 
        ]
      ]
    )...
  ), {}) : {}

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
  for_each =   try(var.config.create, true) ? try(merge(
    flatten(
      [ for nacl_name, nacl_attr in var.config.nacls: 
        [ for rule_index, rule_attr in nacl_attr.egress:  
          { "${nacl_name}_ingress_${rule_index}" = merge(rule_attr, { nacl_name = nacl_name, rule_number = rule_index}) } 
        ]
      ]
    )...
  ), {}) : {}

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
