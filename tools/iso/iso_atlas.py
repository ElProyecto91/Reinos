#!/usr/bin/env python3
"""Empaqueta los sprites isométricos (salida de iso_post.py) en hojas de atlas para el juego.
Escribe en <destino> (normalmente art/iso): atlas_N.png (RGBA, con el color de los bordes extendido a los píxeles
transparentes para que el filtrado bilineal no deje halos oscuros), mask_N.png (RGB, mismo reparto: R = parte que se
tiñe con el color del jugador, G = cristal de ventana que brilla de noche) y atlas.json ({"sheets": [[atlas, máscara], ...], "sprites": {nombre: [hoja, x, y, w, h, ox, oy]}}).
Las categorías van seguidas (lo que se dibuja junto comparte hoja: menos cambios de textura al ordenar por profundidad).
Los edificios de cada civilización (sprites «<civ>__<tipo>», ver tools/iso/iso_civs.gd) no van en el atlas global: cada civilización
tiene su paquete (atlas_<civ>_N.png, mask_<civ>_N.png y civ_<civ>.json, mismo formato que atlas.json) que el juego carga sólo
si alguien de la partida juega con ella (IsoArt.ensure_civ). Los edificios genéricos antiguos (sin «__») se descartan.
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
# edificios que ahora son propios de cada civilización: los sprites genéricos sin «<civ>__» ya no se usan
CIV_BASES = {"casa", "centro", "almacen", "cuartel", "arqueria", "establo", "taller", "puerto", "torre", "monasterio", "castillo",
             "herreria", "mercado", "muralla", "puerta"}
SHEET_CIV = 2048      # ancho de las hojas de los paquetes de civilización (alto máximo SHEET: caben en una sola hoja más estrecha)

def split_civ(name):
    """«francos__casa_sh» -> («francos», «casa_sh»); sin prefijo -> («», nombre)."""
    if "__" in name:
        c, b = name.split("__", 1)
        return c, b
    return "", name

def legacy(name):
    c, b = split_civ(name)
    return c == "" and b.split("_")[0] in CIV_BASES

def skip(name):
    if legacy(name):
        return True
    m = UNIT_DIR.match(name)
    if not m:
        return False
    base = name.split("_%s_" % m.group(1))[0]
    return base in UNIT_CATS and m.group(1) not in BAKED_DIRS

def make_icons(src, dst):
    """Iconos de menú de 96x96 (sprite encajado con margen) + máscara de equipo: unidades de cara a la cámara y edificios
    (los de cada civilización se llaman ic_<civ>__<tipo>)."""
    from PIL import Image as I
    targets = {}
    files = sorted(f[:-4] for f in os.listdir(src) if f.endswith(".png") and not f.endswith("_m.png") and not f.endswith("_sh.png"))
    present = set(files)
    for n in files:
        m = re.match(r"^(.+)_1_idle$", n)
        if m:
            targets["ic_" + m.group(1)] = n
    for b in ["mina", "granja"]:
        if b in present:
            targets["ic_" + b] = b
    civs = sorted({split_civ(n)[0] for n in files if split_civ(n)[0]})
    types = ["casa", "centro", "almacen", "cuartel", "arqueria", "establo", "taller", "torre", "monasterio", "castillo", "herreria", "mercado"]
    for c in civs:
        for b in types:
            if "%s__%s" % (c, b) in present:
                targets["ic_%s__%s" % (c, b)] = "%s__%s" % (c, b)
        for k, v in (("muralla", "muralla_poste"), ("puerta", "puerta_x"), ("puerto", "puerto_2")):
            if "%s__%s" % (c, v) in present:
                targets["ic_%s__%s" % (c, k)] = "%s__%s" % (c, v)
    names = sorted(targets)
    cols = 12
    rows = (len(names) + cols - 1) // cols
    sheet = I.new("RGBA", (cols * ICON, max(rows, 1) * ICON), (0, 0, 0, 0))
    msheet = I.new("L", (cols * ICON, max(rows, 1) * ICON), 0)
    rects = {}
    for i, n in enumerate(names):
        sp = I.open(os.path.join(src, targets[n] + ".png")).convert("RGBA")
        mp = os.path.join(src, targets[n] + "_m.png")
        mk = I.open(mp).convert("RGB").split()[0] if os.path.exists(mp) else I.new("L", sp.size, 0)   # canal R: sólo el equipo
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

def load_mask_rgb(path):
    """Máscara de un sprite como RGB (R equipo, G cristal): las antiguas, de un solo canal (L), sólo traen equipo."""
    im = Image.open(path)
    if im.mode == "L":
        a = np.asarray(im)
        return np.stack([a, np.zeros_like(a), np.zeros_like(a)], axis=-1)
    return np.asarray(im.convert("RGB"))

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
    base = split_civ(name)[1]
    base = base[:-3] if base.endswith("_sh") else base
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

def pack(src, anchors, names, tag, dst, sheet_size, sheet_h=None):
    """Empaqueta `names` en hojas de `sheet_size` y las escribe como atlas_<tag>_N.png / mask_<tag>_N.png (tag vacío: atlas_N.png).
    Devuelve ({"sheets", "sprites", "hit"}, bytes de PNG)."""
    sfx = (tag + "_") if tag else ""
    names = sorted(names, key=lambda n: (cat_of(n), -anchors[n][3], n))
    sheet_h = sheet_h or sheet_size
    pages = [(np.zeros((sheet_h, sheet_size, 4), np.uint8), np.zeros((sheet_h, sheet_size, 3), np.uint8))]
    packers = [MaxRects(sheet_size, sheet_h)]
    placed = {}
    hits = {}
    for n in names:
        im = np.asarray(Image.open(os.path.join(src, n + ".png")).convert("RGBA"))
        h, w = im.shape[:2]
        mp = os.path.join(src, n + "_m.png")
        mk = load_mask_rgb(mp) if os.path.exists(mp) else None
        pos = packers[-1].place(w + PAD, h + PAD)
        if pos is None:
            pages.append((np.zeros((sheet_h, sheet_size, 4), np.uint8), np.zeros((sheet_h, sheet_size, 3), np.uint8)))
            packers.append(MaxRects(sheet_size, sheet_h))
            pos = packers[-1].place(w + PAD, h + PAD)
            if pos is None:
                raise SystemExit("el sprite %s (%dx%d) no cabe en una hoja de %d" % (n, w, h, sheet_size))
        x, y = pos
        px, py = x + PAD // 2, y + PAD // 2
        pages[-1][0][py:py + h, px:px + w] = im
        if mk is not None:
            pages[-1][1][py:py + h, px:px + w] = mk
        a = anchors[n]
        placed[n] = [len(pages) - 1, px, py, w, h, a[0], a[1]]
        if not n.endswith("_sh") and split_civ(n)[1].split("_")[0] in HIT_CATS:
            hits[n] = hit_mask(im)
    sheets = []
    total = 0
    for i, (col, mk) in enumerate(pages):
        # recorta el alto sobrante de la hoja (la textura no tiene por qué ser cuadrada)
        used = int(np.where(col[..., 3].any(axis=1))[0].max()) + 1 + PAD
        hh = min(sheet_h, used)
        col = bleed(col[:hh])
        fa, fm = "atlas_%s%d.png" % (sfx, i), "mask_%s%d.png" % (sfx, i)
        Image.fromarray(col, "RGBA").save(os.path.join(dst, fa), optimize=True)
        Image.fromarray(mk[:hh], "RGB").save(os.path.join(dst, fm), optimize=True)
        sheets.append([fa, fm])
        total += os.path.getsize(os.path.join(dst, fa)) + os.path.getsize(os.path.join(dst, fm))
        print("  hoja %s%d: %dx%d" % (sfx, i, sheet_size, hh))
    return {"sheets": sheets, "sprites": placed, "hit": hits}, total

def main():
    src, dst = sys.argv[1], sys.argv[2]
    anchors = json.load(open(os.path.join(src, "anchors.json")))
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(dst):
        if ((f.startswith("atlas_") or f.startswith("mask_")) and f.endswith(".png")) or (f.startswith("civ_") and f.endswith(".json") and not f.endswith("_meta.json")):
            os.remove(os.path.join(dst, f))
    dropped = [n for n in anchors if legacy(n)]
    if dropped:
        print("descartados %d sprites de edificios genéricos antiguos (ahora son por civilización)" % len(dropped))
    keep = [n for n in anchors if not skip(n)]
    glob = [n for n in keep if split_civ(n)[0] == ""]
    by_civ = {}
    for n in keep:
        c = split_civ(n)[0]
        if c:
            by_civ.setdefault(c, []).append(n)
    print("paquete global:")
    gdata, gbytes = pack(src, anchors, glob, "", dst, SHEET)
    json.dump({"sheets": gdata["sheets"], "sprites": gdata["sprites"], "hit": gdata["hit"]}, open(os.path.join(dst, "atlas.json"), "w"))
    print("global: %d sprites, %d hojas, %.2f MB" % (len(gdata["sprites"]), len(gdata["sheets"]), gbytes / 1e6))
    for civ in sorted(by_civ):
        names = by_civ[civ]
        print("paquete %s (%d sprites):" % (civ, len(names)))
        cdata, cbytes = pack(src, anchors, names, civ, dst, SHEET_CIV, SHEET)
        json.dump(cdata, open(os.path.join(dst, "civ_%s.json" % civ), "w"))
        print("  %s: %d sprites, %d hojas, %.2f MB PNG" % (civ, len(cdata["sprites"]), len(cdata["sheets"]), cbytes / 1e6))
    make_icons(src, dst)

if __name__ == "__main__":
    main()
