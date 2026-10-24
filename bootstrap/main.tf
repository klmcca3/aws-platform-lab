# Step 1: creates the S3 bucket that will hold Terraform state.
# Run once with local state: terraform init && terraform apply

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# Bucket names are global, so this must be unique to you.
resource "aws_s3_bucket" "tf_state" {
  bucket = "keith-mccarthy-tf-state-lab"

  # Prevents an accidental `terraform destroy` from deleting your state.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Project     = "aws-platform-lab"
    Owner       = "keith"
    Environment = "lab"
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
