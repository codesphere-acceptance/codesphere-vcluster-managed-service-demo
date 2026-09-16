#!/usr/bin/env bash
# Deploy the demo-app Helm chart into the team's vCluster.
#
# The Codesphere base image ships `helm` + `kubectl`, and booking the vCluster
# managed service auto-mounts its kubeconfig at ~/.kube/config. So the entire
# deployment is a single, reproducible `helm upgrade --install` — no extra
# tooling to install, nothing assembled by hand.
#
# RELEASE / NAMESPACE must match the headless route target in ci.yml:
#   http://<RELEASE>-x-<NAMESPACE>-x-k8s.rg-<teamId>.svc.cluster.local:80
set -euo pipefail

RELEASE="${RELEASE:-demo-app}"
NAMESPACE="${NAMESPACE:-demo}"
CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../chart" && pwd)"

echo "== vCluster context =="
kubectl config current-context || {
  echo "error: no kubeconfig — book the team's vCluster (virtual-k8s) managed service first (Managed Services UI / Public API)" >&2
  exit 1
}

echo "== helm upgrade --install ${RELEASE} (namespace: ${NAMESPACE}) =="
helm upgrade --install "$RELEASE" "$CHART_DIR" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --wait \
  --timeout 5m

kubectl -n "$NAMESPACE" rollout status "deployment/${RELEASE}" --timeout=5m

echo "Deployed ${RELEASE} into namespace ${NAMESPACE} of the vCluster."
