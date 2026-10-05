#!/usr/bin/env bash
# ==============================================================================
# QEMU Launcher for x86_64 Tiny Bootable Linux
# Supports KVM acceleration if available, clean console handling
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${PROJECT_ROOT}/bin"

KERNEL="${BIN_DIR}/bzImage"
INITRD="${BIN_DIR}/initramfs.cpio.gz"

if [ ! -f "${KERNEL}" ]; then
    echo "Error: Kernel image not found at ${KERNEL}"
    echo "Run ./scripts/build_all.sh first."
    exit 1
fi

if [ ! -f "${INITRD}" ]; then
    echo "Error: Initramfs not found at ${INITRD}"
    echo "Run ./scripts/build_all.sh first."
    exit 1
fi

ACCEL_FLAGS=""
if [ -w /dev/kvm ]; then
    echo "==> Hardware KVM acceleration detected (/dev/kvm)."
    ACCEL_FLAGS="-enable-kvm -cpu host"
else
    echo "==> Running in TCG emulation mode (no /dev/kvm)."
    ACCEL_FLAGS="-cpu max"
fi

echo "================================================================="
echo " Booting x86_64 Tiny Linux in QEMU..."
echo " Serial Console: redirected to terminal."
echo " Press 'Ctrl + A' then 'X' to exit QEMU at any time."
echo "================================================================="
sleep 1

# Reset terminal on exit
trap 'stty sane 2>/dev/null || true' EXIT

qemu-system-x86_64 \
    -M q35 \
    ${ACCEL_FLAGS} \
    -m 512M \
    -smp 2 \
    -kernel "${KERNEL}" \
    -initrd "${INITRD}" \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    -append "console=ttyS0 quiet loglevel=3 panic=1" \
    -no-reboot \
    -nographic

