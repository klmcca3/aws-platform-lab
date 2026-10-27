# Day 5: account-wide security services for the workloads account.
# Keep this folder up for the rest of the week. Do NOT destroy it nightly:
# Security Hub restarts its checks and Config records every rebuild, which adds cost.

terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "keith-mccarthy-tf-state-lab"
    key          = "security/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"

  assume_role {
    role_arn = "arn:aws:iam::482889161126:role/OrganizationAccountAccessRole"
  }

  default_tags {
    tags = {
      Project     = "aws-platform-lab"
      Owner       = "keith"
      Environment = "lab"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}
