#!/bin/bash

# Central Gitea Configuration Management
# Source this file in other scripts to get consistent Gitea connection settings

# =============================================================================
# GITEA CONNECTION CONFIGURATION
# =============================================================================

# SSL/TLS Mode Configuration
# Set to "true" for secure HTTPS with proper certificates
# Set to "false" for development mode with self-signed certificates
export GITEA_SSL_SECURE_MODE="false"

# Protocol and Port Configuration
if [ "$GITEA_SSL_SECURE_MODE" = "true" ]; then
  # Secure mode: HTTPS with proper SSL verification
  export GITEA_PROTOCOL="https"
  export GITEA_LOCAL_PORT="8443"
  export GITEA_CURL_SSL_OPTS=""
  export GITEA_GIT_SSL_VERIFY="true"
else
  # Development mode: HTTP with Helm deployment
  export GITEA_PROTOCOL="http"
  export GITEA_LOCAL_PORT="3000"
  export GITEA_CURL_SSL_OPTS="-k"
  export GITEA_GIT_SSL_VERIFY="false"
fi

# Connection Endpoints
export GITEA_LOCAL_HOST="localhost"
export GITEA_LOCAL_URL="${GITEA_PROTOCOL}://${GITEA_LOCAL_HOST}:${GITEA_LOCAL_PORT}"

# Internal Kubernetes Service URLs
export GITEA_INTERNAL_SERVICE="gitea-http.gitea.svc.cluster.local"
export GITEA_INTERNAL_PORT="443"
export GITEA_INTERNAL_URL="https://${GITEA_INTERNAL_SERVICE}:${GITEA_INTERNAL_PORT}"

# Docker/Container Internal URLs (for Actions runner jobs)
export GITEA_CONTAINER_URL="https://host.docker.internal:${GITEA_LOCAL_PORT}"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Execute curl with appropriate SSL settings
gitea_curl() {
  if [ "$GITEA_SSL_SECURE_MODE" = "true" ]; then
    curl "$@"
  else
    curl ${GITEA_CURL_SSL_OPTS} "$@"
  fi
}

# Execute curl with admin authentication and SSL settings
gitea_admin_curl() {
  local username=$(kubectl get secret gitea-credentials -o jsonpath='{.data.username}' | base64 -d)
  local password=$(kubectl get secret gitea-credentials -o jsonpath='{.data.password}' | base64 -d)

  if [ "$GITEA_SSL_SECURE_MODE" = "true" ]; then
    curl -u "$username:$password" "$@"
  else
    curl ${GITEA_CURL_SSL_OPTS} -u "$username:$password" "$@"
  fi
}

# Get the appropriate Gitea URL for local access (port-forwarded)
gitea_local_url() {
  echo "$GITEA_LOCAL_URL"
}

# Get the appropriate Gitea URL for internal cluster access
gitea_internal_url() {
  echo "$GITEA_INTERNAL_URL"
}

# Get the appropriate Gitea URL for container/Actions access
gitea_container_url() {
  echo "$GITEA_CONTAINER_URL"
}

# Get SSH URL for GitStateStore access
gitea_ssh_url() {
  echo "ssh://git@gitea-ssh.gitea.svc.cluster.local:22"
}

# Get SSH repository URL for a specific repository
gitea_ssh_repo_url() {
  local owner=${1:-gitea_admin}
  local repo=${2:-kratix}
  echo "$(gitea_ssh_url)/$owner/$repo.git"
}

# Configure Git SSL settings appropriately
gitea_configure_git_ssl() {
  git config http.sslVerify "$GITEA_GIT_SSL_VERIFY"
}

# Check if port forward is needed and running
gitea_ensure_port_forward() {
  local check_url="$GITEA_LOCAL_URL"

  if ! gitea_curl -s "$check_url" >/dev/null 2>&1; then
    echo "🔗 Starting port forward to Gitea..."
    kubectl port-forward -n gitea svc/gitea-http ${GITEA_LOCAL_PORT}:3000 >/dev/null 2>&1 &
    export GITEA_PORT_FORWARD_PID=$!
    echo "⏳ Waiting for port forward..."
    sleep 5

    # Set up cleanup trap
    cleanup_port_forward() {
      if [ ! -z "$GITEA_PORT_FORWARD_PID" ]; then
        kill $GITEA_PORT_FORWARD_PID 2>/dev/null || true
      fi
    }

    # # Only set trap if not already set
    if [ -z "$GITEA_CLEANUP_TRAP_SET" ]; then
      trap cleanup_port_forward EXIT
      export GITEA_CLEANUP_TRAP_SET="true"
    fi
  fi
}

# =============================================================================
# DISPLAY CONFIGURATION
# =============================================================================

gitea_show_config() {
  echo "🔧 Gitea Configuration:"
  echo "  SSL Secure Mode: $GITEA_SSL_SECURE_MODE"
  echo "  Local URL: $GITEA_LOCAL_URL"
  echo "  Internal URL: $GITEA_INTERNAL_URL"
  echo "  Container URL: $GITEA_CONTAINER_URL"
  echo "  Curl Options: $GITEA_CURL_SSL_OPTS"
  echo "  Git SSL Verify: $GITEA_GIT_SSL_VERIFY"
  echo ""
}

# =============================================================================
# VALIDATION
# =============================================================================

# Validate that required environment is available
gitea_validate_environment() {
  # Check kubectl is available
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "❌ kubectl not found. Please install kubectl."
    return 1
  fi

  # Check if we can access the Kubernetes cluster
  if ! kubectl get pods >/dev/null 2>&1; then
    echo "❌ Cannot access Kubernetes cluster. Please check your kubeconfig."
    return 1
  fi

  return 0
}

# Auto-source validation when script is loaded
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  # Script is being sourced
  gitea_validate_environment >/dev/null 2>&1 || true
fi
