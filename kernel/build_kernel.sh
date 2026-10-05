#!/usr/bin/env bash
# ==============================================================================
# Linux Kernel Builder for x86_64
# Downloads, configures, and compiles a minimal bootable bzImage
# ==============================================================================
set -euo pipefail

KERNEL_VERSION="6.6.78"
KERNEL_MAJOR="v6.x"
KERNEL_TAR="linux-${KERNEL_VERSION}.tar.xz"
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/${KERNEL_MAJOR}/${KERNEL_TAR}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${PROJECT_ROOT}/build"
BIN_DIR="${PROJECT_ROOT}/bin"

mkdir -p "${BUILD_DIR}" "${BIN_DIR}"
cd "${BUILD_DIR}"

echo "==> [1/4] Checking kernel source archive..."
if [ ! -f "${KERNEL_TAR}" ]; then
    echo "    Downloading ${KERNEL_TAR} from kernel.org..."
    wget -c "${KERNEL_URL}"
else
    echo "    Archive ${KERNEL_TAR} already present."
fi

echo "==> [2/4] Extracting kernel sources..."
if [ ! -d "linux-${KERNEL_VERSION}" ]; then
    tar -xf "${KERNEL_TAR}"
fi

cd "linux-${KERNEL_VERSION}"

echo "==> [3/4] Configuring x86_64 kernel..."
make x86_64_defconfig

# Ensure all vital options for QEMU serial, initramfs, and networking are explicitly enabled
scripts/config --enable CONFIG_BLK_DEV_INITRD
scripts/config --enable CONFIG_RD_GZIP
scripts/config --enable CONFIG_DEVTMPFS
scripts/config --enable CONFIG_DEVTMPFS_MOUNT
scripts/config --enable CONFIG_SERIAL_8250
scripts/config --enable CONFIG_SERIAL_8250_CONSOLE
scripts/config --enable CONFIG_NET
scripts/config --enable CONFIG_INET
scripts/config --enable CONFIG_PACKET
scripts/config --enable CONFIG_UNIX
scripts/config --enable CONFIG_NETDEVICES
scripts/config --enable CONFIG_NET_CORE
scripts/config --enable CONFIG_ETHERNET
scripts/config --enable CONFIG_VIRTIO
scripts/config --enable CONFIG_VIRTIO_PCI
scripts/config --enable CONFIG_VIRTIO_NET
scripts/config --enable CONFIG_VIRTIO_CONSOLE
scripts/config --enable CONFIG_E1000
scripts/config --enable CONFIG_E1000E

# Disable signing keys & BTF debug (avoids missing certificate errors on Ubuntu)
scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS ""
scripts/config --set-str CONFIG_SYSTEM_REVOCATION_KEYS ""
scripts/config --disable CONFIG_DEBUG_INFO_BTF

# Disable Netfilter/firewall (not needed in minimal OS, avoids NTFS case collision on xt_TCPMSS)
scripts/config --disable CONFIG_NETFILTER

make olddefconfig



echo "==> [4/4] Compiling bzImage with $(nproc) jobs..."
make -j"$(nproc)" bzImage

# Copy compiled bzImage to project bin directory
cp arch/x86/boot/bzImage "${BIN_DIR}/bzImage"

echo "================================================================="
echo " Kernel build complete!"
echo " Binary created: ${BIN_DIR}/bzImage"
echo " Size: $(du -h "${BIN_DIR}/bzImage" | cut -f1)"
echo "================================================================="
