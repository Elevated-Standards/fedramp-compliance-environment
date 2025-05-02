output "cluster_security_group_id" {
  description = "ID of the ECS cluster security group"
  value       = aws_security_group.ecs_cluster.id
}

output "alb_security_group_id" {
  description = "ID of the ALB security group for ECS services"
  value       = aws_security_group.alb.id
}

output "secrets_kms_key_id" {
  description = "ID of the KMS key for secrets encryption"
  value       = aws_kms_key.ecs_secrets.key_id
}

output "ebs_kms_key_id" {
  description = "ID of the KMS key for EBS volume encryption"
  value       = aws_kms_key.ebs.key_id
}

output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL for ECS services"
  value       = aws_wafv2_web_acl.ecs_services.arn
}