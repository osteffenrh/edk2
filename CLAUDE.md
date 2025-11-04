# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

EDK II (EFI Development Kit II) is a cross-platform firmware development environment for UEFI and PI specifications. The codebase is organized into packages, each containing modules, libraries, and platform definitions.

## Build System

EDK II uses a Python-based build system (stuart/pytools) and traditional EDK2 build commands.

### Setup Environment

```bash
# Source the setup script (sets WORKSPACE and other env vars)
. edksetup.sh

# Install Python dependencies
pip install --upgrade -r pip-requirements.txt

# Initialize submodules
git submodule update --init
```

### Building with Stuart (Recommended for CI/Platform Builds)

```bash
# Setup: Initialize submodules and dependencies
stuart_setup -c <Package>/PlatformCI/PlatformBuild.py TOOL_CHAIN_TAG=<GCC5|VS2022> -a <X64|IA32|AARCH64>

# Update: Update external dependencies
stuart_update -c <Package>/PlatformCI/PlatformBuild.py TOOL_CHAIN_TAG=<GCC5|VS2022> -a <X64|IA32|AARCH64>

# Build: Compile firmware
stuart_build -c <Package>/PlatformCI/PlatformBuild.py TOOL_CHAIN_TAG=<GCC5|VS2022> -a <X64|IA32|AARCH64>

# Common platforms:
# - OvmfPkg/PlatformCI/PlatformBuild.py (QEMU/KVM virtual platform)
# - EmulatorPkg/PlatformCI/PlatformBuild.py (Host-based emulator)
# - UefiPayloadPkg/PlatformCI/PlatformBuild.py (Universal Payload)
```

### Building with Traditional Build Command

```bash
# After sourcing edksetup.sh
build -a <ARCH> -t <TOOLCHAIN> -p <Package>/<Platform>.dsc -b <DEBUG|RELEASE|NOOPT>

# Example: Build OVMF for X64
build -a X64 -t GCC5 -p OvmfPkg/OvmfPkgX64.dsc -b DEBUG
```

### Compiling BaseTools

```bash
# Required when BaseTools C source changes
python BaseTools/Edk2ToolsBuild.py -t <ToolChainTag>
```

### Running Tests

```bash
# Run CI checks for a package
stuart_ci_build -c .pytool/CISettings.py -p <PackageName> TOOL_CHAIN_TAG=<TOOLCHAIN>

# Build and run host-based unit tests
stuart_build -c <Package>/PlatformCI/PlatformBuild.py -a X64 TOOL_CHAIN_TAG=GCC5 -t NOOPT

# Host test DSCs are in: <Package>/Test/<Package>HostTest.dsc
```

## Architecture and Code Organization

### Package Structure

Each package follows this structure:
- **Include/**: Public header files, library class definitions, protocol/GUID definitions
- **Library/**: Library implementations (LibraryClass instances)
- **<Module>/**: Individual driver/application modules
- **Test/**: Unit tests and test infrastructure
- **PlatformCI/**: Platform CI build scripts

### Key File Types

- **`.dec`**: Package Declaration - Defines GUIDs, protocols, PPIs, library classes
- **`.dsc`**: Platform Description - Describes what gets built (components, libraries, build options)
- **`.inf`**: Module Information - Describes individual module (sources, dependencies, GUID)
- **`.fdf`**: Flash Description - Defines flash layout and firmware volumes
- **`.h`**: Header files
- **`.c`**: C source files

### Critical Packages

- **MdePkg**: Foundation package with UEFI/PI specifications, base libraries
- **MdeModulePkg**: Core modules (DXE Core, PEI Core, drivers, BDS, ACPI, etc.)
- **UefiCpuPkg**: CPU architecture specific modules (MTRR, MP services, SMM)
- **SecurityPkg**: Security features (TCG/TPM, SecureBoot, authenticated variables)
- **NetworkPkg**: Network stack (TCP/IP, HTTP, ISCSI, etc.)
- **CryptoPkg**: Cryptographic libraries (OpenSSL, mbedTLS wrappers)
- **OvmfPkg**: Open Virtual Machine Firmware (QEMU/KVM)
- **ArmPkg/ArmPlatformPkg/ArmVirtPkg**: ARM architecture support
- **BaseTools**: Build tools and utilities
- **UnitTestFrameworkPkg**: Unit testing framework (host-based and target-based)

### Build Phases and Module Types

EDK II firmware executes in phases:
1. **SEC** (Security) - First code to execute, minimal environment
2. **PEI** (Pre-EFI Initialization) - Memory init, early hardware setup
3. **DXE** (Driver Execution Environment) - Main driver loading phase
4. **BDS** (Boot Device Selection) - Boot manager
5. **TSL** (Transient System Load) - OS loader
6. **RT** (Runtime) - Runtime services after OS handoff

Module types: `SEC`, `PEI_CORE`, `PEIM`, `DXE_CORE`, `DXE_DRIVER`, `DXE_RUNTIME_DRIVER`, `DXE_SMM_DRIVER`, `UEFI_DRIVER`, `UEFI_APPLICATION`, `HOST_APPLICATION`

### Library Classes

Libraries are abstract interfaces (library classes) with concrete implementations. A module declares which library classes it needs in its INF, and the DSC file maps those to specific library instances. Common library classes:
- `BaseLib`: Basic CPU/string/math operations
- `DebugLib`: Debug logging
- `MemoryAllocationLib`: Memory allocation services
- `UefiBootServicesTableLib`: Access to UEFI Boot Services
- `UefiRuntimeServicesTableLib`: Access to UEFI Runtime Services
- `PrintLib`: Formatted printing
- `TimerLib`: Timer services

## Development Workflow

### Adding a New Module

1. Create module directory in appropriate package
2. Create `.inf` file describing module (sources, libraries, protocols, GUIDs)
3. Add module to package's `.dsc` file Components section
4. If it's a new library: declare library class in package's `.dec` file
5. Build and test

### Modifying Code

- Follow UEFI/PI specifications for interfaces
- Use proper library classes instead of direct hardware access
- All files must have SPDX license identifier: `SPDX-License-Identifier: BSD-2-Clause-Patent`
- Run CI checks before submitting: `stuart_ci_build`

### Code Style

- EDK II Coding Standard (enforced by EccCheck and UncrustifyCheck plugins)
- Function names: `PascalCase`
- Variables: `PascalCase`
- Macros/Constants: `UPPER_CASE` or `ALL_CAPS_WITH_UNDERSCORES`
- Use UEFI types: `UINT8`, `UINT16`, `UINT32`, `UINT64`, `BOOLEAN`, `CHAR16`, `EFI_STATUS`

### Code Formatting

All C files (except third-party libraries) must be formatted with uncrustify:

```bash
# Format a single file in-place
../../Uncrustify/build/uncrustify -c .pytool/Plugin/UncrustifyCheck/uncrustify.cfg --replace $file

# Check formatting without modifying (CI uses this)
../../Uncrustify/build/uncrustify -c .pytool/Plugin/UncrustifyCheck/uncrustify.cfg --check $file
```

Note: Third-party libraries (submodules in CryptoPkg, MdeModulePkg, etc.) are excluded from formatting requirements.

### Testing

- Host-based unit tests: Use `UnitTestFrameworkPkg` with `HOST_APPLICATION` modules
- Target-based tests: Tests that run on actual firmware
- CI automatically runs tests in `<Package>/Test/<Package>HostTest.dsc`

## Contribution Guidelines

All commits must:
- Include `Signed-off-by` line with real name and email
- Follow commit message format: `Package-Module: Brief-summary` (max ~70 chars first line)
- Reference Maintainers.txt for package reviewers (Cc them on patches)
- Pass CI checks (run `stuart_ci_build` locally first)
- Submit to mailing list: devel@edk2.groups.io

## Common Architectures

- **X64**: x86-64 (64-bit Intel/AMD)
- **IA32**: x86 (32-bit Intel/AMD)
- **AARCH64**: 64-bit ARM
- **RISCV64**: 64-bit RISC-V
- **LOONGARCH64**: 64-bit LoongArch

## Platform-Specific Notes

### OvmfPkg (QEMU/KVM)
- Build with `stuart_build -c OvmfPkg/PlatformCI/PlatformBuild.py`
- Run with `--FlashOnly` to launch QEMU after build
- Main DSC files: `OvmfPkgX64.dsc`, `OvmfPkgIa32X64.dsc`, `AmdSevX64.dsc`, `IntelTdxX64.dsc`
- Supports confidential computing: AMD SEV, Intel TDX

### EmulatorPkg
- Host-based emulator (runs on Windows/Linux as regular application)
- Useful for rapid development/debugging without actual hardware or VM
- Build with `stuart_build -c EmulatorPkg/PlatformCI/PlatformBuild.py`

### UefiPayloadPkg
- Universal payload that can be used with coreboot, Slim Bootloader, etc.
- Build creates payload binary loaded by bootloader

## Debugging

- Set `TARGET = DEBUG` in `Conf/target.txt` or use `-b DEBUG`
- Use `DEBUG` macro from `DebugLib` for logging
- OVMF: Serial port output captured by QEMU (see stdout/stderr)
- EmulatorPkg: Direct console output
- Source-level debugging: Use SourceLevelDebugPkg with GDB

## External Dependencies

Managed by stuart via ext_dep (external dependencies):
- NASM (assembler)
- IASL (ACPI compiler)
- Cross-compilers for non-native architectures
- These are automatically downloaded by `stuart_setup`/`stuart_update`

## Reference Documentation

- TianoCore Wiki: https://github.com/tianocore/tianocore.github.io/wiki
- UEFI Specification: https://uefi.org/specifications
- PI Specification: https://uefi.org/specifications
- Mailing list: https://edk2.groups.io/g/devel
