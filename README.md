# 🔍 Monitoring Agent Deployment with Ansible (Prometheus + Grafana + Loki + Node Exporter + Promtail)

This project automates the deployment of a full monitoring stack using **Ansible**, targeting:

- One **Monitoring Node** (Prometheus + Grafana + Loki + Node Exporter)
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

