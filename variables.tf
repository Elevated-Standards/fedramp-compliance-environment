variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to deploy resources"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "state_bucket_name" {
  description = "S3 bucket to store OpenTofu state"
  type        = string
  default     = "fedramp-terraform-state"
}

variable "state_lock_table" {
  description = "DynamoDB table for state locking"
  type        = string
  default     = "fedramp-terraform-locks"
}

# ECS Cluster Configuration
variable "ecs_cluster_name" {
  description = "Name for the ECS cluster"
  type        = string
  default     = "fedramp-ecs-cluster"
}

variable "instance_type" {
  description = "EC2 instance type for ECS container instances"
  type        = string
  default     = "m5.large"
}

variable "instance_group_desired_size" {
  description = "Desired size for ECS instance group"
  type        = number
  default     = 3
}

variable "instance_group_min_size" {
  description = "Minimum size for ECS instance group"
  type        = number
  default     = 2
}

variable "instance_group_max_size" {
  description = "Maximum size for ECS instance group"
  type        = number
  default     = 5
}