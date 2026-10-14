set -e
mkdir -p /root/efs
dev(){ for u in /sys/class/block/*/uevent; do if [ "$(sed -n 's/^PARTNAME=//p' $u)" = "$1" ]; then echo /dev/$(sed -n 's/^DEVNAME=//p' $u); fi; done; return 0; }
for pair in modemst1:modem_fs1 modemst2:modem_fs2 fsg_a:modem_fsg fsc:modem_fsc; do
  p=${pair%%:*}; f=${pair##*:}; d=$(dev $p)
  [ -b "$d" ] || { echo "no partition $p"; exit 1; }
  dd if=$d of=/root/efs/$f bs=4096 2>/dev/null
  echo "$p ($d) -> /root/efs/$f $(stat -c %s /root/efs/$f) bytes sha256=$(sha256sum /root/efs/$f | cut -c1-16)"
done
chmod 600 /root/efs/*
