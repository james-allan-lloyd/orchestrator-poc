#!/bin/bash

# Helper script to get and store Gitea Actions runner registration token

set -e

echo "🔑 Gitea Actions Runner Token Setup"

# Check if token already exists
EXISTING_TOKEN=$(kubectl get secret gitea-runner-token -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

if [ ! -z "$EXISTING_TOKEN" ]; then
    echo "✅ Registration token already exists in Kubernetes secret"
    echo "Token: ${EXISTING_TOKEN:0:8}..."
    echo ""
    echo "To view full token:"
    echo "  kubectl get secret gitea-runner-token -o jsonpath='{.data.token}' | base64 -d"
    echo ""
    echo "To delete and recreate:"
    echo "  kubectl delete secret gitea-runner-token"
    echo "  $0"
    exit 0
fi

# Get Gitea credentials
GITEA_USERNAME=$(kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d)
GITEA_PASSWORD=$(kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d)

echo "📋 Gitea credentials:"
echo "Username: $GITEA_USERNAME"
echo "Password: $GITEA_PASSWORD"
echo ""

# Check if port forward is running
if ! curl -k -s https://localhost:8443 > /dev/null 2>&1; then
    echo "🔗 Starting port forward to Gitea..."
    kubectl port-forward -n gitea svc/gitea-http 8443:443 > /dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    echo "⏳ Waiting for port forward..."
    sleep 5
    
    cleanup() {
        if [ ! -z "$PORT_FORWARD_PID" ]; then
            kill $PORT_FORWARD_PID 2>/dev/null || true
        fi
    }
    trap cleanup EXIT
fi

echo "🌐 Gitea is accessible at: http://localhost:8080"
echo ""

# Try to get registration token via API
echo "🔄 Attempting to create registration token via API..."
TOKEN_RESPONSE=$(curl -s -X POST \
    "http://localhost:8080/api/v1/admin/actions/runners/registration-token" \
    -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" 2>/dev/null || echo "")

if [ ! -z "$TOKEN_RESPONSE" ] && echo "$TOKEN_RESPONSE" | grep -q '"token"'; then
    # Extract token from JSON response
    REGISTRATION_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    echo "✅ Successfully created registration token via API"
else
    echo "❌ API token creation failed. Response: $TOKEN_RESPONSE"
    echo ""
    echo "📝 Fallback to manual token creation:"
    echo "1. Open: http://localhost:8080/admin/actions/runners"
    echo "2. Login with the credentials above"
    echo "3. Click 'Create registration token'"
    echo "4. Copy the token that appears"
    echo ""
    
    # Prompt for token input
    read -p "🔑 Please paste the registration token here: " REGISTRATION_TOKEN
fi

if [ -z "$REGISTRATION_TOKEN" ]; then
    echo "❌ No registration token obtained"
    exit 1
fi

# Store token in Kubernetes secret
echo "💾 Storing registration token in Kubernetes secret..."
kubectl create secret generic gitea-runner-token \
    --from-literal=token="$REGISTRATION_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Registration token stored successfully!"
echo "Token: ${REGISTRATION_TOKEN:0:8}..."
echo ""
echo "🚀 Now you can run the runner setup script:"
echo "  ./scripts/setup-gitea-runner.sh"