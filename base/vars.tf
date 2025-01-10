variable "default_tags" {
  default = {
    opentofu = "true"
    module = "otf-iac-aws-networking"
  }
}

variable "aws_vpc_block_public_access_options" {
  description = "(Optional) Enable AWS VPC Block Public Access"
  type        = bool
  default     = true
}