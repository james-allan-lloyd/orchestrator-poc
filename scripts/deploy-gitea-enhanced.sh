#!/bin/bash

set -e

# Source central Gitea configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/gitea-config.sh"

echo "🚀 Deploying Enhanced Gitea with Actions and Persistent Storage..."

echo "🗑️  Step 1: Removing existing Gitea installation..."
kubectl delete -f manifests/gitea-install-enhanced.yaml --ignore-not-found=true
kubectl delete pvc gitea-storage -n gitea --ignore-not-found=true

echo "⏳ Waiting for cleanup to complete..."
sleep 10

echo "🔑 Step 2: Generating Gitea credentials and secrets..."
./scripts/generate-gitea-credentials.sh

# Step 3: Deploy enhanced Gitea
echo "🏗️  Step 3: Deploying enhanced Gitea..."
kubectl apply -f manifests/gitea-install-enhanced.yaml

# Step 4: Wait for deployment
echo "⏳ Step 4: Waiting for Gitea to be ready..."
kubectl wait --for=condition=ready pod -l app=gitea -n gitea --timeout=300s

# Step 5: Display status and credentials
echo ""
echo "✅ Enhanced Gitea deployment completed!"
echo ""
echo "📋 Deployment Information:"
echo "  Namespace: gitea"
echo "  Storage: 5GB persistent volume"
echo "  Actions: Enabled"
echo "  HTTP URL: $(gitea_local_url) (via port-forward)"
echo "  SSH: localhost:30222"
echo ""

# Get credentials
GITEA_USERNAME=$(kubectl get secret gitea-admin -n gitea -o jsonpath='{.data.username}' | base64 -d)
GITEA_PASSWORD=$(kubectl get secret gitea-admin -n gitea -o jsonpath='{.data.password}' | base64 -d)

echo "🔐 Admin Credentials:"
echo "  Username: $GITEA_USERNAME"
echo "  Password: $GITEA_PASSWORD"
echo ""

echo "🔧 Next Steps:"
echo "1. Start port forward: kubectl port-forward -n gitea svc/gitea-http $(echo "$(gitea_local_url)" | cut -d: -f3):443"
echo "2. Access Gitea: $(gitea_local_url)"
echo "3. Login with admin credentials above"
echo "4. Verify Actions are enabled in Admin -> Actions -> Runners"
echo "5. Create runner registration token for Actions runner"
echo ""
echo "🚀 To setup Actions runner:"
echo "  ./scripts/get-runner-token.sh"
echo "  ./scripts/setup-gitea-runner.sh"

