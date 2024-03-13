variable "network" {
  description = ""
  type = object({
    vpc_cidr = string

    availability_zone_count    = optional(number)
    public_subnet_bits         = optional(number, 28)
    private_subnet_bits        = optional(number, 27)
    flowlogs_retention_in_days = optional(number, -1)

    public_subnet_tags  = optional(map(string))
    private_subnet_tags = optional(map(string))
  })

  validation {
    condition     = try(var.network.availability_zone_count > 0 && var.network.availability_zone_count < 4, true)
    error_message = "`network.availability_zone_count` is invalid. Must be a number between 1 and 3."
  }

  validation {
    condition     = can(cidrnetmask(var.network.vpc_cidr))
    error_message = "`network.vpc_cidr` is invalid. Must be valid CIDR range between /16 and /28."
  }
}

variable "nat" {
  type = object({
    mode = optional(string, "single_nat_instance")
  })
  default = {}

  validation {
    condition     = try(contains(["none", "ha_nat_gw", "single_nat_instance"], var.nat.mode), true)
    error_message = "`var.nat.mode` is invalid. Valid values are [none ha_nat_gw single_nat_instance]."
  }
}

variable "bastion" {
  type = object({
    type                    = optional(string, "t4g.nano")
    security_groups         = optional(set(string), [])
    trusted_ip_cidrs        = optional(set(string), [])
    trusted_ssh_public_keys = optional(set(string), [])
  })
  default = {}
}
