grep -lE "^(PrivateIPC|PrivatePIDs|PrivateUsers|ProtectProc|ProcSubset)=" /usr/lib/systemd/system/cockpit*.service /usr/lib/systemd/system/cockpit*.socket 2>/dev/null
for u in $(ls /usr/lib/systemd/system | grep -E "^cockpit.*\.service$"); do
  if grep -qE "^PrivateIPC=yes|^PrivatePIDs=yes|^PrivateUsers=yes" /usr/lib/systemd/system/$u; then
    mkdir -p /etc/systemd/system/$u.d
    printf '[Service]\nPrivateIPC=no\nPrivatePIDs=no\nPrivateUsers=no\n' > /etc/systemd/system/$u.d/10-ibiza-no-ns.conf
    echo "dropin: $u"
  fi
done
systemctl daemon-reload
systemctl reset-failed cockpit.service cockpit.socket
systemctl restart cockpit.socket
sleep 2
systemctl is-active cockpit.socket
ss -ltn | grep 9090
curl -sk -o /dev/null -w "https://localhost:9090 -> HTTP %{http_code}\n" https://localhost:9090/
systemctl is-active cockpit.service
systemctl --failed --no-legend
