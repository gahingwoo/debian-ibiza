# postmarketOS (Nura edge) userspace on the vendor 5.4 kernel

A console-only postmarketOS root filesystem boots on this phone, on the same vendor kernel and stage-1 initramfs as Debian.
It is not a postmarketOS device port: there is no `device-motorola-ibiza` package, no screen, and the kernel is not built by
pmbootstrap. It shows that the userspace runs.

Tested 2026-10-14 with `fastboot boot` (nothing is written to `boot_a`; a reboot returns to Debian):

* `build_rootfs.sh` builds the root image with pmbootstrap for the generic `qemu-aarch64` device (about 400 MB).
* Copy it to `/pmos/rootfs.img` on the phone's Debian partition.
* Build the boot image with `ibiza.rootfile=/pmos/rootfs.img` on the kernel command line (see `boot/build_stage1.py`).
  Stage 1 then mounts the Debian partition, loop-mounts that file as the root and starts `/sbin/init`. If the file is missing
  or unusable it falls back to the normal Debian boot.
* Result: Nura edge on Linux 5.4.302-moto, OpenRC as PID 1, `usb0` at 192.168.2.200, sshd running, 20 services started and
  none crashed. Log in as `woo` or `root` with the ssh key you put in `~/pmos-keys/`; `wheel` has passwordless sudo.
  (The first test image had neither, so the running system could not be rebooted remotely; the root key and sudo rule are
  added by `build_rootfs.sh` now, checked only by inspecting the image, not by booting it again.)

The systemd variant does not work. Its PID 1 prints `Failed to determine whether /proc is a mount point` and freezes, because
this kernel has no `CONFIG_FHANDLE` (no `name_to_handle_at`) and its `statx` has no mount id (added in Linux 5.8). Debian's
systemd 257 has a fallback and boots; use the OpenRC variant (`service_manager = openrc`).

WiFi, Bluetooth and Cockpit are not set up in the postmarketOS root. The WiFi and Bluetooth scripts in this repository
assume Debian paths.
