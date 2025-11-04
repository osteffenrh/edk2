#!/bin/bash
# @file
# Local CI Build Script for ArmVirtPkg
#
# This script builds ArmVirtPkg configurations locally
# Based on ArmVirtPkg/PlatformCI/.azurepipelines/Ubuntu-GCC.yml
#
# Usage:
#   ./ci-local-armvirt.sh [CONFIG] [TARGET]
#
# Configurations:
#   QEMU        - QEMU AARCH64 (default)
#   QEMU_KERNEL - QEMU with kernel support
#   KVMTOOL     - KVM tool
#   CLOUDHV     - Cloud Hypervisor
#
# Targets: DEBUG, RELEASE, NOOPT (default: DEBUG)
#
# Examples:
#   ./ci-local-armvirt.sh QEMU DEBUG
#   ./ci-local-armvirt.sh QEMU_KERNEL RELEASE
#
# SPDX-License-Identifier: BSD-2-Clause-Patent

set -e

CONFIG="${1:-QEMU}"
TARGET="${2:-DEBUG}"
TOOL_CHAIN_TAG="GCC5"

# Configuration mapping
case "${CONFIG}" in
    QEMU)
        BUILD_FILE="ArmVirtPkg/PlatformCI/QemuBuild.py"
        BUILD_ARCH="AARCH64"
        BUILD_FLAGS="BLD_*_SECURE_BOOT_ENABLE=1 BLD_*_TPM2_ENABLE=1 BLD_*_NETWORK_TLS_ENABLE=1 BLD_*_NETWORK_IP6_ENABLE=1 BLD_*_NETWORK_HTTP_BOOT_ENABLE=1"
        RUN_FLAGS="MAKE_STARTUP_NSH=TRUE QEMU_HEADLESS=TRUE"
        SHOULD_RUN=true
        ;;
    QEMU_KERNEL)
        BUILD_FILE="ArmVirtPkg/PlatformCI/QemuKernelBuild.py"
        BUILD_ARCH="AARCH64"
        BUILD_FLAGS=""
        RUN_FLAGS="MAKE_STARTUP_NSH=TRUE QEMU_HEADLESS=TRUE"
        SHOULD_RUN=true
        ;;
    KVMTOOL)
        BUILD_FILE="ArmVirtPkg/PlatformCI/KvmToolBuild.py"
        BUILD_ARCH="AARCH64"
        BUILD_FLAGS=""
        RUN_FLAGS=""
        SHOULD_RUN=false
        ;;
    CLOUDHV)
        BUILD_FILE="ArmVirtPkg/PlatformCI/CloudHvBuild.py"
        BUILD_ARCH="AARCH64"
        BUILD_FLAGS=""
        RUN_FLAGS=""
        SHOULD_RUN=false
        ;;
    *)
        echo "Error: Unknown configuration '${CONFIG}'"
        echo "Valid configurations: QEMU, QEMU_KERNEL, KVMTOOL, CLOUDHV"
        exit 1
        ;;
esac

echo "========================================="
echo "ArmVirtPkg Platform CI Build"
echo "========================================="
echo "Configuration: ${CONFIG}"
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

# Optional: Run in QEMU (only for configurations that support it)
if [ "${SHOULD_RUN}" = true ]; then
    echo ""
    read -p "Run in QEMU? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Running in QEMU (headless, will timeout in 2 minutes)..."
        stuart_build -c "${BUILD_FILE}" TOOL_CHAIN_TAG="${TOOL_CHAIN_TAG}" TARGET="${TARGET}" -a "${BUILD_ARCH}" ${BUILD_FLAGS} ${RUN_FLAGS} --FlashOnly || true
    fi
fi
