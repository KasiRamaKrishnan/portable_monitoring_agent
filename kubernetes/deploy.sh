#!/usr/bin/env bash
# =============================================================================
# Kubernetes Monitoring Stack Deployment Script
# Deploys: Prometheus, Node Exporter, kube-state-metrics, Loki, Promtail, Grafana
# Namespace: monitoring
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="monitoring"

# ─── Colour helpers ───────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ─── Pre-flight checks ────────────────────────────────────────────────────────
command -v kubectl &>/dev/null || error "kubectl not found. Please install it first."
kubectl cluster-info &>/dev/null || error "Cannot reach Kubernetes cluster. Check your kubeconfig."

# ─── Parse arguments ──────────────────────────────────────────────────────────
ACTION="${1:-deploy}"   # deploy | destroy | status
case "$ACTION" in
  deploy|destroy|status) ;;
  *) error "Usage: $0 [deploy|destroy|status]" ;;
esac

apply_or_delete() {
  local op="$1"; shift
  if [[ "$op" == "apply" ]]; then
    kubectl apply -f "$@"
  else
    kubectl delete --ignore-not-found -f "$@"
  fi
}

# ─── STATUS ───────────────────────────────────────────────────────────────────
if [[ "$ACTION" == "status" ]]; then
  info "Monitoring stack status in namespace: $NAMESPACE"
  echo ""
  kubectl get pods      -n "$NAMESPACE" -o wide 2>/dev/null || warn "No pods found"
  echo ""
  kubectl get services  -n "$NAMESPACE"         2>/dev/null || warn "No services found"
  echo ""
  kubectl get daemonsets -n "$NAMESPACE"        2>/dev/null || warn "No daemonsets found"
  echo ""
  kubectl get deployments -n "$NAMESPACE"       2>/dev/null || warn "No deployments found"
  exit 0
fi

# ─── DESTROY ──────────────────────────────────────────────────────────────────
if [[ "$ACTION" == "destroy" ]]; then
  warn "This will DELETE all monitoring resources in namespace '${NAMESPACE}'."
  read -r -p "Are you sure? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { info "Cancelled."; exit 0; }

  for component in grafana promtail loki kube-state-metrics node-exporter prometheus; do
    info "Deleting $component ..."
    kubectl delete --ignore-not-found -f "${SCRIPT_DIR}/${component}/"
  done
  kubectl delete --ignore-not-found namespace "$NAMESPACE"
  success "All monitoring resources deleted."
  exit 0
fi

# ─── DEPLOY ───────────────────────────────────────────────────────────────────
info "Deploying monitoring stack to Kubernetes cluster ..."
echo ""

# 1. Namespace
info "Creating namespace: ${NAMESPACE}"
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

# 2. Prometheus (RBAC + ConfigMap + Deployment + Service)
info "Deploying Prometheus ..."
kubectl apply -f "${SCRIPT_DIR}/prometheus/clusterrole.yaml"
kubectl apply -f "${SCRIPT_DIR}/prometheus/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/prometheus/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/prometheus/service.yaml"

# 3. Node Exporter DaemonSet
info "Deploying Node Exporter DaemonSet ..."
kubectl apply -f "${SCRIPT_DIR}/node-exporter/daemonset.yaml"
kubectl apply -f "${SCRIPT_DIR}/node-exporter/service.yaml"

# 4. kube-state-metrics
info "Deploying kube-state-metrics ..."
kubectl apply -f "${SCRIPT_DIR}/kube-state-metrics/clusterrole.yaml"
kubectl apply -f "${SCRIPT_DIR}/kube-state-metrics/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/kube-state-metrics/service.yaml"

# 5. Loki
info "Deploying Loki ..."
kubectl apply -f "${SCRIPT_DIR}/loki/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/loki/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/loki/service.yaml"

# 6. Promtail DaemonSet
info "Deploying Promtail DaemonSet ..."
kubectl apply -f "${SCRIPT_DIR}/promtail/clusterrole.yaml"
kubectl apply -f "${SCRIPT_DIR}/promtail/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/promtail/daemonset.yaml"

# 7. Grafana
info "Deploying Grafana ..."
kubectl apply -f "${SCRIPT_DIR}/grafana/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/grafana/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/grafana/service.yaml"

echo ""
info "Waiting for deployments to become ready (timeout: 120s) ..."
for deploy in prometheus loki grafana kube-state-metrics; do
  kubectl rollout status deployment/"$deploy" -n "$NAMESPACE" --timeout=120s \
    && success "$deploy is ready" \
    || warn "$deploy rollout timed out — check: kubectl logs -n $NAMESPACE deploy/$deploy"
done

echo ""
success "Monitoring stack deployed!"
echo ""
echo "─────────────────────────────────────────────────────────"
echo " Access Grafana:"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "<node-ip>")
echo "   http://${NODE_IP}:30300   (NodePort)"
echo "   Default credentials: admin / admin"
echo ""
echo " Port-forward (dev/local):"
echo "   kubectl port-forward -n monitoring svc/grafana    3000:3000"
echo "   kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "   kubectl port-forward -n monitoring svc/loki       3100:3100"
echo "─────────────────────────────────────────────────────────"
