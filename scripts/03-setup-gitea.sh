#!/bin/bash

set -e

# Source central Gitea configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/gitea-config.sh"

echo "🚀 Stage 3: Setting up Gitea with Actions runner..."

# Check Kratix is ready
if ! kubectl get deployment kratix-platform-controller-manager -n kratix-platform-system >/dev/null 2>&1; then
    echo "❌ Kratix not found. Run Stage 2 first."
    exit 1
fi

# Helper functions from generate-gitea-credentials.sh
generate_random_string() {
  local length="${1:-32}"
  openssl rand -hex $((length / 2))
}

generate_jwt_secret() {
  openssl rand -base64 64 | tr -d '\n'
}

echo "🗑️  Cleaning up any existing Gitea installation..."
helm uninstall gitea -n gitea --ignore-not-found >/dev/null 2>&1 || true
kubectl delete namespace gitea --ignore-not-found=true
sleep 10

echo "📋 Adding Gitea Helm repository..."
if ! helm repo list | grep -q gitea-charts; then
    helm repo add gitea-charts https://dl.gitea.com/charts/
fi
helm repo update

echo "🔑 Generating Gitea credentials..."

# Create namespace
kubectl create namespace gitea

# Generate admin credentials
echo "🔐 Generating admin credentials..."
GITEA_USERNAME="gitea_admin"
GITEA_PASSWORD=$(generate_random_string 16)

kubectl create secret generic gitea-admin \
  --from-literal=username="$GITEA_USERNAME" \
  --from-literal=password="$GITEA_PASSWORD" \
  --namespace=gitea

# Create compatibility secret in default namespace (only admin credentials)
kubectl create secret generic gitea-credentials \
  --from-literal=username="$GITEA_USERNAME" \
  --from-literal=password="$GITEA_PASSWORD" \
  --namespace=default

# Generate security tokens
echo "🔑 Generating security tokens..."
INTERNAL_TOKEN=$(generate_jwt_secret)
SECRET_KEY=$(generate_random_string 64)
JWT_SECRET=$(generate_jwt_secret)
LFS_JWT_SECRET=$(generate_random_string 43)

kubectl create secret generic gitea-security \
  --from-literal=internal-token="$INTERNAL_TOKEN" \
  --from-literal=secret-key="$SECRET_KEY" \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --from-literal=lfs-jwt-secret="$LFS_JWT_SECRET" \
  --namespace=gitea

echo "🏗️  Installing Gitea via Helm..."
helm install gitea gitea-charts/gitea -n gitea -f manifests/gitea-helm-values.yaml

echo "⏳ Waiting for Gitea to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=gitea -n gitea --timeout=300s

echo "🔗 Setting up port forward for Gitea access..."
kubectl port-forward -n gitea service/gitea-http 3000:3000 > /dev/null 2>&1 &
GITEA_PF_PID=$!
sleep 5

echo "✅ Port forward established (PID: $GITEA_PF_PID)"

echo "🏃 Setting up Actions runner..."
./scripts/setup-gitea-runner.sh

echo "📁 Creating test repository..."

# Configuration for test repo
REPO_NAME="actions-test"
TEST_REPO_DIR="$SCRIPT_DIR/../repos/test-actions"

echo "📦 Creating test repository in Gitea..."
gitea_ensure_port_forward

# Create repository via API
echo "🏗️  Creating repository via API..."
REPO_RESPONSE=$(gitea_curl -s -X POST \
  "$(gitea_local_url)/api/v1/user/repos" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$REPO_NAME\",
    \"description\": \"Test repository for Gitea Actions runner\",
    \"private\": false,
    \"auto_init\": false,
    \"default_branch\": \"main\"
  }")

if echo "$REPO_RESPONSE" | grep -q "already exists"; then
  echo "⚠️  Repository already exists, continuing..."
elif echo "$REPO_RESPONSE" | grep -q "clone_url"; then
  echo "✅ Repository created successfully"
else
  echo "❌ Failed to create repository. Continuing anyway..."
fi

# Initialize and push test repository
if [ -d "$TEST_REPO_DIR" ]; then
    echo "📤 Initializing and pushing test repository..."
    cd "$TEST_REPO_DIR"

    # Initialize git if not already done
    if [ ! -d ".git" ]; then
      git init
      git checkout -b main 2>/dev/null || git checkout main
    fi

    # Configure git
    git config user.name "Test User" 2>/dev/null || true
    git config user.email "test@example.com" 2>/dev/null || true
    gitea_configure_git_ssl

    # Add remote if not exists  
    REMOTE_URL="$(gitea_local_url)/$GITEA_USERNAME/$REPO_NAME.git"
    if ! git remote get-url origin >/dev/null 2>&1; then
      git remote add origin "$REMOTE_URL"
    else
      git remote set-url origin "$REMOTE_URL"
    fi

    # Add, commit and push
    git add .
    git commit -m "Add Gitea Actions test workflow" || git commit -m "Update test repository" || true

    # Push with credentials
    echo "🚀 Pushing to repository..."
    git push "$(gitea_local_url | sed "s|://|://$GITEA_USERNAME:$GITEA_PASSWORD@|")/$GITEA_USERNAME/$REPO_NAME.git" main || echo "⚠️  Push failed, repository may already be up to date"
else
    echo "⚠️  Test repository directory not found at $TEST_REPO_DIR"
fi

echo "✅ Stage 3 Complete!"
echo ""
echo "📋 Gitea Information:"
echo "  URL: http://localhost:3000"
echo "  Username: $GITEA_USERNAME"
echo "  Password: $GITEA_PASSWORD"
echo "  SSH: localhost:30222"
echo "  Port Forward PID: $GITEA_PF_PID"
echo ""
echo "🔧 Verification:"
kubectl get pods -n gitea
echo ""
echo "🏃 Actions Runner Status:"
docker ps --filter name=gitea-runner --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "No runners found"
echo ""
echo "🎯 Next: Run ./scripts/04-configure-ssh-gitea.sh"

echo ""
echo "⚠️  IMPORTANT: Keep this terminal open to maintain port forward (PID: $GITEA_PF_PID)"
echo "   Or run: kubectl port-forward -n gitea service/gitea-http 3000:3000"