resource "aws_security_group" "bastion" {
  count = local.enable_bastion

  description = "Bastion host security group"
  name        = "${local.name_prefix}bastion"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}bastion"
  })
}

resource "aws_iam_role" "bastion" {
  count = local.enable_bastion

  name               = "${local.name_prefix}bastion-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

resource "aws_iam_instance_profile" "bastion" {
  count = local.enable_bastion

  name = "${local.name_prefix}bastion-profile"
  role = aws_iam_role.bastion[0].name
}

resource "aws_launch_configuration" "bastion" {
  count = local.enable_bastion

  name_prefix                 = "${local.name_prefix}bastion"
  image_id                    = data.aws_ami.this.id
  instance_type               = local.bastion_instance_type
  iam_instance_profile        = aws_iam_instance_profile.bastion[0].id
  associate_public_ip_address = true
  enable_monitoring           = true
  user_data                   = file("${path.module}/userdata/bastion.sh")
  security_groups = setunion([
    aws_security_group.bastion[0].id],
    var.bastion.security_groups,
  )

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
  min_size                  = 0
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
