resource "aws_cloudwatch_log_group" "this" {
  count = var.config.flowlogs_retention_in_days < 1 ? 0 : 1

  name              = "${local.name_prefix}flow-log"
  retention_in_days = var.config.flowlogs_retention_in_days
  tags              = local.default_tags
}

resource "aws_iam_role" "this" {
  count = var.config.flowlogs_retention_in_days < 1 ? 0 : 1

  name = "${local.name_prefix}flow_log_role"
  path = "/"
  tags = local.default_tags

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Sid" : "AssumeVpcFlowLogs",
      "Effect" : "Allow",
      "Principal" : {
        "Service" : "vpc-flow-logs.amazonaws.com"
      },
      "Action" : "sts:AssumeRole"
    }]
  })

  inline_policy {
    name = "cloudwatch_log_permission"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        "Action" : [
          "logs:DescribeLogStreams",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow"
        Resource = ["${aws_cloudwatch_log_group.this[0].arn}:*"]
      }]
    })
  }
}

resource "aws_flow_log" "this" {
  count = var.config.flowlogs_retention_in_days < 1 ? 0 : 1

  iam_role_arn    = aws_iam_role.this[0].arn
  log_destination = aws_cloudwatch_log_group.this[0].arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.this.id

  tags = merge(local.default_tags, {
    Name = "${local.name_prefix}flowlog"
  })
}
