# AWS Backup for the lab database.
#
# Why this lives in security/ and not infra/: backups must outlive the resources they
# protect. infra/ is destroyed nightly; if the vault were there, the backups would be
# destroyed with the database.
#
# Why only RDS: the app servers are stateless and rebuilt from code on every launch,
# so there is nothing on them worth backing up. The database is the only state.

resource "aws_backup_vault" "lab" {
  name          = "lab-backup-vault"
  force_destroy = true # lab only: lets you delete the vault with recovery points at the end of the week
}

resource "aws_backup_plan" "lab" {
  name = "lab-daily-db-backup"

  rule {
    rule_name         = "daily"
    target_vault_name = aws_backup_vault.lab.name
    schedule          = "cron(0 19 * * ? *)" # 19:00 UTC (noon Pacific), when the lab is usually running
    start_window      = 60                   # minutes
    completion_window = 180

    lifecycle {
      delete_after = 7 # days
    }
  }
}

# Role AWS Backup uses to create backups and run restores.
data "aws_iam_policy_document" "backup_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "backup" {
  name               = "lab-aws-backup"
  assume_role_policy = data.aws_iam_policy_document.backup_trust.json
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Back up any RDS database tagged Project = aws-platform-lab.
resource "aws_backup_selection" "lab_db" {
  name         = "lab-rds"
  plan_id      = aws_backup_plan.lab.id
  iam_role_arn = aws_iam_role.backup.arn

  resources = ["arn:aws:rds:*:*:db:*"]

  condition {
    string_equals {
      key   = "aws:ResourceTag/Project"
      value = "aws-platform-lab"
    }
  }
}

output "backup_vault_name" {
  value = aws_backup_vault.lab.name
}

output "backup_role_arn" {
  value = aws_iam_role.backup.arn
}
