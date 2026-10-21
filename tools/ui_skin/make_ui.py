#!/usr/bin/env python3
"""Texturas de la interfaz de Reinos (madera y pergamino), generadas con código: sin imágenes de terceros y deterministas.

Salida (art/ui/): bar.png (franja de madera de la barra superior; se repite en horizontal), wood_dark.png y parch.png (interiores sin
costuras que se repiten en botones y paneles), btn.png / btn_down.png / btn_on.png (marco biselado del botón en 9 trozos),
panel.png (marco de madera con filete dorado y remaches), mm.png (marco del minimapa) y thin.png (marco fino de los retratos). Los marcos tienen el
centro hueco: solo una sombra interior translúcida que se dibuja encima del interior.

Las texturas se pintan a 1,5 píxeles por píxel virtual (la mayoría de móviles escalan 1,25-1,5): scripts/ui_skin.gd las dibuja
con K = 1/1,5. Todo lo que se repite es sin costuras (el desenfoque gaussiano «envuelve» los bordes).

Uso: python3 tools/ui_skin/make_ui.py [directorio de salida]      (por defecto art/ui)
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

SS = 2   # sobremuestreo de los marcos (filetes y remaches limpios al bajar)
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "ui")

WOOD = np.array([0.54, 0.35, 0.18], np.float32)
PARCH = np.array([0.93, 0.85, 0.66], np.float32)
GOLD = np.array([0.90, 0.70, 0.28], np.float32)
DARK = np.array([0.075, 0.045, 0.025], np.float32)


def lp(h, w, sy, sx, rng):
    """Ruido de paso bajo sin costuras (media 0, desviación 1)."""
    a = rng.standard_normal((h, w)).astype(np.float32)
    a = ndi.gaussian_filter(a, sigma=(sy, sx), mode="wrap")
    a -= a.mean()
    a /= a.std() + 1e-6
    return a


def wood(h, w, plank_h, rng, knots=1, joints=True):
    """Tablones horizontales sin costuras. h debe ser múltiplo de plank_h. Devuelve (h, w, 3) en 0..1."""
    n = h // plank_h
    img = np.zeros((h, w, 3), np.float32)
    g_lo = lp(h, w, 2.0, max(w / 6.0, 16), rng)
    g_hi = lp(h, w, 0.8, max(w / 18.0, 5), rng)
    warp = lp(h, w, 9, max(w / 4.0, 20), rng)
    for p in range(n):
        ys = slice(p * plank_h, (p + 1) * plank_h)
        tone = 1.0 + rng.uniform(-0.12, 0.12)
        hue = rng.uniform(-0.03, 0.03)
        yy = (np.arange(plank_h, dtype=np.float32)[:, None]) / plank_h
        rings = np.sin(2 * np.pi * (yy * rng.uniform(2.5, 4.5) + warp[ys] * 0.35 + rng.random()))
        s = tone * (1 + 0.10 * g_lo[ys] + 0.055 * g_hi[ys] + 0.07 * rings)
        col = WOOD * np.array([1 + hue * 1.6, 1.0, 1 - hue * 1.6], np.float32)
        img[ys] = col[None, None, :] * s[..., None]
    # nudos (con anillos), lejos de las juntas
    y = np.arange(h, dtype=np.float32)[:, None]
    x = np.arange(w, dtype=np.float32)[None, :]
    for _ in range(knots):
        p = int(rng.integers(0, n))
        kx = rng.uniform(0.15, 0.85) * w
        ky = p * plank_h + plank_h * rng.uniform(0.35, 0.65)
        rx, ry = rng.uniform(plank_h * 0.28, plank_h * 0.42), rng.uniform(plank_h * 0.14, plank_h * 0.2)
        dx = ((x - kx + w / 2) % w) - w / 2
        dy = ((y - ky + h / 2) % h) - h / 2
        rr = np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2)
        k = 1.0 - 0.42 * np.exp(-rr ** 2 * 1.3) + 0.10 * np.sin(rr * 8.0) * np.exp(-rr ** 2 * 0.45)
        img *= k[..., None]
    # juntas entre tablones (surco oscuro y borde claro) y juntas a tope escalonadas
    for p in range(n):
        y0 = p * plank_h
        img[y0:y0 + max(1, plank_h // 24)] *= 0.34
        img[(y0 + max(1, plank_h // 24)) % h] *= 1.16
        if joints:
            jx = int(rng.uniform(0.12, 0.88) * w)
            a, b = p * plank_h + 2, (p + 1) * plank_h
            img[a:b, jx:jx + 2] *= 0.42
            img[a:b, (jx + 2) % w] *= 1.12
    return np.clip(img, 0, 1)


def parchment(h, w, rng):
    """Pergamino sin costuras: manchas grandes, moteado, fibras y puntitos."""
    b = lp(h, w, w / 6.0, w / 6.0, rng) * 0.045 + lp(h, w, w / 20.0, w / 20.0, rng) * 0.03 + lp(h, w, 2, 2, rng) * 0.012
    fib = lp(h, w, 0.6, 5, rng) * 0.012 + lp(h, w, 5, 0.6, rng) * 0.012
    stain = np.clip(lp(h, w, w / 9.0, w / 9.0, rng) - 1.15, 0, None) * 0.8
    img = PARCH[None, None, :] * (1 + b + fib)[..., None]
    img *= 1 - stain[..., None] * np.array([0.10, 0.17, 0.30], np.float32)
    dots = rng.random((h, w)) < 0.0015
    dots = ndi.binary_dilation(dots, iterations=1) & (rng.random((h, w)) < 0.6)
    img[dots] *= 0.74
    return np.clip(img, 0, 1)


def frame(N, m, band, rng, gold_w=2.2, gold_k=1.0, rivets=True, up=True, tint=None, shadow=0.5):
    """Marco cuadrado N×N con borde de grosor m (texels finales) y el centro hueco: solo queda la sombra interior, translúcida,
    que se dibuja encima del interior (baldosa de madera o pergamino). up: bisel hacia fuera (sin pulsar) o hacia dentro (pulsado)."""
    P = N - 2 * m
    n2 = N * SS
    xs = (np.arange(n2, dtype=np.float32) + 0.5) / SS
    X, Y = np.meshgrid(xs, xs)
    dl, dr, dt, db = X, N - X, Y, N - Y
    d = np.minimum(np.minimum(dl, dr), np.minimum(dt, db))
    tl = np.minimum(dl, dt) < np.minimum(dr, db)           # más cerca de arriba/izquierda
    hor = np.minimum(dt, db) <= np.minimum(dl, dr)         # banda superior/inferior (inglete a 45°)
    # madera del marco: un tablón por banda, veta a lo largo, con el periodo exacto del lado (sin costuras al repetir)
    wb = wood(band * SS, P * SS, band * SS, rng, knots=0)
    di = np.clip((d * SS).astype(int), 0, band * SS - 1)
    along = np.where(hor, X - m, Y - m)
    ai = np.mod((along * SS).astype(int), P * SS)
    col = wb[di, ai] * np.array([1.12, 1.10, 1.06], np.float32)   # el marco, algo más claro que el interior
    if tint is not None:
        col = col * tint
    img = np.zeros((n2, n2, 4), np.float32)
    img[..., :3] = col
    img[..., 3] = (d < m).astype(np.float32)
    hi = np.where(tl, 1.0, -1.0) * (1.0 if up else -1.0)
    # contorno oscuro y bisel
    img[..., :3] = np.where((d < 1.4)[..., None], DARK, img[..., :3])
    amt = np.where((d >= 1.4) & (d < 3.6), np.where(hi > 0, 0.30, -0.28), 0.0)
    img[..., :3] *= (1 + amt)[..., None]
    # filete dorado (en ranura: el bisel se invierte) y línea oscura interior
    g0, g1 = band, band + gold_w
    gt = np.clip((d - g0) / gold_w, 0, 1)
    gshade = 1.0 + np.where(hi > 0, -0.18, 0.18) * (1 - gt)
    img[..., :3] = np.where(((d >= g0) & (d < g1))[..., None], GOLD[None, None, :] * (gshade * gold_k)[..., None], img[..., :3])
    img[..., :3] = np.where(((d >= g1) & (d < g1 + 1.2))[..., None], DARK, img[..., :3])
    # sombra interior translúcida: del filete hacia el centro
    s0 = g1 + 1.2
    inner = d >= s0
    t = np.clip((d - s0) / max(m - s0, 1e-3), 0, 1)
    img[..., :3] = np.where(inner[..., None], 0.0, img[..., :3])
    img[..., 3] = np.where(inner, shadow * (1 - t) ** 2, img[..., 3])
    img[..., 3] = np.where(d >= m, 0.0, img[..., 3])
    # remaches en las esquinas
    if rivets:
        r = band * 0.27
        for cx, cy in ((band * 0.5 + 0.6, band * 0.5 + 0.6), (N - band * 0.5 - 0.6, band * 0.5 + 0.6),
                       (band * 0.5 + 0.6, N - band * 0.5 - 0.6), (N - band * 0.5 - 0.6, N - band * 0.5 - 0.6)):
            rr = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2)
            lit = 1.0 - np.clip(np.sqrt((X - (cx - r * 0.35)) ** 2 + (Y - (cy - r * 0.35)) ** 2) / (r * 1.3), 0, 1)
            rc = GOLD[None, None, :] * (0.55 + 0.75 * lit)[..., None]
            img[..., :3] = np.where((rr < r)[..., None], rc, img[..., :3])
            img[..., :3] = np.where(((rr >= r) & (rr < r + 0.9))[..., None], DARK, img[..., :3])
            img[..., 3] = np.maximum(img[..., 3], np.where(rr < r + 0.9, 1.0, 0.0))
    return to_image(img)


def to_image(img):
    """Baja el sobremuestreo con alfa premultiplicado (sin halos oscuros en los bordes)."""
    a = img[..., 3:4]
    pm = np.concatenate([img[..., :3] * a, a], axis=2)
    n = img.shape[0] // SS
    pm = pm.reshape(n, SS, n, SS, 4).mean(axis=(1, 3))
    a2 = pm[..., 3:4]
    rgb = np.where(a2 > 1e-4, pm[..., :3] / np.maximum(a2, 1e-4), 0.0)
    out = np.concatenate([rgb, a2], axis=2)
    return Image.fromarray((np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8), "RGBA")


def bar(rng):
    """Franja de la barra superior (84 texels = 56 px virtuales), se repite en horizontal cada 512."""
    h, w = 84, 512
    img = wood(h, w, 42, rng, knots=2)
    img *= np.array([0.80, 0.78, 0.76], np.float32)
    img[0:2] *= 1.30                                  # filo de luz arriba
    img[h - 20:h] *= np.linspace(1.0, 0.72, 20)[:, None, None]
    rows = {h - 9: (DARK, 2), h - 7: (GOLD * 1.0, 3), h - 4: (GOLD * 0.55, 1), h - 3: (DARK, 3)}
    for y0, (c, n) in rows.items():
        img[y0:y0 + n] = c
    img[h - 7] = GOLD * 1.15
    return Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").convert("RGBA")


def save(im, name):
    p = os.path.join(OUT, name)
    im.save(p, optimize=True)
    print("%-14s %dx%d  %6d B" % (name, im.width, im.height, os.path.getsize(p)))


def tile_img(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").convert("RGBA")


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(11)
    save(bar(rng), "bar.png")
    # interiores que se repiten (sin costuras): madera oscura de los botones y pergamino de los paneles
    save(tile_img(wood(128, 128, 64, rng, knots=0, joints=False) * 0.62), "wood_dark.png")
    save(tile_img(parchment(512, 512, rng)), "parch.png")
    # marcos: el centro es hueco (solo sombra interior translúcida)
    save(frame(96, 16, 8, rng, gold_w=1.3, gold_k=0.78, rivets=False, shadow=0.55), "btn.png")
    save(frame(96, 16, 8, rng, gold_w=1.3, gold_k=0.55, rivets=False, up=False, shadow=0.7), "btn_down.png")
    save(frame(96, 16, 8, rng, gold_w=2.6, gold_k=1.12, rivets=False, tint=np.array([1.0, 0.95, 0.85], np.float32), shadow=0.45), "btn_on.png")
    save(frame(256, 24, 10, rng, gold_w=2.0, gold_k=0.95, rivets=True, shadow=0.55), "panel.png")
    save(frame(96, 16, 10, rng, gold_w=1.6, gold_k=0.9, rivets=True, shadow=0.55), "mm.png")
    save(frame(64, 10, 5, rng, gold_w=1.2, gold_k=0.85, rivets=False, shadow=0.5), "thin.png")


if __name__ == "__main__":
    main()
