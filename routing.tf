locals {
  route = merge(
    {
      public = {
        gateway     = aws_internet_gateway.this.id
        destination = "0.0.0.0/0"
        type        = "gateway_id"
      }
    },
    { private = null },
    {
      for k, v in aws_nat_gateway.this : "nat_gw-${local.subnet[k].no}" => {
        gateway     = v.id
        destination = "0.0.0.0/0"
        type        = "nat_gateway_id"
      }
    },
    {
      for k, v in aws_instance.nat_instance : "nat-instance" => {
        gateway     = v.primary_network_interface_id
        destination = "0.0.0.0/0"
        type        = "network_interface_id"
      }
    }
  )
}

resource "aws_route_table" "this" {
  for_each = local.route

  vpc_id = aws_vpc.this.id
  tags = merge(local.default_tags, {
    "Name" = "${local.name_prefix}${each.key}-route-table"
  })
}

resource "aws_route" "this" {
  for_each = { for k, v in local.route : k => v if v != null }

  route_table_id       = aws_route_table.this[each.key].id
  gateway_id           = each.value.type == "gateway_id" ? each.value.gateway : null
  nat_gateway_id       = each.value.type == "nat_gateway_id" ? each.value.gateway : null
  network_interface_id = each.value.type == "network_interface_id" ? each.value.gateway : null

  destination_cidr_block = each.value.destination
}

resource "aws_route_table_association" "public" {
  for_each = { for k, v in local.subnet : k => v if v.type == "public" }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this["public"].id
}

resource "aws_route_table_association" "isolated" {
  for_each = { for k, v in local.subnet : k => v if v.type == "private" && var.nat.mode == "none" }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this["private"].id
}

resource "aws_route_table_association" "nat_gw" {
  for_each = { for k, v in local.subnet : k => v if v.type == "private" && length(aws_nat_gateway.this) > 0 }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this["nat_gw-${each.value.no}"].id
}

resource "aws_route_table_association" "nat_instance" {
  for_each = { for k, v in local.subnet : k => v if v.type == "private" && length(aws_instance.nat_instance) > 0 }

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this["nat-instance"].id
}
