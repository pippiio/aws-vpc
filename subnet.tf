resource "aws_subnet" "this" {
  for_each = local.subnet

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.availability_zone

  map_public_ip_on_launch = each.value.type == "public"

  tags = merge(local.default_tags, merge(each.value.tags, {
    Name = "${local.name_prefix}${each.key}",
    Type = each.value.type,
  }))
}
