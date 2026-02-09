#!/bin/bash

set -e

echo "📦 Installing Team Promise..."

# Podman prefixes images with localhost/ automatically; Docker does not.
# Use the localhost/ prefix explicitly so kind load works on both runtimes.
if podman --version >/dev/null 2>&1 && ! [ -f /etc/containers/nodocker ]; then
  IMAGE_TAG="localhost/team-configure:latest"
else
  IMAGE_TAG="team-configure:latest"
fi

# Detect Kind cluster name from current kubectl context (kind-<name> → <name>)
CLUSTER_NAME=$(kubectl config current-context | sed 's/^kind-//')
echo "  Using Kind cluster: $CLUSTER_NAME"

if [ "${CI:-}" = "true" ]; then
  docker buildx build \
    --cache-from type=gha \
    --cache-to type=gha,mode=max \
    --load -t "$IMAGE_TAG" \
    promises/team-promise/workflows/resource/configure/team-configure/python
else
  docker build -t "$IMAGE_TAG" promises/team-promise/workflows/resource/configure/team-configure/python
fi
kind load docker-image -n "$CLUSTER_NAME" "$IMAGE_TAG"

# Install the Team Promise
kubectl apply -f promises/team-promise/promise.yaml
