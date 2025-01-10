# Outputs

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# We need this to get the account id to plan.tfplan for rego policy
output "account_id" {
  value = local.account_id
}
