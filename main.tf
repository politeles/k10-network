# modules/vpc/main.tf
provider "aws" {
  region = var.aws_region
}

# For EKS cluster: 
# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  vpc_name     = "${var.env_name} ${var.vpc_name}"
  cluster_name = "${var.cluster_name}-${var.env_name}"
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
}

# this is a VPC for EKS cluster
# We define 2 public and 2 private subnets
# public subnets are tagged with the role of ELB
# private subnets are tagged with the role of internal ELB

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = var.vpc_name

  cidr = var.vpc_cidr
  azs  = local.azs
  private_subnets     = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]
  public_subnets      = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 4)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

