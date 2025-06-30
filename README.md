# 🔍 Monitoring Agent Deployment with Ansible (Prometheus + Grafana + Loki + Node Exporter + Promtail)

This project automates the deployment of a full monitoring stack using **Ansible**, targeting:

- One **Monitoring Node** (Prometheus + Grafana + Loki + Node Exporter + Promtail)
- Multiple **Worker Nodes** (Node Exporter + Promtail)

---

## 📦 Stack Components

| Component     | Role                                |
|---------------|-------------------------------------|
| Prometheus    | Metrics collection                  |
| Grafana       | Metrics & logs visualization        |
| Loki          | Log aggregation                     |
| Node Exporter | Export Linux system metrics         |
| Promtail      | Forward logs to Loki                |

---

## 🛠️ Prerequisites

- Ansible installed on the **control host** (can be your laptop or the monitoring node itself)
- SSH access from control host to all target VMs
- SSH private key available and referenced in inventory
- Docker installed automatically via playbooks
- Git installed on control host
- All VMs are Ubuntu-based

---

## 📁 Directory Structure

```bash
monitoring-deploy/
├── inventory.ini
├── playbooks/
│   ├── playbook-monitor.yml
│   └── playbook-workers.yml
├── files/
│   └── promtail-config.yaml


# 📊 Complete Monitoring Stack Documentation

> **Automated deployment of Prometheus, Grafana, Loki monitoring stack using Ansible**

## Table of Contents
1. [🚀 Quick Start](#-quick-start)
2. [🏗️ Architecture Overview](#️-architecture-overview)
3. [🔧 Component Details](#-component-details)
4. [📋 Prerequisites](#-prerequisites)
5. [⚙️ Installation Guide](#️-installation-guide)
6. [🔨 Configuration](#-configuration)
7. [📊 Monitoring and Dashboards](#-monitoring-and-dashboards)
8. [🔍 Troubleshooting](#-troubleshooting)
9. [🛠️ Maintenance](#️-maintenance)
10. [🔒 Security Considerations](#-security-considerations)

## 🚀 Quick Start

### Prerequisites Checklist
- [ ] Ubuntu 18.04+ on all nodes
- [ ] SSH access to all nodes  
- [ ] Ansible installed on control host
- [ ] Network connectivity between nodes

### 3-Step Deployment
```bash
# Step 1: Clone and setup
git clone https://github.com/KasiRamaKrishnan/portable_monitoring_agent.git
cd portable_monitoring_agent/monitoring-deploy

# Step 2: Configure inventory.ini with your node IPs and SSH keys
ansible all -i inventory.ini -m ping  # Test connectivity

# Step 3: Deploy
ansible-playbook -i inventory.ini playbooks/playbook-workers.yml --ask-become-pass   # Worker nodes
ansible-playbook -i inventory.ini playbooks/playbook-monitor.yml --ask-become-pass   # Monitoring node
```

### Post-Deployment Access
- **Grafana**: `http://monitoring-node-ip:3000` (admin/admin)
- **Prometheus**: `http://monitoring-node-ip:9090`

---

## 🏗️ Architecture Overview

This monitoring solution implements a distributed observability stack using modern open-source tools. The architecture follows a hub-and-spoke model where the monitoring node acts as the central collection and visualization point.

**Key Components:**
- **Monitoring Node**: Central hub running Prometheus, Grafana, Loki, Node Exporter, and Promtail
- **Worker Nodes**: Distributed agents running Node Exporter and Promtail

### High-Level Architecture

```
                    ╔═══════════════════════════════════════════════════════════════╗
                    ║                    MONITORING NODE                           ║
                    ║  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        ║
                    ║  │ Prometheus  │  │   Grafana   │  │    Loki     │        ║
                    ║  │   :9090     │  │    :3000    │  │   :3100     │        ║
                    ║  └─────────────┘  └─────────────┘  └─────────────┘        ║
                    ║  ┌─────────────┐  ┌─────────────┐                         ║
                    ║  │Node Exporter│  │  Promtail   │                         ║
                    ║  │   :9100     │  │   :9080     │                         ║
                    ║  └─────────────┘  └─────────────┘                         ║
                    ╚═══════════════════════════════════════════════════════════════╝
                                            │
                                            │ Scrapes metrics & collects logs
                                            ▼
                    ╔═══════════════════════════════════════════════════════════════╗
                    ║                    WORKER NODES                              ║
                    ║  ┌─────────────┐  ┌─────────────┐                          ║
                    ║  │Node Exporter│  │  Promtail   │                          ║
                    ║  │   :9100     │  │   :9080     │                          ║
                    ║  └─────────────┘  └─────────────┘                          ║
                    ╚═══════════════════════════════════════════════════════════════╝
```
![image](https://github.com/user-attachments/assets/b7d5b25c-7f59-4373-a139-f852fc4ea59d)

### Data Flow

```
📊 METRICS FLOW
Node Exporter (All Nodes) → Prometheus (Monitoring Node) → Grafana (Visualization)

📝 LOGS FLOW  
Promtail (All Nodes) → Loki (Monitoring Node) → Grafana (Visualization)
```

**Process:**
1. **Metrics Collection**: Node Exporter on all nodes exposes system metrics
2. **Metrics Aggregation**: Prometheus scrapes metrics from all Node Exporters  
3. **Log Collection**: Promtail on all nodes tails log files and forwards to Loki
4. **Log Aggregation**: Loki receives and indexes logs from all Promtail instances
5. **Visualization**: Grafana queries both Prometheus and Loki for unified dashboards

## 🔧 Component Details

### Monitoring Node Components

#### Prometheus (Port 9090)
- **Purpose**: Time-series metrics database and monitoring system
- **Responsibilities**:
  - Scrapes metrics from Node Exporters across all nodes
  - Stores time-series data with automatic retention policies
  - Provides PromQL query language for metrics analysis
  - Handles alerting rules and notifications
- **Data Storage**: Local filesystem with configurable retention
- **Key Features**: Service discovery, rule evaluation, alert management

#### Grafana (Port 3000)
- **Purpose**: Visualization and analytics platform
- **Responsibilities**:
  - Creates dashboards for metrics and logs
  - Provides alerting and notification capabilities
  - User management and access control
  - Data source management (Prometheus + Loki)
- **Default Access**: admin/admin (change immediately)
- **Key Features**: Rich visualization, templating, annotations

#### Loki (Port 3100)
- **Purpose**: Log aggregation system inspired by Prometheus
- **Responsibilities**:
  - Receives log streams from Promtail instances
  - Indexes logs using labels (not full-text)
  - Provides LogQL query language
  - Efficient log storage and retrieval
- **Storage**: Local filesystem with configurable retention
- **Key Features**: Label-based indexing, efficient compression

#### Node Exporter (Port 9100)
- **Purpose**: Hardware and OS metrics exporter for Unix systems
- **Responsibilities**:
  - Exposes CPU, memory, disk, network metrics
  - Provides filesystem and process statistics
  - Hardware sensor data collection
- **Metrics Format**: Prometheus exposition format
- **Update Frequency**: Real-time metric exposure

#### Promtail (Port 9080)
- **Purpose**: Log shipping agent for Loki
- **Responsibilities**:
  - Tails log files (syslog, application logs)
  - Adds labels and metadata to log entries
  - Forwards structured logs to Loki
  - Handles log parsing and filtering
- **Configuration**: YAML-based with discovery capabilities

### Worker Node Components

#### Node Exporter (Port 9100)
- Same functionality as monitoring node
- Configured to be scraped by central Prometheus
- Exposes worker node system metrics

#### Promtail (Port 9080)
- Same functionality as monitoring node
- Configured to forward logs to central Loki
- Tails worker node specific logs

## Prerequisites

### System Requirements

#### Monitoring Node
- **OS**: Ubuntu 18.04+ (recommended: Ubuntu 20.04/22.04)
- **CPU**: Minimum 2 cores, Recommended 4+ cores
- **RAM**: Minimum 4GB, Recommended 8GB+
- **Storage**: Minimum 50GB, Recommended 100GB+ SSD
- **Network**: Stable internet connection, open ports for services

#### Worker Nodes
- **OS**: Ubuntu 18.04+ (recommended: Ubuntu 20.04/22.04)
- **CPU**: Minimum 1 core
- **RAM**: Minimum 1GB, Recommended 2GB+
- **Storage**: Minimum 10GB free space
- **Network**: Network connectivity to monitoring node

### Software Prerequisites

#### Control Host (Ansible Controller)
```bash
# Install Ansible
sudo apt update
sudo apt install ansible python3-pip git -y

# Verify installation
ansible --version
```

#### All Target Nodes
- SSH server running and accessible
- User account with sudo privileges
- Python3 installed (usually pre-installed on Ubuntu)

### Network Requirements

#### Required Open Ports

| Node Type | Port | Service | Description |
|-----------|------|---------|-------------|
| **Monitoring Node** | 22 | SSH | Remote access |
| | 3000 | Grafana | Web UI |
| | 9090 | Prometheus | Web UI & API |
| | 9100 | Node Exporter | Metrics endpoint |
| | 3100 | Loki | Log ingestion API |
| | 9080 | Promtail | Metrics endpoint |
| **Worker Nodes** | 22 | SSH | Remote access |
| | 9100 | Node Exporter | Metrics endpoint |
| | 9080 | Promtail | Metrics endpoint |

#### Firewall Configuration Example
```bash
# On monitoring node
sudo ufw allow 22/tcp
sudo ufw allow 3000/tcp
sudo ufw allow 9090/tcp
sudo ufw allow 9100/tcp
sudo ufw allow 3100/tcp
sudo ufw allow 9080/tcp
sudo ufw enable

# On worker nodes
sudo ufw allow 22/tcp
sudo ufw allow 9100/tcp
sudo ufw allow 9080/tcp  
sudo ufw enable
```

## Installation Guide

### Step 1: Clone Repository
```bash
git clone https://github.com/KasiRamaKrishnan/portable_monitoring_agent.git
cd portable_monitoring_agent/monitoring-deploy
```

### Step 2: Configure Inventory

Create and edit `inventory.ini`:

```ini
[monitoring_nodes]
monitoring-server ansible_host=192.168.1.100 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem

[worker_nodes]
worker-1 ansible_host=192.168.1.101 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem
worker-2 ansible_host=192.168.1.102 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem
worker-3 ansible_host=192.168.1.103 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/your-key.pem

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
monitoring_node_ip=192.168.1.100
```

> **📝 Note**: Replace IP addresses and SSH key paths with your actual values

### Step 3: Verify Connectivity
```bash
# Test SSH connectivity to all nodes
ansible all -i inventory.ini -m ping

# Expected output: SUCCESS for all nodes
```

### Step 4: Deploy Worker Nodes
```bash
# Deploy monitoring agents on worker nodes
ansible-playbook -i inventory.ini playbooks/playbook-workers.yml

# This installs: Docker, Node Exporter, Promtail
```

### Step 5: Deploy Monitoring Node
```bash
# Deploy complete monitoring stack on monitoring node
ansible-playbook -i inventory.ini playbooks/playbook-monitor.yml

# Monitor deployment progress
# This installs: Docker, Prometheus, Grafana, Loki, Node Exporter, Promtail
```

## Configuration

### Prometheus Configuration

The Prometheus configuration automatically includes:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: 
          - 'localhost:9100'  # monitoring node
          - '192.168.1.101:9100'  # worker-1
          - '192.168.1.102:9100'  # worker-2
          - '192.168.1.103:9100'  # worker-3
```

### Loki Configuration

Default Loki configuration:
```yaml
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  boltdb_shipper:
    active_index_directory: /loki/boltdb-shipper-active
    cache_location: /loki/boltdb-shipper-cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
```

### Promtail Configuration

Promtail configuration for log collection:
```yaml
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://192.168.1.100:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          __path__: /var/log/syslog
```

### Docker Compose Services

The monitoring node runs services via Docker Compose:

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin

  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yaml:/etc/loki/local-config.yaml
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yaml

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points'
      - '^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)'

  promtail:
    image: grafana/promtail:latest
    ports:
      - "9080:9080"
    volumes:
      - /var/log:/var/log:ro
      - ./promtail-config.yaml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml

volumes:
  prometheus_data:
  grafana_data:
  loki_data:
```

### Quick Deployment Commands

```bash
# 1. Clone repository
git clone https://github.com/KasiRamaKrishnan/portable_monitoring_agent.git
cd portable_monitoring_agent/monitoring-deploy

# 2. Configure inventory (edit with your IPs and SSH keys)
vim inventory.ini

# 3. Test connectivity
ansible all -i inventory.ini -m ping

# 4. Deploy monitoring node
ansible-playbook -i inventory.ini playbooks/playbook-monitor.yml --ask-become-pass

# 5. Deploy worker nodes  
ansible-playbook -i inventory.ini playbooks/playbook-workers.yml --ask-become-pass

# 6. Access Grafana
# http://your-monitoring-node-ip:3000 (admin/admin)
```

> **✅ Deployment Status**: All services should be running after successful deployment

### Manual Deployment Steps (Alternative)

If you prefer manual deployment:

#### On Monitoring Node:
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Create directories
mkdir -p ~/monitoring/{prometheus,grafana,loki,promtail}
cd ~/monitoring

# Create docker-compose.yml (use configuration above)
# Create configuration files
# Start services
docker-compose up -d
```

#### On Worker Nodes:
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Start Node Exporter
docker run -d \
  --name node-exporter \
  --restart unless-stopped \
  -p 9100:9100 \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /:/rootfs:ro \
  prom/node-exporter:latest \
  --path.procfs=/host/proc \
  --path.sysfs=/host/sys \
  --collector.filesystem.ignored-mount-points='^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)'

# Start Promtail (create config first)
docker run -d \
  --name promtail \
  --restart unless-stopped \
  -p 9080:9080 \
  -v /var/log:/var/log:ro \
  -v /path/to/promtail-config.yaml:/etc/promtail/config.yml \
  grafana/promtail:latest \
  -config.file=/etc/promtail/config.yml
```

### Verification Steps

After deployment, verify all services:

```bash
# Check service status on monitoring node
docker ps
docker-compose ps

# Verify service endpoints
curl http://localhost:9090  # Prometheus
curl http://localhost:3000  # Grafana
curl http://localhost:3100/ready  # Loki
curl http://localhost:9100/metrics  # Node Exporter
curl http://localhost:9080/metrics  # Promtail

# Check worker nodes
curl http://worker-ip:9100/metrics  # Node Exporter
curl http://worker-ip:9080/metrics  # Promtail
```

## Monitoring and Dashboards

### Accessing Services

| Service | URL | Default Credentials | Purpose |
|---------|-----|---------------------|---------|
| **Grafana** | `http://monitoring-node-ip:3000` | admin/admin | Dashboards & Visualization |
| **Prometheus** | `http://monitoring-node-ip:9090` | - | Metrics Query Interface |
| **Node Exporter** | `http://any-node-ip:9100/metrics` | - | Raw Metrics Data |
| **Promtail** | `http://any-node-ip:9080/metrics` | - | Promtail Metrics |

> **⚠️ Security Warning**: Change Grafana's default password immediately after first login!

### Setting Up Grafana

#### Initial Configuration
1. Login to Grafana (admin/admin)
2. Change default password
3. Add data sources:
   - **Prometheus**: http://localhost:9090
   - **Loki**: http://localhost:3100

#### Essential Dashboards

**System Overview Dashboard:**
- CPU usage across all nodes
- Memory utilization
- Disk space and I/O
- Network traffic
- System load averages

**Node Exporter Dashboard:**
- Import Dashboard ID: 1860 (Node Exporter Full)
- Configure data source as Prometheus
- Customize for your environment

**Log Dashboard:**
- Create panels for log visualization
- Use LogQL queries for log analysis
- Set up log-based alerts

#### Sample Prometheus Queries

| Metric | Query | Description |
|--------|-------|-------------|
| **CPU Usage** | `100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)` | CPU usage percentage by node |
| **Memory Usage** | `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100` | Memory usage percentage |
| **Disk Usage** | `100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes)` | Disk usage percentage |
| **Network RX** | `rate(node_network_receive_bytes_total[5m]) * 8` | Network receive rate (bits/sec) |
| **Network TX** | `rate(node_network_transmit_bytes_total[5m]) * 8` | Network transmit rate (bits/sec) |

#### Sample LogQL Queries

| Use Case | Query | Description |
|----------|-------|-------------|
| **All Logs** | `{job="varlogs"}` | All logs from varlogs job |
| **Error Logs** | `{job="syslog"} \|= "error"` | Filter for error messages |
| **SSH Failures** | `{job="syslog"} \|= "Failed password"` | Failed SSH login attempts |
| **System Events** | `{job="syslog"} \|= "systemd"` | System service messages |

### Alerting Configuration

#### Prometheus Alert Rules

Create `alert-rules.yml`:
```yaml
groups:
  - name: node-alerts
    rules:
      - alert: NodeDown
        expr: up{job="node-exporter"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"
          description: "Node {{ $labels.instance }} has been down for more than 1 minute"

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 90% for more than 5 minutes"

      - alert: DiskSpaceLow
        expr: 100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes) > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk usage is above 85% for more than 10 minutes"
```

#### Grafana Alerting

Configure notification channels:
1. Go to Alerting → Notification channels
2. Add channels (email, Slack, etc.)
3. Create alert rules in dashboards
4. Test notifications

## Troubleshooting

### Common Issues and Solutions

#### Services Not Starting

**Problem**: Docker containers fail to start
```bash
# Check container logs
docker logs prometheus
docker logs grafana
docker logs loki
docker logs node-exporter
docker logs promtail

# Check Docker Compose status
docker-compose ps
docker-compose logs
```

**Solution**: 
- Verify configuration files syntax
- Check port conflicts
- Ensure sufficient disk space
- Verify file permissions

#### Prometheus Not Scraping Targets

**Problem**: Targets showing as DOWN in Prometheus
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets
```

**Solution**:
- Verify network connectivity between nodes
- Check firewall rules
- Confirm Node Exporter is running on target nodes
- Validate Prometheus configuration

#### Grafana Data Source Issues

**Problem**: Cannot connect to Prometheus/Loki
**Solution**:
- Verify data source URLs
- Check service availability
- Test connectivity from Grafana container
- Review Grafana logs

#### Loki Not Receiving Logs

**Problem**: No logs appearing in Grafana
```bash
# Check Promtail logs
docker logs promtail

# Test Loki API
curl http://localhost:3100/loki/api/v1/label
```

**Solution**:
- Verify Promtail configuration
- Check log file permissions
- Confirm network connectivity to Loki
- Validate log paths exist

### Diagnostic Commands

```bash
# System resource check
df -h
free -h
top
htop

# Network connectivity
telnet monitoring-node-ip 9090
telnet monitoring-node-ip 3100
netstat -tulpn | grep -E "(9090|3000|3100|9100|9080)"

# Docker troubleshooting
docker system info
docker system df
docker stats

# Log analysis
journalctl -u docker
tail -f /var/log/syslog
```

### Log Locations

```bash
# Docker logs
docker logs <container_name>

# System logs
/var/log/syslog
/var/log/docker.log

# Application logs (if custom)
~/monitoring/logs/
```

## Maintenance

### Regular Maintenance Tasks

#### Daily Tasks
- Monitor dashboard alerts
- Check system resource usage
- Review error logs
- Verify backup status

#### Weekly Tasks
- Review Prometheus storage usage
- Clean up old Docker images
- Update security patches
- Check disk space trends

#### Monthly Tasks
- Review and update alert rules
- Performance optimization
- Security audit
- Documentation updates

### Data Retention Configuration

#### Prometheus Retention
```bash
# Modify prometheus service in docker-compose.yml
command:
  - '--storage.tsdb.retention.time=30d'
  - '--storage.tsdb.retention.size=10GB'
```

#### Loki Retention
```yaml
# In loki-config.yaml
table_manager:
  retention_deletes_enabled: true
  retention_period: 744h  # 31 days
```

### Backup Procedures

#### Configuration Backup
```bash
# Create backup directory
mkdir -p ~/monitoring-backup/$(date +%Y%m%d)

# Backup configurations
cp ~/monitoring/docker-compose.yml ~/monitoring-backup/$(date +%Y%m%d)/
cp ~/monitoring/prometheus.yml ~/monitoring-backup/$(date +%Y%m%d)/
cp ~/monitoring/loki-config.yaml ~/monitoring-backup/$(date +%Y%m%d)/
cp ~/monitoring/promtail-config.yaml ~/monitoring-backup/$(date +%Y%m%d)/

# Backup Grafana dashboards
docker exec grafana grafana-cli admin export-dashboard > ~/monitoring-backup/$(date +%Y%m%d)/dashboards.json
```

#### Data Backup
```bash
# Stop services
docker-compose down

# Backup volumes
docker run --rm -v monitoring_prometheus_data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus-data-$(date +%Y%m%d).tar.gz -C /data .
docker run --rm -v monitoring_grafana_data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-data-$(date +%Y%m%d).tar.gz -C /data .
docker run --rm -v monitoring_loki_data:/data -v $(pwd):/backup alpine tar czf /backup/loki-data-$(date +%Y%m%d).tar.gz -C /data .

# Start services
docker-compose up -d
```

### Updates and Upgrades

#### Updating Container Images
```bash
# Update all images
docker-compose pull

# Restart services with new images
docker-compose down
docker-compose up -d

# Clean up old images
docker image prune -f
```

#### System Updates
```bash
# Update Ubuntu packages
sudo apt update && sudo apt upgrade -y

# Update Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### Performance Tuning

#### Prometheus Optimization
- Adjust scrape intervals based on requirements
- Configure recording rules for complex queries
- Optimize storage settings
- Implement federation for large deployments

#### Grafana Optimization
- Use template variables for dynamic dashboards
- Implement query caching
- Optimize panel queries
- Set appropriate refresh intervals

## Security Considerations

### Network Security

#### Firewall Configuration
```bash
# Monitoring node - restrictive approach
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow from trusted-subnet to any port 22
sudo ufw allow from trusted-subnet to any port 3000
sudo ufw allow from worker-nodes to any port 9090
sudo ufw allow from worker-nodes to any port 3100
sudo ufw enable
```

#### VPN/Private Network
- Deploy monitoring stack on private network
- Use VPN for external access
- Implement network segmentation
- Use jump hosts for SSH access

### Authentication and Authorization

#### Grafana Security
```bash
# Change default credentials immediately
# Configure LDAP/OAuth integration
# Implement role-based access control
# Enable session security
```

#### Prometheus Security
- Implement basic authentication
- Use reverse proxy (nginx/Apache)
- Configure IP whitelisting
- Enable TLS/SSL

### Container Security

#### Docker Security Best Practices
```bash
# Run containers as non-root user
# Use official images only
# Regularly update images
# Implement resource limits
# Use Docker secrets for sensitive data
```

#### Example Secure Configuration
```yaml
services:
  grafana:
    image: grafana/grafana:latest
    user: "472:472"  # grafana user
    environment:
      - GF_SECURITY_ADMIN_PASSWORD_FILE=/run/secrets/grafana_password
    secrets:
      - grafana_password
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'

secrets:
  grafana_password:
    file: ./secrets/grafana_password.txt
```

### Data Security

#### Encryption
- Enable TLS for all web interfaces
- Encrypt data at rest
- Use encrypted communication between components
- Implement log sanitization

#### Access Control
- Implement principle of least privilege
- Regular access reviews
- Multi-factor authentication
- Audit logging

### Monitoring Security Events

#### Security Dashboard
Create dashboards to monitor:
- Failed login attempts
- Unusual network traffic
- System changes
- Resource anomalies

#### Security Alerts
```yaml
# Security-focused alert rules
- alert: SuspiciousLoginAttempts
  expr: increase(node_ssh_failed_attempts_total[5m]) > 5
  for: 1m
  labels:
    severity: warning
  annotations:
    summary: "Multiple failed SSH attempts detected"

- alert: UnusualNetworkTraffic
  expr: rate(node_network_receive_bytes_total[5m]) > 100000000  # 100MB/s
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "Unusual network traffic detected"
```

## Conclusion

This monitoring stack provides comprehensive observability for your infrastructure with:

- **Metrics Collection**: Complete system and application metrics
- **Log Aggregation**: Centralized log management and analysis
- **Visualization**: Rich dashboards and real-time monitoring
- **Alerting**: Proactive issue detection and notification
- **Scalability**: Easy to add new nodes and services
- **Automation**: Ansible-driven deployment and configuration

### Next Steps

1. **Customize Dashboards**: Create specific dashboards for your applications
2. **Extend Monitoring**: Add application-specific exporters
3. **Implement Alerting**: Configure notification channels and alert rules
4. **Optimize Performance**: Fine-tune based on your workload
5. **Enhance Security**: Implement additional security measures
6. **Plan Scaling**: Prepare for horizontal scaling needs

### Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Node Exporter Documentation](https://github.com/prometheus/node_exporter)
- [Promtail Documentation](https://grafana.com/docs/loki/latest/clients/promtail/)

For issues and contributions, visit the [GitHub repository](https://github.com/KasiRamaKrishnan/portable_monitoring_agent).
