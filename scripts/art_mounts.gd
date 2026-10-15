class_name ArtMounts
extends RefCounted
## Caballos con jinete (jinete, explorador, caballero) y el ariete.
## Mismo sistema que ArtUnits: tres capas (fondo / equipo / frente), luz arriba a la izquierda.

const OUT := ArtUnits.OUT

static func V(x: float, y: float) -> Vector2:
	return Vector2(x, y)

static func sh(c: Color, f: float) -> Color:
	return Painter.shade(c, f)

const HIP_Y := 49.0          # donde nacen las patas
const HOOF_Y := 66.0

## pierna de caballo: dos tramos con casco
static func _hleg(sp: ArtUnits.Sp, hip: Vector2, au: float, flex: float, w: float, col: Color, hoof_col: Color) -> void:
	var up := 9.4
	var lo := 9.6
	var knee := hip + V(sin(au), cos(au)) * up
	var al := au - flex
	var foot := knee + V(sin(al), cos(al)) * lo
	ArtUnits.limb(sp, hip, knee, w, col)
	ArtUnits.limb(sp, knee, foot - V(0, 1.0), w * 0.74, sh(col, 0.94))
	sp.line(foot + V(-0.3, -1.6), foot + V(0.2, 0.2), w * 0.80 + 1.6, OUT)
	sp.line(foot + V(-0.3, -1.6), foot + V(0.2, 0.2), w * 0.80, hoof_col)

## phase < 0: de pie. Devuelve el desplazamiento vertical del cuerpo.
static func _gait(phase: float) -> Dictionary:
	if phase < 0.0:
		return {"fn": [0.04, 0.10], "ff": [-0.10, 0.08], "hn": [-0.06, 0.12], "hf": [0.10, 0.10], "bob": 0.0, "tail": 0.0}
	var p := phase * TAU
	var out := {}
	var defs := {"fn": [0.0, 0.58], "hf": [0.0, 0.50], "ff": [PI, 0.58], "hn": [PI, 0.50]}
	for k in defs:
		var d: Array = defs[k]
		var ph: float = p + float(d[0])
		var au: float = float(d[1]) * sin(ph)
		var fl: float = 0.18 + 0.95 * maxf(0.0, cos(ph))
		out[k] = [au, fl]
	out["bob"] = -1.3 * absf(sin(p * 2.0))
	out["tail"] = sin(p)
	return out

## Dibuja el caballo en capa 0 (y la gualdrapa del equipo en la capa 1). Devuelve la posición de la boca (para las riendas).
static func horse(sp: ArtUnits.Sp, phase: float, coat: Color, mane: Color, blaze: bool, armor: bool, drape: bool) -> Vector2:
	var gt := _gait(phase)
	var bob: float = gt["bob"]
	var hoof := Color(0.16, 0.12, 0.09)
	sp.lay(0)
	var by := 41.5 + bob
	# patas lejanas
	var hipf := V(47.5, HIP_Y + bob)
	var hiph := V(29.0, HIP_Y + bob)
	_hleg(sp, hipf + V(-1.0, 0), gt["ff"][0], gt["ff"][1], 4.6, sh(coat, 0.72), hoof)
	_hleg(sp, hiph + V(-1.0, 0), gt["hf"][0], gt["hf"][1], 4.8, sh(coat, 0.72), hoof)
	# cola
	var sw: float = gt["tail"]
	var t0 := V(22.0, by - 5.5)
	var t1 := V(15.5 - sw * 1.5, by + 3.0)
	var t2 := V(13.5 - sw * 3.5, by + 12.0)
	var t3 := V(15.0 - sw * 4.5, by + 19.0)
	ArtUnits.limb(sp, t0, t1, 4.6, mane)
	ArtUnits.limb(sp, t1, t2, 4.0, mane)
	ArtUnits.limb(sp, t2, t3, 3.0, mane)
	# tinta del cuerpo (unión de formas)
	sp.ell(37.0, by, 15.6, 10.0, OUT)
	sp.ell(48.5, by - 1.0, 9.0, 10.6, OUT)
	sp.ell(27.5, by - 0.4, 9.0, 10.4, OUT)
	var n0 := V(50.0, by - 4.0)
	var n1 := V(59.5, by - 19.0)
	sp.line(n0, n1, 11.8, OUT)
	var h0 := V(60.5, by - 20.0)
	var h1 := V(69.0, by - 12.5)
	sp.line(h0, h1, 8.0, OUT)
	sp.tri(V(57.5, by - 22.0), V(60.5, by - 22.5), V(58.5, by - 27.0), OUT)
	sp.tri(V(61.0, by - 23.0), V(63.5, by - 22.0), V(62.5, by - 27.0), OUT)
	# relleno
	sp.ell(37.0, by, 14.8, 9.2, coat)
	sp.ell(48.5, by - 1.0, 8.2, 9.8, coat)
	sp.ell(27.5, by - 0.4, 8.2, 9.6, coat)
	sp.line(n0, n1, 10.0, coat)
	sp.line(h0, h1, 6.2, coat)
	sp.tri(V(58.0, by - 22.0), V(60.0, by - 22.0), V(58.8, by - 26.0), coat)
	sp.tri(V(61.5, by - 22.5), V(63.0, by - 22.0), V(62.4, by - 26.0), coat)
	# luces y sombras
	sp.ell(38.0, by + 5.4, 13.0, 4.2, sh(coat, 0.80))
	sp.ell(48.5, by + 4.0, 7.0, 5.0, sh(coat, 0.84))
	sp.ell(36.0, by - 5.4, 11.5, 3.3, sh(coat, 1.15))
	sp.ell(26.0, by - 4.0, 4.6, 4.2, sh(coat, 1.10))
	sp.ell(46.5, by - 5.0, 4.4, 4.2, sh(coat, 1.10))
	sp.line(n0 + V(1.8, 1.8), n1 + V(1.8, 2.2), 3.0, sh(coat, 0.82))
	sp.line(n0 + V(-2.0, -1.0), n1 + V(-2.0, -0.6), 2.2, sh(coat, 1.14))
	sp.line(h0 + V(0.6, 1.4), h1 + V(0.0, 1.4), 2.0, sh(coat, 0.84))
	if blaze:
		sp.line(h0 + V(1.4, -1.2), h1 + V(1.0, -1.0), 1.7, Color(0.96, 0.94, 0.88))
	# crines
	sp.line(n0 + V(-3.4, -2.6), n1 + V(-3.2, -2.2), 3.4, mane)
	for k in 5:
		var q := n0.lerp(n1, float(k) / 4.0)
		sp.line(q + V(-3.0, -1.5), q + V(-5.4, 0.8 + sw * 0.4), 1.5, sh(mane, 0.9))
	sp.line(V(58.0, by - 22.0), V(63.5, by - 18.5), 2.6, mane)
	# cara: ojo, ollar, boca
	sp.disc(h0.x + 2.6, h0.y + 0.2, 1.0, Color(0.06, 0.04, 0.03))
	sp.disc(h0.x + 2.2, h0.y - 0.1, 0.4, Color(1, 1, 1, 0.8))
	sp.disc(h1.x + 1.6, h1.y - 0.4, 0.8, Color(0.10, 0.07, 0.05))
	sp.line(h1 + V(0.6, 2.4), h1 + V(-3.0, 2.0), 0.6, Color(0.14, 0.09, 0.06))
	# brida de cuero
	var lea := Color(0.34, 0.21, 0.10)
	sp.line(h0 + V(-1.8, -1.6), h1 + V(-1.0, 0.8), 1.0, lea)
	sp.line(h0 + V(-0.6, -2.4), h0 + V(1.2, 2.6), 0.9, lea)
	sp.line(h1 + V(-2.0, 0.8), h1 + V(-1.4, 2.8), 0.9, lea)
	# patas cercanas (delante del cuerpo)
	_hleg(sp, hipf, gt["fn"][0], gt["fn"][1], 5.0, coat, hoof)
	_hleg(sp, hiph, gt["hn"][0], gt["hn"][1], 5.2, coat, hoof)
	if armor:
		# testera de acero y placas
		var steel := Color(0.66, 0.68, 0.74)
		sp.line(h0 + V(0.6, -1.0), h1 + V(-0.6, -0.4), 4.0, OUT)
		sp.line(h0 + V(0.6, -1.0), h1 + V(-0.6, -0.4), 2.6, steel)
		sp.line(h0 + V(0.6, -1.6), h1 + V(-0.6, -1.0), 0.8, Color(1, 1, 1, 0.7))
		sp.line(n0 + V(0.5, -1.8), n1 + V(-0.2, 2.0), 5.0, OUT)
		sp.line(n0 + V(0.5, -1.8), n1 + V(-0.2, 2.0), 3.6, steel)
	# gualdrapa del equipo (capa 1) y silla (capa 2)
	if drape:
		sp.lay(1)
		var w := 0.86
		var dl := 11.0 if armor else 5.2
		var x0 := 27.0 if armor else 30.0
		var x1 := 48.0 if armor else 44.5
		var pts: Array = [V(x0 + 1.0, by - 8.4), V(x1 - 1.5, by - 8.4), V(x1, by + dl), V(x0, by + dl)]
		sp.poly(pts, ArtUnits.g(w))
		sp.poly([pts[0], V(x0 + 4.0, by - 8.4), V(x0 + 3.4, by + dl), pts[3]], ArtUnits.g(1.0))
		sp.poly([V(x1 - 5.0, by - 8.4), pts[1], pts[2], V(x1 - 3.6, by + dl)], ArtUnits.g(0.62))
		sp.rect(x0 - 0.4, by + dl - 1.8, x1 - x0 + 0.8, 1.8, ArtUnits.g(0.52))
		sp.lay(2)
		sp.rect(x0 - 0.4, by + dl - 2.4, x1 - x0 + 0.8, 0.9, Color(0.86, 0.74, 0.34))
		sp.line(pts[0], pts[1], 1.2, OUT)
		sp.line(pts[0], pts[3], 1.0, OUT)
		sp.line(pts[1], pts[2], 1.0, OUT)
		sp.line(pts[3], pts[2], 1.0, OUT)
	else:
		sp.lay(1)
		sp.ell(37.0, by - 8.0, 8.6, 2.3, ArtUnits.g(0.84))
		sp.ell(36.0, by - 8.5, 6.0, 1.0, ArtUnits.g(1.0))
	sp.lay(2)
	sp.ell(37.5, by - 8.8, 5.6, 2.4, OUT)
	sp.ell(37.5, by - 8.8, 4.9, 1.8, Color(0.38, 0.23, 0.11))
	return h1 + V(1.0, 1.0)

static func _cavalry_pose(f: int, kind: String) -> Dictionary:
	# devuelve: phase del caballo, brazos del jinete y dirección de la lanza
	var pose := {"phase": -1.0, "an": [0.5, 0.9], "af": [0.55, 0.55], "lance": Vector2(0.28, -1.0), "lean": 0.0}
	if f >= 1 and f <= 4:
		pose["phase"] = float(f - 1) / 4.0
		pose["lance"] = Vector2(1.0, -0.35)
		pose["lean"] = 0.8
	elif f == 5:
		pose["phase"] = 0.10
		pose["an"] = [0.55, 0.55]
		pose["lance"] = Vector2(1.0, -0.55)
		pose["lean"] = -1.4
	elif f == 6:
		pose["phase"] = 0.34
		pose["an"] = [1.38, 0.15]
		pose["af"] = [1.15, 0.30]
		pose["lance"] = Vector2(1.0, 0.02)
		pose["lean"] = 2.6
	return pose

static func _rider_leg(sp: ArtUnits.Sp, hip: Vector2, boots: Color, pants: Color) -> void:
	var knee := hip + V(5.8, 6.0)
	var foot := knee + V(-3.2, 8.2)
	ArtUnits.limb(sp, hip, knee, 4.8, pants)
	ArtUnits.limb(sp, knee, foot - V(0, 1.0), 4.0, sh(pants, 0.97))
	ArtUnits.boot(sp, foot, 0.3, boots)

static func _p_jinete(sp: ArtUnits.Sp, f: int) -> void:
	var cp := _cavalry_pose(f, "jinete")
	sp.at(0.0, 0.0)
	var coat := Color(0.55, 0.36, 0.20)
	var mouth := horse(sp, float(cp["phase"]), coat, Color(0.17, 0.11, 0.07), false, false, true)
	var gt := _gait(float(cp["phase"]))
	var bob: float = gt["bob"]
	sp.at(7.0, -2.5 + bob)
	var pose := {"ln": [0.5, 1.0], "lf": [0.5, 1.0], "an": cp["an"], "af": cp["af"], "bob": 0.0}
	var j := ArtUnits.skel(pose, float(cp["lean"]))
	sp.lay(0)
	ArtUnits.arm_seg(sp, j, "f", Color(0.80, 0.74, 0.58), ArtUnits.SKIN)
	ArtUnits.tunic(sp, j, 2.0, 0.86)
	sp.lay(2)
	_rider_leg(sp, j["hip"], Color(0.24, 0.16, 0.09), Color(0.38, 0.30, 0.20))
	ArtUnits.belt(sp, j)
	var hd: Vector2 = j["head"]
	ArtUnits.head(sp, hd, ArtUnits.SKIN, Color(0.30, 0.20, 0.10), Color(0, 0, 0, 0), true)
	ArtUnits.helm_cap(sp, hd, Color(0.52, 0.36, 0.20))
	sp.lay(1)
	sp.line(V(hd.x - 1.0, hd.y - 4.6), V(hd.x - 5.0, hd.y - 8.4), 2.6, ArtUnits.g(0.9))
	sp.line(V(hd.x - 5.0, hd.y - 8.4), V(hd.x - 8.4, hd.y - 6.0), 2.2, ArtUnits.g(0.75))
	sp.lay(2)
	ArtUnits.arm_seg(sp, j, "n", Color(0.80, 0.74, 0.58), ArtUnits.SKIN)
	ArtUnits.spear(sp, j["hand_n"], cp["lance"], 58.0)
	# riendas
	var hf: Vector2 = j["hand_f"]
	sp.line(hf, mouth - V(7.0, -2.5 - bob), 0.6, Color(0.30, 0.18, 0.08))

static func _p_explorador(sp: ArtUnits.Sp, f: int) -> void:
	var cp := _cavalry_pose(f, "explorador")
	sp.at(0.0, 0.0)
	var coat := Color(0.76, 0.62, 0.40)
	var mouth := horse(sp, float(cp["phase"]) if f <= 4 else (0.1 if f == 5 else 0.34), coat, Color(0.42, 0.30, 0.18), true, false, true)
	var gt := _gait(float(cp["phase"]) if f <= 4 else (0.1 if f == 5 else 0.34))
	var bob: float = gt["bob"]
	sp.at(7.0, -2.5 + bob)
	var running := f >= 1
	var pose := {"ln": [0.5, 1.0], "lf": [0.5, 1.0], "an": [0.55, 0.55], "af": [0.30, 0.55], "bob": 0.0}
	if f == 5 or f == 6:
		pose["af"] = [2.2, 0.3]          # mano a la frente: otea el horizonte
	var j := ArtUnits.skel(pose, 1.0 if running else 0.0)
	var cloak := Color(0.0, 0, 0)
	# capa al viento (equipo) detrás de la espalda
	var s: Vector2 = j["sh"]
	sp.lay(0)
	ArtUnits.arm_seg(sp, j, "f", Color(0.72, 0.64, 0.44), ArtUnits.SKIN)
	sp.lay(1)
	var fl := 0.0 if f == 0 else (3.0 + 2.0 * sin(float(f) * 1.7))
	var cp0: Array = [V(s.x - 3.6, s.y - 1.6), V(s.x + 1.0, s.y - 1.4), V(s.x - 6.0 - fl, s.y + 15.0 + fl * 0.3), V(s.x - 13.0 - fl * 1.8, s.y + 12.0)]
	sp.opoly(cp0, ArtUnits.g(0.84), OUT, 0.0)
	sp.poly([cp0[0], cp0[1], V(s.x - 1.0, s.y + 6.0)], ArtUnits.g(1.0))
	sp.poly([cp0[3], cp0[2], V(s.x - 5.0 - fl * 0.6, s.y + 5.0)], ArtUnits.g(0.62))
	ArtUnits.tunic(sp, j, 2.0, 0.78)
	sp.lay(2)
	_rider_leg(sp, j["hip"], Color(0.24, 0.16, 0.09), Color(0.40, 0.34, 0.22))
	ArtUnits.belt(sp, j)
	var hd: Vector2 = j["head"]
	ArtUnits.head(sp, hd, ArtUnits.SKIN, Color(0.22, 0.14, 0.07))
	# sombrero de ala ancha con pluma
	sp.ell(hd.x + 0.4, hd.y - 2.4, 7.6, 2.0, OUT)
	sp.ell(hd.x + 0.4, hd.y - 2.5, 7.0, 1.5, Color(0.50, 0.40, 0.24))
	sp.ell(hd.x, hd.y - 4.4, 3.8, 3.0, OUT)
	sp.ell(hd.x, hd.y - 4.3, 3.2, 2.5, Color(0.56, 0.45, 0.27))
	sp.rect(hd.x - 3.0, hd.y - 3.4, 6.0, 0.9, Color(0.30, 0.20, 0.10))
	sp.line(V(hd.x - 1.0, hd.y - 5.2), V(hd.x - 5.4, hd.y - 9.6), 2.2, OUT)
	sp.line(V(hd.x - 1.0, hd.y - 5.2), V(hd.x - 5.4, hd.y - 9.6), 1.2, Color(0.86, 0.30, 0.22))
	ArtUnits.arm_seg(sp, j, "n", Color(0.72, 0.64, 0.44), ArtUnits.SKIN)
	var hn: Vector2 = j["hand_n"]
	sp.line(hn, mouth - V(7.0, -2.5 - bob), 0.6, Color(0.30, 0.18, 0.08))
	# talego a la grupa
	sp.ell(26.0, 28.0, 4.2, 3.6, OUT)
	sp.ell(26.0, 28.0, 3.5, 3.0, Color(0.60, 0.46, 0.26))
	sp.rect(24.4, 25.2, 3.2, 1.0, Color(0.34, 0.22, 0.10))

static func _p_caballero(sp: ArtUnits.Sp, f: int) -> void:
	var cp := _cavalry_pose(f, "caballero")
	sp.at(0.0, 4.0)
	var coat := Color(0.30, 0.25, 0.22)
	var mouth := horse(sp, float(cp["phase"]), coat, Color(0.10, 0.08, 0.07), false, true, true)
	var gt := _gait(float(cp["phase"]))
	var bob: float = gt["bob"]
	sp.at(7.0, 1.5 + bob)
	var steel := Color(0.66, 0.68, 0.74)
	var pose := {"ln": [0.5, 1.0], "lf": [0.5, 1.0], "an": [0.55, 0.95], "af": cp["an"], "bob": 0.0}
	if f == 6:
		pose["an"] = [0.45, 0.95]
	var j := ArtUnits.skel(pose, float(cp["lean"]))
	sp.lay(0)
	ArtUnits.arm_seg(sp, j, "f", steel, steel, false)
	ArtUnits.tunic(sp, j, 3.0, 0.84, Color(0.80, 0.68, 0.30))
	sp.lay(2)
	_rider_leg(sp, j["hip"], Color(0.50, 0.52, 0.58), Color(0.56, 0.58, 0.64))
	ArtUnits.belt(sp, j, Color(0.24, 0.15, 0.07))
	# peto de acero sobre la sobrevesta (sólo una franja: la sobrevesta es del equipo)
	var s: Vector2 = j["sh"]
	sp.rect(s.x - 4.2, s.y - 1.4, 9.2, 3.0, OUT)
	sp.rect(s.x - 3.8, s.y - 1.1, 8.4, 2.4, steel)
	sp.rect(s.x - 3.8, s.y - 1.1, 8.4, 0.8, sh(steel, 1.25))
	var hd: Vector2 = j["head"]
	# yelmo de cubo con rendija
	sp.rect(hd.x - 4.6, hd.y - 5.4, 9.4, 11.4, OUT)
	sp.rect(hd.x - 3.9, hd.y - 4.8, 8.0, 10.2, steel)
	sp.rect(hd.x - 3.9, hd.y - 4.8, 2.6, 10.2, sh(steel, 1.18))
	sp.rect(hd.x + 1.8, hd.y - 4.8, 2.3, 10.2, sh(steel, 0.78))
	sp.rect(hd.x - 0.6, hd.y - 1.9, 4.8, 1.2, Color(0.04, 0.03, 0.03))
	sp.rect(hd.x - 4.2, hd.y - 5.0, 8.6, 1.0, sh(steel, 0.80))
	for k in 3:
		sp.rect(hd.x + 1.0 + k * 1.2, hd.y + 1.4, 0.5, 0.5, Color(0.12, 0.10, 0.10))
	# penacho del equipo
	sp.lay(1)
	var fl := 0.0 if f == 0 else 1.5 * sin(float(f) * 1.6)
	sp.line(V(hd.x, hd.y - 5.4), V(hd.x - 3.0, hd.y - 9.6 + fl), 3.4, ArtUnits.g(0.9))
	sp.line(V(hd.x - 3.0, hd.y - 9.6 + fl), V(hd.x - 8.2, hd.y - 7.6 + fl * 1.5), 3.0, ArtUnits.g(0.7))
	sp.lay(2)
	ArtUnits.arm_seg(sp, j, "n", steel, steel, false)
	# lanza (mano lejana) y escudo (mano cercana)
	ArtUnits.spear(sp, j["hand_f"], cp["lance"], 64.0)
	var hn: Vector2 = j["hand_n"]
	var sc := hn + V(2.2, 0.8)
	sp.lay(1)
	var kite: Array = [V(sc.x - 5.4, sc.y - 7.0), V(sc.x + 5.4, sc.y - 7.0), V(sc.x + 4.6, sc.y + 3.0), V(sc.x, sc.y + 11.0), V(sc.x - 4.6, sc.y + 3.0)]
	sp.poly(kite, ArtUnits.g(0.84))
	sp.poly([kite[0], V(sc.x - 1.8, sc.y - 7.0), V(sc.x - 1.4, sc.y + 8.0), kite[4]], ArtUnits.g(1.0))
	sp.poly([V(sc.x + 2.2, sc.y - 7.0), kite[1], kite[2], V(sc.x + 1.4, sc.y + 8.0)], ArtUnits.g(0.62))
	sp.lay(2)
	for i in 5:
		sp.line(kite[i], kite[(i + 1) % 5], 1.4, OUT)
	sp.line(V(sc.x - 4.6, sc.y - 6.4), V(sc.x + 4.6, sc.y - 6.4), 1.1, Color(0.80, 0.68, 0.30))
	sp.line(V(sc.x, sc.y - 6.4), V(sc.x, sc.y + 9.4), 1.1, Color(0.80, 0.68, 0.30))
	var hf: Vector2 = j["hand_f"]
	sp.line(hf, mouth - V(7.0, -2.5 - bob - 3.0), 0.5, Color(0.30, 0.18, 0.08))

# ---------------------------------------------------------------- ariete

static func _wheel(sp: ArtUnits.Sp, c: Vector2, r: float, ang: float, dark: float) -> void:
	sp.disc(c.x, c.y, r + 1.3, OUT)
	sp.disc(c.x, c.y, r, sh(Color(0.46, 0.30, 0.15), dark))
	sp.disc(c.x - 0.5, c.y - 0.6, r * 0.78, sh(Color(0.56, 0.37, 0.19), dark))
	for k in 6:
		var a := ang + float(k) * PI / 3.0
		var d := V(cos(a), sin(a)) * (r - 0.6)
		sp.line(c - d, c + d, 1.5, OUT)
		sp.line(c - d, c + d, 0.8, sh(Color(0.34, 0.21, 0.10), dark))
	sp.arc(c.x, c.y, r - 0.6, 0.0, TAU, 1.1, sh(Color(0.32, 0.33, 0.38), dark))
	sp.disc(c.x, c.y, 1.7, OUT)
	sp.disc(c.x - 0.2, c.y - 0.2, 1.2, sh(Color(0.62, 0.63, 0.70), dark))

static func _p_ariete(sp: ArtUnits.Sp, f: int) -> void:
	sp.at(8.0, 0.0)
	var wood := Color(0.52, 0.34, 0.17)
	var wd := Color(0.40, 0.25, 0.12)
	var iron := Color(0.56, 0.58, 0.64)
	var dx := 0.0
	var bob := 0.0
	var ang := 0.0
	if f >= 1 and f <= 4:
		ang = float(f - 1) * 0.26
		bob = -0.7 * absf(sin(float(f) * 1.57))
	elif f == 5:
		dx = -7.0
	elif f == 6:
		dx = 10.0
	sp.at(8.0, bob)
	var gy := 50.0
	# ruedas lejanas, poste lejano y tronco
	sp.lay(0)
	_wheel(sp, V(32.0, gy - 6.0), 6.0, ang + 0.3, 0.72)
	_wheel(sp, V(66.0, gy - 6.0), 6.0, ang + 0.3, 0.72)
	sp.line(V(30.0, 22.0), V(30.0, gy - 7.0), 4.4, OUT)
	sp.line(V(30.0, 22.0), V(30.0, gy - 7.0), 3.0, sh(wd, 0.85))
	sp.line(V(64.0, 22.0), V(64.0, gy - 7.0), 4.4, OUT)
	sp.line(V(64.0, 22.0), V(64.0, gy - 7.0), 3.0, sh(wd, 0.85))
	# cadenas
	for cx in [38.0, 56.0]:
		sp.line(V(cx, 20.0), V(cx + dx * 0.08, 33.0), 1.6, OUT)
		sp.line(V(cx, 20.0), V(cx + dx * 0.08, 33.0), 0.8, Color(0.60, 0.62, 0.68))
	# tronco con aros y cabeza de hierro
	var l0 := V(7.0 + dx, 34.5)
	var l1 := V(76.0 + dx, 34.5)
	sp.line(l0, l1, 8.8, OUT)
	sp.line(l0, l1, 7.2, wood)
	sp.line(l0 + V(0, 2.2), l1 + V(0, 2.2), 2.6, sh(wood, 0.76))
	sp.line(l0 + V(0, -2.2), l1 + V(0, -2.2), 1.6, sh(wood, 1.25))
	for rx in [14.0, 38.0, 62.0]:
		sp.rect(rx + dx, 30.4, 3.0, 8.2, OUT)
		sp.rect(rx + dx + 0.4, 30.8, 2.2, 7.4, Color(0.34, 0.35, 0.40))
	var tip := V(77.0 + dx, 34.5)
	var head: Array = [tip + V(0, -4.6), tip + V(7.0, -3.2), tip + V(11.0, 0.0), tip + V(7.0, 3.2), tip + V(0, 4.6)]
	sp.opoly(head, iron, OUT, 1.0)
	sp.poly([head[0], head[1], tip + V(1.0, -1.0), tip + V(0.0, -1.2)], sh(iron, 1.30))
	sp.poly([tip + V(1.0, 1.0), head[3], head[4]], sh(iron, 0.72))
	sp.disc(tip.x + 10.0, tip.y, 1.3, Color(0.88, 0.90, 0.95))
	# techo (sin color de equipo), tejas de madera
	var roof: Array = [V(18.0, 24.0), V(28.0, 10.0), V(70.0, 10.0), V(80.0, 24.0)]
	sp.lay(1)
	# faldón del equipo bajo el techo
	var skirt: Array = [V(22.0, 23.0), V(76.0, 23.0), V(76.0, 31.0), V(22.0, 31.0)]
	sp.poly(skirt, ArtUnits.g(0.84))
	sp.poly([V(22.0, 23.0), V(34.0, 23.0), V(34.0, 31.0), V(22.0, 31.0)], ArtUnits.g(1.0))
	sp.poly([V(64.0, 23.0), V(76.0, 23.0), V(76.0, 31.0), V(64.0, 31.0)], ArtUnits.g(0.62))
	for i in 6:
		sp.rect(23.0 + i * 9.0, 23.0, 0.9, 8.0, ArtUnits.g(0.5, 0.8))
	sp.lay(2)
	sp.rect(21.4, 22.6, 55.2, 0.9, OUT)
	sp.rect(21.4, 30.6, 55.2, 0.9, OUT)
	sp.rect(21.4, 22.6, 0.9, 9.0, OUT)
	sp.rect(75.8, 22.6, 0.9, 9.0, OUT)
	sp.lay(2)
	sp.opoly(roof, wood, OUT, 1.1)
	sp.poly([roof[0], roof[1], V(40.0, 10.0), V(32.0, 24.0)], sh(wood, 1.16))
	sp.poly([V(64.0, 10.0), roof[2], roof[3], V(66.0, 24.0)], sh(wood, 0.76))
	for i in range(1, 5):
		var y := 10.0 + float(i) * 2.8
		var inset := (y - 10.0) * 0.72
		sp.line(V(28.0 - inset, y), V(70.0 + inset, y), 0.8, sh(wd, 0.85))
	for i in 8:
		var x := 31.0 + float(i) * 5.4
		sp.line(V(x, 10.6), V(18.0 + (x - 28.0) * 1.476, 23.4), 0.5, Color(0.26, 0.15, 0.06, 0.55))
	sp.rect(18.0, 23.2, 62.0, 1.8, sh(wd, 0.72))
	# poste y ruedas cercanas
	sp.line(V(24.0, 24.0), V(24.0, gy - 7.0), 4.8, OUT)
	sp.line(V(24.0, 24.0), V(24.0, gy - 7.0), 3.4, wd)
	sp.line(V(23.2, 24.0), V(23.2, gy - 7.0), 1.0, sh(wd, 1.3))
	sp.line(V(72.0, 24.0), V(72.0, gy - 7.0), 4.8, OUT)
	sp.line(V(72.0, 24.0), V(72.0, gy - 7.0), 3.4, wd)
	sp.line(V(71.2, 24.0), V(71.2, gy - 7.0), 1.0, sh(wd, 1.3))
	_wheel(sp, V(26.0, gy - 6.5), 6.6, ang, 1.0)
	_wheel(sp, V(70.0, gy - 6.5), 6.6, ang, 1.0)
