# Account-level security settings. These fix common Security Hub CSPM failures
# (AWS Foundational Security Best Practices) that apply to the whole account.

# S3.1: block public access for EVERY bucket in the account, current and future.
# Overrides any bucket that tries to turn its own protection off.
resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# EC2.7: every new EBS volume in this region is encrypted automatically.
resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

# IAM.7: strong password policy for any IAM user with a console password.
# (The workloads account has no IAM users today; this protects against future ones.)
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_uppercase_characters   = true
  require_lowercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 24
  max_password_age               = 90
}
