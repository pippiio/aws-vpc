output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "The ARN of the VPC."
  value       = aws_vpc.this.arn
}

output "vpc_cidr" {
  description = "The VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "vpc_flow_logs_loggroup" {
  description = "The VPC FlowLogs log group in CloudWatch."
  value       = local.config.flowlogs_retention_in_days < 1 ? null : aws_cloudwatch_log_group.this[0].arn
}

output "public_subnet" {
  value = [for k, v in local.subnet : aws_subnet.this[k].id if v.type == "public"]
}

output "private_subnet" {
  value = [for k, v in local.subnet : aws_subnet.this[k].id if v.type == "private"]
}

output "bastion_public_ip" {
  value = local.enable_bastion > 0 ? aws_eip_association.bastion[0].public_ip : null
}

output "bastion_sg" {
  value = local.enable_bastion > 0 ? aws_security_group.bastion[0].id : null
}

output "kms_arn" {
  value = aws_kms_key.this.arn
}

output "kms_alias" {
  value = aws_kms_alias.this.name
}
