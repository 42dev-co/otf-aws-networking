# Default Security Group for Route53 Resolver

resource "aws_security_group" "resolver_enpoints" {
  for_each =   try(var.config.create, true) && try(var.config.route53_endpoints.create, false) ? local.security_groups_per_resolver_endpoint : {}
  # for_each = local.security_groups_per_resolver_endpoint

  name        = each.key
  description = "Route53 Resolver Endpoint Security Group for ${each.key}"
  vpc_id      = aws_vpc.this[0].id

  dynamic "ingress" {
    for_each = toset(try(each.value.ipv4, []))
    content {
      description      = "Allow route 53 queries in, udp"
      from_port        = 53
      to_port          = 53
      cidr_blocks      = ["${ingress.key}"]
      protocol         = "udp"
    }
  }

  dynamic "ingress" {
    for_each = toset(try(each.value.ipv4, []))
    content {
      description      = "Allow route 53 queries in, tcp"
      from_port        = 53
      to_port          = 53
      cidr_blocks      = ["${ingress.key}"]
      protocol         = "tcp"
    }
  }

  dynamic "ingress" {
    for_each = toset(try(each.value.ipv6, []))
    content {
      description      = "Allow route 53 queries in, udp"
      from_port        = 53
      to_port          = 53
      ipv6_cidr_blocks      = ["${ingress.key}"]
      protocol         = "udp"
    }
  }

  dynamic "ingress" {
    for_each = toset(try(each.value.ipv6, []))
    content {
      description      = "Allow route 53 queries in, tcp"
      from_port        = 53
      to_port          = 53
      ipv6_cidr_blocks      = ["${ingress.key}"]
      protocol         = "tcp"
    }
  }
}

resource "aws_route53_resolver_endpoint" "inbound" {
  
  for_each = try(var.config.create, true) && try(var.config.route53_endpoints.create, false) ? try(var.config.route53_endpoints.inbound, {}) : {}
  # for_each =  try(var.config.route53_endpoints.inbound, {}) 
  
  direction           = "INBOUND"
  name                = "${each.key}-inbound"

  # use default security group if none specify
  security_group_ids  = [aws_security_group.resolver_enpoints["${each.key}_inbound"].id]

  dynamic "ip_address" {
    for_each = try(each.value.ip_addresses, {})

    content {
      subnet_id = try(aws_subnet.this[ip_address.value.subnet_id].id, ip_address.value.subnet_id)
      ip        = try(ip_address.value.ip, null)
    }
  }

  tags = merge(var.default_tags, 
    { 
      "Name" = "${each.key}-inbound" ,
    }, 
    try(each.value.tags, {})
  )

  timeouts {
    create = try(each.value.timeouts.create ,"20m")
    update = try(each.value.timeouts.update ,"20m")
    delete = try(each.value.timeouts.delete ,"20m")
  }

  depends_on = [ aws_security_group.resolver_enpoints ]
}

resource "aws_route53_resolver_endpoint" "outbound" {
  
  for_each = try(var.config.create, true) && try(var.config.route53_endpoints.create, false) ? try(var.config.route53_endpoints.outbound, {}) : {}

  direction           = "OUTBOUND"
  name                = "${each.key}-outbound"

  # use default security group if none specify
  security_group_ids  =  [aws_security_group.resolver_enpoints["${each.key}_outbound"].id]

  dynamic "ip_address" {
    for_each = try(each.value.ip_addresses, {})

    content {
      subnet_id = ip_address.value.subnet_id
      ip        = try(ip_address.value.ip, null)
    }
  }

  tags = merge(var.default_tags, 
    { 
      "Name" = "${each.key}-outbound" ,
    }, 
    try(each.value.tags, {})
  )

  timeouts {
    create = try(each.value.timeouts.create ,"20m")
    update = try(each.value.timeouts.update ,"20m")
    delete = try(each.value.timeouts.delete ,"20m")
  }

  depends_on = [ aws_security_group.resolver_enpoints ]
}

resource "aws_route53_resolver_rule" "this" {

  for_each = try(var.config.create, true) && try(var.config.route53_endpoints.create, false) ?  try(var.config.route53_endpoints.rules, {}) : {}


  domain_name          = each.value.domain_name
  name                 = each.key
  rule_type            = try(each.value.rule_type, "FORWARD")

  resolver_endpoint_id = try(each.value.rule_type, "FORWARD") == "FORWARD" ? aws_route53_resolver_endpoint.outbound[each.value.resolver_outbound_endpoint].id : null

  dynamic "target_ip" {
    for_each = try(each.value.target_ips, {})

    content{
      ip   = target_ip.key
      port = target_ip.value
    }
  }

  tags                =  merge(
    { "Name" = "${each.key}-rules" },
    try(each.value.tags, {}),
    var.default_tags
  )
}

locals {
  resolver_rule_association = try(var.config.create, true)  ? merge([
    for rule_k, rule_v in try(var.config.route53_endpoints.rules, {}) : merge([
      # Default association
      try(rule_v.associate_default_vpc, false) ? {
        "${rule_k}-default" : {
          rule_k = rule_k
          vpc_id = aws_vpc.this[0].id
        }
      } : {},
      # Additional association
      {
        for asso_k, asso_v in try(rule_v.association, {}) :
          "${rule_k}-${asso_k}" => {
            rule_k = rule_k
            vpc_id = try(asso_v.vpc_id, null)
          }
      }
    ]...)
  ]...) : {}

  security_groups_per_resolver_endpoint = merge(flatten([for type in ["outbound", "inbound"]: [for endpoint, attr in try(var.config.route53_endpoints[type], {}):  { "${endpoint}_${type}" = attr.whitelist_cidr_blocks } ]])...)
}

resource "aws_route53_resolver_rule_association" "resolver_rule_association" {
  for_each =  try(var.config.create, true) && try(var.config.route53_endpoints.create, false) ? local.resolver_rule_association : {}
  
  resolver_rule_id = aws_route53_resolver_rule.this[each.value.rule_k].id
  vpc_id           = each.value.vpc_id
}


# output "security_groups_per_resolver_endpoint" {
#   value = local.security_groups_per_resolver_endpoint
# }