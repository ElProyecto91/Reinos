#!/usr/bin/env python3
"""Empaqueta los sprites isométricos (salida de iso_post.py) en hojas de 2048x2048 para la prueba de rendimiento.
Escribe en <destino>: atlas_N.png, atlas.json ({"sheets": [...], "sprites": {nombre: [hoja, x, y, w, h, ox, oy]}}) y,
en <destino>/ind/, los PNG sueltos (para comparar el coste de no usar atlas).
Uso: python3 tools/iso/iso_atlas.py /tmp/iso_sprites isotest/sprites"""
import json, os, shutil, sys
from PIL import Image

SHEET = 2048
PAD = 6

def main():
    src, dst = sys.argv[1], sys.argv[2]
    anchors = json.load(open(os.path.join(src, "anchors.json")))
    names = sorted(anchors, key=lambda n: -anchors[n][3])        # por altura decreciente (empaquetado por estantes)
    os.makedirs(os.path.join(dst, "ind"), exist_ok=True)
    for f in os.listdir(dst):
        if f.startswith("atlas_") and f.endswith(".png"):
            os.remove(os.path.join(dst, f))
    sheets, placed = [], {}
    cur = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
    x = y = shelf_h = 0
    for n in names:
        im = Image.open(os.path.join(src, n + ".png")).convert("RGBA")
        w, h = im.size
        if x + w + PAD > SHEET:
            x, y, shelf_h = 0, y + shelf_h + PAD, 0
        if y + h + PAD > SHEET:
            sheets.append(cur)
            cur = Image.new("RGBA", (SHEET, SHEET), (0, 0, 0, 0))
            x = y = shelf_h = 0
        cur.alpha_composite(im, (x + PAD // 2, y + PAD // 2))
        a = anchors[n]
        placed[n] = [len(sheets), x + PAD // 2, y + PAD // 2, w, h, a[0], a[1]]
        x += w + PAD
        shelf_h = max(shelf_h, h)
        shutil.copy(os.path.join(src, n + ".png"), os.path.join(dst, "ind", n + ".png"))
    sheets.append(cur)
    names_out = []
    for i, s in enumerate(sheets):
        nm = "atlas_%d.png" % i
        s.save(os.path.join(dst, nm), optimize=True)
        names_out.append(nm)
    json.dump({"sheets": names_out, "sprites": placed}, open(os.path.join(dst, "atlas.json"), "w"))
    tot = sum(os.path.getsize(os.path.join(dst, f)) for f in names_out)
    print("sprites:", len(placed), "hojas:", len(sheets), "peso hojas: %.2f MB" % (tot / 1e6))

if __name__ == "__main__":
    main()
