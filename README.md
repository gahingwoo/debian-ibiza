# debian-ibiza — Debian 13 on a Moto G50 (XT2137-2, SM4350 "holi", codename *ibiza*)

Debian 13 (trixie, arm64) running on a **Motorola Moto G50** with the **stock bootloader, a locked-down hypervisor and the
vendor 5.4 kernel** — no mainline kernel, no new bootloader. Android (LineageOS) stays on slot A and is never modified:
Linux is started from RAM with `fastboot boot`, so a reboot always returns to Android.

中文一句话：不换内核、不动 Android，用 `fastboot boot` 把 Debian 13 从内存里启动起来；WiFi、蓝牙、Cockpit 网页管理都能用。

## Status

| Feature | State | Notes |
|---|---|---|
| Boot Debian 13 (systemd 257) | works | `fastboot boot`, rootfs is a raw ext4 slice of the (unused) slot-B `system_b` area in `super` |
| USB gadget networking + serial | works | NCM + ACM; static `192.168.2.200` on the Mac's Internet Sharing subnet, or `10.55.0.2` |
| `ibiza.local` / Cockpit | works | avahi + Cockpit with a custom **Phone** page (PatternFly 6) |
| **WiFi** (WCN3990 via icnss2 + `wlan.ko`) | works | modem + Android's own `pm-service`/`cnss-daemon` run in a chroot (see below) |
| **Bluetooth** (same chip, UART `ttyHS0`) | works | userspace firmware load + pty proxy; scan verified, pairing/audio untested |
| Regulatory domain | works | `regulatory.db` packed in the initramfs |
| KVM | **impossible** | Qualcomm hypervisor owns EL2 (`CPU: All CPU(s) started at EL1`) |
| Slot B boot | **no** | firmware on slot B is older, bootloader refuses `set_active b`; not needed |
| Cellular modem / audio / GPU / camera | not attempted | the modem *is* booted (WiFi needs it) but cellular is unused |

## How it works

```
fastboot boot boot_b.img
  └─ stage 1 initramfs (boot/init, busybox): USB gadget, mknod-based /dev (kernel has no devtmpfs)
       └─ loop-mounts the rootfs from the `super` partition (offset + no sizelimit) and switch_root → systemd
            ├─ NetworkManager (usb0 static + wlan0), avahi, cockpit
            ├─ ibiza-wifi.service      wifi/wifi_stack.sh   modem + Android helpers + wlan.ko
            └─ ibiza-bluetooth.service bluetooth/bt_boot.sh WCN3990 BT bring-up
```

Things that took the longest to find (details and evidence in [`docs/HANDOFF.md`](docs/HANDOFF.md)):

* **systemd needs `/dev` to be a mount point** — the kernel has no `CONFIG_DEVTMPFS`, and systemd treats the devtmpfs mount as
  fatal and freezes silently otherwise. Stage 1 mounts a tmpfs on the new root's `/dev` and populates it from `/sys/class/*`.
* **WiFi lives in the modem.** The WLAN firmware runs in a modem protection domain that fetches `wlanmdsp.mbn` over TFTP.
  So the modem subsystem must boot (`/dev/subsys_modem`, restart level `RELATED`), with `qrtr`/`pd-mapper`/`tqftpserv`/`rmtfs`
  registered **before** the modem link comes up (the downstream kernel drops userspace QRTR registrations afterwards).
  `rmtfs` works on *copies* of the EFS partitions, never the real ones.
* **Android's userspace runs inside Debian.** `cnss-daemon` (sends board data, calibration) and `pm-service` are bionic
  binaries, run from a read-only `system_a`/`vendor_a` plus the runtime APEX in an overlayfs chroot. `wifi/ibizaprop/propshim.c`
  is a tiny `LD_PRELOAD` that replaces the missing property service and SELinux checks (without it libbinder busy-loops forever
  in `WaitForPropertyCreation`). The board data file (`bdwlan_ibiza_ipa.bin`) must be visible at `/vendor/firmware_mnt/image`.
* **Bluetooth** died seconds after firmware download for four independent reasons: the host geni UART runtime-suspends when
  idle; closing the tty drops RTS and the chip sleeps; the kernel's `hci_qca` sends a 243-byte first TLV segment that
  kills the chip's parser (userspace sends 16 bytes first); and the chip shares power rails with WiFi so power-cycling it is a no-op.
  A resident perl process keeps the tty open and exposes a pty for `btattach`.
* Kernel quirks: no devtmpfs, no IPC/PID/USER namespaces (Cockpit units need `PrivateIPC=no` etc.), no debugfs,
  `wlan.ko` is built with `PANIC_ON_BUG` (**never `rmmod wlan`** after a failed load).

## Layout

| Dir | What |
|---|---|
| `boot/` | stage-1 `init` and `build_stage1.py` (builds the boot image from your `boot.img`'s kernel + busybox + init) |
| `rootfs/` | Debian 13 rootfs build (`debootstrap` in a native arm64 VM), config, self-check, ext4 image |
| `wifi/` | `wifi_stack.sh` (whole stack), Android chroot, property/SELinux shim, logd stand-in, EFS copy |
| `bluetooth/` | WCN3990 bring-up and the pty proxy |
| `net/` | NetworkManager / avahi / usb0 setup |
| `phone-setup/` | Cockpit identity (fake DMI, cpuinfo model name), LED/Android detection, systemd drop-ins |
| `cockpit/` | the Cockpit "Phone" page (React 18 + PatternFly 6, esbuild) |
| `flash/` | the original LineageOS / Magisk / GApps flashing helpers |
| `tools/` | ssh helpers (`pi.sh`), pstore grabber, throughput server |
| `docs/` | `HANDOFF.md` = the complete engineering log with all verified findings |

## What you must supply (not in this repo)

Nothing proprietary is committed. From **your own** phone you need: the LineageOS `boot.img` (kernel), the `modem_a` and
`bluetooth_a` partition contents (firmware), `vendor_a`/`system_a` (read from `super`), `btpower.ko` and `wlan.ko` from
`/vendor/lib/modules`, and Debian packages from deb.debian.org. Cockpit's `pkg/lib` is fetched from
<https://github.com/cockpit-project/cockpit> at commit `92e0108d` (see `cockpit/deploy.sh` / HANDOFF).

## Warnings

* The modem touches the EFS partitions (`modemst1/2`, `fsg`, `fsc`: IMEI, RF calibration). Back them up, and keep `rmtfs`
  on copies (`wifi/efs_copy.sh`). The packaged `rmtfs.service` uses `-P` (real partitions) — mask it.
* The rootfs lives past the end of what the LP metadata registers for `system_b`. Do not run LP operations / OTA updates that
  could allocate in `super`'s free area.
* `rootfs/configure_rootfs.sh` locks the root password unless you pass `ROOT_PW`; add your ssh key to `/root/.ssh/authorized_keys` and a normal sudo user for Cockpit. `phone-setup/ibiza-lockdown.sh` (+ `.service`) kills the stage-1 rescue servers (unauthenticated telnetd/CGI httpd) after boot, and `10-ibiza-hardening.conf` sets `PermitRootLogin prohibit-password`.
* This is research code for one device. Flashing or booting images can brick hardware; read the scripts first.

## Licence

The Cockpit page under `cockpit/` carries AGPL-3.0-or-later headers (structure follows
[ezy_speech_cockpit](https://github.com/gahingwoo/ezy_speech_cockpit) and Cockpit's starter-kit). The rest has no licence file yet.
