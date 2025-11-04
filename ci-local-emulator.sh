#!/bin/bash
# @file
# Local CI Build Script for EmulatorPkg
#
# This script builds EmulatorPkg configurations locally
# Based on EmulatorPkg/PlatformCI/.azurepipelines/Ubuntu-GCC.yml
#
# Usage:
#   ./ci-local-emulator.sh [TARGET] [SECURE_BOOT]
#
# Targets: DEBUG, RELEASE, NOOPT (default: DEBUG)
# Secure Boot: Enable with "FULL", disable with "" (default: "")
#
# Examples:
#   ./ci-local-emulator.sh DEBUG
#   ./ci-local-emulator.sh RELEASE FULL
#
# SPDX-License-Identifier: BSD-2-Clause-Patent

set -e

TARGET="${1:-DEBUG}"
SECURE_BOOT="${2:-}"
TOOL_CHAIN_TAG="GCC5"

BUILD_FILE="EmulatorPkg/PlatformCI/PlatformBuild.py"
BUILD_ARCH="X64"
RUN_FLAGS="MAKE_STARTUP_NSH=TRUE"

if [ "${SECURE_BOOT}" = "FULL" ]; then
    BUILD_FLAGS="BLD_*_SECURE_BOOT_ENABLE=TRUE"
    CONFIG_NAME="X64 FULL"
else
    BUILD_FLAGS=""
    CONFIG_NAME="X64"
fi

echo "========================================="
echo "EmulatorPkg Platform CI Build"
echo "========================================="
echo "Configuration: ${CONFIG_NAME}"
echo "Build File: ${BUILD_FILE}"
echo "Architecture: ${BUILD_ARCH}"
echo "Target: ${TARGET}"
echo "Toolchain: ${TOOL_CHAIN_TAG}"
echo "Build Flags: ${BUILD_FLAGS}"
echo "========================================="

# Ensure virtual environment is activated
if [ -z "${VIRTUAL_ENV}" ]; then
    echo "Activating Python virtual environment..."
    source "${HOME}/venv-edk2/bin/activate"
fi

# Add ~/.local/bin to PATH
export PATH="${HOME}/.local/bin:${PATH}"

# Setup
echo ""
echo "Step 1: stuart_setup"
echo "-------------------"
stuart_setup -c "${BUILD_FILE}" TOOL_CHAIN_TAG="${TOOL_CHAIN_TAG}" -t "${TARGET}" -a "${BUILD_ARCH}" ${BUILD_FLAGS}

# Update
echo ""
echo "Step 2: stuart_update"
echo "--------------------"
stuart_update -c "${BUILD_FILE}" TOOL_CHAIN_TAG="${TOOL_CHAIN_TAG}" -t "${TARGET}" -a "${BUILD_ARCH}" ${BUILD_FLAGS}

# Build BaseTools
echo ""
echo "Step 3: Build BaseTools"
echo "-----------------------"
python BaseTools/Edk2ToolsBuild.py -t "${TOOL_CHAIN_TAG}"

# Build
echo ""
echo "Step 4: stuart_build"
echo "-------------------"
stuart_build -c "${BUILD_FILE}" TOOL_CHAIN_TAG="${TOOL_CHAIN_TAG}" TARGET="${TARGET}" -a "${BUILD_ARCH}" ${BUILD_FLAGS}

echo ""
echo "========================================="
echo "Build complete!"
echo "========================================="
echo "Build logs are in: Build/"
echo ""
echo "Note: EmulatorPkg run functionality is disabled in CI (should_run: false)"
echo "To run the emulator manually, use:"
echo "  stuart_build -c ${BUILD_FILE} TOOL_CHAIN_TAG=${TOOL_CHAIN_TAG} TARGET=${TARGET} -a ${BUILD_ARCH} ${BUILD_FLAGS} ${RUN_FLAGS} --FlashOnly"
