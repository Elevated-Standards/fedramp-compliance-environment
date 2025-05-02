# CloudWatch Log Group for ECS cluster logs (FedRAMP requirement)
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/aws/ecs/${var.environment}/${var.ecs_cluster_id}"
  retention_in_days = 365  # FedRAMP requires logs to be retained for at least one year

  tags = {
    Name        = "${var.environment}-ecs-logs"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# Security Hub (FedRAMP requirement for continuous monitoring)
resource "aws_securityhub_account" "main" {}

# Enable Security Hub FedRAMP standard
resource "aws_securityhub_standards_subscription" "fedramp" {
  depends_on    = [aws_securityhub_account.main]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

# CloudTrail for API activity logging (FedRAMP requirement)
resource "aws_cloudtrail" "main" {
  name                          = "${var.environment}-fedramp-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  kms_key_id                    = aws_kms_key.cloudtrail.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
  }

  tags = {
    Name        = "${var.environment}-fedramp-trail"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# S3 bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.environment}-fedramp-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name        = "${var.environment}-cloudtrail-logs"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# S3 bucket for CloudTrail logs - block public access (FedRAMP requirement)
resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for CloudTrail
resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = "arn:aws:s3:::${aws_s3_bucket.cloudtrail_logs.id}"
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${aws_s3_bucket.cloudtrail_logs.id}/cloudtrail/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.cloudtrail_logs]
}

# KMS key for CloudTrail log encryption (FedRAMP requirement)
resource "aws_kms_key" "cloudtrail" {
  description             = "KMS key for CloudTrail log encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudTrail to encrypt logs"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-cloudtrail-kms"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# AWS Config for configuration monitoring (FedRAMP requirement)
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.environment}-config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.environment}-config-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_logs.id
  s3_key_prefix  = "config"

  snapshot_delivery_properties {
    delivery_frequency = "Six_Hours"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_configuration_recorder_status" "main" {
  name       = aws_config_configuration_recorder.main.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.main]
}

# S3 bucket for Config logs
resource "aws_s3_bucket" "config_logs" {
  bucket = "${var.environment}-fedramp-config-logs-${data.aws_caller_identity.current.account_id}"
  
  tags = {
    Name        = "${var.environment}-config-logs"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# S3 bucket for Config logs - block public access
resource "aws_s3_bucket_public_access_block" "config_logs" {
  bucket = aws_s3_bucket.config_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM role for AWS Config
resource "aws_iam_role" "config_role" {
  name = "${var.environment}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-config-role"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

# Amazon GuardDuty (FedRAMP requirement for threat detection)
resource "aws_guardduty_detector" "main" {
  enable = true

  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = {
    Name        = "${var.environment}-guardduty"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# ECS-specific monitoring configurations
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  alarm_name          = "${var.environment}-ecs-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ecs cpu utilization"
  
  dimensions = {
    ClusterName = var.ecs_cluster_id
  }
  
  alarm_actions = [aws_sns_topic.alerts.arn]
  
  tags = {
    Name        = "${var.environment}-ecs-cpu-alarm"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  alarm_name          = "${var.environment}-ecs-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ecs memory utilization"
  
  dimensions = {
    ClusterName = var.ecs_cluster_id
  }
  
  alarm_actions = [aws_sns_topic.alerts.arn]
  
  tags = {
    Name        = "${var.environment}-ecs-memory-alarm"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# SNS Topic for alarms (FedRAMP requires notifications for operational events)
resource "aws_sns_topic" "alerts" {
  name = "${var.environment}-fedramp-alerts"
  
  kms_master_key_id = aws_kms_key.sns.id
  
  tags = {
    Name        = "${var.environment}-fedramp-alerts"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# KMS Key for SNS Topic encryption
resource "aws_kms_key" "sns" {
  description             = "KMS key for SNS topic encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Name        = "${var.environment}-sns-kms"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# AWS Config Rule for ECS compliance
resource "aws_config_config_rule" "ecs_task_definition_user_for_host_mode_check" {
  name        = "ecs-task-definition-user-for-host-mode-check"
  description = "Checks if ECS task definitions with host networking mode have 'privileged' or 'user' container definitions"

  source {
    owner             = "AWS"
    source_identifier = "ECS_TASK_DEFINITION_USER_FOR_HOST_MODE_CHECK"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# Get current AWS region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}