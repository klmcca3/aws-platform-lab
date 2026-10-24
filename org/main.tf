# Creates the AWS Organization and a "workloads" member account.
# Run from your main (management) account. Do NOT destroy this nightly.

terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "keith-mccarthy-tf-state-lab" # same bucket as infra/
    key          = "org/terraform.tfstate"       # different key
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
}

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  # Turns on SCPs so you can attach one in the next step.
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_account" "workloads" {
  name      = "workloads"
  email     = "klmcca3+aws-workloads@gmail.com" # must be unused by any AWS account
  parent_id = aws_organizations_organizational_unit.workloads.id

  # Role you assume from the management account to administer this account.
  role_name = "OrganizationAccountAccessRole"

  # Closing accounts is slow and rate-limited, so never let Terraform do it by accident.
  close_on_deletion = false
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name]
  }

  tags = {
    Project     = "aws-platform-lab"
    Owner       = "keith"
    Environment = "lab"
  }
}

output "workloads_account_id" {
  value = aws_organizations_account.workloads.id
}
#workloads_account_id = "482889161126"