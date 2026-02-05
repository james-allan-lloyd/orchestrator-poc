#!/bin/bash

# Gitea Actions Runner Setup Script
# Based on https://docs.gitea.com/next/usage/actions/act-runner#install-with-the-docker-image

set -e

# Source central Gitea configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/gitea-config.sh"

echo "🚀 Setting up Gitea Actions Runner..."

# Configuration
RUNNER_NAME="gitea-runner-local"
RUNNER_IMAGE="docker.io/gitea/act_runner:latest"
CONTAINER_NAME="gitea-actions-runner"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$PROJECT_ROOT/runner-config"

# Display configuration
gitea_show_config

# Get Gitea credentials from Kubernetes
echo "📋 Getting Gitea credentials from Kubernetes..."
GITEA_USERNAME=$(kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d)
GITEA_PASSWORD=$(kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d)

echo "Username: $GITEA_USERNAME"
echo "Using instance URL: $(gitea_local_url)"

# Ensure port forward is running
gitea_ensure_port_forward

# Get registration token from Kubernetes secret
echo "🔑 Getting registration token..."
GITEA_RUNNER_REGISTRATION_TOKEN=$(kubectl get secret gitea-runner-token -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

if [ -z "$GITEA_RUNNER_REGISTRATION_TOKEN" ]; then
  echo "❌ No registration token found in Kubernetes secret"
  echo ""
  echo "🔧 First-time setup required:"
  echo "1. Run: ./scripts/get-runner-token.sh"
  echo "2. Follow the instructions to get a token from Gitea UI"
  echo "3. Then run this script again"
  exit 1
fi

echo "✅ Found registration token in Kubernetes secret: ${GITEA_RUNNER_REGISTRATION_TOKEN:0:8}..."

# Pre-flight checks for Podman functionality
echo "🔍 Running pre-flight checks..."

# Check if Podman socket exists
PODMAN_SOCKET="/run/user/$(id -u)/podman/podman.sock"
if [ ! -S "$PODMAN_SOCKET" ]; then
  echo "❌ Podman socket not found at $PODMAN_SOCKET"
  echo "🔧 Starting Podman socket service..."
  systemctl --user start podman.socket
  sleep 2

  if [ ! -S "$PODMAN_SOCKET" ]; then
    echo "❌ Failed to create Podman socket. Please run:"
    echo "  systemctl --user start podman.socket"
    exit 1
  fi
fi

echo "✅ Podman socket available at $PODMAN_SOCKET"

# Test Podman functionality
echo "🧪 Testing Podman functionality..."
if ! docker version >/dev/null 2>&1; then
  echo "❌ Podman/Docker command not working"
  exit 1
fi
echo "✅ Podman/Docker command working"

# Check configuration file
if [ ! -f "$CONFIG_DIR/config.yaml" ]; then
  echo "❌ Configuration file not found at $CONFIG_DIR/config.yaml"
  exit 1
fi
echo "✅ Configuration file found"

# Stop existing runner if running
echo "🛑 Stopping any existing runner..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

# Enhanced configuration with Podman socket fix
echo "🐳 Starting runner with Podman configuration..."
docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  -e GITEA_INSTANCE_URL="$(gitea_local_url)" \
  -e GITEA_RUNNER_REGISTRATION_TOKEN="$GITEA_RUNNER_REGISTRATION_TOKEN" \
  -e GITEA_RUNNER_NAME="$RUNNER_NAME" \
  -e CONFIG_FILE="/etc/act_runner/config.yaml" \
  -v "$PODMAN_SOCKET:/var/run/docker.sock:Z" \
  -v "$CONFIG_DIR:/etc/act_runner:ro" \
  -v gitea-runner-data:/data \
  --network host \
  --add-host=host.docker.internal:host-gateway \
  --security-opt label=disable \
  $RUNNER_IMAGE

echo "✅ Runner started with Podman configuration"

echo "⏳ Waiting for runner to register..."
sleep 15

# Check runner status
echo "📊 Checking runner status..."
docker logs --tail 20 $CONTAINER_NAME

echo ""
echo "✅ Gitea Actions Runner setup complete!"
echo ""
echo "📋 Runner Information:"
echo "  Container: $CONTAINER_NAME"
echo "  Name: $RUNNER_NAME"
echo "  Instance URL: $(gitea_local_url)"
echo "  Status: $(docker ps --format 'table {{.Status}}' --filter name=$CONTAINER_NAME | tail -n 1)"
echo ""
echo "🔧 Useful commands:"
echo "  View logs: docker logs -f $CONTAINER_NAME"
echo "  Stop runner: docker stop $CONTAINER_NAME"
echo "  Remove runner: docker rm $CONTAINER_NAME"
echo ""
echo "🌐 Access Gitea at: $(gitea_local_url)"
echo "👤 Username: $GITEA_USERNAME"
echo "🔒 Password: $GITEA_PASSWORD"
echo ""
echo "ℹ️  Note: Keep the port forward running (PID: $GITEA_PORT_FORWARD_PID) for the runner to work"

# Don't cleanup on successful exit - user needs the port forward
trap - EXIT

