class_name ArtMounts
extends RefCounted
## Caballos con jinete (jinete, explorador, caballero) y el ariete.
## Mismo sistema que ArtUnits: tres capas (fondo / equipo / frente), luz arriba a la izquierda.

const OUT := ArtUnits.OUT

static func V(x: float, y: float) -> Vector2:
	return Vector2(x, y)

static func sh(c: Color, f: float) -> Color:
	return ArtUnits.sh(c, f)

const HIP_Y := 49.0          # donde nacen las patas
const HOOF_Y := 66.0

## pierna de caballo: dos tramos con casco
static func _hleg(sp: ArtUnits.Sp, hip: Vector2, au: float, flex: float, w: float, col: Color, hoof_col: Color) -> void:
	var up := 9.4
	var lo := 9.6
	var knee := hip + V(sin(au), cos(au)) * up
	var al := au - flex
	var foot := knee + V(sin(al), cos(al)) * lo
	ArtUnits.limb(sp, hip, knee, w * 1.18, col, 0.62)                          # antebrazo/muslo: ancho arriba, afina a la rodilla
	ArtUnits.limb(sp, knee, foot - V(0, 1.2), w * 0.64, sh(col, 0.94), 0.80)   # caña fina
	sp.disc(knee.x, knee.y, w * 0.36, sh(col, 0.92))                           # rodilla / corvejón
	sp.disc(knee.x - 0.3, knee.y - 0.4, w * 0.16, sh(col, 1.15))
	sp.line(foot + V(-0.3, -1.8), foot + V(0.3, 0.3), w * 0.74 + 1.4, OUT)
	sp.line(foot + V(-0.3, -1.8), foot + V(0.3, 0.3), w * 0.74, hoof_col)
	sp.line(foot + V(-0.9, -1.4), foot + V(-0.6, 0.0), 0.7, sh(hoof_col, 1.5))

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
	ArtUnits._cap(sp, n0, n1, 12.8, 8.6, OUT)
	var h0 := V(60.5, by - 20.0)
	var h1 := V(69.0, by - 12.5)
	ArtUnits._cap(sp, h0, h1, 9.2, 5.4, OUT)
	sp.ell(h0.x + 1.2, h0.y + 2.8, 3.9, 3.3, OUT)
	sp.tri(V(57.5, by - 22.0), V(60.5, by - 22.5), V(58.5, by - 27.0), OUT)
	sp.tri(V(61.0, by - 23.0), V(63.5, by - 22.0), V(62.5, by - 27.0), OUT)
	# relleno
	sp.ell(37.0, by, 14.8, 9.2, coat)
	sp.ell(48.5, by - 1.0, 8.2, 9.8, coat)
	sp.ell(27.5, by - 0.4, 8.2, 9.6, coat)
	ArtUnits._cap(sp, n0, n1, 11.0, 7.0, coat)
	ArtUnits._cap(sp, h0, h1, 7.6, 3.9, coat)
	sp.ell(h0.x + 1.2, h0.y + 2.8, 3.2, 2.6, coat)
	sp.tri(V(58.0, by - 22.0), V(60.0, by - 22.0), V(58.8, by - 26.0), coat)
	sp.tri(V(61.5, by - 22.5), V(63.0, by - 22.0), V(62.4, by - 26.0), coat)
	# luces y sombras
	sp.ell(38.0, by + 5.4, 13.0, 4.2, sh(coat, 0.80))
	sp.ell(48.5, by + 4.0, 7.0, 5.0, sh(coat, 0.84))
	sp.ell(36.0, by - 5.4, 11.5, 3.3, sh(coat, 1.15))
	sp.ell(26.0, by - 4.0, 4.6, 4.2, sh(coat, 1.10))
	sp.ell(46.5, by - 5.0, 4.4, 4.2, sh(coat, 1.10))
	sp.line(n0 + V(1.8, 1.8), n1 + V(1.1, 1.4), 2.8, sh(coat, 0.82))
	sp.line(n0 + V(-2.0, -1.0), n1 + V(-2.0, -0.6), 2.2, sh(coat, 1.14))
	sp.line(h0 + V(0.6, 1.4), h1 + V(0.0, 1.4), 2.0, sh(coat, 0.84))
	sp.ell(37.0, by + 7.2, 9.5, 2.6, sh(coat, 0.68))                          # vientre
	sp.line(V(45.0, by - 5.5), V(49.5, by + 5.5), 1.0, sh(coat, 0.66))         # separación de la espalda
	sp.line(V(32.0, by - 6.5), V(31.0, by + 4.5), 0.9, sh(coat, 0.70))         # grupa
	sp.ell(25.5, by - 1.8, 3.6, 5.0, sh(coat, 1.16))
	sp.ell(47.0, by - 1.0, 3.0, 4.2, sh(coat, 1.10))
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
	# yelmo de cubo con corona redondeada, rendija, banda en cruz y remaches
	var hp: Array = [V(hd.x - 4.0, hd.y + 5.6), V(hd.x + 4.5, hd.y + 5.6), V(hd.x + 4.2, hd.y - 2.2), V(hd.x + 2.4, hd.y - 5.0), V(hd.x - 2.6, hd.y - 5.3), V(hd.x - 4.2, hd.y - 2.2)]
	sp.poly(ArtUnits.grow(hp, 0.95), OUT)
	sp.poly(hp, steel)
	sp.poly([hp[5], V(hd.x - 1.2, hd.y - 5.2), V(hd.x - 1.2, hd.y + 5.6), hp[0]], sh(steel, 1.22))
	sp.poly([V(hd.x + 1.8, hd.y - 4.7), hp[3], hp[2], hp[1], V(hd.x + 1.8, hd.y + 5.6)], sh(steel, 0.74))
	sp.ell(hd.x - 1.4, hd.y - 3.9, 1.8, 1.0, sh(steel, 1.45))
	sp.rect(hd.x - 4.2, hd.y + 4.3, 8.9, 1.3, sh(steel, 0.78))
	sp.rect(hd.x + 0.3, hd.y - 5.0, 1.2, 10.4, sh(steel, 0.90))
	sp.rect(hd.x - 0.9, hd.y - 1.9, 5.2, 1.2, Color(0.04, 0.03, 0.03))
	for k in 3:
		sp.rect(hd.x + 1.6 + k * 1.1, hd.y + 1.4, 0.5, 0.5, Color(0.12, 0.10, 0.10))
	for ry in [-3.4, 2.8]:
		sp.disc(hd.x - 2.6, hd.y + ry, 0.45, sh(steel, 1.5))
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

# ---------------------------------------------------------------- arquero a caballo

static func _p_arquero_caballo(sp: ArtUnits.Sp, f: int) -> void:
	var ph := -1.0
	if f >= 1 and f <= 4:
		ph = float(f - 1) / 4.0
	elif f == 5 or f == 7:
		ph = 0.10
	elif f == 6:
		ph = 0.34
	sp.at(0.0, 0.0)
	var coat := Color(0.66, 0.66, 0.69)
	var mouth := horse(sp, ph, coat, Color(0.24, 0.24, 0.27), true, false, true)
	var bob: float = float(_gait(ph)["bob"])
	sp.at(7.0, -2.5 + bob)
	var pose := {"ln": [0.5, 1.0], "lf": [0.5, 1.0], "an": [0.75, 0.30], "af": [0.35, 0.55], "bob": 0.0}
	var lean := 0.0
	var mode := 0          # 0 en marcha, 1 tensando, 2 suelta, 3 apuntando
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
	var j := ArtUnits.skel(pose, lean)
	var sleeve := Color(0.60, 0.50, 0.32)
	sp.lay(0)
	ArtUnits.quiver(sp, j)
	ArtUnits.arm_seg(sp, j, "f", sleeve, ArtUnits.SKIN)
	ArtUnits.tunic(sp, j, 2.0, 0.84)
	sp.lay(2)
	_rider_leg(sp, j["hip"], Color(0.24, 0.16, 0.09), Color(0.36, 0.30, 0.20))
	ArtUnits.belt(sp, j, Color(0.30, 0.19, 0.09))
	var hd: Vector2 = j["head"]
	ArtUnits.head(sp, hd, ArtUnits.SKIN, Color(0.22, 0.14, 0.07), Color(0, 0, 0, 0), true)
	ArtUnits.hood(sp, hd, Color(0.46, 0.30, 0.16), true)
	var s: Vector2 = j["sh"]
	sp.line(V(s.x - 3.5, s.y - 1.0), V(s.x + 3.5, s.y + 11.0), 1.3, OUT)
	sp.line(V(s.x - 3.5, s.y - 1.0), V(s.x + 3.5, s.y + 11.0), 0.8, Color(0.42, 0.27, 0.12))
	ArtUnits.arm_seg(sp, j, "n", sleeve, ArtUnits.SKIN)
	var gn: Vector2 = j["hand_n"]
	var gf: Vector2 = j["hand_f"]
	match mode:
		0:
			ArtUnits.bow(sp, gn + V(1.0, 0.5), gn + V(1.0, 0.5), false, false)
			sp.line(gf, mouth - V(7.0, -2.5 - bob), 0.6, Color(0.30, 0.18, 0.08))
		1:
			ArtUnits.bow(sp, gn + V(1.0, 0.0), gf, true, true)
		2:
			ArtUnits.bow(sp, gn + V(1.0, 0.0), gn + V(1.0, 0.0), false, false)
		3:
			ArtUnits.bow(sp, gn + V(1.0, 0.0), gf, true, true)
	if mode == 1 or mode == 3:
		ArtUnits.hand(sp, gf, ArtUnits.SKIN)
		ArtUnits.hand(sp, gn, ArtUnits.SKIN)

# ---------------------------------------------------------------- asedio: catapulta y trabuquete

static func _stone(sp: ArtUnits.Sp, c: Vector2, r: float) -> void:
	sp.disc(c.x, c.y, r + 1.1, OUT)
	sp.disc(c.x, c.y, r, Color(0.58, 0.57, 0.55))
	sp.disc(c.x + 0.5, c.y + 0.7, r * 0.72, Color(0.46, 0.45, 0.44))
	sp.disc(c.x - 0.7, c.y - 0.8, r * 0.45, Color(0.78, 0.77, 0.74))

## Tablero de madera con listones (para cajas y paneles de equipo se usa otra capa).
static func _planks(sp: ArtUnits.Sp, x: float, y: float, w: float, h: float, col: Color) -> void:
	sp.rect(x - 0.9, y - 0.9, w + 1.8, h + 1.8, OUT)
	sp.rect(x, y, w, h, col)
	sp.rect(x, y, w, 1.0, sh(col, 1.2))
	sp.rect(x, y + h - 1.2, w, 1.2, sh(col, 0.72))
	var n := int(w / 5.0)
	for i in range(1, n):
		sp.rect(x + float(i) * 5.0, y, 0.6, h, sh(col, 0.68))

static func _p_catapulta(sp: ArtUnits.Sp, f: int) -> void:
	var wood := Color(0.52, 0.34, 0.17)
	var wd := Color(0.40, 0.25, 0.12)
	var iron := Color(0.56, 0.58, 0.64)
	var rope := Color(0.76, 0.66, 0.44)
	var ang := 0.0
	var bob := 0.0
	var phi := -100.0
	var cocked := false
	if f >= 1 and f <= 4:
		ang = float(f - 1) * 0.26
		bob = -0.6 * absf(sin(float(f) * 1.57))
		phi = -100.0 + 4.0 * sin(float(f) * 1.57)
	elif f == 5:
		phi = 150.0
		cocked = true
	elif f == 6:
		phi = -40.0
	sp.at(0.0, bob)
	var gy := 68.0
	var P := V(58.0, 32.0)
	var d := V(cos(deg_to_rad(phi)), sin(deg_to_rad(phi)))
	var tip := P + d * 27.0
	var stub := P - d * 9.0
	# --- capa 0: lado lejano
	sp.lay(0)
	_wheel(sp, V(31.0, gy - 8.0), 6.0, ang + 0.3, 0.72)
	_wheel(sp, V(85.0, gy - 8.0), 6.0, ang + 0.3, 0.72)
	ArtUnits.limb(sp, V(16.0, gy - 15.0), V(100.0, gy - 15.0), 4.2, sh(wd, 0.82))
	ArtUnits.limb(sp, V(45.0, gy - 15.5), P + V(2.0, 1.0), 4.0, sh(wd, 0.78))
	ArtUnits.limb(sp, V(78.0, gy - 15.5), P + V(2.0, 1.0), 4.0, sh(wd, 0.78))
	# --- capa 1: panel y banderín del equipo
	sp.lay(1)
	var pan: Array = [V(24.0, gy - 25.0), V(92.0, gy - 25.0), V(92.0, gy - 15.5), V(24.0, gy - 15.5)]
	sp.poly(pan, ArtUnits.g(0.84))
	sp.poly([pan[0], V(38.0, gy - 25.0), V(38.0, gy - 15.5), pan[3]], ArtUnits.g(1.0))
	sp.poly([V(78.0, gy - 25.0), pan[1], pan[2], V(78.0, gy - 15.5)], ArtUnits.g(0.62))
	for i in 6:
		sp.rect(30.0 + i * 11.0, gy - 25.0, 0.8, 9.5, ArtUnits.g(0.5, 0.8))
	var fw := 1.0 + 1.6 * sin(float(f) * 1.9) if f > 0 else 0.0
	var flag: Array = [V(16.0, 29.0), V(16.0, 40.0), V(3.0 - fw, 38.0), V(5.0 - fw * 0.5, 32.0)]
	sp.poly(flag, ArtUnits.g(0.84))
	sp.poly([flag[0], V(16.0, 33.0), V(8.0, 33.5), flag[3]], ArtUnits.g(1.0))
	sp.poly([flag[3], V(8.0, 33.5), V(16.0, 36.5), flag[1], flag[2]], ArtUnits.g(0.66))
	# --- capa 2: cuerpo
	sp.lay(2)
	sp.rect(23.4, gy - 25.6, 69.2, 0.9, OUT)
	sp.rect(23.4, gy - 15.9, 69.2, 0.9, OUT)
	sp.rect(23.4, gy - 25.6, 0.9, 10.6, OUT)
	sp.rect(91.8, gy - 25.6, 0.9, 10.6, OUT)
	ArtUnits.limb(sp, V(12.0, gy - 14.5), V(102.0, gy - 14.5), 5.2, wood)
	sp.line(V(16.0, gy - 14.0), V(16.0, 28.0), 2.4, OUT)
	sp.line(V(16.0, gy - 14.0), V(16.0, 28.0), 1.4, wd)
	# torno trasero
	var wn := V(24.0, gy - 31.0)
	sp.disc(wn.x, wn.y, 5.0, OUT)
	sp.disc(wn.x, wn.y, 4.0, sh(wood, 0.9))
	sp.disc(wn.x - 0.6, wn.y - 0.6, 2.8, sh(wood, 1.15))
	for k in 4:
		var a := float(k) * PI / 2.0 + 0.5
		sp.line(wn, wn + V(cos(a), sin(a)) * 5.6, 1.1, wd)
	sp.disc(wn.x, wn.y, 1.2, OUT)
	if cocked:
		sp.line(tip, wn + V(2.0, -2.0), 1.1, OUT)
		sp.line(tip, wn + V(2.0, -2.0), 0.6, rope)
	# resorte de torsión (tambor de cuerda) y brazo
	sp.ell(P.x, P.y + 2.0, 7.6, 6.6, OUT)
	sp.ell(P.x, P.y + 2.0, 6.8, 5.8, Color(0.66, 0.54, 0.34))
	for k in 5:
		sp.line(P + V(-5.6 + float(k) * 2.8, -2.6), P + V(-5.6 + float(k) * 2.8, 7.0), 0.8, Color(0.40, 0.30, 0.16, 0.85))
	sp.ell(P.x - 1.6, P.y - 0.8, 3.6, 2.0, Color(0.82, 0.72, 0.52, 0.8))
	ArtUnits.limb(sp, stub, P, 5.2, wood)
	ArtUnits.limb(sp, P, tip, 4.2, wood)
	sp.line(stub - d * 1.0, stub + d * 1.0, 6.4, OUT)
	sp.line(stub - d * 0.6, stub + d * 0.6, 5.0, iron)
	# cuchara
	sp.ell(tip.x + d.x * 2.0, tip.y + d.y * 2.0 + 0.6, 5.0, 3.8, OUT)
	sp.ell(tip.x + d.x * 2.0, tip.y + d.y * 2.0 + 0.6, 4.2, 3.0, sh(wood, 0.82))
	sp.ell(tip.x + d.x * 2.0 - 0.4, tip.y + d.y * 2.0 + 0.2, 3.0, 1.8, sh(wd, 0.62))
	if cocked:
		_stone(sp, tip + d * 2.0 + V(0.0, -2.0), 3.6)
	# bastidor cercano delante del brazo
	ArtUnits.limb(sp, V(41.0, gy - 15.0), P + V(-1.0, 1.0), 4.8, wood)
	ArtUnits.limb(sp, V(75.0, gy - 15.0), P + V(1.0, 1.0), 4.8, wood)
	ArtUnits.limb(sp, V(47.0, gy - 26.0), V(69.0, gy - 26.0), 3.0, wd)
	sp.disc(P.x, P.y, 3.2, OUT)
	sp.disc(P.x, P.y, 2.4, iron)
	sp.disc(P.x - 0.6, P.y - 0.6, 1.0, Color(0.9, 0.92, 0.96))
	_wheel(sp, V(33.0, gy - 7.5), 6.6, ang, 1.0)
	_wheel(sp, V(83.0, gy - 7.5), 6.6, ang, 1.0)

static func _p_trabuquete(sp: ArtUnits.Sp, f: int) -> void:
	var wood := Color(0.52, 0.34, 0.17)
	var wd := Color(0.40, 0.25, 0.12)
	var iron := Color(0.56, 0.58, 0.64)
	var rope := Color(0.76, 0.66, 0.44)
	var ang := 0.0
	var bob := 0.0
	var phi := -78.0
	var mode := 0          # 0 reposo, 1 armado, 2 disparo
	if f >= 1 and f <= 4:
		ang = float(f - 1) * 0.26
		bob = -0.5 * absf(sin(float(f) * 1.57))
		phi = -78.0 + 2.5 * sin(float(f) * 1.57)
	elif f == 5:
		phi = 148.0
		mode = 1
	elif f == 6:
		phi = -32.0
		mode = 2
	sp.at(0.0, bob)
	var gy := 96.0
	var P := V(62.0, 48.0)
	var d := V(cos(deg_to_rad(phi)), sin(deg_to_rad(phi)))
	var tip := P + d * 42.0
	var stub := P - d * 13.0
	# --- capa 0: lado lejano
	sp.lay(0)
	_wheel(sp, V(30.0, gy - 6.0), 5.2, ang + 0.3, 0.72)
	_wheel(sp, V(96.0, gy - 6.0), 5.2, ang + 0.3, 0.72)
	ArtUnits.limb(sp, V(16.0, gy - 10.0), V(112.0, gy - 10.0), 5.0, sh(wd, 0.82))
	ArtUnits.limb(sp, V(41.0, gy - 10.5), P + V(3.0, 1.0), 4.6, sh(wd, 0.78))
	ArtUnits.limb(sp, V(91.0, gy - 10.5), P + V(3.0, 1.0), 4.6, sh(wd, 0.78))
	# --- capa 1: faldón y banderín del equipo
	sp.lay(1)
	var pan: Array = [V(24.0, gy - 21.0), V(104.0, gy - 21.0), V(104.0, gy - 11.5), V(24.0, gy - 11.5)]
	sp.poly(pan, ArtUnits.g(0.84))
	sp.poly([pan[0], V(40.0, gy - 21.0), V(40.0, gy - 11.5), pan[3]], ArtUnits.g(1.0))
	sp.poly([V(88.0, gy - 21.0), pan[1], pan[2], V(88.0, gy - 11.5)], ArtUnits.g(0.62))
	for i in 7:
		sp.rect(31.0 + i * 11.0, gy - 21.0, 0.8, 9.5, ArtUnits.g(0.5, 0.8))
	var fw := 1.0 + 1.6 * sin(float(f) * 1.9) if f > 0 else 0.0
	var flag: Array = [V(15.0, 52.0), V(15.0, 64.0), V(2.0 - fw, 62.0), V(4.0 - fw * 0.5, 55.0)]
	sp.poly(flag, ArtUnits.g(0.84))
	sp.poly([flag[0], V(15.0, 56.5), V(7.0, 57.0), flag[3]], ArtUnits.g(1.0))
	sp.poly([flag[3], V(7.0, 57.0), V(15.0, 60.0), flag[1], flag[2]], ArtUnits.g(0.66))
	# --- capa 2: cuerpo
	sp.lay(2)
	sp.rect(23.4, gy - 21.6, 81.2, 0.9, OUT)
	sp.rect(23.4, gy - 11.9, 81.2, 0.9, OUT)
	sp.rect(23.4, gy - 21.6, 0.9, 10.6, OUT)
	sp.rect(103.8, gy - 21.6, 0.9, 10.6, OUT)
	ArtUnits.limb(sp, V(12.0, gy - 9.0), V(114.0, gy - 9.0), 6.0, wood)
	sp.line(V(15.0, gy - 9.0), V(15.0, 50.0), 2.6, OUT)
	sp.line(V(15.0, gy - 9.0), V(15.0, 50.0), 1.5, wd)
	# contrapeso colgado del brazo corto (entre los dos bastidores)
	var bc := stub + V(0.0, 10.0)
	_planks(sp, bc.x - 7.5, bc.y - 7.0, 15.0, 15.0, sh(wood, 0.88))
	sp.rect(bc.x - 6.0, bc.y - 5.5, 12.0, 4.4, OUT)
	for k in 3:
		sp.disc(bc.x - 4.0 + float(k) * 4.0, bc.y - 3.4, 1.8, Color(0.56, 0.55, 0.53))
		sp.disc(bc.x - 4.3 + float(k) * 4.0, bc.y - 3.8, 0.7, Color(0.78, 0.77, 0.74))
	sp.rect(bc.x - 7.5, bc.y - 1.0, 15.0, 1.6, iron)
	sp.rect(bc.x - 7.5, bc.y + 4.0, 15.0, 1.6, iron)
	sp.line(stub, bc + V(-5.0, -7.0), 0.9, OUT)
	sp.line(stub, bc + V(5.0, -7.0), 0.9, OUT)
	# brazo
	ArtUnits.limb(sp, stub, P, 6.0, wood)
	ArtUnits.limb(sp, P, tip, 4.6, wood)
	sp.line(stub - d * 1.0, stub + d * 1.0, 7.0, OUT)
	sp.line(stub - d * 0.6, stub + d * 0.6, 5.6, iron)
	for k in 3:
		var q := P.lerp(tip, 0.3 + float(k) * 0.22)
		sp.line(q - V(-d.y, d.x) * 2.6, q + V(-d.y, d.x) * 2.6, 1.1, Color(0.30, 0.31, 0.36))
	# honda
	var pouch := tip + V(3.0, 15.0)
	if mode == 1:
		pouch = tip + V(14.0, 14.0)
	elif mode == 2:
		pouch = tip + V(15.0, -4.0)
	sp.line(tip, pouch, 1.4, OUT)
	sp.line(tip, pouch, 0.7, rope)
	sp.ell(pouch.x, pouch.y, 3.4, 2.4, OUT)
	sp.ell(pouch.x, pouch.y, 2.7, 1.8, Color(0.46, 0.32, 0.18))
	if mode == 1:
		_stone(sp, pouch + V(0.0, -2.2), 3.4)
	# caballete cercano delante del brazo
	ArtUnits.limb(sp, V(36.0, gy - 9.5), P + V(-1.0, 1.0), 5.6, wood)
	ArtUnits.limb(sp, V(88.0, gy - 9.5), P + V(1.0, 1.0), 5.6, wood)
	ArtUnits.limb(sp, V(41.0, gy - 17.0), V(83.0, gy - 17.0), 3.6, wd)
	ArtUnits.limb(sp, V(44.0, gy - 17.0), V(55.0, gy - 31.0), 2.6, wd)
	ArtUnits.limb(sp, V(80.0, gy - 17.0), V(69.0, gy - 31.0), 2.6, wd)
	sp.rect(P.x - 5.0, P.y - 4.2, 10.0, 3.2, OUT)
	sp.rect(P.x - 4.4, P.y - 3.7, 8.8, 2.3, iron)
	sp.disc(P.x, P.y, 3.6, OUT)
	sp.disc(P.x, P.y, 2.8, iron)
	sp.disc(P.x - 0.7, P.y - 0.7, 1.1, Color(0.9, 0.92, 0.96))
	_wheel(sp, V(28.0, gy - 5.5), 5.8, ang, 1.0)
	_wheel(sp, V(98.0, gy - 5.5), 5.8, ang, 1.0)
