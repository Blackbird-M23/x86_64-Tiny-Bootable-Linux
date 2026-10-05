#!/usr/bin/env bash
# ==============================================================================
# Statically Linked BusyBox Builder for x86_64
# ==============================================================================
set -euo pipefail

BUSYBOX_VERSION="1.36.1"
BUSYBOX_TAR="busybox-${BUSYBOX_VERSION}.tar.bz2"
BUSYBOX_URL="https://busybox.net/downloads/${BUSYBOX_TAR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
ROOTFS_DIR="${PROJECT_ROOT}/build/rootfs"

mkdir -p "${BUILD_DIR}" "${ROOTFS_DIR}"
cd "${BUILD_DIR}"

echo "==> [1/4] Checking BusyBox source archive..."
if [ ! -f "${BUSYBOX_TAR}" ]; then
    echo "    Downloading ${BUSYBOX_TAR}..."
    wget -c "${BUSYBOX_URL}"
else
    echo "    Archive ${BUSYBOX_TAR} already present."
fi

echo "==> [2/4] Extracting BusyBox sources..."
if [ ! -d "busybox-${BUSYBOX_VERSION}" ]; then
    tar -xjf "${BUSYBOX_TAR}"
fi

cd "busybox-${BUSYBOX_VERSION}"

echo "==> [3/4] Configuring BusyBox for static compilation..."
make defconfig

# Force static binary so it requires no external libc or ld-linux.so
sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
# Avoid TC (traffic control) errors if missing kernel headers
sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config

echo "==> [4/4] Compiling and installing to rootfs..."
make -j"$(nproc)"
make CONFIG_PREFIX="${ROOTFS_DIR}" install

# Verify the resulting binary is genuinely static
if file "${ROOTFS_DIR}/bin/busybox" | grep -q "statically linked"; then
    echo "    [OK] Busybox successfully built as statically linked binary!"
else
    echo "    [WARNING] BusyBox is not statically linked! It may fail in a bare initramfs."
fi

echo "================================================================="
echo " BusyBox build complete!"
echo " Installed to: ${ROOTFS_DIR}"
echo "================================================================="
