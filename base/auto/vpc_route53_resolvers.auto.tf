locals {
  # Route53 Resolver Inbound Endpoints (Per VPCs)
  router53_inbound_endpoints = merge(flatten([ for vpc, vpc_config in local.vpcs: [
    for endpoint, endpoint_config in vpc_config.route53_endpoints.inbound: 
      { "${vpc}-${endpoint}" = merge(endpoint_config, { vpc = vpc, name = endpoint }) } if try(endpoint_config.create, false)
  ] if try(vpc.config.create, true) && try(vpc_config.route53_endpoints.create, false) ])...)

  # Route53 Resolver Outbound Endpoints (Per VPCs)
  router53_outbound_endpoints = merge(flatten([ for vpc, vpc_config in local.vpcs: [
    for endpoint, endpoint_config in vpc_config.route53_endpoints.outbound: 
      { "${vpc}-${endpoint}" = merge(endpoint_config, { vpc = vpc, name = endpoint }) } if try(endpoint_config.create, false)
  ] if try(vpc.config.create, true) && try(vpc_config.route53_endpoints.create, false) ])...)

  # Route53 Resolver Rules (Per VPCs)
  # Rules are created if there are outbound endpoints
  router53_resolver_rules = length(local.router53_outbound_endpoints) > 0 ? merge(flatten([ for vpc, vpc_config in local.vpcs: [
    for rule, rule_config in vpc_config.route53_endpoints.rules: 
      { "${vpc}-${rule}" = merge(rule_config, { vpc = vpc, name = rule }) } 
  ] if try(vpc.config.create, true) && try(vpc_config.route53_endpoints.create, false) ])...) : {}
}

### Route53 Resolver

resource "aws_security_group" "default_route53_endpoint" {
  for_each =   local.vpcs

  name        = each.key
  description = "Route53 Resolver Endpoint Security Group for ${each.key}"
  vpc_id      = aws_vpc.this[each.key].id

  dynamic "ingress" {
    for_each = toset(try(each.value.ipv4, []))
    content {
      description      = "Allow route 53 queries in, udp"
      from_port        = 53
      to_port          = 53
      cidr_blocks      = [aws_vpc.this[each.key].cidr_block]
      protocol         = "udp"
    }
  }

  dynamic "ingress" {
    for_each = toset(try(each.value.ipv4, []))
    content {
      description      = "Allow route 53 queries in, tcp"
      from_port        = 53
      to_port          = 53
      cidr_blocks      = [aws_vpc.this[each.key].cidr_block]
      protocol         = "tcp"
    }
  }

  dynamic "ingress" {
    for_each = toset(try(each.value.ipv6, []))
    content {
      description      = "Allow route 53 queries in, udp"
      from_port        = 53
      to_port          = 53
      ipv6_cidr_blocks = [aws_vpc.this[each.key].ipv6_cidr_block]
      protocol         = "udp"
    }
  }

  dynamic "ingress" {
    for_each = toset(try(each.value.ipv6, []))
    content {
      description      = "Allow route 53 queries in, tcp"
      from_port        = 53
      to_port          = 53
      ipv6_cidr_blocks = [aws_vpc.this[each.key].ipv6_cidr_block]
      protocol         = "tcp"
    }
  }

  tags = merge(
    var.default_tags, 
    { 
      "Name" = "default_route53_endpoint",
    }, 
  )


  depends_on = [ aws_security_group.default_route53_endpoint ]
}

resource "aws_route53_resolver_endpoint" "inbound" {
  
  for_each = local.router53_inbound_endpoints
  
  direction           = "INBOUND"
  name                = "${each.value.name}-inbound"

  security_group_ids  = length(try(each.value.security_group_ids, []))  > 0 ? [for sgid in try(each.value.security_group_ids, []): try(module.security_group["${each.value.vpc}-${sgid}"].security_group_id, sgid)] : [aws_security_group.default_route53_endpoint[each.value.vpc].id]

  dynamic "ip_address" {
    for_each = try(each.value.ip_addresses, {})

    content {
      subnet_id = try(aws_subnet.this["${each.value.vpc}-${ip_address.value.subnet_id}"].id, ip_address.value.subnet_id)
      ip        = try(ip_address.value.ip, null)
    }
  }

  tags = merge(var.default_tags, 
    { 
      "Name" = "${each.value.name}-inbound" ,
    }, 
    try(each.value.tags, {})
  )

  timeouts {
    create = try(each.value.timeouts.create ,"20m")
    update = try(each.value.timeouts.update ,"20m")
    delete = try(each.value.timeouts.delete ,"20m")
  }

  depends_on = [ module.security_group ]
}

resource "aws_route53_resolver_endpoint" "outbound" {
  
  for_each = local.router53_outbound_endpoints

  direction           = "OUTBOUND"
  name                = "${each.key}-outbound"

  # use default security group if none specify
  security_group_ids  =  length(try(each.value.security_group_ids, []))  > 0 ? [for sgid in try(each.value.security_group_ids, []): try(module.security_group["${each.value.vpc}-${sgid}"].security_group_id, sgid)] : [aws_security_group.default_route53_endpoint[each.value.vpc].id]

  dynamic "ip_address" {
    for_each = try(each.value.ip_addresses, {})

    content {
      subnet_id = try(aws_subnet.this["${each.value.vpc}-${ip_address.value.subnet_id}"].id, ip_address.value.subnet_id)
      ip        = try(ip_address.value.ip, null)
    }
  }

  tags = merge(var.default_tags, 
    { 
      "Name" = "${each.value.name}-outbound" ,
    }, 
    try(each.value.tags, {})
  )

  timeouts {
    create = try(each.value.timeouts.create ,"20m")
    update = try(each.value.timeouts.update ,"20m")
    delete = try(each.value.timeouts.delete ,"20m")
  }

  depends_on = [ aws_security_group.default_route53_endpoint ]
}

resource "aws_route53_resolver_rule" "this" {
  for_each = local.router53_resolver_rules

  domain_name          = each.value.domain_name
  name                 = each.value.name
  rule_type            = try(each.value.rule_type, "FORWARD")

  resolver_endpoint_id = try(each.value.rule_type, "FORWARD") == "FORWARD" ? aws_route53_resolver_endpoint.outbound["${each.value.vpc}-${each.value.resolver_outbound_endpoint}"].id : null

  dynamic "target_ip" {
    for_each = try(each.value.target_ips, {})

    content{
      ip   = target_ip.key
      port = target_ip.value
    }
  }

  tags = merge(
    { "Name" = each.value.name },
    try(each.value.tags, {}),
    var.default_tags
  )
}

resource "aws_route53_resolver_rule_association" "resolver_rule_association" {
  for_each =  { for k, v in local.router53_resolver_rules: k => v if try(v.associate, false) }
  
  resolver_rule_id = aws_route53_resolver_rule.this[each.key].id
  vpc_id           = aws_vpc.this[each.value.vpc].id

  depends_on = [ aws_vpc.this, aws_route53_resolver_rule.this ]
}
