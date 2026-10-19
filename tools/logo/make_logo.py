#!/usr/bin/env python3
"""Genera el logo de Reinos (emblema heráldico + rótulo) y todos los iconos de la app.

Uso:  python3 tools/logo/make_logo.py [salida_previa_dir]

Sale a:  art/icon/*.png (lanzador de Android), icon.png (proyecto), art/logo/*.png (menú y fuentes)
Necesita: Chromium con Playwright y la fuente Lora (SIL OFL: libre también para logotipos).
El emblema es SVG dibujado a mano aquí mismo (sin plantillas ni imágenes externas).
"""
import os, sys
from playwright.sync_api import sync_playwright

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# ---- paleta -----------------------------------------------------------------------------------------------------
GOLD = ["#fff3b8", "#f7d467", "#e0a92e", "#b97c19", "#8a5a10", "#d9a233", "#f6d675"]   # degradado metálico (arriba -> abajo)
BLUE_L, BLUE_R = "#2457b3", "#173f86"       # mitades del campo del escudo
BLUE_DEEP = "#0a1f48"
CRIMSON = "#c8283a"
IVORY = "#fff7dc"

# ---- escudo heráldico (con base en V suave) -----------------------------------------------------------------------
# caja 600 x 700 centrada en x=512; arriba y=262, punta y=962 antes de escalar
SHIELD = "M212 262 H812 V560 C812 742 680 874 512 962 C344 874 212 742 212 560 Z"


def gold_grad(gid, x1=0, y1=0, x2=0, y2=1):
    stops = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in zip([0, .22, .45, .68, .84, .93, 1], GOLD))
    return f'<linearGradient id="{gid}" x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}">{stops}</linearGradient>'


def crown(fill):
    """Corona de cinco puntas con bolas en las puntas y tres gemas en la banda."""
    pts = "M316 262 L316 152 L376 206 L418 118 L466 206 L512 76 L558 206 L606 118 L648 206 L708 152 L708 262 Z"
    tips = "".join(f'<circle cx="{x}" cy="{y}" r="15" fill="{fill}"/>' for x, y in [(316, 146), (418, 110), (512, 66), (606, 110), (708, 146)])
    band = f'<rect x="304" y="228" width="416" height="58" rx="14" fill="{fill}"/>'
    return f'<path d="{pts}" fill="{fill}" stroke-linejoin="round"/>{tips}{band}'


def castle(fill, cut):
    """Castillo plano de tres torres con puerta, saeteras y pendón. `cut` = color de los huecos."""
    parts = []
    # muralla y torres laterales
    parts.append(f'<rect x="410" y="700" width="204" height="190" fill="{fill}"/>')
    for x0 in (344, 608):
        parts.append(f'<rect x="{x0}" y="612" width="72" height="278" fill="{fill}"/>')
        for i in range(3):
            parts.append(f'<rect x="{x0 + i * 26}" y="586" width="20" height="30" fill="{fill}"/>')
    # torre del homenaje
    parts.append(f'<rect x="452" y="500" width="120" height="390" fill="{fill}"/>')
    for i in range(4):
        parts.append(f'<rect x="{452 + i * 33.4:.1f}" y="470" width="20" height="34" fill="{fill}"/>')
    parts.append(f'<rect x="452" y="560" width="120" height="6" fill="{cut}" opacity=".4"/>')
    parts.append(f'<rect x="344" y="660" width="72" height="5" fill="{cut}" opacity=".4"/><rect x="608" y="660" width="72" height="5" fill="{cut}" opacity=".4"/>')
    # puerta con arco y rastrillo
    parts.append(f'<path d="M482 890 V776 A30 30 0 0 1 542 776 V890 Z" fill="{cut}"/>')
    for x in (494, 512, 530):
        parts.append(f'<rect x="{x - 1.5}" y="776" width="3" height="114" fill="{fill}" opacity=".5"/>')
    # saeteras
    for x, y in ((376, 656), (640, 656), (500, 530), (516, 530)):
        parts.append(f'<rect x="{x}" y="{y}" width="8" height="38" rx="3" fill="{cut}"/>')
    # pendón
    parts.append(f'<rect x="509" y="372" width="6" height="100" fill="{fill}"/>')
    return "".join(parts)


def pennant():
    return f'<path d="M515 380 L596 402 L515 426 Z" fill="{CRIMSON}"/><path d="M515 380 L596 402 L515 392 Z" fill="#e8505f" opacity=".85"/>'


def emblem_defs():
    return f"""
    {gold_grad("g")}
    {gold_grad("gd", 0, 0, 1, 1)}
    <linearGradient id="bl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{BLUE_L}"/><stop offset="1" stop-color="#112f6b"/></linearGradient>
    <linearGradient id="br" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{BLUE_R}"/><stop offset="1" stop-color="#0c2556"/></linearGradient>
    <radialGradient id="glow" cx=".5" cy=".28" r=".7"><stop offset="0" stop-color="#7fb0ff" stop-opacity=".55"/><stop offset="1" stop-color="#7fb0ff" stop-opacity="0"/></radialGradient>
    <clipPath id="field"><path d="{SHIELD}" transform="translate(512 612) scale(.885 .89) translate(-512 -612)"/></clipPath>
    <filter id="sh" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="16" stdDeviation="14" flood-color="#000" flood-opacity=".5"/></filter>
    <filter id="soft" x="-10%" y="-10%" width="120%" height="120%"><feDropShadow dx="0" dy="5" stdDeviation="5" flood-color="#000" flood-opacity=".45"/></filter>
    """


def emblem(shadow=True):
    """El emblema completo en un lienzo de 1024 x 1024 (corona arriba, punta del escudo abajo)."""
    sc = 'transform="translate(512 612) scale(.885 .89) translate(-512 -612)"'
    sc2 = 'transform="translate(512 612) scale(.80 .81) translate(-512 -612)"'
    body = f"""
    <g {'filter="url(#sh)"' if shadow else ''}>
      <!-- marco dorado: contorno oscuro, oro y reborde interior -->
      <path d="{SHIELD}" fill="#3a2406" stroke="#3a2406" stroke-width="14" stroke-linejoin="round"/>
      <path d="{SHIELD}" fill="url(#gd)"/>
      <path d="{SHIELD}" fill="none" stroke="#fff3b8" stroke-opacity=".55" stroke-width="3" transform="translate(512 612) scale(.985 .985) translate(-512 -612)"/>
      <!-- campo: dos mitades azules (partido) con brillo suave -->
      <path d="{SHIELD}" fill="#06143a" transform="translate(512 612) scale(.895 .9) translate(-512 -612)"/>
      <g clip-path="url(#field)">
        <rect x="200" y="240" width="312" height="740" fill="url(#bl)"/>
        <rect x="512" y="240" width="320" height="740" fill="url(#br)"/>
        <rect x="200" y="240" width="640" height="740" fill="url(#glow)"/>
        <path d="M512 240 V980" stroke="#0a1f48" stroke-opacity=".35" stroke-width="3"/>
      </g>
      <path d="{SHIELD}" fill="none" stroke="#06143a" stroke-width="5" {sc}/>
      <path d="{SHIELD}" fill="none" stroke="url(#gd)" stroke-width="3.5" stroke-opacity=".8" {sc2}/>
      <!-- castillo -->
      <g filter="url(#soft)" clip-path="url(#field)">
        {castle("url(#g)", BLUE_DEEP)}
        {pennant()}
      </g>
    </g>
    <!-- corona -->
    <g filter="url(#soft)">
      <g stroke="#3a2406" stroke-width="16" stroke-linejoin="round">{crown("#3a2406")}</g>
      <g>{crown("url(#g)")}</g>
      <circle cx="512" cy="257" r="17" fill="{CRIMSON}" stroke="#3a2406" stroke-width="4"/>
      <circle cx="404" cy="257" r="12" fill="#2f7be0" stroke="#3a2406" stroke-width="4"/>
      <circle cx="620" cy="257" r="12" fill="#2f7be0" stroke="#3a2406" stroke-width="4"/>
      <circle cx="507" cy="251" r="5" fill="#fff" opacity=".6"/>
      <path d="M318 236 H706" stroke="#fff3b8" stroke-opacity=".6" stroke-width="3"/>
    </g>
    """
    return body


def emblem_mono():
    """Silueta de una sola tinta para los iconos temáticos de Android 13+: escudo + corona, castillo calado."""
    sc = 'transform="translate(512 612) scale(.885 .89) translate(-512 -612)"'
    return f"""
    <mask id="m"><rect width="1024" height="1024" fill="#fff"/>{castle("#000", "#fff")}<path d="M515 380 L596 402 L515 426 Z" fill="#000"/>
      <path d="{SHIELD}" fill="none" stroke="#000" stroke-width="10" {sc}/></mask>
    <g mask="url(#m)"><path d="{SHIELD}" fill="#fff" stroke="#fff" stroke-width="14" stroke-linejoin="round"/></g>
    <g>{crown("#fff")}</g>
    """


def svg(w, h, view, inner, defs=""):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{view}"><defs>{emblem_defs()}{defs}</defs>{inner}</svg>'


# ---- páginas HTML que Chromium convierte en PNG --------------------------------------------------------------------
def page(body, w, h, bg="transparent"):
    return f"""<html><head><style>html,body{{margin:0;padding:0;background:{bg};width:{w}px;height:{h}px;overflow:hidden}}
    .wm{{font:700 128px 'Lora',serif;letter-spacing:.10em;}}</style></head><body>{body}</body></html>"""


def icon_bg_parts():
    """(defs, cuerpo) del fondo del icono: azul noche con halo cálido tras el escudo y rayos muy tenues (lienzo 1024)."""
    import math
    rays = "".join(f'<path d="M512 560 L{512 + 900 * math.cos(a):.0f} {560 + 900 * math.sin(a):.0f} L{512 + 900 * math.cos(a + .09):.0f} {560 + 900 * math.sin(a + .09):.0f} Z" fill="#ffffff" opacity=".045"/>'
                   for a in [i * 0.2618 for i in range(24)])
    defs = ('<radialGradient id="bg" cx=".5" cy=".5" r=".75"><stop offset="0" stop-color="#2b5db8"/><stop offset=".55" stop-color="#14346f"/><stop offset="1" stop-color="#081634"/></radialGradient>'
            '<radialGradient id="warm" cx=".5" cy=".56" r=".42"><stop offset="0" stop-color="#ffcf6a" stop-opacity=".38"/><stop offset="1" stop-color="#ffcf6a" stop-opacity="0"/></radialGradient>')
    body = f'<rect width="1024" height="1024" fill="url(#bg)"/>{rays}<rect width="1024" height="1024" fill="url(#warm)"/>'
    return defs, body


def icon_bg(size):
    d, b = icon_bg_parts()
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 1024 1024"><defs>{d}</defs>{b}</svg>'


def render(pg, html, out, w, h):
    pg.set_viewport_size({"width": w, "height": h})
    pg.set_content(html)
    pg.wait_for_timeout(350)
    pg.screenshot(path=out, omit_background=True, clip={"x": 0, "y": 0, "width": w, "height": h})


def fit_emblem(scale, cx=216, cy=216, dy=0):
    """Emblema (1024 de lienzo, centro visual ~ (512,520)) escalado y centrado en un lienzo de 432."""
    return f'<g transform="translate({cx} {cy + dy}) scale({scale}) translate(-512 -520)">'


def main():
    prev = sys.argv[1] if len(sys.argv) > 1 else "/tmp/logo_out"
    os.makedirs(prev, exist_ok=True)
    os.makedirs(os.path.join(ROOT, "art", "logo"), exist_ok=True)
    A = os.path.join(ROOT, "art", "icon")
    L = os.path.join(ROOT, "art", "logo")
    with sync_playwright() as p:
        b = p.chromium.launch()
        pg = b.new_page()

        # 1) emblema suelto, 1024, fondo transparente (para otros usos)
        render(pg, page(svg(1024, 1024, "0 0 1024 1024", emblem()), 1024, 1024), os.path.join(L, "emblema_1024.png"), 1024, 1024)

        # 2) capas adaptativas de Android (432): primer plano dentro de la zona segura (círculo de 264 px), fondo, monocroma
        s = 0.272
        fg = svg(432, 432, "0 0 432 432", f"{fit_emblem(s, dy=4)}{emblem()}</g>")
        render(pg, page(fg, 432, 432), os.path.join(A, "ic_fg_432.png"), 432, 432)
        render(pg, page(icon_bg(432), 432, 432), os.path.join(A, "ic_bg_432.png"), 432, 432)
        mono = svg(432, 432, "0 0 432 432", f"{fit_emblem(0.285, dy=4)}{emblem_mono()}</g>")
        render(pg, page(mono, 432, 432), os.path.join(A, "ic_mono_432.png"), 432, 432)

        # 3) icono clásico (192) y del proyecto (512): fondo + emblema más grande, con esquinas redondeadas
        def full_icon(size, sc, rounded=True):
            r = size * 0.22 if rounded else 0
            bd, bb = icon_bg_parts()
            return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}"><defs>{emblem_defs()}{bd}'
                    f'<clipPath id="rr"><rect width="{size}" height="{size}" rx="{r}"/></clipPath></defs>'
                    f'<g clip-path="url(#rr)"><g transform="scale({size / 1024})">{bb}</g>'
                    f'<g transform="translate({size / 2} {size * 0.515}) scale({sc * size / 1024}) translate(-512 -520)">{emblem()}</g></g></svg>')
        render(pg, page(full_icon(192, 1.02), 192, 192), os.path.join(A, "ic_main_192.png"), 192, 192)
        render(pg, page(full_icon(512, 1.02), 512, 512), os.path.join(ROOT, "icon.png"), 512, 512)
        render(pg, page(full_icon(1024, 1.02, False), 1024, 1024), os.path.join(prev, "icon_1024_cuadrado.png"), 1024, 1024)

        # 4) logotipo horizontal para el menú: emblema + REINOS + filete + lema (se dibuja a 2x: 1240 x 280 = 620 x 140 lógicos)
        wm = f"""
        <div style="position:absolute;left:0;top:0;width:1240px;height:280px">
          <div style="position:absolute;left:0px;top:0px">{svg(286, 286, "0 0 1024 1024", emblem())}</div>
          <div style="position:absolute;left:300px;top:24px;width:920px">
            <div class="wm" style="font-size:150px;line-height:150px;background:linear-gradient(180deg,#fff3b8 0%,#f7d467 28%,#e0a92e 52%,#b97c19 74%,#f1c75a 100%);-webkit-background-clip:text;background-clip:text;color:transparent;filter:drop-shadow(0 4px 0 #3a2406) drop-shadow(0 0 2px #3a2406) drop-shadow(0 10px 10px rgba(0,0,0,.45));">REINOS</div>
            <div style="display:flex;align-items:center;gap:16px;margin-top:20px;width:880px">
              <div style="height:4px;flex:1;background:linear-gradient(90deg,transparent,#e0a92e 60%,#fff3b8)"></div>
              <div style="width:16px;height:16px;transform:rotate(45deg);background:#f7d467;box-shadow:0 0 0 3px #3a2406"></div>
              <div style="height:4px;flex:1;background:linear-gradient(270deg,transparent,#e0a92e 60%,#fff3b8)"></div>
            </div>
            <div style="font:700 36px 'Inter',sans-serif;letter-spacing:.34em;color:{IVORY};margin-top:16px;text-shadow:0 2px 6px rgba(0,0,0,.6)">ESTRATEGIA EN TIEMPO REAL</div>
          </div>
        </div>"""
        render(pg, page(wm, 1240, 280), os.path.join(L, "logotipo_menu.png"), 1240, 280)
        b.close()
    print("ok")


if __name__ == "__main__":
    main()
