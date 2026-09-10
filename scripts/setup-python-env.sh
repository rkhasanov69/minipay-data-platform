#!/usr/bin/env bash
set -euo pipefail

if ! dpkg -s python3.12-venv &> /dev/null; then
    echo "Installing python3.12-venv..."
    sudo apt update
    sudo apt install -y python3.12-venv
else
    echo "python3.12-venv already installed, skipping"
fi

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

ALIAS_LINE="alias activate-mp=\"source $(pwd)/venv/bin/activate\""

if ! grep -qF "activate-mp" ~/.bashrc; then
    echo "Adding activate-mp alias to ~/.bashrc..."
    echo "$ALIAS_LINE" >> ~/.bashrc
    echo "Run 'source ~/.bashrc' (or open a new terminal) to start using 'activate-mp'."
else
    echo "activate-mp alias already present in ~/.bashrc, skipping"
fi

echo "Done!"
