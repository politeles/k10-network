# modules/vpc/main.tf
provider "aws" {
  region = var.aws_region
}


locals {
  vpc_name     = "${var.env_name} ${var.vpc_name}"
  cluster_name = "${var.cluster_name}-${var.env_name}"
}

#define the vpc
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name                                          = var.vpc_name,
    "kubernetes.io/cluster/${local.cluster_name}" = "shared",
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}


# We will define 4 subnets, 2 public and 2 private
resource "aws_subnet" "private-subnet-1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr_block-1
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags = {
    Name                                          = "${var.vpc_name}-private-subnet-1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

resource "aws_subnet" "private-subnet-2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidr_block-2
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false
  tags = {
    Name                                          = "${var.vpc_name}-private-subnet-2"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

resource "aws_subnet" "public-subnet-1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_block-1
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = false
  tags = {
    Name                                          = "${var.vpc_name}-public-subnet-1"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }
}

resource "aws_subnet" "public-subnet-2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_block-2
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = false
  tags = {
    Name                                          = "${var.vpc_name}-public-subnet-2"
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }
}

# internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.vpc_name}-igw"
  }
}

resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    "Name" = "${local.vpc_name}-public-route"
  }
}

resource "aws_route_table_association" "public-1-association" {
  subnet_id      = aws_subnet.public-subnet-1.id
  route_table_id = aws_route_table.public-route.id
}

resource "aws_route_table_association" "public-2-association" {
  subnet_id      = aws_subnet.public-subnet-2.id
  route_table_id = aws_route_table.public-route.id
}

# Define a default route table for the private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.vpc_name}-private Subnet route table"
  }
}


# elastic ip creation
resource "aws_eip" "nat-1" {
  tags = {
    "Name" = "${local.vpc_name}-NAT-1"
  }
}

resource "aws_eip" "nat-2" {
  tags = {
    "Name" = "${local.vpc_name}-NAT-2"
  }
}

resource "aws_nat_gateway" "nat-gw-1" {
  allocation_id = aws_eip.nat-1.id
  subnet_id     = aws_subnet.public-subnet-1.id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    "Name" = "${local.vpc_name}-NAT-gw-1"
  }
}

resource "aws_nat_gateway" "nat-gw-2" {
  allocation_id = aws_eip.nat-1.id
  subnet_id     = aws_subnet.public-subnet-2.id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    "Name" = "${local.vpc_name}-NAT-gw-b"
  }
}

resource "aws_route_table" "private-route-1" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw-1.id
  }

  tags = {
    "Name" = "${local.vpc_name}-private-route-1"
  }
}

resource "aws_route_table" "private-route-2" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw-2.id
  }

  tags = {
    "Name" = "${local.vpc_name}-private-route-2"
  }
}

resource "aws_route_table_association" "private-1-association" {
  subnet_id      = aws_subnet.private-subnet-1.id
  route_table_id = aws_route_table.private-route-1.id
}

resource "aws_route_table_association" "private-2-association" {
  subnet_id      = aws_subnet.private-subnet-2.id
  route_table_id = aws_route_table.private-route-2.id
}

# Create a Route 53 zone for DNS support inside the VPC
resource "aws_route53_zone" "private-zone" {
  # AWS requires a lowercase name. 
  #name = "lower(${var.env_name}.${var.vpc_name}.com)"
  name = "${var.env_name}.${var.vpc_name}.com"
  #name = "testing.com"
  force_destroy = true

  vpc {
    vpc_id = aws_vpc.main.id
  }
}