# EDK2 CI Matrix Runner - Quick Reference

## Quick Start

```bash
# 1. First time setup
make setup

# 2. Run all DEBUG builds
make ci-debug

# 3. Check status
make ci-status

# 4. Retry failures (if any)
make ci-retry
```

## Common Workflows

### First Time Setup
```bash
make setup                    # Creates venv, installs dependencies
```

### Run All Builds
```bash
make ci-debug                 # DEBUG only (recommended for testing)
make ci-all                   # DEBUG, RELEASE, NOOPT (full matrix)
```

### Selective Builds
```bash
make ci-core                  # Core packages only
make ci-platforms             # Platform builds only
```

### Resume/Retry
```bash
make ci-status                # Check what passed/failed
make ci-retry                 # Retry only failed jobs
./ci-matrix-runner.sh         # Resume (skips successful jobs)
```

### Clean Slate
```bash
make ci-clean                 # Remove all results and start fresh
```

## What Gets Built (DEBUG Mode)

### Core Packages (~14 jobs)
- **ArmPkg, ArmPlatformPkg** - ARM architecture support
- **MdePkg, UefiCpuPkg** - Foundation + CPU
- **MdeModulePkg** - Core modules (DXE, PEI, BDS)
- **NetworkPkg, RedfishPkg** - Network stack + Redfish
- **CryptoPkg** - Cryptography
- **SecurityPkg** - Security features (TPM, SecureBoot)
- **FmpDevicePkg, FatPkg, UnitTestFrameworkPkg, DynamicTablesPkg**
- **PcAtChipsetPkg, PrmPkg, ShellPkg, SourceLevelDebugPkg, StandaloneMmPkg, SignedCapsulePkg**
- **IntelFsp2Pkg, IntelFsp2WrapperPkg** - Intel FSP
- **UefiPayloadPkg** (IA32/X64 + AARCH64)
- **EmbeddedPkg** - Embedded support

### Platform Builds (~18 jobs)

**OvmfPkg** (11 configs):
- X64 - Standard X64 build
- IA32X64 - IA32 PEI + X64 DXE
- FULL - SecureBoot + SMM + TPM2 + Network
- MM - StandaloneMM variant
- AMDSEV - AMD SEV confidential computing
- BHYVE - FreeBSD bhyve
- CLOUDHV - Cloud Hypervisor
- MICROVM - QEMU microvm
- XEN - Xen hypervisor
- INTELTDX - Intel TDX confidential computing
- RISCV64, LOONGARCH64 - RISC-V and LoongArch

**ArmVirtPkg** (4 configs):
- QEMU - QEMU AARCH64 (full featured)
- QEMU_KERNEL - With kernel support
- KVMTOOL - KVM tool
- CLOUDHV - Cloud Hypervisor

**EmulatorPkg** (2 configs):
- Standard - Basic emulator
- FULL - With SecureBoot

**Total: ~32 jobs in DEBUG mode**

## Advanced Usage

### Script Options
```bash
./ci-matrix-runner.sh --all-targets     # DEBUG + RELEASE + NOOPT
./ci-matrix-runner.sh --core-only       # Core packages only
./ci-matrix-runner.sh --platforms-only  # Platforms only
./ci-matrix-runner.sh --retry-failed    # Retry failures
./ci-matrix-runner.sh --clean           # Clean everything
./ci-matrix-runner.sh --jobs 4          # Parallel jobs (experimental)
```

### Make Targets
```bash
make setup          # Initial setup
make ci-debug       # All DEBUG builds
make ci-all         # All targets (DEBUG, RELEASE, NOOPT)
make ci-core        # Core packages only
make ci-platforms   # Platforms only
make ci-status      # Show status
make ci-retry       # Retry failures
make ci-clean       # Clean all results
make help           # Show help
```

## Output Organization

```
ci-matrix-builds/
├── status/                                    # Job status tracking
│   └── CORE-MdePkg_UefiCpuPkg-DEBUG.status   # "SUCCESS" or "FAILED"
├── logs/                                      # Build logs
│   └── CORE-MdePkg_UefiCpuPkg-DEBUG.log      # Full build output
└── CORE-MdePkg_UefiCpuPkg-DEBUG/             # Preserved Build/ directory
    ├── BUILDLOG_*.txt
    ├── TestSuites.xml
    └── ...
```

## Status Indicators

When running `make ci-status`:
- ✓ Green = SUCCESS
- ✗ Red = FAILED
- ○ Yellow = PENDING/RUNNING

## Typical Build Times

**Per Job** (on modern hardware):
- Core packages: 5-15 minutes
- Simple platforms: 3-10 minutes
- Full platforms: 10-20 minutes

**Full DEBUG Matrix** (~32 jobs): 3-8 hours (sequential)

## Tips

1. **Start with core packages only** to verify setup:
   ```bash
   make ci-core
   ```

2. **Check status frequently** to catch failures early:
   ```bash
   make ci-status
   ```

3. **Resume is automatic** - just rerun the same command:
   ```bash
   make ci-debug     # Runs everything
   # ... wait ...
   make ci-debug     # Skips successful, continues failed/pending
   ```

4. **Investigate failures** using log files:
   ```bash
   cat ci-matrix-builds/logs/OVMF-X64-DEBUG.log | less
   ```

5. **Preserve specific builds** before cleaning:
   ```bash
   cp -r ci-matrix-builds/OVMF-X64-DEBUG ~/saved-builds/
   ```

## Troubleshooting

**Problem**: Jobs fail with "stuart_* command not found"
```bash
make setup          # Ensure setup is done
source ~/venv-edk2/bin/activate
```

**Problem**: Want to rebuild a specific successful job
```bash
rm ci-matrix-builds/status/OVMF-X64-DEBUG.status
make ci-debug       # Will rebuild that job
```

**Problem**: Disk space running low
```bash
make ci-clean       # Remove all build artifacts
# Or selectively remove old builds:
rm -rf ci-matrix-builds/CORE-*  # Remove only core package builds
```

**Problem**: Need to see live build output
```bash
tail -f ci-matrix-builds/logs/OVMF-X64-DEBUG.log
```

## Integration with CI

The matrix runner replicates the Azure Pipelines CI matrix:

| CI Job Matrix | Matrix Runner Equivalent |
|---------------|-------------------------|
| TARGET_MDE_CPU | CORE-MdePkg_UefiCpuPkg-DEBUG |
| OVMF_X64_DEBUG | OVMF-X64-DEBUG |
| QEMU_AARCH64_DEBUG | ARMVIRT-QEMU-DEBUG |
| EmulatorPkg_X64_DEBUG | EMULATOR--DEBUG |

This means you can verify your changes will pass CI before pushing!

## Example Session

```bash
# Day 1: First setup and test
make setup
make ci-core              # Test core packages (~2 hours)
make ci-status            # Check results

# Day 2: Continue with platforms
make ci-platforms         # Build platforms (~4 hours)
make ci-status            # Check results
make ci-retry             # Retry any failures

# Day 3: Full validation
make ci-all               # Full matrix with all targets
# ... wait several hours ...
make ci-status            # Final results
```

## File Size Estimates

- Each core package build: ~500MB - 2GB
- Each platform build: ~100MB - 500MB
- Full DEBUG matrix: ~20-40GB total
- Full matrix (all targets): ~60-120GB total

Plan disk space accordingly!
