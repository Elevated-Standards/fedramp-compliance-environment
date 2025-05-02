# ECS Cluster for running containerized applications
resource "aws_ecs_cluster" "main" {
  name = "${var.environment}-${var.cluster_name}"

  setting {
    name  = "containerInsights"
    value = "enabled"  # FedRAMP requires detailed monitoring
  }

  configuration {
    execute_command_configuration {
      kms_key_id = var.ecs_exec_kms_key_arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs_exec.name
      }
    }
  }

  tags = {
    Name        = "${var.environment}-${var.cluster_name}"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# CloudWatch Log Group for ECS Exec (for secure container access)
resource "aws_cloudwatch_log_group" "ecs_exec" {
  name              = "/aws/ecs/${var.environment}/exec-logs"
  retention_in_days = 365  # FedRAMP requires logs to be retained for at least one year

  tags = {
    Name        = "${var.environment}-ecs-exec-logs"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# ECS Capacity Providers (EC2 launch type)
resource "aws_ecs_capacity_provider" "ec2" {
  name = "${var.environment}-ec2-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs_instances.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      maximum_scaling_step_size = 10
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = {
    Name        = "${var.environment}-ec2-capacity-provider"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# Attach capacity provider to the ECS Cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ec2.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    base              = 1
    weight            = 100
  }
}

# Auto Scaling Group for ECS instances
resource "aws_autoscaling_group" "ecs_instances" {
  name                 = "${var.environment}-ecs-instances"
  vpc_zone_identifier  = var.subnet_ids
  min_size             = var.instance_group_min_size
  max_size             = var.instance_group_max_size
  desired_capacity     = var.instance_group_desired_size
  health_check_type    = "EC2"
  protect_from_scale_in = true

  launch_template {
    id      = aws_launch_template.ecs_instances.id
    version = aws_launch_template.ecs_instances.latest_version
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-ecs-instance"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Compliance"
    value               = "FedRAMP"
    propagate_at_launch = true
  }
}

# Launch template for ECS instances
resource "aws_launch_template" "ecs_instances" {
  name                   = "${var.environment}-ecs-instances"
  description            = "Launch template for ECS instances"
  update_default_version = true
  
  image_id      = var.ecs_ami_id != "" ? var.ecs_ami_id : data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type = var.instance_type
  key_name      = var.enable_ssh_access ? var.ssh_key_name : null

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  monitoring {
    enabled = true  # FedRAMP requires detailed monitoring
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ecs_instances.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 required for FedRAMP
    http_put_response_hop_limit = 1
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
    echo ECS_ENABLE_SPOT_INSTANCE_DRAINING=true >> /etc/ecs/ecs.config
    echo ECS_CONTAINER_INSTANCE_TAGS={"Name":"${var.environment}-ecs-instance","Environment":"${var.environment}"} >> /etc/ecs/ecs.config
    # Install CloudWatch agent
    yum install -y amazon-cloudwatch-agent
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:${aws_ssm_parameter.cloudwatch_agent_config.name}
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-ecs-instance"
      Environment = var.environment
      Compliance  = "FedRAMP"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.environment}-ecs-volume"
      Environment = var.environment
      Compliance  = "FedRAMP"
    }
  }
}

# SSM Parameter for CloudWatch Agent Configuration
resource "aws_ssm_parameter" "cloudwatch_agent_config" {
  name  = "/${var.environment}/ecs/cloudwatch-agent-config"
  type  = "String"
  value = jsonencode({
    logs = {
      logs_collected = {
        files = {
          collect_list = [
            {
              file_path = "/var/log/messages"
              log_group_name = "/aws/ecs/${var.environment}/system-logs"
              log_stream_name = "{instance_id}/messages"
            },
            {
              file_path = "/var/log/ecs/ecs-agent.log"
              log_group_name = "/aws/ecs/${var.environment}/agent-logs"
              log_stream_name = "{instance_id}/ecs-agent"
            },
            {
              file_path = "/var/log/audit/audit.log"
              log_group_name = "/aws/ecs/${var.environment}/audit-logs"
              log_stream_name = "{instance_id}/audit"
            }
          ]
        }
      }
    }
    metrics = {
      namespace = "ECS/ContainerInsights",
      metrics_collected = {
        mem = {
          measurement = [
            "mem_used_percent"
          ]
        },
        disk = {
          measurement = [
            "disk_used_percent"
          ],
          resources = [
            "/"
          ]
        }
      }
    }
  })

  tags = {
    Name        = "${var.environment}-cloudwatch-agent-config"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# Security Group for ECS instances
resource "aws_security_group" "ecs_instances" {
  name        = "${var.environment}-ecs-instances-sg"
  description = "Security group for ECS instances"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow outbound traffic"
  }

  tags = {
    Name        = "${var.environment}-ecs-instances-sg"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# Instance Profile for ECS instances
resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${var.environment}-ecs-instance-profile"
  role = var.ecs_instance_role_name
}

# Default ECS Task Execution Role if needed for tasks
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-ecs-task-execution-role"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Get latest ECS-optimized AMI from SSM Parameter Store
data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}