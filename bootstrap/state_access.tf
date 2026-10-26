# Lets the GitHub Actions roles in the workloads account read and write the infra/ state.
# Cross-account S3 access needs two halves: this bucket policy (management account)
# and an IAM permission on each role (workloads account, see iam/state_access.tf).

locals {
  workloads_account_id = "482889161126"
  github_role_arns = [
    "arn:aws:iam::${local.workloads_account_id}:role/github-actions-plan",
    "arn:aws:iam::${local.workloads_account_id}:role/github-actions-apply",
  ]
}

data "aws_iam_policy_document" "tf_state_access" {
  # List only the infra/ state prefix
  statement {
    sid       = "ListLabState"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tf_state.arn]
    principals {
      type        = "AWS"
      identifiers = local.github_role_arns
    }
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["lab/*"]
    }
  }

  # Read/write the state file and its lock file, nothing else in the bucket
  statement {
    sid       = "ReadWriteLabState"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tf_state.arn}/lab/*"]
    principals {
      type        = "AWS"
      identifiers = local.github_role_arns
    }
  }

  # Refuse any unencrypted (plain HTTP) access
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.tf_state.arn, "${aws_s3_bucket.tf_state.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.tf_state_access.json
}
