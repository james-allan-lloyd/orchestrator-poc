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

docker build -t "$IMAGE_TAG" promises/team-promise/workflows/resource/configure/team-configure/python
kind load docker-image -n kratix-poc "$IMAGE_TAG"

# Install the Team Promise
kubectl apply -f promises/team-promise/promise.yaml
