#!/bin/bash
# @file
# Local CI Setup Script - Extracted from Azure Pipelines CI configuration
#
# This script sets up the environment for running EDK2 CI locally
# Based on .azurepipelines/Ubuntu-GCC.yml and templates/pr-gate-steps.yml
#
# SPDX-License-Identifier: BSD-2-Clause-Patent

set -e

# Add ~/.local/bin to PATH (where pip installs tools)
export PATH="${HOME}/.local/bin:${PATH}"
echo "Updated PATH: ${PATH}"

# Create and activate Python virtual environment
if [ ! -d "${HOME}/venv-edk2" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "${HOME}/venv-edk2"
fi

echo "Activating virtual environment..."
source "${HOME}/venv-edk2/bin/activate"

# Install/upgrade Python requirements
echo "Installing Python dependencies..."
pip install --upgrade -r pip-requirements.txt

# Install spell check prerequisites (optional, comment out if not needed)
# Requires Node.js to be installed first
if command -v npm &> /dev/null; then
    echo "Installing cspell for spell checking..."
    npm install -g cspell@5.20.0
else
    echo "WARNING: npm not found. Skipping cspell installation."
    echo "Install Node.js from https://nodejs.org/ if you need spell checking."
fi

echo ""
echo "Setup complete! Virtual environment is activated."
echo "To activate this environment in the future, run:"
echo "  source ${HOME}/venv-edk2/bin/activate"
