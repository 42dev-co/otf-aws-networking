### Prefix Lists
locals {
  ### Prefix Lists (Region wide)
  prefix_lists_array = [for f in fileset(path.module, "./resources/prefix_lists/*.yaml"): [try(yamldecode(file(f)), null), f]]
  prefix_lists_with_err = [ for prefix_list in local.prefix_lists_array: prefix_list[1] if prefix_list[0] == null ]
  prefix_lists_has_err = length(local.prefix_lists_with_err) > 0
  prefix_lists = local.prefix_lists_has_err ? {} : merge([ for prefix_list in local.prefix_lists_array: prefix_list[0]]...)
}

resource "aws_ec2_managed_prefix_list" "this" {
  for_each = local.prefix_lists

  name = each.key
  address_family = each.value.address_family
  max_entries = each.value.max_entries <= 1000 ? each.value.max_entries : 1000
  
  dynamic "entry" {
    for_each = try(each.value.entries, {})
    content {
      cidr = entry.value.cidr
      description = entry.value.description
    }
  }
  
  tags = merge(
    var.default_tags,
    try(each.value.tags, {})
  )
}