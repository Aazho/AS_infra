variable "project" {
  type        = string
  description = "Name of the project"
  default     = "iac"
}

variable "region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-3"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-\\d+$", var.region))
    error_message = "Region format is not valid."
  }
}

variable "environment" {
  type        = string
  description = "Name of the current environment"
  default     = "test"
  validation {
    condition     = contains(["dev", "test", "staging", "production"], lower(var.environment))
    error_message = "Wrong enrionment type. Choose between dev, test, staging and production"
  }
}


variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR"
  default     = "10.0.0.0/16"
  validation {
    condition     = can(regex("^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\/(3[0-2]|[12]?[0-9])$", var.vpc_cidr))
    error_message = "CIDR format is not valid."
  }
}