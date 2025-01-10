output "aws_ram_resource_share_id" {
  description = "The ID of the RAM resource share"
  value = try(var.config.create, true) && try(length(var.config.principals) > 0, false) ? aws_ram_resource_share.tgw[0].id : null
}

output "vpc_attachment_ids" {
  value = try(var.config.create, true) ? try([for k, v in var.config.vpc_attachments: aws_ec2_transit_gateway_vpc_attachment.this[k].id if try(v.create, false) ], []) : []
}

output "peering_attachment_ids" {
  value = try(var.config.create, true) ? try([for k, v in var.config.vpc_attachments: aws_ec2_transit_gateway_peering_attachment.this[k].id if try(v.create, false) ], []) : []
}

output "vpc_attachment_accepter_ids" {
  value = try(var.config.create, true) ? try([for k, v in var.config.vpc_attachments: aws_ec2_transit_gateway_vpc_attachment_accepter.this[k].id if try(v.create, false) ], []) : []
}

output "peering_attachment_accepter_ids" {
  value = try(var.config.create, true) ? try([for k, v in var.config.vpc_attachments: aws_ec2_transit_gateway_peering_attachment_accepter.this[k].id if try(v.create, false) ], []) : []
}