#!/bin/bash

# End-to-end test runner script for team-promise
# Requires a running Kind cluster with Kratix installed
# Follows the pattern of run-integration-tests.sh

set -e # Exit on any error

echo "🔬 Running team-promise end-to-end tests..."
echo

# Check cluster is accessible
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "❌ Kubernetes cluster not accessible."
  echo "   Run ./scripts/build-poc.sh or ./scripts/01-setup-cluster.sh + ./scripts/02-install-kratix.sh first."
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
$SCRIPT_DIR/update-promise.sh

echo "⏳ Waiting for Promise to be ready..."
kubectl wait --for=condition=Available promise/team --timeout=180s

cd tests

# Check if virtual environment exists
if [ ! -d "test-env" ]; then
  echo "Creating virtual environment in tests/test-env/..."
  python -m venv test-env
fi

echo "Activating virtual environment..."
source test-env/bin/activate

echo "Installing/updating test dependencies..."
pip install -r requirements.txt

echo
echo "Running end-to-end tests..."
python -m pytest e2e/ -v -s

echo
echo "✅ All end-to-end tests completed successfully!"

deactivate
echo "Virtual environment deactivated."
