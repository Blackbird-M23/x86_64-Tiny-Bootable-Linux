# Windows & WSL2 Setup Guide

This guide walks you through setting up a complete, professional Linux kernel development and QEMU virtualization environment on Windows 10/11.

---

## 1. Setting Up WSL2 (Windows Subsystem for Linux)

WSL2 provides a real, lightweight Linux kernel running in a dedicated Hyper-V virtual machine, ensuring full POSIX compatibility, correct file permissions (`chmod +x`), and native compilation speeds for the Linux kernel.

### Step 1.1: Install WSL2 with Ubuntu
Open **PowerShell as Administrator** and run:
```powershell
wsl --install -d Ubuntu
```
- If prompted to restart your computer, reboot Windows to enable virtualization features.
- When Ubuntu opens for the first time, set your Linux username and password.

### Step 1.2: Verify WSL2 Status
In PowerShell:
```powershell
wsl -l -v
```
You should see:
```text
  NAME      STATE           VERSION
* Ubuntu    Running         2
```
*(Ensure the VERSION column says `2`).*

---

## 2. Installing Build Dependencies inside Ubuntu

Open your **Ubuntu terminal** (or run `wsl` in Windows Terminal / PowerShell), and install all necessary compiler tools:

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
    qemu-system-x86 \
    qemu-utils
```

### Explanation of Key Packages
- `build-essential`: GCC, G++, Make, and standard C library headers.
- `bison` & `flex`: Parser and lexical analyzer generators required for the Linux Kconfig system.
- `libssl-dev` & `libelf-dev`: Cryptographic headers and ELF file manipulation tools for module signing and kernel object processing.
- `bc`: Arbitrary-precision calculator used in kernel build time calculations.
- `cpio`: Archive format required for Linux initramfs packaging (`newc` format).
- `qemu-system-x86`: The QEMU x86_64 machine emulator.

---

## 3. Navigating to the Project from WSL2

Windows drives are automatically mounted inside WSL2 under `/mnt/<drive_letter>/`.

## 3. Navigating to the Project & Building

> [!TIP]
> **Performance Recommendation:** Copy the project from `/mnt/d/` to your native Linux home directory (`~/`). The native ext4 filesystem avoids Windows NTFS file-locking conflicts and compiles **5x to 10x faster**:
> ```bash
> cp -r /mnt/d/boot_chain-main/x86_64-boot-chain ~/x86_64-boot-chain
> cd ~/x86_64-boot-chain
> ```

Make all scripts executable and run the build:
```bash
chmod +x scripts/*.sh kernel/*.sh initramfs/*.sh

# Step 1: Compile Linux Kernel (bzImage)
./kernel/build_kernel.sh

# Step 2: Compile BusyBox
./initramfs/build_busybox.sh

# Step 3: Package Initramfs with automated DHCP
./initramfs/build_initramfs.sh

# Step 4: Copy artifacts back to Windows D: drive (optional)
cp -r bin/* /mnt/d/boot_chain-main/x86_64-boot-chain/bin/
```

---

## 4. Running the Machine

### Option A: Running inside WSL2 (Recommended)
```bash
./scripts/run_qemu.sh
```

### Option B: Running natively on Windows (PowerShell)
If you have QEMU for Windows installed (`winget install SoftwareFreedomConservancy.QEMU`):
```powershell
cd D:\boot_chain-main\x86_64-boot-chain
.\scripts\run_qemu.ps1
```

---

## 5. Explore Your System (Run these commands inside `~ #`)

Once the prompt appears:

### A. Inspect the Process Tree
```sh
ps
```

### B. Check System Info & Virtual Filesystems
```sh
uname -a
cat /proc/cmdline
cat /proc/meminfo | head -n 5
mount
```

### C. Check IP Address and Routing (Automated Network)
```sh
ifconfig
route -n
cat /etc/resolv.conf
```

### D. Test Live Internet Connectivity
```sh
ping -c 3 1.1.1.1
ping -c 3 google.com
nslookup google.com
wget -q -O - http://example.com
```

### E. Navigate and Test the RAM Filesystem
```sh
cd /etc
ls -la
echo "Test file in RAM" > /tmp/test.txt
cat /tmp/test.txt
```

---

## 6. How to Exit QEMU
In terminal/console mode (`-nographic`):
- Press **`Ctrl + A`**, release both keys, then press **`X`**.
- Or inside your custom Linux shell, type `poweroff -f` or `exit`.
