#!/usr/bin/env python3
"""Servidor de pruebas para tools/updater_test.gd: imita (mal y bien) la API de releases."""
import http.server, json, sys

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, body, ctype="application/json"):
        b = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)
    def do_GET(self):
        p = self.path
        if p == "/ok":
            self._send(200, json.dumps({"tag_name": "build-99999", "draft": False, "prerelease": False}))
        elif p == "/same":
            self._send(200, json.dumps({"tag_name": "build-3", "draft": False, "prerelease": False}))
        elif p == "/evil":
            self._send(200, json.dumps({"tag_name": "build-9; rm -rf /", "html_url": "http://evil.example/x.apk"}))
        elif p == "/html":
            self._send(200, "<html>hola</html>", "text/html")
        elif p == "/big":
            self._send(200, json.dumps({"tag_name": "build-99999", "pad": "x" * 400000}))
        elif p == "/slow":
            import time; time.sleep(20); self._send(200, "{}")
        else:
            self._send(404, json.dumps({"message": "Not Found"}))

http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
