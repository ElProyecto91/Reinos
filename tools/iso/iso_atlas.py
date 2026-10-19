#!/usr/bin/env python3
"""Empaqueta los sprites isométricos (salida de iso_post.py) en hojas de atlas para el juego.
Escribe en <destino> (normalmente art/iso): atlas_N.png (RGBA, con el color de los bordes extendido a los píxeles
transparentes para que el filtrado bilineal no deje halos oscuros), mask_N.png (L, mismo reparto: 255 = parte que se
tiñe con el color del jugador) y atlas.json ({"sheets": [[atlas, máscara], ...], "sprites": {nombre: [hoja, x, y, w, h, ox, oy]}}).
Las categorías van seguidas (lo que se dibuja junto comparte hoja: menos cambios de textura al ordenar por profundidad).
Uso: python3 tools/iso/iso_atlas.py /tmp/iso_sprites art/iso"""
import json, os, re, sys
import numpy as np
from PIL import Image
from scipy import ndimage

SHEET = 4096
PAD = 4
# orden de categorías: lo primero que sale en pantalla en una partida normal va en la primera hoja
CATS = ["roble", "pino", "palma", "seco", "nieve", "otono", "retono", "roca", "oro", "piedra", "bayas", "pez", "montana",
        "muralla", "puerta", "granja", "andamio", "casa", "centro", "almacen", "cuartel", "arqueria", "establo", "taller", "puerto",
        "torre", "monasterio", "herreria", "mercado", "mina", "castillo",
        "aldeano", "piquero", "espadachin", "arquero", "alabardero", "ballestero", "hostigador", "monje", "hachero", "arquero_largo",
        "teutonico", "berserker", "jinete", "explorador", "caballero", "arquero_caballo", "conquistador", "catafracta", "mameluco", "mangudai",
        "ariete", "catapulta", "trabuquete", "ciervo", "jabali", "barco_pesca", "barco_transporte", "galera", "galeon"]

# direcciones de unidad que se hornean (las demás son espejos en el juego, ver IsoView.MIRROR)
UNIT_DIR = re.compile(r"^[a-z_]+_([0-7])_[a-z0-9]+(_sh|_m)?$")
BAKED_DIRS = {"1", "2", "3", "4", "5"}
UNIT_CATS = set(CATS[CATS.index("aldeano"):CATS.index("ariete")])
ICON = 96
HIT_CELL = 4          # lado (px de sprite) de las celdas de la máscara de toque de los edificios
HIT_CATS = set(CATS[CATS.index("casa"):CATS.index("aldeano")])

def skip(name):
    m = UNIT_DIR.match(name)
    if not m:
        return False
    base = name.split("_%s_" % m.group(1))[0]
    return base in UNIT_CATS and m.group(1) not in BAKED_DIRS

def make_icons(src, dst):
    """Iconos de menú de 96x96 (sprite encajado con margen) + máscara de equipo: unidades de cara a la cámara y edificios."""
    from PIL import Image as I
    targets = {}
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png") or f.endswith("_m.png") or f.endswith("_sh.png"):
            continue
        n = f[:-4]
        m = re.match(r"^(.+)_1_idle$", n)
        if m:
            targets["ic_" + m.group(1)] = n
    for b in ["casa", "centro", "almacen", "cuartel", "arqueria", "establo", "taller", "torre", "monasterio", "castillo", "herreria", "mercado", "mina", "granja"]:
        if os.path.exists(os.path.join(src, b + ".png")):
            targets["ic_" + b] = b
    for k, v in (("muralla", "muralla_poste"), ("puerta", "puerta_x"), ("puerto", "puerto_2")):
        if os.path.exists(os.path.join(src, v + ".png")):
            targets["ic_" + k] = v
    names = sorted(targets)
    cols = 12
    rows = (len(names) + cols - 1) // cols
    sheet = I.new("RGBA", (cols * ICON, max(rows, 1) * ICON), (0, 0, 0, 0))
    msheet = I.new("L", (cols * ICON, max(rows, 1) * ICON), 0)
    rects = {}
    for i, n in enumerate(names):
        sp = I.open(os.path.join(src, targets[n] + ".png")).convert("RGBA")
        mp = os.path.join(src, targets[n] + "_m.png")
        mk = I.open(mp).convert("L") if os.path.exists(mp) else I.new("L", sp.size, 0)
        k = min((ICON - 8) / sp.width, (ICON - 8) / sp.height)
        w, h = max(1, round(sp.width * k)), max(1, round(sp.height * k))
        sp2 = sp.resize((w, h), I.LANCZOS)
        mk2 = mk.resize((w, h), I.LANCZOS)
        x, y = (i % cols) * ICON + (ICON - w) // 2, (i // cols) * ICON + (ICON - h) // 2
        sheet.paste(sp2, (x, y))
        msheet.paste(mk2, (x, y))
        rects[n] = [(i % cols) * ICON, (i // cols) * ICON, ICON, ICON]
    sheet.save(os.path.join(dst, "icons.png"), optimize=True)
    msheet.save(os.path.join(dst, "icons_m.png"), optimize=True)
    json.dump(rects, open(os.path.join(dst, "icons.json"), "w"))
    print("iconos:", len(rects))

def hit_mask(im):
    """Máscara de toque: una celda de HIT_CELL x HIT_CELL px vale 1 si algún píxel es opaco. Devuelve [ancho, alto, hex]
    (filas de bits, de izquierda a derecha en el bit más alto, rellenas hasta un byte)."""
    h, w = im.shape[:2]
    cw, ch = (w + HIT_CELL - 1) // HIT_CELL, (h + HIT_CELL - 1) // HIT_CELL
    a = np.zeros((ch * HIT_CELL, cw * HIT_CELL), np.uint8)
    a[:h, :w] = im[..., 3]
    cells = (a.reshape(ch, HIT_CELL, cw, HIT_CELL).max(axis=(1, 3)) > 40)
    rowb = (cw + 7) // 8
    out = bytearray()
    for r in range(ch):
        row = np.zeros(rowb * 8, np.uint8)
        row[:cw] = cells[r]
        out += np.packbits(row).tobytes()
    return [cw, ch, out.hex()]

def cat_of(name):
    base = name[:-3] if name.endswith("_sh") else name
    best = len(CATS)
    for i, c in enumerate(CATS):
        if base == c or base.startswith(c + "_"):
            best = min(best, i) if i < best else best
            break
    return best

def bleed(page):
    """Extiende el RGB de los píxeles opacos a los transparentes vecinos (relleno por el más cercano)."""
    a = page[..., 3]
    solid = a > 0
    if solid.all() or not solid.any():
        return page
    idx = ndimage.distance_transform_edt(~solid, return_distances=False, return_indices=True)
    out = page.copy()
    out[..., :3] = page[idx[0], idx[1], :3]
    out[..., 3] = a
    return out

class MaxRects:
    """Empaquetado MaxRects (mejor ajuste por lado corto) de una hoja SHEET x SHEET."""
    def __init__(self, w, h):
        self.free = [(0, 0, w, h)]

    def place(self, w, h):
        best = None
        for (fx, fy, fw, fh) in self.free:
            if w <= fw and h <= fh:
                score = (fy + h, fx)
                if best is None or score < best[0]:
                    best = (score, fx, fy)
        if best is None:
            return None
        _, x, y = best
        new = []
        for (fx, fy, fw, fh) in self.free:
            if x >= fx + fw or x + w <= fx or y >= fy + fh or y + h <= fy:
                new.append((fx, fy, fw, fh))
                continue
            if x > fx:
                new.append((fx, fy, x - fx, fh))
            if x + w < fx + fw:
                new.append((x + w, fy, fx + fw - (x + w), fh))
            if y > fy:
                new.append((fx, fy, fw, y - fy))
            if y + h < fy + fh:
                new.append((fx, y + h, fw, fy + fh - (y + h)))
        # quita los rectángulos contenidos en otro
        pruned = []
        for i, r in enumerate(new):
            contained = False
            for j, q in enumerate(new):
                if i != j and q[0] <= r[0] and q[1] <= r[1] and q[0] + q[2] >= r[0] + r[2] and q[1] + q[3] >= r[1] + r[3] and (q != r or j < i):
                    contained = True
                    break
            if not contained:
                pruned.append(r)
        self.free = pruned
        return x, y

def main():
    src, dst = sys.argv[1], sys.argv[2]
    anchors = json.load(open(os.path.join(src, "anchors.json")))
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(dst):
        if (f.startswith("atlas_") or f.startswith("mask_")) and f.endswith(".png"):
            os.remove(os.path.join(dst, f))
    names = sorted([n for n in anchors if not skip(n)], key=lambda n: (cat_of(n), -anchors[n][3], n))
    pages = [(np.zeros((SHEET, SHEET, 4), np.uint8), np.zeros((SHEET, SHEET), np.uint8))]
    packers = [MaxRects(SHEET, SHEET)]
    placed = {}
    hits = {}
    for n in names:
        im = np.asarray(Image.open(os.path.join(src, n + ".png")).convert("RGBA"))
        h, w = im.shape[:2]
        mp = os.path.join(src, n + "_m.png")
        mk = np.asarray(Image.open(mp).convert("L")) if os.path.exists(mp) else None
        pos = packers[-1].place(w + PAD, h + PAD)
        if pos is None:
            pages.append((np.zeros((SHEET, SHEET, 4), np.uint8), np.zeros((SHEET, SHEET), np.uint8)))
            packers.append(MaxRects(SHEET, SHEET))
            pos = packers[-1].place(w + PAD, h + PAD)
        x, y = pos
        px, py = x + PAD // 2, y + PAD // 2
        pages[-1][0][py:py + h, px:px + w] = im
        if mk is not None:
            pages[-1][1][py:py + h, px:px + w] = mk
        a = anchors[n]
        placed[n] = [len(pages) - 1, px, py, w, h, a[0], a[1]]
        if not n.endswith("_sh") and n.split("_")[0] in HIT_CATS:
            hits[n] = hit_mask(im)
    sheets = []
    for i, (col, mk) in enumerate(pages):
        # recorta el alto sobrante de la hoja (la textura no tiene por qué ser cuadrada)
        used = int(np.where(col[..., 3].any(axis=1))[0].max()) + 1 + PAD
        hh = min(SHEET, used)
        col = bleed(col[:hh])
        Image.fromarray(col, "RGBA").save(os.path.join(dst, "atlas_%d.png" % i), optimize=True)
        Image.fromarray(mk[:hh], "L").save(os.path.join(dst, "mask_%d.png" % i), optimize=True)
        sheets.append(["atlas_%d.png" % i, "mask_%d.png" % i])
        print("hoja %d: %dx%d" % (i, SHEET, hh))
    json.dump({"sheets": sheets, "sprites": placed, "hit": hits}, open(os.path.join(dst, "atlas.json"), "w"))
    make_icons(src, dst)
    tot = sum(os.path.getsize(os.path.join(dst, f)) for s in sheets for f in s)
    print("sprites:", len(placed), "hojas:", len(sheets), "peso PNG: %.2f MB" % (tot / 1e6))

if __name__ == "__main__":
    main()
