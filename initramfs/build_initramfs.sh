#!/usr/bin/env bash
# ==============================================================================
# Initramfs Packager for x86_64
# Copies /init, networking scripts, validates symlinks, and bundles into initramfs.cpio.gz
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ROOTFS_DIR="${PROJECT_ROOT}/build/rootfs"
BIN_DIR="${PROJECT_ROOT}/bin"

if [ ! -d "${ROOTFS_DIR}" ] || [ ! -f "${ROOTFS_DIR}/bin/busybox" ]; then
    echo "Error: BusyBox not found in ${ROOTFS_DIR}. Run build_busybox.sh first!"
    exit 1
fi

mkdir -p "${BIN_DIR}"
cd "${ROOTFS_DIR}"

echo "==> [1/5] Creating essential standard directory tree..."
mkdir -p dev proc sys etc tmp root var/run mnt bin sbin usr/bin usr/sbin usr/share/udhcpc

echo "==> [2/5] Installing /init script..."
cp "${SCRIPT_DIR}/init" "${ROOTFS_DIR}/init"
chmod +x "${ROOTFS_DIR}/init"

echo "==> [3/5] Installing DHCP network handler script..."
if [ -f "${SCRIPT_DIR}/udhcpc.script" ]; then
    cp "${SCRIPT_DIR}/udhcpc.script" "${ROOTFS_DIR}/usr/share/udhcpc/default.script"
    chmod +x "${ROOTFS_DIR}/usr/share/udhcpc/default.script"
fi

echo "==> [4/5] Validating symlinks (ensuring no absolute host paths)..."
# Check if any symlink points to a host path like /root or /mnt
DANGLING_COUNT=0
while IFS= read -r link; do
    target=$(readlink "$link")
    case "$target" in
        /*)
            echo "    Fixing absolute symlink: $link -> $target"
            link_dir=$(dirname "$link")
            link_name=$(basename "$link")
            target_rel=$(realpath --relative-to="$link_dir" "$target" 2>/dev/null || echo "$target")
            rm "$link"
            ln -s "$target_rel" "$link"
            DANGLING_COUNT=$((DANGLING_COUNT + 1))
            ;;
    esac
done < <(find . -type l)

if [ "$DANGLING_COUNT" -gt 0 ]; then
    echo "    Repaired $DANGLING_COUNT absolute symlinks to be relative."
else
    echo "    All symlinks are clean and relative."
fi

echo "==> [5/5] Packing initramfs.cpio.gz (newc format)..."
OUTPUT_CPIO="${BIN_DIR}/initramfs.cpio.gz"

find . -print0 | cpio --null -ov --format=newc | gzip -9 > "${OUTPUT_CPIO}"

echo "================================================================="
echo " Initramfs bundle created successfully!"
echo " Target: ${OUTPUT_CPIO}"
echo " Size  : $(du -h "${OUTPUT_CPIO}" | cut -f1)"
echo "================================================================="
