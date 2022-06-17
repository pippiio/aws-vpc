# pippiio aws-vpc
Terraform module for deploying AWS VPC resources

## Usage
```hcl
module "vpc" {
  source = "git::https://github.com/pippiio/aws-vpc.git"

  config = {
    vpc_cidr = "10.64.0.0/21"

    availability_zone_count = 3
    public_subnet_bits      = 26
    private_subnet_bits     = 24

    nat_mode = "ha_nat_gw"
  }
}
```

## Requirements
|Name     |Version |
|---------|--------|
|terraform|>= 1.2.0|
|aws      |~> 4.0  |


## Variables
### config:
|Name                      |Type       |Default            |Required|Description|
|--------------------------|-----------|-------------------|--------|-----------|
|vpc_cidr                  |string     |nil                |yes     |Cidr range for VPC|
|availability_zone_count   |number     |nil                |no      |Count of availability zones to use|
|public_subnet_bits        |number     |28                 |no      |Count of bits in the public subnet|
|private_subnet_bits       |number     |27                 |no      |Count of bits in the private subnet|
|nat_mode                  |string     |single_nat_instance|no      |Natgateway mode `single_nat_instance` or `ha_nat_gw`|
|flowlogs_retention_in_days|number     |-1                 |no      |Retention in days for flowlogs|
|bastion_security_groups   |set(string)|nil                |no      |Security group ID's for bastion|
|trusted_ip_cidrs          |set(string)|nil                |no      |IP Ciders to trust on bastion host|
|trusted_ssh_public_keys   |set(string)|nil                |no      |SSH keys to trust on bastion host|

### name_prefix:
|Type        |Default|Required|Description|
|------------|-------|--------|-----------|
|string      |pippi- |no      |A prefix that will be used on all named resources|

### default_tags:
|Type        |Default|Required|Description|
|------------|-------|--------|-----------|
|map(string) |nil    |no      |A map of default tags, that will be applied to all resources applicable|