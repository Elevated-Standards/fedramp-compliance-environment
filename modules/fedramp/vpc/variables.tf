variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones to deploy resources"
  type        = list(string)
}