# ECS Instance IAM Role (for EC2 container instances)
resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.environment}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name        = "${var.environment}-ecs-instance-role"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# Attach required policies for ECS instances
resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  role       = aws_iam_role.ecs_instance_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ecs_instance_role.name
}

# FedRAMP compliance requires CloudWatch logging
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.ecs_instance_role.name
}

# SSM access for instance management (FedRAMP requirement)
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ecs_instance_role.name
}

# ECS Service Role
resource "aws_iam_role" "ecs_service_role" {
  name = "${var.environment}-ecs-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-ecs-service-role"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# Attach the ECS service role policy
resource "aws_iam_role_policy_attachment" "ecs_service_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
  role       = aws_iam_role.ecs_service_role.name
}

# Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
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

# Attach the task execution role policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

# Task Role (for container tasks)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.environment}-ecs-task-role"

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
    Name        = "${var.environment}-ecs-task-role"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

# Custom policy for ECS instances with FedRAMP compliance requirements
resource "aws_iam_policy" "ecs_fedramp_policy" {
  name        = "${var.environment}-ecs-fedramp-policy"
  description = "FedRAMP compliance policy for ECS instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags",
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-ecs-fedramp-policy"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_fedramp_policy" {
  policy_arn = aws_iam_policy.ecs_fedramp_policy.arn
  role       = aws_iam_role.ecs_instance_role.name
}

# Allow ECS Exec capability for secure shell access to containers (FedRAMP compliant alternative to SSH)
resource "aws_iam_policy" "ecs_exec_policy" {
  name        = "${var.environment}-ecs-exec-policy"
  description = "Policy for ECS Exec functionality"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "${var.environment}-ecs-exec-policy"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_exec_policy" {
  policy_arn = aws_iam_policy.ecs_exec_policy.arn
  role       = aws_iam_role.ecs_task_role.name
}