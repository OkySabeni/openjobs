variable "environment" {
  description = "The environment"
}

variable "subnet_ids" {
  type = "list"
  description = "subnet ids"
}

// this is needed here because the networking portion has direct access to the aws_vpc
variable "vpc_id" {
  description = "vpc id"
}

variable "allocated_storage" {
  default = "20" // ??? how come others do not actually have values. do we use ENVs or something ???
  description = "the storage size in GB"
}

variable "instance_class" {
  description = "the instance type"
}

variable "multi_az" {
  default = false
  description = "multi-az allowed?"
}

variable "database_name" {
  description = "the database name"
}

variable "database_username" {
  description = "the database username"
}

variable "database_password" {
  description = "the database password"
}
