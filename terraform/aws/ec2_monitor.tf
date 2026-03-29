# =============================================================================
# EC2 — Monitor Server
# Runs: Prometheus + Loki + Grafana + Alertmanager via docker-compose
# =============================================================================

resource "aws_instance" "monitor" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.monitor_instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.monitor.id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 100  # GB — stores Prometheus + Loki data
    delete_on_termination = true
    encrypted             = true
  }

  # Bootstrap: install Docker + docker-compose and clone the repo
  user_data = <<-EOF
    #!/bin/bash
    set -e

    # System update
    apt-get update -y
    apt-get upgrade -y

    # Install Docker
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin git

    # Add ubuntu user to docker group
    usermod -aG docker ubuntu

    # Clone the monitoring repo
    git clone https://github.com/KasiRamaKrishnan/portable_monitoring_agent.git \
      /home/ubuntu/portable_monitoring_agent
    chown -R ubuntu:ubuntu /home/ubuntu/portable_monitoring_agent

    # Copy versions.env as .env for docker-compose
    cp /home/ubuntu/portable_monitoring_agent/versions.env \
       /home/ubuntu/portable_monitoring_agent/.env

    # Start the monitoring stack
    cd /home/ubuntu/portable_monitoring_agent
    docker compose up -d

    echo "Monitor server bootstrap complete" >> /var/log/monitoring-bootstrap.log
  EOF

  tags = { Name = "monitoring-server-${var.environment}" }
}
