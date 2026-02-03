#!/bin/bash

# Contract test runner script
# Follows the instructions in CLAUDE.md

set -e  # Exit on any error

echo "📋 Running team-promise contract tests..."
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
echo "Running contract tests..."
python -m pytest contract/ -v

echo
echo "✅ All contract tests completed successfully!"

deactivate
echo "Virtual environment deactivated."