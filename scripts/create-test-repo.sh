#!/bin/bash

# Script to create test repository in Gitea for Actions testing

set -e

echo "📦 Creating test repository in Gitea..."

# Configuration
LOCAL_GITEA_URL="http://localhost:8080"
REPO_NAME="actions-test"
TEST_REPO_DIR="/home/james/src/orchestrator-poc/test-actions-repo"

# Get Gitea credentials
GITEA_USERNAME=$(kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d)
GITEA_PASSWORD=$(kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d)

echo "Username: $GITEA_USERNAME"
echo "Repository: $REPO_NAME"

# Check if port forward is running
if ! curl -k -s "$LOCAL_GITEA_URL" > /dev/null; then
    echo "🔗 Starting port forward to Gitea..."
    kubectl port-forward -n gitea svc/gitea-http 8080:443 > /dev/null 2>&1 &
    PORT_FORWARD_PID=$!
    echo "⏳ Waiting for port forward..."
    sleep 5
fi

# Create repository via API
echo "🏗️  Creating repository via API..."
REPO_RESPONSE=$(curl -k -s -X POST \
  "$LOCAL_GITEA_URL/api/v1/user/repos" \
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
    echo "❌ Failed to create repository:"
    echo "$REPO_RESPONSE"
    exit 1
fi

# Initialize and push test repository
echo "📤 Initializing and pushing test repository..."
cd "$TEST_REPO_DIR"

# Initialize git if not already done
if [ ! -d ".git" ]; then
    git init
    git checkout -b main 2>/dev/null || git checkout main
fi

# Configure git (if not configured globally)
git config user.name "Test User" 2>/dev/null || true
git config user.email "test@example.com" 2>/dev/null || true

# Add remote if not exists
REMOTE_URL="$LOCAL_GITEA_URL/$GITEA_USERNAME/$REPO_NAME.git"
if ! git remote get-url origin > /dev/null 2>&1; then
    git remote add origin "$REMOTE_URL"
else
    git remote set-url origin "$REMOTE_URL"
fi

# Add, commit and push
git add .
git commit -m "Add Gitea Actions test workflow" || git commit -m "Update test repository" || true

# Push with credentials
echo "🚀 Pushing to repository..."
git push "http://$GITEA_USERNAME:$GITEA_PASSWORD@localhost:8080/$GITEA_USERNAME/$REPO_NAME.git" main

echo ""
echo "✅ Test repository setup complete!"
echo ""
echo "📋 Repository Information:"
echo "  Name: $REPO_NAME"
echo "  URL: $LOCAL_GITEA_URL/$GITEA_USERNAME/$REPO_NAME"
echo "  Actions: $LOCAL_GITEA_URL/$GITEA_USERNAME/$REPO_NAME/actions"
echo ""
echo "🔧 Next steps:"
echo "1. Ensure Gitea Actions runner is running"
echo "2. Visit the Actions tab to see workflow execution"
echo "3. Push changes to trigger workflows"
echo ""
echo "🌐 Access Gitea at: $LOCAL_GITEA_URL"
echo "👤 Username: $GITEA_USERNAME"