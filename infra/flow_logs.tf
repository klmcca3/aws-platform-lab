# VPC Flow Logs: records accepted and rejected network traffic to CloudWatch Logs.

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/lab/vpc-flow-logs"
  retention_in_days = 7 # keeps storage cost low; logs older than a week are deleted
}

# Role the Flow Logs service assumes to write into CloudWatch Logs.
data "aws_iam_policy_document" "flow_logs_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
    # Prevents another account's flow logs from using this role (confused deputy protection).
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "lab-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.flow_logs_trust.json
}

# Least privilege: write only to this one log group.
data "aws_iam_policy_document" "flow_logs_write" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = ["${aws_cloudwatch_log_group.flow_logs.arn}:*"]
  }
}

resource "aws_iam_role_policy" "flow_logs_write" {
  name   = "write-flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_write.json
}

resource "aws_flow_log" "vpc" {
  vpc_id               = aws_vpc.lab.id
  traffic_type         = "ALL" # both ACCEPT and REJECT records
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn

  max_aggregation_interval = 60 # write records every minute instead of every 10

  tags = { Name = "lab-vpc-flow-log" }
}


/*

Outputs:

private_subnet_ids = [
  "subnet-0deacb1d0231fa3cf",
  "subnet-0a3678cff3b7d4320",
]
public_subnet_ids = [
  "subnet-0c313798f1ebb4f34",
  "subnet-0b369b5022c4ebb63",
]
s3_endpoint_id = "vpce-0196438ef13d4f6a8"
ssm_endpoint_ids = {
  "ec2messages" = "vpce-0d62c285265c580a4"
  "ssm" = "vpce-0e4b9690e5dd6b338"
  "ssmmessages" = "vpce-051dcc7a4c534a69d"
}
vpc_id = "vpc-07f802ec00650e925"

 */