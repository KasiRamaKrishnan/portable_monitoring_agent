#!/usr/bin/env bash
# =============================================================================
# Kubernetes Monitoring Stack — Deploy / Destroy / Status
#
# Components deployed:
#   - Grafana Alloy DaemonSet   (replaces Node Exporter + Promtail)
#   - Prometheus                (metrics storage, remote_write receiver)
#   - Loki                      (log storage)
#   - Alertmanager              (alert routing)
#   - kube-state-metrics        (Kubernetes object metrics)
#   - Grafana                   (dashboards, NodePort 30300)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="monitoring"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

command -v kubectl &>/dev/null || error "kubectl not found."
kubectl cluster-info &>/dev/null 2>&1 || error "Cannot reach Kubernetes cluster. Check kubeconfig."

ACTION="${1:-deploy}"
case "$ACTION" in
  deploy|destroy|status) ;;
  *) error "Usage: $0 [deploy|destroy|status]" ;;
esac

# ─── STATUS ───────────────────────────────────────────────────────────────────
if [[ "$ACTION" == "status" ]]; then
  info "Monitoring stack status in namespace: $NAMESPACE"
  echo ""; kubectl get pods        -n "$NAMESPACE" -o wide
  echo ""; kubectl get services    -n "$NAMESPACE"
  echo ""; kubectl get daemonsets  -n "$NAMESPACE"
  echo ""; kubectl get deployments -n "$NAMESPACE"
  exit 0
fi

# ─── DESTROY ──────────────────────────────────────────────────────────────────
if [[ "$ACTION" == "destroy" ]]; then
  warn "This will DELETE all monitoring resources in namespace '${NAMESPACE}'."
  read -r -p "Are you sure? [y/N] " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || { info "Cancelled."; exit 0; }
  for component in grafana alertmanager loki kube-state-metrics prometheus alloy; do
    info "Deleting $component ..."; kubectl delete --ignore-not-found -f "${SCRIPT_DIR}/${component}/"
  done
  kubectl delete --ignore-not-found namespace "$NAMESPACE"
  success "All monitoring resources deleted."
  exit 0
fi

# ─── DEPLOY ───────────────────────────────────────────────────────────────────
info "Deploying monitoring stack to Kubernetes ..."

# 1. Namespace
info "Creating namespace: ${NAMESPACE}"
kubectl apply -f "${SCRIPT_DIR}/namespace.yaml"

# 2. Prometheus (RBAC → ConfigMap → Deployment → Service)
info "Deploying Prometheus ..."
kubectl apply -f "${SCRIPT_DIR}/prometheus/clusterrole.yaml"
kubectl apply -f "${SCRIPT_DIR}/prometheus/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/prometheus/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/prometheus/service.yaml"

# 3. Alertmanager
info "Deploying Alertmanager ..."
kubectl apply -f "${SCRIPT_DIR}/alertmanager/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/alertmanager/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/alertmanager/service.yaml"

# 4. Loki
info "Deploying Loki ..."
kubectl apply -f "${SCRIPT_DIR}/loki/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/loki/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/loki/service.yaml"

# 5. kube-state-metrics
info "Deploying kube-state-metrics ..."
kubectl apply -f "${SCRIPT_DIR}/kube-state-metrics/clusterrole.yaml"
kubectl apply -f "${SCRIPT_DIR}/kube-state-metrics/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/kube-state-metrics/service.yaml"

# 6. Grafana Alloy DaemonSet (replaces Node Exporter + Promtail)
info "Deploying Grafana Alloy DaemonSet ..."
kubectl apply -f "${SCRIPT_DIR}/alloy/clusterrole.yaml"
kubectl apply -f "${SCRIPT_DIR}/alloy/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/alloy/daemonset.yaml"
kubectl apply -f "${SCRIPT_DIR}/alloy/service.yaml"

# 7. Grafana
info "Deploying Grafana ..."
kubectl apply -f "${SCRIPT_DIR}/grafana/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/grafana/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/grafana/service.yaml"

echo ""
info "Waiting for deployments to be ready (timeout: 120s) ..."
for deploy in prometheus alertmanager loki grafana kube-state-metrics; do
  kubectl rollout status deployment/"$deploy" -n "$NAMESPACE" --timeout=120s \
    && success "$deploy is ready" \
    || warn "$deploy rollout timed out — check: kubectl logs -n $NAMESPACE deploy/$deploy"
done

echo ""
success "Monitoring stack deployed!"
echo ""
echo "─────────────────────────────────────────────────────────────────────"
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "<node-ip>")
echo "  Grafana      → http://${NODE_IP}:30300  (admin / admin)"
echo "  Prometheus   → kubectl port-forward -n monitoring svc/prometheus   9090:9090"
echo "  Loki         → kubectl port-forward -n monitoring svc/loki         3100:3100"
echo "  Alertmanager → kubectl port-forward -n monitoring svc/alertmanager 9093:9093"
echo "  Alloy UI     → kubectl port-forward -n monitoring ds/alloy         12345:12345"
echo "─────────────────────────────────────────────────────────────────────"
