#!/bin/bash
# Build and install the Phone page on the phone (over the project ssh key, see ../linuxb/pi.sh).
set -e
cd "$(dirname "$0")"
NODE_ENV=production node build.js
source ../linuxb/pi.sh
# the backup must live outside /usr/share/cockpit, or Cockpit lists it as a second "Phone"
pssh 'rm -rf /root/ibiza-phone.bak; [ -d /usr/share/cockpit/ibiza-phone ] && mv /usr/share/cockpit/ibiza-phone /root/ibiza-phone.bak; mkdir -p /usr/share/cockpit/ibiza-phone'
COPYFILE_DISABLE=1 tar -C dist -cf - . | pssh 'tar --no-same-owner -C /usr/share/cockpit/ibiza-phone -xf - 2>/dev/null; chown -R root:root /usr/share/cockpit/ibiza-phone && chmod -R a+rX /usr/share/cockpit/ibiza-phone && ls -l /usr/share/cockpit/ibiza-phone'
pssh 'cockpit-bridge --packages 2>&1 | grep -i ibiza'
