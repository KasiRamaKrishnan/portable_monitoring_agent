# =============================================================================
# Outputs
# After `terraform apply`, these values are printed to the terminal.
# The generate-inventory.sh script reads them automatically to build
# monitoring-deploy/inventory.ini ready for Ansible.
# =============================================================================

# ─── Monitor Server ───────────────────────────────────────────────────────────

output "monitor_public_ip" {
  description = "Public IP of the monitoring server (Grafana / Prometheus / Loki)"
  value       = aws_instance.monitor.public_ip
}

output "monitor_private_ip" {
  description = "Private IP of the monitoring server (used by workers to push metrics/logs)"
  value       = aws_instance.monitor.private_ip
}

output "monitor_access_urls" {
  description = "Direct access URLs for the monitoring stack"
  value = {
    grafana      = "http://${aws_instance.monitor.public_ip}:3000  (admin / admin)"
    prometheus   = "http://${aws_instance.monitor.public_ip}:9090"
    loki         = "http://${aws_instance.monitor.public_ip}:3100"
    alertmanager = "http://${aws_instance.monitor.public_ip}:9093"
  }
}

# ─── Linux Workers ────────────────────────────────────────────────────────────

output "linux_worker_public_ips" {
  description = "Public IPs of Linux worker nodes (used by Ansible over SSH)"
  value       = aws_instance.linux_worker[*].public_ip
}

output "linux_worker_private_ips" {
  description = "Private IPs of Linux worker nodes"
  value       = aws_instance.linux_worker[*].private_ip
}

# ─── Windows Workers ─────────────────────────────────────────────────────────

output "windows_worker_public_ips" {
  description = "Public IPs of Windows worker nodes (used by Ansible over WinRM)"
  value       = aws_instance.windows_worker[*].public_ip
}

output "windows_worker_private_ips" {
  description = "Private IPs of Windows worker nodes"
  value       = aws_instance.windows_worker[*].private_ip
}

# ─── EKS ─────────────────────────────────────────────────────────────────────

output "eks_cluster_name" {
  description = "EKS cluster name — use with aws eks update-kubeconfig"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = aws_eks_cluster.main.version
}

output "eks_kubeconfig_command" {
  description = "Run this command to configure kubectl for the EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

# ─── Networking ───────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets (EKS nodes)"
  value       = aws_subnet.private[*].id
}

# ─── SSH key reminder ─────────────────────────────────────────────────────────

output "ssh_connection_examples" {
  description = "Example SSH commands for each node type"
  value = {
    monitor        = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.monitor.public_ip}"
    linux_worker_1 = length(aws_instance.linux_worker) > 0 ? "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.linux_worker[0].public_ip}" : "no linux workers"
  }
}
