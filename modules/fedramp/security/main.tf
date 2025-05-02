# ECS Cluster Security Group
resource "aws_security_group" "ecs_cluster" {
  name        = "${var.environment}-ecs-cluster-sg"
  description = "Security group for ECS cluster"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-ecs-cluster-sg"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# Allow inbound traffic from the cluster to itself
resource "aws_security_group_rule" "cluster_inbound" {
  security_group_id = aws_security_group.ecs_cluster.id
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  description       = "Allow internal cluster communication"
}

# Allow all outbound traffic
resource "aws_security_group_rule" "cluster_outbound" {
  security_group_id = aws_security_group.ecs_cluster.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound traffic"
}

# Service ALB Security Group (for externally exposed services)
resource "aws_security_group" "alb" {
  name        = "${var.environment}-ecs-alb-sg"
  description = "Security group for Load Balancer access to ECS Services"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.environment}-ecs-alb-sg"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# Only allow HTTPS inbound to ALB (FedRAMP requirement)
resource "aws_security_group_rule" "alb_https_inbound" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTPS inbound traffic"
}

# Allow outbound traffic from ALB to ECS cluster
resource "aws_security_group_rule" "alb_to_ecs_outbound" {
  security_group_id        = aws_security_group.alb.id
  type                     = "egress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_cluster.id
  description              = "Allow traffic to ECS services"
}

# Allow inbound traffic from ALB to ECS cluster
resource "aws_security_group_rule" "ecs_from_alb_inbound" {
  security_group_id        = aws_security_group.ecs_cluster.id
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow traffic from ALB to ECS tasks"
}

# KMS Key for encrypting ECS secrets (FedRAMP requirement)
resource "aws_kms_key" "ecs_secrets" {
  description             = "KMS key for encrypting ECS secrets"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Name        = "${var.environment}-ecs-secrets-kms"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "ecs_secrets" {
  name          = "alias/${var.environment}-ecs-secrets"
  target_key_id = aws_kms_key.ecs_secrets.key_id
}

# KMS Key for EBS volume encryption (FedRAMP requirement)
resource "aws_kms_key" "ebs" {
  description             = "KMS key for encrypting EBS volumes"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Name        = "${var.environment}-ebs-kms"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.environment}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

# AWS WAF Web ACL for ECS services (FedRAMP requirement)
resource "aws_wafv2_web_acl" "ecs_services" {
  name        = "${var.environment}-ecs-waf"
  description = "WAF Web ACL for ECS services"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # FedRAMP required protection - SQL injection
  rule {
    name     = "SQLi-Detection"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLi-Detection"
      sampled_requests_enabled   = true
    }
  }

  # FedRAMP required protection - Common vulnerabilities
  rule {
    name     = "Common-Vulnerabilities"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "Common-Vulnerabilities"
      sampled_requests_enabled   = true
    }
  }

  # Rate limiting (DDoS protection)
  rule {
    name     = "Rate-Limiting"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 1000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "Rate-Limiting"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.environment}-ecs-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name        = "${var.environment}-ecs-waf"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# AWS Config Rules for FedRAMP compliance
resource "aws_config_config_rule" "encrypted_volumes" {
  name = "${var.environment}-encrypted-volumes"

  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
}

resource "aws_config_config_rule" "root_account_mfa" {
  name = "${var.environment}-root-account-mfa-enabled"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }
}

resource "aws_config_config_rule" "s3_bucket_ssl" {
  name = "${var.environment}-s3-bucket-ssl-requests-only"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SSL_REQUESTS_ONLY"
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}