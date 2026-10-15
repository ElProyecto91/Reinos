class_name ArtBuildings
extends RefCounted
## Edificios a escala de aldea: paredes de piedra y entramado, tejados con tejas, chimeneas,
## patio, sombras y objetos (barriles, heno, dianas). Todo se pinta por código a doble resolución
## (SS) para que se vea nítido al acercar. Cada edificio tiene una capa neutra y otra de equipo
## (estandartes y adornos con el color del jugador).

const SS := 2
const INK := Color(0.10, 0.07, 0.05, 0.92)

class Cv extends RefCounted:
	var img: Image
	var s: float
	func _init(i: Image, sc: float) -> void:
		img = i
		s = sc
	func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
		Painter.rect(img, x * s, y * s, w * s, h * s, c)
	func ell(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
		Painter.ellipse(img, cx * s, cy * s, rx * s, ry * s, c)
	func disc(cx: float, cy: float, r: float, c: Color) -> void:
		Painter.disc(img, cx * s, cy * s, r * s, c)
	func tri(ax: float, ay: float, bx: float, by: float, cx: float, cy: float, c: Color) -> void:
		Painter.tri(img, ax * s, ay * s, bx * s, by * s, cx * s, cy * s, c)
	func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
		Painter.quad(img, a * s, b * s, c * s, d * s, col)
	func line(x0: float, y0: float, x1: float, y1: float, w: float, c: Color) -> void:
		Painter.line(img, x0 * s, y0 * s, x1 * s, y1 * s, w * s, c)

static func sh(c: Color, f: float) -> Color:
	return Painter.shade(c, f)

# ---------------------------------------------------------------- materiales

## Muro de sillares: hileras con piedras de tono variable y juntas oscuras.
static func stone(cv: Cv, x: float, y: float, w: float, h: float, base: Color, seed_v: int, row_h: float = 5.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	cv.rect(x, y, w, h, sh(base, 0.55))
	var yy := y
	var row := 0
	while yy < y + h - 0.5:
		var rh := minf(row_h, y + h - yy)
		var xx := x - (0.0 if row % 2 == 0 else rng.randf_range(2.0, 5.0))
		while xx < x + w:
			var bw := rng.randf_range(6.0, 11.0)
			var x0 := maxf(xx, x)
			var x1 := minf(xx + bw, x + w)
			if x1 - x0 > 0.6:
				var tone := rng.randf_range(0.90, 1.10)
				cv.rect(x0 + 0.4, yy + 0.4, x1 - x0 - 0.8, rh - 0.8, sh(base, tone))
				cv.rect(x0 + 0.4, yy + 0.4, x1 - x0 - 0.8, 0.9, sh(base, tone * 1.18))   # luz arriba
			xx += bw
		yy += rh
		row += 1

## Entramado de madera sobre revoco.
static func timber(cv: Cv, x: float, y: float, w: float, h: float, plaster: Color, wood: Color, seed_v: int, panels: int = 3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	cv.rect(x, y, w, h, plaster)
	for i in int(w * h / 14.0):
		cv.rect(x + rng.randf() * w, y + rng.randf() * h, rng.randf_range(0.8, 2.0), 0.7, sh(plaster, rng.randf_range(0.90, 1.05)))
	var pw := w / float(panels)
	for i in range(panels):
		var px := x + i * pw
		# arriostramiento en diagonal en algunos paneles
		if (i + seed_v) % 2 == 0:
			cv.line(px + 1.0, y + h - 1.0, px + pw - 1.0, y + 1.0, 1.6, wood)
		else:
			cv.line(px + 1.0, y + 1.0, px + pw - 1.0, y + h - 1.0, 1.6, wood)
	for i in range(panels + 1):
		cv.rect(x + i * pw - 0.9, y, 1.8, h, wood)
	cv.rect(x, y, w, 1.8, wood)
	cv.rect(x, y + h - 1.8, w, 1.8, wood)
	cv.rect(x, y + h * 0.5 - 0.7, w, 1.4, sh(wood, 0.9))

## Tablones de madera (verticales u horizontales).
static func planks(cv: Cv, x: float, y: float, w: float, h: float, base: Color, seed_v: int, vertical: bool = true) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	cv.rect(x, y, w, h, sh(base, 0.6))
	var n := int((w if vertical else h) / 3.6)
	var step := (w if vertical else h) / float(maxi(n, 1))
	for i in n:
		var tone := rng.randf_range(0.88, 1.10)
		if vertical:
			cv.rect(x + i * step + 0.3, y, step - 0.6, h, sh(base, tone))
			cv.rect(x + i * step + 0.3, y, 0.8, h, sh(base, tone * 1.15))
			if rng.randf() < 0.5:
				cv.rect(x + i * step + 1.0, y + rng.randf() * h * 0.8, 0.7, rng.randf_range(2.0, 6.0), sh(base, 0.72))
		else:
			cv.rect(x, y + i * step + 0.3, w, step - 0.6, sh(base, tone))
			cv.rect(x, y + i * step + 0.3, w, 0.8, sh(base, tone * 1.15))

## Tejado en trapecio con hileras de tejas escalonadas. top_inset estrecha la cumbrera.
static func tiles(cv: Cv, xl: float, xr: float, y_eave: float, y_ridge: float, inset: float, base: Color, seed_v: int, row_h: float = 4.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	cv.quad(Vector2(xl, y_eave), Vector2(xr, y_eave), Vector2(xr - inset, y_ridge), Vector2(xl + inset, y_ridge), sh(base, 0.62))
	var rows := maxi(1, int(round((y_eave - y_ridge) / row_h)))
	var rh := (y_eave - y_ridge) / float(rows)
	for r in rows:
		var ya := y_ridge + r * rh
		var yb := ya + rh
		var ta := float(r) / float(rows)
		var tb := float(r + 1) / float(rows)
		var la := xl + inset * (1.0 - ta)
		var ra := xr - inset * (1.0 - ta)
		var lb := xl + inset * (1.0 - tb)
		var rb := xr - inset * (1.0 - tb)
		var tone := 1.0 + (0.12 - 0.20 * ta) + rng.randf_range(-0.04, 0.04)
		cv.quad(Vector2(la, ya + 0.5), Vector2(ra, ya + 0.5), Vector2(rb, yb - 0.3), Vector2(lb, yb - 0.3), sh(base, tone))
		# tejas individuales
		var tw := 5.0
		var off := 0.0 if r % 2 == 0 else tw * 0.5
		var xx := lb + off
		while xx < rb:
			cv.rect(xx, ya + 0.6, 0.7, rh - 0.9, sh(base, 0.70))
			xx += tw
		cv.rect(minf(la, lb), yb - 1.0, absf(maxf(ra, rb) - minf(la, lb)), 0.9, sh(base, 0.58))   # sombra bajo la hilera

## Paja: muchos trazos cortos.
static func thatch(cv: Cv, xl: float, xr: float, y_eave: float, y_ridge: float, inset: float, base: Color, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	cv.quad(Vector2(xl, y_eave), Vector2(xr, y_eave), Vector2(xr - inset, y_ridge), Vector2(xl + inset, y_ridge), sh(base, 0.72))
	var n := int((xr - xl) * (y_eave - y_ridge) / 5.0)
	for i in n:
		var t := rng.randf()
		var y := y_ridge + t * (y_eave - y_ridge)
		var lx := xl + inset * (1.0 - t)
		var rx := xr - inset * (1.0 - t)
		var x := rng.randf_range(lx, rx)
		var k := rng.randf_range(0.85, 1.28)
		cv.line(x, y, x + rng.randf_range(-1.2, 1.2), y + rng.randf_range(2.0, 4.5), 0.9, sh(base, k))
	cv.rect(xl + inset, y_ridge - 1.0, xr - xl - 2.0 * inset, 2.2, sh(base, 0.8))   # cumbrera

static func door(cv: Cv, x: float, y: float, w: float, h: float, wood: Color, arch: bool = true) -> void:
	cv.rect(x - 1.2, y - 1.2, w + 2.4, h + 1.2, INK)
	if arch:
		cv.disc(x + w * 0.5, y, w * 0.5 + 1.2, INK)
	cv.rect(x, y, w, h, sh(wood, 0.85))
	if arch:
		cv.disc(x + w * 0.5, y, w * 0.5, sh(wood, 0.85))
	var n := int(w / 3.0)
	for i in range(1, n):
		cv.rect(x + i * (w / n) - 0.3, y - (w * 0.45 if arch else 0.0), 0.7, h + (w * 0.45 if arch else 0.0), sh(wood, 0.6))
	cv.rect(x + w * 0.5 - 0.5, y - (w * 0.5 if arch else 0.0), 1.0, h + (w * 0.5 if arch else 0.0), sh(wood, 0.55))
	cv.rect(x, y + h * 0.25, w, 1.3, Color(0.22, 0.22, 0.25))
	cv.rect(x, y + h * 0.7, w, 1.3, Color(0.22, 0.22, 0.25))
	cv.disc(x + w * 0.5 - 2.0, y + h * 0.55, 0.9, Color(0.75, 0.62, 0.3))
	cv.disc(x + w * 0.5 + 2.0, y + h * 0.55, 0.9, Color(0.75, 0.62, 0.3))

static func window(cv: Cv, x: float, y: float, w: float, h: float, shutter: Color) -> void:
	cv.rect(x - 1.0, y - 1.0, w + 2.0, h + 2.0, INK)
	cv.rect(x, y, w, h, Color(0.16, 0.20, 0.26))
	cv.rect(x + 0.5, y + 0.5, w * 0.5 - 0.5, h * 0.45, Color(0.42, 0.55, 0.66, 0.9))      # reflejo
	cv.rect(x + w * 0.5 - 0.4, y, 0.8, h, INK)
	cv.rect(x, y + h * 0.5 - 0.4, w, 0.8, INK)
	cv.rect(x - 2.4, y - 0.5, 2.2, h + 1.0, shutter)
	cv.rect(x + w + 0.2, y - 0.5, 2.2, h + 1.0, sh(shutter, 0.8))
	cv.rect(x - 1.0, y + h + 1.0, w + 2.0, 1.4, Color(0.50, 0.48, 0.44))    # alféizar

static func chimney(cv: Cv, x: float, y0: float, y1: float, w: float, col: Color, seed_v: int) -> void:
	cv.rect(x - 1.0, y0 - 1.0, w + 2.0, y1 - y0 + 1.0, INK)
	stone(cv, x, y0, w, y1 - y0, col, seed_v, 3.0)
	cv.rect(x - 1.0, y0 - 1.6, w + 2.0, 2.0, sh(col, 1.1))
	cv.rect(x + 1.0, y0 - 0.2, w - 2.0, 1.2, Color(0.08, 0.06, 0.05))

static func barrel(cv: Cv, x: float, y: float, r: float = 4.0) -> void:
	cv.ell(x + 1.0, y + r * 0.9, r * 1.1, r * 0.45, Color(0, 0, 0, 0.25))
	cv.rect(x - r - 0.9, y - r * 1.2 - 0.9, r * 2.0 + 1.8, r * 2.4 + 1.8, INK)
	cv.rect(x - r, y - r * 1.2, r * 2.0, r * 2.4, Color(0.56, 0.37, 0.19))
	cv.rect(x - r, y - r * 1.2, r * 0.7, r * 2.4, Color(0.70, 0.48, 0.26))
	for k in [-0.7, 0.7]:
		cv.rect(x - r, y + k * r - 0.5, r * 2.0, 1.0, Color(0.25, 0.22, 0.22))
	cv.ell(x, y - r * 1.2, r, r * 0.4, Color(0.66, 0.46, 0.25))

static func crate(cv: Cv, x: float, y: float, s: float = 6.0) -> void:
	cv.ell(x + s * 0.5 + 1.0, y + s, s * 0.9, s * 0.3, Color(0, 0, 0, 0.22))
	cv.rect(x - 0.9, y - 0.9, s + 1.8, s + 1.8, INK)
	cv.rect(x, y, s, s, Color(0.62, 0.44, 0.24))
	cv.rect(x, y, s, 1.2, Color(0.78, 0.58, 0.34))
	cv.line(x + 0.6, y + 0.6, x + s - 0.6, y + s - 0.6, 1.0, Color(0.36, 0.24, 0.12))
	cv.line(x + s - 0.6, y + 0.6, x + 0.6, y + s - 0.6, 1.0, Color(0.36, 0.24, 0.12))

static func sack(cv: Cv, x: float, y: float, s: float = 4.5) -> void:
	cv.ell(x + 1.0, y + s * 0.8, s, s * 0.35, Color(0, 0, 0, 0.22))
	cv.ell(x, y, s + 0.9, s * 0.9 + 0.9, INK)
	cv.ell(x, y, s, s * 0.9, Color(0.84, 0.76, 0.54))
	cv.ell(x - s * 0.3, y - s * 0.3, s * 0.5, s * 0.4, Color(0.94, 0.88, 0.68))
	cv.rect(x - s * 0.35, y - s * 0.95, s * 0.7, 1.4, Color(0.52, 0.40, 0.22))

static func hay(cv: Cv, x: float, y: float, w: float = 10.0, h: float = 6.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x * 31 + y * 17)
	cv.ell(x + w * 0.5 + 1.0, y + h, w * 0.6, h * 0.3, Color(0, 0, 0, 0.22))
	cv.rect(x - 0.9, y - 0.9, w + 1.8, h + 1.8, INK)
	cv.rect(x, y, w, h, Color(0.86, 0.72, 0.30))
	for i in int(w * h / 2.2):
		cv.rect(x + rng.randf() * w, y + rng.randf() * h, rng.randf_range(1.0, 2.6), 0.6, sh(Color(0.86, 0.72, 0.30), rng.randf_range(0.78, 1.2)))
	cv.rect(x, y + h * 0.3, w, 0.9, Color(0.52, 0.36, 0.14))
	cv.rect(x, y + h * 0.7, w, 0.9, Color(0.52, 0.36, 0.14))

static func fence(cv: Cv, x0: float, x1: float, y: float) -> void:
	var x := x0
	while x <= x1:
		cv.rect(x - 0.9, y - 6.0, 1.8, 8.0, Color(0.36, 0.24, 0.13))
		x += 6.0
	cv.rect(x0, y - 4.5, x1 - x0, 1.3, Color(0.52, 0.36, 0.2))
	cv.rect(x0, y - 1.5, x1 - x0, 1.3, Color(0.46, 0.31, 0.17))

## Mancha de suelo bajo el edificio: tierra pisada con adoquines sueltos.
static func yard(cv: Cv, cx: float, cy: float, rx: float, ry: float, seed_v: int, paved: bool = false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	cv.ell(cx + 3.0, cy + 2.0, rx, ry, Color(0, 0, 0, 0.18))       # sombra suave extendida
	cv.ell(cx, cy, rx, ry, Color(0.50, 0.42, 0.30, 0.55))
	cv.ell(cx, cy, rx * 0.88, ry * 0.86, Color(0.60, 0.51, 0.37, 0.65))
	for i in int(rx * ry / 6.0):
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf())
		var px := cx + cos(a) * rx * 0.85 * d
		var py := cy + sin(a) * ry * 0.85 * d
		if paved:
			cv.ell(px, py, rng.randf_range(1.6, 2.8), rng.randf_range(0.9, 1.5), sh(Color(0.66, 0.62, 0.54), rng.randf_range(0.85, 1.12)))
		else:
			cv.rect(px, py, rng.randf_range(0.8, 1.8), 0.7, sh(Color(0.62, 0.53, 0.38), rng.randf_range(0.8, 1.2)))

## Sombra proyectada hacia el sureste por un volumen de ancho w y altura h.
static func cast_shadow(cv: Cv, x0: float, x1: float, yb: float, h: float) -> void:
	var dx := h * 0.55
	var dy := h * 0.10
	cv.quad(Vector2(x0 + 2.0, yb), Vector2(x1, yb), Vector2(x1 + dx, yb + dy), Vector2(x0 + dx * 0.5, yb + dy), Color(0, 0, 0, 0.26))

static func pennant(cv: Cv, x: float, y_top: float, y_bot: float, col: Color, w: float = 9.0, h: float = 6.0) -> void:
	cv.rect(x - 0.7, y_top, 1.4, y_bot - y_top, Color(0.20, 0.15, 0.10))
	cv.tri(x + 0.7, y_top, x + 0.7 + w, y_top + h * 0.5, x + 0.7, y_top + h, col)
	cv.tri(x + 0.7, y_top, x + 0.7 + w, y_top + h * 0.5, x + 0.7, y_top + h * 0.45, sh(col, 1.25))
	cv.disc(x, y_top - 0.4, 1.1, Color(0.85, 0.7, 0.3))

static func banner(cv: Cv, x: float, y_top: float, w: float, h: float, col: Color) -> void:
	cv.rect(x - w * 0.5 - 1.0, y_top - 2.0, w + 2.0, 1.6, Color(0.24, 0.17, 0.10))
	cv.rect(x - w * 0.5, y_top - 0.4, w, h - 2.0, col)
	cv.tri(x - w * 0.5, y_top + h - 2.4, x + w * 0.5, y_top + h - 2.4, x, y_top + h + 1.0, col)
	cv.rect(x - w * 0.5, y_top - 0.4, w * 0.35, h - 2.0, sh(col, 1.2))
	cv.rect(x - w * 0.5, y_top + h * 0.35, w, 1.0, sh(col, 0.7))

# ---------------------------------------------------------------- edificios

const STONE := Color(0.67, 0.65, 0.61)
const STONE_BLUE := Color(0.58, 0.60, 0.64)
const PLASTER := Color(0.91, 0.85, 0.70)
const WOOD := Color(0.37, 0.25, 0.14)
const PLANK := Color(0.58, 0.40, 0.22)
const TILE_RED := Color(0.67, 0.29, 0.21)
const SLATE := Color(0.38, 0.43, 0.50)
const SHINGLE := Color(0.46, 0.33, 0.22)
const STRAW := Color(0.80, 0.66, 0.34)

## Cara lateral derecha (más oscura) de un volumen: da profundidad.
static func side_face(cv: Cv, x1: float, yb: float, y_top: float, dx: float, dy: float, col: Color) -> void:
	cv.quad(Vector2(x1, yb), Vector2(x1 + dx, yb - dy), Vector2(x1 + dx, y_top - dy), Vector2(x1, y_top), col)
	cv.line(x1 + dx, yb - dy, x1 + dx, y_top - dy, 1.0, INK)

static func roof_side(cv: Cv, er: Vector2, eb: Vector2, rb: Vector2, rr: Vector2, col: Color, lines: int = 4) -> void:
	cv.quad(er, eb, rb, rr, col)
	for i in range(1, lines):
		var t := float(i) / float(lines)
		cv.line(lerpf(er.x, rr.x, t), lerpf(er.y, rr.y, t), lerpf(eb.x, rb.x, t), lerpf(eb.y, rb.y, t), 0.8, sh(col, 0.7))
	cv.line(er.x, er.y, eb.x, eb.y, 1.0, INK)

static func paint_base(cv: Cv, type: String) -> void:
	match type:
		"casa":
			yard(cv, 32, 57, 29, 6, 1)
			cast_shadow(cv, 10, 52, 56, 26)
			side_face(cv, 50, 56, 36, 8, 5, sh(PLASTER, 0.70))
			stone(cv, 50, 51, 8, 5, STONE, 4, 3.0)
			stone(cv, 10, 51, 40, 5, STONE, 2, 3.0)
			timber(cv, 10, 36, 40, 15, PLASTER, WOOD, 3, 4)
			door(cv, 26, 42, 9, 14, PLANK, true)
			window(cv, 14, 41, 6, 6, Color(0.30, 0.42, 0.52))
			window(cv, 40, 41, 6, 6, Color(0.30, 0.42, 0.52))
			roof_side(cv, Vector2(55, 36), Vector2(63, 31), Vector2(47, 12), Vector2(43, 14), sh(TILE_RED, 0.66))
			tiles(cv, 5, 55, 36, 14, 12, TILE_RED, 7)
			cv.rect(5, 36, 50, 2.2, Color(0, 0, 0, 0.30))
			chimney(cv, 19, 6, 21, 6, STONE, 9)
		"almacen":
			yard(cv, 32, 57, 29, 6, 2)
			cast_shadow(cv, 8, 50, 56, 24)
			side_face(cv, 50, 56, 34, 8, 5, sh(PLANK, 0.68))
			planks(cv, 8, 34, 42, 22, PLANK, 5, true)
			stone(cv, 8, 52, 42, 4, STONE, 6, 3.0)
			door(cv, 22, 40, 14, 16, Color(0.50, 0.34, 0.18), false)
			cv.line(22.5, 40.5, 35.5, 55.5, 1.4, Color(0.30, 0.2, 0.1))
			cv.line(35.5, 40.5, 22.5, 55.5, 1.4, Color(0.30, 0.2, 0.1))
			sack(cv, 26, 52, 3.4)
			sack(cv, 32, 53, 3.0)
			roof_side(cv, Vector2(55, 34), Vector2(63, 29), Vector2(46, 14), Vector2(43, 16), sh(SHINGLE, 0.66))
			tiles(cv, 3, 55, 34, 16, 9, SHINGLE, 11, 3.6)
			cv.rect(3, 34, 52, 2.2, Color(0, 0, 0, 0.30))
			barrel(cv, 14, 53, 3.6)
			barrel(cv, 20, 55, 3.0)
			crate(cv, 41, 50, 6)
			sack(cv, 50, 53, 3.4)
		"centro":
			yard(cv, 48, 87, 45, 9, 7, true)
			cast_shadow(cv, 10, 78, 88, 40)
			# torre del campanario (queda detrás del tejado)
			stone(cv, 39, 30, 18, 30, STONE, 12, 4.0)
			cv.rect(38, 28, 20, 3, sh(STONE, 1.15))
			stone(cv, 37, 18, 22, 12, STONE, 13, 4.0)
			for ax in [41.0, 51.0]:
				cv.rect(ax - 0.9, 19.0, 6.8, 11.0, INK)
				cv.rect(ax, 20.0, 5.0, 10.0, Color(0.12, 0.09, 0.08))
				cv.disc(ax + 2.5, 20.0, 2.5, Color(0.12, 0.09, 0.08))
			cv.disc(44, 25, 2.1, Color(0.86, 0.66, 0.22))
			cv.rect(43.4, 22, 1.2, 2, Color(0.3, 0.2, 0.1))
			tiles(cv, 34, 62, 18, 6, 12, SLATE, 14, 3.4)
			cv.rect(34, 18, 28, 1.8, Color(0, 0, 0, 0.3))
			# sala principal
			side_face(cv, 76, 88, 62, 12, 7, sh(PLASTER, 0.70))
			stone(cv, 76, 80, 12, 8, STONE, 15, 4.0)
			stone(cv, 12, 80, 64, 8, STONE, 16, 4.0)
			timber(cv, 12, 62, 64, 18, PLASTER, WOOD, 17, 6)
			door(cv, 40, 66, 16, 22, PLANK, true)
			cv.rect(36, 86, 24, 2.6, Color(0.74, 0.72, 0.68))
			cv.rect(38, 88, 20, 2.0, Color(0.62, 0.60, 0.56))
			window(cv, 18, 68, 8, 8, Color(0.30, 0.42, 0.52))
			window(cv, 66, 68, 8, 8, Color(0.30, 0.42, 0.52))
			roof_side(cv, Vector2(82, 62), Vector2(94, 55), Vector2(78, 31), Vector2(66, 38), sh(TILE_RED, 0.66), 5)
			tiles(cv, 6, 82, 62, 38, 16, TILE_RED, 18, 4.0)
			cv.rect(6, 62, 76, 2.6, Color(0, 0, 0, 0.30))
			chimney(cv, 69, 27, 46, 7, STONE, 19)
			barrel(cv, 7, 84, 4.0)
			barrel(cv, 14, 86, 3.4)
			crate(cv, 80, 80, 6)
			sack(cv, 88, 86, 4.0)
		"cuartel":
			yard(cv, 48, 88, 45, 8, 21)
			cast_shadow(cv, 8, 78, 88, 36)
			side_face(cv, 78, 88, 60, 12, 7, sh(STONE_BLUE, 0.66))
			stone(cv, 8, 60, 70, 28, STONE_BLUE, 22, 4.5)
			cv.rect(8, 60, 70, 2.8, sh(WOOD, 1.0))
			door(cv, 34, 68, 14, 20, Color(0.34, 0.22, 0.12), false)
			cv.rect(30, 86, 22, 2.6, Color(0.74, 0.72, 0.68))
			window(cv, 60, 70, 8, 8, Color(0.30, 0.34, 0.42))
			window(cv, 16, 70, 8, 8, Color(0.30, 0.34, 0.42))
			roof_side(cv, Vector2(83, 60), Vector2(95, 53), Vector2(79, 31), Vector2(69, 34), sh(SLATE, 0.66), 5)
			tiles(cv, 3, 83, 60, 34, 14, SLATE, 23, 4.0)
			cv.rect(3, 60, 80, 2.6, Color(0, 0, 0, 0.32))
			chimney(cv, 60, 20, 42, 8, Color(0.50, 0.46, 0.44), 24)
			# escudo con espadas cruzadas sobre la puerta
			cv.disc(41, 63, 4.6, INK)
			cv.disc(41, 63, 3.8, Color(0.84, 0.82, 0.76))
			cv.line(38.5, 60.5, 43.5, 65.5, 1.2, Color(0.30, 0.30, 0.34))
			cv.line(43.5, 60.5, 38.5, 65.5, 1.2, Color(0.30, 0.30, 0.34))
			# armero y muñeco de entrenamiento
			cv.rect(9, 79, 1.6, 9, WOOD)
			cv.rect(21, 79, 1.6, 9, WOOD)
			cv.rect(9, 80, 13, 1.4, sh(WOOD, 1.2))
			for sx in [11.0, 14.0, 17.0, 20.0]:
				cv.line(sx, 88, sx + 1.0, 76, 1.0, Color(0.55, 0.40, 0.22))
				cv.tri(sx + 1.0, 74, sx - 0.4, 77, sx + 2.4, 77, Color(0.82, 0.84, 0.88))
			cv.rect(82, 78, 2, 10, WOOD)
			cv.rect(78, 80, 10, 2, WOOD)
			cv.disc(83, 76, 3.2, Color(0.78, 0.66, 0.36))
			hay(cv, 70, 83, 10, 5)
		"arqueria":
			yard(cv, 48, 88, 45, 8, 31)
			cast_shadow(cv, 10, 76, 86, 34)
			side_face(cv, 74, 86, 56, 12, 7, sh(PLANK, 0.62))
			planks(cv, 10, 56, 64, 30, sh(PLANK, 0.62), 32, true)
			cv.rect(10, 56, 64, 5, Color(0, 0, 0, 0.35))
			# arcos colgados al fondo
			for bx in [20.0, 32.0, 44.0, 56.0]:
				cv.line(bx, 66, bx - 2.0, 74, 1.6, Color(0.70, 0.52, 0.30))
				cv.line(bx - 2.0, 74, bx, 82, 1.6, Color(0.70, 0.52, 0.30))
				cv.line(bx, 66, bx, 82, 0.6, Color(0.9, 0.9, 0.85))
			for px in [10.0, 40.0, 72.0]:
				cv.rect(px - 2.4, 54, 5.0, 33, INK)
				cv.rect(px - 1.8, 54, 3.8, 33, Color(0.50, 0.35, 0.19))
				cv.rect(px - 1.8, 54, 1.3, 33, Color(0.66, 0.48, 0.27))
				cv.rect(px - 3.4, 84, 7.0, 3.2, Color(0.55, 0.53, 0.5))
			roof_side(cv, Vector2(80, 54), Vector2(92, 47), Vector2(76, 28), Vector2(66, 30), sh(STRAW, 0.62), 5)
			thatch(cv, 4, 80, 54, 30, 14, STRAW, 33)
			cv.rect(4, 54, 76, 2.4, Color(0, 0, 0, 0.30))
			# dianas
			for t in [Vector2(20, 80), Vector2(76, 82)]:
				cv.line(t.x - 4, 90, t.x - 1, t.y + 5, 1.6, WOOD)
				cv.line(t.x + 4, 90, t.x + 1, t.y + 5, 1.6, WOOD)
				cv.disc(t.x, t.y, 8.2, INK)
				cv.disc(t.x, t.y, 7.4, Color(0.92, 0.9, 0.82))
				cv.disc(t.x, t.y, 5.6, Color(0.78, 0.16, 0.14))
				cv.disc(t.x, t.y, 3.8, Color(0.92, 0.9, 0.82))
				cv.disc(t.x, t.y, 2.2, Color(0.78, 0.16, 0.14))
				cv.disc(t.x, t.y, 0.9, Color(0.95, 0.8, 0.25))
				cv.line(t.x + 1.2, t.y - 1.2, t.x + 6.0, t.y - 5.0, 0.9, Color(0.85, 0.85, 0.8))
			hay(cv, 44, 82, 12, 6)
			barrel(cv, 62, 84, 3.4)
		"establo":
			yard(cv, 48, 88, 45, 8, 41)
			cast_shadow(cv, 10, 74, 88, 38)
			var barn := Color(0.64, 0.31, 0.23)
			side_face(cv, 74, 88, 56, 12, 7, sh(barn, 0.66))
			planks(cv, 10, 56, 64, 32, barn, 40, true)
			stone(cv, 10, 84, 64, 4, STONE, 42, 3.0)
			cv.rect(10, 56, 64, 3, Color(0, 0, 0, 0.3))
			# puerta grande con cruces blancas
			var wh := Color(0.92, 0.89, 0.80)
			cv.rect(30, 60, 24, 28, INK)
			cv.rect(31, 61, 22, 27, sh(barn, 0.80))
			cv.rect(31, 61, 22, 1.6, wh)
			cv.rect(31, 61, 1.6, 27, wh)
			cv.rect(51.4, 61, 1.6, 27, wh)
			cv.rect(41.2, 61, 1.6, 27, wh)
			cv.line(32, 62, 41, 87, 1.4, wh)
			cv.line(41, 62, 32, 87, 1.4, wh)
			cv.line(43, 62, 52, 87, 1.4, wh)
			cv.line(52, 62, 43, 87, 1.4, wh)
			# tejado de dos pendientes (mansarda)
			roof_side(cv, Vector2(79, 56), Vector2(91, 49), Vector2(70, 36), Vector2(66, 40), sh(SHINGLE, 0.62), 4)
			tiles(cv, 5, 79, 56, 40, 4, SHINGLE, 43, 4.0)
			tiles(cv, 10, 74, 40, 24, 16, sh(SHINGLE, 1.08), 44, 4.0)
			cv.rect(5, 56, 74, 2.6, Color(0, 0, 0, 0.30))
			# ventanuco del henil
			cv.rect(37.4, 44, 11, 11, INK)
			cv.rect(38.4, 45, 9, 9, Color(0.14, 0.09, 0.06))
			cv.rect(38.4, 51, 9, 3, Color(0.82, 0.68, 0.28))
			# paddock con caballo y heno
			fence(cv, 76, 94, 86)
			cv.ell(86, 78, 6.5, 3.6, INK)
			cv.ell(86, 78, 5.7, 2.9, Color(0.50, 0.30, 0.16))
			cv.line(91, 77, 93, 72, 3.0, Color(0.50, 0.30, 0.16))
			cv.ell(94, 71.5, 2.6, 1.7, Color(0.46, 0.27, 0.14))
			for lx in [82.5, 84.5, 88.0, 89.5]:
				cv.line(lx, 80, lx, 85, 1.1, Color(0.38, 0.22, 0.12))
			hay(cv, 12, 82, 11, 6)
			cv.rect(54, 84, 14, 3.4, INK)
			cv.rect(54.6, 84.4, 12.8, 2.6, Color(0.44, 0.30, 0.17))
			cv.rect(55, 84.8, 12, 1.4, Color(0.30, 0.55, 0.70))
		"taller":
			yard(cv, 48, 88, 45, 8, 61)
			cast_shadow(cv, 8, 76, 88, 38)
			side_face(cv, 76, 88, 56, 12, 7, sh(PLANK, 0.60))
			planks(cv, 8, 56, 68, 32, sh(PLANK, 0.78), 62, true)
			stone(cv, 8, 84, 68, 4, STONE, 63, 3.0)
			# nave abierta con el interior en sombra
			cv.rect(15, 61, 54, 25, INK)
			cv.rect(16, 62, 52, 24, Color(0.17, 0.12, 0.08))
			cv.rect(16, 62, 52, 5, Color(0, 0, 0, 0.35))
			# ariete a medio montar sobre caballetes
			for tx in [24.0, 54.0]:
				cv.line(tx - 5, 86, tx, 76, 2.4, INK)
				cv.line(tx + 5, 86, tx, 76, 2.4, INK)
				cv.line(tx - 5, 86, tx, 76, 1.4, Color(0.52, 0.36, 0.18))
				cv.line(tx + 5, 86, tx, 76, 1.4, Color(0.52, 0.36, 0.18))
			cv.rect(18, 72.4, 46, 6.4, INK)
			cv.rect(18.6, 73.0, 44.8, 5.2, Color(0.54, 0.36, 0.18))
			cv.rect(18.6, 73.0, 44.8, 1.4, Color(0.70, 0.50, 0.26))
			cv.rect(60, 71.6, 7, 8, INK)
			cv.tri(60.6, 72.2, 60.6, 79.0, 67.0, 75.6, Color(0.66, 0.68, 0.74))
			for rx in [30.0, 44.0]:
				cv.rect(rx, 72.4, 2.4, 6.4, Color(0.30, 0.31, 0.36))
			# rueda apoyada
			cv.disc(24, 66, 5.4, INK)
			cv.disc(24, 66, 4.5, Color(0.48, 0.32, 0.16))
			cv.disc(24, 66, 1.4, INK)
			for k in 4:
				var ang := float(k) * PI / 4.0
				cv.line(24 - cos(ang) * 4.2, 66 - sin(ang) * 4.2, 24 + cos(ang) * 4.2, 66 + sin(ang) * 4.2, 0.9, INK)
			# postes
			for px in [8.0, 42.0, 74.0]:
				cv.rect(px - 2.4, 54, 5.0, 33, INK)
				cv.rect(px - 1.8, 54, 3.8, 33, Color(0.50, 0.35, 0.19))
				cv.rect(px - 1.8, 54, 1.3, 33, Color(0.66, 0.48, 0.27))
			roof_side(cv, Vector2(82, 54), Vector2(94, 47), Vector2(78, 28), Vector2(68, 30), sh(SHINGLE, 0.62), 5)
			tiles(cv, 3, 82, 54, 30, 14, SHINGLE, 65, 4.0)
			cv.rect(3, 54, 79, 2.4, Color(0, 0, 0, 0.30))
			# troncos apilados y tablones
			for r in 3:
				for k in range(3 - r):
					var lx := 80.0 + k * 5.0 + r * 2.5
					var ly := 86.0 - r * 4.4
					cv.disc(lx, ly, 2.8, INK)
					cv.disc(lx, ly, 2.2, Color(0.74, 0.55, 0.30))
					cv.disc(lx, ly, 0.9, Color(0.52, 0.36, 0.18))
			for k in 4:
				cv.rect(70, 84 - k * 1.8, 12, 1.5, INK)
				cv.rect(70.4, 84.3 - k * 1.8, 11.2, 0.9, sh(PLANK, 1.0 + k * 0.05))
			barrel(cv, 12, 88, 3.2)
		"puerto":
			yard(cv, 48, 88, 45, 8, 71, true)
			cast_shadow(cv, 10, 76, 88, 38)
			var weather := Color(0.56, 0.52, 0.47)
			side_face(cv, 76, 88, 56, 12, 7, sh(weather, 0.62))
			stone(cv, 10, 78, 66, 10, STONE_BLUE, 72, 3.5)
			side_face(cv, 76, 88, 78, 12, 7, sh(STONE_BLUE, 0.62))
			planks(cv, 10, 56, 66, 22, weather, 73, true)
			cv.rect(10, 56, 66, 4, Color(0, 0, 0, 0.30))
			# portalón de carga y letrero con ancla
			door(cv, 36, 62, 18, 16, PLANK, false)
			cv.rect(32, 76, 26, 2.6, Color(0.74, 0.72, 0.68))
			cv.line(45, 56, 45, 61, 1.2, INK)
			cv.disc(45, 52.5, 5.4, INK)
			cv.disc(45, 52.5, 4.6, Color(0.84, 0.80, 0.66))
			cv.line(45, 49.5, 45, 56, 1.2, Color(0.22, 0.24, 0.30))
			cv.line(42, 52.2, 48, 52.2, 1.1, Color(0.22, 0.24, 0.30))
			cv.line(42.2, 54.4, 45, 56.4, 1.1, Color(0.22, 0.24, 0.30))
			cv.line(47.8, 54.4, 45, 56.4, 1.1, Color(0.22, 0.24, 0.30))
			cv.disc(45, 49.6, 1.0, Color(0.22, 0.24, 0.30))
			window(cv, 16, 64, 6, 6, Color(0.28, 0.40, 0.50))
			window(cv, 64, 64, 6, 6, Color(0.28, 0.40, 0.50))
			roof_side(cv, Vector2(82, 56), Vector2(94, 49), Vector2(78, 28), Vector2(66, 32), sh(SLATE, 0.66), 5)
			tiles(cv, 4, 82, 56, 30, 14, SLATE, 74, 4.0)
			cv.rect(4, 56, 78, 2.6, Color(0, 0, 0, 0.32))
			# grúa de carga a la derecha
			cv.rect(86.4, 38, 3.6, 50, INK)
			cv.rect(87.0, 38, 2.4, 50, Color(0.46, 0.31, 0.16))
			cv.line(88, 38, 74, 47, 3.0, INK)
			cv.line(88, 38, 74, 47, 1.8, Color(0.52, 0.36, 0.18))
			cv.line(88, 40, 74, 48.5, 0.7, Color(0.9, 0.9, 0.85))
			cv.line(75, 47.5, 75, 62, 0.8, Color(0.20, 0.15, 0.10))
			crate(cv, 72, 62, 6)
			# red tendida a secar
			for px in [6.0, 24.0]:
				cv.rect(px - 0.9, 70, 1.8, 18, INK)
				cv.rect(px - 0.4, 70, 0.9, 18, Color(0.52, 0.36, 0.18))
			cv.line(6, 72, 24, 72, 1.2, Color(0.40, 0.28, 0.14))
			for k in 7:
				cv.line(7.5 + k * 2.4, 72, 7.5 + k * 2.4, 82, 0.5, Color(0.55, 0.70, 0.56, 0.85))
			for k in 5:
				cv.line(7.0, 73 + k * 2.2, 23.0, 73.4 + k * 2.2, 0.5, Color(0.55, 0.70, 0.56, 0.85))
			barrel(cv, 60, 87, 3.4)
			barrel(cv, 66, 88, 3.0)
			crate(cv, 80, 82, 5)
			# bote varado
			cv.ell(18, 91, 9.6, 3.2, INK)
			cv.ell(18, 90.6, 8.8, 2.6, Color(0.50, 0.33, 0.17))
			cv.ell(17, 89.8, 7.0, 1.0, Color(0.64, 0.46, 0.24))
		"torre":
			yard(cv, 32, 57, 22, 5, 51)
			cast_shadow(cv, 16, 47, 56, 40)
			side_face(cv, 47, 56, 22, 7, 4, sh(STONE, 0.66))
			stone(cv, 17, 22, 30, 34, STONE, 50, 4.5)
			cv.rect(17, 22, 30, 2.6, sh(STONE, 0.8))
			# parapeto saliente con almenas
			cv.rect(13, 14, 38, 8, INK)
			stone(cv, 14, 15, 36, 6, sh(STONE, 1.08), 52, 3.0)
			cv.rect(13, 21, 38, 2.4, Color(0, 0, 0, 0.35))
			for mx in [14.0, 22.0, 30.0, 38.0, 45.0]:
				cv.rect(mx - 0.9, 8.0, 6.8, 8.0, INK)
				cv.rect(mx, 9.0, 5.0, 7.0, sh(STONE, 1.12))
				cv.rect(mx, 9.0, 5.0, 1.2, sh(STONE, 1.3))
			# troneras y puerta
			for sp in [Vector2(30.5, 28), Vector2(23, 40), Vector2(38, 40)]:
				cv.rect(sp.x - 0.8, sp.y - 0.8, 3.6, 10.6, INK)
				cv.rect(sp.x, sp.y, 2.0, 9.0, Color(0.06, 0.05, 0.05))
			door(cv, 27, 45, 10, 11, PLANK, true)
		"muralla":
			cast_shadow(cv, 4, 60, 56, 26)
			side_face(cv, 60, 56, 26, 4, 2, sh(STONE, 0.66))
			stone(cv, 4, 26, 56, 30, STONE, 60, 4.5)
			cv.rect(3, 22, 58, 6, INK)
			stone(cv, 4, 23, 56, 4, sh(STONE, 1.08), 61, 3.0)
			for mx in [4.0, 16.0, 28.0, 40.0, 52.0]:
				cv.rect(mx - 0.9, 14.0, 8.0, 9.0, INK)
				cv.rect(mx, 15.0, 6.2, 8.0, sh(STONE, 1.12))
		"puerta":
			cast_shadow(cv, 4, 60, 56, 40)
			stone(cv, 3, 14, 17, 42, STONE, 70, 4.5)
			stone(cv, 44, 14, 17, 42, STONE, 71, 4.5)
			stone(cv, 20, 22, 24, 8, sh(STONE, 1.05), 72, 4.0)
			for px in [3.0, 44.0]:
				cv.rect(px - 0.9, 8.0, 18.8, 6.0, INK)
				for mx in [0.0, 6.5, 13.0]:
					cv.rect(px + mx, 8.5, 5.0, 6.0, sh(STONE, 1.12))
			cv.rect(20, 28, 24, 28, INK)
			cv.disc(32, 34, 12.0, INK)
			cv.rect(21, 34, 22, 22, Color(0.40, 0.26, 0.12))
			cv.disc(32, 34, 11.0, Color(0.40, 0.26, 0.12))
			for gx in range(1, 6):
				cv.rect(21 + gx * 3.6, 24, 0.8, 32, Color(0.25, 0.16, 0.08))
			cv.rect(21, 40, 22, 1.6, Color(0.22, 0.22, 0.25))
			cv.rect(21, 50, 22, 1.6, Color(0.22, 0.22, 0.25))

static func paint_team(cv: Cv, type: String, c: Color) -> void:
	var d := sh(c, 0.55)
	match type:
		"casa":
			pennant(cv, 40, 2, 16, c, 9.0, 6.0)
			cv.rect(27.4, 37.0, 6.2, 4.4, INK)
			cv.rect(28.0, 37.6, 5.0, 3.4, c)
		"almacen":
			pennant(cv, 40, 4, 18, c, 9.0, 6.0)
			cv.rect(8, 34.4, 42, 3.0, c)
			cv.rect(8, 36.8, 42, 0.8, d)
		"centro":
			pennant(cv, 48, 0, 10, c, 9.0, 5.5)
			banner(cv, 33, 64, 6.0, 15.0, c)
			banner(cv, 63, 64, 6.0, 15.0, c)
			cv.rect(40, 62.0, 16, 2.4, c)
		"cuartel":
			pennant(cv, 26, 22, 38, c, 9.0, 6.0)
			cv.disc(41, 63, 3.2, c)
			banner(cv, 55, 66, 6.0, 12.0, c)
			banner(cv, 25, 66, 6.0, 12.0, c)
		"arqueria":
			pennant(cv, 42, 22, 32, c, 9.0, 6.0)
			banner(cv, 42, 58, 8.0, 14.0, c)
		"establo":
			pennant(cv, 42, 14, 24, c, 9.0, 6.0)
			banner(cv, 24, 62, 6.0, 12.0, c)
			cv.rect(31, 61, 22, 1.8, c)
		"taller":
			pennant(cv, 40, 14, 24, c, 9.0, 6.0)
			banner(cv, 66, 66, 6.0, 12.0, c)
			cv.rect(18, 62, 46, 1.8, c)
		"puerto":
			pennant(cv, 40, 12, 22, c, 9.0, 6.0)
			banner(cv, 62, 64, 6.0, 12.0, c)
			banner(cv, 28, 64, 6.0, 12.0, c)
		"torre":
			pennant(cv, 32, -2, 10, c, 9.0, 6.0)
			cv.rect(28.4, 31.0, 7.2, 7.0, INK)
			cv.rect(29.0, 31.6, 6.0, 5.8, c)
		"muralla", "puerta":
			pennant(cv, 32, 0, 14, c, 9.0, 6.0)
