#!/bin/sh
# Cockpit's "File browser" page. Debian 13 does not ship cockpit-files in the main archive, only in trixie-backports.
# Backports have priority 100, so only the package named here is taken from them. Run as root on the phone.
set -e
cat > /etc/apt/sources.list.d/backports.sources <<'S'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
S
apt-get update
apt-get install -y -t trixie-backports cockpit-files
