variable "environment" {
  description = "The environment"
}

variable "vpc_id" {
  description = "The VPC id"
}

variable "availability_zones" {
  type = "list"
  description = "the azs to use"
}

variable "security_group_ids" {
  type = "list"
  description = "The SGs to use"
}

variable "subnets_ids" {
  type = "list"
  description = "the private subnets to use"
}

variable "public_subnet_ids" {
  type = "list"
  description = "the private subnets to use"
}

variable "database_endpoint" {
  description = "the database endpoint"
}

variable "database_username" {
  description = "the database username"
}

variable "database_password" {
  description = "the database password"
}

variable "database_name" {
  description = "the database that the app will use"
}

variable "repository_name" {
  description = "the name of the repository"
}

variable "secret_key_base" {
  description = "the secret key base to use in the app"
}
