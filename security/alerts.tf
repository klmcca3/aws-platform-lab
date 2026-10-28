# Alert topic for CloudWatch alarms. It lives in security/ (kept up all week) rather
# than infra/ (destroyed nightly), so you confirm the email subscription only once.

variable "alert_email" {
  description = "Email address that receives alarm notifications"
  type        = string
}

# Not encrypted with the AWS-managed SNS key on purpose: CloudWatch alarms can't publish
# to a topic using that key. Production would use a customer-managed KMS key whose
# key policy allows CloudWatch.
resource "aws_sns_topic" "alerts" {
  name = "lab-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
