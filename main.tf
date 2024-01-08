locals {
  availability_zone_count = length(data.aws_availability_zones.available.names)
  vpc_cidr_bits           = tonumber(regex("/(\\d+)$", var.network.vpc_cidr)[0])
  pub_sub_cidr_bits       = var.network.public_subnet_bits - local.vpc_cidr_bits - [0, 1, 2, 2][local.availability_zone_count - 1]
  prv_sub_cidr_bits       = var.network.private_subnet_bits - local.vpc_cidr_bits - [0, 1, 2, 2][local.availability_zone_count - 1]

  cidrs = cidrsubnets(var.network.vpc_cidr, local.pub_sub_cidr_bits, local.prv_sub_cidr_bits)

  subnet = { for net in setunion(
    [for idx in range(local.availability_zone_count) : {
      type              = "public"
      no                = idx
      availability_zone = data.aws_availability_zones.available.names[idx]
      cidr              = cidrsubnet(local.cidrs[0], var.network.public_subnet_bits - local.vpc_cidr_bits - local.pub_sub_cidr_bits, idx)
    }],
    [for idx in range(local.availability_zone_count) : {
      type              = "private"
      no                = idx
      availability_zone = data.aws_availability_zones.available.names[idx]
      cidr              = cidrsubnet(local.cidrs[1], var.network.private_subnet_bits - local.vpc_cidr_bits - local.prv_sub_cidr_bits, idx)
    }]
  ) : "${net.type}-${net.no}" => net }

  enable_nat_instance = var.nat.mode == "single_nat_instance" ? 1 : 0
  enable_bastion      = length(var.bastion.trusted_ssh_public_keys) > 0 ? 1 : 0
}
