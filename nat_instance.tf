resource "aws_security_group" "nat_instance" {
  count = local.enable_nat_instance

  name        = "${local.name_prefix}nat-instance"
  description = "Security Group for NAT Instance"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow ingress traffic from the private subnet CIDR block"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [for k, v in local.subnet : aws_subnet.this[k].cidr_block if v.type == "private"]
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

data "aws_iam_policy_document" "nat_instance_inline_policy" {
  count = local.enable_nat_instance

  statement {
    actions   = ["ec2:ModifyInstanceAttribute"]
    resources = ["arn:aws:ec2:${local.region_name}:${local.account_id}:instance/*"]
  }

  statement {
    actions = ["ec2:AssociateAddress"]
    resources = [
      "arn:aws:ec2:${local.region_name}:${local.account_id}:instance/*",
      "arn:aws:ec2:${local.region_name}:${local.account_id}:elastic-ip/${aws_eip.nat_instance[0].allocation_id}",
    ]
  }

  statement {
    actions = ["ec2:AttachNetworkInterface"]
    resources = [
      "arn:aws:ec2:${local.region_name}:${local.account_id}:instance/*",
      "arn:aws:ec2:eu-central-1:381492064914:network-interface/${aws_network_interface.nat_instance[0].id}"
    ]
  }
}

resource "aws_iam_role" "nat_instance" {
  count = local.enable_nat_instance

  name               = "${local.name_prefix}nat-instance-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  inline_policy {
    name   = "nat_instance_inline_policy"
    policy = data.aws_iam_policy_document.nat_instance_inline_policy[0].json
  }
}

resource "aws_iam_instance_profile" "nat_instance" {
  count = local.enable_nat_instance

  name = "${local.name_prefix}nat-instance-profile"
  role = aws_iam_role.nat_instance[0].name
}

resource "aws_network_interface" "nat_instance" {
  count = local.enable_nat_instance

  description       = "${local.name_prefix}nat-instance eni"
  subnet_id         = aws_subnet.this["public-0"].id
  security_groups   = [aws_security_group.nat_instance[0].id]
  source_dest_check = false

  tags = merge(local.default_tags, {
    "Name" = "${local.name_prefix}nat-instance"
  })
}

resource "aws_eip" "nat_instance" {
  count = local.enable_nat_instance

  domain = "vpc"
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}nat-instance"
    Type = "public"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_template" "nat_instance" {
  count = local.enable_nat_instance

  name_prefix   = "${local.name_prefix}nat-instance"
  image_id      = data.aws_ami.this.id
  instance_type = local.nat_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.nat_instance[0].name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.nat_instance[0].id]
    device_index                = 0
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(templatefile("${path.module}/userdata/nat-instance.sh", {
    aws_region = local.region_name
    eip        = aws_eip.nat_instance[0].allocation_id
    eni        = aws_network_interface.nat_instance[0].id
  }))

  block_device_mappings {
    device_name = data.aws_ami.this.root_device_name

    ebs {
      encrypted = true
    }
  }

  metadata_options {
    http_put_response_hop_limit = 1
    http_endpoint               = "enabled"
    http_tokens                 = "required"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "nat_instance" {
  count = local.enable_nat_instance

  desired_capacity          = 1
  max_size                  = 1
  min_size                  = 1
  vpc_zone_identifier       = [for k, v in local.subnet : aws_subnet.this[k].id if v.type == "public"]

  launch_template {
    id      = aws_launch_template.nat_instance[0].id
    version = "$Latest"
  }
  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
  wait_for_capacity_timeout = "0"
  max_instance_lifetime     = 60 * 60 * 24 * 35

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}nat-instance"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.default_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
