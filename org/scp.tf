# Service control policy: deny all actions outside us-west-2 for accounts in the
# Workloads OU. Global services are exempted, because they run from us-east-1
# behind the scenes. Based on AWS's documented region-restriction example.
# SCPs never apply to the management account, only to member accounts.

resource "aws_organizations_policy" "region_restrict" {
  name        = "deny-outside-us-east-2"
  description = "Deny actions outside us-eest-2, except global services"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyOutsideApprovedRegion"
        Effect = "Deny"
        NotAction = [
          "a4b:*", "acm:*", "aws-marketplace-management:*", "aws-marketplace:*",
          "aws-portal:*", "budgets:*", "ce:*", "chime:*", "cloudfront:*",
          "config:*", "cur:*", "directconnect:*",
          "ec2:DescribeRegions", "ec2:DescribeTransitGateways", "ec2:DescribeVpnGateways",
          "fms:*", "globalaccelerator:*", "health:*", "iam:*", "importexport:*",
          "kms:*", "mobileanalytics:*", "networkmanager:*", "organizations:*",
          "pricing:*", "route53:*", "route53domains:*", "route53-recovery-cluster:*",
          "route53-recovery-control-config:*", "route53-recovery-readiness:*",
          "s3:GetAccountPublic*", "s3:ListAllMyBuckets", "s3:ListMultiRegionAccessPoints",
          "s3:PutAccountPublic*", "shield:*", "sts:*", "support:*",
          "trustedadvisor:*", "waf-regional:*", "waf:*", "wafv2:*", "wellarchitected:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = ["us-east-2"]
          }
        }
      }
    ]
  })

  tags = {
    Project     = "aws-platform-lab"
    Owner       = "keith"
    Environment = "lab"
  }
}

resource "aws_organizations_policy_attachment" "region_restrict_workloads" {
  policy_id = aws_organizations_policy.region_restrict.id
  target_id = aws_organizations_organizational_unit.workloads.id
}
