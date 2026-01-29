#!/usr/bin/env sh

set -xe

# Install Python dependencies
pip install pyyaml

# Run the Python configure script
python3 /scripts/configure.py
