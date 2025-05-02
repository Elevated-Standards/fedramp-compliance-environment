variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster"
  type        = list(string)
}

variable "eks_cluster_role_arn" {
  description = "ARN of the IAM role for EKS cluster"
  type        = string
}

variable "eks_node_role_arn" {
  description = "ARN of the IAM role for EKS nodes"
  type        = string
}

variable "cluster_security_group_id" {
  description = "ID of the security group for EKS cluster"
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "fedramp-eks"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "eks_secrets_kms_key_arn" {
  description = "ARN of the KMS key for EKS secrets encryption"
  type        = string
  default     = ""
}

variable "eks_ebs_kms_key_arn" {
  description = "ARN of the KMS key for EKS EBS volume encryption"
  type        = string
  default     = ""
}

variable "node_group_instance_types" {
  description = "List of EC2 instance types for EKS node group"
  type        = list(string)
  default     = ["t3.medium", "t3.large"]
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in EKS node group"
  type        = number
  default     = 3
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in EKS node group"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in EKS node group"
  type        = number
  default     = 5
}

variable "enable_ssh_access" {
  description = "Enable SSH access to worker nodes"
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "Name of EC2 key pair for SSH access"
  type        = string
  default     = ""
}

variable "bastion_security_group_id" {
  description = "Security group ID for bastion host"
  type        = string
  default     = ""
}