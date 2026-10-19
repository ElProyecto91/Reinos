#!/usr/bin/env python3
"""Imagen comparativa de varias civilizaciones: una fila por civilización con casa, centro, cuartel, monasterio, torre y castillo.
Uso: python3 tools/iso/civ_compare.py <carpeta_con_subcarpetas_por_civ> <salida.png> [civ1,civ2,...] [equipo=azul|rojo] [zoom=0.5]
La carpeta de entrada contiene <civ>/anchors.json y los sprites que escribe tools/iso/civ_preview.sh (/tmp/civ_spr)."""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from civ_sheet import TEAMS, GRASS, tint

KINDS = ["casa", "centro", "cuartel", "monasterio", "torre", "castillo"]

def main():
    root, out = sys.argv[1], sys.argv[2]
    civs = None
    team = TEAMS["azul"]
    zoom = 0.5
    for a in sys.argv[3:]:
        if a.startswith("equipo="): team = TEAMS[a[7:]]
        elif a.startswith("zoom="): zoom = float(a[5:])
        else: civs = a.split(",")
    if civs is None:
        civs = sorted(d for d in os.listdir(root) if os.path.exists(os.path.join(root, d, "anchors.json")))
    cw, ch, ox, oy = 560, 520, 280, 400
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
    sheet = Image.new("RGBA", (cw * len(KINDS), ch * len(civs)), GRASS)
    d = ImageDraw.Draw(sheet)
    for r, civ in enumerate(civs):
        src = os.path.join(root, civ)
        anchors = json.load(open(os.path.join(src, "anchors.json")))
        d.text((8, r * ch + 6), civ.upper(), fill=(255, 255, 255, 255), font=font)
        for c, kind in enumerate(KINDS):
            n = "%s__%s" % (civ, kind)
            if n not in anchors:
                continue
            cx, cy = c * cw + ox, r * ch + oy
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
    if zoom != 1.0:
        sheet = sheet.resize((int(sheet.width * zoom), int(sheet.height * zoom)), Image.LANCZOS)
    sheet.convert("RGB").save(out)
    print("comparativa:", out, sheet.size)

if __name__ == "__main__":
    main()
