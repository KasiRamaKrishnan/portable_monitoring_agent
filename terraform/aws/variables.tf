# =============================================================================
# Input Variables
# Copy terraform.tfvars.example → terraform.tfvars and fill in your values.
# =============================================================================

# ─── AWS ─────────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name — used in resource tags and names"
  type        = string
  default     = "test"
}

# ─── SSH key ─────────────────────────────────────────────────────────────────

variable "key_pair_name" {
  description = <<-EOT
    Name of an existing EC2 Key Pair for SSH access to Linux instances.
    Create one in the AWS Console → EC2 → Key Pairs, then download the .pem file.
  EOT
  type        = string
}

variable "allowed_ssh_cidr" {
  description = "Your public IP in CIDR notation (e.g. 203.0.113.10/32). Only this IP can SSH / WinRM into the nodes."
  type        = string
  default     = "0.0.0.0/0" # Restrict this to your IP in production!
}

# ─── Networking ───────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (monitor server + worker nodes)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (EKS nodes)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

# ─── Instance types ──────────────────────────────────────────────────────────

variable "monitor_instance_type" {
  description = "EC2 instance type for the monitoring server (needs more RAM for Prometheus + Loki + Grafana)"
  type        = string
  default     = "t3.medium" # 2 vCPU, 4 GB RAM
}

variable "linux_worker_instance_type" {
  description = "EC2 instance type for Linux worker nodes"
  type        = string
  default     = "t3.small" # 2 vCPU, 2 GB RAM
}

variable "linux_worker_count" {
  description = "Number of Linux worker nodes to create"
  type        = number
  default     = 2
}

variable "windows_worker_instance_type" {
  description = "EC2 instance type for the Windows worker node (Windows needs more RAM)"
  type        = string
  default     = "t3.medium" # 2 vCPU, 4 GB RAM
}

variable "windows_worker_count" {
  description = "Number of Windows worker nodes to create"
  type        = number
  default     = 1
}

variable "windows_admin_password" {
  description = <<-EOT
    Administrator password for Windows nodes.
    Must meet Windows complexity requirements:
    - Minimum 12 characters
    - Uppercase + lowercase + digit + special character
    Store this in a .tfvars file that is NOT committed to git.
  EOT
  type        = string
  sensitive   = true
}

# ─── EKS ─────────────────────────────────────────────────────────────────────

variable "eks_cluster_name" {
  description = "Name for the EKS cluster"
  type        = string
  default     = "monitoring-test-cluster"
}

variable "eks_kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.29"
}

variable "eks_node_instance_type" {
  description = "EC2 instance type for EKS worker nodes"
  type        = string
  default     = "t3.medium"
}

variable "eks_node_min" {
  description = "Minimum number of EKS nodes"
  type        = number
  default     = 2
}

variable "eks_node_max" {
  description = "Maximum number of EKS nodes"
  type        = number
  default     = 4
}

variable "eks_node_desired" {
  description = "Desired number of EKS nodes"
  type        = number
  default     = 2
}
