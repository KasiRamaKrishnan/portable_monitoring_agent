# =============================================================================
# EKS — Kubernetes Cluster
#
# Creates:
#   - IAM roles for cluster + node group
#   - EKS control plane (in private subnets)
#   - Managed node group (t3.medium, 2-4 nodes)
#
# After terraform apply, configure kubectl:
#   aws eks update-kubeconfig --region <region> --name <cluster_name>
#
# Then deploy the monitoring stack:
#   ./kubernetes/deploy.sh deploy
# =============================================================================

# ─── IAM Role: EKS Cluster ───────────────────────────────────────────────────

resource "aws_iam_role" "eks_cluster" {
  name = "monitoring-eks-cluster-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# ─── IAM Role: EKS Node Group ────────────────────────────────────────────────

resource "aws_iam_role" "eks_nodes" {
  name = "monitoring-eks-nodes-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_ecr_readonly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# ─── EKS Cluster ─────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = var.eks_cluster_name
  version  = var.eks_kubernetes_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = aws_subnet.private[*].id
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true  # Set false if running kubectl from within VPC
  }

  # Enable control-plane logging
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]

  tags = { Name = "${var.eks_cluster_name}-${var.environment}" }
}

# ─── EKS Managed Node Group ──────────────────────────────────────────────────

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "monitoring-workers-${var.environment}"
  node_role_arn   = aws_iam_role.eks_nodes.arn

  # Nodes go in private subnets
  subnet_ids = aws_subnet.private[*].id

  instance_types = [var.eks_node_instance_type]
  capacity_type  = "ON_DEMAND"

  scaling_config {
    desired_size = var.eks_node_desired
    max_size     = var.eks_node_max
    min_size     = var.eks_node_min
  }

  update_config {
    max_unavailable = 1
  }

  # Use latest EKS-optimised AMI automatically
  ami_type       = "AL2_x86_64"
  disk_size      = 20

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly,
  ]

  tags = { Name = "eks-worker-${var.environment}" }
}

# ─── aws-auth ConfigMap (allow nodes to join the cluster) ────────────────────
# Terraform manages this so you don't have to patch it manually.

resource "aws_eks_access_entry" "nodes" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = aws_iam_role.eks_nodes.arn
  type          = "EC2_LINUX"
}
