provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = "FedRAMP-Containers"
      ManagedBy   = "OpenTofu"
    }
  }
}

# Initialize OpenTofu backend for state management
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.6.0"
}

# Remote state backend configuration (uncomment when ready to use)
# If using OpenTofu Cloud, adjust accordingly
/*
terraform {
  backend "s3" {
    bucket         = var.state_bucket_name
    key            = "fedramp/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.state_lock_table
    encrypt        = true
  }
}
*/

# VPC Module
module "vpc" {
  source             = "./modules/fedramp/vpc"
  vpc_cidr           = var.vpc_cidr
  environment        = var.environment
  availability_zones = var.availability_zones
  # Remove EKS-specific configuration
}

# IAM Module
module "iam" {
  source      = "./modules/fedramp/iam"
  environment = var.environment
}

# Security Module
module "security" {
  source           = "./modules/fedramp/security"
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  # Remove EKS-specific configuration
}

# ECS (Container Service) Module
module "ecs" {
  source              = "./modules/fedramp/ecs"
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  ecs_instance_role_name = module.iam.ecs_instance_role_name
  cluster_name        = var.ecs_cluster_name
  instance_type       = var.instance_type
  instance_group_desired_size = var.instance_group_desired_size
  instance_group_min_size     = var.instance_group_min_size
  instance_group_max_size     = var.instance_group_max_size
  ebs_kms_key_arn     = module.security.ebs_kms_key_id
  ecs_exec_kms_key_arn = module.security.secrets_kms_key_id
  enable_ssh_access   = false # FedRAMP recommends using SSM instead of SSH
}

# Monitoring & Logging Module
module "monitoring" {
  source         = "./modules/fedramp/monitoring"
  environment    = var.environment
  vpc_id         = module.vpc.vpc_id
  ecs_cluster_id = module.ecs.cluster_id
}