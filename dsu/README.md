# DSU: boot Debian from Android, reboot returns to Android

A 16 MiB Dynamic System Update image whose `/system/bin/init` is the Debian stage-1 (`dsu_init`). Android's first-stage init
mounts it as `/system` and execs it; it brings up the USB gadget, loop-mounts the Debian rootfs from `super`, `pivot_root`s
(busybox `switch_root` refuses: `/` is ext4, not ramfs) and execs systemd.

From Android (needs root or adb shell):

    gsi_tool enable -s && reboot      # one-shot: next boot is Linux, the boot after that is Android again

Debian's plain `reboot` returns to Android. `gsi_tool wipe` removes the image. Install: `cycle.sh` (adb push + VerificationActivity
intent with `KEY_SYSTEM_SIZE`/`KEY_USERDATA_SIZE`; `am force-stop com.android.dynsystem` first if the intent is silently ignored).
Nothing on slot A or in boot_a is modified. Costs ~0.5 GiB userdata_gsi + 2 GiB scratch in /data while installed.

## Android app
`app/` is a 1-button app (Magisk `su` -> `gsi_tool enable -s && reboot`). Build: `app/build.sh`.
