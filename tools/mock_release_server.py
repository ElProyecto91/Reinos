#!/usr/bin/env python3
"""Servidor de pruebas para tools/updater_test.gd: imita (mal y bien) la API de releases y las descargas del APK."""
import hashlib, http.server, json, re, sys, time

# «APK» de mentira (1,5 MB deterministas) y su suma; el juego exige >= 1 MB
BLOB = bytes((i * 7 + 3) % 256 for i in range(1_500_000))
GOOD = hashlib.sha256(BLOB).hexdigest()
BAD = hashlib.sha256(b"otra cosa").hexdigest()
DL = re.compile(r"^/(dl[a-z0-9]*)/build-(\d{1,6})/reinos\.apk(\.sha256)?$")

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, body, ctype="application/json", extra=None):
        b = body if isinstance(body, bytes) else body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(b)
    def _download(self, kind, build, sha):
        if kind == "dl404":
            return self._send(404, json.dumps({"message": "Not Found"}))
        if kind == "dlredir":
            host = self.headers.get("Host", "127.0.0.1")
            return self._send(302, "", "text/plain", {"Location": "http://%s/dl/build-%s/reinos.apk%s" % (host, build, ".sha256" if sha else "")})
        if sha:
            return self._send(200, ("%s  reinos.apk\n" % (BAD if kind == "dlbad" else GOOD)), "text/plain")
        # el APK
        self.send_response(200)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(len(BLOB)))
        self.end_headers()
        if kind == "dlshort":      # se corta a la mitad
            self.wfile.write(BLOB[:700_000]); self.wfile.flush(); return
        if kind == "dlstall":      # 100 KB y se queda callado
            self.wfile.write(BLOB[:100_000]); self.wfile.flush(); time.sleep(30); return
        if kind == "dlslow":       # a trozos, para ver la barra de progreso
            for i in range(0, len(BLOB), 100_000):
                self.wfile.write(BLOB[i:i + 100_000]); self.wfile.flush(); time.sleep(0.25)
            return
        self.wfile.write(BLOB)
    def do_GET(self):
        p = self.path
        m = DL.match(p)
        if m:
            try:
                return self._download(m.group(1), m.group(2), bool(m.group(3)))
            except (BrokenPipeError, ConnectionResetError):
                return
        if p == "/ok":
            self._send(200, json.dumps({"tag_name": "build-99999", "draft": False, "prerelease": False,
                                        "assets": [{"name": "reinos.apk", "size": 39_000_000}, {"name": "reinos.apk.sha256", "size": 77}]}))
        elif p == "/same":
            self._send(200, json.dumps({"tag_name": "build-3", "draft": False, "prerelease": False}))
        elif p == "/evil":
            self._send(200, json.dumps({"tag_name": "build-9; rm -rf /", "html_url": "http://evil.example/x.apk"}))
        elif p == "/html":
            self._send(200, "<html>hola</html>", "text/html")
        elif p == "/big":
            self._send(200, json.dumps({"tag_name": "build-99999", "pad": "x" * 400000}))
        elif p == "/limit":    # límite de consultas de GitHub sin autenticar
            self._send(403, json.dumps({"message": "API rate limit exceeded"}))
        elif p == "/slow":
            time.sleep(20); self._send(200, "{}")
        else:
            self._send(404, json.dumps({"message": "Not Found"}))

http.server.ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
