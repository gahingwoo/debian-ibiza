dpkg -i /root/debs_avahi/*.deb 2>&1 | tail -n 3
systemctl enable --now avahi-daemon 2>&1 | tail -n 1
sleep 2; systemctl is-active avahi-daemon; avahi-resolve -n ibiza.local 2>&1 | head -n 2
# fixed address: the Mac's Internet Sharing pool is 192.168.2.0/24 and hands out a new lease every boot otherwise
nmcli con mod usb0 ipv4.method manual ipv4.addresses "192.168.2.200/24,10.55.0.2/24" ipv4.gateway 192.168.2.1 ipv4.dns "192.168.2.1 1.1.1.1" ipv4.ignore-auto-dns yes
nohup setsid sh -c 'sleep 1; nmcli con up usb0' </dev/null >/tmp/usb0up.log 2>&1 &
sleep 8
ip -4 -br a show usb0; ip route | head -n 3
