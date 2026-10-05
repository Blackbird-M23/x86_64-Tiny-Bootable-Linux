<#
.SYNOPSIS
    Windows PowerShell Launcher for x86_64 Tiny Bootable Linux in QEMU
#>
[CmdletBinding()]
param (
    [string]$KernelPath = "$PSScriptRoot\..\bin\bzImage",
    [string]$InitrdPath = "$PSScriptRoot\..\bin\initramfs.cpio.gz",
    [int]$MemoryMB = 512
)

# Resolve paths
$KernelFull = [System.IO.Path]::GetFullPath($KernelPath)
$InitrdFull = [System.IO.Path]::GetFullPath($InitrdPath)

if (-not (Test-Path $KernelFull)) {
    Write-Error "Kernel binary not found at $KernelFull. Build it first inside WSL2!"
    exit 1
}

if (-not (Test-Path $InitrdFull)) {
    Write-Error "Initramfs binary not found at $InitrdFull. Build it first inside WSL2!"
    exit 1
}

# Locate QEMU executable
$QemuExe = (Get-Command "qemu-system-x86_64.exe" -ErrorAction SilentlyContinue)?.Source
if (-not $QemuExe) {
    $CommonPaths = @(
        "C:\Program Files\qemu\qemu-system-x86_64.exe",
        "C:\Program Files (x86)\qemu\qemu-system-x86_64.exe",
        "$env:LOCALAPPDATA\Programs\qemu\qemu-system-x86_64.exe"
    )
    foreach ($path in $CommonPaths) {
        if (Test-Path $path) {
            $QemuExe = $path
            break
        }
    }
}

if (-not $QemuExe) {
    Write-Warning "qemu-system-x86_64.exe was not found in PATH or standard Program Files."
    Write-Host "You can install QEMU on Windows using:" -ForegroundColor Yellow
    Write-Host "    winget install SoftwareFreedomConservancy.QEMU" -ForegroundColor Cyan
    Write-Host "Or run the VM directly inside WSL2 using ./scripts/run_qemu.sh" -ForegroundColor Cyan
    exit 1
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " Booting x86_64 Tiny Linux using QEMU on Windows" -ForegroundColor Green
Write-Host " QEMU Binary : $QemuExe"
Write-Host " Kernel      : $KernelFull"
Write-Host " Initramfs   : $InitrdFull"
Write-Host " Memory      : $MemoryMB MB"
Write-Host " Press 'Ctrl + A' then 'X' to exit QEMU at any time."
Write-Host "==========================================================" -ForegroundColor Green

# Test for Windows Hypervisor Platform (WHPX) acceleration
$accelArgs = @("-accel", "whpx", "-accel", "tcg")

$qemuArgs = @(
    "-M", "q35",
    "-m", "${MemoryMB}M",
    "-smp", "2",
    "-kernel", "$KernelFull",
    "-initrd", "$InitrdFull",
    "-netdev", "user,id=net0",
    "-device", "virtio-net-pci,netdev=net0",
    "-append", "console=ttyS0 quiet loglevel=3 panic=1",
    "-no-reboot",
    "-nographic"
) + $accelArgs

& $QemuExe $qemuArgs
