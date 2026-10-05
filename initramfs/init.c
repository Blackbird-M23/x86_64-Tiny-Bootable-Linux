/*
 * ==============================================================================
 * Minimal Standalone C PID 1 for Linux
 *
 * Demonstrates how PID 1 functions using direct kernel system calls:
 * - Mounts /proc, /sys, /dev
 * - Reaps zombie children (waitpid)
 * - Spawns a shell or basic loop
 * - Shuts down the machine cleanly using sys/reboot.h
 * ==============================================================================
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/mount.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/reboot.h>

static void safe_mkdir(const char *dir) {
    struct stat st;
    if (stat(dir, &st) != 0) {
        mkdir(dir, 0755);
    }
}

int main(int argc, char *argv[]) {
    printf("\n");
    printf("========================================================\n");
    printf("  [PID 1] Minimal C Init Starting on x86_64...\n");
    printf("========================================================\n");

    /* Create and mount pseudo-filesystems */
    safe_mkdir("/proc");
    safe_mkdir("/sys");
    safe_mkdir("/dev");
    safe_mkdir("/tmp");

    if (mount("proc", "/proc", "proc", 0, NULL) == 0) {
        printf("  [PID 1] Mounted /proc successfully.\n");
    } else {
        perror("  [PID 1] Failed to mount /proc");
    }

    if (mount("sysfs", "/sys", "sysfs", 0, NULL) == 0) {
        printf("  [PID 1] Mounted /sys successfully.\n");
    } else {
        perror("  [PID 1] Failed to mount /sys");
    }

    if (mount("devtmpfs", "/dev", "devtmpfs", 0, NULL) == 0) {
        printf("  [PID 1] Mounted /dev (devtmpfs) successfully.\n");
    }

    printf("========================================================\n");
    printf("  Direct C PID 1 is alive. Launching shell...\n");
    printf("========================================================\n\n");

    /* Fork child to run interactive shell if present */
    pid_t pid = fork();
    if (pid == 0) {
        /* Child process */
        char *shell_args[] = {"/bin/sh", NULL};
        char *envp[] = {"PATH=/bin:/sbin:/usr/bin:/usr/sbin", "TERM=linux", NULL};
        execve("/bin/sh", shell_args, envp);
        
        /* If no shell is available, fallback message */
        printf("  [PID 1 Child] /bin/sh not found. Running in standalone loop mode.\n");
        exit(1);
    }

    /* Parent PID 1 loop: reap zombies and wait */
    int status;
    while (1) {
        pid_t wpid = waitpid(-1, &status, WNOHANG);
        if (wpid == pid) {
            printf("\n  [PID 1] Shell process exited. Cleanly shutting down system...\n");
            sync();
            reboot(RB_POWER_OFF);
            break;
        }
        sleep(1);
    }

    return 0;
}
