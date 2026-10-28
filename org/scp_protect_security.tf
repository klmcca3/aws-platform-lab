# SCP: no one in the Workloads OU can switch off the security services,
# even with full admin rights. Blocks the "defense evasion" step attackers use
# to cover their tracks (like deleting the CloudTrail trail).
#
# Exception: OrganizationAccountAccessRole, the role Terraform uses to manage
# security/. In production this would be a tightly controlled break-glass role.

resource "aws_organizations_policy" "protect_security" {
  name        = "protect-security-services"
  description = "Deny disabling CloudTrail, Config, GuardDuty, and Security Hub"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ProtectSecurityServices"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail",
          "cloudtrail:PutEventSelectors",
          "config:DeleteConfigurationRecorder",
          "config:StopConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "guardduty:DeleteDetector",
          "guardduty:UpdateDetector",
          "guardduty:DisassociateFromMasterAccount",
          "securityhub:DisableSecurityHub",
          "securityhub:BatchDisableStandards",
          "s3:PutAccountPublicAccessBlock",
          "ec2:DisableEbsEncryptionByDefault"
        ]
        Resource = "*"
        Condition = {
          ArnNotLike = {
            "aws:PrincipalArn" = "arn:aws:iam::*:role/OrganizationAccountAccessRole"
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "protect_security_workloads" {
  policy_id = aws_organizations_policy.protect_security.id
  target_id = aws_organizations_organizational_unit.workloads.id
}
