#!/bin/bash

# Script to configure repository secrets for Gitea Actions workflows

set -e

# Source central Gitea configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/gitea-config.sh"

echo "🔐 Configuring Repository Secrets for Gitea Actions"

# Configuration
REPO_OWNER="gitea_admin"
REPO_NAME="kratix"

# Display configuration
gitea_show_config

# Get credentials
GITEA_USERNAME=$(kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d)
GITEA_PASSWORD=$(kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d)

# Get admin token
GITEA_ADMIN_TOKEN=$(kubectl get secret gitea-admin-token -o jsonpath='{.data.token}' | base64 -d 2>/dev/null || echo "")

if [ -z "$GITEA_ADMIN_TOKEN" ]; then
  echo "❌ No admin token found. Please run:"
  echo "  ./scripts/generate-gitea-admin-token.sh"
  exit 1
fi

echo "📋 Configuration:"
echo "Repository: $REPO_OWNER/$REPO_NAME"
echo "Token: ${GITEA_ADMIN_TOKEN:0:8}..."
echo ""

# Ensure port forward is running
gitea_ensure_port_forward

# Check if repository exists
echo "🔍 Checking if kratix repository exists..."
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

# Configure repository secret for GITEA_ADMIN_TOKEN
echo "🔑 Setting up repository secret GITEA_ADMIN_TOKEN..."

# Check if Gitea supports repository secrets API (newer versions)
SECRET_RESPONSE=$(gitea_curl -s -X PUT \
  "$(gitea_local_url)/api/v1/repos/$REPO_OWNER/$REPO_NAME/actions/secrets/GITEA_ADMIN_TOKEN" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
        "data": "'$GITEA_ADMIN_TOKEN'"
    }' 2>/dev/null || echo "API_NOT_SUPPORTED")

if echo "$SECRET_RESPONSE" | grep -q "API_NOT_SUPPORTED\|404\|Not Found"; then
  echo "⚠️  Repository secrets API not supported, using organization-level secret..."

  # Try organization-level secret instead
  ORG_SECRET_RESPONSE=$(gitea_curl -s -X PUT \
    "$(gitea_local_url)/api/v1/orgs/$REPO_OWNER/actions/secrets/GITEA_ADMIN_TOKEN" \
    -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
    -H "Content-Type: application/json" \
    -d '{
            "data": "'$GITEA_ADMIN_TOKEN'"
        }' 2>/dev/null || echo "ORG_API_NOT_SUPPORTED")

  if echo "$ORG_SECRET_RESPONSE" | grep -q "ORG_API_NOT_SUPPORTED\|404"; then
    echo "⚠️  Organization secrets API also not supported"
    echo "📝 Manual secret configuration required:"
    echo ""
    echo "1. Navigate to: $(gitea_local_url)/$REPO_OWNER/$REPO_NAME/settings/secrets"
    echo "2. Or try: $(gitea_local_url)/$REPO_OWNER/settings/secrets"
    echo "3. Create new secret:"
    echo "   Name: GITEA_ADMIN_TOKEN"
    echo "   Value: $GITEA_ADMIN_TOKEN"
    echo ""
    echo "Alternative: Use environment variable in workflow:"
    echo 'env:'
    echo '  GITEA_ADMIN_TOKEN: "'$GITEA_ADMIN_TOKEN'"'
  else
    echo "✅ Organization-level secret configured"
  fi
else
  echo "✅ Repository secret configured successfully"
fi

# Ensure Actions are enabled for the repository
echo "🚀 Enabling Actions for repository..."
ACTIONS_ENABLE=$(gitea_curl -s -X PATCH \
  "$(gitea_local_url)/api/v1/repos/$REPO_OWNER/$REPO_NAME" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
  -H "Content-Type: application/json" \
  -d '{
        "has_actions": true
    }' 2>/dev/null || echo "")

if echo "$ACTIONS_ENABLE" | grep -q '"has_actions":true'; then
  echo "✅ Actions enabled for repository"
else
  echo "⚠️  Could not verify Actions are enabled"
fi

echo ""
echo "✅ Repository secrets configuration complete!"
echo ""
echo "📋 Summary:"
echo "  Repository: $(gitea_local_url)/$REPO_OWNER/$REPO_NAME"
echo "  Actions: $(gitea_local_url)/$REPO_OWNER/$REPO_NAME/actions"
echo "  Token: Available as GITEA_ADMIN_TOKEN in workflows"
echo ""
echo "🚀 Next steps:"
echo "1. Fix Terraform provider configuration"
echo "2. Test pipeline with Team Promise"

