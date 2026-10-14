set -e
mkdir -p /etc/ibiza
cat > /etc/ibiza/fake-dmi.txt <<'D'
/sys/class/dmi/id/sys_vendor:Motorola
/sys/class/dmi/id/product_name:moto g50 (XT2137-2)
/sys/class/dmi/id/product_version:ibiza
/sys/class/dmi/id/product_family:moto g
/sys/class/dmi/id/product_serial:SERIAL_NUMBER
/sys/class/dmi/id/board_vendor:Motorola
/sys/class/dmi/id/board_name:Snapdragon 480 5G (SM4350)
/sys/class/dmi/id/board_version:holi
/sys/class/dmi/id/bios_vendor:Motorola MBM (UEFI)
/sys/class/dmi/id/bios_version:MBM-3.0-uefi-1f15ff22498-221026
/sys/class/dmi/id/bios_date:10/26/2022
/sys/class/dmi/id/bios_release:3.0
/sys/class/dmi/id/chassis_vendor:Motorola
/sys/class/dmi/id/chassis_type:11
/sys/class/dmi/id/chassis_asset_tag:SERIAL_NUMBER
D
cat > /usr/local/bin/grep <<'W'
#!/bin/sh
# Cockpit reads DMI with "grep -r . /sys/class/dmi/id". This ARM phone has no DMI, so answer that exact call from
# /etc/ibiza/fake-dmi.txt; every other call (and the real-DMI case) goes straight to the real grep.
if [ "$#" -eq 3 ] && [ "$1" = "-r" ] && [ "$2" = "." ] && [ "$3" = "/sys/class/dmi/id" ] && [ ! -d /sys/class/dmi/id ] && [ -r /etc/ibiza/fake-dmi.txt ]; then
  exec /usr/bin/cat /etc/ibiza/fake-dmi.txt
fi
exec /usr/bin/grep "$@"
W
chmod 755 /usr/local/bin/grep
echo "--- as woo, what cockpit runs"
su woo -c 'grep -r . /sys/class/dmi/id || true' | head -n 20
echo "--- normal grep unchanged"
echo hello | grep -c hello
grep -r . /etc/hostname
