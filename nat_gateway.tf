resource "aws_eip" "nat_gw" {
  for_each = { for k, v in local.subnet : k => v if v.type == "public" && local.config.nat_mode == "ha_nat_gw" }

  vpc = true

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}natgw-ip-${each.value.no}"
    Type = "public"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = { for k, v in local.subnet : k => v
    if v.type == "public" && local.config.nat_mode == "ha_nat_gw"
  }

  allocation_id = aws_eip.nat_gw[each.key].id
  subnet_id     = aws_subnet.this[each.key].id

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}natgw-${each.value.no}"
  })

  depends_on = [aws_internet_gateway.this]
}
