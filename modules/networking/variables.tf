variable "vpc_cidr" {
  description = "the CIDR block of the vpc"
}

variable "public_subnets_cidr" {
  type = "list"
  description = "the CIDR block for the public subnet"
}

variable "private_subnets_cidr" {
  type = "list"
  description = "the CIDR block for the private subnet"
}

variable "environment" {
  description = "the environment"
}

variable "region" {
  description = "the region to launch the bastion host"
}

variable "availability_zones" {
  type = "list"
  description = "the az that the resources will be launched"
}

variable "key_name" {
  description = "the public key for the bastion host"
}
