#!/usr/bin/env python3
"""Tiny LAN throughput source for testing the phone's WiFi. GET /zeros?mb=N streams N MiB of zeros; nothing is stored.
Run on the Mac:  python3 speedtest_server.py   (Ctrl-C to stop). Bound to the Mac's WiFi/LAN address only."""
import http.server, socketserver, sys, urllib.parse
BIND = sys.argv[1] if len(sys.argv) > 1 else "0.0.0.0"
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        mb = int(q.get("mb", ["200"])[0]); chunk = bytes(1 << 20)
        self.send_response(200); self.send_header("Content-Length", str(mb << 20)); self.end_headers()
        try:
            for _ in range(mb): self.wfile.write(chunk)
        except (BrokenPipeError, ConnectionResetError): pass
    def do_PUT(self):   # phone -> Mac (upload) test: the body is read and thrown away
        n = int(self.headers.get("Content-Length", 0)); left = n
        while left > 0:
            b = self.rfile.read(min(1 << 20, left));  left -= len(b) if b else left
        self.send_response(200); self.send_header("Content-Length", "0"); self.end_headers()
    def log_message(self, *a): pass
class T(socketserver.ThreadingMixIn, http.server.HTTPServer): daemon_threads = True
print("serving on", BIND, ":8000"); T((BIND, 8000), H).serve_forever()
