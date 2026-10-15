class_name ArtUnits
extends RefCounted
## Personas, caballos, arietes y barcos pintados por código, con fotogramas de animación.
## Cada fotograma se pinta en tres capas (0 fondo, 1 equipo en grises, 2 frente): al dibujar, la capa de
## equipo se tiñe con el color del jugador, así que no hace falta una hoja por equipo.
## Luz desde arriba a la izquierda, igual que árboles y edificios.

const OUT := Color(0.07, 0.05, 0.04, 0.96)
const SKIN := Color(0.93, 0.76, 0.60)
const WSCALE := 0.62          # tamaño en el mundo = celda lógica × WSCALE
const PAD := 4                # margen entre celdas de la hoja (px de textura)

const F_IDLE := 0
const F_WALK := 1             # 1..4
const F_ACT := 5              # acciones (aldeano: 5 + 2·oficio + fase; soldados: 5 preparar, 6 golpe, 7 apuntar)
const TRADE_CHOP := 0
const TRADE_MINE := 1
const TRADE_FARM := 2
const TRADE_BUILD := 3

## [ancho, alto, ancla x, ancla y (pies o línea de flotación), factor de resolución, nº de fotogramas]
const CELLS := {
	"aldeano": [60, 64, 30, 60, 2.0, 13],
	"piquero": [88, 76, 30, 72, 2.0, 7],
	"espadachin": [76, 76, 30, 72, 2.0, 7],
	"arquero": [74, 76, 30, 72, 2.0, 8],
	"ballestero": [70, 76, 30, 72, 2.0, 8],
	"jinete": [104, 76, 40, 66, 2.0, 7],
	"explorador": [92, 76, 40, 66, 2.0, 7],
	"caballero": [112, 82, 42, 70, 2.0, 7],
	"ariete": [112, 56, 56, 52, 2.0, 7],
	"barco_pesca": [80, 60, 40, 44, 1.6, 6],
	"barco_transporte": [104, 70, 52, 58, 1.6, 4],
	"galera": [128, 64, 62, 46, 1.6, 6],
	"galeon": [132, 84, 62, 74, 1.6, 6],
}

static func sheet_size(type: String) -> Vector2i:
	var c: Array = CELLS[type]
	var k: float = c[4]
	var cw := int(ceil(float(c[0]) * k)) + PAD * 2
	var ch := int(ceil(float(c[1]) * k)) + PAD * 2
	return Vector2i(cw * int(c[5]), ch * 3)

static func cell_px(type: String) -> Vector2i:
	var c: Array = CELLS[type]
	var k: float = c[4]
	return Vector2i(int(ceil(float(c[0]) * k)), int(ceil(float(c[1]) * k)))

static func frame_rect(type: String, frame: int, layer: int) -> Rect2i:
	var cp := cell_px(type)
	return Rect2i(frame * (cp.x + PAD * 2) + PAD, layer * (cp.y + PAD * 2) + PAD, cp.x, cp.y)

## Pinta todos los fotogramas de un tipo y devuelve la hoja (3 filas de capas).
static func build_sheet(type: String) -> Image:
	var sz := sheet_size(type)
	var sheet := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	var c: Array = CELLS[type]
	for f in int(c[5]):
		var sp := Sp.new(int(c[0]), int(c[1]), float(c[4]))
		_paint(type, f, sp)
		for l in 3:
			var r := frame_rect(type, f, l)
			sheet.blit_rect(sp.im[l], Rect2i(0, 0, r.size.x, r.size.y), r.position)
	return sheet

# ---------------------------------------------------------------- lienzo de tres capas

class Sp extends RefCounted:
	var im: Array[Image] = []
	var k: float
	var L: int = 0
	var ox: float = 0.0       # desplazamiento del dibujo dentro de la celda (en píxeles lógicos)
	var oy: float = 0.0
	func _init(w: int, h: int, scale: float) -> void:
		k = scale
		for i in 3:
			var m := Image.create(int(ceil(w * scale)), int(ceil(h * scale)), false, Image.FORMAT_RGBA8)
			m.fill(Color(0, 0, 0, 0))
			im.append(m)
	func lay(i: int) -> Sp:
		L = i
		return self
	func at(x: float, y: float) -> Sp:
		ox = x
		oy = y
		return self
	func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
		Painter.rect(im[L], (x + ox) * k, (y + oy) * k, w * k, h * k, c)
	func ell(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
		Painter.ellipse(im[L], (cx + ox) * k, (cy + oy) * k, rx * k, ry * k, c)
	func disc(cx: float, cy: float, r: float, c: Color) -> void:
		Painter.ellipse(im[L], (cx + ox) * k, (cy + oy) * k, r * k, r * k, c)
	func tri(a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
		Painter.tri(im[L], (a.x + ox) * k, (a.y + oy) * k, (b.x + ox) * k, (b.y + oy) * k, (c.x + ox) * k, (c.y + oy) * k, col)
	func line(a: Vector2, b: Vector2, w: float, c: Color) -> void:
		Painter.line(im[L], (a.x + ox) * k, (a.y + oy) * k, (b.x + ox) * k, (b.y + oy) * k, w * k, c)
	func arc(cx: float, cy: float, r: float, a0: float, a1: float, w: float, c: Color) -> void:
		Painter.arc(im[L], (cx + ox) * k, (cy + oy) * k, r * k, a0, a1, w * k, c)
	func poly(pts: Array, c: Color) -> void:
		for i in range(1, pts.size() - 1):
			tri(pts[0], pts[i], pts[i + 1], c)
	## Polígono con contorno (el contorno sale en la capa indicada, el relleno en la actual).
	func opoly(pts: Array, c: Color, ink: Color = Color(0.07, 0.05, 0.04, 0.96), d: float = 1.0) -> void:
		var cc := Vector2.ZERO
		for p: Vector2 in pts:
			cc += p
		cc /= float(pts.size())
		var big: Array = []
		for p: Vector2 in pts:
			big.append(p + (p - cc).normalized() * d)
		poly(big, ink)
		poly(pts, c)

static func sh(c: Color, f: float) -> Color:
	return Painter.shade(c, f)

static func g(v: float, a: float = 1.0) -> Color:
	return Color(v, v, v, a)

static func V(x: float, y: float) -> Vector2:
	return Vector2(x, y)

## Contorno a partir de una lista de puntos (polígono convexo ensanchado desde su centro).
static func grow(pts: Array, d: float) -> Array:
	var c := Vector2.ZERO
	for p: Vector2 in pts:
		c += p
	c /= float(pts.size())
	var out: Array = []
	for p: Vector2 in pts:
		out.append(p + (p - c).normalized() * d)
	return out

# ---------------------------------------------------------------- esqueleto humano

const THIGH := 12.0
const SHIN := 12.0
const UARM := 8.2
const FARM := 7.6

## Poses de la marcha: [ángulo muslo, flexión rodilla] por pierna y [ángulo hombro, flexión codo] por brazo
## (ángulos desde la vertical hacia abajo; positivo = hacia delante, que es la derecha del sprite).
const WALK := [
	{"ln": [0.55, 0.06], "lf": [-0.42, 0.40], "an": [-0.55, 0.25], "af": [0.50, 0.40], "bob": 0.9},
	{"ln": [0.04, 0.16], "lf": [0.22, 1.10], "an": [-0.12, 0.30], "af": [0.12, 0.35], "bob": -0.5},
	{"ln": [-0.42, 0.40], "lf": [0.55, 0.06], "an": [0.50, 0.40], "af": [-0.55, 0.25], "bob": 0.9},
	{"ln": [0.22, 1.10], "lf": [0.04, 0.16], "an": [0.12, 0.35], "af": [-0.12, 0.30], "bob": -0.5},
]
const IDLE_POSE := {"ln": [0.06, 0.04], "lf": [-0.10, 0.04], "an": [0.10, 0.28], "af": [-0.06, 0.30], "bob": 0.0}

static func skel(pose: Dictionary, lean: float = 0.0) -> Dictionary:
	var bob: float = pose.get("bob", 0.0)
	var hip := V(30.0, 36.0 + bob)
	var shd := V(30.5 + lean, 23.0 + bob)
	var out := {"hip": hip, "sh": shd, "neck": shd + V(0.9 + lean * 0.15, -3.4), "head": shd + V(1.8 + lean * 0.3, -8.6)}
	for side in ["n", "f"]:
		var lg: Array = pose["l" + side]
		var hp := hip + V(0.0 if side == "n" else -0.8, 0.0)
		var knee := hp + V(sin(lg[0]), cos(lg[0])) * THIGH
		var a2: float = float(lg[0]) - float(lg[1])
		var foot := knee + V(sin(a2), cos(a2)) * SHIN
		out["hp_" + side] = hp
		out["knee_" + side] = knee
		out["foot_" + side] = foot
		out["fang_" + side] = a2
		var ar: Array = pose["a" + side]
		var sp := shd + V(0.4 if side == "n" else -0.6, 0.6)
		var elbow := sp + V(sin(ar[0]), cos(ar[0])) * UARM
		var a3: float = float(ar[0]) + float(ar[1])
		var hand := elbow + V(sin(a3), cos(a3)) * FARM
		out["sp_" + side] = sp
		out["elbow_" + side] = elbow
		out["hand_" + side] = hand
		out["hang_" + side] = a3
	return out

## Miembro con volumen: tinta, color base, sombra abajo a la derecha y luz arriba a la izquierda.
static func limb(sp: Sp, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	sp.line(a, b, w + 1.7, OUT)
	sp.line(a, b, w, col)
	var d := (b - a).normalized()
	var n := V(-d.y, d.x)
	if n.x < 0.0 or (absf(n.x) < 0.2 and n.y < 0.0):
		n = -n          # normal hacia la derecha/abajo (lado en sombra)
	sp.line(a + n * w * 0.26, b + n * w * 0.26, w * 0.42, sh(col, 0.76))
	sp.line(a - n * w * 0.24, b - n * w * 0.24, maxf(0.9, w * 0.30), sh(col, 1.20))

static func boot(sp: Sp, foot: Vector2, ang: float, col: Color) -> void:
	# bota: continúa la pierna y apunta hacia delante (derecha)
	var toe := foot + V(3.6, 0.9 - absf(sin(ang)) * 0.4)
	sp.line(foot + V(-0.4, -1.2), toe, 3.6 + 1.6, OUT)
	sp.line(foot + V(-0.4, -1.2), toe, 3.6, col)
	sp.line(foot + V(-0.4, -0.2), toe + V(0, 0.4), 1.3, sh(col, 0.65))
	sp.line(foot + V(-0.6, -2.0), toe + V(-0.6, -0.9), 1.0, sh(col, 1.25))

static func hand(sp: Sp, p: Vector2, skin: Color = SKIN) -> void:
	sp.disc(p.x, p.y, 2.15, OUT)
	sp.disc(p.x, p.y, 1.55, skin)
	sp.disc(p.x - 0.4, p.y - 0.5, 0.7, sh(skin, 1.12))

# ---------------------------------------------------------------- cabeza

## Cabeza mirando a la derecha. hair: color del pelo (alpha 0 = sin pelo visible).
static func head(sp: Sp, c: Vector2, skin: Color, hair: Color, beard: Color = Color(0, 0, 0, 0), bald: bool = false) -> void:
	# cuello
	sp.rect(c.x - 1.9, c.y + 2.8, 3.6, 3.4, OUT)
	sp.rect(c.x - 1.4, c.y + 2.8, 2.8, 3.4, sh(skin, 0.80))
	sp.ell(c.x, c.y, 3.9, 4.4, OUT)
	sp.ell(c.x, c.y, 3.2, 3.7, skin)
	# sombra abajo-derecha y luz arriba-izquierda
	sp.ell(c.x + 0.7, c.y + 1.1, 2.4, 2.6, sh(skin, 0.86))
	sp.ell(c.x - 0.4, c.y - 0.6, 2.4, 2.8, skin)
	sp.ell(c.x - 1.0, c.y - 1.5, 1.2, 1.2, sh(skin, 1.10))
	# nariz, oreja, ojo, ceja, boca
	sp.tri(c + V(3.0, 0.0), c + V(4.3, 1.3), c + V(2.7, 1.6), sh(skin, 0.95))
	sp.disc(c.x - 1.2, c.y + 0.9, 0.95, sh(skin, 0.72))
	sp.disc(c.x + 1.6, c.y - 0.2, 0.62, Color(0.10, 0.07, 0.05))
	sp.line(c + V(0.7, -1.4), c + V(2.6, -1.1), 0.7, sh(hair if hair.a > 0.0 else Color(0.3, 0.2, 0.1), 0.8))
	sp.line(c + V(1.5, 2.3), c + V(2.8, 2.2), 0.55, Color(0.55, 0.28, 0.25))
	if beard.a > 0.0:
		sp.ell(c.x + 1.0, c.y + 2.5, 2.9, 2.2, beard)
		sp.ell(c.x + 0.6, c.y + 2.2, 2.0, 1.4, sh(beard, 1.15))
		sp.line(c + V(1.4, 2.4), c + V(2.8, 2.5), 0.6, Color(0.55, 0.28, 0.25))
	if hair.a > 0.0 and not bald:
		sp.ell(c.x - 0.6, c.y - 1.9, 3.5, 2.5, hair)
		sp.ell(c.x - 2.2, c.y + 0.2, 1.6, 2.8, sh(hair, 0.85))
		sp.ell(c.x - 1.2, c.y - 2.7, 1.8, 1.0, sh(hair, 1.25))

# ---------------------------------------------------------------- piezas de ropa

## Torso (capa de equipo) con sombra a la derecha, luz a la izquierda y pliegues. extra: largo del faldón.
static func tunic(sp: Sp, j: Dictionary, skirt: float, team_v: float = 0.86, trim: Color = Color(0, 0, 0, 0)) -> void:
	var s: Vector2 = j["sh"]
	var h: Vector2 = j["hip"]
	var ys := s.y - 1.4
	var yb := h.y + skirt
	var pts: Array = [V(s.x - 4.3, ys), V(s.x + 4.9, ys + 0.4), V(h.x + 4.7 + skirt * 0.12, yb), V(h.x - 4.4 - skirt * 0.12, yb)]
	sp.lay(0).poly(grow(pts, 1.1), OUT)
	sp.lay(1).poly(pts, g(team_v))
	# luz a la izquierda, sombra a la derecha
	sp.poly([pts[0], V(pts[0].x + 2.3, ys), V(pts[3].x + 2.1, yb), pts[3]], g(minf(1.0, team_v * 1.14)))
	sp.poly([V(pts[1].x - 3.1, ys + 0.4), pts[1], pts[2], V(pts[2].x - 3.0, yb)], g(team_v * 0.68))
	# pliegues del faldón y arruga del pecho
	for fx in [-1.8, 0.6, 2.8]:
		sp.line(V(h.x + fx, h.y + 3.0), V(h.x + fx * 1.25, yb - 0.4), 0.7, g(team_v * 0.62, 0.8))
	sp.line(V(s.x - 1.0, ys + 6.0), V(s.x + 2.2, ys + 8.4), 0.6, g(team_v * 0.65, 0.7))
	# bajo del faldón y cuello
	sp.rect(h.x - 4.6 - skirt * 0.12, yb - 1.1, 9.3 + skirt * 0.24, 1.1, g(team_v * 0.58))
	sp.lay(2)
	if trim.a > 0.0:
		sp.line(V(s.x - 2.0, ys + 0.4), V(s.x + 3.0, ys + 0.7), 1.2, trim)

static func belt(sp: Sp, j: Dictionary, col: Color = Color(0.30, 0.19, 0.09), buckle: bool = true) -> void:
	var h: Vector2 = j["hip"]
	sp.lay(2)
	sp.rect(h.x - 4.9, h.y - 1.6, 9.9, 2.3, OUT)
	sp.rect(h.x - 4.6, h.y - 1.3, 9.3, 1.7, col)
	sp.rect(h.x - 4.6, h.y - 1.3, 9.3, 0.6, sh(col, 1.3))
	if buckle:
		sp.rect(h.x + 1.8, h.y - 1.5, 1.8, 2.1, Color(0.82, 0.72, 0.30))

## Piernas con calzas/pantalón y botas. back = pierna lejana (capa 0) o cercana (capa 2).
static func leg(sp: Sp, j: Dictionary, side: String, pants: Color, boots: Color) -> void:
	var hp: Vector2 = j["hp_" + side]
	var kn: Vector2 = j["knee_" + side]
	var ft: Vector2 = j["foot_" + side]
	var shade := 0.78 if side == "f" else 1.0
	limb(sp, hp, kn, 4.6, sh(pants, shade))
	limb(sp, kn, ft - V(0.0, 1.6), 4.0, sh(pants, shade * 0.97))
	boot(sp, ft, float(j["fang_" + side]), sh(boots, shade))

static func arm_seg(sp: Sp, j: Dictionary, side: String, sleeve: Color, skin: Color, bare_fore: bool = true) -> void:
	var sp0: Vector2 = j["sp_" + side]
	var el: Vector2 = j["elbow_" + side]
	var hd: Vector2 = j["hand_" + side]
	var shade := 0.80 if side == "f" else 1.0
	limb(sp, sp0, el, 3.9, sh(sleeve, shade))
	limb(sp, el, hd - (hd - el).normalized() * 0.8, 3.3, sh(skin if bare_fore else sleeve, shade * (0.95 if bare_fore else 0.97)))
	hand(sp, hd, sh(skin, shade))

# ---------------------------------------------------------------- herramientas y armas

static func axe(sp: Sp, h: Vector2, ang: float) -> void:
	# ang: dirección del mango (0 = hacia abajo; positivo gira hacia delante)
	var d := V(sin(ang), -cos(ang))        # del puño hacia la punta
	var tip := h + d * 12.0
	sp.line(h - d * 3.0, tip, 2.0 + 1.5, OUT)
	sp.line(h - d * 3.0, tip, 2.0, Color(0.52, 0.34, 0.16))
	sp.line(h - d * 3.0 + V(-0.3, -0.3), tip + V(-0.3, -0.3), 0.7, Color(0.72, 0.52, 0.28))
	var n := V(-d.y, d.x)
	var a := tip + n * -3.4 - d * 0.5
	var b := tip + n * 4.0 - d * 0.5
	var c := tip - d * 5.2 + n * 0.4
	sp.tri(a - d * 0.8 + n * 0.4, b + d * 0.8, c, OUT)
	sp.tri(a, b, c + d * 0.6, Color(0.66, 0.68, 0.74))
	sp.line(a, b, 1.1, Color(0.90, 0.92, 0.96))

static func pick(sp: Sp, h: Vector2, ang: float) -> void:
	var d := V(sin(ang), -cos(ang))
	var tip := h + d * 12.0
	sp.line(h - d * 3.0, tip, 3.5, OUT)
	sp.line(h - d * 3.0, tip, 2.0, Color(0.52, 0.34, 0.16))
	var n := V(-d.y, d.x)
	var l := tip + n * -6.2 + d * 1.2
	var r := tip + n * 6.2 + d * 1.2
	sp.line(l, tip + d * 0.5, 3.0, OUT)
	sp.line(r, tip + d * 0.5, 3.0, OUT)
	sp.line(l, tip + d * 0.5, 1.6, Color(0.62, 0.64, 0.70))
	sp.line(r, tip + d * 0.5, 1.6, Color(0.62, 0.64, 0.70))
	sp.disc(tip.x, tip.y, 1.3, Color(0.45, 0.30, 0.15))

static func hammer(sp: Sp, h: Vector2, ang: float) -> void:
	var d := V(sin(ang), -cos(ang))
	var tip := h + d * 10.0
	sp.line(h - d * 3.0, tip, 3.4, OUT)
	sp.line(h - d * 3.0, tip, 2.0, Color(0.52, 0.34, 0.16))
	var n := V(-d.y, d.x)
	sp.line(tip - n * 3.8, tip + n * 3.8, 5.4, OUT)
	sp.line(tip - n * 3.6, tip + n * 3.6, 3.8, Color(0.60, 0.62, 0.68))
	sp.line(tip - n * 3.4 - d * 0.8, tip + n * 3.4 - d * 0.8, 1.0, Color(0.88, 0.90, 0.95))

static func hoe(sp: Sp, h: Vector2, ang: float) -> void:
	var d := V(sin(ang), -cos(ang))
	var tip := h + d * 13.0
	sp.line(h - d * 3.0, tip, 3.4, OUT)
	sp.line(h - d * 3.0, tip, 2.0, Color(0.55, 0.38, 0.18))
	var n := V(-d.y, d.x)
	sp.line(tip, tip + n * 4.6 - d * 2.4, 3.6, OUT)
	sp.line(tip, tip + n * 4.6 - d * 2.4, 2.0, Color(0.60, 0.62, 0.68))

static func spear(sp: Sp, h: Vector2, dir: Vector2, length: float, team_pennant: bool = true) -> void:
	var d := dir.normalized()
	var tail := h - d * (length * 0.30)
	var tip := h + d * (length * 0.70)
	sp.lay(2)
	sp.line(tail, tip, 3.2, OUT)
	sp.line(tail, tip, 1.8, Color(0.58, 0.40, 0.20))
	sp.line(tail + V(-0.3, -0.3), tip + V(-0.3, -0.3), 0.6, Color(0.78, 0.58, 0.32))
	var n := V(-d.y, d.x)
	var base := tip - d * 6.4
	sp.tri(tip + d * 1.2, base + n * 2.6, base - n * 2.6, OUT)
	sp.tri(tip, base + n * 1.9 - d * 0.2, base - n * 1.9 - d * 0.2, Color(0.82, 0.85, 0.92))
	sp.tri(tip, base - n * 1.9 - d * 0.2, base + d * 0.8, Color(1, 1, 1, 0.55))
	if team_pennant:
		var pb := tip - d * 8.2
		var flutter := n * 0.8
		sp.lay(1)
		sp.tri(pb, pb - d * 6.4 + n * 3.2 + flutter, pb - d * 6.4 - n * 0.4, g(0.9))
		sp.tri(pb, pb - d * 6.4 + n * 3.2 + flutter, pb - d * 2.5 + n * 2.0, g(0.65))
		sp.lay(2)

static func sword(sp: Sp, h: Vector2, dir: Vector2, ly: int = 2) -> void:
	var d := dir.normalized()
	var n := V(-d.y, d.x)
	var tip := h + d * 15.5
	sp.lay(ly)
	sp.line(h - d * 2.6, h, 2.6, OUT)
	sp.line(h - d * 2.4, h, 1.4, Color(0.34, 0.20, 0.10))
	sp.disc(h.x - d.x * 3.0, h.y - d.y * 3.0, 1.5, Color(0.80, 0.68, 0.30))
	sp.line(h - n * 3.4, h + n * 3.4, 2.6, OUT)
	sp.line(h - n * 3.2, h + n * 3.2, 1.3, Color(0.82, 0.70, 0.30))
	sp.line(h, tip - d * 1.0, 3.4, OUT)
	sp.tri(tip + d * 1.2, h + n * 1.7 + d * 1.0, h - n * 1.7 + d * 1.0, OUT)
	sp.line(h + d * 0.6, tip - d * 0.8, 2.3, Color(0.84, 0.87, 0.93))
	sp.line(h + d * 0.8, tip - d * 1.2, 0.8, Color(1, 1, 1, 0.8))
	sp.line(h + d * 1.0 + n * 0.8, tip - d * 1.6 + n * 0.6, 0.7, Color(0.55, 0.58, 0.66))

## Escudo visto de canto: cara en color de equipo (capa 1), contorno y borde delante (capa 2).
static func shield(sp: Sp, c: Vector2, rx: float, ry: float, rim: Color) -> void:
	sp.lay(1)
	sp.ell(c.x, c.y, rx, ry, g(0.82))
	sp.ell(c.x + 0.6, c.y + 0.7, rx * 0.8, ry * 0.8, g(0.62))
	sp.ell(c.x - 0.4, c.y - 0.5, rx * 0.78, ry * 0.8, g(0.92))
	sp.lay(2)
	sp.arc(c.x, c.y, rx + 0.5, 0.0, TAU, 1.5, OUT)
	sp.arc(c.x, c.y, rx - 0.5, 0.0, TAU, 1.5, rim)
	sp.disc(c.x, c.y, minf(rx, ry) * 0.30 + 0.6, OUT)
	sp.disc(c.x, c.y, minf(rx, ry) * 0.30, Color(0.78, 0.80, 0.86))
	sp.disc(c.x - 0.4, c.y - 0.4, minf(rx, ry) * 0.12, Color(1, 1, 1, 0.85))

# ---------------------------------------------------------------- despacho por tipo

static func _paint(type: String, f: int, sp: Sp) -> void:
	match type:
		"aldeano":
			_p_aldeano(sp, f)
		"piquero":
			_p_piquero(sp, f)
		"espadachin":
			_p_espadachin(sp, f)
		"arquero":
			_p_arquero(sp, f)
		"ballestero":
			_p_ballestero(sp, f)
		"jinete":
			ArtMounts._p_jinete(sp, f)
		"explorador":
			ArtMounts._p_explorador(sp, f)
		"caballero":
			ArtMounts._p_caballero(sp, f)
		"ariete":
			ArtMounts._p_ariete(sp, f)
		"barco_pesca":
			ArtShips._p_pesca(sp, f)
		"barco_transporte":
			ArtShips._p_transporte(sp, f)
		"galera":
			ArtShips._p_galera(sp, f)
		"galeon":
			ArtShips._p_galeon(sp, f)
		_:
			_p_aldeano(sp, 0)

static func walk_pose(f: int) -> Dictionary:
	if f >= F_WALK and f < F_WALK + 4:
		return WALK[f - F_WALK]
	return IDLE_POSE

# ---------------------------------------------------------------- aldeano

static func _p_aldeano(sp: Sp, f: int) -> void:
	var pose := walk_pose(f)
	var lean := 0.0
	var trade := -1
	var phase := 0
	if f >= F_ACT:
		trade = (f - F_ACT) / 2
		phase = (f - F_ACT) % 2
		pose = {"ln": [0.20, 0.10], "lf": [-0.22, 0.14], "an": [0.0, 0.3], "af": [0.0, 0.3], "bob": 0.0}
		match trade:
			TRADE_CHOP:
				pose = {"ln": [0.22, 0.10], "lf": [-0.20, 0.12], "an": [-2.5, 0.35] if phase == 0 else [0.55, 0.2], "af": [-2.3, 0.5] if phase == 0 else [0.60, 0.2], "bob": 0.0}
				lean = -0.6 if phase == 0 else 2.2
			TRADE_MINE:
				pose = {"ln": [0.24, 0.12], "lf": [-0.22, 0.12], "an": [-2.7, 0.3] if phase == 0 else [0.70, 0.2], "af": [-2.5, 0.4] if phase == 0 else [0.75, 0.2], "bob": 0.0}
				lean = -0.8 if phase == 0 else 2.6
			TRADE_FARM:
				pose = {"ln": [0.28, 0.20], "lf": [-0.30, 0.18], "an": [-1.6, 0.5] if phase == 0 else [0.55, 0.45], "af": [-1.5, 0.6] if phase == 0 else [0.60, 0.5], "bob": 1.0}
				lean = 1.6 if phase == 0 else 3.4
			TRADE_BUILD:
				pose = {"ln": [0.18, 0.10], "lf": [-0.16, 0.12], "an": [-2.2, 0.3] if phase == 0 else [0.45, 0.25], "af": [-0.15, 0.3], "bob": 0.0}
				lean = 0.4 if phase == 0 else 1.8
	var j := skel(pose, lean)
	var pants := Color(0.42, 0.31, 0.20)
	var boots := Color(0.26, 0.17, 0.10)
	var linen := Color(0.86, 0.80, 0.64)
	var skin := SKIN
	# --- fondo: pierna y brazo lejanos
	sp.lay(0)
	leg(sp, j, "f", pants, boots)
	arm_seg(sp, j, "f", linen, skin)
	# --- equipo: túnica del jugador
	tunic(sp, j, 5.0, 0.86)
	# --- frente: pierna cercana, cinturón, cabeza, brazo cercano y herramienta
	sp.lay(2)
	leg(sp, j, "n", pants, boots)
	belt(sp, j, Color(0.34, 0.22, 0.10))
	# bolsa al cinto
	var hip: Vector2 = j["hip"]
	sp.ell(hip.x - 3.2, hip.y + 2.6, 2.3, 2.8, OUT)
	sp.ell(hip.x - 3.2, hip.y + 2.6, 1.7, 2.2, Color(0.55, 0.40, 0.22))
	var hd: Vector2 = j["head"]
	head(sp, hd, skin, Color(0.36, 0.24, 0.12))
	# sombrero de paja
	sp.ell(hd.x + 0.3, hd.y - 2.4, 6.6, 1.9, OUT)
	sp.ell(hd.x + 0.3, hd.y - 2.5, 6.0, 1.4, Color(0.82, 0.68, 0.34))
	sp.ell(hd.x, hd.y - 4.1, 3.7, 2.6, OUT)
	sp.ell(hd.x, hd.y - 4.0, 3.1, 2.1, Color(0.84, 0.70, 0.36))
	sp.ell(hd.x - 0.6, hd.y - 4.6, 1.8, 1.1, Color(0.95, 0.84, 0.50))
	sp.rect(hd.x - 3.0, hd.y - 3.4, 6.0, 0.9, Color(0.50, 0.30, 0.14))
	arm_seg(sp, j, "n", linen, skin)
	var h: Vector2 = j["hand_n"]
	match trade:
		TRADE_CHOP:
			axe(sp, h, -2.6 + (0.0 if phase == 0 else 2.4) if false else (-2.7 if phase == 0 else 0.7))
		TRADE_MINE:
			pick(sp, h, -2.8 if phase == 0 else 0.8)
		TRADE_FARM:
			hoe(sp, h, -2.4 if phase == 0 else 0.5)
		TRADE_BUILD:
			hammer(sp, h, -2.3 if phase == 0 else 0.4)

# ---------------------------------------------------------------- cascos y complementos

static func helm_cap(sp: Sp, hd: Vector2, steel: Color) -> void:
	# casquete de hierro con cubrenuca
	sp.ell(hd.x - 0.3, hd.y - 1.9, 4.5, 3.6, OUT)
	sp.ell(hd.x - 0.3, hd.y - 1.9, 3.9, 3.0, steel)
	sp.ell(hd.x - 1.1, hd.y - 2.8, 2.0, 1.3, sh(steel, 1.28))
	sp.rect(hd.x - 4.2, hd.y - 0.2, 3.2, 3.2, OUT)
	sp.rect(hd.x - 3.8, hd.y - 0.2, 2.6, 2.9, sh(steel, 0.80))
	sp.rect(hd.x - 4.0, hd.y - 0.6, 7.6, 1.1, sh(steel, 0.70))

static func helm_nasal(sp: Sp, hd: Vector2, steel: Color) -> void:
	# yelmo cónico con nasal y cofia de malla
	sp.ell(hd.x - 1.4, hd.y + 1.6, 3.6, 4.6, OUT)
	sp.ell(hd.x - 1.4, hd.y + 1.7, 3.0, 4.0, Color(0.52, 0.54, 0.60))
	for i in 3:
		sp.line(V(hd.x - 3.6, hd.y + 0.6 + i * 1.6), V(hd.x - 0.2, hd.y + 0.6 + i * 1.6), 0.5, Color(0.30, 0.31, 0.36, 0.8))
	sp.ell(hd.x - 0.2, hd.y - 2.0, 4.3, 3.7, OUT)
	sp.ell(hd.x - 0.2, hd.y - 2.0, 3.7, 3.1, steel)
	sp.tri(V(hd.x - 2.6, hd.y - 4.0), V(hd.x + 1.4, hd.y - 4.1), V(hd.x - 0.6, hd.y - 6.8), OUT)
	sp.tri(V(hd.x - 2.0, hd.y - 4.0), V(hd.x + 0.9, hd.y - 4.1), V(hd.x - 0.6, hd.y - 6.0), steel)
	sp.ell(hd.x - 1.2, hd.y - 3.0, 1.8, 1.2, sh(steel, 1.30))
	sp.rect(hd.x - 3.8, hd.y - 0.4, 7.4, 1.1, sh(steel, 0.78))
	sp.rect(hd.x + 2.0, hd.y - 1.0, 1.1, 4.4, OUT)
	sp.rect(hd.x + 2.2, hd.y - 0.8, 0.7, 4.0, sh(steel, 0.9))

static func helm_kettle(sp: Sp, hd: Vector2, steel: Color) -> void:
	# sombrero de ala ancha de hierro
	sp.ell(hd.x + 0.3, hd.y - 2.5, 7.0, 2.0, OUT)
	sp.ell(hd.x + 0.3, hd.y - 2.6, 6.4, 1.45, sh(steel, 0.88))
	sp.ell(hd.x, hd.y - 4.1, 4.0, 3.0, OUT)
	sp.ell(hd.x, hd.y - 4.0, 3.4, 2.5, steel)
	sp.ell(hd.x - 0.9, hd.y - 4.8, 1.8, 1.1, sh(steel, 1.32))
	sp.rect(hd.x - 3.2, hd.y - 2.7, 6.4, 0.7, sh(steel, 0.70))

static func hood(sp: Sp, hd: Vector2, col: Color, feather: bool) -> void:
	# capucha verde con cola caída y pluma
	sp.tri(V(hd.x - 3.4, hd.y - 1.5), V(hd.x - 8.4, hd.y + 4.8), V(hd.x - 1.0, hd.y + 4.4), OUT)
	sp.tri(V(hd.x - 3.0, hd.y - 1.0), V(hd.x - 7.4, hd.y + 4.0), V(hd.x - 1.2, hd.y + 3.6), sh(col, 0.80))
	sp.ell(hd.x - 0.4, hd.y - 2.1, 4.4, 3.8, OUT)
	sp.ell(hd.x - 0.4, hd.y - 2.1, 3.8, 3.2, col)
	sp.ell(hd.x - 1.4, hd.y - 3.0, 1.9, 1.4, sh(col, 1.25))
	sp.tri(V(hd.x - 2.0, hd.y - 4.4), V(hd.x + 1.6, hd.y - 4.6), V(hd.x - 0.2, hd.y - 7.4), OUT)
	sp.tri(V(hd.x - 1.6, hd.y - 4.4), V(hd.x + 1.2, hd.y - 4.6), V(hd.x - 0.2, hd.y - 6.6), col)
	sp.rect(hd.x - 3.6, hd.y - 0.9, 5.4, 1.0, sh(col, 0.70))
	if feather:
		sp.line(V(hd.x + 0.6, hd.y - 4.2), V(hd.x + 5.2, hd.y - 9.6), 2.4, OUT)
		sp.line(V(hd.x + 0.6, hd.y - 4.2), V(hd.x + 5.2, hd.y - 9.6), 1.3, Color(0.94, 0.92, 0.84))
		sp.line(V(hd.x + 0.4, hd.y - 4.0), V(hd.x + 4.6, hd.y - 9.0), 0.5, Color(0.70, 0.66, 0.56))

static func quiver(sp: Sp, j: Dictionary) -> void:
	# aljaba a la espalda (tras el torso)
	var s: Vector2 = j["sh"]
	var a := V(s.x - 4.0, s.y - 3.0)
	var b := V(s.x - 7.5, s.y + 11.0)
	for k in 3:
		sp.line(a + V(-1.0 + k * 1.2, 0), a + V(-1.6 + k * 1.2, -4.5), 0.9, OUT)
		sp.line(a + V(-1.0 + k * 1.2, 0), a + V(-1.6 + k * 1.2, -4.0), 0.5, Color(0.93, 0.92, 0.86))
	sp.line(a, b, 5.2, OUT)
	sp.line(a, b, 3.6, Color(0.50, 0.32, 0.15))
	sp.line(a + V(-0.8, 0), b + V(-0.8, 0), 1.0, Color(0.70, 0.48, 0.24))
	sp.line(a + V(0.5, 2.0), b + V(0.5, -1.0), 0.8, Color(0.28, 0.17, 0.08))

static func bow(sp: Sp, grip: Vector2, string_hand: Vector2, drawn: bool, arrow: bool) -> void:
	sp.lay(2)
	var wood := Color(0.55, 0.36, 0.17)
	var top := grip + V(-2.6, -13.5)
	var bot := grip + V(-2.6, 13.5)
	var mt := grip + V(0.9, -7.0)
	var mb := grip + V(0.9, 7.0)
	var pts := [top, mt, grip, mb, bot]
	for i in 4:
		sp.line(pts[i], pts[i + 1], 3.3, OUT)
	for i in 4:
		sp.line(pts[i], pts[i + 1], 2.0, wood)
	sp.line(top + V(-0.3, 0.3), mt + V(-0.3, -0.2), 0.7, Color(0.78, 0.58, 0.32))
	sp.line(grip + V(-0.2, -2.6), grip + V(-0.2, 2.6), 3.0, Color(0.30, 0.18, 0.08))
	var sc := Color(0.94, 0.92, 0.84, 0.95)
	if drawn:
		sp.line(top, string_hand, 0.7, sc)
		sp.line(string_hand, bot, 0.7, sc)
	else:
		sp.line(top, bot, 0.7, sc)
	if arrow:
		var tip := grip + V(7.5, 0.0)
		sp.line(string_hand, tip, 1.9, OUT)
		sp.line(string_hand, tip, 1.0, Color(0.74, 0.60, 0.38))
		sp.tri(tip + V(2.6, 0.0), tip + V(-0.6, -1.9), tip + V(-0.6, 1.9), OUT)
		sp.tri(tip + V(1.8, 0.0), tip + V(-0.2, -1.2), tip + V(-0.2, 1.2), Color(0.86, 0.88, 0.94))
		sp.line(string_hand + V(0.2, 0), string_hand + V(2.6, -1.3), 0.8, Color(0.95, 0.95, 0.90))
		sp.line(string_hand + V(0.2, 0), string_hand + V(2.6, 1.3), 0.8, Color(0.95, 0.95, 0.90))

static func crossbow(sp: Sp, butt: Vector2, dir: Vector2, bolt: bool) -> void:
	sp.lay(2)
	var d := dir.normalized()
	var n := V(-d.y, d.x)
	var front := butt + d * 18.0
	var wood := Color(0.50, 0.32, 0.16)
	sp.line(butt, front, 4.2, OUT)
	sp.line(butt, front, 2.9, wood)
	sp.line(butt + n * 0.8, front + n * 0.8, 0.8, Color(0.74, 0.54, 0.28))
	sp.line(butt - n * 0.3, butt + d * 4.0 - n * 0.3, 3.6, sh(wood, 0.78))
	# arco de acero y cuerda
	var le := front + n * 7.2 + d * 1.6
	var re := front - n * 7.2 + d * 1.6
	sp.line(le, front + d * 0.4, 3.0, OUT)
	sp.line(re, front + d * 0.4, 3.0, OUT)
	sp.line(le, front + d * 0.4, 1.7, Color(0.42, 0.44, 0.50))
	sp.line(re, front + d * 0.4, 1.7, Color(0.42, 0.44, 0.50))
	var sc := Color(0.92, 0.90, 0.82, 0.95)
	sp.line(le, butt + d * 14.0, 0.6, sc)
	sp.line(re, butt + d * 14.0, 0.6, sc)
	sp.line(front - d * 1.0 - n * 0.5, front + d * 1.5 - n * 0.5, 2.6, Color(0.62, 0.64, 0.70))
	# gatillo
	sp.tri(butt + d * 7.0 + n * 0.9, butt + d * 9.4 + n * 0.9, butt + d * 7.6 + n * 3.6, OUT)
	if bolt:
		sp.line(butt + d * 8.0 + n * 1.6, front + d * 6.0 + n * 1.6, 1.4, OUT)
		sp.line(butt + d * 8.0 + n * 1.6, front + d * 5.0 + n * 1.6, 0.8, Color(0.76, 0.62, 0.40))
		var tip := front + d * 6.0 + n * 1.6
		sp.tri(tip + d * 2.8, tip - d * 0.4 + n * 1.7, tip - d * 0.4 - n * 1.7, OUT)
		sp.tri(tip + d * 2.0, tip + n * 1.0, tip - n * 1.0, Color(0.88, 0.90, 0.95))

# ---------------------------------------------------------------- infantería

const STANCE_W := {"ln": [-0.30, 0.30], "lf": [0.45, 0.20]}
const STANCE_S := {"ln": [0.75, 0.15], "lf": [-0.55, 0.35]}

static func _mk(base: Dictionary, over: Dictionary) -> Dictionary:
	var d := base.duplicate(true)
	for k in over:
		d[k] = over[k]
	return d

## Cuerpo común del soldado: piernas, túnica del equipo, cinturón y cabeza. Devuelve el esqueleto.
static func _inf_body(sp: Sp, pose: Dictionary, lean: float, pants: Color, boots: Color, skirt: float, sleeve: Color, hair: Color, beard: Color, trim: Color = Color(0, 0, 0, 0)) -> Dictionary:
	var j := skel(pose, lean)
	sp.lay(0)
	leg(sp, j, "f", pants, boots)
	arm_seg(sp, j, "f", sleeve, SKIN)
	tunic(sp, j, skirt, 0.86, trim)
	sp.lay(2)
	leg(sp, j, "n", pants, boots)
	belt(sp, j)
	head(sp, j["head"], SKIN, hair, beard)
	return j

static func _p_piquero(sp: Sp, f: int) -> void:
	sp.at(0.0, 12.0)
	var pose := _mk(walk_pose(f), {})
	var lean := 0.0
	var sd := V(0.10, -1.0)
	if f <= F_WALK + 3:
		pose["an"] = [0.35, 0.75]
	elif f == 5:
		pose = _mk(STANCE_W, {"an": [0.55, 0.70], "af": [1.00, 0.50], "bob": 0.0})
		lean = -1.0
		sd = V(1.0, -0.30)
	else:
		pose = _mk(STANCE_S, {"an": [1.45, 0.10], "af": [1.25, 0.25], "bob": 0.0})
		lean = 2.5
		sd = V(1.0, -0.03)
	var j := _inf_body(sp, pose, lean, Color(0.38, 0.33, 0.24), Color(0.26, 0.17, 0.10), 4.5, Color(0.80, 0.74, 0.58), Color(0.34, 0.22, 0.12), Color(0, 0, 0, 0))
	var hd: Vector2 = j["head"]
	helm_cap(sp, hd, Color(0.64, 0.66, 0.72))
	arm_seg(sp, j, "n", Color(0.80, 0.74, 0.58), SKIN)
	spear(sp, j["hand_n"], sd, 50.0)

static func _p_espadachin(sp: Sp, f: int) -> void:
	sp.at(0.0, 12.0)
	var mail := Color(0.60, 0.62, 0.68)
	var pose := _mk(walk_pose(f), {})
	var lean := 0.0
	var sdir := V(0.75, -0.62)
	var drawn := false
	if f <= F_WALK + 3:
		pose["an"] = [0.30, 0.95]
	elif f == 5:
		pose = _mk(STANCE_W, {"an": [0.40, 1.00], "af": [-2.5, 0.30], "bob": 0.0})
		lean = -1.2
		sdir = V(-0.20, -1.0)
		drawn = true
	else:
		pose = _mk(STANCE_S, {"an": [0.45, 0.95], "af": [2.0, 0.20], "bob": 0.0})
		lean = 2.4
		sdir = V(0.90, 0.45)
		drawn = true
	var j := skel(pose, lean)
	var hip: Vector2 = j["hip"]
	sp.lay(0)
	if not drawn:
		# vaina colgando tras la cadera
		sp.line(hip + V(-1.5, 0.0), hip + V(-9.5, 9.0), 3.6, OUT)
		sp.line(hip + V(-1.5, 0.0), hip + V(-9.5, 9.0), 2.2, Color(0.30, 0.18, 0.10))
		sp.disc(hip.x - 9.8, hip.y + 9.3, 1.5, Color(0.80, 0.68, 0.30))
	leg(sp, j, "f", Color(0.30, 0.26, 0.22), Color(0.22, 0.15, 0.09))
	arm_seg(sp, j, "f", mail, SKIN, false)
	if drawn:
		sword(sp, j["hand_f"], sdir, 0)
	tunic(sp, j, 3.5, 0.84, Color(0.12, 0.10, 0.08))
	sp.lay(2)
	leg(sp, j, "n", Color(0.30, 0.26, 0.22), Color(0.22, 0.15, 0.09))
	belt(sp, j, Color(0.24, 0.15, 0.07))
	if not drawn:
		# empuñadura asomando por delante del cinturón
		sp.line(hip + V(2.8, -1.6), hip + V(3.8, -5.6), 1.8, OUT)
		sp.line(hip + V(2.8, -1.6), hip + V(3.8, -5.0), 1.0, Color(0.34, 0.20, 0.10))
		sp.line(hip + V(1.2, -3.4), hip + V(6.2, -3.8), 1.6, OUT)
		sp.line(hip + V(1.4, -3.4), hip + V(6.0, -3.8), 0.8, Color(0.82, 0.70, 0.30))
	head(sp, j["head"], SKIN, Color(0.14, 0.10, 0.07), Color(0.18, 0.12, 0.08, 0.9))
	helm_nasal(sp, j["head"], Color(0.70, 0.72, 0.78))
	arm_seg(sp, j, "n", mail, SKIN, false)
	var hn: Vector2 = j["hand_n"]
	shield(sp, hn + V(2.8, -1.2), 5.6, 7.2, Color(0.80, 0.68, 0.30))

static func _p_arquero(sp: Sp, f: int) -> void:
	sp.at(0.0, 12.0)
	var green := Color(0.28, 0.40, 0.22)
	var pose := _mk(walk_pose(f), {})
	var lean := 0.0
	var mode := 0        # 0 en marcha, 1 tensando, 2 suelta, 3 apuntando
	if f <= F_WALK + 3:
		pose["an"] = [0.20, 0.45]
	elif f == 5:
		pose = _mk({"ln": [0.18, 0.12], "lf": [-0.20, 0.12]}, {"an": [1.30, 0.15], "af": [0.80, 1.20], "bob": 0.0})
		mode = 1
	elif f == 6:
		pose = _mk({"ln": [0.18, 0.12], "lf": [-0.20, 0.12]}, {"an": [1.52, 0.05], "af": [-1.00, 1.00], "bob": 0.0})
		lean = -0.6
		mode = 2
	else:
		pose = _mk({"ln": [0.18, 0.12], "lf": [-0.20, 0.12]}, {"an": [1.52, 0.05], "af": [-1.57, 2.90], "bob": 0.0})
		lean = 0.4
		mode = 3
	var j := skel(pose, lean)
	sp.lay(0)
	quiver(sp, j)
	leg(sp, j, "f", Color(0.34, 0.27, 0.18), Color(0.25, 0.16, 0.09))
	arm_seg(sp, j, "f", Color(0.78, 0.72, 0.56), SKIN)
	tunic(sp, j, 3.0, 0.86)
	sp.lay(2)
	leg(sp, j, "n", Color(0.34, 0.27, 0.18), Color(0.25, 0.16, 0.09))
	belt(sp, j, Color(0.30, 0.19, 0.09))
	var hd: Vector2 = j["head"]
	head(sp, hd, SKIN, Color(0.46, 0.26, 0.12), Color(0, 0, 0, 0), true)
	hood(sp, hd, green, true)
	# correa del carcaj
	var s: Vector2 = j["sh"]
	sp.line(V(s.x - 3.5, s.y - 1.0), V(s.x + 3.5, s.y + 11.0), 1.3, OUT)
	sp.line(V(s.x - 3.5, s.y - 1.0), V(s.x + 3.5, s.y + 11.0), 0.8, Color(0.42, 0.27, 0.12))
	arm_seg(sp, j, "n", Color(0.78, 0.72, 0.56), SKIN)
	var gn: Vector2 = j["hand_n"]
	var gf: Vector2 = j["hand_f"]
	match mode:
		0:
			bow(sp, gn + V(1.0, 0.5), gn + V(1.0, 0.5), false, false)
		1:
			bow(sp, gn + V(1.0, 0.0), gf, true, true)
		2:
			bow(sp, gn + V(1.0, 0.0), gn + V(1.0, 0.0), false, false)
		3:
			bow(sp, gn + V(1.0, 0.0), gf, true, true)
	# la mano que tensa la cuerda va por delante
	if mode == 1 or mode == 3:
		hand(sp, gf, SKIN)
	if mode == 3 or mode == 1:
		hand(sp, gn, SKIN)

static func _p_ballestero(sp: Sp, f: int) -> void:
	sp.at(0.0, 12.0)
	var pose := _mk(walk_pose(f), {})
	var lean := 0.0
	var mode := 0
	if f <= F_WALK + 3:
		pose["an"] = [0.45, 0.90]
	elif f == 5:
		pose = _mk({"ln": [0.14, 0.12], "lf": [-0.18, 0.12]}, {"an": [0.80, 0.60], "af": [0.55, 0.90], "bob": 0.0})
		mode = 1
		lean = 1.2
	elif f == 6:
		pose = _mk({"ln": [0.14, 0.12], "lf": [-0.18, 0.12]}, {"an": [1.42, 0.12], "af": [0.95, 1.15], "bob": 0.0})
		mode = 2
		lean = -0.8
	else:
		pose = _mk({"ln": [0.14, 0.12], "lf": [-0.18, 0.12]}, {"an": [1.42, 0.12], "af": [0.95, 1.15], "bob": 0.0})
		mode = 3
		lean = 0.2
	var jack := Color(0.42, 0.30, 0.17)
	var j := skel(pose, lean)
	sp.lay(0)
	leg(sp, j, "f", Color(0.30, 0.24, 0.18), Color(0.22, 0.15, 0.09))
	arm_seg(sp, j, "f", jack, SKIN)
	tunic(sp, j, 4.0, 0.86, Color(0.20, 0.13, 0.07))
	sp.lay(2)
	leg(sp, j, "n", Color(0.30, 0.24, 0.18), Color(0.22, 0.15, 0.09))
	belt(sp, j, Color(0.22, 0.14, 0.07))
	# virotes al cinto
	var h: Vector2 = j["hip"]
	sp.rect(h.x + 3.0, h.y - 1.0, 3.6, 6.2, OUT)
	sp.rect(h.x + 3.4, h.y - 0.6, 2.8, 5.6, Color(0.44, 0.29, 0.14))
	for k in 3:
		sp.line(V(h.x + 3.9 + k * 0.9, h.y - 0.6), V(h.x + 3.9 + k * 0.9, h.y - 2.6), 0.6, Color(0.88, 0.86, 0.80))
	head(sp, j["head"], SKIN, Color(0.44, 0.30, 0.16), Color(0, 0, 0, 0), true)
	helm_kettle(sp, j["head"], Color(0.58, 0.60, 0.66))
	arm_seg(sp, j, "n", jack, SKIN)
	var hn: Vector2 = j["hand_n"]
	var hf: Vector2 = j["hand_f"]
	var s: Vector2 = j["sh"]
	match mode:
		0:
			crossbow(sp, hn - V(0.85, -0.5) * 8.5, V(0.85, -0.5), false)
		1:
			crossbow(sp, hn - V(0.7, 0.7) * 9.0, V(0.7, 0.7), false)
		2:
			crossbow(sp, V(s.x + 2.5, s.y + 2.0), V(1.0, -0.03), false)
		3:
			crossbow(sp, V(s.x + 2.5, s.y + 2.0), V(1.0, -0.03), true)
	hand(sp, hn, SKIN)
	if mode >= 2:
		hand(sp, hf, SKIN)
