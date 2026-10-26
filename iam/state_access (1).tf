# The workloads-account half of cross-account state access.
# The bucket policy in bootstrap/ allows these roles in; these policies let the roles reach out.
# (The apply role already has AdministratorAccess, so only the read-only plan role needs this.)
# terraform plan writes a short-lived lock file, so the plan role needs Put/Delete on that one key.

locals {
  state_bucket_arn = "arn:aws:s3:::keith-mccarthy-tf-state-lab"
}

data "aws_iam_policy_document" "plan_state_access" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [local.state_bucket_arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${local.state_bucket_arn}/lab/*"]
  }
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_bucket_arn}/lab/terraform.tfstate.tflock"]
  }
}

resource "aws_iam_role_policy" "plan_state_access" {
  name   = "terraform-state-access"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.plan_state_access.json
}
