# EIP for Nat Gateway
resource "aws_eip" "this_nat" {
  for_each =  try(var.config.create, true) ? try(var.config.nat_gateways, {}) : {}
  
  domain    = "vpc"

  tags = merge(var.default_tags, 
    { 
      "Name"   = format("%s-nat-eip", each.key),
      "vpc"    = var.name,
      "subnet" = each.value.subnet
    }, 
    try(each.value.tags, {})
  )

  depends_on = [aws_internet_gateway.this]
}

# Nat Gateway
resource "aws_nat_gateway" "this" {
  for_each =  try(var.config.create, true) ? try(var.config.nat_gateways, {}) : {}

  # checks if the connectivity_type is public, 
  # if it is then it will use the eip id, 
  # otherwise it will use the allocation_id
  allocation_id                          = try(each.value.connectivity_type == "public", false) ? try(each.value.allocation_id, aws_eip.this_nat[each.key].id) : aws_eip.this_nat[each.key].id
  
  connectivity_type                      = try(each.value.connectivity_type, "public")
  private_ip                             = try(each.value.private_ip, null)
  # We can use subnet or subnet_id
  subnet_id                              = try(each.value.subnet_id, aws_subnet.this[each.value.subnet].id) 
  secondary_allocation_ids               = try(each.value.secondary_allocation_ids, [])
  secondary_private_ip_address_count     = try(each.value.secondary_private_ip_address_count, null)
  secondary_private_ip_addresses         = try(each.value.secondary_private_ip_addresses, [])

  tags = merge(var.default_tags, 
    { 
      "Name"   = format("%s-nat-gateway", each.key),
      "vpc"    = var.name,
      "subnet" = each.value.subnet
    }, 
    try(each.value.tags, {})
  )
  depends_on = [aws_internet_gateway.this, aws_subnet.this]

  lifecycle {
    ignore_changes = [
      subnet_id
    ]
  }
}
