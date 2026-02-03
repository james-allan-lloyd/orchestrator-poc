#!/usr/bin/env bash

set -e

platform_destination_ip() {
  docker inspect kratix-poc-control-plane | yq ".[0].NetworkSettings.Networks.kind.IPAddress"
}

generate_random_string() {
  local length="${1:-32}"
  openssl rand -hex $((length / 2))
}

generate_jwt_secret() {
  openssl rand -base64 64 | tr -d '\n'
}

generate_gitea_credentials() {
  local context="${1:-kind-kratix-poc}"

  echo "🔧 Generating Gitea credentials and secrets..."

  # Create namespace
  kubectl create namespace gitea --context "${context}" || true

  # Generate admin credentials if they don't exist
  if kubectl get secret gitea-admin --context "${context}" -n gitea >/dev/null 2>&1; then
    echo "✅ Gitea admin credentials already exist"
    GITEA_USERNAME=$(kubectl get secret gitea-admin --context "${context}" -n gitea -o jsonpath='{.data.username}' | base64 -d)
    GITEA_PASSWORD=$(kubectl get secret gitea-admin --context "${context}" -n gitea -o jsonpath='{.data.password}' | base64 -d)
  else
    echo "🔐 Generating new admin credentials..."
    GITEA_USERNAME="gitea_admin"
    GITEA_PASSWORD=$(generate_random_string 16)
    
    kubectl create secret generic gitea-admin \
      --context "${context}" \
      --from-literal=username="$GITEA_USERNAME" \
      --from-literal=password="$GITEA_PASSWORD" \
      --namespace=gitea
      
    echo "✅ Created admin credentials: $GITEA_USERNAME"
  fi

  # Generate security tokens if they don't exist
  if kubectl get secret gitea-security --context "${context}" -n gitea >/dev/null 2>&1; then
    echo "✅ Gitea security tokens already exist"
  else
    echo "🔑 Generating security tokens..."
    INTERNAL_TOKEN=$(generate_jwt_secret)
    SECRET_KEY=$(generate_random_string 64)
    JWT_SECRET=$(generate_jwt_secret)
    LFS_JWT_SECRET=$(generate_random_string 43)
    
    kubectl create secret generic gitea-security \
      --context "${context}" \
      --from-literal=internal-token="$INTERNAL_TOKEN" \
      --from-literal=secret-key="$SECRET_KEY" \
      --from-literal=jwt-secret="$JWT_SECRET" \
      --from-literal=lfs-jwt-secret="$LFS_JWT_SECRET" \
      --namespace=gitea
      
    echo "✅ Created security tokens"
  fi

  # Generate TLS certificates if gitea binary is available
  if [ -f "./gitea" ]; then
    echo "🔒 Generating TLS certificates..."
    ./gitea cert --host "$(platform_destination_ip)" --ca

    kubectl create secret generic gitea-tls \
      --context "${context}" \
      --from-file=caFile="./cert.pem" \
      --from-file=privateKey="./key.pem" \
      --namespace=gitea \
      --dry-run=client -o yaml | kubectl apply --context "${context}" -f -

    # Also create in default namespace for compatibility
    kubectl create secret generic gitea-credentials \
      --context "${context}" \
      --from-file=caFile="./cert.pem" \
      --from-file=privateKey="./key.pem" \
      --from-literal=username="$GITEA_USERNAME" \
      --from-literal=password="$GITEA_PASSWORD" \
      --namespace=default \
      --dry-run=client -o yaml | kubectl apply --context "${context}" -f -

    rm ./cert.pem ./key.pem
    echo "✅ Created TLS certificates"
  else
    echo "⚠️  Gitea binary not found, skipping TLS certificate generation"
    echo "   Download from: https://docs.gitea.com/installation/install-from-binary"
    
    # Create compatibility secret without TLS
    kubectl create secret generic gitea-credentials \
      --context "${context}" \
      --from-literal=username="$GITEA_USERNAME" \
      --from-literal=password="$GITEA_PASSWORD" \
      --namespace=default \
      --dry-run=client -o yaml | kubectl apply --context "${context}" -f -
  fi

  echo ""
  echo "📋 Gitea Credentials Summary:"
  echo "  Admin Username: $GITEA_USERNAME"
  echo "  Admin Password: $GITEA_PASSWORD"
  echo ""
  echo "🔐 Secrets created:"
  echo "  gitea-admin (admin credentials)"
  echo "  gitea-security (internal tokens)"
  if [ -f "./gitea" ]; then
    echo "  gitea-tls (certificates)"
  fi
  echo "  gitea-credentials (compatibility - default namespace)"
}

echo "Generating Gitea credentials and namespace..."
generate_gitea_credentials "$1"

echo "Gitea credentials generated"