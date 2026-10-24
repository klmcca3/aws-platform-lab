# GitHub OIDC provider and two GitHub Actions roles in the WORKLOADS account.
# Keep this folder up all week; don't destroy it nightly (pipelines depend on it).

terraform {
  required_version = ">= 1.10"

  backend "s3" {
    bucket       = "keith-mccarthy-tf-state-lab" # same state bucket
    key          = "iam/terraform.tfstate"       # its own key
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

# Builds everything in the workloads account by assuming the admin role.
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

variable "github_owner" {
  description = "Your GitHub username"
  type        = string
  default     = "YOUR_GITHUB_USERNAME" # change this
}

variable "github_repo" {
  description = "Repo name"
  type        = string
  default     = "aws-platform-lab"
}

locals {
  repo = "${var.github_owner}/${var.github_repo}"
}

# Lets AWS trust short-lived tokens issued by GitHub Actions. No access keys stored in GitHub.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"] # AWS no longer checks this for GitHub, but older providers require a value
}

# ---------- Plan role: read-only, usable from pull requests ----------
data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo}:pull_request", "repo:${local.repo}:ref:refs/heads/*"]
    }
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "github-actions-plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# ---------- Apply role: can change infrastructure, main branch only ----------
data "aws_iam_policy_document" "apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_apply" {
  name                 = "github-actions-apply"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
}

# Lab trade-off: Terraform needs broad rights to build VPCs, EC2, RDS, and IAM
# instance roles. The guardrails are the main-branch-only trust policy above
# and the region SCP on the Workloads OU. In production you would narrow this.
resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.github_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "github_plan_role_arn" {
  value = aws_iam_role.github_plan.arn
}

output "github_apply_role_arn" {
  value = aws_iam_role.github_apply.arn
}
