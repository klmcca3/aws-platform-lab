# Day 2+: the lab infrastructure. This is the folder you destroy nightly.

terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "keith-mccarthy-tf-state-lab"
    key          = "lab/terraform.tfstate"
    region       = "us-east-2" # where the state bucket lives
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

# On your Mac: you sign in to the management account, so Terraform assumes the admin role
# in the workloads account. In GitHub Actions: the job is already signed in to the workloads
# account through OIDC, so the pipeline sets this variable to "" and the block is skipped.
variable "assume_role_arn" {
  type    = string
  default = "arn:aws:iam::482889161126:role/OrganizationAccountAccessRole"
}

# Builds everything in the workloads account.
provider "aws" {
  region = "us-east-2"

  dynamic "assume_role" {
    for_each = var.assume_role_arn == "" ? [] : [var.assume_role_arn]
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = {
      Project     = "aws-platform-lab"
      Owner       = "keith"
      Environment = "lab"
    }
  }
}
