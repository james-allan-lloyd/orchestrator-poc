#!/bin/bash

# Script to generate Gitea admin API token and store it as Kubernetes secret

set -e

# Source central Gitea configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/gitea-config.sh"

echo "🔑 Gitea Admin Token Generation"

# Display configuration
gitea_show_config

# Get Gitea admin credentials
GITEA_USERNAME=$(kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d)
GITEA_PASSWORD=$(kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d)

echo "📋 Using admin credentials:"
echo "Username: $GITEA_USERNAME"
echo ""

# Check if token already exists
EXISTING_TOKEN=$(kubectl get secret gitea-admin-token -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

if [ ! -z "$EXISTING_TOKEN" ]; then
  echo "✅ Admin token already exists in Kubernetes secret"
  echo "Token: ${EXISTING_TOKEN:0:8}..."
  echo ""
  echo "To regenerate token:"
  echo "  kubectl delete secret gitea-admin-token"
  echo "  $0"
  exit 0
fi

# Ensure port forward is running
gitea_ensure_port_forward

echo "🌐 Gitea is accessible at: $(gitea_local_url)"
echo ""

# Generate admin API token
echo "🔄 Creating admin API token via API..."
TOKEN_RESPONSE=$(gitea_curl -s -X POST \
  "$(gitea_local_url)/api/v1/users/$GITEA_USERNAME/tokens" \
  -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
        "name": "kratix-admin-token-'$(date +%Y%m%d-%H%M%S)'",
        "scopes": ["all"]
    }' 2>/dev/null || echo "")

if [ ! -z "$TOKEN_RESPONSE" ] && echo "$TOKEN_RESPONSE" | grep -q '"sha1"'; then
  # Extract token from JSON response
  ADMIN_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"sha1":"[^"]*' | cut -d'"' -f4)
  echo "✅ Successfully created admin API token"

  # Store token in Kubernetes secret
  echo "💾 Storing admin token in Kubernetes secret..."
  kubectl create secret generic gitea-admin-token \
    --from-literal=token="$ADMIN_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

  echo "✅ Admin token stored successfully!"
  echo "Token: ${ADMIN_TOKEN:0:8}..."
  echo ""
  echo "🔧 Token is now available as:"
  echo "  kubectl get secret gitea-admin-token -o jsonpath='{.data.token}' | base64 -d"
else
  echo "❌ API token creation failed. Response: $TOKEN_RESPONSE"
  echo ""
  echo "📝 Manual token creation required:"
  echo "1. Open: $(gitea_local_url)/user/settings/applications"
  echo "2. Login with the admin credentials above"
  echo "3. Click 'Generate New Token'"
  echo "4. Name: kratix-admin-token, Scopes: Select 'all'"
  echo "5. Copy the generated token"
  echo ""

  # Prompt for token input
  read -p "🔑 Please paste the admin token here: " ADMIN_TOKEN

  if [ ! -z "$ADMIN_TOKEN" ]; then
    # Store token in Kubernetes secret
    echo "💾 Storing admin token in Kubernetes secret..."
    kubectl create secret generic gitea-admin-token \
      --from-literal=token="$ADMIN_TOKEN" \
      --dry-run=client -o yaml | kubectl apply -f -

    echo "✅ Admin token stored successfully!"
  else
    echo "❌ No token provided"
    exit 1
  fi
fi

echo ""
echo "🚀 Next steps:"
echo "1. Configure repository secrets: ./scripts/configure-repository-secrets.sh"
echo "2. Test Terraform access to Gitea API"

