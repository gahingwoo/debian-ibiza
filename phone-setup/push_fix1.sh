R=/mnt/root
cat > $R/etc/systemd/network/10-usb0.network <<'N'
[Match]
Name=usb0
[Network]
Address=10.55.0.2/24
Gateway=10.55.0.1
DNS=1.1.1.1
DHCPServer=yes
[DHCPServer]
PoolOffset=10
PoolSize=10
EmitDNS=no
EmitRouter=no
N
cat > $R/etc/systemd/system/ibiza-cpufreq.service <<'N'
[Unit]
Description=Set cpufreq governor to schedutil
After=sysinit.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo schedutil > $g; done'
[Install]
WantedBy=multi-user.target
N
mkdir -p $R/etc/systemd/system/multi-user.target.wants
ln -sf /etc/systemd/system/ibiza-cpufreq.service $R/etc/systemd/system/multi-user.target.wants/ibiza-cpufreq.service
sync
umount $R/dev/pts $R/dev $R/sys $R/proc
sync
umount $R && echo unmounted_ok
mount | grep -c loop0
