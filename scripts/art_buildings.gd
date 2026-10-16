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
	cv.rect(x, y, w, h, sh(base, 0.50))
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
				cv.rect(x0 + 0.4, yy + 0.4, x1 - x0 - 0.8, 0.9, sh(base, tone * 1.20))      # luz arriba
				cv.rect(x0 + 0.4, yy + 0.4, 0.7, rh - 0.8, sh(base, tone * 1.10))           # luz a la izquierda
				cv.rect(x0 + 0.4, yy + rh - 1.1, x1 - x0 - 0.8, 0.7, sh(base, tone * 0.80))  # sombra abajo
				if rng.randf() < 0.35 and x1 - x0 > 3.0 and rh > 3.0:                        # picaduras de la piedra
					cv.rect(x0 + rng.randf_range(1.0, x1 - x0 - 1.8), yy + rng.randf_range(1.0, rh - 2.0), rng.randf_range(0.8, 1.8), 0.8, sh(base, tone * 0.80))
			xx += bw
		yy += rh
		row += 1
	vgrad(cv, x, y, w, h, 0.0, 0.18, Color(0.05, 0.04, 0.10))      # más oscuro hacia el suelo

## Degradado vertical con franjas finas (oclusión ambiental, suciedad, luz).
static func vgrad(cv: Cv, x: float, y: float, w: float, h: float, a_top: float, a_bot: float, col: Color = Color(0, 0, 0)) -> void:
	var n := maxi(2, int(h / 2.0))
	var step := h / float(n)
	for i in n:
		var a := lerpf(a_top, a_bot, (float(i) + 0.5) / float(n))
		if a > 0.004:
			cv.rect(x, y + i * step, w, step + 0.3, Color(col.r, col.g, col.b, a))

## Musgo en la base de un muro.
static func moss(cv: Cv, x: float, y_bot: float, w: float, seed_v: int, amount: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	for i in int(w / 5.0 * amount):
		var mh := rng.randf_range(0.8, 2.4)
		var rw := rng.randf_range(1.2, 2.8)
		cv.ell(x + rw + rng.randf() * maxf(0.5, w - 2.0 * rw), y_bot - mh * 0.55, rw, mh, Color(0.30, 0.46, 0.18, rng.randf_range(0.30, 0.50)))

## Hiedra trepando por una esquina.
static func ivy(cv: Cv, x: float, y_bot: float, h: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var px := x
	var py := y_bot
	while py > y_bot - h:
		px = clampf(px + rng.randf_range(-1.6, 1.6), x - 1.0, x + 4.5)
		for k in 2:
			var lx := px + rng.randf_range(-2.0, 2.0)
			var ly := py + rng.randf_range(-1.2, 1.2)
			var r := rng.randf_range(0.9, 1.7)
			cv.disc(lx, ly, r + 0.4, Color(0.11, 0.21, 0.08, 0.85))
			cv.disc(lx, ly, r, Color(0.24, 0.40, 0.14, 0.95) if k == 0 else Color(0.33, 0.50, 0.20, 0.95))
		py -= rng.randf_range(0.9, 1.6)

## Esquinas de sillares grandes y alternos.
static func quoins(cv: Cv, xl: float, xr: float, y: float, h: float, base: Color, seed_v: int, bw: float = 4.6, bh: float = 4.2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var n := int(h / bh)
	for i in n:
		var wl := bw if i % 2 == 0 else bw * 0.68
		var yy := y + float(i) * bh
		for side in 2:
			var xx := xl if side == 0 else xr - wl
			var tone := rng.randf_range(0.98, 1.14)
			cv.rect(xx, yy + 0.2, wl, bh - 0.4, sh(base, 0.55))
			cv.rect(xx + 0.3, yy + 0.4, wl - 0.6, bh - 0.8, sh(base, tone))
			cv.rect(xx + 0.3, yy + 0.4, wl - 0.6, 0.8, sh(base, tone * 1.2))
			cv.rect(xx + 0.3, yy + bh - 1.1, wl - 0.6, 0.6, sh(base, tone * 0.74))

## Entramado de madera sobre revoco.
static func timber(cv: Cv, x: float, y: float, w: float, h: float, plaster: Color, wood: Color, seed_v: int, panels: int = 3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	cv.rect(x, y, w, h, plaster)
	for i in int(w * h / 10.0):
		cv.rect(x + rng.randf() * w, y + rng.randf() * h, rng.randf_range(0.8, 2.2), 0.7, sh(plaster, rng.randf_range(0.88, 1.06)))
	vgrad(cv, x, y, w, h, 0.0, 0.17, Color(0.32, 0.20, 0.08))            # humedad y suciedad abajo
	for i in int(w / 10.0):                                              # churretones bajo el alero
		cv.rect(x + rng.randf() * w, y, 0.7, rng.randf_range(2.0, h * 0.55), Color(0.34, 0.24, 0.12, 0.10))
	var pw := w / float(panels)
	for i in range(panels):
		var px := x + i * pw
		var d0 := Vector2(px + 1.0, y + h - 1.0)
		var d1 := Vector2(px + pw - 1.0, y + 1.0)
		if (i + seed_v) % 2 != 0:
			d0 = Vector2(px + 1.0, y + 1.0)
			d1 = Vector2(px + pw - 1.0, y + h - 1.0)
		cv.line(d0.x, d0.y, d1.x, d1.y, 1.9, sh(wood, 0.78))
		cv.line(d0.x - 0.3, d0.y - 0.3, d1.x - 0.3, d1.y - 0.3, 0.8, sh(wood, 1.22))
	for i in range(panels + 1):
		var bx := x + i * pw - 0.9
		cv.rect(bx, y, 1.9, h, wood)
		cv.rect(bx, y, 0.6, h, sh(wood, 1.25))
		cv.rect(bx + 1.5, y, 0.4, h, sh(wood, 0.7))
	for by in [y, y + h - 1.8, y + h * 0.5 - 0.7]:
		cv.rect(x, by, w, 1.8 if by != y + h * 0.5 - 0.7 else 1.4, wood)
		cv.rect(x, by, w, 0.6, sh(wood, 1.25))
		cv.rect(x, by + 1.2, w, 0.5, sh(wood, 0.7))

## Tablones de madera (verticales u horizontales).
static func planks(cv: Cv, x: float, y: float, w: float, h: float, base: Color, seed_v: int, vertical: bool = true) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	cv.rect(x, y, w, h, sh(base, 0.55))
	var n := int((w if vertical else h) / 3.6)
	var step := (w if vertical else h) / float(maxi(n, 1))
	for i in n:
		var tone := rng.randf_range(0.88, 1.10)
		if vertical:
			cv.rect(x + i * step + 0.3, y, step - 0.6, h, sh(base, tone))
			cv.rect(x + i * step + 0.3, y, 0.8, h, sh(base, tone * 1.18))
			cv.rect(x + i * step + step - 0.9, y, 0.4, h, sh(base, tone * 0.78))
			if rng.randf() < 0.55:                                  # nudo de la madera
				var ky := y + rng.randf_range(2.0, h - 3.0)
				cv.ell(x + i * step + step * 0.5, ky, 0.9, 1.5, sh(base, 0.62))
			if rng.randf() < 0.5:
				cv.rect(x + i * step + 1.0, y + rng.randf() * h * 0.8, 0.7, rng.randf_range(2.0, 6.0), sh(base, 0.72))
		else:
			cv.rect(x, y + i * step + 0.3, w, step - 0.6, sh(base, tone))
			cv.rect(x, y + i * step + 0.3, w, 0.8, sh(base, tone * 1.15))
	vgrad(cv, x, y, w, h, 0.0, 0.20, Color(0.08, 0.05, 0.02))

## Tejado en trapecio con hileras de tejas escalonadas. top_inset estrecha la cumbrera.
static func tiles(cv: Cv, xl: float, xr: float, y_eave: float, y_ridge: float, inset: float, base: Color, seed_v: int, row_h: float = 4.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	cv.quad(Vector2(xl, y_eave), Vector2(xr, y_eave), Vector2(xr - inset, y_ridge), Vector2(xl + inset, y_ridge), sh(base, 0.55))
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
		var tone := 1.0 + (0.14 - 0.24 * ta)
		cv.quad(Vector2(la, ya + 0.5), Vector2(ra, ya + 0.5), Vector2(rb, yb - 0.3), Vector2(lb, yb - 0.3), sh(base, tone * 0.86))
		# tejas individuales: tono propio, luz arriba, extremo inferior en sombra y junta
		var tw := 5.0
		var xx := lb - (tw * 0.5 if r % 2 == 1 else 0.0)
		while xx < rb:
			var a := maxf(xx, la)
			var b := minf(xx + tw, ra)
			if b - a > 0.9:
				var tt := tone * rng.randf_range(0.90, 1.08)
				cv.rect(a + 0.2, ya + 0.3, b - a - 0.4, rh - 0.4, sh(base, tt))
				cv.rect(a + 0.2, ya + 0.3, b - a - 0.4, 0.8, sh(base, tt * 1.18))
				cv.rect(a + 0.2, yb - 1.4, b - a - 0.4, 1.0, sh(base, tt * 0.70))
				cv.rect(b - 0.7, ya + 0.3, 0.5, rh - 0.4, sh(base, tt * 0.66))
			xx += tw
		cv.rect(minf(la, lb), yb - 0.7, absf(maxf(ra, rb) - minf(la, lb)), 0.7, sh(base, 0.50))   # sombra bajo la hilera
	# liquen y tejas sueltas
	for i in 4:
		var ty := rng.randf_range(y_ridge + 2.0, y_eave - 2.0)
		var tk := (ty - y_ridge) / (y_eave - y_ridge)
		cv.ell(rng.randf_range(xl + inset * (1.0 - tk) + 3.0, xr - inset * (1.0 - tk) - 3.0), ty, rng.randf_range(1.5, 3.0), 0.9, Color(0.40, 0.52, 0.26, 0.30))
	# cumbrera con caballete y alero con tablón
	cv.rect(xl + inset - 1.0, y_ridge - 1.6, xr - xl - 2.0 * inset + 2.0, 2.6, sh(base, 0.72))
	cv.rect(xl + inset - 1.0, y_ridge - 1.6, xr - xl - 2.0 * inset + 2.0, 0.8, sh(base, 1.25))
	cv.rect(xl - 0.6, y_eave - 1.4, xr - xl + 1.2, 2.0, Color(0.27, 0.17, 0.09))
	cv.rect(xl - 0.6, y_eave - 1.4, xr - xl + 1.2, 0.6, Color(0.46, 0.32, 0.19))

## Paja: muchos trazos cortos.
static func thatch(cv: Cv, xl: float, xr: float, y_eave: float, y_ridge: float, inset: float, base: Color, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	cv.quad(Vector2(xl, y_eave), Vector2(xr, y_eave), Vector2(xr - inset, y_ridge), Vector2(xl + inset, y_ridge), sh(base, 0.66))
	var n := int((xr - xl) * (y_eave - y_ridge) / 3.2)
	for i in n:
		var t := rng.randf()
		var y := y_ridge + t * (y_eave - y_ridge)
		var lx := xl + inset * (1.0 - t)
		var rx := xr - inset * (1.0 - t)
		var x := rng.randf_range(lx, rx)
		var k := rng.randf_range(0.82, 1.30) * (1.10 - 0.18 * t)
		cv.line(x, y, x + rng.randf_range(-1.2, 1.2), y + rng.randf_range(2.0, 4.8), 0.9, sh(base, k))
	# manojos atados en hileras
	var rows := int((y_eave - y_ridge) / 6.0)
	for r in range(1, rows + 1):
		var ty := y_ridge + float(r) * (y_eave - y_ridge) / float(rows + 1)
		var tk := (ty - y_ridge) / (y_eave - y_ridge)
		cv.rect(xl + inset * (1.0 - tk) + 0.5, ty, (xr - xl) - 2.0 * inset * (1.0 - tk) - 1.0, 0.7, sh(base, 0.60))
	cv.rect(xl + inset - 1.0, y_ridge - 1.4, xr - xl - 2.0 * inset + 2.0, 2.6, sh(base, 0.78))   # cumbrera
	cv.rect(xl + inset - 1.0, y_ridge - 1.4, xr - xl - 2.0 * inset + 2.0, 0.8, sh(base, 1.18))
	cv.rect(xl - 0.4, y_eave - 1.8, xr - xl + 0.8, 2.4, sh(base, 0.70))                          # borde grueso del alero
	cv.rect(xl - 0.4, y_eave - 1.8, xr - xl + 0.8, 0.8, sh(base, 1.10))

static func door(cv: Cv, x: float, y: float, w: float, h: float, wood: Color, arch: bool = true, frame: bool = false) -> void:
	if frame:
		cv.rect(x - 2.6, y - 0.6, w + 5.2, h + 0.6, Color(0.68, 0.66, 0.62))
		if arch:
			cv.disc(x + w * 0.5, y, w * 0.5 + 2.6, Color(0.68, 0.66, 0.62))
		cv.rect(x - 2.6, y - 0.6, 0.9, h + 0.6, Color(0.82, 0.80, 0.76))
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
	cv.rect(x, y + h * 0.25, w, 0.4, Color(0.38, 0.38, 0.42))
	cv.rect(x, y + h * 0.7, w, 0.4, Color(0.38, 0.38, 0.42))
	cv.disc(x + w * 0.5 - 2.0, y + h * 0.55, 0.9, Color(0.75, 0.62, 0.3))
	cv.disc(x + w * 0.5 + 2.0, y + h * 0.55, 0.9, Color(0.75, 0.62, 0.3))
	cv.rect(x - 0.4, y + h - 0.4, w + 0.8, 0.8, Color(0, 0, 0, 0.35))

static func window(cv: Cv, x: float, y: float, w: float, h: float, shutter: Color, arch: bool = false, box: bool = false) -> void:
	var glass := Color(0.16, 0.20, 0.26)
	cv.rect(x - 1.0, y - 1.0, w + 2.0, h + 2.0, INK)
	if arch:
		cv.disc(x + w * 0.5, y, w * 0.5 + 1.0, INK)
	cv.rect(x, y, w, h, glass)
	if arch:
		cv.disc(x + w * 0.5, y, w * 0.5, glass)
	cv.rect(x + 0.5, y + 0.5, w * 0.5 - 0.5, h * 0.45, Color(0.42, 0.55, 0.66, 0.9))      # reflejo
	cv.rect(x + 0.4, y + h * 0.62, w - 0.8, h * 0.38 - 0.4, Color(0.96, 0.72, 0.30, 0.38))  # luz cálida del interior
	cv.rect(x + w * 0.5 - 0.4, y - (w * 0.4 if arch else 0.0), 0.8, h + (w * 0.4 if arch else 0.0), INK)
	cv.rect(x, y + h * 0.5 - 0.4, w, 0.8, INK)
	cv.rect(x - 2.4, y - 0.5, 2.2, h + 1.0, shutter)
	cv.rect(x + w + 0.2, y - 0.5, 2.2, h + 1.0, sh(shutter, 0.8))
	var k := 1.0
	while k < h:
		cv.rect(x - 2.4, y - 0.5 + k, 2.2, 0.4, sh(shutter, 0.62))
		cv.rect(x + w + 0.2, y - 0.5 + k, 2.2, 0.4, sh(shutter, 0.52))
		k += 1.8
	if not arch:
		cv.rect(x - 1.8, y - 2.2, w + 3.6, 1.3, Color(0.72, 0.70, 0.66))                  # dintel
		cv.rect(x - 1.8, y - 2.2, w + 3.6, 0.5, Color(0.86, 0.84, 0.80))
	cv.rect(x - 1.2, y + h + 1.0, w + 2.4, 1.4, Color(0.52, 0.50, 0.46))                # alféizar
	cv.rect(x - 1.2, y + h + 1.0, w + 2.4, 0.5, Color(0.70, 0.68, 0.64))
	if box:
		cv.rect(x - 1.4, y + h + 2.2, w + 2.8, 2.4, INK)
		cv.rect(x - 0.9, y + h + 2.6, w + 1.8, 1.6, Color(0.46, 0.30, 0.16))
		var fx := x - 0.2
		var i := 0
		while fx < x + w + 0.4:
			cv.disc(fx, y + h + 2.3, 1.0, [Color(0.86, 0.22, 0.22), Color(0.95, 0.80, 0.25), Color(0.90, 0.45, 0.60)][i % 3])
			cv.disc(fx + 0.9, y + h + 3.0, 0.8, Color(0.30, 0.52, 0.22))
			fx += 1.9
			i += 1

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

## Sombra suave que el alero proyecta sobre la pared.
static func eave_shadow(cv: Cv, x0: float, x1: float, y: float, depth: float = 7.0, a: float = 0.42) -> void:
	vgrad(cv, x0, y, x1 - x0, depth, a, 0.0, Color(0.06, 0.03, 0.10))

## Buhardilla con ventanuco y tejadillo a dos aguas, apoyada sobre un tejado.
static func dormer(cv: Cv, cx: float, y_base: float, w: float, roof: Color) -> void:
	var h := w * 0.82
	var x0 := cx - w * 0.5
	var apex := y_base - h - w * 0.62
	cv.tri(x0 - 1.9, y_base - h + 0.2, x0 + w + 1.9, y_base - h + 0.2, cx, apex - 0.9, INK)
	cv.rect(x0 - 0.9, y_base - h, w + 1.8, h + 0.9, INK)
	cv.rect(x0, y_base - h, w, h, PLASTER)
	vgrad(cv, x0, y_base - h, w, h, 0.0, 0.18, Color(0.32, 0.20, 0.08))
	cv.rect(x0, y_base - h, 1.0, h, WOOD)
	cv.rect(x0 + w - 1.0, y_base - h, 1.0, h, WOOD)
	var wx := x0 + w * 0.5 - 2.2
	var wy := y_base - h * 0.84
	cv.rect(wx - 0.8, wy - 0.8, 5.6, h * 0.55 + 1.6, INK)
	cv.rect(wx, wy, 4.0, h * 0.55, Color(0.16, 0.20, 0.26))
	cv.rect(wx + 0.4, wy + 0.4, 1.6, h * 0.25, Color(0.42, 0.55, 0.66, 0.9))
	cv.rect(wx + 1.8, wy, 0.5, h * 0.55, INK)
	cv.tri(x0 - 1.2, y_base - h, x0 + w + 1.2, y_base - h, cx, apex, sh(roof, 0.92))
	cv.tri(cx, apex, x0 + w + 1.2, y_base - h, cx + 0.2, y_base - h, sh(roof, 0.66))
	cv.line(x0 - 1.2, y_base - h, cx, apex, 0.9, sh(roof, 1.25))
	cv.rect(x0 - 1.4, y_base - h - 0.2, w + 2.8, 1.2, Color(0.27, 0.17, 0.09))

## Antorcha de pared con llama.
static func torch(cv: Cv, x: float, y: float) -> void:
	cv.rect(x - 0.6, y, 1.2, 5.0, Color(0.25, 0.17, 0.10))
	cv.rect(x - 1.4, y - 0.4, 2.8, 1.2, Color(0.22, 0.22, 0.25))
	cv.ell(x, y - 2.0, 1.7, 2.3, Color(0.95, 0.45, 0.10, 0.9))
	cv.ell(x, y - 1.6, 0.9, 1.4, Color(1.0, 0.85, 0.35))

## Matacanes: piedras salientes bajo un parapeto.
static func corbels(cv: Cv, x0: float, x1: float, y: float, base: Color) -> void:
	cv.rect(x0, y, x1 - x0, 1.5, sh(base, 0.92))
	cv.rect(x0, y, x1 - x0, 0.5, sh(base, 1.25))
	var x := x0 + 1.4
	while x + 3.0 <= x1 - 0.8:
		cv.rect(x, y + 1.5, 3.0, 2.2, sh(base, 0.86))
		cv.rect(x + 0.4, y + 3.7, 2.2, 0.9, sh(base, 0.70))
		cv.rect(x, y + 1.5, 0.6, 2.2, sh(base, 1.15))
		x += 6.0
	cv.rect(x0, y + 1.5, x1 - x0, 0.8, Color(0, 0, 0, 0.22))

## Aspillera con marco de piedra clara.
static func slit(cv: Cv, x: float, y: float, h: float, base: Color) -> void:
	cv.rect(x - 1.8, y - 1.2, 5.6, h + 2.4, sh(base, 1.16))
	cv.rect(x - 1.0, y - 0.8, 3.9, h + 1.6, INK)
	cv.rect(x, y, 2.0, h, Color(0.05, 0.04, 0.05))
	cv.rect(x - 1.8, y - 1.2, 5.6, 0.7, sh(base, 1.32))

## Vidriera ojival: marco de piedra clara, plomos y cristales de colores con luz cálida detrás.
static func stained(cv: Cv, x: float, y: float, w: float, h: float, base: Color) -> void:
	cv.rect(x - 2.2, y - 0.4, w + 4.4, h + 1.0, sh(base, 1.18))
	cv.disc(x + w * 0.5, y, w * 0.5 + 2.2, sh(base, 1.18))
	cv.rect(x - 2.2, y - 0.4, 0.8, h + 1.0, sh(base, 1.34))
	cv.rect(x - 1.0, y - 0.4, w + 2.0, h + 0.6, INK)
	cv.disc(x + w * 0.5, y, w * 0.5 + 1.0, INK)
	var blue := Color(0.22, 0.34, 0.72)
	cv.rect(x, y, w, h, blue)
	cv.disc(x + w * 0.5, y, w * 0.5, Color(0.28, 0.42, 0.80))
	cv.rect(x, y + h * 0.34, w, h * 0.33, Color(0.78, 0.22, 0.20))
	cv.rect(x, y + h * 0.67, w, h * 0.33, Color(0.26, 0.56, 0.38))
	cv.disc(x + w * 0.5, y + h * 0.50, w * 0.23, Color(0.94, 0.76, 0.28))
	cv.rect(x + 0.4, y, w * 0.32, h, Color(1, 1, 1, 0.10))
	cv.rect(x + w * 0.5 - 0.35, y - w * 0.45, 0.7, h + w * 0.45, INK)
	cv.rect(x, y + h * 0.34 - 0.3, w, 0.6, INK)
	cv.rect(x, y + h * 0.67 - 0.3, w, 0.6, INK)
	cv.rect(x - 1.2, y + h + 0.5, w + 2.4, 1.3, sh(base, 0.80))

## Almenas repartidas de forma uniforme entre x0 y x1.
static func merlons(cv: Cv, x0: float, x1: float, y: float, base: Color, n: int, gap: float, h: float = 8.0) -> void:
	var w := ((x1 - x0) - float(n - 1) * gap) / float(n)
	for i in n:
		var x := x0 + float(i) * (w + gap)
		cv.rect(x - 0.9, y - 0.9, w + 1.8, h + 0.9, INK)
		cv.rect(x, y, w, h, sh(base, 1.10))
		cv.rect(x, y, w, 1.1, sh(base, 1.30))
		cv.rect(x, y, 0.8, h, sh(base, 1.25))
		cv.rect(x + w - 1.2, y, 1.2, h, sh(base, 0.82))

## Tejado cónico de pizarra (torreones y campanarios).
static func cone(cv: Cv, cx: float, y_base: float, hw: float, y_tip: float, col: Color) -> void:
	cv.tri(cx - hw - 1.2, y_base + 0.6, cx + hw + 1.2, y_base + 0.6, cx, y_tip - 1.4, INK)
	cv.tri(cx - hw, y_base, cx + hw, y_base, cx, y_tip, col)
	cv.tri(cx, y_tip, cx + hw, y_base, cx + hw * 0.15, y_base, sh(col, 0.66))
	cv.tri(cx - hw, y_base, cx - hw * 0.30, y_base, cx, y_tip, sh(col, 1.16))
	var n := 5
	for i in range(1, n):
		var t := float(i) / float(n)
		var hwt := hw * t
		cv.line(cx - hwt, lerpf(y_tip, y_base, t), cx + hwt, lerpf(y_tip, y_base, t), 0.7, sh(col, 0.60))
	cv.rect(cx - hw - 1.4, y_base - 1.0, hw * 2.0 + 2.8, 2.2, sh(col, 0.72))
	cv.rect(cx - hw - 1.4, y_base - 1.0, hw * 2.0 + 2.8, 0.7, sh(col, 1.14))

## Cruz dorada.
static func cross(cv: Cv, x: float, y: float, h: float = 5.0) -> void:
	var gold := Color(0.90, 0.74, 0.26)
	cv.rect(x - 1.0, y - 0.6, 2.0, h + 1.2, INK)
	cv.rect(x - 1.9, y + h * 0.28 - 0.6, 3.8, 2.2, INK)
	cv.rect(x - 0.4, y, 0.8, h, gold)
	cv.rect(x - 1.3, y + h * 0.28, 2.6, 0.8, gold)

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

## Puesto de mercado: mostrador de madera con mercancías bajo un toldo de tela (las rayas del equipo van en `stall_stripes`).
static func stall(cv: Cv, x: float, y: float, w: float, kind: int) -> void:
	var cloth := Color(0.93, 0.89, 0.78)
	# postes y mostrador
	cv.rect(x + 1.0, y + 8, 2.2, 24, INK)
	cv.rect(x + 1.4, y + 8, 1.4, 24, WOOD)
	cv.rect(x + w - 3.2, y + 8, 2.2, 24, INK)
	cv.rect(x + w - 2.8, y + 8, 1.4, 24, WOOD)
	cv.rect(x + 0.4, y + 19, w - 0.8, 12, INK)
	planks(cv, x + 1.0, y + 20, w - 2.0, 10, PLANK, 60 + kind, false)
	cv.rect(x - 0.6, y + 18, w + 1.2, 2.6, INK)
	cv.rect(x, y + 18.4, w, 1.8, sh(PLANK, 1.25))
	# mercancías sobre el mostrador
	if kind == 0:
		for i in 6:
			var ax := x + 5.0 + float(i) * 5.2
			cv.disc(ax, y + 16.0 - float(i % 2) * 1.6, 2.4, Color(0.42, 0.04, 0.06))
			cv.disc(ax, y + 16.0 - float(i % 2) * 1.6, 2.0, Color(0.84, 0.14, 0.14))
			cv.disc(ax - 0.6, y + 15.2 - float(i % 2) * 1.6, 0.7, Color(1.0, 0.7, 0.7))
		sack(cv, x + w - 7.0, y + 17.6, 4.0)
	else:
		for i in 4:
			var bx := x + 5.0 + float(i) * 7.0
			var cc: Color = [Color(0.20, 0.34, 0.62), Color(0.62, 0.20, 0.22), Color(0.22, 0.52, 0.30), Color(0.78, 0.62, 0.20)][i]
			cv.rect(bx, y + 12.0, 5.4, 6.4, INK)
			cv.rect(bx + 0.5, y + 12.5, 4.4, 5.4, cc)
			cv.ell(bx + 2.7, y + 12.6, 2.2, 0.9, sh(cc, 1.3))
		crate(cv, x + w - 7.0, y + 17.0, 5)
	# toldo: tela crema inclinada con flecos
	var tl := Vector2(x - 3.0, y)
	var tr := Vector2(x + w + 3.0, y)
	var bl := Vector2(x - 6.0, y + 10.0)
	var br := Vector2(x + w + 6.0, y + 10.0)
	cv.quad(tl + Vector2(0, -1.4), tr + Vector2(0, -1.4), br + Vector2(0.8, 0.6), bl + Vector2(-0.8, 0.6), INK)
	cv.quad(tl, tr, br, bl, cloth)
	cv.quad(tl, tr, tr.lerp(br, 0.22), tl.lerp(bl, 0.22), sh(cloth, 1.1))
	cv.quad(tl.lerp(bl, 0.8), tr.lerp(br, 0.8), br, bl, sh(cloth, 0.80))

static func stall_stripes(cv: Cv, x: float, y: float, w: float, c: Color) -> void:
	var tl := Vector2(x - 3.0, y)
	var tr := Vector2(x + w + 3.0, y)
	var bl := Vector2(x - 6.0, y + 10.0)
	var br := Vector2(x + w + 6.0, y + 10.0)
	var n := 8
	for i in range(0, n, 2):
		var f0 := float(i) / float(n)
		var f1 := float(i + 1) / float(n)
		cv.quad(tl.lerp(tr, f0), tl.lerp(tr, f1), bl.lerp(br, f1), bl.lerp(br, f0), c)
		cv.quad(tl.lerp(bl, 0.8).lerp(tr.lerp(br, 0.8), f0), tl.lerp(bl, 0.8).lerp(tr.lerp(br, 0.8), f1), bl.lerp(br, f1), bl.lerp(br, f0), sh(c, 0.78))
	# flecos
	for i in 9:
		var fx := bl.x + 1.5 + float(i) * (br.x - bl.x - 3.0) / 8.0
		cv.disc(fx, y + 10.8, 1.5, c if i % 2 == 0 else Color(0.93, 0.89, 0.78))

static func paint_base(cv: Cv, type: String) -> void:
	match type:
		"casa":
			yard(cv, 32, 57, 29, 6, 1)
			cast_shadow(cv, 10, 52, 56, 26)
			side_face(cv, 50, 56, 36, 8, 5, sh(PLASTER, 0.70))
			stone(cv, 50, 51, 8, 5, STONE, 4, 3.0)
			stone(cv, 10, 51, 40, 5, STONE, 2, 3.0)
			moss(cv, 10, 56, 40, 5)
			timber(cv, 10, 36, 40, 15, PLASTER, WOOD, 3, 4)
			door(cv, 26, 42, 9, 14, PLANK, true)
			window(cv, 14, 41, 6, 6, Color(0.30, 0.42, 0.52), false, true)
			window(cv, 40, 41, 6, 6, Color(0.30, 0.42, 0.52), false, true)
			ivy(cv, 11.0, 56, 15, 8)
			eave_shadow(cv, 10, 50, 36)
			roof_side(cv, Vector2(55, 36), Vector2(63, 31), Vector2(47, 12), Vector2(43, 14), sh(TILE_RED, 0.66))
			tiles(cv, 5, 55, 36, 14, 12, TILE_RED, 7)
			dormer(cv, 31, 31, 9, TILE_RED)
			chimney(cv, 19, 6, 21, 6, STONE, 9)
		"mina":
			yard(cv, 32, 57, 29, 6, 4)
			cast_shadow(cv, 8, 56, 57, 22)
			# colina de roca con la boca de la galería, vigas de madera, vagoneta con mineral y montón de pepitas
			var rock := Color(0.52, 0.50, 0.50)
			var blobs := [Vector3(32, 38, 20), Vector3(15, 44, 11), Vector3(50, 44, 12), Vector3(23, 26, 12), Vector3(41, 27, 11)]
			for b: Vector3 in blobs:
				cv.disc(b.x, b.y, b.z + 1.2, INK)
			for b: Vector3 in blobs:
				cv.disc(b.x, b.y, b.z, sh(rock, 0.70))
			for b: Vector3 in blobs:
				cv.disc(b.x - 1.5, b.y - 2.0, b.z * 0.84, rock)
			for b: Vector3 in blobs:
				cv.disc(b.x - 3.0, b.y - 4.0, b.z * 0.46, sh(rock, 1.25))
			cv.line(28, 22, 24, 34, 0.9, Color(0.10, 0.09, 0.10, 0.7))
			cv.line(44, 24, 47, 36, 0.9, Color(0.10, 0.09, 0.10, 0.7))
			moss(cv, 14, 54, 12, 3, 0.7)
			# galería
			cv.disc(32, 42.5, 9.6, INK)
			cv.rect(22.4, 42.5, 19.2, 14.5, INK)
			cv.disc(32, 42.5, 8.4, Color(0.05, 0.04, 0.04))
			cv.rect(23.6, 42.5, 16.8, 13.5, Color(0.05, 0.04, 0.04))
			cv.rect(24.5, 52.0, 15.0, 4.0, Color(0.12, 0.10, 0.08))
			cv.disc(31, 47, 1.2, Color(0.95, 0.78, 0.25, 0.8))
			cv.disc(35, 50, 0.9, Color(0.95, 0.78, 0.25, 0.7))
			# marco de madera
			for px: float in [21.0, 40.0]:
				cv.rect(px - 0.6, 37.0, 4.2, 20.0, INK)
				cv.rect(px, 37.6, 3.0, 19.0, WOOD)
				cv.rect(px, 37.6, 1.0, 19.0, sh(WOOD, 1.3))
			cv.rect(18.6, 34.0, 26.8, 5.0, INK)
			cv.rect(19.2, 34.6, 25.6, 3.6, WOOD)
			cv.rect(19.2, 34.6, 25.6, 1.0, sh(WOOD, 1.3))
			cv.line(24, 45, 29, 38.4, 1.4, sh(WOOD, 0.8))
			cv.line(40, 45, 35, 38.4, 1.4, sh(WOOD, 0.8))
			torch(cv, 17.5, 46)
			# vías hasta el borde
			cv.line(28.5, 52, 24.5, 63, 1.0, Color(0.34, 0.30, 0.28))
			cv.line(35.5, 52, 39.5, 63, 1.0, Color(0.34, 0.30, 0.28))
			for ty: float in [55.0, 59.0]:
				var k: float = (ty - 52.0) / 11.0
				cv.rect(28.5 - 4.0 * k - 2.0, ty, 7.0 + 8.0 * k, 1.4, sh(WOOD, 0.9))
			# vagoneta con mineral
			cv.ell(48, 56.5, 7, 2, Color(0, 0, 0, 0.28))
			cv.rect(41.5, 49.4, 13, 7.4, INK)
			cv.rect(42.2, 50.2, 11.6, 5.8, PLANK)
			cv.rect(42.2, 50.2, 11.6, 1.2, sh(PLANK, 1.3))
			cv.disc(44.5, 57, 2.0, INK)
			cv.disc(44.5, 57, 1.3, Color(0.44, 0.44, 0.48))
			cv.disc(51.5, 57, 2.0, INK)
			cv.disc(51.5, 57, 1.3, Color(0.44, 0.44, 0.48))
			for g: Vector3 in [Vector3(44.5, 49.4, 2.5), Vector3(48.5, 48.4, 3.0), Vector3(52.0, 49.6, 2.3)]:
				cv.disc(g.x, g.y, g.z, Color(0.50, 0.38, 0.08))
				cv.disc(g.x - 0.4, g.y - 0.5, g.z * 0.82, Color(0.95, 0.78, 0.22))
				cv.disc(g.x - 0.9, g.y - 1.0, g.z * 0.36, Color(1.0, 0.96, 0.62))
			# montón de pepitas y un pico
			for g: Vector3 in [Vector3(11, 57, 2.4), Vector3(15, 58, 2.0), Vector3(13, 55.4, 2.0)]:
				cv.disc(g.x, g.y, g.z + 0.5, INK)
				cv.disc(g.x, g.y, g.z, Color(0.95, 0.78, 0.22))
				cv.disc(g.x - 0.6, g.y - 0.7, g.z * 0.4, Color(1.0, 0.96, 0.62))
			cv.line(7.5, 49, 12, 60, 1.2, sh(WOOD, 0.85))
			cv.line(4.5, 51.5, 11, 49.2, 1.4, Color(0.55, 0.57, 0.62))
		"almacen":
			yard(cv, 32, 57, 29, 6, 2)
			cast_shadow(cv, 8, 50, 56, 24)
			side_face(cv, 50, 56, 34, 8, 5, sh(PLANK, 0.68))
			planks(cv, 8, 34, 42, 22, PLANK, 5, true)
			stone(cv, 8, 52, 42, 4, STONE, 6, 3.0)
			moss(cv, 8, 56, 42, 6, 0.8)
			door(cv, 22, 40, 14, 16, Color(0.50, 0.34, 0.18), false, true)
			cv.line(22.5, 40.5, 35.5, 55.5, 1.4, Color(0.30, 0.2, 0.1))
			cv.line(35.5, 40.5, 22.5, 55.5, 1.4, Color(0.30, 0.2, 0.1))
			sack(cv, 26, 52, 3.4)
			sack(cv, 32, 53, 3.0)
			# polea de carga con cuerda y farol
			cv.rect(40, 37, 12, 2.2, INK)
			cv.rect(40.4, 37.4, 11.2, 1.4, Color(0.50, 0.34, 0.18))
			cv.line(50, 39, 50, 45, 0.7, Color(0.78, 0.68, 0.46))
			cv.disc(50, 46, 1.6, Color(0.95, 0.75, 0.30))
			eave_shadow(cv, 8, 50, 34)
			roof_side(cv, Vector2(55, 34), Vector2(63, 29), Vector2(46, 14), Vector2(43, 16), sh(SHINGLE, 0.66))
			tiles(cv, 3, 55, 34, 16, 9, SHINGLE, 11, 3.6)
			barrel(cv, 14, 53, 3.6)
			barrel(cv, 20, 55, 3.0)
			crate(cv, 41, 50, 6)
			sack(cv, 50, 53, 3.4)
		"centro":
			yard(cv, 48, 87, 45, 9, 7, true)
			cast_shadow(cv, 10, 78, 88, 40)
			# torre del campanario (queda detrás del tejado)
			stone(cv, 39, 30, 18, 30, STONE, 12, 4.0)
			quoins(cv, 39, 57, 30, 28, STONE, 25, 3.6, 4.0)
			cv.rect(38, 28, 20, 3, sh(STONE, 1.15))
			stone(cv, 37, 18, 22, 12, STONE, 13, 4.0)
			for ax in [41.0, 51.0]:
				cv.rect(ax - 0.9, 19.0, 6.8, 11.0, INK)
				cv.rect(ax, 20.0, 5.0, 10.0, Color(0.12, 0.09, 0.08))
				cv.disc(ax + 2.5, 20.0, 2.5, Color(0.12, 0.09, 0.08))
				cv.rect(ax + 0.3, 27.4, 4.4, 0.9, sh(STONE, 1.2))
			cv.disc(44, 25, 2.1, Color(0.86, 0.66, 0.22))
			cv.rect(43.4, 22, 1.2, 2, Color(0.3, 0.2, 0.1))
			tiles(cv, 34, 62, 18, 6, 12, SLATE, 14, 3.4)
			# sala principal
			side_face(cv, 76, 88, 62, 12, 7, sh(PLASTER, 0.70))
			stone(cv, 76, 80, 12, 8, STONE, 15, 4.0)
			stone(cv, 12, 80, 64, 8, STONE, 16, 4.0)
			moss(cv, 12, 88, 64, 16, 0.9)
			timber(cv, 12, 62, 64, 18, PLASTER, WOOD, 17, 6)
			door(cv, 40, 66, 16, 22, PLANK, true, true)
			cv.rect(36, 86, 24, 2.6, Color(0.74, 0.72, 0.68))
			cv.rect(38, 88, 20, 2.0, Color(0.62, 0.60, 0.56))
			cv.rect(34, 84.6, 28, 1.4, Color(0.80, 0.78, 0.74))
			window(cv, 18, 68, 8, 8, Color(0.30, 0.42, 0.52), false, true)
			window(cv, 66, 68, 8, 8, Color(0.30, 0.42, 0.52), false, true)
			torch(cv, 36.5, 71)
			torch(cv, 59.5, 71)
			eave_shadow(cv, 12, 76, 62)
			roof_side(cv, Vector2(82, 62), Vector2(94, 55), Vector2(78, 31), Vector2(66, 38), sh(TILE_RED, 0.66), 5)
			tiles(cv, 6, 82, 62, 38, 16, TILE_RED, 18, 4.0)
			dormer(cv, 28, 57, 10, TILE_RED)
			dormer(cv, 64, 57, 10, TILE_RED)
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
			quoins(cv, 8, 78, 62, 26, STONE_BLUE, 26, 4.4, 4.5)
			# zócalo y contrafuertes
			cv.rect(8, 84, 70, 4, sh(STONE_BLUE, 1.08))
			cv.rect(8, 84, 70, 0.8, sh(STONE_BLUE, 1.28))
			for bx in [29.0, 50.0]:
				cv.rect(bx, 61, 3.0, 24, sh(STONE_BLUE, 0.80))
				cv.rect(bx, 61, 0.9, 24, sh(STONE_BLUE, 1.15))
			moss(cv, 8, 88, 70, 21, 0.9)
			cv.rect(8, 60, 70, 2.8, sh(WOOD, 1.0))
			door(cv, 34, 68, 14, 20, Color(0.34, 0.22, 0.12), false, true)
			cv.rect(30, 86, 22, 2.6, Color(0.74, 0.72, 0.68))
			window(cv, 60, 70, 8, 8, Color(0.30, 0.34, 0.42), true)
			window(cv, 16, 70, 8, 8, Color(0.30, 0.34, 0.42), true)
			torch(cv, 31.5, 72)
			torch(cv, 50.5, 72)
			eave_shadow(cv, 8, 78, 60)
			roof_side(cv, Vector2(83, 60), Vector2(95, 53), Vector2(79, 31), Vector2(69, 34), sh(SLATE, 0.66), 5)
			tiles(cv, 3, 83, 60, 34, 14, SLATE, 23, 4.0)
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
		"herreria":
			yard(cv, 48, 88, 45, 8, 41)
			cast_shadow(cv, 8, 78, 88, 34)
			side_face(cv, 78, 88, 58, 12, 7, sh(STONE, 0.60))
			stone(cv, 8, 58, 70, 30, sh(STONE, 0.84), 42, 4.5)
			quoins(cv, 8, 78, 60, 28, sh(STONE, 0.92), 43, 4.4, 4.5)
			cv.rect(8, 84, 70, 4, sh(STONE, 1.02))
			cv.rect(8, 84, 70, 0.8, sh(STONE, 1.25))
			moss(cv, 8, 88, 70, 44, 0.5)
			cv.rect(8, 58, 70, 2.8, WOOD)
			# fragua: boca de la forja con brasas y llamas
			cv.rect(38, 64, 26, 24, INK)
			cv.rect(39.4, 65.4, 23.2, 22.6, Color(0.16, 0.06, 0.04))
			cv.disc(51, 66.6, 11.6, INK)
			cv.disc(51, 66.8, 10.4, Color(0.16, 0.06, 0.04))
			cv.ell(51, 86, 10, 3.4, Color(0.78, 0.30, 0.06))
			cv.ell(51, 85.4, 7, 2.4, Color(1.0, 0.62, 0.14))
			cv.tri(44, 86, 46.4, 74, 49, 86, Color(0.95, 0.42, 0.08))
			cv.tri(48, 86, 51.4, 70, 55, 86, Color(1.0, 0.56, 0.10))
			cv.tri(53, 86, 56, 75, 59, 86, Color(0.95, 0.42, 0.08))
			cv.tri(49.6, 86, 51.4, 77, 53.4, 86, Color(1.0, 0.86, 0.34))
			cv.ell(51, 80, 15, 10, Color(1.0, 0.5, 0.1, 0.10))
			cv.rect(34, 86, 34, 2.6, Color(0.60, 0.58, 0.55))
			window(cv, 14, 68, 8, 8, Color(0.28, 0.30, 0.36), true)
			torch(cv, 33.5, 70)
			torch(cv, 68.5, 70)
			eave_shadow(cv, 8, 78, 58)
			roof_side(cv, Vector2(83, 58), Vector2(95, 51), Vector2(79, 30), Vector2(69, 33), sh(SLATE, 0.62), 5)
			tiles(cv, 3, 83, 58, 32, 14, sh(SLATE, 0.88), 45, 4.0)
			# chimenea ancha de la fragua
			chimney(cv, 56, 12, 40, 11, Color(0.46, 0.43, 0.41), 46)
			cv.rect(54.6, 11, 13.8, 2.8, INK)
			cv.ell(61.5, 10, 6.0, 1.8, Color(0.12, 0.08, 0.06))
			# yunque, tajo y herramientas
			cv.rect(14, 84, 6, 4.4, WOOD)
			cv.rect(10, 80.4, 14, 3.4, INK)
			cv.rect(10.6, 80.8, 12.8, 2.4, Color(0.34, 0.35, 0.39))
			cv.tri(10.6, 81.2, 5.4, 82.4, 10.6, 83.4, Color(0.34, 0.35, 0.39))
			cv.rect(11.4, 80.8, 11, 0.8, Color(0.62, 0.64, 0.70))
			cv.rect(14.4, 83.4, 5, 2.6, Color(0.26, 0.27, 0.31))
			cv.line(24.6, 74, 22.4, 80.4, 1.1, WOOD)
			cv.rect(21.6, 73, 5.6, 2.8, Color(0.40, 0.41, 0.45))
			# rastrillo de espadas y barril de agua
			cv.rect(70, 74, 1.4, 14, WOOD)
			cv.rect(81, 74, 1.4, 14, WOOD)
			for sx in [72.6, 75.2, 77.8, 80.0]:
				cv.line(sx, 86, sx + 0.4, 71, 1.0, Color(0.72, 0.74, 0.80))
				cv.rect(sx - 1.0, 85.4, 2.4, 1.2, Color(0.50, 0.36, 0.18))
			barrel(cv, 27, 86, 3.8)
			crate(cv, 36, 87, 5)
		"mercado":
			yard(cv, 48, 87, 45, 9, 51, true)
			cast_shadow(cv, 8, 88, 88, 30)
			# casa del mercader al fondo
			side_face(cv, 76, 56, 28, 8, 5, sh(PLASTER, 0.70))
			stone(cv, 20, 50, 56, 6, STONE, 52, 3.0)
			timber(cv, 20, 28, 56, 22, PLASTER, WOOD, 53, 5)
			door(cv, 42, 36, 12, 18, PLANK, true, true)
			window(cv, 26, 33, 6, 6, Color(0.30, 0.42, 0.52), false, true)
			window(cv, 64, 33, 6, 6, Color(0.30, 0.42, 0.52), false, true)
			eave_shadow(cv, 20, 76, 28)
			roof_side(cv, Vector2(81, 28), Vector2(89, 23), Vector2(73, 9), Vector2(69, 11), sh(TILE_RED, 0.66))
			tiles(cv, 15, 81, 28, 10, 8, TILE_RED, 54, 3.8)
			chimney(cv, 28, 4, 18, 5, STONE, 55)
			# dos puestos con toldo y mercancías
			stall(cv, 7.0, 56.0, 36.0, 0)
			stall(cv, 53.0, 56.0, 36.0, 1)
			# balanza del mercader en el centro
			cv.rect(46.4, 64, 1.4, 20, WOOD)
			cv.rect(41.6, 64, 11, 1.4, WOOD)
			cv.line(42.2, 65, 41.0, 71, 0.5, Color(0.8, 0.7, 0.4))
			cv.line(51.8, 65, 53.0, 71, 0.5, Color(0.8, 0.7, 0.4))
			cv.ell(41.0, 71.4, 3.0, 1.0, Color(0.86, 0.68, 0.22))
			cv.ell(53.0, 71.4, 3.0, 1.0, Color(0.86, 0.68, 0.22))
			cv.disc(47.1, 63.4, 1.6, Color(0.86, 0.68, 0.22))
			barrel(cv, 44, 86, 3.4)
			sack(cv, 51, 87, 3.4)
		"arqueria":
			yard(cv, 48, 88, 45, 8, 31)
			cast_shadow(cv, 10, 76, 86, 34)
			side_face(cv, 74, 86, 56, 12, 7, sh(PLANK, 0.62))
			planks(cv, 10, 56, 64, 30, sh(PLANK, 0.62), 32, true)
			eave_shadow(cv, 10, 74, 54, 9.0, 0.5)
			# arcos y carcajes colgados al fondo
			for bx in [20.0, 32.0, 44.0, 56.0]:
				cv.line(bx, 66, bx - 2.0, 74, 1.6, Color(0.70, 0.52, 0.30))
				cv.line(bx - 2.0, 74, bx, 82, 1.6, Color(0.70, 0.52, 0.30))
				cv.line(bx, 66, bx, 82, 0.6, Color(0.9, 0.9, 0.85))
			cv.rect(61.4, 64, 4.2, 9, INK)
			cv.rect(62.0, 64.6, 3.0, 8, Color(0.46, 0.28, 0.14))
			for fx in [62.4, 63.6, 64.8]:
				cv.line(fx, 64.4, fx, 62.0, 0.8, Color(0.85, 0.85, 0.80))
			for px in [10.0, 40.0, 72.0]:
				cv.rect(px - 2.4, 54, 5.0, 33, INK)
				cv.rect(px - 1.8, 54, 3.8, 33, Color(0.50, 0.35, 0.19))
				cv.rect(px - 1.8, 54, 1.3, 33, Color(0.66, 0.48, 0.27))
				cv.rect(px + 1.0, 54, 0.9, 33, Color(0.36, 0.24, 0.12))
				cv.rect(px - 3.4, 84, 7.0, 3.2, Color(0.55, 0.53, 0.5))
				cv.rect(px - 3.4, 84, 7.0, 0.8, Color(0.72, 0.70, 0.66))
			roof_side(cv, Vector2(80, 54), Vector2(92, 47), Vector2(76, 28), Vector2(66, 30), sh(STRAW, 0.62), 5)
			thatch(cv, 4, 80, 54, 30, 14, STRAW, 33)
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
			moss(cv, 10, 88, 64, 43, 0.8)
			eave_shadow(cv, 10, 74, 56, 8.0, 0.5)
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
			# ventanuco del henil con polea
			cv.rect(37.4, 44, 11, 11, INK)
			cv.rect(38.4, 45, 9, 9, Color(0.14, 0.09, 0.06))
			cv.rect(38.4, 51, 9, 3, Color(0.82, 0.68, 0.28))
			cv.rect(36.4, 42.6, 13, 1.6, Color(0.27, 0.17, 0.09))
			cv.line(43, 44, 43, 49, 0.6, Color(0.78, 0.68, 0.46))
			# veleta
			cv.line(42, 22, 42, 14, 0.8, Color(0.20, 0.17, 0.14))
			cv.tri(42, 12.4, 46.6, 14.6, 42, 16.4, Color(0.18, 0.16, 0.14))
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
			moss(cv, 8, 88, 68, 64, 0.8)
			# nave abierta con el interior en sombra
			cv.rect(15, 61, 54, 25, INK)
			cv.rect(16, 62, 52, 24, Color(0.17, 0.12, 0.08))
			cv.rect(16, 62, 52, 5, Color(0, 0, 0, 0.35))
			cv.ell(42, 80, 20, 5, Color(0.95, 0.60, 0.20, 0.10))      # brillo de la fragua
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
				cv.rect(px + 1.0, 54, 0.9, 33, Color(0.36, 0.24, 0.12))
			eave_shadow(cv, 8, 76, 54, 9.0, 0.5)
			roof_side(cv, Vector2(82, 54), Vector2(94, 47), Vector2(78, 28), Vector2(68, 30), sh(SHINGLE, 0.62), 5)
			tiles(cv, 3, 82, 54, 30, 14, SHINGLE, 65, 4.0)
			# troncos apilados y tablones
			for r in 3:
				for k in range(3 - r):
					var lx := 80.0 + k * 5.0 + r * 2.5
					var ly := 86.0 - r * 4.4
					cv.disc(lx, ly, 2.8, INK)
					cv.disc(lx, ly, 2.2, Color(0.74, 0.55, 0.30))
					cv.disc(lx, ly, 1.4, Color(0.62, 0.44, 0.22))
					cv.disc(lx, ly, 0.6, Color(0.52, 0.36, 0.18))
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
			moss(cv, 10, 88, 66, 75, 1.0)
			planks(cv, 10, 56, 66, 22, weather, 73, true)
			# portalón de carga y letrero con ancla
			door(cv, 36, 62, 18, 16, PLANK, false, true)
			cv.rect(32, 76, 26, 2.6, Color(0.74, 0.72, 0.68))
			cv.line(45, 56, 45, 61, 1.2, INK)
			cv.disc(45, 52.5, 5.4, INK)
			cv.disc(45, 52.5, 4.6, Color(0.84, 0.80, 0.66))
			cv.line(45, 49.5, 45, 56, 1.2, Color(0.22, 0.24, 0.30))
			cv.line(42, 52.2, 48, 52.2, 1.1, Color(0.22, 0.24, 0.30))
			cv.line(42.2, 54.4, 45, 56.4, 1.1, Color(0.22, 0.24, 0.30))
			cv.line(47.8, 54.4, 45, 56.4, 1.1, Color(0.22, 0.24, 0.30))
			cv.disc(45, 49.6, 1.0, Color(0.22, 0.24, 0.30))
			window(cv, 16, 64, 6, 6, Color(0.28, 0.40, 0.50), true)
			window(cv, 64, 64, 6, 6, Color(0.28, 0.40, 0.50), true)
			eave_shadow(cv, 10, 76, 56)
			roof_side(cv, Vector2(82, 56), Vector2(94, 49), Vector2(78, 28), Vector2(66, 32), sh(SLATE, 0.66), 5)
			tiles(cv, 4, 82, 56, 30, 14, SLATE, 74, 4.0)
			# grúa de carga a la derecha
			cv.rect(86.4, 38, 3.6, 50, INK)
			cv.rect(87.0, 38, 2.4, 50, Color(0.46, 0.31, 0.16))
			cv.rect(87.0, 38, 0.8, 50, Color(0.62, 0.44, 0.24))
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
			quoins(cv, 17, 47, 25, 28, STONE, 53, 3.6, 4.2)
			# zócalo con talud
			cv.rect(15, 51, 34, 5, sh(STONE, 1.06))
			cv.rect(15, 51, 34, 0.9, sh(STONE, 1.28))
			cv.rect(15, 55, 34, 1.0, Color(0, 0, 0, 0.28))
			moss(cv, 15, 56, 34, 55, 1.0)
			cv.rect(17, 22, 30, 2.6, sh(STONE, 0.8))
			# parapeto saliente con matacanes y almenas
			cv.rect(13, 14, 38, 8, INK)
			stone(cv, 14, 15, 36, 6, sh(STONE, 1.08), 52, 3.0)
			corbels(cv, 14, 50, 21.2, STONE)
			for mx in [14.0, 22.0, 30.0, 38.0, 45.0]:
				cv.rect(mx - 0.9, 8.0, 6.8, 8.0, INK)
				cv.rect(mx, 9.0, 5.0, 7.0, sh(STONE, 1.12))
				cv.rect(mx, 9.0, 5.0, 1.2, sh(STONE, 1.3))
				cv.rect(mx, 9.0, 0.8, 7.0, sh(STONE, 1.25))
			# troneras y puerta
			for sp in [Vector2(30.5, 28), Vector2(23, 40), Vector2(38, 40)]:
				slit(cv, sp.x, sp.y, 9.0, STONE)
			door(cv, 27, 45, 10, 11, PLANK, true)
		"monasterio":
			yard(cv, 48, 88, 45, 8, 81, true)
			cast_shadow(cv, 8, 80, 88, 52)
			# nave
			side_face(cv, 80, 88, 62, 10, 6, sh(STONE, 0.66))
			stone(cv, 28, 62, 52, 26, STONE, 82, 4.5)
			quoins(cv, 28, 80, 64, 24, STONE, 83, 4.0, 4.5)
			cv.rect(28, 84, 52, 4, sh(STONE, 1.08))
			cv.rect(28, 84, 52, 0.8, sh(STONE, 1.28))
			moss(cv, 28, 88, 52, 84, 0.9)
			cv.rect(28, 62, 52, 2.6, sh(STONE, 0.84))
			door(cv, 46, 72, 10, 16, PLANK, true, true)
			cv.rect(41, 86, 20, 2.4, Color(0.74, 0.72, 0.68))
			cv.rect(43, 88, 16, 1.8, Color(0.62, 0.60, 0.56))
			stained(cv, 35.0, 69, 4.6, 10, STONE)
			stained(cv, 68.0, 69, 4.6, 10, STONE)
			torch(cv, 42.5, 76)
			torch(cv, 60.5, 76)
			eave_shadow(cv, 28, 80, 62)
			roof_side(cv, Vector2(84, 62), Vector2(94, 56), Vector2(82, 37), Vector2(72, 40), sh(TILE_RED, 0.66), 5)
			tiles(cv, 24, 84, 62, 40, 12, TILE_RED, 85, 4.0)
			dormer(cv, 56, 58, 8, TILE_RED)
			# campanario delante de la nave
			stone(cv, 8, 28, 22, 60, STONE, 86, 4.5)
			quoins(cv, 8, 30, 30, 56, STONE, 87, 3.6, 4.4)
			cv.rect(8, 28, 2.0, 60, Color(1, 1, 1, 0.09))
			cv.rect(25, 28, 5.0, 60, Color(0, 0, 0, 0.14))
			cv.rect(6, 82, 26, 6, sh(STONE, 1.06))
			cv.rect(6, 82, 26, 0.9, sh(STONE, 1.28))
			cv.rect(6, 87, 26, 1.0, Color(0, 0, 0, 0.28))
			moss(cv, 6, 88, 26, 88, 1.0)
			ivy(cv, 8, 86, 30, 89)
			cv.rect(6, 25, 26, 3.2, sh(STONE, 1.12))
			cv.rect(6, 25, 26, 0.8, sh(STONE, 1.32))
			cv.rect(7, 47, 24, 2.0, sh(STONE, 1.10))
			cv.rect(7, 47, 24, 0.6, sh(STONE, 1.30))
			for ax in [11.5, 20.0]:
				cv.rect(ax - 0.9, 32.0, 6.8, 13.0, INK)
				cv.rect(ax, 33.0, 5.0, 12.0, Color(0.12, 0.09, 0.08))
				cv.disc(ax + 2.5, 33.0, 2.5, Color(0.12, 0.09, 0.08))
				cv.rect(ax - 0.4, 44.2, 5.8, 1.2, sh(STONE, 1.2))
			cv.disc(14.0, 39.0, 2.4, Color(0.86, 0.62, 0.20))
			cv.rect(13.6, 35.5, 0.8, 1.6, Color(0.30, 0.20, 0.10))
			cv.disc(14.0, 41.6, 0.7, Color(0.30, 0.20, 0.10))
			stained(cv, 17.0, 63, 4.4, 10, STONE)
			slit(cv, 17.8, 53.0, 6.0, STONE)
			cone(cv, 19, 26, 15.0, 4, SLATE)
			cross(cv, 19, -0.5, 5.0)
			# huerto de hierbas
			for bx in [60.0, 76.0]:
				cv.rect(bx - 0.9, 89.1, 13.8, 6.8, INK)
				cv.rect(bx, 90, 12, 5, Color(0.36, 0.25, 0.14))
				cv.rect(bx, 90, 12, 1.0, Color(0.50, 0.36, 0.20))
				for k in 5:
					cv.disc(bx + 1.6 + k * 2.3, 92.0, 1.2, Color(0.28, 0.50, 0.20))
					cv.disc(bx + 1.2 + k * 2.3, 91.6, 0.6, Color(0.46, 0.68, 0.30))
					cv.disc(bx + 1.6 + k * 2.3, 94.0, 0.9, Color(0.34, 0.56, 0.24))
			cv.disc(66.0, 91.0, 0.9, Color(0.92, 0.80, 0.30))
			cv.disc(82.0, 92.6, 0.9, Color(0.90, 0.40, 0.55))
			barrel(cv, 34, 90, 3.4)
		"castillo":
			yard(cv, 64, 119, 60, 9, 91, true)
			cast_shadow(cv, 4, 118, 120, 84)
			# torre del homenaje (detrás de las murallas)
			stone(cv, 40, 14, 48, 50, STONE_BLUE, 92, 4.6)
			quoins(cv, 40, 88, 16, 46, STONE_BLUE, 93, 4.0, 4.5)
			cv.rect(40, 14, 48, 2.6, sh(STONE_BLUE, 0.84))
			cv.rect(38, 13, 52, 10, INK)
			stone(cv, 39, 14, 50, 8, sh(STONE_BLUE, 1.08), 94, 3.0)
			corbels(cv, 39, 89, 21.2, STONE_BLUE)
			merlons(cv, 39, 89, 5, STONE_BLUE, 6, 3.6, 9.0)
			slit(cv, 50, 32, 9.0, STONE_BLUE)
			slit(cv, 76, 32, 9.0, STONE_BLUE)
			window(cv, 60.5, 36, 7, 9, Color(0.30, 0.34, 0.42), true)
			# muralla cortina
			stone(cv, 10, 66, 108, 52, STONE, 95, 4.8)
			cv.rect(10, 110, 108, 8, sh(STONE, 1.06))
			cv.rect(10, 110, 108, 0.9, sh(STONE, 1.28))
			cv.rect(10, 117, 108, 1.0, Color(0, 0, 0, 0.28))
			moss(cv, 10, 118, 108, 96, 1.1)
			cv.rect(9, 57, 110, 9, INK)
			stone(cv, 10, 58, 108, 7, sh(STONE, 1.08), 97, 3.0)
			corbels(cv, 10, 118, 64.2, STONE)
			merlons(cv, 12, 116, 48, STONE, 11, 3.6, 10.0)
			slit(cv, 30, 84, 10.0, STONE)
			slit(cv, 94, 84, 10.0, STONE)
			# casa de la puerta
			stone(cv, 50, 52, 28, 66, STONE, 100, 4.6)
			quoins(cv, 50, 78, 54, 62, STONE, 101, 3.8, 4.4)
			cv.rect(50, 52, 28, 2.4, sh(STONE, 0.84))
			cv.rect(48, 45, 32, 8, INK)
			stone(cv, 49, 46, 30, 6, sh(STONE, 1.08), 102, 3.0)
			corbels(cv, 49, 79, 51.2, STONE)
			merlons(cv, 49, 79, 37, STONE, 4, 3.4, 9.0)
			cv.rect(50, 110, 28, 8, sh(STONE, 1.06))
			cv.rect(50, 110, 28, 0.9, sh(STONE, 1.28))
			slit(cv, 62.0, 60, 8.0, STONE)
			# arco de entrada con rastrillo
			cv.rect(54.6, 91, 18.8, 27, sh(STONE, 1.16))
			cv.disc(64, 91, 9.4, sh(STONE, 1.16))
			cv.rect(54.6, 91, 1.0, 27, sh(STONE, 1.34))
			cv.rect(56.0, 91, 16.0, 27, INK)
			cv.disc(64, 91, 8.0, INK)
			cv.rect(57.2, 91, 13.6, 27, Color(0.10, 0.08, 0.07))
			cv.disc(64, 91, 6.8, Color(0.10, 0.08, 0.07))
			cv.rect(58, 96, 12, 8, Color(0.30, 0.20, 0.10, 0.45))
			var iron := Color(0.50, 0.52, 0.58)
			for gx in 5:
				var bxx := 58.4 + gx * 2.9
				cv.rect(bxx - 0.5, 90.0 + absf(float(gx) - 2.0) * 1.2, 1.0, 22.0 - absf(float(gx) - 2.0) * 1.2, iron)
				cv.tri(bxx - 0.9, 112.0, bxx + 0.9, 112.0, bxx, 115.0, iron)
			for gy in [96.0, 102.0, 108.0]:
				cv.rect(57.4, gy, 13.2, 1.0, iron)
				cv.rect(57.4, gy, 13.2, 0.4, sh(iron, 1.3))
			torch(cv, 52.2, 96)
			torch(cv, 75.8, 96)
			# torreones de esquina
			for tx: float in [2.0, 94.0]:
				var mid := tx + 16.0
				stone(cv, tx, 30, 32, 88, STONE, 103 + int(tx), 4.8)
				quoins(cv, tx, tx + 32.0, 34, 80, STONE, 105 + int(tx), 4.0, 4.6)
				cv.rect(tx, 30, 3.0, 88, Color(1, 1, 1, 0.09))
				cv.rect(tx + 23.0, 30, 9.0, 88, Color(0, 0, 0, 0.14))
				cv.rect(tx - 2.0, 106, 36.0, 12, sh(STONE, 1.06))
				cv.rect(tx - 2.0, 106, 36.0, 0.9, sh(STONE, 1.28))
				cv.rect(tx - 2.0, 117, 36.0, 1.0, Color(0, 0, 0, 0.28))
				moss(cv, tx - 2.0, 118, 36.0, 107 + int(tx), 1.0)
				cv.rect(tx - 2.0, 24, 36.0, 10, INK)
				stone(cv, tx - 1.0, 25, 34.0, 8, sh(STONE, 1.08), 108 + int(tx), 3.0)
				corbels(cv, tx - 1.0, tx + 33.0, 32.2, STONE)
				merlons(cv, tx - 1.0, tx + 33.0, 14, STONE, 4, 3.2, 11.0)
				slit(cv, mid - 1.0, 50, 10.0, STONE)
				slit(cv, mid - 1.0, 76, 10.0, STONE)
				window(cv, mid - 3.0, 90, 6, 8, Color(0.30, 0.34, 0.42), true)
			ivy(cv, 2, 116, 52, 111)
			barrel(cv, 44, 114, 4.0)
			barrel(cv, 49, 116, 3.4)
			crate(cv, 82, 110, 6)
			sack(cv, 90, 115, 4.0)
		"muralla":
			cast_shadow(cv, 4, 60, 56, 26)
			side_face(cv, 60, 56, 26, 4, 2, sh(STONE, 0.66))
			stone(cv, 4, 26, 56, 30, STONE, 60, 4.5)
			cv.rect(4, 50, 56, 6, sh(STONE, 1.06))                    # zócalo
			cv.rect(4, 50, 56, 0.9, sh(STONE, 1.28))
			cv.rect(4, 55, 56, 1.0, Color(0, 0, 0, 0.28))
			moss(cv, 4, 56, 56, 62, 1.0)
			cv.rect(3, 22, 58, 6, INK)
			stone(cv, 4, 23, 56, 4, sh(STONE, 1.08), 61, 3.0)
			corbels(cv, 4, 60, 27.0, STONE)
			slit(cv, 31, 36, 9.0, STONE)
			for mx in [4.0, 16.0, 28.0, 40.0, 52.0]:
				cv.rect(mx - 0.9, 14.0, 8.0, 9.0, INK)
				cv.rect(mx, 15.0, 6.2, 8.0, sh(STONE, 1.12))
				cv.rect(mx, 15.0, 6.2, 1.2, sh(STONE, 1.3))
				cv.rect(mx, 15.0, 0.8, 8.0, sh(STONE, 1.25))
		"puerta":
			cast_shadow(cv, 4, 60, 56, 40)
			stone(cv, 3, 14, 17, 42, STONE, 70, 4.5)
			stone(cv, 44, 14, 17, 42, STONE, 71, 4.5)
			quoins(cv, 3, 20, 20, 36, STONE, 74, 3.8, 4.2)
			quoins(cv, 44, 61, 20, 36, STONE, 75, 3.8, 4.2)
			stone(cv, 20, 22, 24, 8, sh(STONE, 1.05), 72, 4.0)
			moss(cv, 3, 56, 17, 76, 1.0)
			moss(cv, 44, 56, 17, 77, 1.0)
			for px in [3.0, 44.0]:
				cv.rect(px - 0.9, 8.0, 18.8, 6.0, INK)
				corbels(cv, px, px + 17.0, 14.0, STONE)
				for mx in [0.0, 6.5, 13.0]:
					cv.rect(px + mx, 8.5, 5.0, 6.0, sh(STONE, 1.12))
					cv.rect(px + mx, 8.5, 5.0, 1.1, sh(STONE, 1.3))
			slit(cv, 10.0, 30.0, 9.0, STONE)
			slit(cv, 51.0, 30.0, 9.0, STONE)
			cv.rect(20, 28, 24, 28, INK)
			cv.disc(32, 34, 12.0, INK)
			cv.rect(21, 34, 22, 22, Color(0.40, 0.26, 0.12))
			cv.disc(32, 34, 11.0, Color(0.40, 0.26, 0.12))
			for gx in range(1, 6):
				cv.rect(21 + gx * 3.6, 24, 0.8, 32, Color(0.25, 0.16, 0.08))
			cv.rect(21, 40, 22, 1.6, Color(0.22, 0.22, 0.25))
			cv.rect(21, 50, 22, 1.6, Color(0.22, 0.22, 0.25))
			for gx in range(1, 6):                                        # remaches de hierro
				cv.disc(21 + gx * 3.6 + 0.4, 40.8, 0.6, Color(0.55, 0.55, 0.60))
				cv.disc(21 + gx * 3.6 + 0.4, 50.8, 0.6, Color(0.55, 0.55, 0.60))

static func paint_team(cv: Cv, type: String, c: Color) -> void:
	var d := sh(c, 0.55)
	match type:
		"casa":
			pennant(cv, 40, 2, 16, c, 9.0, 6.0)
			cv.rect(27.4, 37.0, 6.2, 4.4, INK)
			cv.rect(28.0, 37.6, 5.0, 3.4, c)
		"mina":
			pennant(cv, 47, 6, 20, c, 9.0, 6.0)
			cv.rect(19.2, 38.0, 25.6, 1.6, c)
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
		"herreria":
			pennant(cv, 26, 22, 38, c, 9.0, 6.0)
			cv.rect(8, 58.4, 70, 2.0, c)
			banner(cv, 25, 66, 6.0, 12.0, c)
			banner(cv, 70, 70, 6.0, 12.0, c)
		"mercado":
			pennant(cv, 48, 2, 14, c, 9.0, 6.0)
			stall_stripes(cv, 7.0, 56.0, 36.0, c)
			stall_stripes(cv, 53.0, 56.0, 36.0, c)
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
		"monasterio":
			pennant(cv, 72, 28, 41, c, 9.0, 6.0)
			banner(cv, 19, 50, 7.0, 12.0, c)
			cv.rect(43.6, 70.2, 14.8, 1.8, c)
		"castillo":
			pennant(cv, 64, 0, 10, c, 10.0, 6.5)
			pennant(cv, 18, 2, 16, c, 9.0, 6.0)
			pennant(cv, 110, 2, 16, c, 9.0, 6.0)
			banner(cv, 64, 22, 8.0, 18.0, c)
			banner(cv, 44, 70, 6.0, 14.0, c)
			banner(cv, 84, 70, 6.0, 14.0, c)
			cv.rect(50, 86.0, 28, 2.0, c)
		"muralla", "puerta":
			pennant(cv, 32, 0, 14, c, 9.0, 6.0)
