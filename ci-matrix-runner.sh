#!/bin/bash
# @file
# CI Matrix Build Runner
#
# Runs all CI matrix builds, tracks progress, and preserves outputs.
# Can resume from failures and skip already-successful builds.
#
# Usage:
#   ./ci-matrix-runner.sh [OPTIONS]
#
# Options:
#   --all-targets     Build DEBUG, RELEASE, and NOOPT (default: DEBUG only)
#   --retry-failed    Retry previously failed jobs
#   --clean           Remove all previous build results and start fresh
#   --jobs N          Run N jobs in parallel (default: 1)
#   --core-only       Run only core package builds
#   --platforms-only  Run only platform builds
#   --help            Show this help
#
# SPDX-License-Identifier: BSD-2-Clause-Patent

set -e

# Default configuration
BUILD_TARGETS="DEBUG"
RETRY_FAILED=false
CLEAN=false
PARALLEL_JOBS=1
BUILD_CORE=true
BUILD_PLATFORMS=true

# Directories
MATRIX_DIR="ci-matrix-builds"
STATUS_DIR="${MATRIX_DIR}/status"
LOGS_DIR="${MATRIX_DIR}/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --all-targets)
            BUILD_TARGETS="DEBUG,RELEASE,NOOPT"
            shift
            ;;
        --retry-failed)
            RETRY_FAILED=true
            shift
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --jobs)
            PARALLEL_JOBS="$2"
            shift 2
            ;;
        --core-only)
            BUILD_CORE=true
            BUILD_PLATFORMS=false
            shift
            ;;
        --platforms-only)
            BUILD_CORE=false
            BUILD_PLATFORMS=true
            shift
            ;;
        --help)
            head -n 20 "$0" | grep "^#" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Initialize directories
mkdir -p "${STATUS_DIR}" "${LOGS_DIR}"

# Clean if requested
if [ "${CLEAN}" = true ]; then
    echo -e "${YELLOW}Cleaning previous build results...${NC}"
    rm -rf "${MATRIX_DIR}"
    mkdir -p "${STATUS_DIR}" "${LOGS_DIR}"
    echo "Clean complete."
fi

# Ensure virtual environment is activated
if [ -z "${VIRTUAL_ENV}" ]; then
    if [ -f "${HOME}/venv-edk2/bin/activate" ]; then
        echo "Activating Python virtual environment..."
        source "${HOME}/venv-edk2/bin/activate"
    else
        echo -e "${RED}ERROR: Virtual environment not found!${NC}"
        echo "Run ./ci-local-setup.sh first"
        exit 1
    fi
fi

export PATH="${HOME}/.local/bin:${PATH}"

# Job status functions
job_key() {
    local type="$1"
    local name="$2"
    local target="$3"
    echo "${type}-${name}-${target}" | tr ' ,/' '_'
}

job_status_file() {
    echo "${STATUS_DIR}/$(job_key "$@").status"
}

job_log_file() {
    echo "${LOGS_DIR}/$(job_key "$@").log"
}

job_build_dir() {
    local type="$1"
    local name="$2"
    local target="$3"
    echo "${MATRIX_DIR}/$(job_key "$@")"
}

mark_job_status() {
    local status="$1"
    shift
    echo "${status}" > "$(job_status_file "$@")"
}

get_job_status() {
    local status_file="$(job_status_file "$@")"
    if [ -f "${status_file}" ]; then
        cat "${status_file}"
    else
        echo "PENDING"
    fi
}

should_run_job() {
    local status="$(get_job_status "$@")"

    if [ "${status}" = "SUCCESS" ]; then
        return 1  # Don't run
    elif [ "${status}" = "FAILED" ] && [ "${RETRY_FAILED}" = false ]; then
        return 1  # Don't run
    else
        return 0  # Run
    fi
}

# Build a single job
run_job() {
    local type="$1"
    local name="$2"
    local target="$3"
    shift 3
    local extra_args=("$@")

    local key="$(job_key "${type}" "${name}" "${target}")"
    local log_file="$(job_log_file "${type}" "${name}" "${target}")"
    local build_dir="$(job_build_dir "${type}" "${name}" "${target}")"

    echo -e "${BLUE}[${key}]${NC} Starting..."
    mark_job_status "RUNNING" "${type}" "${name}" "${target}"

    # Start time
    local start_time=$(date +%s)

    # Run the build and capture output
    local build_result=0
    {
        echo "========================================="
        echo "Job: ${key}"
        echo "Type: ${type}"
        echo "Name: ${name}"
        echo "Target: ${target}"
        echo "Extra Args: ${extra_args[*]}"
        echo "Started: $(date)"
        echo "========================================="
        echo ""

        case "${type}" in
            CORE)
                ./ci-local-core-packages.sh "${name}" "${extra_args[@]}" "${target}"
                ;;
            OVMF)
                ./ci-local-ovmf.sh "${name}" "${target}"
                ;;
            ARMVIRT)
                ./ci-local-armvirt.sh "${name}" "${target}"
                ;;
            EMULATOR)
                ./ci-local-emulator.sh "${target}" "${name}"
                ;;
        esac

        echo ""
        echo "========================================="
        echo "Completed: $(date)"
        echo "========================================="
    } > "${log_file}" 2>&1 || build_result=$?

    # End time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Preserve Build/ directory
    if [ -d "Build" ]; then
        mkdir -p "${build_dir}"
        cp -r Build/* "${build_dir}/" 2>/dev/null || true
    fi

    # Update status
    if [ ${build_result} -eq 0 ]; then
        mark_job_status "SUCCESS" "${type}" "${name}" "${target}"
        echo -e "${GREEN}[${key}]${NC} SUCCESS (${duration}s)"
        return 0
    else
        mark_job_status "FAILED" "${type}" "${name}" "${target}"
        echo -e "${RED}[${key}]${NC} FAILED (${duration}s)"
        echo "  Log: ${log_file}"
        return 1
    fi
}

# Generate job list
generate_jobs() {
    local jobs=()

    # Core package jobs (from Ubuntu-GCC.yml matrix)
    if [ "${BUILD_CORE}" = true ]; then
        # Split targets by comma
        IFS=',' read -ra TARGETS <<< "${BUILD_TARGETS}"

        for target in "${TARGETS[@]}"; do
            # TARGET_ARM_ARMPLATFORM
            jobs+=("CORE|ArmPkg,ArmPlatformPkg|${target}|IA32,X64,AARCH64,RISCV64,LOONGARCH64")

            # TARGET_MDE_CPU
            jobs+=("CORE|MdePkg,UefiCpuPkg|${target}|IA32,X64,AARCH64,RISCV64,LOONGARCH64")

            # TARGET_MDEMODULE (split for DEBUG/NOOPT vs RELEASE)
            if [ "${target}" = "DEBUG" ] || [ "${target}" = "NOOPT" ]; then
                jobs+=("CORE|MdeModulePkg|${target}|IA32,X64,AARCH64,RISCV64,LOONGARCH64")
            elif [ "${target}" = "RELEASE" ]; then
                jobs+=("CORE|MdeModulePkg|${target},NO-TARGET|IA32,X64,AARCH64,RISCV64,LOONGARCH64")
            fi

            # TARGET_NETWORK
            jobs+=("CORE|NetworkPkg,RedfishPkg|${target}|IA32,X64,AARCH64,RISCV64,LOONGARCH64")

            # TARGET_OTHER
            jobs+=("CORE|PcAtChipsetPkg,PrmPkg,ShellPkg,SourceLevelDebugPkg,StandaloneMmPkg,SignedCapsulePkg|${target}|IA32,X64,AARCH64,RISCV64,LOONGARCH64")

            # TARGET_FMP_FAT_TEST
            jobs+=("CORE|FmpDevicePkg,FatPkg,UnitTestFrameworkPkg,DynamicTablesPkg|${target}|IA32,X64,AARCH64,RISCV64,LOONGARCH64")

            # TARGET_CRYPTO (split for DEBUG/NOOPT vs RELEASE)
            if [ "${target}" = "DEBUG" ] || [ "${target}" = "NOOPT" ]; then
                jobs+=("CORE|CryptoPkg|${target}|IA32,X64,AARCH64,RISCV64,LOONGARCH64")
            elif [ "${target}" = "RELEASE" ]; then
                jobs+=("CORE|CryptoPkg|${target},NO-TARGET|IA32,X64,AARCH64,RISCV64,LOONGARCH64")
            fi

            # TARGET_FSP
            jobs+=("CORE|IntelFsp2Pkg,IntelFsp2WrapperPkg|${target}|IA32,X64,AARCH64,RISCV64,LOONGARCH64")

            # TARGET_SECURITY
            jobs+=("CORE|SecurityPkg|${target}|IA32,X64,AARCH64,RISCV64,LOONGARCH64")

            # TARGET_UEFIPAYLOAD_IA32_X64
            jobs+=("CORE|UefiPayloadPkg|${target}|IA32,X64")

            # TARGET_UEFIPAYLOAD_AARCH64_GCC_ONLY
            jobs+=("CORE|UefiPayloadPkg|${target}|AARCH64")

            # TARGET_PLATFORMS (NO-TARGET only for code checks)
            if [ "${target}" = "NOOPT" ]; then
                jobs+=("CORE|ArmVirtPkg,EmulatorPkg,OvmfPkg|NO-TARGET,NOOPT|IA32,X64,AARCH64,RISCV64,LOONGARCH64")
            fi

            # EmbeddedPkg (GCC only)
            jobs+=("CORE|EmbeddedPkg|${target}|IA32,X64,AARCH64,RISCV64,LOONGARCH64")
        done
    fi

    # Platform jobs
    if [ "${BUILD_PLATFORMS}" = true ]; then
        IFS=',' read -ra TARGETS <<< "${BUILD_TARGETS}"

        for target in "${TARGETS[@]}"; do
            # OvmfPkg configurations
            jobs+=("OVMF|X64|${target}")
            jobs+=("OVMF|IA32X64|${target}")

            # Skip FULL NOOPT - too large for FDF
            if [ "${target}" != "NOOPT" ]; then
                jobs+=("OVMF|FULL|${target}")
                jobs+=("OVMF|MM|${target}")
            fi

            # Other OVMF variants (DEBUG only to save time)
            if [ "${target}" = "DEBUG" ]; then
                jobs+=("OVMF|AMDSEV|${target}")
                jobs+=("OVMF|BHYVE|${target}")
                jobs+=("OVMF|CLOUDHV|${target}")
                jobs+=("OVMF|MICROVM|${target}")
                jobs+=("OVMF|XEN|${target}")
                jobs+=("OVMF|INTELTDX|${target}")
                jobs+=("OVMF|RISCV64|${target}")
                jobs+=("OVMF|LOONGARCH64|${target}")
            fi

            # ArmVirtPkg configurations
            jobs+=("ARMVIRT|QEMU|${target}")
            jobs+=("ARMVIRT|QEMU_KERNEL|${target}")

            # KVMTOOL and CLOUDHV (DEBUG only)
            if [ "${target}" = "DEBUG" ]; then
                jobs+=("ARMVIRT|KVMTOOL|${target}")
                jobs+=("ARMVIRT|CLOUDHV|${target}")
            fi

            # EmulatorPkg
            jobs+=("EMULATOR||${target}")
            jobs+=("EMULATOR|FULL|${target}")
        done
    fi

    printf '%s\n' "${jobs[@]}"
}

# Main execution
main() {
    echo "========================================="
    echo "EDK2 CI Matrix Build Runner"
    echo "========================================="
    echo "Build Targets: ${BUILD_TARGETS}"
    echo "Parallel Jobs: ${PARALLEL_JOBS}"
    echo "Build Core: ${BUILD_CORE}"
    echo "Build Platforms: ${BUILD_PLATFORMS}"
    echo "Retry Failed: ${RETRY_FAILED}"
    echo "Output Directory: ${MATRIX_DIR}"
    echo "========================================="
    echo ""

    # Generate job list
    local all_jobs=($(generate_jobs))
    local total_jobs=${#all_jobs[@]}

    echo "Total jobs in matrix: ${total_jobs}"
    echo ""

    # Filter jobs that need to run
    local jobs_to_run=()
    local skipped=0

    for job_spec in "${all_jobs[@]}"; do
        IFS='|' read -ra JOB <<< "${job_spec}"
        local type="${JOB[0]}"
        local name="${JOB[1]}"
        local target="${JOB[2]}"
        local arch="${JOB[3]:-}"

        if should_run_job "${type}" "${name}" "${target}"; then
            jobs_to_run+=("${job_spec}")
        else
            local status="$(get_job_status "${type}" "${name}" "${target}")"
            echo -e "${YELLOW}Skipping [$(job_key "${type}" "${name}" "${target}")]${NC} - ${status}"
            ((skipped++))
        fi
    done

    local to_run=${#jobs_to_run[@]}

    echo ""
    echo "Jobs to run: ${to_run}"
    echo "Jobs skipped: ${skipped}"
    echo ""

    if [ ${to_run} -eq 0 ]; then
        echo "Nothing to do!"
        print_summary
        exit 0
    fi

    # Run jobs
    local current=0
    local success=0
    local failed=0

    for job_spec in "${jobs_to_run[@]}"; do
        ((current++))

        IFS='|' read -ra JOB <<< "${job_spec}"
        local type="${JOB[0]}"
        local name="${JOB[1]}"
        local target="${JOB[2]}"
        local arch="${JOB[3]:-}"

        echo ""
        echo "========================================="
        echo "Job ${current}/${to_run}"
        echo "========================================="

        if run_job "${type}" "${name}" "${target}" "${arch}"; then
            ((success++))
        else
            ((failed++))
        fi

        echo ""
    done

    # Print summary
    echo ""
    echo "========================================="
    echo "Build Matrix Complete"
    echo "========================================="
    echo -e "Total jobs: ${total_jobs}"
    echo -e "Jobs run: ${to_run}"
    echo -e "Jobs skipped: ${skipped}"
    echo -e "${GREEN}Successful: ${success}${NC}"
    echo -e "${RED}Failed: ${failed}${NC}"
    echo "========================================="
    echo ""

    print_summary

    if [ ${failed} -gt 0 ]; then
        exit 1
    fi
}

print_summary() {
    echo ""
    echo "Summary of all jobs:"
    echo "========================================="

    local success_count=0
    local failed_count=0
    local pending_count=0

    for status_file in "${STATUS_DIR}"/*.status; do
        if [ ! -f "${status_file}" ]; then
            continue
        fi

        local job_name=$(basename "${status_file}" .status)
        local status=$(cat "${status_file}")

        case "${status}" in
            SUCCESS)
                echo -e "${GREEN}✓${NC} ${job_name}"
                ((success_count++))
                ;;
            FAILED)
                echo -e "${RED}✗${NC} ${job_name}"
                ((failed_count++))
                ;;
            *)
                echo -e "${YELLOW}○${NC} ${job_name} (${status})"
                ((pending_count++))
                ;;
        esac
    done

    echo "========================================="
    echo -e "${GREEN}Success: ${success_count}${NC} | ${RED}Failed: ${failed_count}${NC} | ${YELLOW}Pending: ${pending_count}${NC}"
    echo ""

    if [ ${failed_count} -gt 0 ]; then
        echo "Failed job logs:"
        for status_file in "${STATUS_DIR}"/*.status; do
            if [ -f "${status_file}" ] && [ "$(cat "${status_file}")" = "FAILED" ]; then
                local job_name=$(basename "${status_file}" .status)
                echo "  ${LOGS_DIR}/${job_name}.log"
            fi
        done
        echo ""
        echo "To retry failed jobs, run:"
        echo "  $0 --retry-failed"
    fi

    echo ""
    echo "Build artifacts preserved in: ${MATRIX_DIR}/"
}

# Run main
main
