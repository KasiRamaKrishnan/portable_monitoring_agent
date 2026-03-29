# =============================================================================
# Security Groups
#
# Monitor server  — accepts inbound from browser + Alloy agents (push)
# Linux workers   — SSH from admin, outbound-only to monitor server
# Windows workers — WinRM from admin, outbound-only to monitor server
# EKS nodes       — managed by EKS, plus allow Alloy push outbound
# =============================================================================

# ─── Monitor Server ───────────────────────────────────────────────────────────

resource "aws_security_group" "monitor" {
  name        = "monitoring-monitor-sg-${var.environment}"
  description = "Monitor server: Grafana, Prometheus, Loki, Alertmanager"
  vpc_id      = aws_vpc.main.id

  # SSH (admin access)
  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Grafana UI
  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Prometheus — browser access + Alloy remote_write from workers
  ingress {
    description = "Prometheus (browser + Alloy remote_write)"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr, var.vpc_cidr]
  }

  # Loki — browser access + Alloy log push from workers
  ingress {
    description = "Loki (browser + Alloy log push)"
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr, var.vpc_cidr]
  }

  # Alertmanager UI
  ingress {
    description = "Alertmanager"
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "monitoring-monitor-sg-${var.environment}" }
}

# ─── Linux Worker Nodes ───────────────────────────────────────────────────────

resource "aws_security_group" "linux_worker" {
  name        = "monitoring-linux-worker-sg-${var.environment}"
  description = "Linux workers: SSH admin, Alloy UI debug"
  vpc_id      = aws_vpc.main.id

  # SSH (Ansible + admin access)
  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Alloy debug UI (optional — useful for troubleshooting)
  ingress {
    description = "Grafana Alloy UI"
    from_port   = 12345
    to_port     = 12345
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # All outbound — workers push to monitor server on 9090 + 3100
  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "monitoring-linux-worker-sg-${var.environment}" }
}

# ─── Windows Worker Node ─────────────────────────────────────────────────────

resource "aws_security_group" "windows_worker" {
  name        = "monitoring-windows-worker-sg-${var.environment}"
  description = "Windows workers: WinRM for Ansible, Alloy UI debug"
  vpc_id      = aws_vpc.main.id

  # WinRM HTTP (Ansible connectivity)
  ingress {
    description = "WinRM HTTP (Ansible)"
    from_port   = 5985
    to_port     = 5985
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # WinRM HTTPS
  ingress {
    description = "WinRM HTTPS"
    from_port   = 5986
    to_port     = 5986
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # RDP (optional — for manual access)
  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # Alloy UI
  ingress {
    description = "Grafana Alloy UI"
    from_port   = 12345
    to_port     = 12345
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "monitoring-windows-worker-sg-${var.environment}" }
}

# ─── EKS Cluster Control Plane ────────────────────────────────────────────────

resource "aws_security_group" "eks_cluster" {
  name        = "monitoring-eks-cluster-sg-${var.environment}"
  description = "EKS cluster control plane"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "monitoring-eks-cluster-sg-${var.environment}" }
}

# Allow nodes to communicate with cluster API
resource "aws_security_group_rule" "eks_cluster_ingress_nodes" {
  description              = "Allow worker nodes to reach API server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
}

# Allow admin to reach kubectl API
resource "aws_security_group_rule" "eks_cluster_ingress_admin" {
  description       = "Allow admin kubectl access"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_cluster.id
  cidr_blocks       = [var.allowed_ssh_cidr]
}

# ─── EKS Worker Nodes ─────────────────────────────────────────────────────────

resource "aws_security_group" "eks_nodes" {
  name        = "monitoring-eks-nodes-sg-${var.environment}"
  description = "EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  # Nodes communicate with each other
  ingress {
    description = "Node-to-node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "-1"
    self        = true
  }

  # Cluster control plane reaches nodes
  ingress {
    description              = "Cluster control plane to nodes"
    from_port                = 1025
    to_port                  = 65535
    protocol                 = "tcp"
    security_group_id        = aws_security_group.eks_nodes.id
    source_security_group_id = aws_security_group.eks_cluster.id
  }

  egress {
    description = "All outbound (pull images, push to monitor)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name                                                    = "monitoring-eks-nodes-sg-${var.environment}"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "owned"
  }
}
