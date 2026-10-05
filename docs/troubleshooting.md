# Troubleshooting Guide & Common Boot Failures

This reference documents the most common boot failures encountered when building a minimal x86_64 Linux system and how to resolve them.

---

## 1. Black Screen / No QEMU Output

### Symptom:
You launch QEMU with `-nographic`, but the terminal hangs indefinitely with no kernel logs.

### Root Causes & Fixes:
1. **Wrong Serial Device:**
   - **Fix:** Ensure you pass `console=ttyS0` in the `-append` string (not `ttyAMA0`, which is ARM-only).
2. **Missing Kernel Serial Driver:**
   - **Fix:** Verify your `.config` includes:
     ```ini
     CONFIG_SERIAL_8250=y
     CONFIG_SERIAL_8250_CONSOLE=y
     ```
     If compiled as a module (`=m`), the kernel cannot print before the root filesystem is mounted. It must be built-in (`=y`).
3. **Early Crash Before Console Init:**
   - **Fix:** Add `earlyprintk=serial,ttyS0,115200` to the kernel cmdline to catch early crashes before the standard serial driver initializes.

---

## 2. Panic: "VFS: Unable to mount root fs on unknown-block(0,0)"

### Symptom:
Kernel boots, prints hardware detection, then panics with:
```text
Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

### Root Causes & Fixes:
1. **Initramfs Not Provided:**
   - You forgot to specify `-initrd bin/initramfs.cpio.gz` in QEMU.
2. **RAM Disk Support Disabled in Kernel:**
   - Verify these kernel configuration options:
     ```ini
     CONFIG_BLK_DEV_INITRD=y
     CONFIG_RD_GZIP=y
     ```
3. **Corrupted Archive Format:**
   - The archive must be generated in `newc` format:
     ```bash
     find . -print0 | cpio --null -ov --format=newc | gzip -9 > initramfs.cpio.gz
     ```

---

## 3. Panic: "No working init found"

### Symptom:
Kernel boots and extracts initramfs, but halts with:
```text
Kernel panic - not syncing: No working init found. Try passing init= option to kernel.
```

### Root Causes & Fixes:
1. **Missing Executable Permissions:**
   - The `/init` script must have executable permission flags (`+x`):
     ```bash
     chmod +x /init
     ```
2. **Broken Shebang / Missing Interpreter:**
   - If `/init` starts with `#!/bin/sh`, the kernel attempts to execute `/bin/sh`.
   - If `/bin/sh` does not exist or points to a broken symlink, the kernel reports "No working init found" because the interpreter could not be launched.
   - Run `ls -l bin/sh` to ensure it links relatively to `busybox` (e.g., `sh -> busybox`).
3. **Dynamic Library Dependency on Static System:**
   - If BusyBox or `/init` was compiled dynamically (`CONFIG_STATIC=n`), it requires `/lib64/ld-linux-x86-64.so.2` and `libc.so.6`.
   - Without these shared libraries in the rootfs, execution fails with errno -2 (ENOENT).
   - Verify static linking:
     ```bash
     file build/rootfs/bin/busybox
     # Must report: statically linked
     ```

---

## 4. Panic: "Attempted to kill init! exitcode=0x00000000"

### Symptom:
You type `exit` in the shell or the `/init` script finishes, and the kernel immediately crashes with:
```text
Kernel panic - not syncing: Attempted to kill init!
```

### Root Cause & Fix:
- In Linux, PID 1 is not allowed to terminate. If PID 1 returns or exits, the kernel treats it as a fatal system failure and panics.
- **Fix:** In `/init`, wrap the interactive shell in an infinite loop or invoke `poweroff -f` / `reboot -f` when the shell exits:
  ```sh
  while true; do
      /bin/sh
      poweroff -f
  done
  ```

---

## 5. Terminal State Garbled After Exiting QEMU

### Symptom:
After stopping QEMU, your terminal does not echo characters or line returns look corrupted.

### Fix:
In your terminal, type blind:
```bash
reset
```
or
```bash
stty sane
```
and press Enter. The launcher script `run_qemu.sh` includes an automatic `trap` that restores terminal settings on exit.

---

## 6. "ifconfig: socket: Function not implemented" or "/proc/net/dev: No such file or directory"

### Symptom:
Running `ifconfig` or `ip` inside the VM returns:
```text
ifconfig: /proc/net/dev: No such file or directory
ifconfig: socket: Function not implemented
```

### Root Cause:
The `socket()` system call returned `ENOSYS` ("Function not implemented") because the Linux kernel currently booted in QEMU was compiled without the core networking subsystem (`CONFIG_NET=y`). The userspace tools (`ifconfig`, `udhcpc`, `ping`) are fine, but the kernel lacks socket handling.

### Fix:
Recompile the Linux kernel with networking support enabled:
```bash
./kernel/build_kernel.sh
```
Then restart QEMU with `./scripts/run_qemu.sh`.

---

## 7. "No rule to make target 'net/netfilter/xt_TCPMSS.o'" (NTFS Case-Sensitivity Collision)

### Symptom:
Kernel compilation halts with:
```text
make[4]: *** No rule to make target 'net/netfilter/xt_TCPMSS.o', needed by 'net/netfilter/built-in.a'. Stop.
make[3]: *** [scripts/Makefile.build:480: net/netfilter] Error 2
```

### Root Cause:
In the upstream Linux kernel source, the directory `net/netfilter/` contains two distinct files that differ only by case:
- `xt_tcpmss.c` (matches TCP MSS values)
- `xt_TCPMSS.c` (modifies TCP MSS values)

When the source tarball was initially extracted on a Windows drive (`/mnt/d/` with NTFS), Windows treated both files as identical due to case-insensitivity and overwrote one with the other.

### Fix:
1. Disable Netfilter (`scripts/config --disable CONFIG_NETFILTER`), as firewalls are unnecessary for minimal boot chains and bypassing netfilter avoids compiling `xt_TCPMSS`.
2. Extract the kernel tarball inside the native WSL ext4 filesystem (`~/`), which is fully case-sensitive:
   ```bash
   cd ~/x86_64-boot-chain/build
   rm -rf linux-6.6.78
   tar -xf linux-6.6.78.tar.xz
   ```

---

## 8. "udhcpc: lease obtained" but "Network is unreachable" & No IP on eth0

### Symptom:
Running `udhcpc -i eth0` prints:
```text
udhcpc: lease of 10.0.2.15 obtained from 10.0.2.2, lease time 86400
```
However, running `ifconfig` shows no IPv4 address on `eth0`, `route -n` has no gateway, and `ping 1.1.1.1` returns `sendto: Network is unreachable`.

### Root Cause:
BusyBox's `udhcpc` does not directly modify network interfaces. Instead, it delegates IP address assignment, routing table entries, and DNS nameserver updates to a hook script:
`/usr/share/udhcpc/default.script bound`
If that script is missing from the root filesystem, the lease is accepted but never applied to the network stack.

### Fix:
1. Ensure `initramfs/udhcpc.script` is created and executable.
2. Re-run `./initramfs/build_initramfs.sh` to package it into `/usr/share/udhcpc/default.script`.
3. To manually configure it inside a running VM without rebooting:
   ```sh
   ifconfig eth0 10.0.2.15 netmask 255.255.255.0 up
   route add default gw 10.0.2.2
   echo "nameserver 10.0.2.3" > /etc/resolv.conf
   ```

---

## 9. "Error: BusyBox not found in .../build/rootfs"

### Symptom:
Running `./initramfs/build_initramfs.sh` fails with:
```text
Error: BusyBox not found in /home/user/x86_64-boot-chain/build/rootfs. Run build_busybox.sh first!
```

### Root Cause:
The initramfs packager bundles pre-compiled BusyBox applets from the `build/rootfs/` staging directory. When switching to a fresh workspace (e.g. copying to `~/`), BusyBox has not been compiled yet.

### Fix:
Compile BusyBox first (takes ~20 seconds), then package the initramfs:
```bash
./initramfs/build_busybox.sh
./initramfs/build_initramfs.sh
```

---

## 10. "make[1]: *** [Makefile:1921: .] Error 2" (DrvFS / NTFS File Locking)

### Symptom:
Compiling the kernel on a mounted Windows drive (`/mnt/d/` or `/mnt/c/`) fails during parallel compilation (`make -j$(nproc)`).

### Root Cause:
WSL2 accesses Windows drives through the DrvFS/9P translation layer. Windows Defender and system indexers actively scan newly generated `.o` and `.tmp` files. During high-concurrency builds, Windows file locking conflicts cause `make` subprocesses to fail.

### Fix:
Move the build to the native WSL2 virtual disk (`~/`), which uses ext4:
```bash
cp -r /mnt/d/boot_chain-main/x86_64-boot-chain ~/x86_64-boot-chain
cd ~/x86_64-boot-chain
./kernel/build_kernel.sh
cp -r bin/* /mnt/d/boot_chain-main/x86_64-boot-chain/bin/
```



