#!/bin/bash
# Run as root in ibiza-build. Exercises the rootfs in a chroot.
R=/var/tmp/ibiza-rootfs
mount --bind /proc $R/proc; mount --bind /dev $R/dev; mount -t devpts devpts $R/dev/pts 2>/dev/null
trap 'umount $R/dev/pts $R/dev $R/proc 2>/dev/null' EXIT
c(){ echo "== $*"; chroot $R /usr/bin/env -i HOME=/root TERM=xterm-256color PATH=/usr/sbin:/usr/bin:/sbin:/bin /bin/bash -lc "$*" 2>&1 | head -n ${N:-8}; }
c 'echo $BASH_VERSION; echo $SHELL'
c 'locale; locale -a'
c 'dpkg --audit; echo audit_rc=$?'
c 'dpkg -l | grep -vc ^ii'
c 'tput colors; infocmp xterm-256color | head -n 2'
c 'ls /bin/sh -l; ls -l /sbin/init'
c 'systemctl is-enabled ssh systemd-networkd serial-getty@ttyGS0'
c 'sshd -t && echo sshd_ok'
c 'python3 -V 2>&1; less --version | head -n 1; vi --version | head -n 1'
c 'for b in ip ping ss free top htop tmux nano curl nft modprobe mkfs.ext4 lsusb lspci; do command -v $b >/dev/null && echo ok $b || echo MISSING $b; done'
c 'cat /etc/os-release | head -n 3; ls /lib/modules'
