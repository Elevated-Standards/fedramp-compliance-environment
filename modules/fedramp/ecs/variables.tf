variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for ECS instances"
  type        = list(string)
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "fedramp-ecs"
}

variable "ecs_instance_role_name" {
  description = "Name of the IAM role for ECS instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for ECS container instances"
  type        = string
  default     = "m5.large"
}

variable "instance_group_desired_size" {
  description = "Desired number of instances in the ECS cluster"
  type        = number
  default     = 3
}

variable "instance_group_min_size" {
  description = "Minimum number of instances in the ECS cluster"
  type        = number
  default     = 2
}

variable "instance_group_max_size" {
  description = "Maximum number of instances in the ECS cluster"
  type        = number
  default     = 5
}

variable "ecs_ami_id" {
  description = "AMI ID for ECS instances (leave empty to use latest ECS-optimized AMI)"
  type        = string
  default     = ""
}

variable "ebs_kms_key_arn" {
  description = "ARN of the KMS key for EBS volume encryption"
  type        = string
  default     = ""
}

variable "ecs_exec_kms_key_arn" {
  description = "ARN of the KMS key for ECS Exec encryption"
  type        = string
  default     = ""
}

variable "enable_ssh_access" {
  description = "Enable SSH access to container instances"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "Name of EC2 key pair for SSH access"
  type        = string
  default     = ""
}