#!/bin/bash

set -e

echo "🧹 Kratix PoC Cleanup"
echo "==================="
echo ""

CLUSTER_NAME="kratix-poc"

echo "🛑 Stopping Actions runner..."
docker stop gitea-actions-runner 2>/dev/null || echo "  No runner container found"
docker rm gitea-actions-runner 2>/dev/null || echo "  No runner container to remove"

echo "🗄️  Removing runner data volume..."
docker volume rm gitea-runner-data 2>/dev/null || echo "  No runner volume found"

echo "🛑 Stopping cloud-provider-kind..."
pkill -f cloud-provider-kind 2>/dev/null || echo "  No cloud-provider-kind process found"

echo "☁️  Destroying Kind cluster..."
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    kind delete cluster --name "${CLUSTER_NAME}"
    echo "✅ Cluster '${CLUSTER_NAME}' deleted"
else
    echo "⚠️  Cluster '${CLUSTER_NAME}' not found"
fi

echo "🧹 Cleaning up temporary files..."
rm -f /tmp/kind-config.yaml
rm -f /tmp/kratix-user-patch.yaml
rm -f /tmp/team-*.yaml
rm -f /tmp/kratix-ssh-key*
rm -f /tmp/destination-backup.yaml
rm -f /tmp/known_hosts

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "🚀 To rebuild the PoC:"
echo "  ./scripts/build-poc.sh"