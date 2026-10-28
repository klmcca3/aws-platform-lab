# Day 6: CloudWatch dashboard and alarms for the app tier and database.
# Alarms notify the lab-alerts SNS topic (created in security/).

data "aws_sns_topic" "alerts" {
  name = "lab-alerts"
}

locals {
  alb_dim = aws_lb.app.arn_suffix
  tg_dim  = aws_lb_target_group.app.arn_suffix
  asg_dim = aws_autoscaling_group.app.name
  db_dim  = aws_db_instance.app.identifier
  alarm_actions = [data.aws_sns_topic.alerts.arn]
}

# ---------- Dashboard ----------
resource "aws_cloudwatch_dashboard" "lab" {
  dashboard_name = "lab-platform"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Requests and errors (load balancer)"
          region = "us-east-2"
          stat   = "Sum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", local.alb_dim],
            [".", "HTTPCode_Target_5XX_Count", ".", "."],
            [".", "HTTPCode_ELB_5XX_Count", ".", "."]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Healthy vs unhealthy servers"
          region = "us-east-2"
          stat   = "Minimum"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", local.tg_dim, "LoadBalancer", local.alb_dim],
            [".", "UnHealthyHostCount", ".", ".", ".", ".", { stat = "Maximum" }]
          ]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 8, height = 6
        properties = {
          title  = "Response time (seconds)"
          region = "us-east-2"
          stat   = "p95"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alb_dim]
          ]
        }
      },
      {
        type = "metric", x = 8, y = 6, width = 8, height = 6
        properties = {
          title  = "App server CPU (%)"
          region = "us-east-2"
          stat   = "Average"
          period = 300
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", local.asg_dim]
          ]
        }
      },
      {
        type = "metric", x = 16, y = 6, width = 8, height = 6
        properties = {
          title  = "Database"
          region = "us-east-2"
          period = 300
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", local.db_dim, { stat = "Average" }],
            [".", "DatabaseConnections", ".", ".", { stat = "Maximum", yAxis = "right" }]
          ]
        }
      },
      {
        type = "alarm", x = 0, y = 12, width = 24, height = 4
        properties = {
          title = "Alarm status"
          alarms = [
            aws_cloudwatch_metric_alarm.no_healthy_hosts.arn,
            aws_cloudwatch_metric_alarm.unhealthy_hosts.arn,
            aws_cloudwatch_metric_alarm.target_5xx.arn,
            aws_cloudwatch_metric_alarm.elb_5xx.arn,
            aws_cloudwatch_metric_alarm.app_cpu.arn,
            aws_cloudwatch_metric_alarm.db_cpu.arn,
            aws_cloudwatch_metric_alarm.db_storage.arn
          ]
        }
      }
    ]
  })
}

# ---------- Alarms ----------
# Critical: the site is down (no server is passing health checks).
resource "aws_cloudwatch_metric_alarm" "no_healthy_hosts" {
  alarm_name          = "lab-no-healthy-hosts"
  alarm_description   = "CRITICAL: no app servers are healthy; the site is down."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  dimensions          = { TargetGroup = local.tg_dim, LoadBalancer = local.alb_dim }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching" # avoids false alerts while a fresh build is starting
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# Warning: at least one server is failing health checks.
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "lab-unhealthy-hosts"
  alarm_description   = "WARNING: one or more app servers are failing the /health check."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { TargetGroup = local.tg_dim, LoadBalancer = local.alb_dim }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# The app is returning errors (5xx from the servers).
resource "aws_cloudwatch_metric_alarm" "target_5xx" {
  alarm_name          = "lab-app-5xx-errors"
  alarm_description   = "App servers returned 5 or more 5xx errors in a minute."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = local.alb_dim }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# The load balancer itself is returning errors (often: no healthy servers to send traffic to).
resource "aws_cloudwatch_metric_alarm" "elb_5xx" {
  alarm_name          = "lab-alb-5xx-errors"
  alarm_description   = "Load balancer returned 5 or more 5xx errors in a minute (502/503: no healthy targets)."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  dimensions          = { LoadBalancer = local.alb_dim }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "app_cpu" {
  alarm_name          = "lab-app-high-cpu"
  alarm_description   = "App server CPU above 80% for 15 minutes."
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { AutoScalingGroupName = local.asg_dim }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "db_cpu" {
  alarm_name          = "lab-db-high-cpu"
  alarm_description   = "Database CPU above 80% for 15 minutes."
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = local.db_dim }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = 80
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "db_storage" {
  alarm_name          = "lab-db-low-storage"
  alarm_description   = "Database free storage below 2 GB."
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = local.db_dim }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "LessThanThreshold"
  threshold           = 2000000000
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

output "dashboard_url" {
  value = "https://us-east-2.console.aws.amazon.com/cloudwatch/home?region=us-east-2#dashboards/dashboard/lab-platform"
}
