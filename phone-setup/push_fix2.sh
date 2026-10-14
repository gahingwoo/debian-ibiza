cat > /etc/systemd/system/ibiza-getty.service <<'N'
[Unit]
Description=Serial console on ttyGS0 (no .device dependency)
After=systemd-user-sessions.service
[Service]
ExecStart=/sbin/agetty -L --noclear ttyGS0 115200 vt220
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
N
systemctl mask serial-getty@ttyGS0.service
systemctl enable ibiza-getty.service
systemctl start ibiza-getty.service
systemctl is-active ssh systemd-networkd ibiza-cpufreq ibiza-getty
systemctl is-system-running
ss -ltn | head
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor /sys/devices/system/cpu/cpu6/cpufreq/scaling_governor
