# x86_64 Tiny Bootable Linux

A minimal, custom-built x86_64 Linux boot chain built from source — custom-compiled Linux kernel (`bzImage`) + hand-crafted root filesystem (`initramfs`) with BusyBox, automated plug-and-play networking, and a custom PID 1 init — booted inside QEMU.

Adapted from the ARM64 experiment to standard **x86_64 PC architecture**, running natively on modern Intel/AMD PCs (Windows via WSL2/QEMU or native Linux).

---

## Architecture Overview

```
+--------------------------------------------------------------------------+
| 1. Bootloader / Emulator (QEMU x86_64 Standard PC: 'q35')                 |
|    - Direct kernel boot loads arch/x86/boot/bzImage into memory          |
|    - Loads initramfs.cpio.gz as initial RAM disk                         |
|    - Attaches virtual network interface card (virtio-net-pci) via SLIRP   |
|    - Sets up zero-page boot parameters (boot_params) and jumps to kernel |
+------------------------------------+-------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
| 2. Linux x86_64 Kernel (bzImage 6.6.78)                                  |
|    - 16-bit real-mode setup code -> 32-bit protected mode decompressor   |
|    - Decompresses vmlinux into memory -> Transitions to 64-bit Long Mode |
|    - ACPI discovery, 8250/16550 UART (ttyS0), VirtIO PCI initialization  |
|    - Networking subsystem (IPv4, TCP/UDP sockets, AF_PACKET, VirtIO-Net) |
|    - Unpacks initramfs into rootfs (tmpfs) in RAM                        |
|    - Executes PID 1 (/init)                                              |
+------------------------------------+-------------------------------------+
                                     |
                                     v
+--------------------------------------------------------------------------+
| 3. Handcrafted RootFS (BusyBox + Custom /init)                           |
|    - Mounts virtual filesystems: /proc, /sys, /dev, /tmp                 |
|    - Initializes /dev nodes via devtmpfs                                 |
|    - Brings up loopback (127.0.0.1) and Ethernet (eth0)                  |
|    - Runs udhcpc in background -> leases 10.0.2.15, sets default gateway |
|    - Configures DNS in /etc/resolv.conf                                  |
|    - Traps shutdown signals & manages child processes                    |
|    - Drops into an interactive BusyBox shell (/bin/sh) with job control  |
+--------------------------------------------------------------------------+
```

---

## Directory Structure

```
x86_64-boot-chain/
├── README.md                      # Master documentation, build steps & troubleshooting log
├── kernel/
│   ├── x86_64_defconfig.config    # Tailored minimal kernel config fragment
│   └── build_kernel.sh            # Script to configure and build Linux kernel (bzImage)
├── initramfs/
│   ├── init                       # Production shell-based PID 1 init script (networking enabled)
│   ├── init.c                     # Standalone minimal C PID 1 implementation (sub-50KB)
│   ├── udhcpc.script              # DHCP event handler script for IP/route/DNS configuration
│   ├── build_busybox.sh           # Builds statically linked BusyBox 1.36.1
│   ├── build_initramfs.sh         # Packages rootfs into initramfs.cpio.gz (relative symlinks)
│   └── build_c_init.sh            # Builds standalone sub-50KB C-only initramfs
├── scripts/
│   ├── build_all.sh               # Master one-click build script
│   ├── run_qemu.sh                # Launch script for Linux / WSL2 bash (auto KVM + virtio-net)
│   ├── run_qemu.bat               # Native Windows batch launcher
│   ├── run_qemu.ps1               # Native Windows PowerShell launcher (WHPX acceleration)
│   └── clean.sh                   # Cleans up build artifacts
└── docs/
    ├── networking-guide.md        # Deep dive into SLIRP networking, ping/wget & web server
    ├── arm64-vs-x86_64.md         # Detailed architectural comparison (Image vs bzImage, ttyS0)
    ├── troubleshooting.md         # Exhaustive guide to kernel panics, errors, and fixes
    └── windows-wsl2-setup.md      # Step-by-step Windows & WSL2 setup guide
```

---

## What Needs to Be Installed

### On Windows
1. **WSL2 with Ubuntu** (for compiling the Linux kernel & BusyBox on a POSIX filesystem):
   ```powershell
   wsl --install -d Ubuntu
   ```
2. **QEMU for Windows** (Optional - if you wish to run QEMU directly from PowerShell):
   ```powershell
   winget install SoftwareFreedomConservancy.QEMU
   ```

### Packages inside Ubuntu (WSL2)
Run inside your Ubuntu WSL2 terminal:
```bash
sudo apt update && sudo apt install -y \
    build-essential \
    libncurses-dev \
    bison \
    flex \
    libssl-dev \
    libelf-dev \
    bc \
    wget \
    cpio \
    tar \
    gzip \
    file \
    qemu-system-x86
```

---

## How to Build the Project

> [!TIP]
> **WSL2 Best Practice:** Always build inside your native Linux directory (`~/x86_64-boot-chain`) rather than the mounted Windows drive (`/mnt/d/`). The native ext4 filesystem is case-sensitive, avoids Windows NTFS file-locking conflicts, and builds **5x to 10x faster**.

```bash
# 1. Copy the project to your native Linux home directory
cp -r /mnt/d/boot_chain-main/x86_64-boot-chain ~/x86_64-boot-chain
cd ~/x86_64-boot-chain

# 2. Compile the Linux Kernel (bzImage)
./kernel/build_kernel.sh

# 3. Compile Statically Linked BusyBox
./initramfs/build_busybox.sh

# 4. Package the Initramfs with DHCP script
./initramfs/build_initramfs.sh

# 5. Copy the finished binaries back to your D: drive
cp -r bin/* /mnt/d/boot_chain-main/x86_64-boot-chain/bin/
```

*(Alternatively, run `./scripts/build_all.sh` to execute all steps sequentially).*

---

## How to Run It

### From Linux / WSL2
```bash
./scripts/run_qemu.sh
```

### From Windows (PowerShell)
If you have QEMU for Windows installed:
```powershell
cd D:\boot_chain-main\x86_64-boot-chain
.\scripts\run_qemu.ps1
```

### Exiting QEMU
Since QEMU runs in `-nographic` mode (attaching the virtual serial console to your terminal):
- To shut down cleanly from inside the VM: type **`poweroff -f`** or **`exit`**.
- To force-kill QEMU at any time: Press **`Ctrl + A`**, release, then press **`X`**.

---

## Feature Tour: Commands to Explore the System

Once your system boots to the `~ #` prompt, test these features:

### 1. Process Tree & PID 1 Behavior
```sh
ps
```
- **Observation:** Notice the ultra-clean process table: PID 1 (`/init`), PID 2 (`kthreadd`), and your shell process.

### 2. System Info & Virtual Filesystems
```sh
uname -a
cat /proc/cmdline
cat /proc/meminfo | head -n 5
mount
```
- **Observation:** Proves that `/proc`, `/sys`, `/dev` (devtmpfs), and `/tmp` were mounted by your custom PID 1 script.

### 3. Plug-and-Play Networking (Live Internet Connection)
Networking is completely automated on boot! Run:
```sh
# Inspect the active IP and traffic stats
ifconfig

# Inspect the Kernel IP routing table
route -n

# Ping public DNS (ICMP packet test)
ping -c 3 1.1.1.1

# Ping by domain name (DNS resolution via /etc/resolv.conf)
ping -c 3 google.com
nslookup google.com

# Fetch a live webpage from the Internet
wget -q -O - http://example.com
```

### 4. Run an Embedded Web Server (Accessible from Windows!)
BusyBox includes a built-in web server (`httpd`).
1. In `scripts/run_qemu.sh` (or `run_qemu.ps1`), add port forwarding:
   `-netdev user,id=net0,hostfwd=tcp::8080-:80`
2. Boot the VM and run:
   ```sh
   mkdir -p /www
   echo "<h1>Hello from My Custom x86_64 Linux OS!</h1>" > /www/index.html
   httpd -h /www -p 80
   ```
3. Open `http://localhost:8080` in your Windows browser to view the webpage served by your kernel!

### 5. Pure C PID 1 Mode (No BusyBox, Sub-50KB OS)
Test the ultra-lightweight standalone C init system:
```bash
qemu-system-x86_64 \
    -M q35 -m 512M \
    -kernel bin/bzImage \
    -initrd bin/initramfs_c.cpio.gz \
    -append "console=ttyS0 quiet" \
    -nographic
```

---

## Engineering Log: Real-World Problems Faced & Solved

Building low-level systems involves debugging real kernel and userspace interactions. Here is the complete log of issues encountered and how they were fixed:

### Problem 1: `ifconfig: socket: Function not implemented`
- **Symptom:**
  ```text
  ~ # ifconfig
  ifconfig: /proc/net/dev: No such file or directory
  ifconfig: socket: Function not implemented
  ```
- **Root Cause:**
  The `socket()` system call returned `ENOSYS` because the kernel was initially compiled without the networking subsystem (`CONFIG_NET=y`). In Linux, if `CONFIG_NET` is missing, the kernel does not implement socket syscalls and does not generate `/proc/net/`.
- **How It Was Fixed:**
  Added core networking options to [`kernel/x86_64_defconfig.config`](file:///d:/boot_chain-main/x86_64-boot-chain/kernel/x86_64_defconfig.config):
  ```ini
  CONFIG_NET=y
  CONFIG_INET=y
  CONFIG_PACKET=y
  CONFIG_UNIX=y
  CONFIG_VIRTIO_NET=y
  ```
  Recompiled the kernel via `./kernel/build_kernel.sh`.

---

### Problem 2: `make[1]: *** [Makefile:1921: .] Error 2` on `/mnt/d/`
- **Symptom:**
  Compiling the kernel directly inside `/mnt/d/...` randomly failed during parallel compilation.
- **Root Cause:**
  WSL2 accesses `/mnt/d/` through the **DrvFS / 9P** translation layer over Windows NTFS. Windows Defender and indexers lock newly created `.o` and `.tmp` files during parallel compilation (`make -j`), causing file-access collisions.
- **How It Was Fixed:**
  Moved the build workspace into the native WSL2 virtual disk (`~/x86_64-boot-chain`):
  ```bash
  cp -r /mnt/d/boot_chain-main/x86_64-boot-chain ~/x86_64-boot-chain
  cd ~/x86_64-boot-chain
  ```
  Native ext4 has no Windows file-locking interference and builds 5x–10x faster.

---

### Problem 3: `make: *** No rule to make target 'net/netfilter/xt_TCPMSS.o'`
- **Symptom:**
  ```text
  make[4]: *** No rule to make target 'net/netfilter/xt_TCPMSS.o', needed by 'net/netfilter/built-in.a'. Stop.
  make[3]: *** [scripts/Makefile.build:480: net/netfilter] Error 2
  ```
- **Root Cause:**
  The legendary **NTFS case-insensitivity collision**. In the Linux kernel source under `net/netfilter/`, there are two distinct files that differ only by case:
  - `xt_tcpmss.c` (lowercase — iptables match module)
  - `xt_TCPMSS.c` (uppercase — iptables target module)
  
  When the tarball was extracted on `/mnt/d/` (Windows NTFS), Windows treated them as identical and overwrote one of them. When copied to `~/`, the folder was already missing `xt_TCPMSS.c`.
- **How It Was Fixed:**
  1. Disabled `CONFIG_NETFILTER` in [`kernel/build_kernel.sh`](file:///d:/boot_chain-main/x86_64-boot-chain/kernel/build_kernel.sh) (`scripts/config --disable CONFIG_NETFILTER`), as firewalls are unnecessary for minimal boot systems.
  2. Re-extracted the kernel archive directly on the case-sensitive native Linux filesystem:
     ```bash
     cd ~/x86_64-boot-chain/build
     rm -rf linux-6.6.78
     tar -xf linux-6.6.78.tar.xz
     ```

---

### Problem 4: `udhcpc: lease obtained` but `Network is unreachable` & Blank `ifconfig`
- **Symptom:**
  `udhcpc` received a lease for `10.0.2.15`, but `ifconfig` did not show an IP address, `route -n` had no gateway, and `ping` returned `Network is unreachable`.
- **Root Cause:**
  In BusyBox, `udhcpc` does **not** configure network interfaces directly. It negotiates the lease and then executes a helper script: `/usr/share/udhcpc/default.script bound`. Without this script, the IP, default route, and DNS resolvers are never applied.
- **How It Was Fixed:**
  Created [`initramfs/udhcpc.script`](file:///d:/boot_chain-main/x86_64-boot-chain/initramfs/udhcpc.script) and updated [`initramfs/build_initramfs.sh`](file:///d:/boot_chain-main/x86_64-boot-chain/initramfs/build_initramfs.sh) to install it to `/usr/share/udhcpc/default.script` with executable permissions.
  ```bash
  ./initramfs/build_initramfs.sh
  ```

---

### Problem 5: `Error: BusyBox not found in build/rootfs`
- **Symptom:**
  Running `./initramfs/build_initramfs.sh` failed with:
  ```text
  Error: BusyBox not found in /home/user/x86_64-boot-chain/build/rootfs. Run build_busybox.sh first!
  ```
- **Root Cause:**
  In the new build directory, BusyBox had not yet been compiled into the `build/rootfs` staging folder.
- **How It Was Fixed:**
  Executed the BusyBox build script before packing the initramfs:
  ```bash
  ./initramfs/build_busybox.sh
  ./initramfs/build_initramfs.sh
  ```
