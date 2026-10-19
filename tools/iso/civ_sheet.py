#!/usr/bin/env python3
"""Hoja de contacto de los edificios de una civilización (para revisar el aspecto sin pasar por el atlas).
Uso: python3 tools/iso/civ_sheet.py <carpeta_sprites> <civ> <salida.png> [equipo=azul|rojo] [zoom=1.0]
Pinta cada sprite con su sombra sobre hierba, con el color de equipo aplicado por la máscara."""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np

TEAMS = {"azul": (0.28, 0.52, 0.98), "rojo": (0.92, 0.25, 0.22), "verde": (0.30, 0.78, 0.30), "amarillo": (0.95, 0.80, 0.20)}
GRASS = (92, 134, 66, 255)

def tint(im, mk, team):
    a = np.asarray(im.convert("RGBA"), np.float32) / 255.0
    m = np.asarray(mk.convert("RGB"), np.float32)[..., 0:1] / 255.0
    k = np.array(team, np.float32) * 1.3333
    rgb = a[..., :3] * (1.0 - m + m * k)
    out = np.concatenate([np.clip(rgb, 0, 1), a[..., 3:4]], axis=-1)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")

def main():
    src, civ, out = sys.argv[1], sys.argv[2], sys.argv[3]
    team = TEAMS["azul"]
    zoom = 1.0
    for a in sys.argv[4:]:
        if a.startswith("equipo="): team = TEAMS[a[7:]]
        if a.startswith("zoom="): zoom = float(a[5:])
    anchors = json.load(open(os.path.join(src, "anchors.json")))
    names = [n for n in sorted(anchors) if n.startswith(civ + "__") and not n.endswith("_sh")]
    big = [n for n in names if n.endswith("castillo")]
    walls = [n for n in names if "muralla" in n or "puerta" in n]
    main = [n for n in names if n not in big and n not in walls]
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
    except Exception:
        font = ImageFont.load_default()

    def render(group, cols, cw, ch, ox, oy):
        rows = (len(group) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * cw, rows * ch), GRASS)
        d = ImageDraw.Draw(sheet)
        for i, n in enumerate(group):
            cx, cy = (i % cols) * cw + ox, (i // cols) * ch + oy
            sh = n + "_sh"
            if sh in anchors:
                s = Image.open(os.path.join(src, sh + ".png")).convert("RGBA")
                a = anchors[sh]
                sheet.alpha_composite(s, (int(cx - a[0]), int(cy - a[1])))
            im = Image.open(os.path.join(src, n + ".png")).convert("RGBA")
            mp = os.path.join(src, n + "_m.png")
            if os.path.exists(mp):
                im = tint(im, Image.open(mp), team)
            a = anchors[n]
            sheet.alpha_composite(im, (int(cx - a[0]), int(cy - a[1])))
            d.text(((i % cols) * cw + 6, (i // cols) * ch + 4), n.split("__")[1], fill=(255, 255, 255, 255), font=font)
        if zoom != 1.0:
            sheet = sheet.resize((int(sheet.width * zoom), int(sheet.height * zoom)), Image.LANCZOS)
        return sheet

    parts = []
    if main:
        parts.append(render(main, 4, 520, 470, 270, 350))
    if big:
        parts.append(render(big, 1, 1000, 760, 330, 450))
    if walls:
        parts.append(render(walls, 7, 240, 230, 110, 190))
    w = max(p.width for p in parts)
    h = sum(p.height for p in parts)
    sheet = Image.new("RGBA", (w, h), GRASS)
    y = 0
    for p in parts:
        sheet.alpha_composite(p, (0, y))
        y += p.height
    sheet.convert("RGB").save(out)
    print("hoja:", out, sheet.size)

if __name__ == "__main__":
    main()
