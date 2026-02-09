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

# Ensure Gitea is reachable via ingress
gitea_wait_for_ready

# Get or create registration token
echo "🔑 Getting registration token..."
GITEA_RUNNER_REGISTRATION_TOKEN=$(kubectl get secret gitea-runner-token -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || echo "")

if [ -z "$GITEA_RUNNER_REGISTRATION_TOKEN" ]; then
  echo "🔄 No existing token found, creating new registration token..."
  
  # Try to get registration token via API
  TOKEN_RESPONSE=$(gitea_curl -s -X POST \
    "$(gitea_local_url)/api/v1/admin/actions/runners/registration-token" \
    -u "$GITEA_USERNAME:$GITEA_PASSWORD" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json")

  if [ ! -z "$TOKEN_RESPONSE" ] && echo "$TOKEN_RESPONSE" | grep -q '"token"'; then
    # Extract token from JSON response
    GITEA_RUNNER_REGISTRATION_TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
    echo "✅ Successfully created registration token via API"
    
    # Store token in Kubernetes secret
    kubectl create secret generic gitea-runner-token \
      --from-literal=token="$GITEA_RUNNER_REGISTRATION_TOKEN" \
      --dry-run=client -o yaml | kubectl apply -f -
  else
    echo "❌ API token creation failed. Response: $TOKEN_RESPONSE"
    echo "🔧 Manual token required - visit: $(gitea_local_url)/admin/actions/runners"
    exit 1
  fi
fi

echo "✅ Found registration token: ${GITEA_RUNNER_REGISTRATION_TOKEN:0:8}..."

# Pre-flight checks for container runtime
echo "🔍 Running pre-flight checks..."

# Detect container runtime socket (Podman or Docker)
CONTAINER_SOCKET=""
PODMAN_SOCKET="/run/user/$(id -u)/podman/podman.sock"
DOCKER_SOCKET="/var/run/docker.sock"

if [ -S "$PODMAN_SOCKET" ]; then
  CONTAINER_SOCKET="$PODMAN_SOCKET"
  echo "✅ Podman socket available at $CONTAINER_SOCKET"
elif [ -S "$DOCKER_SOCKET" ]; then
  CONTAINER_SOCKET="$DOCKER_SOCKET"
  echo "✅ Docker socket available at $CONTAINER_SOCKET"
else
  # Try starting Podman socket as fallback
  echo "⚠️  No container socket found, trying to start Podman socket..."
  systemctl --user start podman.socket 2>/dev/null || true
  sleep 2

  if [ -S "$PODMAN_SOCKET" ]; then
    CONTAINER_SOCKET="$PODMAN_SOCKET"
    echo "✅ Podman socket started at $CONTAINER_SOCKET"
  elif [ -S "$DOCKER_SOCKET" ]; then
    CONTAINER_SOCKET="$DOCKER_SOCKET"
    echo "✅ Docker socket available at $CONTAINER_SOCKET"
  else
    echo "❌ No container runtime socket found."
    echo "  Podman: run 'systemctl --user start podman.socket'"
    echo "  Docker: ensure Docker daemon is running"
    exit 1
  fi
fi

# Test container runtime functionality
echo "🧪 Testing container runtime..."
if ! docker version >/dev/null 2>&1; then
  echo "❌ Container runtime (docker/podman) command not working"
  exit 1
fi
echo "✅ Container runtime working"

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

# Start runner with detected container runtime
echo "🐳 Starting runner with $CONTAINER_SOCKET..."
docker run -d \
  --name $CONTAINER_NAME \
  --restart unless-stopped \
  -e GITEA_INSTANCE_URL="$(gitea_local_url)" \
  -e GITEA_RUNNER_REGISTRATION_TOKEN="$GITEA_RUNNER_REGISTRATION_TOKEN" \
  -e GITEA_RUNNER_NAME="$RUNNER_NAME" \
  -e CONFIG_FILE="/etc/act_runner/config.yaml" \
  -v "$CONTAINER_SOCKET:/var/run/docker.sock:Z" \
  -v "$CONFIG_DIR:/etc/act_runner:ro" \
  -v gitea-runner-data:/data \
  --network host \
  --add-host=host.docker.internal:host-gateway \
  --security-opt label=disable \
  $RUNNER_IMAGE

echo "✅ Runner started"

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

