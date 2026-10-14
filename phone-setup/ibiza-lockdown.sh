#!/bin/sh
# Stage-1 leftovers: unauthenticated telnetd (:23), CGI httpd (:8080/:8081) must not outlive boot.
for p in /proc/[0-9]*; do
  a=$(tr '\0' ' ' < $p/cmdline 2>/dev/null)
  case "$a" in *"telnetd -l"*|*"httpd -p"*) kill ${p#/proc/} 2>/dev/null;; esac
done
exit 0
