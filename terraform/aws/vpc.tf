# =============================================================================
# VPC — Networking Foundation
#
#  Public subnets  → monitor server, Linux workers, Windows worker
#  Private subnets → EKS nodes (no direct internet exposure)
#
#  Internet Gateway → public subnets
#  NAT Gateway      → private subnets (EKS nodes can pull images / updates)
# =============================================================================

# ─── VPC ─────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "monitoring-vpc-${var.environment}" }
}

# ─── Public Subnets ───────────────────────────────────────────────────────────

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                     = "monitoring-public-${count.index + 1}-${var.environment}"
    "kubernetes.io/role/elb" = "1"  # Required for EKS load balancers
  }
}

# ─── Private Subnets ──────────────────────────────────────────────────────────

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                              = "monitoring-private-${count.index + 1}-${var.environment}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# ─── Internet Gateway ─────────────────────────────────────────────────────────

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "monitoring-igw-${var.environment}" }
}

# ─── Elastic IP for NAT Gateway ───────────────────────────────────────────────

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "monitoring-nat-eip-${var.environment}" }
}

# ─── NAT Gateway (in first public subnet) ────────────────────────────────────

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "monitoring-nat-${var.environment}" }

  depends_on = [aws_internet_gateway.main]
}

# ─── Route Tables ─────────────────────────────────────────────────────────────

# Public: route to Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "monitoring-public-rt-${var.environment}" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private: route to NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = { Name = "monitoring-private-rt-${var.environment}" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
