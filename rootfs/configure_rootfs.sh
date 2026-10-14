#!/bin/bash
# Run as root in ibiza-build after build_rootfs.sh. Arg1: path to ssh public key.
set -euo pipefail
R=/var/tmp/ibiza-rootfs
KEY="$1"
echo ibiza > $R/etc/hostname
printf '127.0.0.1 localhost\n127.0.1.1 ibiza\n::1 localhost ip6-localhost ip6-loopback\n' > $R/etc/hosts
printf '# rootfs is mounted by initramfs\n' > $R/etc/fstab
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' $R/etc/locale.gen
printf 'LANG=en_US.UTF-8\n' > $R/etc/default/locale
TZ_NAME=${TZ_NAME:-UTC}; echo $TZ_NAME > $R/etc/timezone; ln -sf /usr/share/zoneinfo/$TZ_NAME $R/etc/localtime
mkdir -p $R/etc/systemd/network $R/root/.ssh
cat > $R/etc/systemd/network/10-usb0.network <<N
[Match]
Name=usb0
[Network]
DHCP=ipv4
Address=10.55.0.2/24
IPv6AcceptRA=yes
[DHCPv4]
UseDNS=yes
UseRoutes=yes
RouteMetric=10
N
install -m600 "$KEY" $R/root/.ssh/authorized_keys
chmod 700 $R/root/.ssh
printf 'PermitRootLogin yes\n' > $R/etc/ssh/sshd_config.d/10-ibiza.conf
chroot $R /bin/bash -c 'locale-gen && echo "root:${ROOT_PW:-ibiza}" | chpasswd && systemctl enable systemd-networkd ssh serial-getty@ttyGS0.service && systemctl disable systemd-resolved 2>/dev/null; true'
rm -f $R/etc/resolv.conf; printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > $R/etc/resolv.conf
rm -f $R/etc/ssh/ssh_host_*; chroot $R ssh-keygen -A
chroot $R apt-get clean

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
cat > $R/etc/systemd/system/ibiza-getty.service <<'N'
[Unit]
Description=Serial console on ttyGS0 (no .device dependency: kernel has no devtmpfs)
After=systemd-user-sessions.service
[Service]
ExecStart=/sbin/agetty -L --noclear ttyGS0 115200 vt220
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
N
chroot $R systemctl enable ibiza-cpufreq.service ibiza-getty.service
chroot $R systemctl mask serial-getty@ttyGS0.service
