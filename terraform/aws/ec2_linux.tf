# =============================================================================
# EC2 — Linux Worker Nodes (Ubuntu 22.04)
# Grafana Alloy is deployed here by Ansible (playbook-linux.yml)
# after Terraform creates the infrastructure.
# =============================================================================

resource "aws_instance" "linux_worker" {
  count                  = var.linux_worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.linux_worker_instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public[count.index % length(aws_subnet.public)].id
  vpc_security_group_ids = [aws_security_group.linux_worker.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
    encrypted             = true
  }

  # Minimal bootstrap — Alloy will be installed by Ansible
  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y python3 python3-pip
    echo "Linux worker bootstrap complete" >> /var/log/monitoring-bootstrap.log
  EOF

  tags = { Name = "linux-worker-${count.index + 1}-${var.environment}" }
}
