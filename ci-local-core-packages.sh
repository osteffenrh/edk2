#!/bin/bash
# @file
# Local CI Build Script for Core Packages
#
# This script runs CI builds for core EDK2 packages locally
# Based on .azurepipelines/Ubuntu-GCC.yml and templates/pr-gate-steps.yml
#
# Usage:
#   ./ci-local-core-packages.sh [PACKAGE] [ARCH] [TARGET]
#
# Examples:
#   ./ci-local-core-packages.sh MdePkg "IA32,X64,AARCH64,RISCV64,LOONGARCH64" "DEBUG,RELEASE,NO-TARGET,NOOPT"
#   ./ci-local-core-packages.sh "MdePkg,UefiCpuPkg" "X64" "DEBUG"
#   ./ci-local-core-packages.sh OvmfPkg "X64" "NO-TARGET,NOOPT"
#
# SPDX-License-Identifier: BSD-2-Clause-Patent

set -e

# Default values from Azure Pipeline
PACKAGE="${1:-MdePkg}"
ARCH="${2:-IA32,X64,AARCH64,RISCV64,LOONGARCH64}"
TARGET="${3:-DEBUG,RELEASE,NO-TARGET,NOOPT}"
TOOL_CHAIN_TAG="GCC5"

echo "========================================="
echo "EDK2 Core Package CI Build"
echo "========================================="
echo "Package(s): ${PACKAGE}"
echo "Architecture(s): ${ARCH}"
echo "Target(s): ${TARGET}"
echo "Toolchain: ${TOOL_CHAIN_TAG}"
echo "========================================="

# Ensure virtual environment is activated
if [ -z "${VIRTUAL_ENV}" ]; then
    echo "Activating Python virtual environment..."
    source "${HOME}/venv-edk2/bin/activate"
fi

# Add ~/.local/bin to PATH
export PATH="${HOME}/.local/bin:${PATH}"

# Setup: Initialize submodules and dependencies
echo ""
echo "Step 1: stuart_setup"
echo "-------------------"
stuart_setup -c .pytool/CISettings.py -p "${PACKAGE}" -t "${TARGET}" -a "${ARCH}" TOOL_CHAIN_TAG="${TOOL_CHAIN_TAG}"

# Update: Get external dependencies
echo ""
echo "Step 2: stuart_update"
echo "--------------------"
stuart_update -c .pytool/CISettings.py -p "${PACKAGE}" -t "${TARGET}" -a "${ARCH}" TOOL_CHAIN_TAG="${TOOL_CHAIN_TAG}"

# Build BaseTools from source
echo ""
echo "Step 3: Build BaseTools"
echo "-----------------------"
python BaseTools/Edk2ToolsBuild.py -t "${TOOL_CHAIN_TAG}"

# Run CI build (includes building and testing)
echo ""
echo "Step 4: stuart_ci_build"
echo "----------------------"
stuart_ci_build -c .pytool/CISettings.py -p "${PACKAGE}" -t "${TARGET}" -a "${ARCH}" TOOL_CHAIN_TAG="${TOOL_CHAIN_TAG}"

echo ""
echo "========================================="
echo "Build complete!"
echo "========================================="
echo "Build logs are in: Build/"
echo "Test results: Build/TestSuites.xml"
echo "Host test results: Build/**/*.result.xml"
