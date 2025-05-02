resource "aws_eks_cluster" "main" {
  name     = "${var.environment}-${var.eks_cluster_name}"
  role_arn = var.eks_cluster_role_arn
  version  = var.eks_cluster_version

  vpc_config {
    security_group_ids      = [var.cluster_security_group_id]
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = false  # FedRAMP recommends private endpoints only
  }

  encryption_config {
    provider {
      key_arn = var.eks_secrets_kms_key_arn
    }
    resources = ["secrets"]
  }

  # Enable EKS control plane logging (FedRAMP requirement)
  enabled_cluster_log_types = [
    "api", 
    "audit", 
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  tags = {
    Name        = "${var.environment}-${var.eks_cluster_name}"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }

  # Ensure IAM Role is created before EKS
  depends_on = [
    var.eks_cluster_role_arn
  ]
}

# Node groups for running container workloads
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.environment}-node-group"
  node_role_arn   = var.eks_node_role_arn
  subnet_ids      = var.subnet_ids

  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  # Configure instance types (t3.medium is minimal for production)
  instance_types = var.node_group_instance_types

  # Use latest EKS optimized AMI with container runtime
  ami_type = "AL2_x86_64"

  # Enable remote access to nodes (via SSM, not SSH - FedRAMP requirement)
  remote_access {
    ec2_ssh_key               = var.enable_ssh_access ? var.ssh_key_name : null
    source_security_group_ids = var.enable_ssh_access ? [var.bastion_security_group_id] : []
  }

  # Enable custom launch template with disk encryption
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  tags = {
    Name        = "${var.environment}-node-group"
    Environment = var.environment
    Compliance  = "FedRAMP"
  }

  # Ensure EKS Cluster is created first
  depends_on = [
    aws_eks_cluster.main
  ]
}

# Launch template for node group with encrypted EBS volumes
resource "aws_launch_template" "eks_nodes" {
  name                   = "${var.environment}-eks-node-template"
  description            = "Launch template for EKS worker nodes"
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.eks_ebs_kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # IMDSv2 required for FedRAMP
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true  # Enable detailed monitoring for FedRAMP compliance
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-eks-node"
      Environment = var.environment
      Compliance  = "FedRAMP"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name        = "${var.environment}-eks-node-volume"
      Environment = var.environment
      Compliance  = "FedRAMP"
    }
  }
}

# Add-ons required for FedRAMP compliance
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "coredns"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "kube-proxy"
}

# AWS EKS OIDC provider for IAM role integration
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}