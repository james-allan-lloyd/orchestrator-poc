#!/bin/bash

set -e

CLUSTER_NAME="kratix-poc"

echo "🚀 Stage 1: Setting up Kind cluster with ingress and port mappings..."

# Check if cluster already exists
if ! kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  # Create kind config with port mappings for SSH and ingress
  echo "🔧 Creating Kind cluster '${CLUSTER_NAME}'..."
  kind create cluster --name "${CLUSTER_NAME}" --config manifests/kind-cluster-config.yaml
fi

echo "📦 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

echo "⏳ Waiting for ingress controller pod to exist..."
until kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller -o name 2>/dev/null | grep -q pod/; do
  sleep 2
done

echo "⏳ Waiting for ingress controller to be ready..."
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

echo "✅ Stage 1 Complete!"
echo ""
echo "📋 Cluster Information:"
echo "  Cluster: ${CLUSTER_NAME}"
echo "  Ingress: NGINX (ready)"
echo "  Port Mappings:"
echo "    - HTTP: localhost:8080 → cluster:80"
echo "    - HTTPS: localhost:8443 → cluster:443"
echo "    - SSH: localhost:30222 → cluster:30222"
echo ""
echo "🔧 Verification:"
kubectl get nodes
kubectl get pods -n ingress-nginx

echo ""
echo "🎯 Next: Run ./scripts/02-install-kratix.sh"

