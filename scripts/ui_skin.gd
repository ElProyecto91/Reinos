class_name UiSkin
extends RefCounted
## Piel de madera y pergamino de la interfaz. Las texturas (art/ui/*.png, hechas con tools/ui_skin/make_ui.py) están pintadas a 1,5 px
## por píxel virtual; aquí se dibujan a escala K: marcos en 9 trozos (esquinas fijas, lados repetidos) sobre un interior que se repite
## (madera oscura o pergamino). Todo son llamadas de dibujo de rectángulos con 8 texturas pequeñas: no hay sombreadores ni
## repetición de textura del motor, y la interfaz sigue sin dibujar nada mientras nada cambia.
## Si faltan las texturas, ready() es false y cada componente usa el estilo plano de siempre.

const K := 1.0 / 1.5

# colores de texto
const CREAM := Color(0.98, 0.94, 0.82)       # sobre madera
const CREAM_DIM := Color(0.86, 0.80, 0.66)
const GOLD := Color(1.0, 0.86, 0.45)
const INK := Color(0.17, 0.10, 0.05)         # sobre pergamino
const INK_2 := Color(0.33, 0.22, 0.11)
const INK_3 := Color(0.44, 0.33, 0.20)
const INK_GREEN := Color(0.09, 0.36, 0.13)
const INK_RED := Color(0.64, 0.09, 0.05)
const INK_BLUE := Color(0.09, 0.27, 0.50)
const EMBOSS := Color(1.0, 0.95, 0.78, 0.55) # reflejo claro bajo la tinta
const SHADOW := Color(0.0, 0.0, 0.0, 0.7)    # sombra bajo texto claro

static var _tex: Dictionary = {}
static var _ready_state := -1                # -1 sin comprobar · 0 no · 1 sí
static var _bold: Font = null

static func tex(n: String) -> Texture2D:
	if _tex.has(n):
		return _tex[n]
	var p := "res://art/ui/%s.png" % n
	var t: Texture2D = load(p) if ResourceLoader.exists(p) else null
	_tex[n] = t
	return t

static func ready() -> bool:
	if _ready_state < 0:
		var ok := true
		for n in ["bar", "wood_dark", "parch", "btn", "btn_down", "btn_on", "panel", "mm", "thin"]:
			if tex(n) == null:
				ok = false
		_ready_state = 1 if ok else 0
	return _ready_state == 1

## Tipografía en negrita para títulos y cifras (el peso normal es la fuente por defecto del proyecto).
static func bold() -> Font:
	if _bold == null:
		_bold = load("res://art/ui/font_bold.tres") if ResourceLoader.exists("res://art/ui/font_bold.tres") else ThemeDB.fallback_font
	return _bold

## Repite `t` (a escala K) por todo el rectángulo `r`.
static func tile(c: CanvasItem, t: Texture2D, r: Rect2, mod: Color = Color.WHITE) -> void:
	var tw := float(t.get_width()) * K
	var th := float(t.get_height()) * K
	var y := r.position.y
	while y < r.end.y - 0.01:
		var h := minf(th, r.end.y - y)
		var x := r.position.x
		while x < r.end.x - 0.01:
			var w := minf(tw, r.end.x - x)
			c.draw_texture_rect_region(t, Rect2(x, y, w, h), Rect2(0.0, 0.0, w / K, h / K), mod)
			x += tw
		y += th

## Marco en 9 trozos: `m` texels de borde. Esquinas a escala K; los lados se repiten (el marco está hecho con el periodo del lado).
## El centro no se dibuja: es hueco (sombra interior translúcida).
static func nine(c: CanvasItem, t: Texture2D, r: Rect2, m: float, mod: Color = Color.WHITE) -> void:
	var tw := float(t.get_width())
	var th := float(t.get_height())
	var mk := minf(m * K, minf(r.size.x, r.size.y) * 0.5)
	var cw := tw - 2.0 * m
	var ch := th - 2.0 * m
	var a := r.position
	var e := r.end
	c.draw_texture_rect_region(t, Rect2(a.x, a.y, mk, mk), Rect2(0.0, 0.0, m, m), mod)
	c.draw_texture_rect_region(t, Rect2(e.x - mk, a.y, mk, mk), Rect2(tw - m, 0.0, m, m), mod)
	c.draw_texture_rect_region(t, Rect2(a.x, e.y - mk, mk, mk), Rect2(0.0, th - m, m, m), mod)
	c.draw_texture_rect_region(t, Rect2(e.x - mk, e.y - mk, mk, mk), Rect2(tw - m, th - m, m, m), mod)
	var x := a.x + mk
	while x < e.x - mk - 0.01:
		var w := minf(cw * K, e.x - mk - x)
		c.draw_texture_rect_region(t, Rect2(x, a.y, w, mk), Rect2(m, 0.0, w / K, m), mod)
		c.draw_texture_rect_region(t, Rect2(x, e.y - mk, w, mk), Rect2(m, th - m, w / K, m), mod)
		x += cw * K
	var y := a.y + mk
	while y < e.y - mk - 0.01:
		var h := minf(ch * K, e.y - mk - y)
		c.draw_texture_rect_region(t, Rect2(a.x, y, mk, h), Rect2(0.0, m, m, h / K), mod)
		c.draw_texture_rect_region(t, Rect2(e.x - mk, y, mk, h), Rect2(tw - m, m, m, h / K), mod)
		y += ch * K

## Botón de madera: interior oscuro + marco biselado. Pulsado se hunde; activado lleva filete dorado y un velo del color de acento.
static func button(c: CanvasItem, r: Rect2, down: bool, on: bool, enabled: bool, veil: Color = Color(1.0, 0.78, 0.30)) -> void:
	var inner := Color.WHITE
	var frame := Color.WHITE
	if down:
		inner = Color(0.70, 0.66, 0.62)
	elif on:
		inner = Color(1.0, 0.90, 0.72)
	if not enabled:
		inner = Color(0.62, 0.60, 0.60)
		frame = Color(0.66, 0.64, 0.64)
	tile(c, tex("wood_dark"), r, inner)
	if on and not down and enabled:
		c.draw_rect(r.grow(-5.0), Color(veil.r, veil.g, veil.b, 0.26), true)
	nine(c, tex("btn_down" if down else ("btn_on" if on else "btn")), r, 16.0, frame)

## Panel de pergamino con marco de madera, filete dorado y remaches.
static func panel(c: CanvasItem, r: Rect2) -> void:
	if not ready():
		c.draw_style_box(UiButton.box(Color(0.90, 0.82, 0.62), Color(0.45, 0.30, 0.14), 8, 4), r)   # claro, para que la tinta se lea
		return
	tile(c, tex("parch"), r)
	nine(c, tex("panel"), r, 24.0)

## Marco fino con remaches sobre lo que haya dentro (minimapa, retratos).
static func inset(c: CanvasItem, r: Rect2) -> void:
	if not ready():
		c.draw_rect(r, Color(0.55, 0.43, 0.22), false, 3.0)
		return
	nine(c, tex("mm"), r, 16.0)

## Marco fino (retratos de la ficha de selección).
static func thin(c: CanvasItem, r: Rect2) -> void:
	if not ready():
		c.draw_rect(r, Color(0.45, 0.30, 0.14), false, 2.0)
		return
	nine(c, tex("thin"), r, 10.0)

## Franja de madera de la barra superior (84 texels de alto = 56 px virtuales) con una sombra suave debajo.
static func bar(c: CanvasItem, r: Rect2) -> void:
	if not ready():
		c.draw_rect(r, Color(0.10, 0.085, 0.07, 0.9), true)
		c.draw_line(Vector2(0, r.end.y - 1), Vector2(r.end.x, r.end.y - 1), Color(0.55, 0.43, 0.22, 0.95), 2.0)
		return
	tile(c, tex("bar"), r)
	c.draw_polygon(PackedVector2Array([Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.end.y + 9.0), Vector2(r.position.x, r.end.y + 9.0)]),
		PackedColorArray([Color(0, 0, 0, 0.38), Color(0, 0, 0, 0.38), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))

## Cajita hundida (donde van los números de recursos): fondo oscuro con filo de luz abajo.
static func slot(c: CanvasItem, r: Rect2) -> void:
	c.draw_style_box(UiButton.box(Color(0.06, 0.035, 0.02, 0.62), Color(0.03, 0.02, 0.01, 0.85), 8, 1), r)
	c.draw_line(Vector2(r.position.x + 7.0, r.end.y - 0.5), Vector2(r.end.x - 7.0, r.end.y - 0.5), Color(0.95, 0.75, 0.40, 0.30), 1.0)

## Texto con sombra (claro sobre madera) o con reflejo (tinta sobre pergamino). `sh` es el color de la sombra; `off` su desplazamiento.
static func text(c: CanvasItem, font: Font, pos: Vector2, s: String, align: int, w: float, fs: int, col: Color, sh: Color = SHADOW, off: Vector2 = Vector2(1.2, 1.6)) -> void:
	c.draw_string(font, pos + off, s, align, w, fs, Color(sh.r, sh.g, sh.b, sh.a * col.a))
	c.draw_string(font, pos, s, align, w, fs, col)

## Tinta sobre pergamino: la misma letra con un reflejo claro un píxel más abajo.
static func ink(c: CanvasItem, font: Font, pos: Vector2, s: String, align: int, w: float, fs: int, col: Color = INK) -> void:
	text(c, font, pos, s, align, w, fs, col, EMBOSS, Vector2(0.0, 1.0))
