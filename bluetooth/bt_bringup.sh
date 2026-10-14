#!/bin/sh
# power the WCN3990 BT side, download rampatch+NVM (first segment 16 bytes), then run the given bt_dl3.pl mode
MODE=${1:-wake}
# keep the geni UART out of runtime suspend (its RX is suspended when idle; the Android HAL votes the UART clock on)
echo on > /sys/devices/platform/soc/4a84000.qcom,qup_uart/power/control
lsmod | grep -q '^btpower ' || insmod /opt/vendor-modules/btpower.ko
M=$(cat /sys/class/bt-dev/btpower/dev | cut -d: -f1)
[ -c /dev/btpower ] || mknod -m 666 /dev/btpower c "$M" 0
pkill -x btpwr 2>/dev/null; sleep 1
perl -e 'open(F,q(+</dev/btpower)) or die; ioctl(F,0xbfad,0); sleep 6; ioctl(F,0xbfad,1); sleep 2;'
nohup setsid perl -e '$0="btpwr"; open(F,q(+</dev/btpower)) or die; sleep 100000' </dev/null >/dev/null 2>&1 &
sleep 2
CHIPVER=${CHIPVER:-} IDLE=${IDLE:-12} timeout 500 perl /root/bt_dl3.pl /lib/firmware/qca/crbtfw21.tlv /lib/firmware/qca/crnv21.bin 16 243 "$MODE" 2>&1 | grep -vE "^seg|^download|^done"
