#!/usr/bin/env python3
"""Fondo del menú de Reinos: un reino medieval al atardecer, pintado con código (sin imágenes de terceros) y determinista.

Capas, de atrás adelante: cielo (índigo -> rosa -> oro) con estrellas, sol y rayos, nubes iluminadas desde abajo, tres cordilleras
con bruma, colinas con linde de pinos, la colina del castillo (izquierda) y la aldea con molino (derecha), y pinos oscuros en
primer plano. Al final: brillo (bloom), viñeta y grano (el grano evita las bandas del degradado al comprimir).

Composición: el menú tapa la franja central (~44 % del ancho), así que el castillo y la aldea viven en los laterales y el centro es
un valle con el resplandor del sol. La imagen es 2,4:1; el juego la dibuja «cover» (se recorta a los lados en pantallas más cuadradas).

Uso: python3 tools/menu_bg/make_bg.py [salida.png]      (por defecto art/menu/fondo.png)
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage as ndi

W, H = 1920, 800
SS = 3                      # sobremuestreo de las siluetas (se promedia al bajar)
SEED = 7
SX, SY = 0.262 * W, 0.62 * H   # el sol: pegado al castillo, fuera de la columna de etiquetas del menú


def C(r, g, b):
    return np.array([r, g, b], dtype=np.float32)


# ----------------------------------------------------------------------------------------------------------------- ruido
def smooth(t):
    return t * t * (3 - 2 * t)


def noise1d(n, k, rng):
    p = rng.random(k + 2)
    x = np.linspace(0, k, n, endpoint=False)
    i = x.astype(int)
    t = smooth(x - i)
    return p[i] * (1 - t) + p[i + 1] * t


def fbm1d(n, k0, octs, rng, gain=0.5):
    out = np.zeros(n)
    amp, tot = 1.0, 0.0
    for o in range(octs):
        out += amp * noise1d(n, k0 * 2 ** o, rng)
        tot += amp
        amp *= gain
    return out / tot


def resize_f(a, h, w):
    return np.asarray(Image.fromarray(a.astype(np.float32), mode="F").resize((w, h), Image.BICUBIC))


def fbm2d(h, w, k0h, k0w, octs, rng, gain=0.5):
    out = np.zeros((h, w), np.float32)
    amp, tot = 1.0, 0.0
    for o in range(octs):
        a = rng.random((k0h * 2 ** o + 2, k0w * 2 ** o + 2)).astype(np.float32)
        out += amp * resize_f(a, h, w)
        tot += amp
        amp *= gain
    return out / tot


rng = np.random.default_rng(SEED)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
xs = np.arange(W, dtype=np.float32)
v = yy / H

# ----------------------------------------------------------------------------------------------------------------- cielo
stops = [(0.00, (0.025, 0.045, 0.15)), (0.22, (0.08, 0.11, 0.31)), (0.42, (0.28, 0.20, 0.46)), (0.55, (0.72, 0.36, 0.42)),
         (0.64, (0.98, 0.58, 0.36)), (0.72, (1.0, 0.80, 0.50)), (1.0, (1.0, 0.86, 0.60))]
sv = [s[0] for s in stops]
img = np.zeros((H, W, 3), np.float32)
for c in range(3):
    img[..., c] = np.interp(v, sv, [s[1][c] for s in stops])
SKY = img.copy()          # el color del cielo en cada fila: sirve de bruma
# el cielo se enfría hacia el lado contrario al sol
away = np.clip((xx - SX) / (0.9 * W), 0, 1)[..., None]
img = img * (1 - 0.18 * away) + C(0.10, 0.12, 0.30) * 0.18 * away * (1 - v[..., None] * 0.5)

# estrellas (solo arriba, tenues)
star = np.zeros((H, W), np.float32)
for _ in range(300):
    sx_, sy_ = rng.random() * W, (rng.random() ** 1.6) * H * 0.45
    star[int(sy_), int(sx_)] = 0.25 + 0.75 * rng.random() ** 2
star = ndi.gaussian_filter(star, 0.9) * 4.5
img += (star * np.clip(1.0 - v / 0.45, 0, 1))[..., None] * C(0.85, 0.88, 1.0)

# sol: disco, resplandor y rayos
rr = np.hypot(xx - SX, yy - SY)
theta = np.arctan2(yy - SY, xx - SX)
ray = np.interp(theta, np.linspace(-math.pi, math.pi, 400), fbm1d(400, 40, 3, rng) ** 2.6)
ray = ndi.gaussian_filter1d(ray, 1.0) * 2.2
glow = 0.95 * np.exp(-rr / (0.075 * H)) + 0.50 * np.exp(-rr / (0.30 * H)) + 0.22 * np.exp(-rr / (0.85 * H)) + 0.10 * ray * np.exp(-rr / (0.55 * H))
img += glow[..., None] * C(1.0, 0.66, 0.30)
disc = np.clip((0.034 * H - rr) / 1.5, 0, 1)
img = img * (1 - disc[..., None]) + C(1.0, 0.96, 0.78) * disc[..., None]

# nubes: bandas alargadas iluminadas por debajo (por el sol bajo)
def clouds(y0, y1, k0h, k0w, thresh, gain, strength, seed):
    r2 = np.random.default_rng(seed)
    d = fbm2d(H, W, k0h, k0w, 5, r2, 0.55)
    d = np.clip((d - thresh) * gain, 0, 1)
    env = np.clip((v - y0) / 0.06, 0, 1) * np.clip((y1 - v) / 0.07, 0, 1)
    d = d * env
    db = ndi.gaussian_filter(d, 5)
    gy, gx = np.gradient(db)
    dirx = np.tanh((SX - xx) / (0.35 * W))
    lit = np.clip(-gy * 70 + (-gx * dirx) * 8 + 0.10, 0, 1)
    near_sun = np.exp(-rr / (0.45 * H))
    lit = np.clip(lit + 0.55 * near_sun * (d > 0.05), 0, 1)
    shade = C(0.20, 0.15, 0.34)
    warm = np.where((v > 0.5)[..., None], C(1.0, 0.64, 0.32), C(0.95, 0.60, 0.50))
    col = shade * (1 - lit[..., None]) + warm * lit[..., None]
    a = (d * strength)[..., None]
    return col, a


for (y0, y1, kh, kw, th, g, st, sd) in [(0.05, 0.48, 3, 12, 0.54, 5.5, 0.85, 11), (0.32, 0.60, 4, 22, 0.56, 5.0, 0.75, 12)]:
    col, a = clouds(y0, y1, kh, kw, th, g, st, sd)
    img = img * (1 - a) + col * a

# ----------------------------------------------------------------------------------------------------------------- capas de terreno
def ridge_curve(base, amp, k0, octs, seed, ridged=0.0):
    r2 = np.random.default_rng(seed)
    f = fbm1d(W, k0, octs, r2)
    if ridged > 0:
        f2 = 1.0 - np.abs(2 * fbm1d(W, k0 + 1, octs, np.random.default_rng(seed + 100)) - 1)
        f = (1 - ridged) * f + ridged * f2
    return (base - amp * (f - 0.3)).astype(np.float32)


def terrain(ytop, top_col, bot_col, fade, rim=0.0, rim_col=C(1.0, 0.62, 0.30), rim_h=0.05, tex=0.0, seed=0):
    """Pinta una cordillera/colina cuyo borde superior es ytop[x]. El color va de top_col (en la cresta) a bot_col (abajo)."""
    global img
    d = (yy - ytop[None, :]) / H
    a = np.clip(yy - ytop[None, :] + 0.5, 0, 1)[..., None]
    g = np.clip(d / fade, 0, 1)[..., None] ** 0.8
    col = top_col * (1 - g) + bot_col * g
    if tex > 0:
        n = fbm2d(H, W, 6, 24, 4, np.random.default_rng(seed + 5), 0.55)
        col = col * (1 + tex * (n[..., None] - 0.5))
    if rim > 0:
        slope = ndi.gaussian_filter1d(np.gradient(ytop), 3)
        dirx = np.sign(SX - xs)
        facing = np.clip(dirx * slope * 0.9, 0, 1)
        rim_a = (facing[None, :] * np.exp(-np.maximum(d, 0) / rim_h))[..., None] * rim
        col = col * (1 - rim_a) + rim_col * rim_a
    img = img * (1 - a) + col * a


def haze(y_center, strength, spread=0.05):
    """Bruma: mezcla lo ya pintado hacia el color del cielo en una franja horizontal (separa las cordilleras)."""
    global img
    a = (strength * np.exp(-(((yy - y_center) / (spread * H)) ** 2)))[..., None]
    img = img * (1 - a) + np.clip(SKY * 1.08 + 0.02, 0, 1) * a


# cordillera lejana (violeta, bruma dorada) + nieve en las cumbres
far = ridge_curve(0.585 * H, 0.17 * H, 3, 6, 21, 0.55)
terrain(far, C(0.58, 0.40, 0.60), C(0.95, 0.64, 0.50), 0.22, rim=0.5, rim_h=0.03)
snow = np.clip((0.50 * H - far) / (0.05 * H), 0, 1)       # solo lo más alto
a = (np.clip(yy - far[None, :] + 0.5, 0, 1) * np.exp(-np.maximum(yy - far[None, :], 0) / (0.035 * H)) * snow[None, :] * 0.55)[..., None]
img = img * (1 - a) + C(0.98, 0.80, 0.78) * a
haze(0.60 * H, 0.35, 0.07)

mid = ridge_curve(0.655 * H, 0.11 * H, 4, 6, 33, 0.35)
terrain(mid, C(0.31, 0.24, 0.47), C(0.62, 0.40, 0.48), 0.2, rim=0.45, rim_h=0.025)
haze(0.675 * H, 0.38, 0.05)

# colinas con bosque lejano
hill = ridge_curve(0.715 * H, 0.05 * H, 3, 5, 44, 0.0)
terrain(hill, C(0.17, 0.20, 0.30), C(0.20, 0.22, 0.30), 0.18, rim=0.35, rim_h=0.02, tex=0.2, seed=44)

# ----------------------------------------------------------------------------------------------------------------- siluetas


class Shapes:
    def __init__(self):
        self.im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    @staticmethod
    def _c(col):
        return tuple(int(max(0, min(1, c)) * 255) for c in col) + (255,)

    def poly(self, pts, col):
        self.d.polygon([(x * SS, y * SS) for x, y in pts], fill=self._c(col))

    def rect(self, x0, y0, x1, y1, col):
        self.d.rectangle([x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1], fill=self._c(col))

    def ellipse(self, x0, y0, x1, y1, col):
        self.d.ellipse([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=self._c(col))

    def line(self, pts, col, width):
        self.d.line([(x * SS, y * SS) for x, y in pts], fill=self._c(col), width=max(1, int(width * SS)), joint="curve")

    def composite(self):
        """Baja el lienzo a W x H promediando con el alfa premultiplicado y lo pone sobre `img`."""
        global img
        arr = np.asarray(self.im)
        out = np.zeros((H, W, 4), np.float32)
        step = 80
        for r in range(0, H, step):
            n = min(step, H - r)
            ch = arr[r * SS:(r + n) * SS].astype(np.float32) / 255.0
            ch[..., :3] *= ch[..., 3:4]
            out[r:r + n] = ch.reshape(n, SS, W, SS, 4).mean(axis=(1, 3))
        a = out[..., 3:4]
        img = img * (1 - a) + out[..., :3]


# colina del castillo (izquierda) y de la aldea (derecha) + valle
def bump(cx, wid, amp):
    return amp * np.exp(-(((xs - cx) / wid) ** 2))


base_near = 0.835 * H - 0.02 * H * fbm1d(W, 4, 4, np.random.default_rng(55))
near = (base_near - bump(0.205 * W, 0.115 * W, 0.235 * H) - bump(0.865 * W, 0.125 * W, 0.215 * H) - bump(0.50 * W, 0.30 * W, 0.02 * H)).astype(np.float32)
near += (0.012 * H * np.sin(xs / 61.0 + 1.0)).astype(np.float32)


def NY(x):
    return float(np.interp(x, xs, near))


# 1) linde de pinos sobre las colinas lejanas (detrás de las colinas cercanas)
S0 = Shapes()
r3 = np.random.default_rng(66)


def pine(S, x, y, h, w, col, tiers=4):
    """Pino: pisos de ramas con el borde dentado (con pocos pisos y pequeño se ve como un triángulo limpio)."""
    for k in range(tiers):
        ap = y - h + k * h * (0.78 / tiers)
        bs = ap + h * (0.40 if tiers <= 4 else 0.30)
        hw = w * 0.5 * (0.40 + 0.60 * (k + 1) / tiers)
        if tiers <= 4 or w < 60:
            S.poly([(x, ap), (x + hw, bs), (x - hw, bs)], col)
        else:
            left, right = [], []
            n = 5
            for j in range(n + 1):
                t = j / n
                ex = hw * t * (1.0 if j % 2 == 0 else 0.80)
                ey = ap + (bs - ap) * t
                left.append((x - ex, ey))
                right.append((x + ex, ey))
            S.poly([(x, ap)] + right + list(reversed(left)), col)
    S.rect(x - w * 0.04, y - h * 0.08, x + w * 0.04, y + 1, col)


x = 0.0
while x < W:
    h_ = 14 + 18 * r3.random()
    yb = float(np.interp(x, xs, hill)) + 2
    v_ = 0.9 + 0.2 * r3.random()
    pine(S0, x, yb + 3, h_, h_ * 0.5, C(0.07, 0.11, 0.18) * v_)
    x += 5 + 9 * r3.random()
S0.composite()
haze(0.735 * H, 0.22, 0.035)


# lago del valle: refleja el cielo (espejo respecto a la orilla lejana) con ondas horizontales
Y0 = int(0.738 * H)
rows = np.arange(Y0, H)
src = np.clip(2 * Y0 - rows, 0, H - 1)
refl = img[src].copy()
rip = ndi.gaussian_filter(np.random.default_rng(123).random((len(rows), W)).astype(np.float32), (1.2, 26)) - 0.5
shift = (rip * 140).astype(int)
cols = np.clip(np.arange(W)[None, :] + shift, 0, W - 1)
refl = np.take_along_axis(refl, cols[..., None].repeat(3, axis=2), axis=1)
refl = ndi.gaussian_filter(refl, (0.8, 5, 0))
depth = ((rows - Y0) / (0.10 * H)).clip(0, 1)[:, None, None]
water = refl * (0.78 - 0.30 * depth) + C(0.03, 0.07, 0.17) * (0.22 + 0.30 * depth)
streak = np.clip(ndi.gaussian_filter(np.random.default_rng(321).random((len(rows), W)).astype(np.float32), (0.6, 40)) - 0.52, 0, 1) * 5.0
water += streak[..., None] * C(1.0, 0.7, 0.4) * 0.10 * np.exp(-(((np.arange(W) - SX) / (0.35 * W)) ** 2))[None, :, None]
img[Y0:] = water

# 2) colinas cercanas con la luz del sol rasante
terrain(near, C(0.09, 0.15, 0.17), C(0.025, 0.05, 0.09), 0.2, rim=0.55, rim_col=C(1.0, 0.58, 0.28), rim_h=0.03, tex=0.25, seed=77)

# camino que baja de la puerta del castillo (color de tierra seca con el sol rasante)
S1 = Shapes()
CX = 0.205 * W
pts = []
for t in np.linspace(0, 1, 40):
    px = CX + 6 + 70 * math.sin(t * 3.3) * (0.3 + t) - 30 * t
    py = NY(CX) + 8 + t * (H * 0.995 - NY(CX))
    pts.append((px, py))
for i in range(len(pts) - 1):
    t = i / len(pts)
    S1.line([pts[i], pts[i + 1]], C(0.42, 0.28, 0.24) * (0.8 + 0.3 * t), 3 + 24 * t ** 1.6)

# ---- castillo ------------------------------------------------------------------------------------------------------
INK = C(0.055, 0.06, 0.13)         # piedra a contraluz
LIT = C(0.50, 0.30, 0.30)          # el lado que mira al sol
ROOF = C(0.10, 0.16, 0.40)         # tejados azules (el color del escudo)
ROOF_L = C(0.30, 0.40, 0.72)
WIN = C(1.0, 0.76, 0.34)
GOLD = C(1.0, 0.80, 0.30)


def merlons(S, x0, x1, ytop, col, w=7, gap=5, h=6):
    x = x0
    while x + w <= x1:
        S.rect(x, ytop - h, x + w, ytop + 1, col)
        x += w + gap


def tower(S, cx, ybase, w, h, roof, flag=None, windows=2, crenel=False):
    x0, x1 = cx - w / 2, cx + w / 2
    S.rect(x0, ybase - h, x1, ybase + 6, INK)
    S.rect(x1 - w * 0.22, ybase - h, x1, ybase + 6, LIT * 0.55)               # canto iluminado
    if crenel:
        S.rect(x0 - 3, ybase - h - 4, x1 + 3, ybase - h + 5, INK)
        merlons(S, x0 - 3, x1 + 3, ybase - h - 4, INK, 6, 4, 6)
    else:
        S.rect(x0 - 3, ybase - h - 2, x1 + 3, ybase - h + 4, INK)
        S.poly([(x0 - 6, ybase - h + 1), (cx, ybase - h - roof), (x1 + 6, ybase - h + 1)], ROOF)
        S.poly([(cx, ybase - h - roof), (x1 + 6, ybase - h + 1), (cx + 1, ybase - h + 1)], ROOF_L * 0.8)
    for i in range(windows):
        wy = ybase - h * (0.78 - 0.30 * i)
        S.rect(cx - 2.5, wy, cx + 2.5, wy + 9, WIN)
    if flag is not None:
        top = ybase - h - (0 if crenel else roof)
        S.line([(cx, top), (cx, top - 30)], INK, 1.6)
        fl = [(cx, top - 30), (cx + 26, top - 25), (cx + 20, top - 21), (cx + 27, top - 16), (cx, top - 14)]
        S.poly(fl, flag)
        S.line([(cx + 2, top - 22), (cx + 22, top - 21)], GOLD, 2.0)


wall_h = 40
x0w, x1w = CX - 150, CX + 150
# muro cortina que sigue la ladera (la altura es constante sobre el terreno)
top_pts = [(xx_, NY(xx_) - wall_h) for xx_ in range(int(x0w), int(x1w) + 1, 4)]
S1.poly(top_pts + [(x1w, NY(x1w) + 8), (x0w, NY(x0w) + 8)], INK)
for xx_ in range(int(x0w) + 6, int(x1w) - 8, 11):
    S1.rect(xx_, NY(xx_) - wall_h - 7, xx_ + 6, NY(xx_) - wall_h + 1, INK)
# edificios dentro del recinto (detrás del muro)
S1.poly([(CX - 102, NY(CX - 102) - wall_h - 4), (CX - 102, NY(CX - 102) - wall_h - 46), (CX - 70, NY(CX - 70) - wall_h - 74),
         (CX - 38, NY(CX - 38) - wall_h - 46), (CX - 38, NY(CX - 38) - wall_h - 4)], INK)
# torre del homenaje con torreón y chapitel
ky = NY(CX) - wall_h + 6
tower(S1, CX, ky + wall_h - 6, 72, 170, 70, flag=C(0.16, 0.34, 0.80), windows=3, crenel=False)
tower(S1, CX - 52, NY(CX - 52) + 2, 38, 118, 56, flag=None, windows=2)
tower(S1, CX + 54, NY(CX + 54) + 2, 38, 126, 56, flag=C(0.78, 0.16, 0.16), windows=2)
tower(S1, CX - 128, NY(CX - 128) + 2, 40, 86, 0, flag=None, windows=1, crenel=True)
tower(S1, CX + 128, NY(CX + 128) + 2, 40, 92, 0, flag=None, windows=1, crenel=True)
tower(S1, CX - 152, NY(CX - 152) + 4, 28, 60, 0, flag=None, windows=0, crenel=True)
tower(S1, CX + 152, NY(CX + 152) + 4, 28, 66, 0, flag=C(0.16, 0.34, 0.80), windows=0, crenel=True)
# puerta con luz de antorchas
gx, gy = CX + 4, NY(CX + 4) + 4
S1.poly([(gx - 13, gy), (gx - 13, gy - 22), (gx - 9, gy - 33), (gx, gy - 38), (gx + 9, gy - 33), (gx + 13, gy - 22), (gx + 13, gy)], WIN * 0.85)
S1.poly([(gx - 8, gy), (gx - 8, gy - 22), (gx, gy - 30), (gx + 8, gy - 22), (gx + 8, gy)], C(0.10, 0.05, 0.05))

# ---- aldea ---------------------------------------------------------------------------------------------------------
r4 = np.random.default_rng(88)


def house(S, x, y, w, wall, roofh, tone):
    wl = C(0.20, 0.13, 0.20) * tone
    S.rect(x - w / 2, y - wall, x + w / 2, y + 1, wl)
    S.rect(x - w / 2, y - wall, x - w / 2 + w * 0.25, y + 1, C(0.55, 0.32, 0.28) * 0.55 * tone)     # lado iluminado (izquierda: el sol está a la izquierda)
    S.poly([(x - w / 2 - 3, y - wall + 1), (x, y - wall - roofh), (x + w / 2 + 3, y - wall + 1)], C(0.34, 0.12, 0.13) * tone)
    S.poly([(x - w / 2 - 3, y - wall + 1), (x, y - wall - roofh), (x, y - wall + 1)], C(0.86, 0.36, 0.22) * tone)
    S.rect(x + w * 0.12, y - wall - roofh * 0.95, x + w * 0.12 + 4, y - wall - roofh * 0.35, wl)       # chimenea
    S.rect(x - 2.5, y - wall * 0.62, x + 2.5, y - wall * 0.62 + 7, WIN)
    if w > 36:
        S.rect(x - w * 0.32, y - wall * 0.62, x - w * 0.32 + 5, y - wall * 0.62 + 7, WIN)


houses = []
for _ in range(17):
    hx = (0.765 + 0.215 * r4.random()) * W
    houses.append((hx, NY(hx) + 4 + 14 * r4.random()))
houses.sort(key=lambda p: p[1])
smoke = []
for hx, hy in houses:
    t = (hy - 0.58 * H) / (0.4 * H)
    s = 1.0 + 0.7 * np.clip(t, 0, 1)
    house(S1, hx, hy, 30 * s + 8 * r4.random(), 21 * s, 17 * s, 0.85 + 0.3 * r4.random())
    if r4.random() < 0.7:
        smoke.append((hx + 4 * s, hy - 38 * s))

# molino de viento en lo alto de la colina
mx = 0.905 * W
my = NY(mx) + 4
S1.poly([(mx - 17, my), (mx - 10, my - 76), (mx + 10, my - 76), (mx + 17, my)], INK)
S1.poly([(mx - 17, my), (mx - 10, my - 76), (mx - 6, my - 76), (mx - 12, my)], LIT * 0.5)
S1.poly([(mx - 14, my - 76), (mx, my - 94), (mx + 14, my - 76)], C(0.28, 0.1, 0.12))
hub = (mx, my - 80)
for k in range(4):
    ang = math.radians(25 + 90 * k)
    ex, ey = hub[0] + 56 * math.cos(ang), hub[1] + 56 * math.sin(ang)
    S1.line([hub, (ex, ey)], INK, 2.4)
    px_, py_ = -math.sin(ang), math.cos(ang)
    S1.poly([(hub[0] + 14 * math.cos(ang), hub[1] + 14 * math.sin(ang)), (ex, ey),
             (ex + 12 * px_, ey + 12 * py_), (hub[0] + 14 * math.cos(ang) + 12 * px_, hub[1] + 14 * math.sin(ang) + 12 * py_)], INK * 1.2)
S1.ellipse(hub[0] - 4, hub[1] - 4, hub[0] + 4, hub[1] + 4, INK)


# campamento en la orilla: tiendas con hogueras y estandartes
r5 = np.random.default_rng(101)
fires = []
for k in range(4):
    tx = (0.735 + 0.085 * k / 3 + 0.008 * r5.random()) * W
    ty = NY(tx) + 6 + 4 * r5.random()
    tw = 44 + 10 * r5.random()
    th = 32 + 6 * r5.random()
    S1.poly([(tx - tw / 2, ty), (tx, ty - th), (tx + tw / 2, ty)], C(0.30, 0.22, 0.20))
    S1.poly([(tx - tw / 2, ty), (tx, ty - th), (tx, ty)], C(0.80, 0.52, 0.36))
    S1.rect(tx - 3, ty - 9, tx + 3, ty, C(0.10, 0.05, 0.05))
    S1.line([(tx, ty - th), (tx, ty - th - 14)], INK, 1.3)
    S1.poly([(tx, ty - th - 14), (tx + 12, ty - th - 11), (tx, ty - th - 8)], C(0.16, 0.34, 0.80) if k % 2 == 0 else C(0.78, 0.16, 0.16))
    fires.append((tx + tw * 0.75, ty + 3))
for fx_, fy_ in fires:
    S1.ellipse(fx_ - 2.5, fy_ - 4, fx_ + 2.5, fy_ + 1, C(1.0, 0.72, 0.28))

# árboles de hoja sobre las colinas cercanas (copas redondas) y algún pino
for _ in range(34):
    side = r4.random() < 0.5
    tx = (0.01 + 0.30 * r4.random() if side else 0.70 + 0.29 * r4.random()) * W
    ty = NY(tx) + 6 + 24 * r4.random()
    s = 0.7 + 0.8 * (ty / H - 0.55)
    if abs(tx - CX) < 175 and ty < NY(CX) + 40:
        continue
    if r4.random() < 0.55:
        pine(S1, tx, ty, 38 * s, 20 * s, C(0.04, 0.09, 0.12) * (0.8 + 0.4 * r4.random()))
    else:
        S1.rect(tx - 1.5, ty - 9 * s, tx + 1.5, ty, C(0.04, 0.05, 0.08))
        for dx, dy, rad in [(-7, -16, 9), (6, -17, 10), (0, -24, 11), (-2, -13, 9)]:
            S1.ellipse(tx + (dx - rad) * s, ty + (dy - rad) * s, tx + (dx + rad) * s, ty + (dy + rad) * s, C(0.05, 0.11, 0.13) * (0.85 + 0.3 * r4.random()))

S1.composite()

# resplandor de las hogueras
for fx_, fy_ in fires:
    m = np.exp(-(((xx - fx_) / 26) ** 2 + ((yy - fy_) / 18) ** 2))
    img += m[..., None] * C(1.0, 0.55, 0.18) * 0.30

# humo de las chimeneas
for sx_, sy_ in smoke:
    for k in range(6):
        px_, py_ = sx_ + 4 * k + 2 * math.sin(k * 1.7), sy_ - 11 * k
        rad = 4 + 3.2 * k
        m = np.exp(-(((xx - px_) / rad) ** 2 + ((yy - py_) / rad) ** 2))
        img = img * (1 - 0.16 * m[..., None]) + C(0.62, 0.48, 0.55) * 0.16 * m[..., None]

# ----------------------------------------------------------------------------------------------------------------- primer plano
S2 = Shapes()
FG = C(0.015, 0.03, 0.055)
for fx, fh, fw in [(0.015, 330, 150), (0.075, 250, 120), (0.145, 160, 80), (0.985, 340, 150), (0.925, 255, 120), (0.862, 170, 82), (0.03, 190, 100)]:
    pine(S2, fx * W, 0.995 * H + 8, fh, fw, FG * (0.9 + 0.2 * r4.random()), tiers=6)
# hierba / matorral en el borde inferior
for k in range(320):
    gx_ = r4.random() * W
    gh = 6 + 22 * r4.random() * (1.0 if (gx_ < 0.3 * W or gx_ > 0.7 * W) else 0.4)
    S2.poly([(gx_ - 2, H + 1), (gx_ + 2 + 3 * r4.random(), H - gh), (gx_ + 4, H + 1)], FG)
S2.composite()

# aves sobre el castillo y la aldea (lejos de la columna del menú, donde taparían el texto)
S3 = Shapes()
for bx, by, bs in [(0.175, 0.17, 1.0), (0.198, 0.135, 0.8), (0.215, 0.185, 0.9), (0.152, 0.125, 0.7), (0.78, 0.30, 0.8), (0.805, 0.34, 0.7)]:
    x_, y_ = bx * W, by * H
    S3.line([(x_ - 9 * bs, y_ - 3 * bs), (x_ - 4 * bs, y_ - 7 * bs), (x_, y_), (x_ + 4 * bs, y_ - 7 * bs), (x_ + 9 * bs, y_ - 3 * bs)], C(0.07, 0.06, 0.14), 1.6 * bs)
S3.composite()

# ----------------------------------------------------------------------------------------------------------------- acabado
lum = img.mean(axis=2)
bright = np.clip(lum - 0.62, 0, 1)[..., None] * img
bloom = np.stack([ndi.gaussian_filter(bright[..., c], 16) for c in range(3)], axis=-1) + np.stack([ndi.gaussian_filter(bright[..., c], 48) for c in range(3)], axis=-1) * 0.8
img = img + 0.60 * bloom

# viñeta y oscurecido del borde inferior (el menú lleva ahí texto claro)
rx, ry = (xx / W - 0.5) * 2.0, (yy / H - 0.5) * 2.0
vig = 1.0 - 0.34 * np.clip((rx ** 2) * 0.8 + (ry ** 2) * 0.55 - 0.15, 0, 1) ** 1.3
img = img * vig[..., None]
img = img * (1 - 0.35 * np.clip((v - 0.86) / 0.14, 0, 1))[..., None]

# gradación suave (curva en S ligera) y grano
img = np.clip(img, 0, 1)
img = img * img * (3 - 2 * img) * 0.35 + img * 0.65
img += np.random.default_rng(99).normal(0, 0.011, img.shape).astype(np.float32)
out = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)

dest = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "..", "art", "menu", "fondo.png")
os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
Image.fromarray(out).save(dest, optimize=True)
print("fondo escrito:", os.path.abspath(dest), out.shape)
