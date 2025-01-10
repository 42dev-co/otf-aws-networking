resource "aws_vpc_peering_connection" "requester" {
  for_each = try(var.config.create, true) ? try(var.config.vpc_peering.requesters, {}) : {}

  vpc_id        = aws_vpc.this[0].id
  peer_vpc_id   = each.value.peer_vpc_id
  peer_owner_id = each.value.peer_owner_id
  peer_region   = each.value.peer_region
  auto_accept   = false

  tags = merge(var.default_tags, 
    { 
      "Name"          = each.key,
      "peer_vpc_id"   = each.value.peer_vpc_id
      "peer_region"   = each.value.peer_region
      "peer_owner_id" = each.value.peer_owner_id
      "type"          = "requester"
    }, 
    try(each.value.tags, {})
  )
}

resource "aws_vpc_peering_connection_accepter" "accepter" {
  for_each = try(var.config.create, true) ? try(var.config.vpc_peering.accepters, {}) : {}

  vpc_peering_connection_id = each.value.vpc_peering_connection_id
  auto_accept               = true

   tags = merge(var.default_tags, 
    { 
      "Name"                        = each.key,
      "vpc_peering_connection_id"   = each.value.peer_vpc_id
      "peer_region"                 = each.value.peer_region
      "type"                        = "accepter"
    }, 
    try(each.value.tags, {})
  )
}

locals {
  peering_connections = merge(concat([ for k , v in aws_vpc_peering_connection.requester:  {"${k}" = v.id } ], [ for k , v in aws_vpc_peering_connection_accepter.accepter:  {"${k}" = v.id} ])...)
}
