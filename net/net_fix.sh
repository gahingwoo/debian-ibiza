cat > /usr/local/sbin/ibiza-usb0-up.sh <<'S'
#!/bin/sh
# NetworkManager does not always activate the usb0 profile when the USB gadget was configured by the initramfs first.
i=0
while [ $i -lt 40 ]; do
  if ip -4 -o addr show usb0 2>/dev/null | grep -q " 192\.168\."; then exit 0; fi
  nmcli -w 10 con up usb0 >/dev/null 2>&1 || true
  sleep 4; i=$((i+1))
done
exit 0
S
chmod 755 /usr/local/sbin/ibiza-usb0-up.sh
cat > /etc/systemd/system/ibiza-usb0-up.service <<'U'
[Unit]
Description=Make sure usb0 gets its DHCP lease from the Mac
After=NetworkManager.service
Wants=NetworkManager.service
[Service]
Type=simple
ExecStart=/usr/local/sbin/ibiza-usb0-up.sh
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable ibiza-usb0-up.service 2>&1 | tail -n 1
ip -4 -o addr show usb0
