cat > /etc/systemd/system/ibiza-cpuinfo.service <<'U'
[Unit]
Description=Show a CPU model name in /proc/cpuinfo (ARM has none)
# no default dependencies: a Before=cockpit.socket unit that also sits after basic.target forms an ordering cycle with sockets.target
DefaultDependencies=no
After=local-fs.target
Before=cockpit.socket
Conflicts=shutdown.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/ibiza-cpuinfo.sh
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemd-analyze verify /etc/systemd/system/ibiza-cpuinfo.service /usr/lib/systemd/system/cockpit.socket 2>&1 | head -n 5
systemctl start cockpit.socket; sleep 1
systemctl is-active cockpit.socket; ss -ltn | grep ':9090'
curl -sk -m 5 -o /dev/null -w "local https: HTTP %{http_code}\n" https://127.0.0.1:9090/
echo "--- other cycle candidates in my units"; grep -lE "^Before=" /etc/systemd/system/ibiza-*.service
