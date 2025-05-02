output "ecs_instance_role_arn" {
  description = "ARN of the ECS instance IAM role"
  value       = aws_iam_role.ecs_instance_role.arn
}

output "ecs_instance_role_name" {
  description = "Name of the ECS instance IAM role"
  value       = aws_iam_role.ecs_instance_role.name
}

output "ecs_service_role_arn" {
  description = "ARN of the ECS service IAM role"
  value       = aws_iam_role.ecs_service_role.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task IAM role"
  value       = aws_iam_role.ecs_task_role.arn
}