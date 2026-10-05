# Networking Guide: Enabling Internet in Tiny x86_64 Linux

This guide explains how networking is implemented in this custom x86_64 Linux system and provides step-by-step instructions to test and interact with the Internet from inside the VM.

---

## 1. Network Architecture Overview

The system uses QEMU's **SLIRP (User-Mode Network)** engine. SLIRP simulates an entire local network, DHCP server, NAT router, and DNS forwarder without requiring host administrative/root privileges or complex TAP/TUN bridge setups.

```
+-------------------------------------------------------------------------------+
| Host Machine (Windows / Linux / WSL2)                                         |
|                                                                               |
|   +-----------------------------------------------------------------------+   |
|   | QEMU SLIRP Virtual Network Engine                                     |   |
|   |                                                                       |   |
|   |  - Gateway / Virtual Router : 10.0.2.2                                |   |
|   |  - Virtual DNS Server       : 10.0.2.3                                |   |
|   |  - Built-in DHCP Server     : 10.0.2.2 (leases 10.0.2.15)             |   |
|   +-----------------------------------+-----------------------------------+   |
|                                       | (Virtual PCI VirtIO NIC)              |
|                                       v                                       |
|   +-----------------------------------------------------------------------+   |
|   | Tiny Linux Guest VM (Our System)                                      |   |
|   |                                                                       |   |
|   |  - Loopback Interface (lo)  : 127.0.0.1                               |   |
|   |  - Ethernet Interface (eth0): 10.0.2.15 (configured via udhcpc)      |   |
|   |  - DNS Configuration        : /etc/resolv.conf -> 10.0.2.3            |   |
|   |  - Default Route            : 0.0.0.0/0 via 10.0.2.2                  |   |
|   +-----------------------------------------------------------------------+   |
+-------------------------------------------------------------------------------+
```

---

## 2. Components Implemented in this Project

1. **Kernel Driver & Socket Layer:**
   - `CONFIG_NET=y` & `CONFIG_INET=y`: TCP/IP, UDP, ICMP protocols.
   - `CONFIG_PACKET=y`: Raw packet sockets (AF_PACKET) required by DHCP clients.
   - `CONFIG_VIRTIO_NET=y`: Driver for QEMU's paravirtualized network card.
   - `CONFIG_E1000=y`: Fallback driver for Intel e1000 virtual NICs.

2. **RootFS & DHCP Handler:**
   - **`/usr/share/udhcpc/default.script`**: Event script invoked by `udhcpc`. When a DHCP lease is bound, it:
     - Assigns the IP address and netmask with `ifconfig`.
     - Sets the default gateway using `route add default gw`.
     - Writes nameserver records to `/etc/resolv.conf`.
   - **`/init`**: On boot, automatically brings up `lo` (`127.0.0.1`), checks for `eth0`, and triggers `udhcpc -i eth0 -b`.

3. **QEMU Emulator Configuration:**
   - The launcher scripts (`run_qemu.sh`, `run_qemu.ps1`, `run_qemu.bat`) now include:
     ```text
     -netdev user,id=net0 -device virtio-net-pci,netdev=net0
     ```

---

## 3. How to Apply and Run

If you already built the system previously, you only need to repackage the initramfs (takes ~2 seconds).

Inside your WSL terminal:
```bash
cd /mnt/d/boot_chain-main/x86_64-boot-chain

# 1. Repack the initramfs with the new networking script
./initramfs/build_initramfs.sh

# 2. (Optional) If you modified kernel options, rebuild the kernel:
# ./kernel/build_kernel.sh

# 3. Launch QEMU with networking enabled
./scripts/run_qemu.sh
```

*(On Windows native PowerShell, run `.\scripts\run_qemu.ps1`).*

---

## 4. Verifying Networking Inside the VM

Once your prompt appears (`~ #`), test the connection with these commands:

### A. Check IP Addresses
```sh
ifconfig
```
**Expected Output:**
- `lo`: `inet addr: 127.0.0.1`
- `eth0`: `inet addr: 10.0.2.15` (Bcast: `10.0.2.255`, Mask: `255.255.255.0`)

### B. Check Routing Table and DNS
```sh
route -n
cat /etc/resolv.conf
```
**Expected Output:**
- Default route pointing to `10.0.2.2` via `eth0`.
- `/etc/resolv.conf` contains `nameserver 10.0.2.3`.

### C. Test ICMP Ping
Ping the virtual gateway router:
```sh
ping -c 3 10.0.2.2
```
Ping the public internet (Cloudflare public DNS):
```sh
ping -c 3 1.1.1.1
```

### D. Test Domain Name Resolution (DNS)
```sh
nslookup example.com
```

### E. Download a Real Web Page with Wget
```sh
wget -q -O - http://example.com
```
You will see the raw HTML of `example.com` printed right in your terminal console!

---

## 5. Bonus: Exposing a Web Server from Inside the VM to Windows

BusyBox includes a built-in lightweight web server (`httpd`). You can run a web server inside your tiny OS and view it from your Windows browser!

### Step 1: Add Port Forwarding to QEMU
In `scripts/run_qemu.sh` or `scripts/run_qemu.ps1`, update the `-netdev` parameter to forward host port `8080` to guest port `80`:
```text
-netdev user,id=net0,hostfwd=tcp::8080-:80
```

### Step 2: Start the Web Server inside the VM
Inside `~ #`:
```sh
mkdir -p /www
echo "<h1>Hello from My Tiny Custom x86_64 Linux!</h1>" > /www/index.html
httpd -h /www -p 80
```

### Step 3: Open in Host Browser
Open your browser on Windows and navigate to:
```
http://localhost:8080
```
Your custom Linux kernel will serve the webpage directly to your host browser!
