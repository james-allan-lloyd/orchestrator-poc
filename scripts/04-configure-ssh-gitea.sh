#!/bin/bash

set -e

# Source central Gitea configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/gitea-config.sh"

echo "🚀 Stage 4: Setting up SSH Git destination..."

# Check Gitea is ready
if ! kubectl get pods -n gitea -l app.kubernetes.io/name=gitea >/dev/null 2>&1; then
  echo "❌ Gitea not found. Run Stage 3 first."
  exit 1
fi

# Get Gitea credentials
GITEA_USERNAME=$(kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d)
GITEA_PASSWORD=$(kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d)

echo "🔑 Generating SSH keys for GitStateStore..."

# Generate SSH key pair
SSH_KEY_PATH="/tmp/kratix-ssh-key"
rm -f "${SSH_KEY_PATH}" "${SSH_KEY_PATH}.pub"

ssh-keygen -t rsa -b 4096 -f "${SSH_KEY_PATH}" -N "" -C "kratix@platform.local"

echo "📤 Installing SSH public key in Gitea..."

# Ensure Gitea is reachable via ingress
gitea_wait_for_ready

# Read SSH public key
SSH_PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")

# Install SSH key via API
KEY_RESPONSE=$(gitea_curl -s -X POST \
  "$(gitea_local_url)/api/v1/user/keys" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{
    \"title\": \"Kratix GitStateStore Key\",
    \"key\": \"$SSH_PUBLIC_KEY\"
  }")

if echo "$KEY_RESPONSE" | grep -q "already exists"; then
  echo "⚠️  SSH key already exists, continuing..."
elif echo "$KEY_RESPONSE" | grep -q "\"id\""; then
  echo "✅ SSH public key installed successfully"
else
  echo "❌ Failed to install SSH key:"
  echo "$KEY_RESPONSE"
  exit 1
fi

echo "🔐 Getting Gitea SSH host key..."

# Get SSH host key from Gitea pod
SSH_HOST_KEY=$(kubectl exec -n gitea deployment/gitea -- cat /data/ssh/gitea.rsa.pub 2>/dev/null ||
  kubectl exec -n gitea deployment/gitea -- ssh-keyscan -p 2222 localhost 2>/dev/null | head -1 ||
  echo "gitea-ssh.gitea.svc.cluster.local ssh-rsa PLACEHOLDER")

echo "🔧 Creating SSH secrets for GitStateStore..."

# Create SSH secret for GitStateStore
kubectl create secret generic gitea-git-ssh \
  --from-file=sshPrivateKey="${SSH_KEY_PATH}" \
  --from-literal=knownHosts="gitea-ssh.gitea.svc.cluster.local $SSH_HOST_KEY" \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -

echo "🏗️  Deploying SSH GitStateStore..."

# Delete existing HTTPS statestore if it exists
kubectl delete gitstatestore default --ignore-not-found=true

# Apply SSH GitStateStore
kubectl apply -f manifests/gitea-ssh-statestore.yaml

echo "⏳ Waiting for GitStateStore to be ready..."
sleep 10

# Check GitStateStore status
echo "🔧 GitStateStore status:"
kubectl get gitstatestore default -o yaml | grep -A 10 "status:" || echo "Status not available yet"

echo "📁 Creating kratix repository..."

# Create kratix repository via API
REPO_RESPONSE=$(gitea_curl -s -X POST \
  "$(gitea_local_url)/api/v1/user/repos" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"kratix\",
    \"description\": \"Kratix GitOps repository for infrastructure\",
    \"private\": false,
    \"auto_init\": true,
    \"default_branch\": \"main\"
  }")

if echo "$REPO_RESPONSE" | grep -q "already exists"; then
  echo "⚠️  Kratix repository already exists, continuing..."
elif echo "$REPO_RESPONSE" | grep -q "clone_url"; then
  echo "✅ Kratix repository created successfully"
else
  echo "⚠️  Repository creation response: $REPO_RESPONSE"
fi

echo "🧪 Testing SSH connection to GitStateStore..."

# Test SSH connection using the generated key
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -p 30222 -i "${SSH_KEY_PATH}" \
  git@localhost info 2>/dev/null && echo "✅ SSH connection successful" || echo "⚠️  SSH connection test failed"

# Cleanup SSH key files
rm -f "${SSH_KEY_PATH}" "${SSH_KEY_PATH}.pub"

echo "✅ Stage 4 Complete!"
echo ""
echo "📋 SSH GitStateStore Information:"
echo "  Repository: ssh://git@gitea-ssh.gitea.svc.cluster.local:22/gitea_admin/kratix.git"
echo "  SSH Keys: Installed"
echo "  Status: Ready (check with: kubectl get gitstatestore)"
echo ""
echo "🔧 Verification:"
kubectl get gitstatestore
kubectl get destinations
echo ""
echo "🎯 Next: Run ./scripts/05-setup-kratix-repo.sh"
