locals {
  config = defaults(var.config, {
    public_subnet_bits         = 28
    private_subnet_bits        = 27
    flowlogs_retention_in_days = -1
    nat_mode                   = "single_nat_instance"
  })

  availability_zone_count = length(data.aws_availability_zones.available.names)
  vpc_cidr_bits           = tonumber(regex("/(\\d+)$", local.config.vpc_cidr)[0])
  pub_sub_cidr_bits       = local.config.public_subnet_bits - local.vpc_cidr_bits - [0, 1, 2, 2][local.availability_zone_count - 1]
  prv_sub_cidr_bits       = local.config.private_subnet_bits - local.vpc_cidr_bits - [0, 1, 2, 2][local.availability_zone_count - 1]

  cidrs = cidrsubnets(local.config.vpc_cidr, local.pub_sub_cidr_bits, local.prv_sub_cidr_bits)

  subnet = { for net in setunion(
    [for idx in range(local.availability_zone_count) : {
      type              = "public"
      no                = idx
      availability_zone = data.aws_availability_zones.available.names[idx]
      cidr              = cidrsubnet(local.cidrs[0], local.config.public_subnet_bits - local.vpc_cidr_bits - local.pub_sub_cidr_bits, idx)
    }],
    [for idx in range(local.availability_zone_count) : {
      type              = "private"
      no                = idx
      availability_zone = data.aws_availability_zones.available.names[idx]
      cidr              = cidrsubnet(local.cidrs[1], local.config.private_subnet_bits - local.vpc_cidr_bits - local.prv_sub_cidr_bits, idx)
    }]
  ) : "${net.type}-${net.no}" => net }

  enable_bastion = local.config.trusted_ssh_public_keys != null ? 1 : 0
}
