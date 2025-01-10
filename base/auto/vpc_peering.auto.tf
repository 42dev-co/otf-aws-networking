### VPC-PEERING
resource "aws_vpc_peering_connection" "requester" {
  for_each = local.vpc_peering_connection_requesters

  vpc_id        = aws_vpc.this[each.value.vpc].id
  peer_vpc_id   = each.value.peer_vpc_id
  peer_owner_id = each.value.peer_owner_id
  peer_region   = each.value.peer_region
  auto_accept   = false

  tags = merge(var.default_tags, 
    { 
      "Name"          = each.key
      "peer_vpc_id"   = each.value.peer_vpc_id
      "peer_region"   = each.value.peer_region
      "peer_owner_id" = each.value.peer_owner_id
      "type"          = "requester"
    }, 
    try(each.value.tags, {})
  )

  depends_on = [ aws_vpc.this ]
}

data "aws_vpc_peering_connections" "pcs" {
}

data "aws_vpc_peering_connection" "pc" {
  for_each =  toset(data.aws_vpc_peering_connections.pcs.ids)
  id = each.key
}

resource "aws_vpc_peering_connection_accepter" "accepter" {
  for_each = local.vpc_peering_connection_accepters

  vpc_peering_connection_id = each.value.vpc_peering_connection_id
  auto_accept               = true

   tags = merge(var.default_tags, 
    { 
      "Name"                        = each.key
      "requester_vpc_id"            = data.aws_vpc_peering_connection.pc[each.value.vpc_peering_connection_id].vpc_id
      "requester_id"                = data.aws_vpc_peering_connection.pc[each.value.vpc_peering_connection_id].owner_id
      "cider_block"                 = try(data.aws_vpc_peering_connection.pc[each.value.vpc_peering_connection_id].cidr_block_set[0]["cidr_block"], data.aws_vpc_peering_connection.pc[each.value.vpc_peering_connection_id].cidr_block)
      "ipv6_cider_block"            = try(data.aws_vpc_peering_connection.pc[each.value.vpc_peering_connection_id].ipv6_cidr_block_set[0]["ipv6_cidr_block"], "")
      "type"                        = "accepter"
    }, 
    try(each.value.tags, {})
  )

  depends_on = [ aws_vpc.this, data.aws_vpc_peering_connection.pc ]
}
