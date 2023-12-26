# modules/vpc/main.tf
provider "aws" {
  region = var.aws_region
}

locals {
  vpc_name     = "${var.env_name} ${var.vpc_name}"
  cluster_name = "${var.cluster_name}-${var.env_name}"
}

# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = var.vpc_name

  cidr = var.vpc_cidr
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  private_subnets = slice(var.private_subnets, 0, 2)
  public_subnets  = slice(var.public_subnets, 0, 2)

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
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