# VPC endpoints: private paths to AWS services, replacing a NAT Gateway.
#
#   S3 (gateway endpoint): free. Adds an S3 route to the private route table.
#   Systems Manager + Secrets Manager (4 interface endpoints): billed hourly per endpoint per AZ.
#     Needed so private instances with no internet can use Session Manager and Patch Manager.

# ---------- S3 gateway endpoint ----------
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.lab.id
  service_name      = "com.amazonaws.us-east-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = { Name = "lab-s3-endpoint" }
}

# ---------- Systems Manager interface endpoints ----------
locals {
  ssm_services = ["ssm", "ssmmessages", "ec2messages", "secretsmanager"] # secretsmanager: app reads the DB password
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = toset(local.ssm_services)

  vpc_id              = aws_vpc.lab.id
  service_name        = "com.amazonaws.us-east-2.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true # instances use the normal service names; DNS resolves them privately

  tags = { Name = "lab-${each.key}-endpoint" }
}

output "s3_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "ssm_endpoint_ids" {
  value = { for k, v in aws_vpc_endpoint.ssm : k => v.id }
}
