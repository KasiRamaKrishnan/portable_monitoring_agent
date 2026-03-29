#!/usr/bin/env bash
# =============================================================================
# Portable Monitoring Agent — Unified Installer
#
# Platform support:
#   --linux       Deploy Grafana Alloy on Linux worker nodes (default)
#   --windows     Deploy Grafana Alloy on Windows worker nodes
#   --kubernetes  Deploy full monitoring stack on Kubernetes
#   --monitor     Deploy the monitor server (docker-compose stack)
#   --all         Deploy all platforms
#
# Usage examples:
#   ./install.sh                   # Linux workers only
#   ./install.sh --monitor         # Monitor server only
#   ./install.sh --linux --monitor # Monitor + Linux workers
#   ./install.sh --all             # Everything
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Argument parsing ─────────────────────────────────────────────────────────
DEPLOY_MONITOR=false
DEPLOY_LINUX=false
DEPLOY_WINDOWS=false
DEPLOY_KUBERNETES=false

if [[ $# -eq 0 ]]; then
  DEPLOY_LINUX=true
fi

for arg in "$@"; do
  case "$arg" in
    --monitor)    DEPLOY_MONITOR=true ;;
    --linux)      DEPLOY_LINUX=true ;;
    --windows)    DEPLOY_WINDOWS=true ;;
    --kubernetes) DEPLOY_KUBERNETES=true ;;
    --all)        DEPLOY_MONITOR=true; DEPLOY_LINUX=true; DEPLOY_WINDOWS=true; DEPLOY_KUBERNETES=true ;;
    --help|-h)
      echo "Usage: $0 [--monitor] [--linux] [--windows] [--kubernetes] [--all]"
      echo ""
      echo "  --monitor     Deploy monitoring backend (Prometheus, Loki, Grafana, Alertmanager)"
      echo "  --linux       Deploy Grafana Alloy on Linux worker nodes (default)"
      echo "  --windows     Deploy Grafana Alloy on Windows worker nodes"
      echo "  --kubernetes  Deploy full stack on Kubernetes"
      echo "  --all         Deploy all"
      exit 0 ;;
    *)
      echo "Unknown argument: $arg  (run '$0 --help')"
      exit 1 ;;
  esac
done

# ─── Ansible setup (needed for Linux/Windows deployments) ────────────────────
setup_ansible() {
  if command -v ansible &>/dev/null; then
    echo "Ansible already installed: $(ansible --version | head -1)"
    return
  fi
  echo "Installing Ansible ..."
  sudo apt update -y
  sudo apt install -y software-properties-common
  sudo add-apt-repository --yes --update ppa:ansible/ansible
  sudo apt install -y ansible
  mkdir -p ~/.ansible
  cat > ~/.ansible.cfg <<EOF
[defaults]
host_key_checking = False
EOF
  grep -q "ANSIBLE_HOST_KEY_CHECKING=False" ~/.bashrc \
    || echo "export ANSIBLE_HOST_KEY_CHECKING=False" >> ~/.bashrc
  # shellcheck disable=SC1090
  source ~/.bashrc
  echo "Ansible installed: $(ansible --version | head -1)"
}

# ─── Monitor Server ───────────────────────────────────────────────────────────
if $DEPLOY_MONITOR; then
  echo ""
  echo "=== Deploying Monitor Server (docker-compose) ==="
  setup_ansible
  cd "${SCRIPT_DIR}/monitoring-deploy"
  ansible-playbook -i inventory.ini playbooks/playbook-monitor.yml
  echo ""
  echo "Monitor server deployed. Access:"
  echo "  Grafana:      http://<monitor-ip>:3000  (admin / admin)"
  echo "  Prometheus:   http://<monitor-ip>:9090"
  echo "  Loki:         http://<monitor-ip>:3100"
  echo "  Alertmanager: http://<monitor-ip>:9093"
fi

# ─── Linux Workers ────────────────────────────────────────────────────────────
if $DEPLOY_LINUX; then
  echo ""
  echo "=== Deploying Grafana Alloy on Linux Workers ==="
  setup_ansible
  cd "${SCRIPT_DIR}/monitoring-deploy"
  ansible-playbook -i inventory.ini playbooks/playbook-linux.yml
  echo ""
  echo "Grafana Alloy deployed on Linux workers."
  echo "  Each worker's Alloy UI: http://<worker-ip>:12345"
fi

# ─── Windows Workers ──────────────────────────────────────────────────────────
if $DEPLOY_WINDOWS; then
  echo ""
  echo "=== Deploying Grafana Alloy on Windows Workers ==="
  setup_ansible

  if ! python3 -c "import winrm" 2>/dev/null; then
    echo "Installing pywinrm ..."
    pip3 install --user pywinrm
  fi

  ansible-galaxy collection install ansible.windows community.windows \
    --ignore-errors 2>/dev/null || true

  cd "${SCRIPT_DIR}/monitoring-deploy"

  WINDOWS_HOSTS=$(ansible -i inventory.ini windows_workers \
    --list-hosts 2>/dev/null | grep -vc "hosts (" || echo 0)

  if [[ "$WINDOWS_HOSTS" -eq 0 ]]; then
    echo ""
    echo "WARNING: No Windows hosts configured."
    echo "  Edit monitoring-deploy/inventory.ini — uncomment hosts under [windows_workers]."
  else
    ansible-playbook -i inventory.ini playbooks/playbook-windows.yml
    echo "Grafana Alloy deployed on Windows workers."
  fi
fi

# ─── Kubernetes ───────────────────────────────────────────────────────────────
if $DEPLOY_KUBERNETES; then
  echo ""
  echo "=== Deploying Monitoring Stack on Kubernetes ==="
  command -v kubectl &>/dev/null || { echo "ERROR: kubectl not found."; exit 1; }
  kubectl cluster-info &>/dev/null    || { echo "ERROR: Cannot reach Kubernetes cluster."; exit 1; }

  chmod +x "${SCRIPT_DIR}/kubernetes/deploy.sh"
  "${SCRIPT_DIR}/kubernetes/deploy.sh" deploy
fi

echo ""
echo "=== Done ==="
