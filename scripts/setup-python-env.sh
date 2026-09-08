#!/usr/bin/env bash
set -euo pipefail

if [ ! -d "venv" ]; then
    echo "Creating venv..."
    python3 -m venv venv
else
    echo "venv already exists, skipping creation"
fi

venv/bin/pip install -r requirements.txt

if [ ! -f ".env" ]; then
    echo "WARNING: .env not found! Create it with POSTGRES_PASSWORD before running the generator."
fi

echo "Done! Run 'source venv/bin/activate' to activate the environment."
