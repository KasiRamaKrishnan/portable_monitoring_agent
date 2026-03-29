#!/bin/bash
# =============================================================================
# Portable Monitoring Agent - Unified Installer
# Supports: Linux (default), Windows (--windows), Kubernetes (--kubernetes)
# =============================================================================
set -e

# ─── Argument parsing ─────────────────────────────────────────────────────────
DEPLOY_LINUX=false
DEPLOY_WINDOWS=false
DEPLOY_KUBERNETES=false

if [[ $# -eq 0 ]]; then
  # Default: deploy Linux monitoring stack (original behaviour)
  DEPLOY_LINUX=true
fi

for arg in "$@"; do
  case "$arg" in
    --linux)      DEPLOY_LINUX=true ;;
    --windows)    DEPLOY_WINDOWS=true ;;
    --kubernetes) DEPLOY_KUBERNETES=true ;;
    --all)        DEPLOY_LINUX=true; DEPLOY_WINDOWS=true; DEPLOY_KUBERNETES=true ;;
    --help|-h)
      echo "Usage: $0 [--linux] [--windows] [--kubernetes] [--all]"
      echo ""
      echo "  --linux       Deploy Node Exporter + Promtail on Linux nodes (default)"
      echo "  --windows     Deploy Windows Exporter + Promtail on Windows nodes"
      echo "  --kubernetes  Deploy full monitoring stack on Kubernetes"
      echo "  --all         Deploy all three platforms"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Run '$0 --help' for usage."
      exit 1
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Linux / Ansible setup ───────────────────────────────────────────────────
if $DEPLOY_LINUX || $DEPLOY_WINDOWS; then
  echo ""
  echo "=== Setting up Ansible ==="

  if ! command -v ansible &>/dev/null; then
    echo "Updating and upgrading system packages..."
    sudo apt update -y
    sudo apt upgrade -y

    echo "Installing dependencies..."
    sudo apt install -y software-properties-common

    echo "Adding Ansible PPA repository..."
    sudo add-apt-repository --yes --update ppa:ansible/ansible

    echo "Installing Ansible..."
    sudo apt install -y ansible
  else
    echo "Ansible already installed: $(ansible --version | head -1)"
  fi

  echo "Verifying Ansible installation..."
  ansible --version

  echo "Configuring Ansible (disable SSH host key checking)..."
  mkdir -p ~/.ansible
  cat <<EOF > ~/.ansible.cfg
[defaults]
host_key_checking = False
EOF

  if ! grep -q "ANSIBLE_HOST_KEY_CHECKING=False" ~/.bashrc; then
    echo "export ANSIBLE_HOST_KEY_CHECKING=False" >> ~/.bashrc
  fi
  # shellcheck disable=SC1090
  source ~/.bashrc

  echo "Ansible setup complete."
fi

# ─── Linux Deployment ────────────────────────────────────────────────────────
if $DEPLOY_LINUX; then
  echo ""
  echo "=== Deploying Linux Monitoring Stack ==="
  cd "${SCRIPT_DIR}/monitoring-deploy"

  echo "Running worker nodes playbook..."
  ansible-playbook -i inventory.ini playbooks/playbook-workers.yml

  echo "Running monitor node playbook..."
  ansible-playbook -i inventory.ini playbooks/playbook-monitor.yml

  echo ""
  echo "Linux monitoring stack deployed."
  echo "  Grafana:    http://<monitor-ip>:3000  (admin/admin)"
  echo "  Prometheus: http://<monitor-ip>:9090"
  echo "  Loki:       http://<monitor-ip>:3100"
fi

# ─── Windows Deployment ──────────────────────────────────────────────────────
if $DEPLOY_WINDOWS; then
  echo ""
  echo "=== Deploying Windows Monitoring Stack ==="

  # Ensure pywinrm is available for Ansible WinRM connections
  if ! python3 -c "import winrm" 2>/dev/null; then
    echo "Installing pywinrm (required for Ansible Windows management)..."
    pip3 install --user pywinrm
  fi

  # Install required Ansible collections
  ansible-galaxy collection install ansible.windows community.windows --ignore-errors 2>/dev/null || true

  cd "${SCRIPT_DIR}/monitoring-deploy"

  # Check if any Windows hosts are defined
  WINDOWS_HOSTS=$(ansible -i inventory.ini windows_workers --list-hosts 2>/dev/null | grep -v "hosts (" | wc -l || echo 0)
  if [[ "$WINDOWS_HOSTS" -eq 0 ]]; then
    echo ""
    echo "WARNING: No Windows hosts found in inventory.ini."
    echo "  Edit monitoring-deploy/inventory.ini and uncomment hosts under [windows_workers]."
    echo "  Also set ansible_password or use ansible-vault for credentials."
    echo ""
  else
    echo "Running Windows nodes playbook..."
    ansible-playbook -i inventory.ini playbooks/playbook-windows.yml
    echo ""
    echo "Windows monitoring stack deployed."
    echo "  Windows Exporter metrics: http://<windows-ip>:9182/metrics"
    echo "  Promtail logs shipped to: http://<monitor-ip>:3100"
  fi
fi

# ─── Kubernetes Deployment ───────────────────────────────────────────────────
if $DEPLOY_KUBERNETES; then
  echo ""
  echo "=== Deploying Kubernetes Monitoring Stack ==="

  if ! command -v kubectl &>/dev/null; then
    echo "ERROR: kubectl not found. Please install kubectl and configure your kubeconfig first."
    exit 1
  fi

  if ! kubectl cluster-info &>/dev/null; then
    echo "ERROR: Cannot reach Kubernetes cluster. Check your kubeconfig."
    exit 1
  fi

  chmod +x "${SCRIPT_DIR}/kubernetes/deploy.sh"
  "${SCRIPT_DIR}/kubernetes/deploy.sh" deploy

  echo ""
  echo "Kubernetes monitoring stack deployed."
  echo "  Port-forward Grafana: kubectl port-forward -n monitoring svc/grafana 3000:3000"
  echo "  Port-forward Prometheus: kubectl port-forward -n monitoring svc/prometheus 9090:9090"
fi

echo ""
echo "=== Installation complete! ==="
