class_name ArtCiv
extends RefCounted
## Las ocho unidades únicas de las civilizaciones, dibujadas con las mismas piezas que ArtUnits y ArtMounts
## (esqueleto, cabezas, miembros con volumen, caballo) y las mismas tres capas: fondo, equipo (se tiñe) y frente.
## A la escala de juego (~1/3 de la hoja) mandan la silueta, el color del yelmo y el arma: por eso cada una cambia
## de cabeza, de arma y de ropa respecto a su unidad base.
##   conquistador (castellanos) · hachero (francos) · arquero_largo (ingleses, ver ArtUnits._p_arquero) ·
##   teutonico (teutones) · berserker (vikingos) · catafracta (bizantinos) · mameluco (sarracenos) · mangudai (mongoles)

const OUT := ArtUnits.OUT

static func V(x: float, y: float) -> Vector2:
	return Vector2(x, y)

static func sh(c: Color, f: float) -> Color:
	return ArtUnits.sh(c, f)

const GOLD := Color(0.86, 0.74, 0.34)
const STEEL := Color(0.66, 0.68, 0.74)

# ---------------------------------------------------------------- armas

## Hacha arrojadiza (francisca): mango corto y hoja de un solo filo.
static func _taxe(sp: ArtUnits.Sp, h: Vector2, dir: Vector2) -> void:
	var d := dir.normalized()
	var n := V(-d.y, d.x)
	var tip := h + d * 9.0
	sp.lay(2)
	sp.line(h - d * 2.2, tip, 3.4, OUT)
	sp.line(h - d * 2.2, tip, 1.9, Color(0.54, 0.36, 0.17))
	sp.line(h - d * 2.2 + V(-0.3, -0.3), tip + V(-0.3, -0.3), 0.6, Color(0.76, 0.56, 0.30))
	var a := tip + n * -3.0 + d * 0.5
	var b := tip + n * 4.4 + d * 0.5
	var c := tip - d * 4.6 + n * 0.6
	sp.tri(a - d * 0.8, b + d * 0.9, c - d * 0.6, OUT)
	sp.tri(a, b, c, Color(0.66, 0.68, 0.74))
	sp.line(a + d * 0.2, b + d * 0.2, 1.0, Color(0.92, 0.94, 0.98))

## Hacha de guerra a dos manos (berserker): mango largo y hoja grande.
static func _great_axe(sp: ArtUnits.Sp, h: Vector2, dir: Vector2) -> void:
	var d := dir.normalized()
	var n := V(-d.y, d.x)
	var tail := h - d * 6.0
	var tip := h + d * 17.0
	sp.lay(2)
	sp.line(tail, tip, 3.8, OUT)
	sp.line(tail, tip, 2.2, Color(0.50, 0.33, 0.15))
	sp.line(tail + V(-0.3, -0.3), tip + V(-0.3, -0.3), 0.7, Color(0.74, 0.54, 0.28))
	var a := tip + n * -4.6 - d * 0.5
	var b := tip + n * 6.4 - d * 0.5
	var c := tip - d * 7.4 + n * 0.8
	sp.tri(a - d * 1.0 + n * 0.3, b + d * 1.0, c - d * 0.8, OUT)
	sp.tri(a, b, c, Color(0.64, 0.66, 0.72))
	sp.tri(a, b, tip - d * 2.4 + n * 0.8, Color(0.84, 0.86, 0.92))
	sp.line(a + d * 0.1, b + d * 0.1, 1.2, Color(0.95, 0.96, 1.0))

## Alfanje: hoja curva hacia delante.
static func _scimitar(sp: ArtUnits.Sp, h: Vector2, dir: Vector2) -> void:
	var d := dir.normalized()
	var n := V(-d.y, d.x)
	if n.x < 0.0:
		n = -n
	sp.lay(2)
	sp.line(h - d * 2.4, h, 2.6, OUT)
	sp.line(h - d * 2.4, h, 1.4, Color(0.30, 0.18, 0.09))
	sp.line(h - n * 2.6, h + n * 2.6, 2.4, OUT)
	sp.line(h - n * 2.4, h + n * 2.4, 1.2, GOLD)
	var pts: Array = [h + d * 0.6, h + d * 6.5 + n * 0.3, h + d * 12.0 + n * 1.8, h + d * 16.0 + n * 4.0, h + d * 18.0 + n * 6.4]
	for i in 4:
		sp.line(pts[i], pts[i + 1], 3.6, OUT)
	for i in 4:
		sp.line(pts[i], pts[i + 1], 2.4, Color(0.86, 0.89, 0.95))
	for i in 4:
		sp.line(pts[i] - n * 0.6, pts[i + 1] - n * 0.6, 0.8, Color(1, 1, 1, 0.8))

## Arcabuz: caja de madera, cañón de hierro, serpentín de la mecha y, al disparar, fogonazo y humo.
static func _gun(sp: ArtUnits.Sp, butt: Vector2, dir: Vector2, flash: bool) -> void:
	var d := dir.normalized()
	var n := V(-d.y, d.x)
	var muzzle := butt + d * 23.0
	sp.lay(2)
	sp.line(butt - d * 1.0, butt + d * 8.0, 4.6, OUT)
	sp.line(butt - d * 1.0, butt + d * 8.0, 3.2, Color(0.50, 0.32, 0.15))
	sp.line(butt + d * 6.0, muzzle, 3.6, OUT)
	sp.line(butt + d * 6.0, muzzle, 2.3, Color(0.34, 0.35, 0.40))
	sp.line(butt + d * 6.0 - n * 0.5, muzzle - n * 0.5, 0.8, Color(0.74, 0.76, 0.82))
	sp.line(butt + d * 7.0, butt + d * 7.6 + n * 2.8, 1.2, OUT)       # serpentín
	sp.disc(muzzle.x + d.x * 0.5, muzzle.y + d.y * 0.5, 1.5, OUT)
	if flash:
		sp.disc(muzzle.x + d.x * 3.2, muzzle.y + d.y * 3.2, 4.6, Color(1.0, 0.62, 0.18, 0.85))
		sp.disc(muzzle.x + d.x * 3.8, muzzle.y + d.y * 3.8, 3.0, Color(1.0, 0.92, 0.55, 0.95))
		sp.disc(muzzle.x + d.x * 7.5, muzzle.y + d.y * 7.5 - 2.0, 4.2, Color(0.88, 0.88, 0.90, 0.55))
		sp.disc(muzzle.x + d.x * 11.0, muzzle.y + d.y * 11.0 - 3.5, 3.4, Color(0.88, 0.88, 0.90, 0.35))

# ---------------------------------------------------------------- infantería

## Hachero (francos): infantería que lanza hachas. Frames: 0 quieto, 1-4 marcha, 5 prepara, 6 lanza, 7 apunta.
static func _p_hachero(sp: ArtUnits.Sp, f: int) -> void:
	sp.at(0.0, 12.0)
	var pose := ArtUnits._mk(ArtUnits.walk_pose(f), {})
	var lean := 0.0
	var dir := V(0.45, -0.9)
	var mode := 0
	if f <= ArtUnits.F_WALK + 3:
		pose["an"] = [0.35, 1.0]
	elif f == 5:
		pose = ArtUnits._mk({"ln": [0.18, 0.12], "lf": [-0.20, 0.12]}, {"an": [-2.35, 0.25], "af": [0.30, 0.50], "bob": 0.0})
		dir = V(-0.78, -0.62)
		lean = -1.4
		mode = 1
	elif f == 6:
		pose = ArtUnits._mk({"ln": [0.50, 0.12], "lf": [-0.40, 0.25]}, {"an": [1.55, 0.10], "af": [-0.50, 0.40], "bob": 0.0})
		lean = 2.2
		mode = 2
	else:
		pose = ArtUnits._mk({"ln": [0.18, 0.12], "lf": [-0.20, 0.12]}, {"an": [2.1, 0.20], "af": [0.20, 0.50], "bob": 0.0})
		dir = V(0.93, -0.36)
		lean = 0.5
		mode = 3
	var j0 := ArtUnits.skel(pose, lean)
	var s0: Vector2 = j0["sh"]
	# escudo redondo a la espalda
	sp.lay(0)
	sp.disc(s0.x - 5.2, s0.y + 6.0, 7.4, OUT)
	sp.disc(s0.x - 5.2, s0.y + 6.0, 6.6, Color(0.50, 0.33, 0.16))
	sp.disc(s0.x - 5.6, s0.y + 5.6, 5.0, Color(0.62, 0.42, 0.20))
	sp.disc(s0.x - 5.2, s0.y + 6.0, 1.8, Color(0.70, 0.72, 0.78))
	var sleeve := Color(0.74, 0.66, 0.48)
	var j := ArtUnits._inf_body(sp, pose, lean, Color(0.34, 0.28, 0.20), Color(0.24, 0.16, 0.09), 3.4, sleeve, Color(0.62, 0.46, 0.20), Color(0.74, 0.58, 0.26, 0.95))
	var hip: Vector2 = j["hip"]
	# segunda hacha al cinto
	sp.lay(2)
	sp.line(hip + V(-3.0, 0.4), hip + V(-7.0, 6.2), 2.6, OUT)
	sp.line(hip + V(-3.0, 0.4), hip + V(-7.0, 6.2), 1.4, Color(0.54, 0.36, 0.17))
	sp.tri(hip + V(-7.8, 4.6), hip + V(-4.6, 7.4), hip + V(-9.8, 7.8), Color(0.66, 0.68, 0.74))
	var hd: Vector2 = j["head"]
	ArtUnits.helm_cap(sp, hd, Color(0.62, 0.64, 0.70))
	ArtUnits.arm_seg(sp, j, "n", sleeve, ArtUnits.SKIN)
	var hn: Vector2 = j["hand_n"]
	if mode == 2:
		_taxe(sp, hn + V(9.0, -4.0), V(0.9, 0.5))       # ya vuela
		sp.line(hn + V(3.0, -1.0), hn + V(8.0, -3.0), 0.8, Color(1, 1, 1, 0.45))
	else:
		_taxe(sp, hn, dir)
	ArtUnits.hand(sp, hn)
	if mode == 1 or mode == 3:
		ArtUnits.hand(sp, j["hand_f"])

## Caballero teutónico (teutones): infantería pesada con yelmo de cubo, sobrevesta con cruz negra y escudo grande.
static func _p_teutonico(sp: ArtUnits.Sp, f: int) -> void:
	sp.at(0.0, 12.0)
	var mail := Color(0.60, 0.62, 0.68)
	var pose := ArtUnits._mk(ArtUnits.walk_pose(f), {})
	var lean := 0.0
	var sdir := V(0.75, -0.62)
	var drawn := false
	if f <= ArtUnits.F_WALK + 3:
		pose["an"] = [0.30, 0.95]
	elif f == 5:
		pose = ArtUnits._mk(ArtUnits.STANCE_W, {"an": [0.40, 1.00], "af": [-2.5, 0.30], "bob": 0.0})
		lean = -1.2
		sdir = V(-0.20, -1.0)
		drawn = true
	else:
		pose = ArtUnits._mk(ArtUnits.STANCE_S, {"an": [0.45, 0.95], "af": [2.0, 0.20], "bob": 0.0})
		lean = 2.4
		sdir = V(0.90, 0.45)
		drawn = true
	var j := ArtUnits.skel(pose, lean)
	var hip: Vector2 = j["hip"]
	var s: Vector2 = j["sh"]
	sp.lay(0)
	if not drawn:
		sp.line(hip + V(-1.5, 0.0), hip + V(-9.5, 9.0), 3.6, OUT)
		sp.line(hip + V(-1.5, 0.0), hip + V(-9.5, 9.0), 2.2, Color(0.30, 0.18, 0.10))
	ArtUnits.leg(sp, j, "f", Color(0.26, 0.24, 0.24), Color(0.18, 0.13, 0.08))
	ArtUnits.arm_seg(sp, j, "f", mail, ArtUnits.SKIN, false)
	if drawn:
		ArtUnits.sword(sp, j["hand_f"], sdir, 0)
	ArtUnits.tunic(sp, j, 6.0, 0.92)
	sp.lay(2)
	ArtUnits.leg(sp, j, "n", Color(0.26, 0.24, 0.24), Color(0.18, 0.13, 0.08))
	ArtUnits.belt(sp, j, Color(0.20, 0.13, 0.07))
	# cruz negra de la orden sobre la sobrevesta
	var ink := Color(0.05, 0.05, 0.06)
	sp.rect(s.x - 0.8, s.y + 0.2, 2.0, 17.0, ink)
	sp.rect(s.x - 3.8, s.y + 3.6, 7.6, 2.2, ink)
	if not drawn:
		sp.line(hip + V(2.8, -1.6), hip + V(3.8, -5.6), 1.8, OUT)
		sp.line(hip + V(2.8, -1.6), hip + V(3.8, -5.0), 1.0, Color(0.34, 0.20, 0.10))
		sp.line(hip + V(1.2, -3.4), hip + V(6.2, -3.8), 1.6, OUT)
		sp.line(hip + V(1.4, -3.4), hip + V(6.0, -3.8), 0.8, GOLD)
	var hd: Vector2 = j["head"]
	ArtUnits.head(sp, hd, ArtUnits.SKIN, Color(0.14, 0.10, 0.07))
	# yelmo de cubo: tapa plana, rendija de visión y agujeros de respiración
	var hp: Array = [V(hd.x - 4.6, hd.y + 6.2), V(hd.x + 5.0, hd.y + 6.2), V(hd.x + 4.8, hd.y - 5.0), V(hd.x - 4.4, hd.y - 5.0)]
	sp.poly(ArtUnits.grow(hp, 0.95), OUT)
	sp.poly(hp, STEEL)
	sp.poly([hp[3], V(hd.x - 1.4, hd.y - 5.0), V(hd.x - 1.4, hd.y + 6.2), hp[0]], sh(STEEL, 1.22))
	sp.poly([V(hd.x + 2.0, hd.y - 5.0), hp[2], hp[1], V(hd.x + 2.0, hd.y + 6.2)], sh(STEEL, 0.72))
	sp.rect(hd.x - 4.6, hd.y - 5.0, 9.6, 1.2, sh(STEEL, 0.80))
	sp.rect(hd.x - 0.6, hd.y - 1.8, 5.4, 1.1, Color(0.03, 0.03, 0.03))
	for k in 3:
		sp.rect(hd.x + 1.8 + k * 1.1, hd.y + 1.8, 0.5, 0.5, Color(0.10, 0.09, 0.09))
	sp.rect(hd.x + 0.2, hd.y - 5.0, 1.1, 11.0, sh(STEEL, 0.88))
	ArtUnits.arm_seg(sp, j, "n", mail, ArtUnits.SKIN, false)
	var hn: Vector2 = j["hand_n"]
	ArtUnits.shield(sp, hn + V(2.8, -0.8), 6.4, 8.8, GOLD)

## Berserker (vikingos): melena y barba salvajes, torso al aire con piel de lobo y hacha a dos manos.
static func _p_berserker(sp: ArtUnits.Sp, f: int) -> void:
	sp.at(0.0, 12.0)
	var pose := ArtUnits._mk(ArtUnits.walk_pose(f), {})
	var lean := 0.0
	var dir := V(0.55, -0.85)
	if f <= ArtUnits.F_WALK + 3:
		pose["an"] = [0.25, 0.85]
	elif f == 5:
		pose = ArtUnits._mk(ArtUnits.STANCE_W, {"an": [-2.6, 0.20], "af": [-2.3, 0.30], "bob": 0.0})
		dir = V(-0.55, -0.85)
		lean = -1.6
	else:
		pose = ArtUnits._mk(ArtUnits.STANCE_S, {"an": [1.75, 0.10], "af": [1.55, 0.25], "bob": 0.0})
		dir = V(0.85, 0.55)
		lean = 2.8
	var j0 := ArtUnits.skel(pose, lean)
	var s0: Vector2 = j0["sh"]
	# escudo redondo a la espalda
	sp.lay(0)
	sp.disc(s0.x - 5.4, s0.y + 6.5, 7.2, OUT)
	sp.disc(s0.x - 5.4, s0.y + 6.5, 6.4, Color(0.46, 0.30, 0.15))
	sp.disc(s0.x - 5.8, s0.y + 6.1, 4.6, Color(0.60, 0.40, 0.19))
	sp.disc(s0.x - 5.4, s0.y + 6.5, 1.7, Color(0.70, 0.72, 0.78))
	var bare := Color(0.90, 0.72, 0.56)
	var hair := Color(0.66, 0.32, 0.12)
	var j := ArtUnits._inf_body(sp, pose, lean, Color(0.34, 0.26, 0.19), Color(0.22, 0.15, 0.09), 2.6, bare, hair, Color(0.66, 0.32, 0.12, 0.97))
	var s: Vector2 = j["sh"]
	var hd: Vector2 = j["head"]
	# piel de lobo sobre los hombros
	sp.lay(2)
	var fur: Array = [V(s.x - 5.6, s.y - 1.6), V(s.x + 3.2, s.y - 2.0), V(s.x + 5.0, s.y + 3.4), V(s.x - 0.5, s.y + 5.4), V(s.x - 6.6, s.y + 3.0)]
	sp.poly(ArtUnits.grow(fur, 0.9), OUT)
	sp.poly(fur, Color(0.52, 0.51, 0.50))
	sp.poly([fur[0], V(s.x - 1.0, s.y - 1.8), V(s.x - 2.0, s.y + 4.4), fur[4]], Color(0.70, 0.69, 0.66))
	sp.poly([V(s.x + 1.6, s.y - 1.9), fur[1], fur[2], V(s.x + 1.0, s.y + 4.8)], Color(0.34, 0.33, 0.33))
	for k in 4:
		sp.line(V(s.x - 5.0 + k * 2.6, s.y + 3.4), V(s.x - 5.6 + k * 2.6, s.y + 6.2), 0.9, Color(0.46, 0.45, 0.44))
	# cinta de guerra (equipo) y mechones
	sp.lay(1)
	sp.line(V(hd.x - 3.8, hd.y - 2.0), V(hd.x + 3.2, hd.y - 2.5), 1.6, ArtUnits.g(0.85))
	sp.lay(2)
	sp.ell(hd.x - 3.4, hd.y + 1.8, 1.8, 4.4, sh(hair, 0.9))
	ArtUnits.arm_seg(sp, j, "n", bare, ArtUnits.SKIN)
	var hn: Vector2 = j["hand_n"]
	_great_axe(sp, hn, dir)
	ArtUnits.hand(sp, hn)
	ArtUnits.hand(sp, j["hand_f"])

# ---------------------------------------------------------------- caballería

## Catafracta (bizantinos): caballo blanco acorazado, jinete con yelmo dorado, escudo redondo y lanza larga.
static func _p_catafracta(sp: ArtUnits.Sp, f: int) -> void:
	var cp := ArtMounts._cavalry_pose(f, "caballero")
	sp.at(0.0, 4.0)
	var coat := Color(0.80, 0.80, 0.78)
	var mouth := ArtMounts.horse(sp, float(cp["phase"]), coat, Color(0.34, 0.32, 0.30), false, true, true)
	var bob: float = ArtMounts._gait(float(cp["phase"]))["bob"]
	sp.at(7.0, 1.5 + bob)
	var pose := {"ln": [0.5, 1.0], "lf": [0.5, 1.0], "an": [0.55, 0.95], "af": cp["an"], "bob": 0.0}
	if f == 6:
		pose["an"] = [0.45, 0.95]
	var j := ArtUnits.skel(pose, float(cp["lean"]))
	sp.lay(0)
	ArtUnits.arm_seg(sp, j, "f", STEEL, STEEL, false)
	ArtUnits.tunic(sp, j, 3.0, 0.84, GOLD)
	sp.lay(2)
	ArtMounts._rider_leg(sp, j["hip"], Color(0.50, 0.52, 0.58), Color(0.56, 0.58, 0.64))
	ArtUnits.belt(sp, j, Color(0.30, 0.16, 0.30))
	var s: Vector2 = j["sh"]
	# coraza de escamas
	sp.rect(s.x - 4.2, s.y - 1.4, 9.2, 4.2, OUT)
	sp.rect(s.x - 3.8, s.y - 1.1, 8.4, 3.5, sh(GOLD, 0.92))
	for k in 4:
		sp.rect(s.x - 3.8 + k * 2.1, s.y + 0.4, 1.0, 1.0, sh(GOLD, 1.3))
		sp.rect(s.x - 2.8 + k * 2.1, s.y + 1.6, 1.0, 1.0, sh(GOLD, 0.7))
	var hd: Vector2 = j["head"]
	ArtUnits.head(sp, hd, ArtUnits.SKIN, Color(0.14, 0.10, 0.07), Color(0.14, 0.10, 0.07, 0.9))
	# yelmo cónico dorado con cubrenuca de malla y nasal
	var hp: Array = [V(hd.x - 4.4, hd.y + 5.0), V(hd.x + 1.4, hd.y + 5.0), V(hd.x + 4.0, hd.y - 2.4), V(hd.x + 0.8, hd.y - 8.6), V(hd.x - 3.6, hd.y - 2.8)]
	sp.poly(ArtUnits.grow(hp, 0.9), OUT)
	sp.poly(hp, GOLD)
	sp.poly([hp[4], V(hd.x - 0.8, hd.y - 8.4), V(hd.x - 1.2, hd.y + 5.0), hp[0]], sh(GOLD, 1.22))
	sp.poly([V(hd.x + 1.0, hd.y - 8.0), hp[2], hp[1], V(hd.x + 0.8, hd.y + 5.0)], sh(GOLD, 0.74))
	sp.rect(hd.x - 4.2, hd.y - 2.6, 8.4, 1.1, sh(GOLD, 0.72))
	sp.rect(hd.x + 2.6, hd.y - 2.4, 1.1, 5.0, OUT)
	sp.rect(hd.x + 2.7, hd.y - 2.2, 0.7, 4.6, sh(GOLD, 0.9))
	sp.lay(1)
	var fl := 0.0 if f == 0 else 1.6 * sin(float(f) * 1.6)
	sp.line(V(hd.x + 0.6, hd.y - 8.4), V(hd.x - 1.6, hd.y - 12.6 + fl), 3.2, ArtUnits.g(0.92))
	sp.line(V(hd.x - 1.6, hd.y - 12.6 + fl), V(hd.x - 6.8, hd.y - 11.0 + fl * 1.4), 2.8, ArtUnits.g(0.70))
	sp.lay(2)
	ArtUnits.arm_seg(sp, j, "n", STEEL, STEEL, false)
	ArtUnits.spear(sp, j["hand_f"], cp["lance"], 66.0)
	var hn: Vector2 = j["hand_n"]
	ArtUnits.shield(sp, hn + V(2.4, 1.0), 7.0, 7.0, GOLD)
	var hf: Vector2 = j["hand_f"]
	sp.line(hf, mouth - V(7.0, -2.5 - bob - 3.0), 0.5, Color(0.30, 0.18, 0.08))

## Mameluco (sarracenos): caballo alazán, jinete de túnica clara con turbante, alfanje y rodela.
static func _p_mameluco(sp: ArtUnits.Sp, f: int) -> void:
	var cp := ArtMounts._cavalry_pose(f, "jinete")
	sp.at(0.0, 0.0)
	var coat := Color(0.74, 0.54, 0.30)
	var mouth := ArtMounts.horse(sp, float(cp["phase"]), coat, Color(0.16, 0.11, 0.07), true, false, true)
	var bob: float = ArtMounts._gait(float(cp["phase"]))["bob"]
	sp.at(7.0, -2.5 + bob)
	var pose := {"ln": [0.5, 1.0], "lf": [0.5, 1.0], "an": cp["an"], "af": cp["af"], "bob": 0.0}
	var j := ArtUnits.skel(pose, float(cp["lean"]))
	var cream := Color(0.90, 0.86, 0.72)
	sp.lay(0)
	ArtUnits.arm_seg(sp, j, "f", cream, ArtUnits.SKIN)
	ArtUnits.tunic(sp, j, 2.5, 0.86)
	sp.lay(2)
	ArtMounts._rider_leg(sp, j["hip"], Color(0.30, 0.20, 0.10), Color(0.84, 0.80, 0.66))
	ArtUnits.belt(sp, j, Color(0.56, 0.16, 0.14))
	var hd: Vector2 = j["head"]
	ArtUnits.head(sp, hd, Color(0.80, 0.60, 0.44), Color(0.22, 0.14, 0.08))
	# perilla y bigote finos (la cara queda legible a tamaño de juego)
	sp.ell(hd.x + 1.9, hd.y + 3.9, 1.1, 1.3, Color(0.14, 0.09, 0.05))
	sp.line(V(hd.x + 1.0, hd.y + 1.9), V(hd.x + 3.2, hd.y + 2.0), 0.7, Color(0.14, 0.09, 0.05))
	# turbante (equipo) con cola caída
	sp.lay(1)
	sp.ell(hd.x - 0.4, hd.y - 2.4, 4.9, 3.8, ArtUnits.g(0.88))
	sp.ell(hd.x - 1.4, hd.y - 3.4, 2.8, 1.8, ArtUnits.g(1.0))
	sp.ell(hd.x + 0.6, hd.y - 1.0, 4.4, 1.5, ArtUnits.g(0.66))
	sp.tri(V(hd.x - 3.6, hd.y - 1.0), V(hd.x - 8.6, hd.y + 4.0 + 0.8 * sin(float(f))), V(hd.x - 2.0, hd.y + 3.4), ArtUnits.g(0.74))
	sp.lay(2)
	sp.line(V(hd.x - 4.4, hd.y - 2.6), V(hd.x + 4.0, hd.y - 0.8), 0.7, OUT)
	sp.line(V(hd.x, hd.y - 6.4), V(hd.x, hd.y - 8.6), 1.4, OUT)
	sp.disc(hd.x, hd.y - 8.8, 1.0, GOLD)
	ArtUnits.arm_seg(sp, j, "n", cream, ArtUnits.SKIN)
	var hf: Vector2 = j["hand_f"]
	var hn: Vector2 = j["hand_n"]
	_scimitar(sp, hn, cp["lance"])
	sp.line(hf, mouth - V(7.0, -2.5 - bob), 0.6, Color(0.30, 0.18, 0.08))
	ArtUnits.shield(sp, hf + V(2.0, 1.0), 4.8, 4.8, GOLD)

## Postura común de los jinetes que disparan: 0 en marcha, 1 apunta, 2 dispara, 3 mantiene la puntería.
static func _shooter_pose(f: int) -> Dictionary:
	var ph := -1.0
	if f >= 1 and f <= 4:
		ph = float(f - 1) / 4.0
	elif f == 5 or f == 7:
		ph = 0.10
	elif f == 6:
		ph = 0.34
	var pose := {"ln": [0.5, 1.0], "lf": [0.5, 1.0], "an": [0.75, 0.30], "af": [0.35, 0.55], "bob": 0.0}
	var lean := 0.0
	var mode := 0
	if f >= 1 and f <= 4:
		lean = 0.7
	elif f == 5:
		pose["an"] = [1.35, 0.12]
		pose["af"] = [0.85, 1.20]
		mode = 1
	elif f == 6:
		pose["an"] = [1.45, 0.05]
		pose["af"] = [-1.00, 1.00]
		lean = -0.6
		mode = 2
	elif f == 7:
		pose["an"] = [1.45, 0.05]
		pose["af"] = [-1.57, 2.90]
		lean = 0.4
		mode = 3
	return {"ph": ph, "pose": pose, "lean": lean, "mode": mode}

## Mangudai (mongoles): caballo pardo, jinete con gorro de piel, coraza de láminas y arco corto.
static func _p_mangudai(sp: ArtUnits.Sp, f: int) -> void:
	var sp0 := _shooter_pose(f)
	var ph: float = sp0["ph"]
	var mode: int = sp0["mode"]
	sp.at(0.0, 0.0)
	var mouth := ArtMounts.horse(sp, ph, Color(0.40, 0.28, 0.18), Color(0.12, 0.09, 0.07), false, false, true)
	var bob: float = ArtMounts._gait(ph)["bob"]
	sp.at(7.0, -2.5 + bob)
	var j := ArtUnits.skel(sp0["pose"], float(sp0["lean"]))
	var coat := Color(0.52, 0.28, 0.18)
	sp.lay(0)
	ArtUnits.quiver(sp, j)
	ArtUnits.arm_seg(sp, j, "f", coat, ArtUnits.SKIN)
	ArtUnits.tunic(sp, j, 2.0, 0.84)
	sp.lay(2)
	ArtMounts._rider_leg(sp, j["hip"], Color(0.20, 0.13, 0.07), Color(0.30, 0.24, 0.16))
	ArtUnits.belt(sp, j, Color(0.22, 0.13, 0.06))
	var hd: Vector2 = j["head"]
	ArtUnits.head(sp, hd, Color(0.86, 0.68, 0.50), Color(0.10, 0.07, 0.05), Color(0.10, 0.07, 0.05, 0.9), true)
	# gorro de fieltro (equipo) con ribete de piel y borla
	sp.lay(1)
	sp.tri(V(hd.x - 4.0, hd.y - 2.0), V(hd.x + 3.6, hd.y - 2.4), V(hd.x - 0.2, hd.y - 8.6), ArtUnits.g(0.86))
	sp.tri(V(hd.x - 4.0, hd.y - 2.0), V(hd.x - 0.8, hd.y - 2.2), V(hd.x - 0.8, hd.y - 8.0), ArtUnits.g(1.0))
	sp.lay(2)
	sp.ell(hd.x - 0.2, hd.y - 1.8, 5.2, 2.4, OUT)
	sp.ell(hd.x - 0.2, hd.y - 1.8, 4.6, 1.9, Color(0.34, 0.26, 0.18))
	sp.ell(hd.x - 1.0, hd.y - 2.4, 2.4, 0.8, Color(0.52, 0.42, 0.30))
	sp.disc(hd.x - 0.2, hd.y - 8.8, 1.1, Color(0.80, 0.22, 0.16))
	var s: Vector2 = j["sh"]
	for k in 3:
		sp.line(V(s.x - 3.2, s.y + 1.4 + k * 2.6), V(s.x + 3.6, s.y + 1.8 + k * 2.6), 0.7, Color(0.28, 0.16, 0.10))
	ArtUnits.arm_seg(sp, j, "n", coat, ArtUnits.SKIN)
	var gn: Vector2 = j["hand_n"]
	var gf: Vector2 = j["hand_f"]
	match mode:
		0:
			ArtUnits.bow(sp, gn + V(1.0, 0.5), gn + V(1.0, 0.5), false, false, 0.82)
			sp.line(gf, mouth - V(7.0, -2.5 - bob), 0.6, Color(0.30, 0.18, 0.08))
		1, 3:
			ArtUnits.bow(sp, gn + V(1.0, 0.0), gf, true, true, 0.82)
		2:
			ArtUnits.bow(sp, gn + V(1.0, 0.0), gn + V(1.0, 0.0), false, false, 0.82)
	if mode == 1 or mode == 3:
		ArtUnits.hand(sp, gf, ArtUnits.SKIN)
		ArtUnits.hand(sp, gn, ArtUnits.SKIN)

## Conquistador (castellanos): caballo bayo, jinete con morrión y coraza, y arcabuz.
static func _p_conquistador(sp: ArtUnits.Sp, f: int) -> void:
	var sp0 := _shooter_pose(f)
	var ph: float = sp0["ph"]
	var mode: int = sp0["mode"]
	sp.at(0.0, 0.0)
	var mouth := ArtMounts.horse(sp, ph, Color(0.34, 0.21, 0.13), Color(0.10, 0.07, 0.05), true, false, true)
	var bob: float = ArtMounts._gait(ph)["bob"]
	sp.at(7.0, -2.5 + bob)
	var pose: Dictionary = sp0["pose"]
	if mode == 1:
		pose["an"] = [1.20, 0.30]
		pose["af"] = [0.95, 1.00]
	elif mode == 2 or mode == 3:
		pose["an"] = [1.50, 0.05]
		pose["af"] = [1.00, 1.45]
	var j := ArtUnits.skel(pose, float(sp0["lean"]))
	var sleeve := Color(0.78, 0.18, 0.16)
	sp.lay(0)
	ArtUnits.arm_seg(sp, j, "f", sleeve, ArtUnits.SKIN)
	ArtUnits.tunic(sp, j, 2.0, 0.84, GOLD)
	sp.lay(2)
	ArtMounts._rider_leg(sp, j["hip"], Color(0.22, 0.14, 0.08), Color(0.58, 0.18, 0.16))
	ArtUnits.belt(sp, j, Color(0.24, 0.15, 0.07))
	var s: Vector2 = j["sh"]
	# peto de acero con arista central
	sp.rect(s.x - 4.2, s.y - 1.4, 9.2, 7.0, OUT)
	sp.rect(s.x - 3.8, s.y - 1.1, 8.4, 6.4, STEEL)
	sp.rect(s.x - 3.8, s.y - 1.1, 3.8, 6.4, sh(STEEL, 1.2))
	sp.rect(s.x + 0.3, s.y - 1.1, 0.8, 6.4, sh(STEEL, 0.76))
	var hd: Vector2 = j["head"]
	ArtUnits.head(sp, hd, ArtUnits.SKIN, Color(0.14, 0.10, 0.07), Color(0.14, 0.10, 0.07, 0.95))
	# morrión: casco con cresta y ala curva
	sp.ell(hd.x - 0.2, hd.y - 1.4, 7.4, 2.0, OUT)
	sp.ell(hd.x - 0.2, hd.y - 1.5, 6.8, 1.4, sh(STEEL, 0.9))
	sp.ell(hd.x - 0.3, hd.y - 3.6, 4.2, 3.6, OUT)
	sp.ell(hd.x - 0.3, hd.y - 3.6, 3.6, 3.0, STEEL)
	sp.ell(hd.x - 1.2, hd.y - 4.4, 1.8, 1.3, sh(STEEL, 1.35))
	sp.tri(V(hd.x - 3.6, hd.y - 4.6), V(hd.x + 3.2, hd.y - 4.6), V(hd.x - 0.2, hd.y - 8.8), OUT)
	sp.tri(V(hd.x - 2.8, hd.y - 4.6), V(hd.x + 2.4, hd.y - 4.6), V(hd.x - 0.2, hd.y - 7.8), sh(STEEL, 0.9))
	sp.lay(1)
	sp.line(V(hd.x - 0.2, hd.y - 8.0), V(hd.x - 5.0, hd.y - 11.0), 2.8, ArtUnits.g(0.9))
	sp.lay(2)
	ArtUnits.arm_seg(sp, j, "n", sleeve, ArtUnits.SKIN)
	var gn: Vector2 = j["hand_n"]
	var gf: Vector2 = j["hand_f"]
	match mode:
		0:
			# arcabuz apoyado en el arzón
			_gun(sp, gn + V(-4.0, 3.5), V(0.85, -0.55), false)
			sp.line(gf, mouth - V(7.0, -2.5 - bob), 0.6, Color(0.30, 0.18, 0.08))
		1:
			_gun(sp, V(s.x + 1.5, s.y + 2.6), V(0.93, -0.30), false)
		2:
			_gun(sp, V(s.x + 0.8, s.y + 2.0), V(1.0, -0.20), true)
		3:
			_gun(sp, V(s.x + 2.5, s.y + 2.0), V(1.0, -0.03), false)
	ArtUnits.hand(sp, gn, ArtUnits.SKIN)
	if mode >= 1:
		ArtUnits.hand(sp, gf, ArtUnits.SKIN)
