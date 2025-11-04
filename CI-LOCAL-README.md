# Local CI Scripts - Run Azure Pipeline Builds Locally

This directory contains shell scripts extracted from the Azure Pipelines CI configuration, allowing you to run the same builds locally without needing the Azure infrastructure.

## Prerequisites

- **Python 3.12+** (as specified in .azurepipelines/templates/defaults.yml)
- **Git** with submodules initialized
- **GCC toolchain** for building (on Fedora: `dnf install gcc gcc-c++ make`)
- **Development headers** (on Fedora: `dnf install libuuid-devel`)
- **Optional: Node.js and npm** for spell checking

## Container Information

The Azure Pipelines run in a Fedora 41 container:
- Image: `ghcr.io/tianocore/containers/fedora-41-test:4dbfa9e`
- All scripts are designed to work on Fedora or similar Linux distributions

## Quick Start

1. **Initial Setup** (run once):
   ```bash
   ./ci-local-setup.sh
   ```
   This creates a Python virtual environment and installs dependencies.

2. **Choose a build script** based on what you want to build:
   - Core packages: `./ci-local-core-packages.sh`
   - OvmfPkg: `./ci-local-ovmf.sh`
   - ArmVirtPkg: `./ci-local-armvirt.sh`
   - EmulatorPkg: `./ci-local-emulator.sh`

## Scripts Overview

### ci-local-setup.sh

Sets up the Python virtual environment and installs all dependencies.

**What it does:**
- Creates Python virtual environment at `~/venv-edk2`
- Installs Python packages from `pip-requirements.txt`
- Installs cspell (if Node.js is available)

**Run this first!**

### ci-local-core-packages.sh

Runs CI builds for core EDK2 packages (the main package validation).

**Source:** `.azurepipelines/Ubuntu-GCC.yml` and `templates/pr-gate-steps.yml`

**Usage:**
```bash
./ci-local-core-packages.sh [PACKAGE] [ARCH] [TARGET]
```

**Examples:**
```bash
# Build MdePkg for all architectures
./ci-local-core-packages.sh MdePkg "IA32,X64,AARCH64,RISCV64,LOONGARCH64" "DEBUG,RELEASE,NO-TARGET,NOOPT"

# Build multiple packages for X64 only
./ci-local-core-packages.sh "MdePkg,UefiCpuPkg" "X64" "DEBUG"

# Build OvmfPkg with code checks only (NO-TARGET)
./ci-local-core-packages.sh OvmfPkg "X64" "NO-TARGET,NOOPT"
```

**Default Package Groups** (from Azure Pipeline matrix):
- `ArmPkg,ArmPlatformPkg`
- `MdePkg,UefiCpuPkg`
- `MdeModulePkg`
- `NetworkPkg,RedfishPkg`
- `CryptoPkg`
- `SecurityPkg`
- `UefiPayloadPkg`
- etc.

**What it does:**
1. `stuart_setup` - Initialize submodules and dependencies
2. `stuart_update` - Update external dependencies
3. Build BaseTools
4. `stuart_ci_build` - Build packages and run CI tests

### ci-local-ovmf.sh

Builds OvmfPkg (QEMU/KVM virtual platform) configurations.

**Source:** `OvmfPkg/PlatformCI/.azurepipelines/Ubuntu-GCC.yml`

**Usage:**
```bash
./ci-local-ovmf.sh [CONFIG] [TARGET]
```

**Configurations:**
- `X64` - X64 only (default)
- `IA32X64` - IA32 PEI + X64 DXE
- `FULL` - Full featured (SecureBoot, SMM, TPM2, Network with TLS, IP6, HTTP boot)
- `MM` - With StandaloneMM
- `AMDSEV` - AMD SEV confidential computing
- `BHYVE` - FreeBSD bhyve hypervisor
- `CLOUDHV` - Cloud Hypervisor
- `MICROVM` - QEMU microvm
- `XEN` - Xen hypervisor
- `INTELTDX` - Intel TDX confidential computing
- `RISCV64` - RISC-V 64-bit
- `LOONGARCH64` - LoongArch 64-bit

**Targets:** `DEBUG`, `RELEASE`, `NOOPT`

**Examples:**
```bash
# Build standard X64 OVMF in DEBUG mode
./ci-local-ovmf.sh X64 DEBUG

# Build full-featured IA32+X64 OVMF in RELEASE mode
./ci-local-ovmf.sh FULL RELEASE

# Build AMD SEV variant
./ci-local-ovmf.sh AMDSEV DEBUG
```

**What it does:**
1. `stuart_setup`
2. `stuart_update`
3. Build BaseTools
4. `stuart_build` - Build the platform
5. Optionally run in QEMU (prompts user)

### ci-local-armvirt.sh

Builds ArmVirtPkg (ARM virtual platforms) configurations.

**Source:** `ArmVirtPkg/PlatformCI/.azurepipelines/Ubuntu-GCC.yml`

**Usage:**
```bash
./ci-local-armvirt.sh [CONFIG] [TARGET]
```

**Configurations:**
- `QEMU` - QEMU AARCH64 (default, with SecureBoot, TPM2, Network)
- `QEMU_KERNEL` - QEMU with kernel support
- `KVMTOOL` - KVM tool
- `CLOUDHV` - Cloud Hypervisor

**Examples:**
```bash
# Build QEMU AARCH64
./ci-local-armvirt.sh QEMU DEBUG

# Build with kernel support
./ci-local-armvirt.sh QEMU_KERNEL RELEASE
```

### ci-local-emulator.sh

Builds EmulatorPkg (host-based emulator).

**Source:** `EmulatorPkg/PlatformCI/.azurepipelines/Ubuntu-GCC.yml`

**Usage:**
```bash
./ci-local-emulator.sh [TARGET] [SECURE_BOOT]
```

**Examples:**
```bash
# Build standard emulator
./ci-local-emulator.sh DEBUG

# Build with Secure Boot enabled
./ci-local-emulator.sh RELEASE FULL
```

## Build Steps Executed

All platform build scripts follow this sequence (from `templates/platform-build-run-steps.yml`):

1. **Activate Python virtual environment**
2. **stuart_setup** - Initialize submodules and dependencies
3. **stuart_update** - Download/update external dependencies (NASM, IASL, cross-compilers)
4. **Build BaseTools** - `python BaseTools/Edk2ToolsBuild.py -t GCC5`
5. **stuart_build** - Compile the platform firmware
6. **Optional: Run in emulator** (QEMU for OVMF/ArmVirt)

## Build Artifacts

After building, you'll find:

- **Build/** - Main build output directory
  - `BUILDLOG_*.txt` - Build logs
  - `BUILDLOG_*.md` - Markdown build reports
  - `TestSuites.xml` - JUnit test results
  - `**/*.result.xml` - Host-based unit test results
  - `**/BUILD_TOOLS_REPORT.html` - BaseTools build report

- **Build/Ovmf{X64,Ia32X64,...}/** - Platform-specific output
  - Firmware images (.fd files)
  - Build output by module

## Differences from Azure Pipeline

These scripts replicate the Linux (Fedora container) builds. The following Azure-specific features are not included:

- Publishing test results to Azure DevOps
- Publishing build artifacts
- Code coverage report generation (Windows-only job)
- PR evaluation (`stuart_pr_eval` to determine which packages changed)

For PR testing, the scripts build everything. In Azure CI, only changed packages are built.

## Toolchain

All scripts use `TOOL_CHAIN_TAG=GCC5` which works with modern GCC versions despite the name.

## Environment Variables

The scripts set:
- `PATH` - Adds `~/.local/bin` for pip-installed tools
- `VIRTUAL_ENV` - Python virtual environment path

## CI Matrix Details

The Azure Pipeline uses a build matrix to parallelize builds. Here's how packages are grouped:

### Core Package CI (`Ubuntu-GCC.yml`)

| Matrix Job | Packages | Targets | Architectures |
|------------|----------|---------|---------------|
| TARGET_GCC_ONLY | EmbeddedPkg | DEBUG,RELEASE,NO-TARGET,NOOPT | All (IA32,X64,AARCH64,RISCV64,LOONGARCH64) |
| TARGET_ARM_ARMPLATFORM | ArmPkg,ArmPlatformPkg | DEBUG,RELEASE,NO-TARGET,NOOPT | All |
| TARGET_MDE_CPU | MdePkg,UefiCpuPkg | DEBUG,RELEASE,NO-TARGET,NOOPT | All |
| TARGET_MDEMODULE_DEBUG | MdeModulePkg | DEBUG,NOOPT | All |
| TARGET_MDEMODULE_RELEASE | MdeModulePkg | RELEASE,NO-TARGET | All |
| TARGET_NETWORK | NetworkPkg,RedfishPkg | DEBUG,RELEASE,NO-TARGET,NOOPT | All |
| TARGET_OTHER | PcAtChipsetPkg,PrmPkg,ShellPkg,SourceLevelDebugPkg,StandaloneMmPkg,SignedCapsulePkg | DEBUG,RELEASE,NO-TARGET,NOOPT | All |
| TARGET_FMP_FAT_TEST | FmpDevicePkg,FatPkg,UnitTestFrameworkPkg,DynamicTablesPkg | DEBUG,RELEASE,NO-TARGET,NOOPT | All |
| TARGET_CRYPTO_DEBUG | CryptoPkg | DEBUG,NOOPT | All |
| TARGET_CRYPTO_RELEASE | CryptoPkg | RELEASE,NO-TARGET | All |
| TARGET_FSP | IntelFsp2Pkg,IntelFsp2WrapperPkg | DEBUG,RELEASE,NO-TARGET,NOOPT | All |
| TARGET_SECURITY | SecurityPkg | DEBUG,RELEASE,NO-TARGET,NOOPT | All |
| TARGET_UEFIPAYLOAD_IA32_X64 | UefiPayloadPkg | DEBUG,RELEASE,NO-TARGET,NOOPT | IA32,X64 |
| TARGET_UEFIPAYLOAD_AARCH64_GCC_ONLY | UefiPayloadPkg | DEBUG,RELEASE,NO-TARGET,NOOPT | AARCH64 |
| TARGET_PLATFORMS | ArmVirtPkg,EmulatorPkg,OvmfPkg | NO-TARGET,NOOPT | All |

## Troubleshooting

**Problem:** `stuart_*` commands not found
**Solution:** Run `./ci-local-setup.sh` first, and ensure virtual environment is activated

**Problem:** Build fails with missing tools (NASM, IASL, etc.)
**Solution:** Run `stuart_update` - it downloads required tools automatically

**Problem:** QEMU fails to run
**Solution:** Ensure QEMU is installed (`dnf install qemu-system-x86 qemu-system-aarch64`)

**Problem:** Permission denied on scripts
**Solution:** Run `chmod +x ci-local-*.sh`

## Matrix Build Runner

For running all CI matrix builds at once with progress tracking:

### Using Make (Recommended)

```bash
# Initial setup (run once)
make setup

# Run all DEBUG builds
make ci-debug

# Run all builds (DEBUG, RELEASE, NOOPT)
make ci-all

# Run only core package builds
make ci-core

# Run only platform builds
make ci-platforms

# Check status
make ci-status

# Retry failed jobs
make ci-retry

# Clean and start over
make ci-clean
```

### Using the Script Directly

```bash
# Run all DEBUG builds
./ci-matrix-runner.sh

# Run all targets (DEBUG, RELEASE, NOOPT)
./ci-matrix-runner.sh --all-targets

# Run only core packages
./ci-matrix-runner.sh --core-only

# Run only platforms
./ci-matrix-runner.sh --platforms-only

# Retry failed jobs
./ci-matrix-runner.sh --retry-failed

# Clean everything
./ci-matrix-runner.sh --clean

# Run N jobs in parallel (experimental)
./ci-matrix-runner.sh --jobs 4
```

### Features

- **Progress Tracking**: Keeps track of which jobs passed/failed
- **Resume Support**: Rerunning skips successful jobs and can retry failures
- **Preserved Outputs**: Each job's Build/ directory saved to `ci-matrix-builds/<job-name>/`
- **Detailed Logs**: Individual log files for each job in `ci-matrix-builds/logs/`
- **Status Tracking**: Status files in `ci-matrix-builds/status/`
- **Summary Reports**: Shows overall success/failure counts

### Matrix Jobs (DEBUG mode)

**Core Packages** (from Ubuntu-GCC.yml):
- ArmPkg, ArmPlatformPkg
- MdePkg, UefiCpuPkg
- MdeModulePkg
- NetworkPkg, RedfishPkg
- CryptoPkg
- SecurityPkg
- FmpDevicePkg, FatPkg, UnitTestFrameworkPkg, DynamicTablesPkg
- PcAtChipsetPkg, PrmPkg, ShellPkg, SourceLevelDebugPkg, StandaloneMmPkg, SignedCapsulePkg
- IntelFsp2Pkg, IntelFsp2WrapperPkg
- UefiPayloadPkg (IA32,X64 and AARCH64)
- EmbeddedPkg

**OvmfPkg Platforms**:
- X64, IA32X64
- FULL (with SecureBoot/SMM/TPM2/Network)
- MM (StandaloneMM)
- AMDSEV, BHYVE, CLOUDHV, MICROVM, XEN, INTELTDX
- RISCV64, LOONGARCH64

**ArmVirtPkg Platforms**:
- QEMU, QEMU_KERNEL
- KVMTOOL, CLOUDHV

**EmulatorPkg**:
- Standard and FULL (with SecureBoot)

### Output Structure

```
ci-matrix-builds/
├── status/                          # Job status files
│   ├── CORE-MdePkg_UefiCpuPkg-DEBUG.status
│   ├── OVMF-X64-DEBUG.status
│   └── ...
├── logs/                            # Build logs
│   ├── CORE-MdePkg_UefiCpuPkg-DEBUG.log
│   ├── OVMF-X64-DEBUG.log
│   └── ...
├── CORE-MdePkg_UefiCpuPkg-DEBUG/   # Preserved Build/ output
│   ├── BUILDLOG_*.txt
│   ├── TestSuites.xml
│   └── ...
├── OVMF-X64-DEBUG/
└── ...
```

## Additional Resources

- [EDK2 CI Documentation](.pytool/Readme.md)
- [Stuart Build System](https://github.com/tianocore/edk2-pytool-extensions)
- [TianoCore Wiki](https://github.com/tianocore/tianocore.github.io/wiki)
