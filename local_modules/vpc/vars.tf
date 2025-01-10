variable "name" {
  description = "(Requried) The name of the VPC"
  type        = string
}

variable "config" {
  description = "(Required) The configuration of the VPC"
  type        = any
}

variable "security_groups" {
  description = "(Required) The security groups to apply to the VPC"
}

variable "default_tags" {
  description = "(Optional) The default tags to apply to all resources"
  type        = map(string)
  default     = {}
}   

variable "tgws" {
  description = "(Required) TGWs information"
}