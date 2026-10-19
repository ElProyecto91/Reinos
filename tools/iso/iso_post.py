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

SHADOW_MAX = 0.60      # alfa de la sombra más densa (medida: la luz directa aporta ~60 % del brillo del suelo)

def load_mask(path, h, w):
    """Máscara horneada -> dos planos (promedio FACTOR x FACTOR ponderado por la cobertura):
    R = equipo (blanco en el horneado), G = cristal de ventana (verde puro: G alto y R bajo; el blanco del equipo no cuenta)."""
    im = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0
    a = im[..., 3:4]
    team = im[..., 0:1] * a
    win = np.clip(im[..., 1:2] - im[..., 0:1], 0.0, 1.0) * a
    a2 = a.reshape(h // FACTOR, FACTOR, w // FACTOR, FACTOR, 1).mean(axis=(1, 3))
    outs = []
    for m in (team, win):
        m2 = m.reshape(h // FACTOR, FACTOR, w // FACTOR, FACTOR, 1).mean(axis=(1, 3))
        outs.append(np.where(a2 > 1e-4, m2 / np.maximum(a2, 1e-4), 0.0)[..., 0])
    return np.stack(outs, axis=-1)

def process(path, origin=ORIGIN, shadow=False, mask_path=None):   # devuelve (imagen recortada, [ox, oy, ancho, alto], máscara recortada o None)
    im = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0
    h, w = im.shape[:2]
    if shadow:
        # el pase de sombras es un suelo blanco con sombras: alfa = cuánto se oscurece respecto del suelo iluminado
        lum = im[..., :3].mean(axis=2)
        l0 = np.percentile(lum, 99.5)
        sa = np.clip((1.0 - lum / max(l0, 1e-4)) / 0.40, 0.0, 1.0) * SHADOW_MAX
        sa = np.where(sa < 0.03, 0.0, sa)
        im = np.concatenate([np.broadcast_to(np.array([0.02, 0.04, 0.10], dtype=np.float32), (h, w, 3)), sa[..., None]], axis=-1)
    a = im[..., 3:4]
    pm = im[..., :3] * a
    # promedio FACTOR x FACTOR con alfa premultiplicado
    pm = pm.reshape(h // FACTOR, FACTOR, w // FACTOR, FACTOR, 3).mean(axis=(1, 3))
    a2 = a.reshape(h // FACTOR, FACTOR, w // FACTOR, FACTOR, 1).mean(axis=(1, 3))
    rgb = np.where(a2 > 1e-4, pm / np.maximum(a2, 1e-4), 0.0)
    out = np.concatenate([np.clip(rgb, 0, 1), a2], axis=-1)
    ys, xs = np.where(out[..., 3] > 0.02)
    if len(xs) == 0:
        return None, None, None
    if xs.min() <= 1 or ys.min() <= 1 or xs.max() >= out.shape[1] - 2 or ys.max() >= out.shape[0] - 2:
        print("AVISO: el contenido toca el borde del lienzo (recortado): " + os.path.basename(path))
    x0, x1, y0, y1 = max(xs.min() - 1, 0), xs.max() + 2, max(ys.min() - 1, 0), ys.max() + 2
    crop = out[y0:y1, x0:x1]
    img = Image.fromarray((crop * 255.0 + 0.5).astype(np.uint8), "RGBA")
    ox = origin[0] / FACTOR - x0
    oy = origin[1] / FACTOR - y0
    mimg = None
    if mask_path and os.path.exists(mask_path):
        mk = load_mask(mask_path, h, w)[y0:y1, x0:x1]
        mk = np.where(crop[..., 3:4] > 0.02, mk, 0.0)
        mk3 = np.concatenate([mk, np.zeros_like(mk[..., :1])], axis=-1)     # R equipo, G cristal, B sin uso
        mimg = Image.fromarray((np.clip(mk3, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGB")
    return img, [round(ox, 2), round(oy, 2), img.width, img.height], mimg

def main():
    src, dst = sys.argv[1], sys.argv[2]
    os.makedirs(dst, exist_ok=True)
    anchors = {}
    ap = os.path.join(dst, "anchors.json")
    if os.path.exists(ap):      # se acumula: se puede hornear por partes (only=...)
        anchors = json.load(open(ap))
    origins = {}
    op = os.path.join(src, "origins.json")
    if os.path.exists(op):
        origins = json.load(open(op))
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png") or f.endswith("_m.png"):
            continue
        nm = f[:-4]
        img, anc, mimg = process(os.path.join(src, f), origins.get(nm, ORIGIN), nm.endswith("_sh"), os.path.join(src, nm + "_m.png"))
        if img is None:
            print("vacío:", f)
            continue
        name = f[:-4]
        img.save(os.path.join(dst, name + ".png"), optimize=True)
        if mimg is not None:
            mimg.save(os.path.join(dst, name + "_m.png"), optimize=True)
        anchors[name] = anc
    with open(os.path.join(dst, "anchors.json"), "w") as fh:
        json.dump(anchors, fh, indent=0)
    total = sum(os.path.getsize(os.path.join(dst, f)) for f in os.listdir(dst) if f.endswith(".png"))
    print("sprites:", len(anchors), "peso total: %.2f MB" % (total / 1e6))

if __name__ == "__main__":
    main()
