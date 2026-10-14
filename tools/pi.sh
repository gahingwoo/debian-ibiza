#!/bin/bash
# ssh/scp helpers for the phone over IPv6 link-local on en9. Usage: source pi.sh; pssh "cmd"; pscp files... remote_dir
ping6 -c1 -I en9 ff02::1 >/dev/null 2>&1
PH=$(ndp -an | awk '/en9/ && $1 ~ /^fe80/ && $4 != "permanent" {print $1}' | head -1)
KEY=$HOME/.ssh/ibiza_key
pssh(){ ssh -i $KEY -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "root@$PH" "$@"; }
pscp(){ local dst="${@: -1}"; local n=$(($#-1)); scp -q -i $KEY -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new "${@:1:$n}" "root@[$PH]:$dst"; }
