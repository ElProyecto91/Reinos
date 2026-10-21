#!/usr/bin/env python3
"""Puente de arte: descarga imágenes por URL en un servidor de GitHub (que sí tiene internet) para dejarlas en art/inbox/.

Por qué existe: las imágenes que genera un conector (FLUX, Hugging Face...) llegan como un enlace firmado y el entorno donde se
programa el juego solo alcanza GitHub. El flujo .github/workflows/art-inbox.yml ejecuta este script, que valida cada enlace y
cada archivo, y deja el resultado en la rama `art-inbox` (nunca en `main`).

Entrada: variable de entorno URLS con elementos «nombre=https://...» separados por espacios o saltos de línea.
Salida: art/inbox/<nombre>.<png|jpg|webp>, más art/inbox/<nombre>.json con el origen (host y tamaño; nunca la URL firmada).

Defensas: solo https; solo dominios de la lista cerrada (también en cada redirección); nombres [a-z0-9_-]; máximo 24 MB;
solo PNG/JPEG/WebP comprobados por sus primeros bytes (la extensión y el Content-Type no se creen); la URL se enmascara en el registro.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

ALLOWED_HOSTS = ("huggingface.co", "raw.githubusercontent.com")   # dominios exactos (Hugging Face; pruebas con archivos del repositorio)
ALLOWED_SUFFIXES = (".bfl.ai", ".huggingface.co", ".hf.space")        # subdominios (FLUX: delivery-*.bfl.ai; Spaces de Gradio)
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,47}$")
MAX_BYTES = 24 * 1024 * 1024
OUT = os.environ.get("ART_INBOX_OUT", "art/inbox")


def host_ok(host: str) -> bool:
    host = (host or "").lower().rstrip(".")
    return host in ALLOWED_HOSTS or host.endswith(ALLOWED_SUFFIXES)


def url_ok(url: str) -> bool:
    p = urllib.parse.urlsplit(url)
    return p.scheme == "https" and p.hostname is not None and p.username is None and p.port in (None, 443) and host_ok(p.hostname)


def sniff(b: bytes):
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"
    if b[:3] == b"\xff\xd8\xff":
        return "jpg"
    if b[:4] == b"RIFF" and b[8:12] == b"WEBP":
        return "webp"
    return None


class Hop(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not url_ok(newurl):
            raise urllib.error.URLError("redirección a un dominio no permitido")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def parse(raw: str):
    items = []
    for tok in raw.split():
        name, sep, url = tok.partition("=")
        if not sep or not NAME_RE.match(name):
            raise ValueError("elemento no válido (se espera nombre=https://...; el nombre solo admite a-z 0-9 _ -)")
        if not url_ok(url):
            raise ValueError("URL no permitida para «%s» (solo https y dominios de la lista cerrada)" % name)
        items.append((name, url))
    if not items:
        raise ValueError("no hay nada que descargar")
    if len({n for n, _ in items}) != len(items):
        raise ValueError("nombres repetidos")
    return items


def fetch(url: str) -> bytes:
    op = urllib.request.build_opener(Hop)
    req = urllib.request.Request(url, headers={"User-Agent": "reinos-art-inbox/1"})
    with op.open(req, timeout=60) as r:
        data = r.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES:
        raise ValueError("más de 24 MB")
    return data


def main() -> int:
    raw = os.environ.get("URLS", "")
    try:
        items = parse(raw)
    except ValueError as e:
        print("ERROR:", e)
        return 2
    for _, url in items:
        print("::add-mask::" + url)
    os.makedirs(OUT, exist_ok=True)
    bad = 0
    for name, url in items:
        host = urllib.parse.urlsplit(url).hostname
        try:
            data = fetch(url)
            ext = sniff(data)
            if ext is None:
                raise ValueError("no es PNG, JPEG ni WebP")
            with open(os.path.join(OUT, "%s.%s" % (name, ext)), "wb") as f:
                f.write(data)
            with open(os.path.join(OUT, "%s.json" % name), "w") as f:
                json.dump({"host": host, "bytes": len(data), "type": ext}, f)
            print("OK  %-24s %9d B  %s  (%s)" % (name, len(data), ext, host))
        except Exception as e:   # noqa: BLE001 - se informa y se sigue con el resto
            bad += 1
            print("FALLO %s (%s): %s" % (name, host, type(e).__name__))
    return 1 if bad == len(items) else 0


if __name__ == "__main__":
    sys.exit(main())
