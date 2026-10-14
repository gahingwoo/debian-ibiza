#!/bin/bash
# Run a command inside the RAM Linux over USB:   bash cmd.sh "uname -a"
exec curl -s -m 20 --data-binary "${1:-uname -a}" http://10.55.0.2:8080/cgi-bin/run
