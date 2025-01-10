output "vpc_id" {
  description = "VPC IDs"
  value = try(aws_vpc.this[0].id, null)
}