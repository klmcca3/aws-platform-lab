# GuardDuty: threat detection from CloudTrail, VPC Flow Logs, and DNS activity.
resource "aws_guardduty_detector" "lab" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# Security Hub: one place for findings and a compliance score.
resource "aws_securityhub_account" "lab" {
  enable_default_standards  = false # subscribe to exactly the standard we want, below
  control_finding_generator = "SECURITY_CONTROL"
  auto_enable_controls      = true

  depends_on = [aws_config_configuration_recorder_status.lab]
}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${local.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.lab]
}

# GuardDuty findings flow into Security Hub automatically: AWS service integrations
# are enabled by default when Security Hub is turned on.

output "guardduty_detector_id" {
  value = aws_guardduty_detector.lab.id
}
