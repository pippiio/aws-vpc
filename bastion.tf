data "aws_ami" "bastion" {
  most_recent = true
  owners      = ["amazon"]
  name_regex  = "al2023-ami-2023*"

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_ip_ranges" "this" {
  regions  = [local.region_name]
  services = ["ec2_instance_connect"]
}

resource "aws_security_group" "bastion" {
  count = local.enable_bastion

  description = "Enable SSH access to the bastion host from external via SSH port"
  name        = "${local.name_prefix}bastion"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "Allow ingress SSH from ec2 instance connect and trusted ips."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = setunion(var.bastion.trusted_ip_cidrs, data.aws_ip_ranges.this.cidr_blocks)
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
    Name = "${local.name_prefix}bastion"
  })
}

resource "aws_security_group" "bastion_ssh" {
  count = local.enable_bastion

  description = "Enable SSH access from the bastion host."
  name        = "${local.name_prefix}bastion-ssh"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "Allow ingress SSH from bastion host."
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion[0].id]
  }

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}bastion-ssh"
  })
}

data "aws_iam_policy_document" "bastion_inline_policy" {
  count = local.enable_bastion

  statement {
    actions = ["ec2:AssociateAddress"]
    resources = [
      "arn:aws:ec2:${local.region_name}:${local.account_id}:instance/*",
      "arn:aws:ec2:${local.region_name}:${local.account_id}:elastic-ip/${aws_eip.bastion[0].allocation_id}",
    ]
  }
}

resource "aws_iam_role" "bastion" {
  count = local.enable_bastion

  name               = "${local.name_prefix}bastion-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  inline_policy {
    name   = "ec2_basic_vpc_policy"
    policy = data.aws_iam_policy_document.ec2.json
  }

  inline_policy {
    name   = "bastion_inline_policy"
    policy = data.aws_iam_policy_document.bastion_inline_policy[0].json
  }
}

resource "aws_iam_instance_profile" "bastion" {
  count = local.enable_bastion

  name = "${local.name_prefix}bastion-profile"
  role = aws_iam_role.bastion[0].name
}

resource "aws_eip" "bastion" {
  count = local.enable_bastion

  vpc = true
  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}bastion"
    Type = "public"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "bastion" {
  count = local.enable_bastion

  name_prefix                 = "${local.name_prefix}bastion"
  image_id                    = data.aws_ami.bastion.id
  instance_type               = "t3.nano"
  iam_instance_profile        = aws_iam_instance_profile.bastion[0].id
  associate_public_ip_address = true
  enable_monitoring           = true
  security_groups = setunion([
    aws_security_group.bastion[0].id],
    var.bastion.bastion_security_groups,
  )

  user_data = templatefile("${path.module}/userdata/bastion.sh", {
    ssh_keys   = var.bastion.trusted_ssh_public_keys
    aws_region = local.region_name
    eip        = aws_eip.bastion[0].allocation_id
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

resource "aws_autoscaling_group" "bastion" {
  count = local.enable_bastion

  desired_capacity          = 1
  max_size                  = 1
  min_size                  = 1
  vpc_zone_identifier       = [aws_subnet.this["public-0"].id]
  launch_configuration      = aws_launch_configuration.bastion[0].id
  health_check_type         = "EC2"
  health_check_grace_period = 300
  force_delete              = true
  wait_for_capacity_timeout = "0"
  max_instance_lifetime     = 60 * 60 * 24 * 4

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}bastion-instance"
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
