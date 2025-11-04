#!/bin/bash
# @file
# Local CI Build Script for OvmfPkg
#
# This script builds OvmfPkg configurations locally
# Based on OvmfPkg/PlatformCI/.azurepipelines/Ubuntu-GCC.yml
#
# Usage:
#   ./ci-local-ovmf.sh [CONFIG] [TARGET]
#
# Configurations:
#   X64         - X64 only (default)
#   IA32X64     - IA32 PEI + X64 DXE
#   FULL        - Full featured (SecureBoot, SMM, TPM2, Network)
#   MM          - With StandaloneMM
#   AMDSEV      - AMD SEV confidential computing
#   BHYVE       - FreeBSD bhyve
#   CLOUDHV     - Cloud Hypervisor
#   MICROVM     - QEMU microvm
#   XEN         - Xen hypervisor
#   INTELTDX    - Intel TDX confidential computing
#   RISCV64     - RISC-V 64-bit
#   LOONGARCH64 - LoongArch 64-bit
#
# Targets: DEBUG, RELEASE, NOOPT (default: DEBUG)
#
# Examples:
#   ./ci-local-ovmf.sh X64 DEBUG
#   ./ci-local-ovmf.sh FULL RELEASE
#   ./ci-local-ovmf.sh IA32X64 DEBUG
#
# SPDX-License-Identifier: BSD-2-Clause-Patent

set -e

CONFIG="${1:-X64}"
TARGET="${2:-DEBUG}"
TOOL_CHAIN_TAG="GCC5"

# Configuration mapping
case "${CONFIG}" in
    X64)
        BUILD_FILE="OvmfPkg/PlatformCI/PlatformBuild.py"
        BUILD_ARCH="X64"
        BUILD_FLAGS=""
        RUN_FLAGS="MAKE_STARTUP_NSH=TRUE QEMU_HEADLESS=TRUE"
        ;;
    IA32X64)
        BUILD_FILE="OvmfPkg/PlatformCI/PlatformBuild.py"
        BUILD_ARCH="IA32,X64"
        BUILD_FLAGS=""
        RUN_FLAGS="MAKE_STARTUP_NSH=TRUE QEMU_HEADLESS=TRUE"
        ;;
    FULL)
        BUILD_FILE="OvmfPkg/PlatformCI/PlatformBuild.py"
        BUILD_ARCH="IA32,X64"
        BUILD_FLAGS="BLD_*_SECURE_BOOT_ENABLE=1 BLD_*_SMM_REQUIRE=1 BLD_*_TPM2_ENABLE=1 BLD_*_NETWORK_TLS_ENABLE=1 BLD_*_NETWORK_IP6_ENABLE=1 BLD_*_NETWORK_HTTP_BOOT_ENABLE=1"
        RUN_FLAGS="MAKE_STARTUP_NSH=TRUE QEMU_HEADLESS=TRUE"
        ;;
    MM)
        BUILD_FILE="OvmfPkg/PlatformCI/PlatformBuild.py"
        BUILD_ARCH="X64"
        BUILD_FLAGS="BLD_*_SECURE_BOOT_ENABLE=1 BLD_*_SMM_REQUIRE=1 BLD_*_TPM2_ENABLE=1 BLD_*_NETWORK_TLS_ENABLE=1 BLD_*_NETWORK_IP6_ENABLE=1 BLD_*_NETWORK_HTTP_BOOT_ENABLE=1 BLD_*_STANDALONE_MM_ENABLE=1"
        RUN_FLAGS="MAKE_STARTUP_NSH=TRUE QEMU_HEADLESS=TRUE"
        ;;
    AMDSEV)
        BUILD_FILE="OvmfPkg/PlatformCI/AmdSevBuild.py"
        BUILD_ARCH="X64"
        BUILD_FLAGS=""
        RUN_FLAGS="QEMU_SKIP=TRUE"
        ;;
    BHYVE)
        BUILD_FILE="OvmfPkg/PlatformCI/BhyveBuild.py"
        BUILD_ARCH="X64"
        BUILD_FLAGS=""
        RUN_FLAGS="QEMU_SKIP=TRUE"
        ;;
    CLOUDHV)
        BUILD_FILE="OvmfPkg/PlatformCI/CloudHvBuild.py"
        BUILD_ARCH="X64"
        BUILD_FLAGS=""
        RUN_FLAGS="QEMU_SKIP=TRUE"
        ;;
    MICROVM)
        BUILD_FILE="OvmfPkg/PlatformCI/MicrovmBuild.py"
        BUILD_ARCH="X64"
        BUILD_FLAGS=""
        RUN_FLAGS="QEMU_SKIP=TRUE"
        ;;
    XEN)
        BUILD_FILE="OvmfPkg/PlatformCI/XenBuild.py"
        BUILD_ARCH="X64"
        BUILD_FLAGS=""
        RUN_FLAGS="QEMU_SKIP=TRUE"
        ;;
    INTELTDX)
        BUILD_FILE="OvmfPkg/PlatformCI/IntelTdxBuild.py"
        BUILD_ARCH="X64"
        BUILD_FLAGS=""
        RUN_FLAGS="QEMU_SKIP=TRUE"
        ;;
    RISCV64)
        BUILD_FILE="OvmfPkg/PlatformCI/QemuBuild.py"
        BUILD_ARCH="RISCV64"
        BUILD_FLAGS=""
        RUN_FLAGS="QEMU_SKIP=TRUE"
        ;;
    LOONGARCH64)
        BUILD_FILE="OvmfPkg/PlatformCI/QemuBuild.py"
        BUILD_ARCH="LOONGARCH64"
        BUILD_FLAGS=""
        RUN_FLAGS="QEMU_SKIP=TRUE"
        ;;
    *)
        echo "Error: Unknown configuration '${CONFIG}'"
        echo "Valid configurations: X64, IA32X64, FULL, MM, AMDSEV, BHYVE, CLOUDHV, MICROVM, XEN, INTELTDX, RISCV64, LOONGARCH64"
        exit 1
        ;;
esac

echo "========================================="
echo "OvmfPkg Platform CI Build"
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

# Optional: Run in QEMU (only if not skipped)
if [[ "${RUN_FLAGS}" != *"QEMU_SKIP=TRUE"* ]]; then
    echo ""
    read -p "Run in QEMU? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Running in QEMU (headless, will timeout in 2 minutes)..."
        stuart_build -c "${BUILD_FILE}" TOOL_CHAIN_TAG="${TOOL_CHAIN_TAG}" TARGET="${TARGET}" -a "${BUILD_ARCH}" ${BUILD_FLAGS} ${RUN_FLAGS} --FlashOnly || true
    fi
fi
