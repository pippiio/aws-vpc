data "aws_ami" "bastion" {
  count = local.enable_bastion

  most_recent = true
  owners      = ["amazon"]
  name_regex  = "^amzn2-ami-hvm.*-ebs"

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
    cidr_blocks = setunion(local.config.trusted_ip_cidrs, data.aws_ip_ranges.this.cidr_blocks)
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
    description = "Allow ingress SSH from bastion host."
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}bastion-ssh"
  })
}

data "aws_iam_policy_document" "bastion_assume_role" {
  count = local.enable_bastion

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "bastion_inline_policy" {
  count = local.enable_bastion

  statement {
    actions   = ["ec2-instance-connect:SendSSHPublicKey"]
    resources = ["arn:aws:ec2:${local.region_name}:${local.account_id}:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:osuser"
      values   = ["ec2-user"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/ec2-instance-connect"
      values   = ["bastion"]
    }
  }

  statement {
    actions   = ["ec2:DescribeInstances"]
    resources = ["arn:aws:ec2:${local.region_name}:${local.account_id}:instance/*"]
  }
}

resource "aws_iam_role" "bastion" {
  count = local.enable_bastion

  name               = "${local.name_prefix}bastion-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume_role[0].json

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

resource "aws_instance" "bastion" {
  count = local.enable_bastion

  ami                     = data.aws_ami.bastion[0].id
  instance_type           = "t3.nano"
  subnet_id               = aws_subnet.this["public-0"].id
  iam_instance_profile    = aws_iam_instance_profile.bastion[0].id
  disable_api_termination = true
  monitoring              = true
  user_data               = templatefile("${path.module}/userdata.sh", { ssh_keys = local.config.trusted_ssh_public_keys })

  vpc_security_group_ids = setunion([aws_security_group.bastion[0].id],
    local.config.bastion_security_groups
  )

  tags = merge(local.default_tags, {
    Name                 = "${local.name_prefix}bastion"
    ec2-instance-connect = "bastion"
    a                    = "b"
  })

  root_block_device {
    encrypted = true
  }

  # metadata_options {
  #   http_endpoint = "enabled"
  #   http_tokens   = "required"
  # }

  lifecycle {
    create_before_destroy = true
  }
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

resource "aws_eip_association" "bastion" {
  count = local.enable_bastion

  instance_id   = aws_instance.bastion[0].id
  allocation_id = aws_eip.bastion[0].id
}
