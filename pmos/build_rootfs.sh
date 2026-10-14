#!/bin/bash
# Builds a console-only postmarketOS ("Nura edge", OpenRC) root filesystem for this phone, inside a native arm64 VM
# (tested in an OrbStack Debian VM). The kernel and initramfs come from boot/, not from pmbootstrap.
# Result: $OUT, an ext4 image to copy to /pmos/rootfs.img on the phone's Debian partition.
# Needs: git, openssl, kpartx, sudo, and your public keys in ~/pmos-keys/*.pub.
set -euo pipefail
OUT=${OUT:-$PWD/rootfs.img}
W=$HOME/.local/var/pmbootstrap
sudo apt-get install -y git openssl kpartx
mkdir -p ~/src ~/.config ~/pmos-keys $W/cache_git
echo 8 > $W/version
[ -d ~/src/pmbootstrap ] || git clone --depth 1 https://gitlab.postmarketos.org/postmarketOS/pmbootstrap.git ~/src/pmbootstrap
[ -d $W/cache_git/pmaports ] || git clone --depth 1 https://gitlab.postmarketos.org/postmarketOS/pmaports.git $W/cache_git/pmaports
cat > ~/.config/pmbootstrap_v3.cfg <<'CFG'
[pmbootstrap]
device = qemu-aarch64
ui = none
user = woo
hostname = ibiza-pmos
timezone = Pacific/Auckland
locale = en_US.UTF-8
ssh_keys = True
ssh_key_glob = ~/pmos-keys/*.pub
extra_packages = none
service_manager = openrc
CFG
cd ~/src/pmbootstrap
./pmbootstrap.py -y install --password "$(openssl rand -hex 12)" --split
cp $W/chroot_native/home/pmos/rootfs/qemu-aarch64-root.img "$OUT"
# Static address on the USB gadget (stage 1 already created usb0), and drop pmOS's own USB DHCP service
sudo mkdir -p /mnt/pmroot && sudo mount -o loop "$OUT" /mnt/pmroot
sudo mkdir -p /mnt/pmroot/etc/local.d
printf '#!/bin/sh\nip link set usb0 up\nip addr add 192.168.2.200/24 dev usb0\nip route add default via 192.168.2.1 dev usb0 metric 700\n' | sudo tee /mnt/pmroot/etc/local.d/10-ibiza-usb0.start >/dev/null
sudo chmod 755 /mnt/pmroot/etc/local.d/10-ibiza-usb0.start
sudo rm -f /mnt/pmroot/etc/runlevels/boot/unudhcpd.usb0
# Root login by key and passwordless sudo for wheel (the dummy password above is unknown, so without this nothing in the
# image can be rebooted or administered by a normal user)
sudo install -d -m 700 /mnt/pmroot/root/.ssh
cat ~/pmos-keys/*.pub | sudo tee /mnt/pmroot/root/.ssh/authorized_keys >/dev/null
sudo chmod 600 /mnt/pmroot/root/.ssh/authorized_keys
printf '%%wheel ALL=(ALL:ALL) NOPASSWD: ALL\n' | sudo tee /mnt/pmroot/etc/sudoers.d/10-wheel-nopasswd >/dev/null
sudo chmod 440 /mnt/pmroot/etc/sudoers.d/10-wheel-nopasswd
sudo umount /mnt/pmroot
echo "done: $OUT"
