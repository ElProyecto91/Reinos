class_name ArtShips
extends RefCounted
## Barcos de perfil mirando a la derecha. El dibujo acaba en la línea de flotación (el agua la pone el renderizador).
## Capas: 0 fondo, 1 equipo (velas, escudos, franjas), 2 frente. Fotogramas 0-3: ciclo de navegación; 4-5: acción.

const OUT := ArtUnits.OUT
const WOOD := Color(0.52, 0.34, 0.17)
const WOOD_D := Color(0.36, 0.22, 0.11)
const CANVAS := Color(0.93, 0.89, 0.77)

static func V(x: float, y: float) -> Vector2:
	return Vector2(x, y)

static func sh(c: Color, f: float) -> Color:
	return Painter.shade(c, f)

static func lerpv(a: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(b, t)

## Casco a partir de dos líneas (borda y quilla) con tablas, luz y sombra.
static func hull(sp: ArtUnits.Sp, top: Array, bot: Array, col: Color) -> void:
	var n := top.size()
	sp.lay(0)
	for i in n - 1:
		sp.opoly([top[i], top[i + 1], bot[i + 1], bot[i]], col, OUT, 1.1)
	for i in n - 1:
		sp.poly([top[i], top[i + 1], bot[i + 1], bot[i]], col)
	for i in n - 1:
		sp.poly([lerpv(top[i], bot[i], 0.70), lerpv(top[i + 1], bot[i + 1], 0.70), bot[i + 1], bot[i]], sh(col, 0.78))
		sp.poly([top[i], top[i + 1], lerpv(top[i + 1], bot[i + 1], 0.14), lerpv(top[i], bot[i], 0.14)], sh(col, 1.20))
	for t in [0.36, 0.58]:
		for i in n - 1:
			sp.line(lerpv(top[i], bot[i], t), lerpv(top[i + 1], bot[i + 1], t), 0.6, Color(0.14, 0.08, 0.03, 0.75))

## Franja de equipo que sigue la borda (capa 1).
static func band(sp: ArtUnits.Sp, top: Array, t0: float, t1: float, bot: Array, v: float = 0.88) -> void:
	sp.lay(1)
	for i in top.size() - 1:
		sp.poly([lerpv(top[i], bot[i], t0), lerpv(top[i + 1], bot[i + 1], t0), lerpv(top[i + 1], bot[i + 1], t1), lerpv(top[i], bot[i], t1)], ArtUnits.g(v))
	sp.lay(2)
	for i in top.size() - 1:
		sp.line(lerpv(top[i], bot[i], t0), lerpv(top[i + 1], bot[i + 1], t0), 0.8, OUT)
		sp.line(lerpv(top[i], bot[i], t1), lerpv(top[i + 1], bot[i + 1], t1), 0.8, OUT)

static func mast(sp: ArtUnits.Sp, base: Vector2, top: Vector2, w: float) -> void:
	sp.lay(2)
	sp.line(base, top, w + 1.6, OUT)
	sp.line(base, top, w, WOOD_D)
	sp.line(base + V(-0.4, 0), top + V(-0.4, 0), maxf(0.6, w * 0.3), sh(WOOD, 1.2))

static func flag(sp: ArtUnits.Sp, at: Vector2, len: float, wave: float) -> void:
	sp.lay(1)
	var p1 := at + V(len * 0.55, 1.6 + wave)
	var p2 := at + V(len, 0.4 + wave * 1.6)
	var p3 := at + V(len * 0.55, 4.6 + wave * 0.5)
	sp.poly([at + V(0, -0.4), p1, p2, p3, at + V(0, 4.2)], ArtUnits.g(0.9))
	sp.poly([at + V(0, 1.6), p1, p2, p3], ArtUnits.g(0.68))
	sp.lay(2)
	sp.line(at + V(0, -0.4), p1, 0.7, OUT)
	sp.line(p1, p2, 0.7, OUT)
	sp.line(p2, p3, 0.7, OUT)
	sp.line(p3, at + V(0, 4.2), 0.7, OUT)

## Vela cuadra: capa 1 (equipo) con vientre, costuras y verga delante.
static func square_sail(sp: ArtUnits.Sp, x0: float, x1: float, yt: float, yb: float, billow: float, team: bool, emblem: bool) -> void:
	var n := 7
	var pts_t: Array = []
	var pts_b: Array = []
	for i in n:
		var u := float(i) / float(n - 1)
		pts_t.append(V(lerpf(x0, x1, u), yt))
		var bulge := sin(u * PI) * billow
		pts_b.append(V(lerpf(x0 + 1.5, x1 - 1.5, u) + bulge * 0.4, yb + bulge))
	sp.lay(1 if team else 2)
	var base := 0.88 if team else 1.0
	var c := ArtUnits.g(base) if team else CANVAS
	for i in n - 1:
		var q: Array = [pts_t[i], pts_t[i + 1], pts_b[i + 1], pts_b[i]]
		var shade := 1.12 - 0.5 * (float(i) / float(n - 2))
		var col: Color = ArtUnits.g(clampf(base * shade, 0.0, 1.0)) if team else sh(CANVAS, shade * 0.92)
		sp.opoly(q, col, OUT, 0.7)
		sp.poly(q, col)
	sp.lay(2)
	for i in range(1, n - 1):
		sp.line(pts_t[i], pts_b[i], 0.5, Color(0.12, 0.08, 0.05, 0.45))
	sp.line(pts_b[0], pts_b[n - 1], 0.0, OUT)
	if emblem:
		var m := V((x0 + x1) * 0.5, (yt + yb) * 0.5 + billow * 0.4)
		var r := (x1 - x0) * 0.14
		sp.line(m + V(-r, 0), m + V(r, 0), 1.6, Color(0.96, 0.92, 0.80, 0.95))
		sp.line(m + V(0, -r), m + V(0, r), 1.6, Color(0.96, 0.92, 0.80, 0.95))
	# verga
	sp.line(V(x0 - 2.0, yt), V(x1 + 2.0, yt), 2.6, OUT)
	sp.line(V(x0 - 2.0, yt), V(x1 + 2.0, yt), 1.5, WOOD_D)

## Vela latina triangular de equipo.
static func lateen(sp: ArtUnits.Sp, tack: Vector2, head: Vector2, clew: Vector2, billow: float) -> void:
	var mid := (head + clew) * 0.5 + V(billow, 0)
	sp.lay(1)
	var tri1: Array = [tack, head, mid]
	var tri2: Array = [tack, mid, clew]
	sp.opoly([tack, head, clew], ArtUnits.g(0.88), OUT, 0.8)
	sp.poly(tri1, ArtUnits.g(1.0))
	sp.poly(tri2, ArtUnits.g(0.70))
	sp.poly([tack, mid, (tack + mid) * 0.5 + V(0, 2.0)], ArtUnits.g(0.60))
	sp.lay(2)
	sp.line(tack, head, 2.2, OUT)
	sp.line(tack, head, 1.2, WOOD_D)
	sp.line(tack, clew, 0.8, OUT)

static func person(sp: ArtUnits.Sp, feet: Vector2, tunic: Color, hat: Color, arm_to: Vector2) -> void:
	sp.lay(2)
	sp.line(feet + V(-0.8, 0), feet + V(-0.8, -4.4), 2.4, OUT)
	sp.line(feet + V(1.0, 0), feet + V(1.0, -4.4), 2.4, OUT)
	sp.line(feet + V(-0.8, 0), feet + V(-0.8, -4.4), 1.4, Color(0.34, 0.26, 0.17))
	sp.line(feet + V(1.0, 0), feet + V(1.0, -4.4), 1.4, Color(0.30, 0.22, 0.14))
	sp.rect(feet.x - 2.5, feet.y - 10.2, 5.2, 6.2, OUT)
	sp.rect(feet.x - 2.0, feet.y - 9.8, 4.2, 5.4, tunic)
	sp.rect(feet.x - 2.0, feet.y - 9.8, 1.4, 5.4, sh(tunic, 1.2))
	sp.line(feet + V(0.4, -9.0), arm_to, 2.4, OUT)
	sp.line(feet + V(0.4, -9.0), arm_to, 1.3, ArtUnits.SKIN)
	sp.disc(feet.x + 0.2, feet.y - 12.4, 2.5, OUT)
	sp.disc(feet.x + 0.2, feet.y - 12.4, 1.9, ArtUnits.SKIN)
	sp.ell(feet.x + 0.2, feet.y - 14.0, 3.4, 1.0, OUT)
	sp.ell(feet.x + 0.2, feet.y - 14.1, 3.0, 0.7, hat)
	sp.ell(feet.x + 0.2, feet.y - 14.9, 1.8, 1.1, hat)

# ---------------------------------------------------------------- barco de pesca

static func _p_pesca(sp: ArtUnits.Sp, f: int) -> void:
	var cyc := f % 4 if f < 4 else 0
	var sway: float = [0.0, 0.7, 0.0, -0.7][cyc]
	sp.at(0.0, sway)
	var top: Array = [V(8, 31), V(24, 33), V(46, 34), V(64, 32), V(75, 27)]
	var bot: Array = [V(15, 45), V(27, 46), V(46, 46), V(60, 45), V(70, 41)]
	hull(sp, top, bot, WOOD)
	band(sp, top, 0.0, 0.20, bot)
	# mástil y vela latina
	var hauling := f >= 4
	mast(sp, V(40, 33), V(40, 5), 2.4)
	var bil: float = 2.5 + sway * 1.5
	lateen(sp, V(41, 8), V(41, 31), V(68, 29), bil)
	flag(sp, V(40, 4), 9.0, sway * 0.8)
	# aparejos
	sp.lay(2)
	sp.line(V(40, 6), V(9, 31), 0.5, Color(0.2, 0.15, 0.1, 0.8))
	# red y caja de pescado
	sp.lay(2)
	sp.ell(58, 32.5, 7.0, 3.4, OUT)
	sp.ell(58, 32.5, 6.2, 2.7, Color(0.28, 0.40, 0.30))
	for k in 5:
		sp.line(V(53.0 + k * 2.4, 30.4), V(53.6 + k * 2.4, 34.4), 0.4, Color(0.65, 0.78, 0.66, 0.7))
	sp.rect(14, 28, 7.0, 5.6, OUT)
	sp.rect(14.5, 28.5, 6.0, 4.6, Color(0.46, 0.31, 0.16))
	sp.line(V(15, 30.3), V(20.5, 30.3), 0.5, WOOD_D)
	# pescador
	var arm := V(30.0, 26.0)
	if f == 4:
		arm = V(33.0, 21.0)
	elif f == 5:
		arm = V(32.0, 30.0)
	person(sp, V(26.0, 33.0), Color(0.62, 0.55, 0.40), Color(0.80, 0.66, 0.32), arm)
	if hauling:
		# red colgando por la borda
		var q: Array = []
		if f == 4:
			q = [V(33.0, 21.0), V(38.0, 27.0), V(48.0, 24.0), V(47.0, 33.0)]
			sp.line(V(33, 21), V(44, 30), 0.7, Color(0.65, 0.78, 0.66))
		else:
			sp.line(V(32, 30), V(43, 40), 0.7, Color(0.65, 0.78, 0.66))
			sp.ell(43.0, 39.0, 3.2, 2.2, Color(0.28, 0.40, 0.30))

# ---------------------------------------------------------------- transporte (coca)

static func _p_transporte(sp: ArtUnits.Sp, f: int) -> void:
	var cyc := f % 4
	var sway: float = [0.0, 0.8, 0.0, -0.8][cyc]
	sp.at(0.0, sway)
	var top: Array = [V(8, 30), V(24, 34), V(48, 36), V(72, 34), V(88, 31), V(96, 27)]
	var bot: Array = [V(15, 55), V(28, 58), V(48, 58), V(68, 58), V(82, 54), V(90, 47)]
	hull(sp, top, bot, WOOD)
	band(sp, top, 0.0, 0.16, bot)
	# castillo de popa
	sp.lay(2)
	sp.opoly([V(6, 29), V(28, 29), V(28, 21), V(8, 20)], sh(WOOD, 1.05), OUT, 1.0)
	sp.poly([V(6, 29), V(28, 29), V(28, 26), V(7, 25)], sh(WOOD, 0.82))
	for i in 5:
		sp.rect(9.0 + i * 4.2, 22.0, 1.8, 6.0, Color(0.18, 0.10, 0.04, 0.5))
	sp.line(V(8, 20), V(28, 21), 1.4, WOOD_D)
	# castillo de proa pequeño
	sp.opoly([V(80, 31), V(98, 28), V(97, 23), V(82, 24)], sh(WOOD, 1.0), OUT, 1.0)
	# barriles de carga
	for i in 3:
		var bx := 33.0 + i * 5.6
		sp.ell(bx, 34.0, 2.8, 3.4, OUT)
		sp.ell(bx, 34.0, 2.3, 2.9, Color(0.54, 0.36, 0.18))
		sp.line(V(bx - 2.0, 33.0), V(bx + 2.0, 33.0), 0.5, Color(0.2, 0.2, 0.22))
		sp.line(V(bx - 2.0, 35.5), V(bx + 2.0, 35.5), 0.5, Color(0.2, 0.2, 0.22))
	# mástil, vela cuadra, aparejos
	mast(sp, V(52, 36), V(52, 4), 2.8)
	square_sail(sp, 30.0, 74.0, 9.0, 32.0, 3.5 + sway * 1.2, true, true)
	flag(sp, V(52, 1), 11.0, sway * 0.8)
	sp.lay(2)
	sp.line(V(52, 5), V(10, 20), 0.5, Color(0.2, 0.15, 0.1, 0.8))
	sp.line(V(52, 5), V(96, 28), 0.5, Color(0.2, 0.15, 0.1, 0.8))
	# marineros asomando
	person(sp, V(18.0, 29.0), Color(0.62, 0.55, 0.40), Color(0.70, 0.30, 0.22), V(22.0, 24.0))
	if f == 5 or f == 4:
		sp.disc(60, 30, 0.0, OUT)

# ---------------------------------------------------------------- galera

static func _oar(sp: ArtUnits.Sp, lock: Vector2, ang: float) -> void:
	# remo desde el escálamo hasta el agua; ang gira respecto a la vertical
	var d := V(sin(ang), cos(ang))
	var tip := lock + d * 18.0
	var inner := lock - d * 5.0
	sp.line(inner, tip, 2.2, OUT)
	sp.line(inner, tip, 1.2, sh(WOOD, 1.1))
	sp.line(tip - d * 4.0, tip, 3.6, OUT)
	sp.line(tip - d * 4.0, tip, 2.4, sh(WOOD, 0.9))

static func _p_galera(sp: ArtUnits.Sp, f: int) -> void:
	var cyc := f % 4 if f < 4 else 0
	var ph := float(cyc) / 4.0 * TAU
	var dy: float = [0.0, 0.5, 0.0, -0.5][cyc]
	sp.at(0.0, dy)
	var top: Array = [V(6, 32), V(24, 35), V(50, 36), V(78, 36), V(100, 34), V(116, 28)]
	var bot: Array = [V(12, 45), V(26, 47), V(50, 47), V(80, 47), V(104, 45), V(113, 41)]
	# remos del lado cercano (detrás del casco, asoman por debajo): capa 0 primero
	sp.lay(0)
	for i in 7:
		var x := 22.0 + float(i) * 12.5
		_oar(sp, V(x, 37.0), sin(ph + float(i) * 0.15) * 0.62 - 0.18)
	hull(sp, top, bot, WOOD_D.lerp(WOOD, 0.55))
	# ariete (espolón) a la altura del agua
	sp.lay(2)
	var iron := Color(0.56, 0.58, 0.64)
	sp.opoly([V(112, 40), V(122, 43), V(112, 46)], iron, OUT, 0.9)
	sp.poly([V(112, 40), V(122, 43), V(112, 42.6)], sh(iron, 1.3))
	# proa curva con mascarón
	sp.line(V(116, 28), V(120, 21), 3.0, OUT)
	sp.line(V(116, 28), V(120, 21), 1.8, sh(WOOD, 1.0))
	sp.disc(120.5, 20.5, 2.2, OUT)
	sp.disc(120.5, 20.5, 1.6, Color(0.82, 0.68, 0.30))
	# popa elevada
	sp.line(V(6, 32), V(3, 22), 3.0, OUT)
	sp.line(V(6, 32), V(3, 22), 1.8, sh(WOOD, 1.0))
	# escudos de equipo a lo largo de la borda
	for i in 10:
		var x := 18.0 + float(i) * 9.4
		var y := 32.8 + (float(i) - 4.5) * 0.18
		sp.lay(1)
		sp.disc(x, y, 3.6, ArtUnits.g(0.84 if i % 2 == 0 else 0.62))
		sp.disc(x - 0.5, y - 0.6, 2.3, ArtUnits.g(1.0 if i % 2 == 0 else 0.78))
		sp.lay(2)
		sp.arc(x, y, 3.3, 0.0, TAU, 1.0, OUT)
		sp.disc(x, y, 0.9, Color(0.78, 0.80, 0.86))
	# soldados tras los escudos
	var shooting := f >= 4
	for i in 3:
		var x := 34.0 + i * 26.0
		sp.lay(2)
		sp.rect(x - 2.0, 22.0, 4.6, 6.0, OUT)
		sp.rect(x - 1.6, 22.4, 3.8, 5.2, Color(0.44, 0.40, 0.32))
		sp.disc(x + 0.2, 19.8, 2.5, OUT)
		sp.disc(x + 0.2, 19.8, 1.9, ArtUnits.SKIN)
		sp.ell(x + 0.2, 18.4, 2.3, 1.6, OUT)
		sp.ell(x + 0.2, 18.4, 1.9, 1.2, Color(0.62, 0.64, 0.70))
		if shooting:
			var pull := 1.0 if f == 4 else 0.0
			sp.line(V(x + 1.0, 24.0), V(x + 7.5, 24.0), 1.6, OUT)
			sp.line(V(x + 1.0, 24.0), V(x + 7.5, 24.0), 0.8, ArtUnits.SKIN)
			sp.arc(x + 8.0, 24.0, 6.0, -1.2, 1.2, 1.2, Color(0.55, 0.36, 0.18))
			if pull > 0.5:
				sp.line(V(x + 3.5, 24.0), V(x + 12.0, 24.0), 0.6, Color(0.95, 0.92, 0.84))
		else:
			sp.line(V(x + 1.0, 24.0), V(x + 3.5, 28.0), 1.6, OUT)
			sp.line(V(x + 1.0, 24.0), V(x + 3.5, 28.0), 0.8, ArtUnits.SKIN)
	# mástil con vela latina de equipo
	mast(sp, V(58, 33), V(58, 4), 2.4)
	lateen(sp, V(59, 8), V(59, 30), V(92, 28), 3.0)
	flag(sp, V(58, 2), 9.0, 0.5 if cyc % 2 == 0 else -0.5)

# ---------------------------------------------------------------- galeón

static func _p_galeon(sp: ArtUnits.Sp, f: int) -> void:
	var cyc := f % 4 if f < 4 else 0
	var sway: float = [0.0, 0.8, 0.0, -0.8][cyc]
	sp.at(0.0, sway)
	var top: Array = [V(6, 44), V(26, 48), V(52, 50), V(80, 50), V(104, 46), V(118, 38)]
	var bot: Array = [V(14, 70), V(30, 74), V(56, 74), V(82, 74), V(104, 68), V(114, 58)]
	var dark := Color(0.34, 0.22, 0.12)
	hull(sp, top, bot, dark)
	# franja de equipo sobre la línea de cañones
	band(sp, top, 0.30, 0.46, bot)
	# castillo de popa alto
	sp.lay(2)
	sp.opoly([V(5, 44), V(38, 47), V(38, 34), V(10, 31)], sh(dark, 1.15), OUT, 1.0)
	sp.poly([V(5, 44), V(38, 47), V(38, 42), V(6, 39)], sh(dark, 0.80))
	for i in 5:
		sp.rect(10.0 + i * 5.6, 33.0, 2.2, 6.0, Color(0.10, 0.06, 0.03, 0.6))
	sp.line(V(10, 31), V(38, 34), 1.6, Color(0.80, 0.68, 0.30))
	sp.rect(6, 43.0, 32, 1.0, Color(0.80, 0.68, 0.30))
	# castillo de proa
	sp.opoly([V(102, 46), V(121, 38), V(119, 31), V(104, 34)], sh(dark, 1.1), OUT, 1.0)
	sp.line(V(121, 38), V(126, 31), 3.0, OUT)
	sp.line(V(121, 38), V(126, 31), 1.8, sh(dark, 1.2))
	# troneras y cañones
	var fire := f >= 4
	for i in 5:
		var x := 36.0 + i * 11.4
		var y := lerpf(55.0, 54.0, float(i) / 4.0)
		sp.lay(2)
		sp.rect(x - 2.6, y - 2.6, 5.2, 5.2, OUT)
		sp.rect(x - 2.0, y - 2.0, 4.0, 4.0, Color(0.04, 0.03, 0.03))
		sp.rect(x - 2.2, y - 2.8, 4.4, 0.9, sh(dark, 1.4))
		if fire:
			var rec := 0.0 if f == 4 else -1.5
			sp.line(V(x - 1.0, y), V(x + 3.8 + rec, y), 2.8, OUT)
			sp.line(V(x - 1.0, y), V(x + 3.8 + rec, y), 1.7, Color(0.28, 0.29, 0.33))
			if f == 4:
				sp.disc(x + 6.4, y, 3.2, Color(1.0, 0.82, 0.30, 0.95))
				sp.disc(x + 6.8, y, 1.9, Color(1.0, 0.98, 0.80, 0.95))
				sp.disc(x + 9.5, y - 2.0, 3.2, Color(0.86, 0.86, 0.88, 0.85))
				sp.disc(x + 12.5, y - 3.4, 2.6, Color(0.80, 0.80, 0.82, 0.7))
			else:
				sp.disc(x + 7.0, y - 3.0, 3.8, Color(0.82, 0.82, 0.85, 0.75))
				sp.disc(x + 10.5, y - 5.0, 3.2, Color(0.78, 0.78, 0.80, 0.6))
				sp.disc(x + 13.0, y - 6.5, 2.6, Color(0.76, 0.76, 0.78, 0.45))
	# tres mástiles
	var billow: float = 4.0 + sway * 1.5
	mast(sp, V(34, 48), V(34, 14), 2.4)
	mast(sp, V(62, 50), V(62, 3), 3.0)
	mast(sp, V(90, 50), V(90, 11), 2.6)
	# mesana latina, mayor y trinquete (equipo)
	lateen(sp, V(35, 20), V(35, 44), V(50, 44), 2.0)
	square_sail(sp, 44.0, 80.0, 8.0, 32.0, billow, true, true)
	square_sail(sp, 47.0, 77.0, 34.0, 46.0, billow * 0.5, false, false)
	square_sail(sp, 76.0, 104.0, 16.0, 38.0, billow * 0.9, true, false)
	flag(sp, V(62, 0), 12.0, sway * 0.9)
	flag(sp, V(90, 9), 9.0, -sway * 0.9)
	sp.lay(2)
	sp.line(V(62, 4), V(8, 31), 0.5, Color(0.2, 0.15, 0.1, 0.8))
	sp.line(V(62, 4), V(124, 34), 0.5, Color(0.2, 0.15, 0.1, 0.8))
