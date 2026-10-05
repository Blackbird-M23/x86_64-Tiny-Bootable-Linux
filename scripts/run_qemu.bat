@echo off
setlocal

set KERNEL=%~dp0..\bin\bzImage
set INITRD=%~dp0..\bin\initramfs.cpio.gz

if not exist "%KERNEL%" (
    echo [ERROR] Kernel not found at %KERNEL%
    echo Please build it first inside WSL2!
    pause
    exit /b 1
)

if not exist "%INITRD%" (
    echo [ERROR] Initramfs not found at %INITRD%
    echo Please build it first inside WSL2!
    pause
    exit /b 1
)

where qemu-system-x86_64 >nul 2>nul
if %errorlevel% neq 0 (
    if exist "C:\Program Files\qemu\qemu-system-x86_64.exe" (
        set QEMU="C:\Program Files\qemu\qemu-system-x86_64.exe"
    ) else (
        echo [ERROR] qemu-system-x86_64.exe not found!
        echo Install via: winget install SoftwareFreedomConservancy.QEMU
        pause
        exit /b 1
    )
) else (
    set QEMU=qemu-system-x86_64
)

echo =========================================================
echo  Launching x86_64 Tiny Linux in QEMU (Windows)
echo  Press Ctrl+A then X to exit.
echo =========================================================

%QEMU% -M q35 -m 512M -smp 2 -kernel "%KERNEL%" -initrd "%INITRD%" -netdev user,id=net0 -device virtio-net-pci,netdev=net0 -append "console=ttyS0 quiet loglevel=3 panic=1" -no-reboot -nographic -accel whpx -accel tcg

