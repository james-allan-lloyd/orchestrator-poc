#!/bin/bash

set -e

CLUSTER_NAME="kratix-poc"

echo "🚀 Stage 1: Setting up Kind cluster with ingress and port mappings..."

# Check if cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
  echo "⚠️  Cluster '${CLUSTER_NAME}' already exists!"
  echo "   To recreate, run: kind delete cluster --name ${CLUSTER_NAME}"
  echo "   Then run this script again."
  exit 1
fi

echo "📋 Creating Kind cluster configuration..."

# Create kind config with port mappings for SSH and ingress
cat >/tmp/kind-config.yaml <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 8080
    protocol: TCP
  - containerPort: 443
    hostPort: 8443
    protocol: TCP
  - containerPort: 30222
    hostPort: 30222
    protocol: TCP
EOF

echo "🔧 Creating Kind cluster '${CLUSTER_NAME}'..."
kind create cluster --name "${CLUSTER_NAME}" --config /tmp/kind-config.yaml

echo "📦 Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
sleep 5

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

