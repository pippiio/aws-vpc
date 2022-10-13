variable "config" {
  description = ""
  type = object({
    vpc_cidr = string

    availability_zone_count = optional(number)
    public_subnet_bits      = optional(number, 28)
    private_subnet_bits     = optional(number, 27)

    nat_mode                   = optional(string, "single_nat_instance")
    flowlogs_retention_in_days = optional(number, -1)

    bastion_security_groups = optional(set(string), [])
    trusted_ip_cidrs        = optional(set(string), [])
    trusted_ssh_public_keys = optional(set(string), [])
  })

  validation {
    error_message = "`config.availability_zone_count` is invalid. Must be a number between 1 and 3."
    condition     = try(var.config.availability_zone_count > 0 && var.config.availability_zone_count < 4, true)
  }

  validation {
    error_message = "`config.vpc_cidr` is invalid. Must be valid CIDR range between /16 and /28."
    condition     = can(cidrnetmask(var.config.vpc_cidr))
  }

  validation {
    condition     = try(contains(["ha_nat_gw", "single_nat_instance"], var.config.nat_mode), true)
    error_message = "`config.nat_mode` is invalid. Valid values are [ha_nat_gw single_nat_instance]."
  }
}
