#!/bin/bash

set -e

echo "🚀 Stage 2: Installing Kratix platform..."

# Check cluster is ready
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "❌ Kubernetes cluster not accessible. Run Stage 1 first."
  exit 1
fi

echo "📦 Installing Kratix components..."
kubectl apply -f https://github.com/syntasso/kratix/releases/download/latest/kratix-quick-start-installer.yaml

echo "⏳ Waiting for installation to complete..."
kubectl wait --for=condition=complete job/kratix-quick-start-installer --timeout=420s

echo "🔧 Applying UID 65534 patch to fix Git operations..."

# Create temporary patch for Kratix deployment to use existing nobody user
cat >/tmp/kratix-user-patch.yaml <<'EOF'
spec:
  template:
    spec:
      containers:
      - name: manager
        env:
        - name: HOME
          value: /tmp
        - name: USER
          value: kratix
        - name: GIT_AUTHOR_NAME
          value: kratix
        - name: GIT_AUTHOR_EMAIL
          value: kratix@platform.local
        - name: GIT_COMMITTER_NAME
          value: kratix
        - name: GIT_COMMITTER_EMAIL
          value: kratix@platform.local
        securityContext:
          runAsUser: 65534
          runAsGroup: 65534
          runAsNonRoot: true
EOF

echo "🔧 Patching Kratix deployment..."
kubectl patch deployment kratix-platform-controller-manager -n kratix-platform-system --patch-file /tmp/kratix-user-patch.yaml

echo "⏳ Waiting for Kratix to be ready..."
kubectl wait --for=condition=available deployment/kratix-platform-controller-manager -n kratix-platform-system --timeout=180s

echo "🗑️  Removing default BucketStateStore destination..."
kubectl delete destination worker-1 --ignore-not-found=true

echo "✅ Stage 2 Complete!"
echo ""
echo "📋 Kratix Status:"
kubectl get pods -n kratix-platform-system
echo ""
echo "🔧 Verification:"
kubectl get destinations
echo ""
echo "🎯 Next: Run ./scripts/03-setup-gitea.sh"

