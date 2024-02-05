resource "aws_ssm_parameter" "bastion_ip" {
  count = local.enable_bastion

  name        = "/vpc/${local.name_prefix}vpc/bastion-ip"
  description = "The Bastion public IP"
  type        = "String"
  value       = aws_eip.bastion[0].public_ip
  tags        = local.default_tags
}
