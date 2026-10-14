#!/bin/sh
# Bluetooth bring-up for the WCN3990 once per boot (see HANDOFF): keep the geni UART out of runtime suspend, power the chip,
# download rampatch+NVM from userspace (first TLV segment only 16 bytes), HCI reset, then a resident perl process keeps
# /dev/ttyHS0 open for good and exposes it as a pty that btattach hands to the kernel. Never close the tty: closing makes the
# UART drop RTS and the chip falls asleep.
rm -f /tmp/bt_pty /tmp/bt_proxy.log
rfkill unblock bluetooth 2>/dev/null
nohup setsid /root/bt_bringup.sh proxy >/tmp/bt_proxy.log 2>&1 </dev/null &
i=0; while [ $i -lt 300 ] && [ ! -s /tmp/bt_pty ]; do sleep 1; i=$((i+1)); done
[ -s /tmp/bt_pty ] || { echo "bt_boot: proxy never came up"; tail -n 5 /tmp/bt_proxy.log; exit 1; }
nohup setsid btattach -B "$(cat /tmp/bt_pty)" -P h4 </dev/null >/tmp/btattach.log 2>&1 &
i=0; while [ $i -lt 30 ] && ! hciconfig hci0 >/dev/null 2>&1; do sleep 1; i=$((i+1)); done
sleep 5
systemctl restart bluetooth; sleep 3
bluetoothctl power on >/dev/null 2>&1
echo "bt_boot: $(hciconfig hci0 | sed -n 2p | tr -s ' ') $(hciconfig hci0 | sed -n 3p | tr -d '\t')"
