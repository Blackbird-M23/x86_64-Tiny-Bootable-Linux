#!/usr/bin/env bash
# ==============================================================================
# Standalone Pure-C Minimal Initramfs Packager
# Builds a tiny (sub-100KB) initramfs without BusyBox
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
C_ROOTFS="${PROJECT_ROOT}/build/rootfs_c"
BIN_DIR="${PROJECT_ROOT}/bin"

mkdir -p "${C_ROOTFS}" "${BIN_DIR}"
rm -rf "${C_ROOTFS:?}"/*

echo "==> Compiling standalone C init binary (statically linked)..."
gcc -static -O2 -Wall "${SCRIPT_DIR}/init.c" -o "${C_ROOTFS}/init"
chmod +x "${C_ROOTFS}/init"

cd "${C_ROOTFS}"
mkdir -p dev proc sys tmp bin

OUTPUT_CPIO="${BIN_DIR}/initramfs_c.cpio.gz"
echo "==> Packaging ${OUTPUT_CPIO}..."
find . -print0 | cpio --null -ov --format=newc | gzip -9 > "${OUTPUT_CPIO}"

echo "================================================================="
echo " Pure C Initramfs created: ${OUTPUT_CPIO}"
echo " Size: $(du -h "${OUTPUT_CPIO}" | cut -f1)"
echo " To run with pure C init: "
echo "   qemu-system-x86_64 -kernel bin/bzImage -initrd bin/initramfs_c.cpio.gz -append \"console=ttyS0\" -nographic"
echo "================================================================="
