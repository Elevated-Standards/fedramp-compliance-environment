output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

output "ecs_capacity_provider_name" {
  description = "Name of the ECS capacity provider"
  value       = module.ecs.capacity_provider_name
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = module.monitoring.guardduty_detector_id
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = module.monitoring.cloudtrail_arn
}

output "ecs_instance_role_arn" {
  description = "ARN of the ECS instance IAM role"
  value       = module.iam.ecs_instance_role_arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task IAM role"
  value       = module.iam.ecs_task_role_arn
}