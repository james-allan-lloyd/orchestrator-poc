#!/bin/bash

set -e

# Master script to build the entire Kratix PoC from scratch
# Runs all 6 stages in sequence with verification

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🎯 Kratix PoC Automated Build"
echo "=============================="
echo ""

# Function to run a stage with error handling
run_stage() {
  local stage_num="$1"
  local stage_name="$2"
  local script_name="$3"
  
  echo "▶️  Stage $stage_num: $stage_name"
  echo "   Script: $script_name"
  echo ""
  
  if [ -x "$SCRIPT_DIR/$script_name" ]; then
    "$SCRIPT_DIR/$script_name"
    echo ""
    echo "✅ Stage $stage_num completed successfully!"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
  else
    echo "❌ Script not found or not executable: $script_name"
    exit 1
  fi
}

echo "🚀 Starting 6-stage Kratix PoC build..."
echo ""

# Stage 1: Cluster setup
run_stage 1 "Cluster Preparation" "01-setup-cluster.sh"

# Stage 2: Kratix installation
run_stage 2 "Kratix Installation" "02-install-kratix.sh"

# Stage 3: Gitea and Actions runner
run_stage 3 "Gitea + Actions Runner" "03-setup-gitea.sh"

# Stage 4: SSH configuration
run_stage 4 "SSH Git Destination" "04-configure-ssh-gitea.sh"

# Stage 5: Kratix repository
run_stage 5 "Kratix Repository + Pipeline" "05-setup-kratix-repo.sh"

# Stage 6: Promise testing
run_stage 6 "Promise Installation + Testing" "06-test-teams.sh"

echo "🎉 KRATIX POC BUILD COMPLETE!"
echo "============================="
echo ""
echo "📋 Access Information:"

# Get credentials
GITEA_USERNAME=$(kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d 2>/dev/null || echo "N/A")
GITEA_PASSWORD=$(kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d 2>/dev/null || echo "N/A")

echo "  🌐 Gitea Web UI: http://localhost:8080"
echo "  👤 Username: $GITEA_USERNAME"
echo "  🔒 Password: $GITEA_PASSWORD"
echo "  📁 Kratix Repository: http://localhost:8080/gitea_admin/kratix"
echo "  🏃 Actions: http://localhost:8080/gitea_admin/kratix/actions"
echo ""
echo "📊 System Status:"
echo "  Kratix Platform:"
kubectl get pods -n kratix-platform-system --no-headers | wc -l | xargs echo "    Pods running:"
echo "  Gitea:"
kubectl get pods -n gitea --no-headers | wc -l | xargs echo "    Pods running:"
echo "  GitStateStore:"
kubectl get gitstatestore default -o jsonpath='    Status: {.status.conditions[0].status} - {.status.conditions[0].message}' 2>/dev/null || echo "    Status: Pending"
echo "  Teams:"
kubectl get teams --no-headers | wc -l | xargs echo "    Teams created:"
echo ""
echo "🔧 Useful Commands:"
echo "  View teams: kubectl get teams"
echo "  View GitStateStore: kubectl get gitstatestore"
echo "  View runner logs: docker logs -f gitea-actions-runner"
echo "  Access Gitea: open http://localhost:8080"
echo ""
echo "🧪 Try creating a team:"
echo '  kubectl apply -f - <<EOF'
echo 'apiVersion: platform.kratix.io/v1alpha1'
echo 'kind: Team'
echo 'metadata:'
echo '  name: my-team'
echo 'spec:'
echo '  id: my-team'
echo '  name: My Team'
echo '  email: myteam@company.com'
echo 'EOF'