#!/bin/bash

set -e

# Source central Gitea configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/gitea-config.sh"

echo "🚀 Stage 6: Installing Promise and testing team lifecycle..."

# Check Kratix repository is ready
if ! kubectl get gitstatestore default >/dev/null 2>&1; then
  echo "❌ Kratix repository not found. Run Stage 5 first."
  exit 1
fi

echo "📦 Installing Team Promise..."

docker build -t team-configure promises/team-promise/workflows/resource/configure/team-configure/python
kind load docker-image -n kratix-poc localhost/team-configure:latest

# Install the Team Promise
kubectl apply -f promises/team-promise/promise.yaml

echo "⏳ Waiting for Promise to be ready..."
kubectl wait --for=condition=Available promise/team --timeout=180s

echo "🏗️  Creating git destination..."
kubectl apply -f manifests/git-destination.yaml

echo "⏳ Waiting for destination to be ready..."
sleep 10

echo "✅ Promise and destination installed!"
echo ""

echo "🧪 Testing team creation..."

# Test team 1: Basic team
echo "📝 Creating test team: alpha..."
cat >/tmp/team-alpha.yaml <<'EOF'
apiVersion: platform.kratix.io/v1alpha1
kind: Team
metadata:
  name: team-alpha
spec:
  id: alpha
  name: Team Alpha
  email: alpha@company.com
EOF

kubectl apply -f /tmp/team-alpha.yaml

# Test team 2: Team without email (should use default)
echo "📝 Creating test team: beta..."
cat >/tmp/team-beta.yaml <<'EOF'
apiVersion: platform.kratix.io/v1alpha1
kind: Team
metadata:
  name: team-beta
spec:
  id: beta
  name: Team Beta
EOF

kubectl apply -f /tmp/team-beta.yaml

# Test team 3: Team with complex name
echo "📝 Creating test team: gamma..."
cat >/tmp/team-gamma.yaml <<'EOF'
apiVersion: platform.kratix.io/v1alpha1
kind: Team
metadata:
  name: team-gamma
spec:
  id: gamma
  name: DevOps Engineering Team
  email: devops@company.com
EOF

kubectl apply -f /tmp/team-gamma.yaml

echo "⏳ Waiting for teams to be processed..."
sleep 30

echo "🔍 Checking team resource status..."
kubectl get teams

echo "🔍 Checking GitStateStore status..."
kubectl get gitstatestore default -o yaml | grep -A 10 "status:" || echo "Status not available yet"

echo "📁 Checking git repository for generated files..."

# Get credentials
GITEA_USERNAME=$(kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d)
GITEA_PASSWORD=$(kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d)

# Ensure Gitea is reachable via ingress
gitea_wait_for_ready

echo "🌐 Repository contents:"
echo "  URL: $(gitea_local_url)/$GITEA_USERNAME/kratix"
echo "  Teams directory: $(gitea_local_url)/$GITEA_USERNAME/kratix/src/branch/main/teams"
echo ""

echo "🧪 Testing team update..."
echo "📝 Updating team alpha with new email..."
cat >/tmp/team-alpha-update.yaml <<'EOF'
apiVersion: platform.kratix.io/v1alpha1
kind: Team
metadata:
  name: team-alpha
spec:
  id: alpha
  name: Team Alpha Updated
  email: alpha-new@company.com
EOF

kubectl apply -f /tmp/team-alpha-update.yaml

echo "⏳ Waiting for update to be processed..."
sleep 20

echo "🧪 Testing team deletion..."
echo "🗑️  Deleting team gamma..."
kubectl delete team team-gamma

echo "⏳ Waiting for deletion to be processed..."
sleep 20

echo "✅ Stage 6 Complete!"
echo ""
echo "📋 Team Testing Summary:"
echo "  Teams created: alpha (updated), beta"
echo "  Teams deleted: gamma"
echo "  Repository: $(gitea_local_url)/$GITEA_USERNAME/kratix"
echo ""
echo "🔧 Verification:"
kubectl get teams
echo ""
echo "🌐 Check the following in Gitea:"
echo "  1. Repository: $(gitea_local_url)/$GITEA_USERNAME/kratix"
echo "  2. Teams files in teams/ directory"
echo "  3. Actions tab for workflow execution"
echo "  4. Organizations created in Gitea (if Terraform successful)"
echo ""
echo "🎉 POC Setup Complete!"
echo ""
echo "📚 Access points:"
echo "  Gitea: $(gitea_local_url) (admin: $GITEA_USERNAME)"
echo "  Teams: kubectl get teams"
echo "  GitStateStore: kubectl get gitstatestore"

# Cleanup temporary files
rm -f /tmp/team-*.yaml

