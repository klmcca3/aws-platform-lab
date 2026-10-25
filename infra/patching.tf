# Patch Manager for the app instances.
#   1. Daily compliance SCAN (reports missing patches, changes nothing).
#   2. Weekly maintenance window that INSTALLS patches and reboots if needed.
# Uses AWS's default Amazon Linux 2023 patch baseline (security and bugfix updates).
# Instances reach the Amazon Linux repos and patch data through the S3 gateway endpoint.

resource "aws_ssm_association" "patch_scan" {
  name             = "AWS-RunPatchBaseline"
  association_name = "lab-patch-scan"

  schedule_expression = "rate(1 day)"

  parameters = {
    Operation = "Scan"
  }

  targets {
    key    = "tag:Project"
    values = ["aws-platform-lab"]
  }
}

resource "aws_ssm_maintenance_window" "patching" {
  name              = "lab-weekly-patching"
  schedule          = "cron(0 4 ? * SUN *)" # Sundays 04:00 UTC
  schedule_timezone = "America/Los_Angeles"
  duration          = 2 # hours
  cutoff            = 1 # stop starting new tasks 1 hour before the window closes
}

resource "aws_ssm_maintenance_window_target" "app" {
  window_id     = aws_ssm_maintenance_window.patching.id
  name          = "lab-app-instances"
  resource_type = "INSTANCE"

  targets {
    key    = "tag:Project"
    values = ["aws-platform-lab"]
  }
}

resource "aws_ssm_maintenance_window_task" "install_patches" {
  window_id       = aws_ssm_maintenance_window.patching.id
  name            = "install-patches"
  task_type       = "RUN_COMMAND"
  task_arn        = "AWS-RunPatchBaseline"
  priority        = 1
  max_concurrency = "1" # one instance at a time, so the app stays up
  max_errors      = "1"

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.app.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      parameter {
        name   = "Operation"
        values = ["Install"]
      }
      parameter {
        name   = "RebootOption"
        values = ["RebootIfNeeded"]
      }
    }
  }
}
