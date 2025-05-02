# FedRAMP-Compliant AWS Container Environment

This repository contains OpenTofu code to deploy a FedRAMP-compliant AWS environment for running containerized applications in ECS (Elastic Container Service).

## Architecture Overview

The infrastructure is organized into modular components adhering to FedRAMP security controls:

- **VPC Module**: Network isolation with public and private subnets
- **IAM Module**: Least privilege access control
- **Security Module**: Security groups, KMS encryption, WAF protection, compliance rules
- **ECS Module**: Container service for running containerized workloads
- **Monitoring Module**: Auditing, logging, and compliance monitoring

## FedRAMP Compliance Features

- **Network Security**
  - Isolated VPC with public and private subnets
  - Private endpoints
  - Security groups with least privilege access
  - VPC Flow Logs for network traffic analysis
  - WAF integration for web application protection

- **Access Control**
  - IAM roles with least privilege
  - AWS Security Hub integration
  - IMDSv2 required for EC2 instances
  - No direct SSH access (SSM Session Manager used instead)

- **Encryption**
  - KMS keys for ECS secrets
  - EBS volume encryption
  - CloudTrail log encryption
  - S3 bucket encryption

- **Monitoring and Audit**
  - CloudTrail multi-region trails
  - VPC Flow Logs
  - AWS Config rules
  - GuardDuty threat detection
  - CloudWatch Logs with extended retention

- **Data Protection**
  - S3 bucket policies prevent public access
  - Encrypted data at rest and in transit
  - HTTPS enforcement

## Prerequisites

- AWS CLI configured with appropriate credentials
- OpenTofu v1.6.0 or higher
- A registered domain (optional, for exposing services)

## Deployment Instructions

1. **Initialize OpenTofu**:
   ```
   tofu init
   ```

2. **Set Required Variables**:
   Create a `terraform.tfvars` file with your specific configuration values:
   ```
   aws_region        = "us-east-1"
   environment       = "prod"
   vpc_cidr          = "10.0.0.0/16"
   availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
   ecs_cluster_name  = "fedramp-ecs-cluster"
   ```

3. **Plan the Deployment**:
   ```
   tofu plan -out=plan.out
   ```

4. **Apply the Configuration**:
   ```
   tofu apply plan.out
   ```

## Working with Containers

After the infrastructure is deployed, you can:

1. Create ECS task definitions for your container images
2. Deploy services with the AWS CLI or console
3. Set up CI/CD pipelines with AWS CodeBuild/CodePipeline
4. Configure AWS Application Load Balancers for exposing services

## FedRAMP Documentation

This infrastructure helps satisfy multiple FedRAMP controls including:

- AC-2, AC-3, AC-6: Access Control
- AU-2, AU-3, AU-12: Audit and Accountability
- SC-7, SC-8, SC-13: System and Communications Protection
- IA-2, IA-5: Identification and Authentication
- CM-6, CM-7: Configuration Management

For complete FedRAMP compliance, additional organizational processes and documentation are required.

## Maintenance and Operations

- **Container Instance Management**: Auto-scaling group handles capacity
- **Rotating KMS Keys**: Enable automatic key rotation
- **Security Monitoring**: Review GuardDuty and Security Hub findings
- **Compliance Auditing**: Use AWS Config rules and remediation
- **Logs and Metrics**: Analyze CloudWatch logs and metrics

