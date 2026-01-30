#!/usr/bin/env bash

# Install Crossview into the current Kubernetes cluster using Helm.
#
# This script exists to provide a "one command" install for local dev (Minikube).
# It aligns with the Helm-based instructions in manuscript/setup/dev.md.

set -euo pipefail

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
NC=$'\033[0m'

die() {
  echo "${RED}ERROR:${NC} $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"
}

need kubectl
need helm

if ! kubectl cluster-info >/dev/null 2>&1; then
  die "Cannot connect to Kubernetes cluster (kubectl cluster-info failed). Is minikube running?"
fi

CHART_VERSION="${CROSSVIEW_CHART_VERSION:-3.4.0}"
NAMESPACE="${CROSSVIEW_NAMESPACE:-crossview}"
DB_PASSWORD="${CROSSVIEW_DB_PASSWORD:-change-me}"
SESSION_SECRET="${CROSSVIEW_SESSION_SECRET:-}"

if [[ -z "$SESSION_SECRET" ]]; then
  if command -v openssl >/dev/null 2>&1; then
    SESSION_SECRET="$(openssl rand -base64 32)"
  else
    die "openssl not found; set CROSSVIEW_SESSION_SECRET to a random value"
  fi
fi

echo "=== Crossview installation ==="
echo
echo "Namespace:    ${NAMESPACE}"
echo "Chart ver:    ${CHART_VERSION}"
echo

helm repo add crossview https://corpobit.github.io/crossview >/dev/null
helm repo update >/dev/null

helm upgrade --install crossview crossview/crossview \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --version "${CHART_VERSION}" \
  --set secrets.dbPassword="${DB_PASSWORD}" \
  --set secrets.sessionSecret="${SESSION_SECRET}" \
  --set service.type=NodePort

echo
echo "Waiting for deployments..."
kubectl wait -n "${NAMESPACE}" --for=condition=Available deploy/crossview-postgres --timeout=600s || true
kubectl wait -n "${NAMESPACE}" --for=condition=Available deploy/crossview --timeout=600s

echo
echo "${GREEN}✓ Crossview installed${NC}"
echo
echo "Access options:"
echo "  - Minikube tunnel URL (keep the terminal open):"
echo "      minikube service -n ${NAMESPACE} crossview-service"
echo "  - Port-forward (works everywhere):"
echo "      kubectl port-forward -n ${NAMESPACE} deploy/crossview 3001:3001"
echo "      open http://localhost:3001"
