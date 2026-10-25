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

# Builds everything in the workloads account.
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
