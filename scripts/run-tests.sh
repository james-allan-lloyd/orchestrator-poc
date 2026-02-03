#!/bin/bash

# Test runner script for team-promise
# Follows the instructions in CLAUDE.md

set -e  # Exit on any error

echo "🧪 Running team-promise tests..."
echo

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
echo "Running unit tests..."
PYTHONPATH=../promises/team-promise/workflows/resource/configure/team-configure/python/scripts python -m pytest unit/ -v

echo
echo "✅ All tests completed successfully!"

deactivate
echo "Virtual environment deactivated."