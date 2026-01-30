#!/usr/bin/env bash

platform_destination_ip() {
  docker inspect kratix-poc-control-plane | yq ".[0].NetworkSettings.Networks.kind.IPAddress"
}

generate_gitea_credentials() {
  # Use gitea from root directory
  local giteabin="./gitea"
  if [ ! -f "$giteabin" ]; then
    echo "gitea binary not found at $giteabin; download here: https://docs.gitea.com/installation/install-from-binary" > /dev/stderr
    exit 1
  fi

  local context="${1:-kind-kratix-poc}"

  $giteabin cert --host "$(platform_destination_ip)" --ca

  kubectl create namespace gitea --context "${context}" || true

  kubectl create secret generic gitea-credentials \
    --context "${context}" \
    --from-file=caFile="./cert.pem" \
    --from-file=privateKey="./key.pem" \
    --from-literal=username="gitea_admin" \
    --from-literal=password="r8sA8CPHD9!bt6d" \
    --namespace=gitea \
    --dry-run=client -o yaml | kubectl apply --context "${context}" -f -

  kubectl create secret generic gitea-credentials \
    --context "${context}" \
    --from-file=caFile="./cert.pem" \
    --from-file=privateKey="./key.pem" \
    --from-literal=username="gitea_admin" \
    --from-literal=password="r8sA8CPHD9!bt6d" \
    --namespace=default \
    --dry-run=client -o yaml | kubectl apply --context "${context}" -f -

  rm ./cert.pem ./key.pem
}

echo "Generating Gitea credentials and namespace..."
generate_gitea_credentials "$1"

echo "Gitea credentials generated"