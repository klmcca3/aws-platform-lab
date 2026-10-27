# AWS Config: records resource configurations and checks them against rules.
# Security Hub's checks depend on Config, so this must be on first.

resource "aws_s3_bucket" "config" {
  bucket_prefix = "lab-config-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket                  = aws_s3_bucket.config.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  bucket = aws_s3_bucket.config.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Role that Config uses to read resource settings and deliver snapshots to the bucket.
data "aws_iam_policy_document" "config_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  name               = "lab-aws-config"
  assume_role_policy = data.aws_iam_policy_document.config_trust.json
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

data "aws_iam_policy_document" "config_delivery" {
  statement {
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.config.arn}/AWSLogs/${local.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
  statement {
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.config.arn]
  }
}

resource "aws_iam_role_policy" "config_delivery" {
  name   = "deliver-to-config-bucket"
  role   = aws_iam_role.config.id
  policy = data.aws_iam_policy_document.config_delivery.json
}

resource "aws_config_configuration_recorder" "lab" {
  name     = "lab-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true # IAM users, roles, and policies
  }
}

resource "aws_config_delivery_channel" "lab" {
  name           = "lab-delivery"
  s3_bucket_name = aws_s3_bucket.config.id

  depends_on = [aws_config_configuration_recorder.lab, aws_iam_role_policy.config_delivery]
}

resource "aws_config_configuration_recorder_status" "lab" {
  name       = aws_config_configuration_recorder.lab.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.lab]
}

# ---------- Managed rules ----------
# Each one maps to a duty statement item: encryption, least exposure, logging, identity.
locals {
  config_rules = {
    "s3-bucket-level-public-access-prohibited" = "S3_BUCKET_LEVEL_PUBLIC_ACCESS_PROHIBITED"
    "s3-bucket-public-read-prohibited"         = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
    "encrypted-volumes"                        = "ENCRYPTED_VOLUMES"
    "rds-storage-encrypted"                    = "RDS_STORAGE_ENCRYPTED"
    "ec2-imdsv2-check"                         = "EC2_IMDSV2_CHECK"
    "vpc-flow-logs-enabled"                    = "VPC_FLOW_LOGS_ENABLED"
    "cloudtrail-enabled"                       = "CLOUD_TRAIL_ENABLED"
    "root-account-mfa-enabled"                 = "ROOT_ACCOUNT_MFA_ENABLED"
  }
}

resource "aws_config_config_rule" "managed" {
  for_each = local.config_rules

  name = each.key
  source {
    owner             = "AWS"
    source_identifier = each.value
  }

  depends_on = [aws_config_configuration_recorder_status.lab]
}
