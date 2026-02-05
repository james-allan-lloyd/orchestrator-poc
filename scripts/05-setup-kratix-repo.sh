#!/bin/bash

set -e

# Source central Gitea configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/gitea-config.sh"

echo "🚀 Stage 5: Setting up Kratix repository and Terraform pipeline..."

# Check SSH GitStateStore is ready
if ! kubectl get gitstatestore default >/dev/null 2>&1; then
    echo "❌ SSH GitStateStore not found. Run Stage 4 first."
    exit 1
fi

# Configuration
REPO_OWNER="gitea_admin"
REPO_NAME="kratix"
BASE_REPO_DIR="$SCRIPT_DIR/../repos/kratix"

# Get credentials
GITEA_USERNAME=$(kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d)
GITEA_PASSWORD=$(kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d)

echo "📋 Repository setup:"
echo "  Owner: $REPO_OWNER"
echo "  Repository: $REPO_NAME"
echo "  Base directory: $BASE_REPO_DIR"

# Ensure port forward is running
gitea_ensure_port_forward

echo "🔑 Generating Gitea admin token for workflows..."

# Generate admin token for API access in workflows
TOKEN_RESPONSE=$(gitea_curl -s -X POST \
  "$(gitea_local_url)/api/v1/users/$GITEA_USERNAME/tokens" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "kratix-workflow-token",
    "scopes": ["write:repository", "write:admin"]
  }')

if echo "$TOKEN_RESPONSE" | grep -q '"sha1"'; then
  GITEA_ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"sha1":"[^"]*' | cut -d'"' -f4)
  echo "✅ Generated admin token: ${GITEA_ADMIN_TOKEN:0:8}..."
  
  # Store in Kubernetes secret
  kubectl create secret generic gitea-admin-token \
    --from-literal=token="$GITEA_ADMIN_TOKEN" \
    --namespace=default \
    --dry-run=client -o yaml | kubectl apply -f -
else
  echo "❌ Failed to create admin token: $TOKEN_RESPONSE"
  exit 1
fi

echo "📁 Setting up kratix repository..."

# Check if repository exists
REPO_CHECK=$(gitea_curl -s -o /dev/null -w "%{http_code}" \
  "$(gitea_local_url)/api/v1/repos/$REPO_OWNER/$REPO_NAME" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD")

if [ "$REPO_CHECK" = "404" ]; then
  echo "📦 Repository doesn't exist, creating it..."
  REPO_RESPONSE=$(gitea_curl -s -X POST \
    "$(gitea_local_url)/api/v1/user/repos" \
    -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "'$REPO_NAME'",
      "description": "Kratix-managed infrastructure as code repository",
      "private": false,
      "auto_init": true,
      "default_branch": "main"
    }')

  if echo "$REPO_RESPONSE" | grep -q '"clone_url"'; then
    echo "✅ Repository created successfully"
  else
    echo "❌ Failed to create repository: $REPO_RESPONSE"
    exit 1
  fi
elif [ "$REPO_CHECK" = "200" ]; then
  echo "✅ Repository already exists"
else
  echo "❌ Error checking repository (HTTP $REPO_CHECK)"
  exit 1
fi

echo "🏗️  Setting up Terraform pipeline in repository..."

# Clone/setup local working copy
if [ -d "$BASE_REPO_DIR/.git" ]; then
    echo "📁 Repository already cloned, updating..."
    cd "$BASE_REPO_DIR"
    git pull origin main || echo "⚠️  Pull failed, continuing..."
else
    echo "📥 Cloning repository..."
    git clone "$(gitea_local_url | sed "s|://|://$GITEA_USERNAME:$GITEA_PASSWORD@|")/$REPO_OWNER/$REPO_NAME.git" "$BASE_REPO_DIR"
    cd "$BASE_REPO_DIR"
fi

# Configure git
git config user.name "Kratix Platform" 2>/dev/null || true
git config user.email "kratix@platform.local" 2>/dev/null || true
gitea_configure_git_ssl

echo "🔧 Setting up repository secrets..."

# Configure repository secret for GITEA_ADMIN_TOKEN
SECRET_RESPONSE=$(gitea_curl -s -X PUT \
  "$(gitea_local_url)/api/v1/repos/$REPO_OWNER/$REPO_NAME/actions/secrets/GITEA_ADMIN_TOKEN" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
    "data": "'$GITEA_ADMIN_TOKEN'"
  }' 2>/dev/null || echo "API_NOT_SUPPORTED")

if echo "$SECRET_RESPONSE" | grep -q "API_NOT_SUPPORTED\|404"; then
  echo "⚠️  Repository secrets API not supported - will use environment variable in workflow"
else
  echo "✅ Repository secret configured successfully"
fi

# Ensure Actions are enabled
echo "🚀 Enabling Actions for repository..."
gitea_curl -s -X PATCH \
  "$(gitea_local_url)/api/v1/repos/$REPO_OWNER/$REPO_NAME" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{ "has_actions": true }' > /dev/null

echo "📄 Verifying Terraform pipeline workflow exists..."
if [ -f ".gitea/workflows/deploy-organizations.yml" ]; then
  echo "✅ Terraform pipeline workflow found"
else
  echo "⚠️  Terraform pipeline workflow not found - should be created by Team Promise output"
fi

echo "✅ Stage 5 Complete!"
echo ""
echo "📋 Kratix Repository Information:"
echo "  URL: $(gitea_local_url)/$REPO_OWNER/$REPO_NAME"
echo "  Actions: $(gitea_local_url)/$REPO_OWNER/$REPO_NAME/actions"
echo "  Local path: $BASE_REPO_DIR"
echo ""
echo "🔧 Verification:"
echo "  GitStateStore status:"
kubectl get gitstatestore default -o jsonpath='{.status.conditions[0].type}: {.status.conditions[0].status} - {.status.conditions[0].message}' 2>/dev/null || echo "Status pending"
echo ""
echo "🎯 Next: Run ./scripts/06-test-teams.sh"