# Portable Monitoring Agent

A self-hosted, multi-platform observability framework that monitors **Linux servers**, **Windows servers**, and **Kubernetes clusters** from a single central stack.

Built on the modern Grafana open-source stack. One agent — **Grafana Alloy** — replaces Node Exporter + Windows Exporter + Promtail across all platforms.

---

## Stack Components

| Component | Role | Port |
|-----------|------|------|
| **Grafana Alloy** | Unified agent — collects metrics AND logs on every node | 12345 (UI) |
| **Prometheus** | Metrics storage — receives pushes from all Alloy agents | 9090 |
| **Loki** | Log storage — receives log pushes from all Alloy agents | 3100 |
| **Grafana** | Dashboards and visualization | 3000 |
| **Alertmanager** | Alert routing (Slack, email, PagerDuty, etc.) | 9093 |
| **kube-state-metrics** | Kubernetes object metrics (deployments, pods, nodes) | 8080 |

---

## How It Works

### Old approach (3 agents per platform)
```
Linux   → Node Exporter + Promtail
Windows → Windows Exporter + Promtail
K8s     → Node Exporter DaemonSet + Promtail DaemonSet + kube-state-metrics
```

### This framework (1 agent everywhere)
```
Linux   ──┐
Windows ──┼──→  Grafana Alloy  →  pushes metrics → Prometheus
K8s     ──┘                    →  pushes logs    → Loki
                                                 → Grafana (dashboards)
                                                 → Alertmanager (alerts)
```

### Why push instead of pull?
The old approach required Prometheus to know every worker's IP address and scrape them. With Grafana Alloy's **push model (remote_write)**:
- Workers push to the monitor server — Prometheus needs no IP list
- Firewall-friendly — only outbound connections from workers
- Adding a new node requires no Prometheus config change

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    MONITOR SERVER                        │
│   docker-compose — each service in its own container     │
│                                                          │
│  ┌────────────┐  ┌──────┐  ┌─────────┐  ┌───────────┐  │
│  │ Prometheus │  │ Loki │  │ Grafana │  │Alertmanager│  │
│  │   :9090    │  │:3100 │  │  :3000  │  │   :9093   │  │
│  └────────────┘  └──────┘  └─────────┘  └───────────┘  │
└──────────────────────────────────────────────────────────┘
          ▲ remote_write (metrics)    ▲ push (logs)
          │                          │
┌─────────┴──────────────────────────┴──────────────────┐
│               GRAFANA ALLOY  (on every node)          │
│  • Linux systemd service                              │
│  • Windows service                                    │
│  • Kubernetes DaemonSet                               │
│                                                       │
│  Collects:  System metrics + Logs + K8s Events        │
└───────────────────────────────────────────────────────┘
```

![Architecture diagram](https://github.com/user-attachments/assets/b7d5b25c-7f59-4373-a139-f852fc4ea59d)

---

## Directory Structure

```
portable_monitoring_agent/
├── versions.env                          # Single source of truth for all component versions
├── docker-compose.yml                    # Monitor server — 4 independent containers
├── install.sh                            # Unified installer (all platforms)
│
├── config/                               # Monitor server configuration
│   ├── prometheus/
│   │   ├── prometheus.yml                # Push model — no worker IPs needed
│   │   └── alerts.yml                    # Alert rules: Linux, Windows, Kubernetes
│   ├── loki/
│   │   └── loki-config.yaml             # Persistent storage, TSDB v13, 30-day retention
│   └── alertmanager/
│       └── alertmanager.yml             # Notification channels (Slack, email, PagerDuty)
│
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/datasources.yaml  # Prometheus + Loki + Alertmanager auto-wired
│   │   └── dashboards/dashboards.yml
│   └── dashboards/
│       ├── node-exporter.json            # Linux system metrics dashboard
│       ├── windows-exporter.json         # Windows system metrics dashboard
│       ├── kubernetes.json               # Kubernetes cluster overview dashboard
│       └── loki-apps-dashboard.json      # Log analysis dashboard
│
├── monitoring-deploy/                    # Ansible — deploys Alloy on nodes
│   ├── inventory.ini                     # Host list: Linux workers + Windows workers
│   ├── group_vars/all.yml
│   ├── playbooks/
│   │   ├── playbook-monitor.yml          # Deploys monitor server via docker-compose
│   │   ├── playbook-linux.yml            # Installs Alloy on Linux (systemd service)
│   │   └── playbook-windows.yml          # Installs Alloy on Windows (Windows service)
│   └── files/
│       ├── alloy-linux.alloy.j2          # Alloy config for Linux nodes
│       └── alloy-windows.alloy.j2        # Alloy config for Windows nodes
│
└── kubernetes/                           # Kubernetes manifests
    ├── namespace.yaml
    ├── deploy.sh                         # deploy / destroy / status
    ├── alloy/                            # Alloy DaemonSet (replaces node-exporter + promtail)
    ├── prometheus/                       # Prometheus with remote_write receiver enabled
    ├── loki/                             # Loki with persistent storage
    ├── grafana/                          # Grafana with pre-wired datasources
    ├── alertmanager/                     # Alertmanager
    └── kube-state-metrics/               # Kubernetes object metrics
```

---

## Prerequisites

### Monitor Server
| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| OS | Ubuntu 20.04+ | Ubuntu 22.04 |
| CPU | 2 cores | 4 cores |
| RAM | 4 GB | 8 GB |
| Disk | 50 GB | 100 GB SSD |

### Linux Worker Nodes
- Ubuntu 18.04+ or any systemd-based Linux
- SSH access from Ansible control host
- Outbound HTTP access to monitor server (port 9090, 3100)

### Windows Worker Nodes
- Windows Server 2016+ or Windows 10+
- WinRM enabled (run `Enable-PSRemoting` as Administrator)
- Outbound HTTP access to monitor server (port 9090, 3100)

### Kubernetes
- kubectl configured with cluster access
- Cluster version 1.19+

### Control Host (where you run Ansible)
- Ansible installed
- Python 3.6+
- `pywinrm` for Windows deployments (`pip install pywinrm`)

---

## Quick Start

### Option A — Deploy everything

```bash
git clone https://github.com/KasiRamaKrishnan/portable_monitoring_agent.git
cd portable_monitoring_agent

# Edit inventory with your server IPs and SSH key
vim monitoring-deploy/inventory.ini

# Deploy all platforms
./install.sh --all
```

### Option B — Deploy selectively

```bash
./install.sh --monitor      # Monitor server only (Prometheus + Loki + Grafana + Alertmanager)
./install.sh --linux        # Grafana Alloy on Linux workers
./install.sh --windows      # Grafana Alloy on Windows workers
./install.sh --kubernetes   # Full stack on Kubernetes
```

### Access the monitoring stack

| Service | URL | Default Login |
|---------|-----|---------------|
| **Grafana** | `http://<monitor-ip>:3000` | admin / admin |
| **Prometheus** | `http://<monitor-ip>:9090` | — |
| **Alertmanager** | `http://<monitor-ip>:9093` | — |
| **Alloy UI** | `http://<any-node-ip>:12345` | — |

> Change the Grafana password after first login.

---

## Configuration

### Step 1 — Set your server IPs

Edit `monitoring-deploy/inventory.ini`:

```ini
[monitor]
monitor_node ansible_host=<YOUR_MONITOR_IP> ansible_user=ubuntu

[workers]
worker1 ansible_host=<LINUX_WORKER_IP_1> ansible_user=ubuntu
worker2 ansible_host=<LINUX_WORKER_IP_2> ansible_user=ubuntu

[windows_workers]
win1 ansible_host=<WINDOWS_WORKER_IP>
# win2 ansible_host=<WINDOWS_WORKER_IP_2>

[windows_workers:vars]
ansible_connection=winrm
ansible_winrm_transport=ntlm
ansible_winrm_server_cert_validation=ignore
ansible_user=Administrator
# ansible_password=<password>  — use ansible-vault, not plain text

[all:vars]
ansible_ssh_private_key_file=~/your-key.pem
monitor_node_ip=<YOUR_MONITOR_IP>
```

### Step 2 — Pin component versions

All versions are managed in one file — `versions.env`:

```bash
ALLOY_VERSION=1.3.1
PROMETHEUS_VERSION=2.52.0
LOKI_VERSION=2.9.4
ALERTMANAGER_VERSION=0.27.0
GRAFANA_VERSION=10.4.1
```

To upgrade a component, change its version here and re-run the installer.

### Step 3 — Configure alerts (optional)

Edit `config/alertmanager/alertmanager.yml` to add your notification channel:

```yaml
receivers:
  - name: 'default'
    slack_configs:
      - channel: '#alerts'
        api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        send_resolved: true
```

Other supported channels: email, PagerDuty, OpsGenie, webhook.

---

## Platform Deployment Details

### Linux Workers

The Ansible playbook installs Grafana Alloy as a **systemd service** via the official Grafana apt repository.

```bash
ansible-playbook -i monitoring-deploy/inventory.ini \
  monitoring-deploy/playbooks/playbook-linux.yml
```

**What Alloy collects on Linux:**
- CPU, memory, disk I/O, filesystem, network, load average
- `/var/log/syslog`, `/var/log/auth.log`, `/var/log/*.log`
- systemd journal (all unit logs)

**Verify deployment:**
```bash
# Check service status on any Linux worker
ssh ubuntu@<worker-ip> systemctl status alloy

# View Alloy's built-in UI
curl http://<worker-ip>:12345/-/ready
```

---

### Windows Workers

The Ansible playbook installs Grafana Alloy as a **Windows service** via the official MSI installer over WinRM.

```bash
# Ensure pywinrm is installed on control host
pip install pywinrm

ansible-playbook -i monitoring-deploy/inventory.ini \
  monitoring-deploy/playbooks/playbook-windows.yml
```

**What Alloy collects on Windows:**
- CPU, memory, disk I/O, disk space, network, services, processes, OS stats
- Windows Event Log: Application, System, Security (errors/warnings)

**Enable WinRM on Windows nodes** (run once as Administrator):
```powershell
Enable-PSRemoting -Force
Set-Item WSMan:\localhost\Service\Auth\Basic -Value $true
Set-Item WSMan:\localhost\Service\AllowUnencrypted -Value $true
```

---

### Kubernetes

Deploys the full monitoring stack in a `monitoring` namespace. Grafana Alloy runs as a **DaemonSet** on every node.

```bash
./kubernetes/deploy.sh deploy    # Deploy full stack
./kubernetes/deploy.sh status    # Check pod/service status
./kubernetes/deploy.sh destroy   # Remove everything
```

**What the Alloy DaemonSet collects:**
- Node metrics via kubelet (`/metrics`) and cAdvisor (`/metrics/cadvisor`)
- kube-state-metrics (deployments, pods, nodes, replica sets)
- All pod container logs (auto-discovered via Kubernetes SD)
- Kubernetes Events as structured logs
- Pods with `prometheus.io/scrape: "true"` annotation

**Access services (local development):**
```bash
kubectl port-forward -n monitoring svc/grafana      3000:3000
kubectl port-forward -n monitoring svc/prometheus   9090:9090
kubectl port-forward -n monitoring svc/loki         3100:3100
kubectl port-forward -n monitoring svc/alertmanager 9093:9093
```

Grafana is also exposed via **NodePort 30300**: `http://<node-ip>:30300`

---

## Open Ports Reference

### Monitor Server
| Port | Service | Who connects |
|------|---------|-------------|
| 22 | SSH | Ansible control host |
| 3000 | Grafana | Browser |
| 9090 | Prometheus | Browser + Alloy agents (remote_write) |
| 3100 | Loki | Alloy agents (log push) |
| 9093 | Alertmanager | Browser + Prometheus |

### Linux / Windows Worker Nodes
| Port | Service | Who connects |
|------|---------|-------------|
| 22 / 5985 | SSH / WinRM | Ansible control host |
| 12345 | Alloy UI | Browser (optional, for debugging) |

> Workers only need **outbound** connections to the monitor server on ports 9090 and 3100. No inbound scraping required.

---

## Dashboards

Four pre-built Grafana dashboards are provisioned automatically:

| Dashboard | Covers |
|-----------|--------|
| **Linux System Metrics** | CPU, memory, disk I/O, filesystem, network, uptime |
| **Windows System Metrics** | CPU, memory, disk space, network, services, processes |
| **Kubernetes Cluster Overview** | Nodes, pods, deployments, container CPU/memory, restarts, network |
| **Loki Log Explorer** | Log search, volume over time, error rate |

---

## Alert Rules

Pre-configured alert rules in `config/prometheus/alerts.yml`:

| Alert | Condition | Severity |
|-------|-----------|----------|
| `InstanceDown` | Any target unreachable > 1 min | critical |
| `AlloyAgentDown` | No agents reporting > 5 min | warning |
| `HighCPUUsageLinux` | CPU > 90% for 5 min | warning |
| `HighCPUUsageWindows` | CPU > 90% for 5 min | warning |
| `HighMemoryUsageLinux` | Memory > 85% for 5 min | warning |
| `HighMemoryUsageWindows` | Memory > 85% for 5 min | warning |
| `DiskSpaceLowLinux` | Disk < 15% free for 5 min | warning |
| `DiskSpaceLowWindows` | Disk < 15% free for 5 min | warning |
| `DiskWillFillIn4Hours` | Disk fill rate projects full in 4h | critical |
| `KubernetesPodCrashLooping` | > 5 restarts in 5 min | critical |
| `KubernetesDeploymentReplicasMismatch` | Desired ≠ available replicas > 5 min | warning |
| `KubernetesNodeNotReady` | Node not ready > 2 min | critical |
| `KubernetesPodOOMKilled` | Container OOM killed | warning |

---

## Useful Queries

### Prometheus (PromQL)

```promql
# CPU usage by node (Linux)
100 - (avg by(hostname) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)

# Memory usage % (Linux)
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage % (Linux)
100 - ((node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100)

# CPU usage (Windows)
100 - (avg by(hostname) (rate(windows_cpu_time_total{mode="idle"}[2m])) * 100)

# Pod restart rate (Kubernetes)
rate(kube_pod_container_status_restarts_total[5m]) * 300

# Top 5 CPU-consuming pods
topk(5, sum by(pod, namespace) (rate(container_cpu_usage_seconds_total[2m])))
```

### Loki (LogQL)

```logql
# All logs from a specific host
{hostname="worker1"}

# Linux auth failures
{job="auth"} |= "Failed password"

# Windows Security events
{log_type="security", platform="windows"}

# Kubernetes pod errors in a namespace
{namespace="production"} |= "error" | json | level="error"

# Kubernetes events (warnings only)
{job="kubernetes-events"} | json | type="Warning"

# Log volume by platform over time
sum by(platform) (rate({job=~".+"}[5m]))
```

---

## Troubleshooting

### Alloy agent is not sending data

```bash
# Linux — check service status and logs
systemctl status alloy
journalctl -u alloy -f

# Check if Alloy can reach the monitor server
curl http://<monitor-ip>:9090/-/healthy
curl http://<monitor-ip>:3100/ready

# View Alloy's built-in debug UI
# Shows pipeline components, errors, and metrics
http://<node-ip>:12345
```

### No metrics in Prometheus

```bash
# Verify remote_write receiver is enabled
curl http://<monitor-ip>:9090/api/v1/status/flags | grep remote-write

# Check if data is arriving (query for any series)
curl 'http://<monitor-ip>:9090/api/v1/query?query=up'
```

### No logs in Loki / Grafana

```bash
# Check Loki is ready
curl http://<monitor-ip>:3100/ready

# Check labels available in Loki
curl http://<monitor-ip>:3100/loki/api/v1/labels

# docker-compose: check Loki container logs
docker compose logs loki
```

### Monitor server containers

```bash
# View status of all containers
docker compose ps

# Tail logs for a specific service
docker compose logs -f prometheus
docker compose logs -f loki
docker compose logs -f grafana
docker compose logs -f alertmanager

# Restart a single service without affecting others
docker compose restart loki
```

### Kubernetes pods not starting

```bash
# Check pod status
kubectl get pods -n monitoring

# Describe a failing pod
kubectl describe pod <pod-name> -n monitoring

# View pod logs
kubectl logs -n monitoring deployment/prometheus
kubectl logs -n monitoring daemonset/alloy
```

---

## Maintenance

### Upgrading a component

1. Update the version in `versions.env`
2. Re-run the relevant installer command:

```bash
# Monitor server upgrade
docker compose pull && docker compose up -d

# Linux workers upgrade (re-runs Ansible)
./install.sh --linux

# Kubernetes upgrade
kubectl set image daemonset/alloy alloy=grafana/alloy:vNEW_VERSION -n monitoring
kubectl rollout status daemonset/alloy -n monitoring
```

### Backup

```bash
# Back up configuration files
BACKUP_DIR=~/monitoring-backup/$(date +%Y%m%d)
mkdir -p "$BACKUP_DIR"
cp -r config/ grafana/ versions.env docker-compose.yml "$BACKUP_DIR/"

# Back up Prometheus data
docker run --rm \
  -v portable_monitoring_agent_prometheus_data:/data \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf /backup/prometheus-data.tar.gz -C /data .

# Back up Loki data
docker run --rm \
  -v portable_monitoring_agent_loki_data:/data \
  -v "$BACKUP_DIR":/backup \
  alpine tar czf /backup/loki-data.tar.gz -C /data .
```

### Data retention

Configured in `config/prometheus/prometheus.yml` (30 days default):
```yaml
# docker-compose.yml — prometheus command flags
--storage.tsdb.retention.time=30d
--storage.tsdb.retention.size=20GB
```

Loki retention configured in `config/loki/loki-config.yaml` (30 days default):
```yaml
limits_config:
  retention_period: 720h   # 30 days
```

---

## Security Notes

- **Grafana password**: Change the default `admin/admin` immediately. Set `GF_SECURITY_ADMIN_PASSWORD` in a `.env` file (gitignored) rather than editing `docker-compose.yml`.
- **Windows credentials**: Use `ansible-vault encrypt_string` for the WinRM password — never commit plain-text passwords to git.
- **Network**: Workers only need outbound access on ports 9090 and 3100 to the monitor server. No inbound ports need to be opened on workers.
- **Loki**: Authentication is disabled by default (`auth_enabled: false`). For production, place Loki behind a reverse proxy with basic auth or use Grafana's built-in auth proxy.

---

## Resources

- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/latest/)
- [Grafana Alloy Component Reference](https://grafana.com/docs/alloy/latest/reference/components/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Alertmanager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)

For issues and contributions, visit the [GitHub repository](https://github.com/KasiRamaKrishnan/portable_monitoring_agent).
