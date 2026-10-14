set -e
cat > /usr/local/sbin/ibiza-cpuinfo.sh <<'S'
#!/bin/sh
# ARM /proc/cpuinfo has no "model name", so Cockpit/lscpu show "unknown". Bind a copy with that line over /proc/cpuinfo.
/usr/bin/grep -q ' /proc/cpuinfo ' /proc/mounts && exit 0
mkdir -p /run/ibiza
/usr/bin/awk '{print} /^processor/{print "model name\t: Qualcomm Kryo 460 (Snapdragon 480 5G, SM4350)"}' /proc/cpuinfo > /run/ibiza/cpuinfo
mount --bind /run/ibiza/cpuinfo /proc/cpuinfo
S
chmod 755 /usr/local/sbin/ibiza-cpuinfo.sh
cat > /etc/systemd/system/ibiza-cpuinfo.service <<'U'
[Unit]
Description=Show a CPU model name in /proc/cpuinfo (ARM has none)
Before=cockpit.socket
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/ibiza-cpuinfo.sh
[Install]
WantedBy=multi-user.target
U
cat > /usr/local/bin/dmidecode <<'D'
#!/bin/sh
# This ARM phone has no SMBIOS. Cockpit's Hardware page calls "dmidecode -t memory"; answer that one call with the
# installed RAM (SoC spec: LPDDR4X) and fail for anything else, like dmidecode does without DMI.
if [ "$1" = "-t" ] && [ "$2" = "memory" ]; then
  kb=$(/usr/bin/awk '/^MemTotal/{print $2}' /proc/meminfo)
  gb=$(( (kb / 1048576) + 1 )); [ "$gb" -lt 1 ] && gb=1
  cat <<M
# dmidecode 3.6 (emulated for Moto G50 / SM4350)

Handle 0x0010, DMI type 17, 40 bytes
Memory Device
	Total Width: 64 bits
	Data Width: 64 bits
	Size: $((gb * 1024)) MB
	Form Factor: Die
	Locator: LPDDR4X
	Bank Locator: SoC package
	Type: LPDDR4X
	Speed: 4266 MT/s
	Manufacturer: Unknown
	Rank: 1
	Memory Technology: DRAM
M
  exit 0
fi
echo "dmidecode: no SMBIOS/DMI on this device" >&2
exit 1
D
chmod 755 /usr/local/bin/dmidecode
systemctl daemon-reload
systemctl enable --now ibiza-cpuinfo.service
echo "--- verify"
su woo -c 'cat /proc/meminfo /proc/cpuinfo | grep -E "^model name" | head -n 2'
lscpu | grep -E "Model name" | head -n 2
dmidecode -t memory | sed -n 3,14p
