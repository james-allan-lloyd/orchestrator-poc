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

# Ensure Gitea is reachable via ingress
gitea_wait_for_ready

echo "🔑 Setting up Gitea admin token for workflows..."

# Check if token already exists in Kubernetes
if kubectl get secret gitea-admin-token >/dev/null 2>&1; then
  echo "✅ Admin token secret already exists, retrieving..."
  GITEA_ADMIN_TOKEN=$(kubectl get secret gitea-admin-token -o jsonpath='{.data.token}' | base64 -d)
  echo "✅ Using existing admin token: ${GITEA_ADMIN_TOKEN:0:8}..."
else
  echo "🔑 Creating new admin token..."

  # Check if token with same name already exists in Gitea
  EXISTING_TOKENS=$(gitea_curl -s -X GET \
    "$(gitea_local_url)/api/v1/users/$GITEA_USERNAME/tokens" \
    -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
    -H "Content-Type: application/json")

  if echo "$EXISTING_TOKENS" | grep -q '"name":"kratix-workflow-token"'; then
    echo "⚠️  Token with name 'kratix-workflow-token' already exists in Gitea"
    echo "🗑️  Deleting existing token to recreate..."

    # Extract token ID and delete it
    TOKEN_ID=$(echo "$EXISTING_TOKENS" | grep -B2 -A2 '"name":"kratix-workflow-token"' | grep '"id":' | grep -o '[0-9]*')
    if [ -n "$TOKEN_ID" ]; then
      gitea_curl -s -X DELETE \
        "$(gitea_local_url)/api/v1/users/$GITEA_USERNAME/tokens/$TOKEN_ID" \
        -u "$GITEA_USERNAME:$GITEA_PASSWORD" >/dev/null
      echo "✅ Deleted existing token"
    fi
  fi

  # Generate admin token for API access in workflows
  TOKEN_RESPONSE=$(gitea_curl -s -X POST \
    "$(gitea_local_url)/api/v1/users/$GITEA_USERNAME/tokens" \
    -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
    -H "Content-Type: application/json" \
    -d '{
      "name": "kratix-workflow-token",
      "scopes": ["write:repository", "write:admin", "read:user", "write:organization"]
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

# Ensure Actions are enabled BEFORE setting secrets
echo "🚀 Enabling Actions for repository..."
gitea_curl -s -X PATCH \
  "$(gitea_local_url)/api/v1/repos/$REPO_OWNER/$REPO_NAME" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{ "has_actions": true }' >/dev/null

echo "🔧 Setting up repository secrets..."

# Configure repository secret for ADMIN_TOKEN_GITEA
SECRET_PAYLOAD=$(printf '{"data": "%s"}' "$GITEA_ADMIN_TOKEN")
SECRET_RESPONSE_FILE=$(mktemp)
SECRET_STATUS=$(gitea_curl -s -o "$SECRET_RESPONSE_FILE" -w '%{http_code}' -X PUT \
  "$(gitea_local_url)/api/v1/repos/$REPO_OWNER/$REPO_NAME/actions/secrets/ADMIN_TOKEN_GITEA" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d "$SECRET_PAYLOAD")

if [ "$SECRET_STATUS" = "201" ] || [ "$SECRET_STATUS" = "204" ]; then
  echo "✅ Repository secret ADMIN_TOKEN_GITEA configured successfully"
else
  echo "❌ Failed to set repository secret (HTTP $SECRET_STATUS)"
  echo "Response: $(cat "$SECRET_RESPONSE_FILE")"
  rm -f "$SECRET_RESPONSE_FILE"
  exit 1
fi

echo "📄 Initializing repository structure from template..."

# Copy template files from repos/kratix to temporary directory
TEMP_REPO_DIR="/tmp/kratix-repo-init"
rm -rf "$TEMP_REPO_DIR"

# Initialize temporary directory as git repository
mkdir -p "$TEMP_REPO_DIR"
cd "$TEMP_REPO_DIR"
git init
git config user.name "Kratix Platform"
git config user.email "kratix@platform.local"
gitea_configure_git_ssl

# Add remote origin
git remote add origin "$(gitea_local_url | sed "s|://|://$GITEA_USERNAME:$GITEA_PASSWORD@|")/$REPO_OWNER/$REPO_NAME.git"
git fetch

git pull origin main --rebase

cp -R "$SCRIPT_DIR/../repos/kratix/." ./

# Add all files and commit
git add .
git commit -m "Sync to template repository"

echo "🚀 Pushing repository initialization to Gitea..."
git push origin main

echo "✅ Repository initialized from template"

# Clean up temporary directory and return to working directory
# rm -rf "$TEMP_REPO_DIR"

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
