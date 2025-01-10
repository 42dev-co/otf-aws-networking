package compliances.vpc_bpa

import future.keywords.in
import future.keywords.if
import future.keywords.contains

debug_account_id := input.account.id

# List of accounts to be excluded
excluded_accounts = [] #["050451372847", "495599747052", "210987654321"]

# Helper rule to check if the current account should be excluded
is_excluded if {
    input.planned_values.outputs.account_id.value == excluded_accounts[_]
}

# Deny if aws_vpc_block_public_access_options is missing
deny contains msg if {
    not is_excluded
    not vpc_bpa_exists
    msg := "aws_vpc_block_public_access_options resource is missing in the Terraform plan"
}

# Deny if internet_gateway_block_mode is not set to "block-bidirectional"
deny contains msg if {
    not is_excluded
    resource := vpc_bpa_resources[_]
    not resource.change.after.internet_gateway_block_mode == "block-bidirectional"
    msg := sprintf("aws_vpc_block_public_access_options (address: %s) must have internet_gateway_block_mode set to 'block-bidirectional'", [resource.address])
}

# Helper rule to check if the resource exists
vpc_bpa_exists if {
    count(vpc_bpa_resources) > 0
}

# Helper rule to get all aws_vpc_block_public_access_options resources
vpc_bpa_resources contains resource if {
    resource := input.resource_changes[_]
    resource.type == "aws_vpc_block_public_access_options"
}
