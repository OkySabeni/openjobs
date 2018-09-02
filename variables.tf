variable "region" {
  description = "Region that the instances will be created"
}

// environment specific variables

variable "production_database_name" {
  description = "the database name for production"
}

variable "production_database_username" {
  description = "the database username for production"
}

variable "production_database_password" {
  description = "the database password for production"
}

variable "production_secret_key_base" {
  description = "the rails secret key for production"
}

variable "domain" {
  default = "the domain of your application"
}
