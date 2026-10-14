#!/bin/bash
# Run as root inside the OrbStack machine ibiza-build (native arm64 trixie).
# Output: /var/tmp/ibiza-rootfs (directory), checked by selfcheck.sh
set -euo pipefail
R=/var/tmp/ibiza-rootfs
PKGS=systemd-sysv,systemd-resolved,udev,dbus,bash,coreutils,util-linux,procps,iproute2,iputils-ping,openssh-server,locales,ncurses-base,ncurses-term,less,nano,vim-tiny,ca-certificates,kmod,e2fsprogs,mount,sudo,htop,curl,iptables,nftables,busybox,tzdata,console-setup-linux,bash-completion,man-db,isc-dhcp-client,pciutils,usbutils,lsof,tmux
rm -rf "$R"
debootstrap --variant=minbase --arch=arm64 --include="$PKGS" trixie "$R" http://deb.debian.org/debian
