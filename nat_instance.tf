data "aws_ami" "nat_instance" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-vpc-nat*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

resource "aws_eip" "nat_instance" {
  count = local.enable_nat_instance

  vpc = true
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}nat-instance"
    Type = "public"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "nat_instance" {
  count = local.enable_nat_instance

  name        = "${local.name_prefix}nat-instance"
  description = "Security Group for NAT Instance"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow ingress traffic from the VPC CIDR block"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    description      = "Allow all egress traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}nat-instance"
  })
}

resource "aws_instance" "nat_instance" {
  count = local.enable_nat_instance

  ami                     = data.aws_ami.nat_instance.id
  instance_type           = "t3.nano"
  subnet_id               = aws_subnet.this["public-0"].id
  vpc_security_group_ids  = [aws_security_group.nat_instance[0].id]
  source_dest_check       = false
  monitoring              = true
  disable_api_termination = true

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}nat-instance"
  })

  root_block_device {
    encrypted = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eip_association" "nat_instance" {
  count = local.enable_nat_instance

  instance_id   = aws_instance.nat_instance[0].id
  allocation_id = aws_eip.nat_instance[0].id
}
