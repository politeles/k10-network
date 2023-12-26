variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "env_name" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "Cluster name"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnets" {
  description = "List of CIDR blocks for subnets"
  type        = list(string)
}

variable "private_subnets" {
  description = "List of CIDR blocks for subnets"
  type        = list(string)
}