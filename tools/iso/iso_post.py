#!/usr/bin/env python3
"""Postproceso de los sprites isométricos horneados por tools/iso/iso_bake.gd.
Baja a la mitad (promedio con alfa premultiplicado, sin halos oscuros), recorta al contenido y guarda
`<salida>/<nombre>.png` y `<salida>/anchors.json` con el punto de origen (centro de la huella, a nivel del suelo)
de cada sprite en píxeles del PNG recortado.
Uso: python3 tools/iso/iso_post.py /tmp/iso_raw /tmp/iso_sprites"""
import json, os, sys
import numpy as np
from PIL import Image

ORIGIN = (448, 720)   # igual que en iso_bake.gd
FACTOR = 2

def process(path):
    im = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0
    h, w = im.shape[:2]
    a = im[..., 3:4]
    pm = im[..., :3] * a
    # promedio FACTOR x FACTOR con alfa premultiplicado
    pm = pm.reshape(h // FACTOR, FACTOR, w // FACTOR, FACTOR, 3).mean(axis=(1, 3))
    a2 = a.reshape(h // FACTOR, FACTOR, w // FACTOR, FACTOR, 1).mean(axis=(1, 3))
    rgb = np.where(a2 > 1e-4, pm / np.maximum(a2, 1e-4), 0.0)
    out = np.concatenate([np.clip(rgb, 0, 1), a2], axis=-1)
    ys, xs = np.where(out[..., 3] > 0.02)
    if len(xs) == 0:
        return None, None
    x0, x1, y0, y1 = max(xs.min() - 1, 0), xs.max() + 2, max(ys.min() - 1, 0), ys.max() + 2
    crop = out[y0:y1, x0:x1]
    img = Image.fromarray((crop * 255.0 + 0.5).astype(np.uint8), "RGBA")
    ox = ORIGIN[0] / FACTOR - x0
    oy = ORIGIN[1] / FACTOR - y0
    return img, [round(ox, 2), round(oy, 2), img.width, img.height]

def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    anchors = {}
    ap = os.path.join(dst, "anchors.json")
    if os.path.exists(ap):      # se acumula: se puede hornear por partes (only=...)
        anchors = json.load(open(ap))
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png"):
            continue
        img, anc = process(os.path.join(src, f))
        if img is None:
            print("vacío:", f)
            continue
        name = f[:-4]
        img.save(os.path.join(dst, name + ".png"), optimize=True)
        anchors[name] = anc
    with open(os.path.join(dst, "anchors.json"), "w") as fh:
        json.dump(anchors, fh, indent=0)
    total = sum(os.path.getsize(os.path.join(dst, f)) for f in os.listdir(dst) if f.endswith(".png"))
    print("sprites:", len(anchors), "peso total: %.2f MB" % (total / 1e6))

if __name__ == "__main__":
    main()
