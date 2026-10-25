# Security groups: each tier only accepts traffic from the tier in front of it.
#
#   Internet --80--> ALB --8080--> App --5432--> Database
#                                  App --443---> VPC endpoints (S3, Systems Manager)

locals {
  app_port = 8080 # Flask app
  db_port  = 5432 # PostgreSQL
}

# ---------- Load balancer: the only thing open to the internet ----------
resource "aws_security_group" "alb" {
  name        = "lab-alb-sg"
  description = "Load balancer: HTTP from the internet"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "lab-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from anywhere"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to app instances only"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = local.app_port
  to_port                      = local.app_port
}

# ---------- App tier: only reachable from the load balancer ----------
resource "aws_security_group" "app" {
  name        = "lab-app-sg"
  description = "App instances: traffic from the load balancer only"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "lab-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from the load balancer"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = local.app_port
  to_port                      = local.app_port
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL to the database"
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = local.db_port
  to_port                      = local.db_port
}

resource "aws_vpc_security_group_egress_rule" "app_to_endpoints" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTPS to VPC interface endpoints (Systems Manager)"
  referenced_security_group_id = aws_security_group.endpoints.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}

resource "aws_vpc_security_group_egress_rule" "app_to_s3" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to S3 through the gateway endpoint"
  prefix_list_id    = data.aws_prefix_list.s3.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

data "aws_prefix_list" "s3" {
  name = "com.amazonaws.us-east-2.s3"
}

# ---------- Database: only reachable from the app tier ----------
resource "aws_security_group" "db" {
  name        = "lab-db-sg"
  description = "Database: PostgreSQL from app instances only"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "lab-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from the app tier"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = local.db_port
  to_port                      = local.db_port
}
# No egress rules: the database never starts connections.

# ---------- VPC interface endpoints (created in the next step) ----------
resource "aws_security_group" "endpoints" {
  name        = "lab-endpoints-sg"
  description = "VPC interface endpoints: HTTPS from app instances"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "lab-endpoints-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "endpoints_from_app" {
  security_group_id            = aws_security_group.endpoints.id
  description                  = "HTTPS from the app tier"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
}
