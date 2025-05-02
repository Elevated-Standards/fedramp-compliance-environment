output "cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "instance_security_group_id" {
  description = "ID of the security group for container instances"
  value       = aws_security_group.ecs_instances.id
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "capacity_provider_name" {
  description = "Name of the ECS capacity provider"
  value       = aws_ecs_capacity_provider.ec2.name
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group for ECS instances"
  value       = aws_autoscaling_group.ecs_instances.name
}