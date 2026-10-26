# RDS PostgreSQL in the private subnets. Encrypted, not public, reachable only from the app tier.
# The master password is created and stored in Secrets Manager by RDS itself
# (manage_master_user_password), so no password ever appears in code or state.

resource "aws_db_subnet_group" "app" {
  name       = "lab-db-subnets"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "app" {
  identifier     = "lab-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  db_name  = "labapp"
  username = "labadmin"

  manage_master_user_password = true # RDS generates the password and keeps it in Secrets Manager

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_subnet_group_name   = aws_db_subnet_group.app.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false # single AZ to keep lab cost down; production would use Multi-AZ

  backup_retention_period = 1 # AWS Backup takes over on Day 6
  skip_final_snapshot     = true
  deletion_protection     = false # lab only: lets the nightly destroy remove it
  apply_immediately       = true
}

output "db_endpoint" {
  value = aws_db_instance.app.address
}

output "db_secret_arn" {
  value = aws_db_instance.app.master_user_secret[0].secret_arn
}
