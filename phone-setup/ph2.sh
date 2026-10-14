set -e
echo "--- LED state before"
for l in /sys/class/leds/led:*; do echo "$(basename $l) brightness=$(cat $l/brightness) max=$(cat $l/max_brightness)"; done
for l in /sys/class/leds/led:*; do echo 0 > $l/brightness 2>/dev/null || true; done
cat > /usr/local/sbin/ibiza-leds-off.sh <<'S'
#!/bin/sh
# Flash/torch LEDs default to off.
for l in /sys/class/leds/led:*; do echo 0 > $l/brightness 2>/dev/null || true; done
S
cat > /usr/local/sbin/ibiza-android-detect.sh <<'S'
#!/bin/sh
# Writes /run/ibiza/android when an Android boot image is present on slot A, so Cockpit only offers "Reboot to Android"
# when there is something to reboot into.
mkdir -p /run/ibiza; chmod 755 /run/ibiza; rm -f /run/ibiza/android
BOOT=""
for u in /sys/class/block/*/uevent; do
  [ "$(sed -n 's/^PARTNAME=//p' $u)" = "boot_a" ] && BOOT=/dev/$(sed -n 's/^DEVNAME=//p' $u)
done
[ -b "$BOOT" ] || exit 0
[ "$(dd if=$BOOT bs=8 count=1 2>/dev/null)" = "ANDROID!" ] && { echo present > /run/ibiza/android; chmod 644 /run/ibiza/android; }
exit 0
S
chmod 755 /usr/local/sbin/ibiza-leds-off.sh /usr/local/sbin/ibiza-android-detect.sh
cat > /etc/systemd/system/ibiza-misc.service <<'U'
[Unit]
Description=Phone housekeeping: LEDs off, detect Android on slot A
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/ibiza-leds-off.sh
ExecStart=/usr/local/sbin/ibiza-android-detect.sh
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now ibiza-misc.service
echo "--- LED state after"
for l in /sys/class/leds/led:*; do echo "$(basename $l) brightness=$(cat $l/brightness)"; done
echo "--- android"
cat /run/ibiza/android 2>&1; ls -l /run/ibiza
