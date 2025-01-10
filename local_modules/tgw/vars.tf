variable "name" {
  description = "(Requried) The name of the VPC"
  type        = string
}

variable "config" {
  description = "(Required) Configuration"
  type = any
}

variable "default_tags" {
  description = "(Optional) Default tags for all resources"
  type = map(string)
  default = {}
}
