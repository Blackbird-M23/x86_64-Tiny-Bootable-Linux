#!/usr/bin/env bash
# ==============================================================================
# Master One-Click Build Script for x86_64 Tiny Bootable Linux
# Checks dependencies, builds kernel, busybox, and bundles initramfs
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "================================================================="
echo " Starting x86_64 Tiny Linux Boot Chain Build"
echo " Project root: ${PROJECT_ROOT}"
echo "================================================================="

# 1. Check prerequisites
MISSING_PKGS=()
for cmd in gcc make wget tar bzip2 xz cpio gzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING_PKGS+=("$cmd")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "Error: Missing required build utilities: ${MISSING_PKGS[*]}"
    echo "Install them on Ubuntu/Debian via:"
    echo "  sudo apt update && sudo apt install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev bc wget cpio tar gzip"
    exit 1
fi

# 2. Build Linux Kernel
echo ""
echo ">>> STEP 1: Building Linux Kernel (bzImage)..."
chmod +x "${PROJECT_ROOT}/kernel/build_kernel.sh"
"${PROJECT_ROOT}/kernel/build_kernel.sh"

# 3. Build Statically Linked BusyBox
echo ""
echo ">>> STEP 2: Building Statically Linked BusyBox..."
chmod +x "${PROJECT_ROOT}/initramfs/build_busybox.sh"
"${PROJECT_ROOT}/initramfs/build_busybox.sh"

# 4. Assemble RootFS and Package Initramfs
echo ""
echo ">>> STEP 3: Packaging Initramfs (initramfs.cpio.gz)..."
chmod +x "${PROJECT_ROOT}/initramfs/build_initramfs.sh"
"${PROJECT_ROOT}/initramfs/build_initramfs.sh"

# 5. Build optional C-only init
echo ""
echo ">>> STEP 4: Compiling Minimal C Initramfs..."
chmod +x "${PROJECT_ROOT}/initramfs/build_c_init.sh"
"${PROJECT_ROOT}/initramfs/build_c_init.sh" || true

echo ""
echo "================================================================="
echo " [SUCCESS] All components built successfully!"
echo " Outputs available in: ${PROJECT_ROOT}/bin"
echo "   - Kernel    : ${PROJECT_ROOT}/bin/bzImage"
echo "   - Initramfs : ${PROJECT_ROOT}/bin/initramfs.cpio.gz"
echo ""
echo " To run the virtual machine now, execute:"
echo "   ./scripts/run_qemu.sh"
echo "================================================================="
