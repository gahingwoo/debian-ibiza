#!/bin/sh
# Rebuild the whole WiFi stack after every boot of the Debian RAM system. Usage: wifi_stack.sh prep|android|modem|all
# prep:    firmware dir, pd-mapper/tqftpserv/rmtfs (rmtfs works on the EFS COPIES in /root/efs)
# android: read-only system_a/vendor_a + runtime APEX -> writable overlay root /android, binderfs, vndservicemanager, pm-service
# modem:   RELATED restart level, hold /dev/subsys_modem open (this boots the modem; all QRTR services must exist BEFORE this)
set -u
log(){ echo "[wifi_stack] $*"; }
part(){ for u in /sys/class/block/*/uevent; do if [ "$(sed -n 's/^PARTNAME=//p' $u)" = "$1" ]; then echo /dev/$(sed -n 's/^DEVNAME=//p' $u); fi; done; }
prep() {
  mkdir -p /mnt/modem
  mountpoint -q /mnt/modem || mount -o ro "$(part modem_a)" /mnt/modem || return 1
  printf '%s' /mnt/modem/image > /sys/module/firmware_class/parameters/path
  mkdir -p /lib/firmware/pdmap
  for j in /mnt/modem/image/*.jsn /mnt/modem/image/wlanmdsp.mbn; do ln -sf "$j" /lib/firmware/pdmap/; done
  mkdir -p /lib/firmware/wlan/qca_cld
  [ -f /lib/firmware/wlan/qca_cld/WCNSS_qcom_cfg.ini ] || cp /root/WCNSS_qcom_cfg.ini /lib/firmware/wlan/qca_cld/
  mountpoint -q /sys/class/remoteproc || mount -t tmpfs tmpfs /sys/class/remoteproc
  mkdir -p /sys/class/remoteproc/remoteproc0
  printf 'pdmap/modem.mbn' > /sys/class/remoteproc/remoteproc0/firmware
  systemctl reset-failed pd-mapper 2>/dev/null; systemctl restart pd-mapper tqftpserv
  ln -sf /dev/uio0 /dev/qcom_rmtfs_uio1
  pgrep -x rmtfs >/dev/null || (setsid /usr/bin/rmtfs -v -o /root/efs > /tmp/rmtfs.log 2>&1 &)
  sleep 2
  log "QRTR services: $(qrtr-lookup 2>/dev/null | awk 'NR>1{printf "%s ", $1}')"
}
# run an Android daemon inside /android with the property + SELinux stand-ins preloaded
apps_run() { n=$1; shift; pgrep -f "^$1" >/dev/null && return 0
  nohup setsid sh -c "exec chroot /android /system/bin/toybox env LD_PRELOAD=/system/lib64/libibizaprop.so $*" </dev/null >/tmp/$n.log 2>&1 & }
android() {
  for n in 1 2 3; do [ -b /dev/loop$n ] || mknod /dev/loop$n b 7 $n; done
  mkdir -p /mnt/vendor_a /mnt/system_a
  if ! mountpoint -q /mnt/vendor_a; then losetup -d /dev/loop1 2>/dev/null; losetup -r -o $((6898688*512)) --sizelimit $((1180096*512)) /dev/loop1 "$(part super)"; mount -o ro /dev/loop1 /mnt/vendor_a; fi
  if ! mountpoint -q /mnt/system_a; then losetup -d /dev/loop2 2>/dev/null; losetup -r -o $((3431424*512)) --sizelimit $((2302048*512)) /dev/loop2 "$(part super)"; mount -o ro /dev/loop2 /mnt/system_a; fi
  [ -f /root/apex_rt/apex_payload.img ] || { mkdir -p /root/apex_rt; (cd /root/apex_rt && busybox unzip -o /mnt/system_a/system/apex/com.android.runtime.apex >/dev/null); }
  sh /root/android_chroot.sh
  mkdir -p /dev/binderfs; mountpoint -q /dev/binderfs || mount -t binder binder /dev/binderfs
  for n in binder hwbinder vndbinder; do ln -sf /dev/binderfs/$n /dev/$n; done
  # Android's daemons look for the WLAN board data (bdwlan_ibiza_ipa.bin, regdb.bin ...) in /vendor/firmware_mnt/image = modem_a
  mountpoint -q /android/vendor/firmware_mnt || mount --bind /mnt/modem /android/vendor/firmware_mnt
  mkdir -p /android/dev/binderfs; mountpoint -q /android/dev/binderfs || mount --bind /dev/binderfs /android/dev/binderfs
  export ANDROID_ROOT=/system ANDROID_DATA=/data
  cp /root/libibizaprop.so /android/system/lib64/libibizaprop.so; chmod 644 /android/system/lib64/libibizaprop.so
  mkdir -p /android/data/vendor/wifi/sockets /android/mnt/vendor/persist/wlan
  pgrep -x logdw >/dev/null || { nohup setsid perl -e '$0="logdw"; do "/root/logdw.pl"' </dev/null >/tmp/logdw.err 2>&1 & sleep 1; }
  apps_run vndsm /vendor/bin/vndservicemanager /dev/vndbinder
  sleep 1
  apps_run pm-service /vendor/bin/pm-service
  sleep 1
  log "android daemons: $(pgrep -af 'vndservicemanager|pm-service' | cut -d' ' -f2- | tr '\n' ';')"
}
modem() {
  for s in /sys/bus/msm_subsys/devices/subsys*; do echo RELATED > $s/restart_level; done
  pgrep -x modemhold >/dev/null || (setsid perl -e '$0="modemhold"; open(F,"</dev/subsys_modem") or die "open: $!"; sleep 100000' >/tmp/modemhold.log 2>&1 &)
  i=0; while [ $i -lt 30 ]; do sleep 2; i=$((i+1)); [ -n "$(qrtr-lookup 69 2>/dev/null | awk 'NR>1')" ] && break; done
  log "modem=$(cat /sys/bus/msm_subsys/devices/subsys2/state) wlfw(69)=$(qrtr-lookup 69 2>/dev/null | awk 'NR>1{print "up"}') after $((i*2))s"
}
wlan_ko() {  # NEVER rmmod wlan: after a failed load hdd_driver_unload hits BUG() (PANIC_ON_BUG) and the phone panics
  lsmod | grep -q '^wlan ' || insmod /opt/vendor-modules/wlan.ko country_code=NZ
  [ -c /dev/wlan ] || mknod -m 660 /dev/wlan c "$(awk '$2=="qcwlanstate"{print $1}' /proc/devices)" 0
  log "wlan.ko loaded, /dev/wlan ready"
}
cnss() {
  export ANDROID_ROOT=/system ANDROID_DATA=/data
  apps_run cnssd /system/vendor/bin/cnss-daemon -n -l
  sleep 2; log "cnss-daemon: $(pgrep -f '^/system/vendor/bin/cnss-daemon' | head -n 1)"
}
on() {  # start the qcacld driver once the firmware says it is ready (Android's WiFi HAL does this by writing ON to /dev/wlan)
  i=0; while [ $i -lt 60 ]; do dmesg | grep -q 'WLAN FW is ready' && break; sleep 1; i=$((i+1)); done
  ip link show wlan0 >/dev/null 2>&1 && { log "wlan0 already exists"; return 0; }
  echo ON > /dev/wlan 2>/dev/null
  i=0; while [ $i -lt 40 ]; do ip link show wlan0 >/dev/null 2>&1 && break; sleep 1; i=$((i+1)); done
  iw reg set NZ 2>/dev/null
  log "fw ready=$(dmesg | grep -c 'WLAN FW is ready') wlan0=$(ip -br link show wlan0 2>/dev/null | cut -c1-60)"
}
case "${1:-all}" in
  prep) prep;; android) android;; wlan) wlan_ko;; cnss) cnss;; modem) modem;; on) on;;
  all) prep; android; wlan_ko; cnss; modem; on;;
esac
