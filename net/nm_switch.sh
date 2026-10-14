#!/bin/sh
# Hand usb0 over from systemd-networkd to NetworkManager (runs detached on the phone)
exec >/root/nm_switch.log 2>&1
set -x
nmcli connection delete usb0 2>/dev/null
nmcli connection add type ethernet ifname usb0 con-name usb0 connection.autoconnect yes ipv4.method auto ipv4.addresses 10.55.0.2/24 ipv6.method auto
mkdir -p /etc/systemd/network.disabled
mv /etc/systemd/network/10-usb0.network /etc/systemd/network.disabled/ 2>/dev/null
systemctl disable systemd-networkd systemd-networkd.socket systemd-networkd-wait-online.service
systemctl stop systemd-networkd.socket systemd-networkd
sleep 2
nmcli connection up usb0
sleep 8
nmcli general status
nmcli networking connectivity check
ip -br a show usb0
ip route
