# VPC with public and private subnets across two availability zones.
#
#   10.0.0.0/16  VPC
#   10.0.0.0/24  public-a     10.0.1.0/24  public-b     (load balancer)
#   10.0.10.0/24 private-a    10.0.11.0/24 private-b    (app and database)

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"]
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true # both required for VPC interface endpoints later
  enable_dns_hostnames = true

  tags = { Name = "lab-vpc" }
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.lab.id
  cidr_block        = local.public_subnets[count.index]
  availability_zone = local.azs[count.index]

  # Nothing gets a public IP automatically; only the load balancer is public.
  map_public_ip_on_launch = false

  tags = { Name = "lab-public-${local.azs[count.index]}", Tier = "public" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.lab.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]

  tags = { Name = "lab-private-${local.azs[count.index]}", Tier = "private" }
}

# A subnet is "public" only because its route table points to an internet gateway.
resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "lab-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = { Name = "lab-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table: local VPC traffic only. No NAT Gateway (cost), so no internet route.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "lab-private-rt" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

output "vpc_id" {
  value = aws_vpc.lab.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

## private_subnet_ids = [
#  "subnet-0deacb1d0231fa3cf",
#  "subnet-0a3678cff3b7d4320",
#]
#public_subnet_ids = [
#  "subnet-0c313798f1ebb4f34",
#  "subnet-0b369b5022c4ebb63",
#]
#vpc_id = "vpc-07f802ec00650e925"##