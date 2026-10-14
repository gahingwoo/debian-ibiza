#!/bin/sh
# Android was removed (boot_a holds the Debian boot image, userdata is the Debian root), so never offer "Reboot to Android".
# Cockpit's Android card only appears when /run/ibiza/android exists.
mkdir -p /run/ibiza; chmod 755 /run/ibiza; rm -f /run/ibiza/android
exit 0
