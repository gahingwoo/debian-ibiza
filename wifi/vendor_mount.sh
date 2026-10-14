SUP=$(for u in /sys/class/block/*/uevent; do if [ "$(sed -n 's/^PARTNAME=//p' $u)" = "super" ]; then echo /dev/$(sed -n 's/^DEVNAME=//p' $u); fi; done)
echo "super=$SUP"
[ -b /dev/loop1 ] || mknod /dev/loop1 b 7 1
losetup -d /dev/loop1 2>/dev/null
losetup -r -o $((6898688*512)) --sizelimit $((1180096*512)) /dev/loop1 $SUP
mkdir -p /mnt/vendor_a; mountpoint -q /mnt/vendor_a || mount -o ro /dev/loop1 /mnt/vendor_a
mount | grep vendor_a
ls /mnt/vendor_a | head -n 12
echo "--- sec_config"; ls -l /mnt/vendor_a/etc/sec_config /mnt/vendor_a/bin/irsc_util 2>&1
cat /mnt/vendor_a/etc/sec_config 2>&1 | head -n 60
