#!/usr/bin/env bash

# setup_venv.sh – creates a Python virtual environment in /opt/vpn_manager
# and installs the required Python package mysqlclient.
# Run this script on the VPS as root (or with sudo) after copying the vpn_manager directory.

set -euo pipefail

# 1. Install system prerequisites (Debian/Ubuntu)
if command -v apt-get >/dev/null 2>&1; then
    echo "Installing system packages..."
    apt-get update -y
    # python3-venv provides the venv module, python3-dev & default-libmysqlclient-dev needed for mysqlclient
    apt-get install -y python3 python3-venv python3-pip python3-dev default-libmysqlclient-dev build-essential pkg-config
else
    echo "Unsupported package manager – you need to install python3, python3-venv, python3-dev and libmysqlclient-dev manually."
    exit 1
fi

VENV_DIR="/opt/vpn_manager/venv"
PYTHON_BIN="/usr/bin/python3"

# 2. Create the virtual environment (overwrite if it already exists)
if [ -d "$VENV_DIR" ]; then
    echo "Virtual environment already exists at $VENV_DIR – removing for a clean install."
    rm -rf "$VENV_DIR"
fi

echo "Creating virtual environment..."
$PYTHON_BIN -m venv "$VENV_DIR"

# 3. Activate the venv and upgrade pip
source "$VENV_DIR/bin/activate"
pip install --upgrade pip setuptools wheel

# 4. Install mysqlclient, flask and websockets inside the venv
pip install mysqlclient flask websockets

deactivate

echo "Virtual environment setup complete. To use it, run:"
echo "    source $VENV_DIR/bin/activate"
