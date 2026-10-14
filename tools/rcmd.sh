#!/bin/bash
# Run a command on the Debian side through the rescue CGI (port 8081, IPv6 link-local on en9):  bash rcmd.sh "systemctl --failed"
ping6 -c1 -I en9 ff02::1 >/dev/null 2>&1
A=$(ndp -an | awk '/en9/ && $1 ~ /^fe80/ && $2 != "(incomplete)" && $4 != "permanent" {print $1}' | head -n 1)
[ -n "$A" ] || { echo "no phone LL address on en9" >&2; exit 1; }
exec curl -g -s -m ${T:-30} --data-binary "${1:-uname -a}" "http://[$A]:8081/cgi-bin/run"
