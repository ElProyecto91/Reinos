#!/usr/bin/env python3
"""Prepara la clave de firma a partir de los secretos de GitHub, aunque se hayan pegado con texto de más.

Entrada (variables de entorno): KS_B64, KS_PASS. Argumento: ruta del .p12 que se escribirá.
Busca, dentro de lo pegado, el bloque base64 y la contraseña que ABREN el keystore (alias "reinos").
Si ninguno abre, falla describiendo la FORMA de lo pegado (nº de líneas, longitudes), nunca su contenido.
"""
import base64, os, re, subprocess, sys, tempfile

B64_TOKEN = re.compile(r"[A-Za-z0-9+/]+={0,2}")
MIN_TOKEN = 40          # un trozo de clave siempre es largo; las palabras normales no
EXPECTED_LEN = 5708     # longitud aproximada de la clave del proyecto (solo para el diagnóstico)


def b64_blocks(raw: str):
    """Candidatos a clave: bloques de tokens base64 consecutivos (una línea o varias si el texto se
    partió). Si la última línea de un texto partido es corta, se prueban también las variantes con
    las 1-3 palabras siguientes pegadas (una de ellas completa la clave; el resto, al no abrir, se descartan)."""
    toks = raw.replace("\r", "").split()
    blocks = []
    i = 0
    while i < len(toks):
        if len(toks[i]) >= MIN_TOKEN and B64_TOKEN.fullmatch(toks[i]):
            j = i
            cur = []
            while j < len(toks) and len(toks[j]) >= MIN_TOKEN and B64_TOKEN.fullmatch(toks[j]):
                cur.append(toks[j])
                j += 1
            base = "".join(cur)
            blocks.append(base)
            tail = ""
            for k in range(j, min(j + 3, len(toks))):
                if not B64_TOKEN.fullmatch(toks[k]):
                    break
                tail += toks[k]
                blocks.append(base + tail)
            i = j
        else:
            i += 1
    # Texto pegado sin separar ("...A=Huella esperada..."): trozos base64 buscados dentro del texto
    for m in re.finditer(r"[A-Za-z0-9+/]{%d,}={0,2}" % MIN_TOKEN, raw.replace("\r", "")):
        blocks.append(m.group(0))
    # Clave partida en varias líneas: se juntan quitando todo el espacio en blanco
    flat = re.sub(r"\s+", "", raw)
    for m in re.finditer(r"[A-Za-z0-9+/]{200,}={0,2}", flat):
        blocks.append(m.group(0))
    # primero los más largos; la clave real suele ser el mayor
    uniq = sorted(set(blocks), key=len, reverse=True)
    return uniq[:20]


def der_trim(data: bytes):
    """Un .p12 es una secuencia DER que declara su propia longitud: se descarta lo que sobre
    (texto pegado a continuación) y se rechaza si falta parte."""
    if len(data) < 4 or data[0] != 0x30:
        return None
    if data[1] & 0x80:
        n = data[1] & 0x7F
        if n == 0 or n > 4 or len(data) < 2 + n:
            return None
        total = 2 + n + int.from_bytes(data[2:2 + n], "big")
    else:
        total = 2 + data[1]
    return data[:total] if total <= len(data) else None


def pass_candidates(raw: str):
    toks = []
    for t in raw.replace("\r", "").split():
        if t not in toks:
            toks.append(t)
    # contraseñas plausibles primero (alfanuméricas y de longitud razonable)
    good = [t for t in toks if re.fullmatch(r"[A-Za-z0-9]{12,64}", t)]
    rest = [t for t in toks if t not in good]
    return (good + rest)[:25]


def opens(path: str, pw: str) -> bool:
    r = subprocess.run(["keytool", "-list", "-keystore", path, "-storepass", pw, "-alias", "reinos"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return r.returncode == 0


def main() -> int:
    out_path = sys.argv[1]
    raw_b64 = os.environ.get("KS_B64", "")
    raw_pass = os.environ.get("KS_PASS", "")
    blocks = b64_blocks(raw_b64)
    passes = pass_candidates(raw_pass)
    tried = 0
    for blk in blocks:
        data = None
        for cut in (0, 1, 2, 3):          # por si hay letras pegadas que descuadran la última cuarteta
            b = blk[:len(blk) - cut] if cut else blk
            try:
                data = der_trim(base64.b64decode(b + "=" * (-len(b) % 4), validate=True))
            except Exception:
                data = None
            if data is not None:
                break
        if data is None:
            continue
        with open(out_path, "wb") as f:
            f.write(data)
        os.chmod(out_path, 0o600)
        for pw in passes:
            tried += 1
            if opens(out_path, pw):
                print(f"::add-mask::{pw}")
                print(f"::add-mask::{blk}")
                with open(os.environ["GITHUB_ENV"], "a") as g:
                    g.write(f"GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD={pw}\n")
                with open(os.environ["GITHUB_OUTPUT"], "a") as g:
                    g.write("fixed=true\n")
                print("::notice title=Firma::clave fija de los secretos de GitHub (se abre correctamente)")
                return 0
    # fallo: describir la forma, nunca el contenido
    lines_b64 = [l for l in raw_b64.replace("\r", "").split("\n")]
    lens = sorted((len(b) for b in blocks), reverse=True)
    print("::error title=Clave de firma::no se pudo abrir el keystore con lo pegado en los secretos. "
          f"ANDROID_KEYSTORE_B64: {len(lines_b64)} lineas, {len(raw_b64)} caracteres, "
          f"bloques base64 encontrados (longitudes): {lens or 'ninguno'} (esperado ~{EXPECTED_LEN} en un solo bloque). "
          f"ANDROID_KEYSTORE_PASSWORD: {len(raw_pass.split())} palabras, {len(raw_pass)} caracteres (esperado: 1 palabra de 32). "
          f"Combinaciones probadas: {tried}.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
