#!/bin/bash

# deploy.sh - Automated deployment script for FedRAMP-compliant AWS container environment
# Created: May 2, 2025

set -e

# Text colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================================${NC}"
echo -e "${BLUE}   FedRAMP-Compliant AWS Container Environment Setup     ${NC}"
echo -e "${BLUE}=========================================================${NC}"

# Check for required tools
echo -e "\n${YELLOW}Checking for required tools...${NC}"

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed or not in PATH${NC}"
    echo -e "Please install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check for OpenTofu / Terraform
if command -v tofu &> /dev/null; then
    TF_CMD="tofu"
    echo -e "${GREEN}OpenTofu is installed!${NC}"
elif command -v terraform &> /dev/null; then
    TF_CMD="terraform"
    echo -e "${YELLOW}Terraform is installed. Using Terraform instead of OpenTofu.${NC}"
else
    echo -e "${RED}Error: Neither OpenTofu nor Terraform is installed${NC}"
    echo -e "Please install OpenTofu: https://opentofu.org/docs/intro/install/"
    exit 1
fi

# Check if AWS credentials are configured
echo -e "\n${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials are not configured or invalid${NC}"
    echo -e "Please run 'aws configure' to set up your AWS credentials"
    exit 1
fi
echo -e "${GREEN}AWS credentials are configured!${NC}"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-east-1"
fi
echo -e "Using AWS Account: ${BLUE}${AWS_ACCOUNT_ID}${NC} in region: ${BLUE}${AWS_REGION}${NC}"

# Check if terraform.tfvars exists, if not create it
echo -e "\n${YELLOW}Checking for terraform.tfvars configuration file...${NC}"
if [ ! -f terraform.tfvars ]; then
    echo -e "${YELLOW}terraform.tfvars not found, creating from example file...${NC}"
    
    if [ ! -f terraform.tfvars.example ]; then
        echo -e "${RED}Error: terraform.tfvars.example is missing${NC}"
        exit 1
    fi
    
    cp terraform.tfvars.example terraform.tfvars
    
    # Ask user for input to customize variables
    read -p "Enter environment name (default: prod): " ENV_NAME
    ENV_NAME=${ENV_NAME:-prod}
    
    read -p "Enter VPC CIDR block (default: 10.0.0.0/16): " VPC_CIDR
    VPC_CIDR=${VPC_CIDR:-10.0.0.0/16}
    
    read -p "Enter ECS cluster name (default: fedramp-ecs-cluster): " CLUSTER_NAME
    CLUSTER_NAME=${CLUSTER_NAME:-fedramp-ecs-cluster}
    
    # Update the values in terraform.tfvars
    sed -i "s/environment = \"prod\"/environment = \"${ENV_NAME}\"/g" terraform.tfvars
    sed -i "s/vpc_cidr = \"10.0.0.0\/16\"/vpc_cidr = \"${VPC_CIDR}\"/g" terraform.tfvars
    sed -i "s/ecs_cluster_name = \"fedramp-ecs-cluster\"/ecs_cluster_name = \"${CLUSTER_NAME}\"/g" terraform.tfvars
    sed -i "s/aws_region = \"us-east-1\"/aws_region = \"${AWS_REGION}\"/g" terraform.tfvars
    
    echo -e "${GREEN}Created and configured terraform.tfvars!${NC}"
else
    echo -e "${GREEN}terraform.tfvars already exists!${NC}"
fi

# Initialize OpenTofu/Terraform
echo -e "\n${YELLOW}Initializing ${TF_CMD}...${NC}"
$TF_CMD init

# Check if state backend needs to be configured
read -p "Do you want to configure remote state storage with S3? (y/n, default: n): " CONFIGURE_BACKEND
CONFIGURE_BACKEND=${CONFIGURE_BACKEND:-n}

if [[ "$CONFIGURE_BACKEND" == "y" || "$CONFIGURE_BACKEND" == "Y" ]]; then
    echo -e "\n${YELLOW}Setting up remote state with S3...${NC}"
    
    # Generate unique names for S3 bucket and DynamoDB table
    STATE_BUCKET="fedramp-state-${AWS_ACCOUNT_ID}-${AWS_REGION}"
    LOCK_TABLE="fedramp-state-locks-${AWS_ACCOUNT_ID}"
    
    # Check if bucket exists, create if it doesn't
    if ! aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
        echo -e "Creating S3 bucket for state storage: ${BLUE}${STATE_BUCKET}${NC}"
        
        # Create S3 bucket with versioning and encryption
        if [[ "$AWS_REGION" == "us-east-1" ]]; then
            aws s3api create-bucket --bucket "$STATE_BUCKET" \
                --region "$AWS_REGION"
        else
            aws s3api create-bucket --bucket "$STATE_BUCKET" \
                --region "$AWS_REGION" \
                --create-bucket-configuration LocationConstraint="$AWS_REGION"
        fi
        
        # Enable versioning
        aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled
        
        # Enable encryption
        aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" \
            --server-side-encryption-configuration '{
                "Rules": [
                    {
                        "ApplyServerSideEncryptionByDefault": {
                            "SSEAlgorithm": "AES256"
                        },
                        "BucketKeyEnabled": true
                    }
                ]
            }'
        
        # Block public access
        aws s3api put-public-access-block --bucket "$STATE_BUCKET" \
            --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    else
        echo -e "S3 bucket already exists: ${BLUE}${STATE_BUCKET}${NC}"
    fi
    
    # Check if DynamoDB table exists, create if it doesn't
    if ! aws dynamodb describe-table --table-name "$LOCK_TABLE" &>/dev/null; then
        echo -e "Creating DynamoDB table for state locking: ${BLUE}${LOCK_TABLE}${NC}"
        aws dynamodb create-table \
            --table-name "$LOCK_TABLE" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region "$AWS_REGION"
    else
        echo -e "DynamoDB table already exists: ${BLUE}${LOCK_TABLE}${NC}"
    fi
    
    # Create backend configuration file
    cat > backend.tf << EOF
terraform {
  backend "s3" {
    bucket         = "${STATE_BUCKET}"
    key            = "fedramp/terraform.tfstate"
    region         = "${AWS_REGION}"
    dynamodb_table = "${LOCK_TABLE}"
    encrypt        = true
  }
}
EOF
    
    # Update main.tf to remove the commented backend block
    sed -i '/# Remote state backend configuration/,/^$/d' main.tf
    
    # Reinitialize with the backend configuration
    echo -e "\n${YELLOW}Reinitializing with remote state configuration...${NC}"
    $TF_CMD init -force-copy
    
    echo -e "${GREEN}Remote state configuration complete!${NC}"
else
    echo -e "\n${YELLOW}Using local state storage...${NC}"
fi

# Plan the deployment
echo -e "\n${YELLOW}Planning the deployment...${NC}"
$TF_CMD plan -out=tfplan

# Ask for confirmation before applying
echo -e "\n${YELLOW}Review the plan above.${NC}"
read -p "Do you want to apply this plan? (y/n, default: n): " APPLY_PLAN
APPLY_PLAN=${APPLY_PLAN:-n}

if [[ "$APPLY_PLAN" == "y" || "$APPLY_PLAN" == "Y" ]]; then
    echo -e "\n${YELLOW}Applying the plan...${NC}"
    $TF_CMD apply tfplan
    
    echo -e "\n${GREEN}==================================================${NC}"
    echo -e "${GREEN}  FedRAMP-compliant AWS environment deployed!      ${NC}"
    echo -e "${GREEN}==================================================${NC}"
    echo -e "\nTo deploy containers to this environment:"
    echo -e "1. Create ECS task definitions for your container images"
    echo -e "2. Create ECS services to run your containers"
    echo -e "3. Set up CI/CD pipelines with AWS CodeBuild/CodePipeline"
    
    # Show important outputs
    echo -e "\n${YELLOW}Important Infrastructure Details:${NC}"
    echo -e "${BLUE}VPC ID:${NC} $($TF_CMD output -raw vpc_id 2>/dev/null || echo 'Not available')"
    echo -e "${BLUE}ECS Cluster Name:${NC} $($TF_CMD output -raw ecs_cluster_name 2>/dev/null || echo 'Not available')"
    echo -e "${BLUE}ECS Cluster ARN:${NC} $($TF_CMD output -raw ecs_cluster_arn 2>/dev/null || echo 'Not available')"
else
    echo -e "\n${YELLOW}Deployment cancelled. The plan was not applied.${NC}"
fi

echo -e "\n${BLUE}Script execution complete!${NC}"