class_name IsoPeople
extends RefCounted
## Personas articuladas (infantería, aldeano, monje) y jinetes (la montura vive en IsoRiders): un único esqueleto paramétrico
## (piernas con rodilla, torso con inclinación, brazos con codo) y un catálogo de armas/cabezas/prendas por tipo de unidad.
## El modelo mira a +z; el horneado lo gira (yaw = 90° − d·45°, ver IsoCatalog). Las poses se piden por nombre de fotograma:
## "idle", "w0".."w3" (marcha), "a0".."a2" (ataque: preparar, golpe/suelta, apuntar), "t00".."t31" (oficios del aldeano).
## Ángulos de brazo: pitch (+ = hacia delante/arriba desde colgando), codo (+ = antebrazo hacia delante), roll (+ = hacia fuera).
## Orientación de arma: [elev, yaw, roll]; elev 0 = apunta hacia arriba, 90 = hacia delante, 180 = hacia abajo.

const M = preload("res://tools/iso/iso_models.gd")
const BODY_S := 1.08
const HIP_Y := 0.46
const HEAD_Y := 0.935   # centro de la cabeza (marco de la cadera sumando dy); el cuello deja un hueco visible bajo el pecho

# ------------------------------------------------------------------ paleta

static func pal(team: Color) -> Dictionary:
	return {
		"skin": M.fmat(Color(0.80, 0.60, 0.45), 0.8, 0.3),
		"skin_d": M.fmat(Color(0.60, 0.42, 0.29), 0.8, 0.3),
		"skin_l": M.fmat(Color(0.86, 0.68, 0.55), 0.8, 0.3),
		"eye": M.fmat(Color(0.07, 0.05, 0.05), 0.6, 0.2),
		"hair": M.fmat(Color(0.30, 0.18, 0.10), 0.9, 0.1),
		"hair_r": M.fmat(Color(0.62, 0.26, 0.10), 0.9, 0.1),
		"hair_k": M.fmat(Color(0.12, 0.09, 0.08), 0.9, 0.1),
		"hair_b": M.fmat(Color(0.74, 0.56, 0.27), 0.9, 0.1),
		"hair_g": M.fmat(Color(0.56, 0.53, 0.49), 0.9, 0.1),
		"linen": M.fmat(Color(0.72, 0.66, 0.52), 0.95, 0.1),
		"ochre": M.fmat(Color(0.64, 0.48, 0.25), 0.95, 0.15),
		"ochre_d": M.fmat(Color(0.52, 0.37, 0.18), 0.95, 0.15),
		"olive": M.fmat(Color(0.40, 0.45, 0.25), 0.95, 0.15),
		"olive_d": M.fmat(Color(0.28, 0.32, 0.18), 0.95, 0.15),
		"russet": M.fmat(Color(0.62, 0.30, 0.18), 0.95, 0.15),
		"russet_d": M.fmat(Color(0.46, 0.21, 0.13), 0.95, 0.15),
		"dye_blue": M.fmat(Color(0.26, 0.38, 0.55), 0.95, 0.15),
		"leather": M.fmat(Color(0.26, 0.17, 0.10), 0.8, 0.3),
		"leather_l": M.fmat(Color(0.48, 0.33, 0.18), 0.8, 0.3),
		"steel": M.fmat(Color(0.52, 0.54, 0.60), 0.4, 0.65),
		"steel_d": M.fmat(Color(0.36, 0.38, 0.44), 0.5, 0.55),
		"mail": M.fmat(Color(0.42, 0.44, 0.50), 0.6, 0.45),
		"wood": M.fmat(Color(0.46, 0.31, 0.17), 0.9, 0.15),
		"wood_d": M.fmat(Color(0.30, 0.20, 0.10), 0.9, 0.15),
		"cloth_w": M.fmat(Color(0.90, 0.86, 0.76), 0.95, 0.1),
		"cloth_t": M.fmat(Color(0.70, 0.56, 0.37), 0.95, 0.15),
		"cloth_d": M.fmat(Color(0.50, 0.38, 0.24), 0.95, 0.15),
		"brown": M.fmat(Color(0.36, 0.26, 0.17), 0.95, 0.15),
		"green": M.fmat(Color(0.26, 0.40, 0.20), 0.95, 0.15),
		"green_d": M.fmat(Color(0.18, 0.28, 0.14), 0.95, 0.15),
		"red": M.fmat(Color(0.74, 0.15, 0.12), 0.85, 0.2),
		"blue": M.fmat(Color(0.18, 0.30, 0.58), 0.85, 0.2),
		"black": M.fmat(Color(0.10, 0.09, 0.11), 0.9, 0.15),
		"fur": M.fmat(Color(0.58, 0.44, 0.30), 1.0, 0.05),
		"fur_d": M.fmat(Color(0.34, 0.24, 0.16), 1.0, 0.05),
		"straw": M.fmat(Color(0.74, 0.62, 0.32), 0.95, 0.1),
		"white": M.fmat(Color(0.94, 0.92, 0.86), 0.9, 0.15),
		"gold": M.fmat(Color(0.88, 0.70, 0.22), 0.35, 0.9),
		"bone": M.fmat(Color(0.86, 0.82, 0.70), 0.8, 0.2),
		"team": M.fmat(team, 0.88, 0.2),
		"team_d": M.fmat(team.darkened(0.30), 0.9, 0.2),
	}

# ------------------------------------------------------------------ especificaciones por unidad

static func spec_of(kind: String) -> Dictionary:
	match kind:
		# Tres aspectos de aldeano (el juego elige uno por unidad: IsoView.VILL_LOOKS): hombre con sombrero de paja, hombre con barba
		# y la cabeza descubierta, y mujer con pañuelo y delantal. El equipo se ve en el cinto, el pañuelo del cuello y la cinta de la cabeza.
		"aldeano":
			return {"arch": "villager", "outfit": "tunic", "top": "ochre", "skirt": "ochre_d", "legs": "brown", "head": "straw", "hair": "hair", "belt": "team", "scarf": "team", "fore": "skin", "hem": "brown"}
		"aldeano_b":
			return {"arch": "villager", "outfit": "tunic", "top": "olive", "skirt": "olive_d", "legs": "cloth_d", "head": "bare_short", "hair": "hair_k", "beard": true, "skin": "skin_d", "belt": "team", "scarf": "team", "fore": "skin", "hem": "brown"}
		"aldeano_c":
			return {"arch": "villager", "outfit": "dress", "top": "russet", "skirt": "russet_d", "legs": "brown", "head": "kerchief", "hair": "hair_b", "skin": "skin_l", "fem": true, "belt": "team", "collar": "linen", "fore": "skin", "boots": false}
		"piquero":
			return {"arch": "polearm", "outfit": "tunic", "top": "team", "skirt": "team_d", "legs": "brown", "armor": "gambeson", "head": "kettle", "weapon": "pike", "off": "buckler", "belt": "leather"}
		"espadachin":
			return {"arch": "sword", "outfit": "tunic", "top": "team", "skirt": "team_d", "legs": "black", "armor": "mail", "head": "nasal", "weapon": "sword", "off": "shield", "belt": "leather"}
		"alabardero":
			return {"arch": "polearm", "outfit": "tunic", "top": "team_d", "skirt": "team", "legs": "black", "armor": "mail", "head": "sallet", "weapon": "halberd", "belt": "leather"}
		"teutonico":
			return {"arch": "gsword", "outfit": "tunic", "top": "white", "skirt": "white", "legs": "steel_d", "armor": "plate", "head": "greathelm", "weapon": "greatsword", "belt": "leather", "surcoat": true}
		"berserker":
			return {"arch": "dual", "outfit": "bare", "top": "skin", "skirt": "fur", "legs": "leather_l", "head": "horned", "weapon": "axe", "off": "axe", "belt": "leather", "skin": "skin"}
		"arquero":
			return {"arch": "bow", "outfit": "tunic", "top": "green", "skirt": "green_d", "legs": "brown", "head": "hood", "weapon": "bow", "belt": "leather", "quiver": true}
		"arquero_largo":
			return {"arch": "bow", "outfit": "tunic", "top": "team", "skirt": "green_d", "legs": "green_d", "head": "cap_feather", "weapon": "longbow", "belt": "leather", "quiver": true}
		"ballestero":
			return {"arch": "xbow", "outfit": "tunic", "top": "team", "skirt": "brown", "legs": "black", "armor": "gambeson", "head": "kettle", "weapon": "crossbow", "belt": "leather", "pack": true}
		"hostigador":
			return {"arch": "javelin", "outfit": "tunic", "top": "brown", "skirt": "cloth_d", "legs": "cloth_d", "head": "cap", "weapon": "javelin", "belt": "team", "scarf": "team", "quiver": true}
		"hachero":
			return {"arch": "javelin", "outfit": "tunic", "top": "team", "skirt": "brown", "legs": "black", "armor": "gambeson", "head": "helm_open", "weapon": "throwaxe", "belt": "leather", "off": "buckler"}
		"monje":
			return {"arch": "monk", "outfit": "robe", "top": "team", "skirt": "team_d", "legs": "brown", "head": "tonsure", "weapon": "staff", "belt": "gold", "scarf": "white"}
	return {"arch": "sword", "outfit": "tunic", "top": "team", "skirt": "team_d", "legs": "black", "head": "bare", "weapon": "", "belt": "leather"}

## Fotogramas que hornea cada tipo (nombres tal como los pide IsoView._frame_name)
static func frames_of(kind: String) -> Array:
	var f := ["idle", "w0", "w1", "w2", "w3"]
	var arch: String = spec_of(kind).arch
	match arch:
		"villager":
			for t in 4:
				for k in 2:
					f.append("t%d%d" % [t, k])
		"monk":
			pass
		"bow", "xbow", "javelin":
			f.append_array(["a0", "a1", "a2"])
		_:
			f.append_array(["a0", "a1"])
	return f

# ------------------------------------------------------------------ poses

static func _walk_phase(key: String) -> float:
	return float(key.substr(1)) * 0.25 if key.begins_with("w") else -1.0

## Pose en reposo/marcha/acción de una infantería (diccionario con ra, la, rw, lw, lean, twist, drop, draw, rshow)
static func pose_of(sp: Dictionary, key: String) -> Dictionary:
	var ph := _walk_phase(key)
	var sw := 0.0 if ph < 0.0 else sin(ph * TAU)
	var p := {"w": ph, "ra": [8.0, 12.0, 4.0], "la": [8.0, 12.0, -4.0], "rw": [0.0, 0.0, 0.0], "lw": [0.0, 0.0, 0.0],
		"lean": 0.0, "twist": 0.0, "drop": 0.0, "draw": 0.0, "rshow": true, "lshow": true, "loaded": true}
	var act := key.begins_with("a") or key.begins_with("t")
	match String(sp.arch):
		"villager":
			# brazos sueltos: el que se adelanta dobla más el codo; en reposo uno cuelga y el otro descansa hacia la cadera
			p.ra = [6.0 - sw * 24.0, 12.0 + maxf(0.0, -sw) * 14.0, 7.0]
			p.la = [6.0 + sw * 24.0, 12.0 + maxf(0.0, sw) * 14.0, 7.0]
			if key == "idle":
				p.ra = [14.0, 30.0, 8.0]
				p.la = [2.0, 12.0, 7.0]
			p.rshow = false
			if key.begins_with("t"):
				var trade := int(key.substr(1, 1))
				var ph2 := int(key.substr(2, 1))
				p.rshow = true
				var tool: Array = ["axe", "pickaxe", "hoe", "hammer"]
				sp.weapon = tool[trade]
				if ph2 == 0:
					p.ra = [150.0, 55.0, 4.0]
					p.la = [140.0, 60.0, -4.0]
					p.rw = [-10.0, 0.0, 0.0]
					p.lean = -6.0
				else:
					p.ra = [72.0, 22.0, 4.0]
					p.la = [76.0, 26.0, -4.0]
					p.rw = [120.0, 0.0, 0.0]
					p.lean = 16.0
					p.drop = -0.02
		"monk":
			p.ra = [28.0, 60.0, 6.0]
			p.rw = [2.0, 0.0, 0.0]
			p.la = [10.0 + sw * 24.0, 20.0, -6.0]
			if ph >= 0.0:
				p.lean = 2.0
		"sword":
			p.ra = [48.0 - sw * 6.0, 70.0, 8.0]
			p.rw = [40.0, 0.0, 0.0]
			p.la = [38.0 + sw * 6.0, 66.0, -8.0]
			if ph >= 0.0:
				p.lean = 3.0
			if key == "a0":
				p.ra = [150.0, 62.0, 6.0]
				p.rw = [-15.0, 0.0, 0.0]
				p.la = [52.0, 72.0, -8.0]
				p.lean = -5.0
				p.twist = 12.0
			elif key == "a1":
				p.ra = [88.0, 14.0, 4.0]
				p.rw = [128.0, 0.0, 0.0]
				p.la = [58.0, 70.0, -8.0]
				p.lean = 14.0
				p.twist = -10.0
		"gsword":
			p.ra = [52.0, 62.0, 4.0]
			p.rw = [24.0, 0.0, 0.0]
			p.la = [48.0, 66.0, -4.0]
			if ph >= 0.0:
				p.lean = 3.0
			if key == "a0":
				p.ra = [158.0, 52.0, 4.0]
				p.la = [152.0, 58.0, -4.0]
				p.rw = [-22.0, 0.0, 0.0]
				p.lean = -6.0
			elif key == "a1":
				p.ra = [86.0, 18.0, 4.0]
				p.la = [82.0, 24.0, -4.0]
				p.rw = [122.0, 0.0, 0.0]
				p.lean = 16.0
		"dual":
			p.ra = [34.0 - sw * 8.0, 64.0, 10.0]
			p.la = [34.0 + sw * 8.0, 64.0, -10.0]
			p.rw = [28.0, 0.0, 0.0]
			p.lw = [28.0, 0.0, 0.0]
			if ph >= 0.0:
				p.lean = 5.0
			if key == "a0":
				p.ra = [150.0, 70.0, 12.0]
				p.la = [150.0, 70.0, -12.0]
				p.rw = [-10.0, 0.0, 0.0]
				p.lw = [-10.0, 0.0, 0.0]
				p.lean = -8.0
			elif key == "a1":
				p.ra = [84.0, 20.0, 8.0]
				p.la = [84.0, 20.0, -8.0]
				p.rw = [125.0, 0.0, 0.0]
				p.lw = [125.0, 0.0, 0.0]
				p.lean = 16.0
		"polearm":
			p.ra = [16.0 - sw * 5.0, 40.0, 6.0]
			p.rw = [3.0, 0.0, 0.0]
			p.la = [36.0 + sw * 5.0, 60.0, -6.0]
			if ph >= 0.0:
				p.lean = 2.0
			if key == "a0":
				p.ra = [28.0, 36.0, 6.0]
				p.la = [46.0, 50.0, -6.0]
				p.rw = [86.0, 0.0, 0.0]
				p.lean = -4.0
			elif key == "a1":
				p.ra = [78.0, 8.0, 6.0]
				p.la = [90.0, 4.0, -6.0]
				p.rw = [88.0, 0.0, 0.0]
				p.lean = 12.0
		"bow":
			p.la = [30.0 + sw * 4.0, 24.0, -6.0]
			p.ra = [10.0 - sw * 24.0, 20.0, 4.0]
			p.lw = [0.0, 0.0, 0.0]
			if key == "a0":
				p.la = [84.0, 6.0, -4.0]
				p.ra = [46.0, 100.0, 4.0]
				p.draw = 0.25
			elif key == "a2":
				p.la = [88.0, 3.0, -4.0]
				p.ra = [78.0, 128.0, 62.0]
				p.draw = 1.0
			elif key == "a1":
				p.la = [88.0, 3.0, -4.0]
				p.ra = [70.0, 96.0, 70.0]
				p.draw = 0.0
		"xbow":
			p.ra = [38.0, 72.0, 6.0]
			p.la = [48.0, 58.0, -6.0]
			p.rw = [86.0, 0.0, 0.0]
			if ph >= 0.0:
				p.lean = 2.0
			if key == "a0":
				p.rw = [40.0, 0.0, 0.0]
				p.lean = 10.0
				p.loaded = false
			elif key == "a2":
				p.ra = [84.0, 52.0, 6.0]
				p.la = [88.0, 22.0, -6.0]
				p.rw = [92.0, 0.0, 0.0]
				p.lean = -2.0
			elif key == "a1":
				p.ra = [84.0, 52.0, 6.0]
				p.la = [88.0, 22.0, -6.0]
				p.rw = [98.0, 0.0, 0.0]
				p.lean = -5.0
				p.loaded = false
		"javelin":
			p.ra = [34.0 - sw * 6.0, 60.0, 6.0]
			p.rw = [8.0, 0.0, 0.0]
			p.la = [10.0 + sw * 24.0, 16.0, -6.0]
			if key == "a0":
				p.ra = [-45.0, 85.0, 6.0]
				p.rw = [72.0, 0.0, 0.0]
				p.la = [60.0, 20.0, -8.0]
				p.lean = -8.0
			elif key == "a2":
				p.ra = [128.0, 62.0, 6.0]
				p.rw = [88.0, 0.0, 0.0]
				p.la = [70.0, 20.0, -8.0]
				p.lean = -3.0
			elif key == "a1":
				p.ra = [70.0, 12.0, 6.0]
				p.la = [20.0, 20.0, -8.0]
				p.rshow = false
				p.lean = 14.0
	# postura natural: en reposo el peso va a una pierna, la cabeza se ladea un poco y el torso gira; andando, el torso contrarresta
	# el paso; en acciones, zancada abierta (así los pies quedan separados y firmes)
	if ph < 0.0:
		if key == "idle":
			p.stance = [-4.0, 6.0]
			p.head = [2.0, 9.0, -3.0]
			p.twist = float(p.twist) + 3.0
			p.roll = -1.5
		elif act:
			p.stance = [-9.0, 11.0]
			p.head = [4.0, 0.0, 0.0]
	else:
		p.twist = float(p.twist) - sw * 4.0
	if act and p.w >= 0.0:
		p.w = -1.0
	return p

# ------------------------------------------------------------------ geometría auxiliar

## Segmento (cilindro fino) entre dos puntos.
static func seg(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material, sides: int = 6) -> MeshInstance3D:
	var d := b - a
	var ln := d.length()
	var mi := M.cyl(parent, r, r, maxf(ln, 0.001), (a + b) * 0.5, m, sides)
	if ln > 0.0001:
		mi.basis = Basis(Quaternion(Vector3.UP, d / ln))
	return mi

static func _dbasis(w: Array) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(float(w[1]))) * Basis(Vector3.RIGHT, deg_to_rad(float(w[0]))) * Basis(Vector3.BACK, deg_to_rad(float(w[2])))

## Cinemática de un brazo en el marco del torso: devuelve {upper, fore (bases), elbow, hand (posiciones)}.
static func arm_k(side: float, a: Array, shoulder: Vector3) -> Dictionary:
	var up := Basis(Vector3.RIGHT, -deg_to_rad(float(a[0]))) * Basis(Vector3.BACK, deg_to_rad(float(a[2])) * side)
	var fo := up * Basis(Vector3.RIGHT, -deg_to_rad(float(a[1])))
	var elbow := shoulder + up * Vector3(0, -0.16, 0)
	var hand := elbow + fo * Vector3(0, -0.16, 0)
	return {"upper": up, "fore": fo, "elbow": elbow, "hand": hand}

# ------------------------------------------------------------------ armas (eje +y, empuñadura en el origen)

static func weapon(g: Node3D, kind: String, P: Dictionary, o: Dictionary = {}) -> void:
	match kind:
		"sword":
			M.box(g, Vector3(0.03, 0.11, 0.03), Vector3(0, 0.0, 0), P.leather)
			M.box(g, Vector3(0.15, 0.025, 0.035), Vector3(0, 0.065, 0), P.steel_d)
			M.box(g, Vector3(0.042, 0.46, 0.012), Vector3(0, 0.32, 0), P.steel)
			M.cyl(g, 0.0, 0.021, 0.05, Vector3(0, 0.575, 0), P.steel, 4)
			M.ball(g, 0.022, Vector3(0, -0.06, 0), P.steel_d)
		"greatsword":
			M.box(g, Vector3(0.03, 0.24, 0.03), Vector3(0, 0.02, 0), P.leather)
			M.box(g, Vector3(0.22, 0.03, 0.04), Vector3(0, 0.15, 0), P.steel_d)
			M.box(g, Vector3(0.055, 0.78, 0.014), Vector3(0, 0.56, 0), P.steel)
			M.cyl(g, 0.0, 0.027, 0.07, Vector3(0, 0.975, 0), P.steel, 4)
			M.ball(g, 0.03, Vector3(0, -0.11, 0), P.steel_d)
		"scimitar":
			M.box(g, Vector3(0.03, 0.11, 0.03), Vector3(0, 0.0, 0), P.leather)
			M.box(g, Vector3(0.13, 0.024, 0.032), Vector3(0, 0.065, 0), P.gold)
			for k in 4:
				var bl := M.box(g, Vector3(0.05, 0.16, 0.012), Vector3(0.0, 0.17 + k * 0.15, 0.015 * k * k * 0.3), P.steel)
				bl.rotation_degrees.x = 7.0 * float(k)
		"axe":
			M.cyl(g, 0.017, 0.02, 0.46, Vector3(0, 0.14, 0), P.wood, 6)
			M.box(g, Vector3(0.03, 0.12, 0.15), Vector3(0, 0.34, 0.06), P.steel)
			M.box(g, Vector3(0.03, 0.06, 0.04), Vector3(0, 0.34, -0.03), P.steel_d)
		"throwaxe":
			M.cyl(g, 0.015, 0.018, 0.32, Vector3(0, 0.08, 0), P.wood, 6)
			M.box(g, Vector3(0.025, 0.10, 0.12), Vector3(0, 0.25, 0.05), P.steel)
		"pike":
			M.cyl(g, 0.014, 0.014, 1.70, Vector3(0, 0.50, 0), P.wood, 6)
			M.cyl(g, 0.0, 0.032, 0.17, Vector3(0, 1.43, 0), P.steel, 5)
			M.box(g, Vector3(0.06, 0.09, 0.006), Vector3(0.035, 1.30, 0), P.team)
		"halberd":
			M.cyl(g, 0.015, 0.015, 1.40, Vector3(0, 0.40, 0), P.wood, 6)
			M.cyl(g, 0.0, 0.026, 0.16, Vector3(0, 1.18, 0), P.steel, 4)
			M.box(g, Vector3(0.03, 0.13, 0.17), Vector3(0, 1.04, 0.09), P.steel)
			M.box(g, Vector3(0.025, 0.04, 0.10), Vector3(0, 1.06, -0.07), P.steel_d)
			M.box(g, Vector3(0.05, 0.08, 0.006), Vector3(0.03, 0.92, 0), P.team)
		"spear":
			M.cyl(g, 0.014, 0.014, 1.55, Vector3(0, 0.42, 0), P.wood, 6)
			M.cyl(g, 0.0, 0.03, 0.15, Vector3(0, 1.25, 0), P.steel, 5)
		"lance":
			M.cyl(g, 0.016, 0.022, 1.85, Vector3(0, 0.50, 0), P.wood, 6)
			M.cyl(g, 0.0, 0.034, 0.18, Vector3(0, 1.51, 0), P.steel, 5)
			M.cyl(g, 0.04, 0.03, 0.10, Vector3(0, 0.0, 0), P.steel_d, 8)
			M.box(g, Vector3(0.012, 0.16, 0.26), Vector3(0, 1.26, -0.13), P.team)
		"hammer":
			M.cyl(g, 0.017, 0.02, 0.40, Vector3(0, 0.12, 0), P.wood, 6)
			M.box(g, Vector3(0.09, 0.08, 0.15), Vector3(0, 0.34, 0.02), P.steel_d)
		"pickaxe":
			M.cyl(g, 0.017, 0.02, 0.50, Vector3(0, 0.16, 0), P.wood, 6)
			var pk := M.box(g, Vector3(0.03, 0.04, 0.36), Vector3(0, 0.42, 0.0), P.steel_d)
			pk.name = "pico"
			M.box(g, Vector3(0.04, 0.06, 0.05), Vector3(0, 0.42, 0.0), P.steel)
		"hoe":
			M.cyl(g, 0.016, 0.019, 0.60, Vector3(0, 0.20, 0), P.wood, 6)
			var hb := M.box(g, Vector3(0.03, 0.04, 0.12), Vector3(0, 0.50, 0.06), P.steel_d)
			hb.rotation_degrees.x = -30.0
		"staff":
			M.cyl(g, 0.016, 0.02, 1.55, Vector3(0, 0.45, 0), P.wood, 6)
			M.box(g, Vector3(0.022, 0.15, 0.022), Vector3(0, 1.26, 0), P.gold)
			M.box(g, Vector3(0.10, 0.022, 0.022), Vector3(0, 1.28, 0), P.gold)
		"javelin":
			M.cyl(g, 0.011, 0.011, 0.95, Vector3(0, 0.30, 0), P.wood, 5)
			M.cyl(g, 0.0, 0.022, 0.12, Vector3(0, 0.82, 0), P.steel, 4)
		"arquebus":
			var bar := M.cyl(g, 0.02, 0.022, 0.86, Vector3(0, 0.40, 0.0), P.steel_d, 8)
			bar.name = "can"
			M.box(g, Vector3(0.045, 0.30, 0.07), Vector3(0, -0.06, -0.01), P.wood)
			M.box(g, Vector3(0.03, 0.06, 0.03), Vector3(0, 0.12, -0.04), P.steel_d)
		"crossbow":
			# eje +y = hacia donde dispara; el arco cruza en x
			M.box(g, Vector3(0.05, 0.54, 0.07), Vector3(0, 0.12, 0), P.wood)
			M.box(g, Vector3(0.42, 0.03, 0.03), Vector3(0, 0.36, 0), P.wood_d)
			M.box(g, Vector3(0.40, 0.008, 0.008), Vector3(0, 0.30, 0), P.cloth_w)
			if bool(o.get("loaded", true)):
				M.cyl(g, 0.008, 0.008, 0.30, Vector3(0, 0.30, 0.045), P.wood_d, 4)
				M.cyl(g, 0.0, 0.02, 0.05, Vector3(0, 0.47, 0.045), P.steel, 4)
		"shield":
			var sd := M.cyl(g, 0.17, 0.17, 0.04, Vector3.ZERO, P.team, 24)
			sd.rotation_degrees.x = 90.0
			var sb := M.ball(g, 0.045, Vector3(0, 0, 0.03), P.steel)
			sb.name = "boss"
			var rim := M.cyl(g, 0.175, 0.175, 0.03, Vector3(0, 0, -0.005), P.steel_d, 24)
			rim.rotation_degrees.x = 90.0
		"buckler":
			var bd := M.cyl(g, 0.105, 0.105, 0.035, Vector3.ZERO, P.leather_l, 20)
			bd.rotation_degrees.x = 90.0
			M.ball(g, 0.035, Vector3(0, 0, 0.03), P.steel)
		"kite":
			var kt := M.box(g, Vector3(0.20, 0.30, 0.035), Vector3(0, -0.04, 0), P.team)
			kt.name = "kite"
			M.cyl(g, 0.0, 0.10, 0.12, Vector3(0, -0.25, 0), P.team, 4).rotation_degrees.y = 45.0
			M.box(g, Vector3(0.20, 0.04, 0.04), Vector3(0, 0.12, 0), P.steel_d)
		"bow", "longbow":
			_bow(g, P, kind == "longbow", o)

## Arco de eje +y con la barriga hacia +z; `draw` = vector (en el marco del arco) desde la empuñadura hasta la mano que tensa.
static func _bow(g: Node3D, P: Dictionary, long: bool, o: Dictionary) -> void:
	var h := 0.92 if long else 0.62
	var prev := Vector3.ZERO
	var n := 6
	for i in n + 1:
		var t := -1.0 + 2.0 * float(i) / float(n)
		var pt := Vector3(0, t * h * 0.5, 0.10 * (1.0 - t * t) + (0.0))
		if i > 0:
			seg(g, prev, pt, 0.014 if long else 0.012, P.wood, 5)
		prev = pt
	var top := Vector3(0, h * 0.5, 0.0)
	var bot := Vector3(0, -h * 0.5, 0.0)
	var dv: Vector3 = o.get("draw", Vector3.ZERO)
	if dv.length() > 0.05:
		var nock := dv
		seg(g, top, nock, 0.004, P.cloth_w, 4)
		seg(g, bot, nock, 0.004, P.cloth_w, 4)
		# flecha: de la mano al frente de la empuñadura
		var tip := Vector3(0, 0.0, 0.34)
		seg(g, nock, tip, 0.006, P.wood_d, 4)
		M.cyl(g, 0.0, 0.016, 0.05, tip + Vector3(0, 0, 0.02), P.steel, 4).rotation_degrees.x = 90.0
	else:
		seg(g, top, bot, 0.004, P.cloth_w, 4)

# ------------------------------------------------------------------ cabezas

static func _hair_m(P: Dictionary, sp: Dictionary) -> Material:
	return P[String(sp.get("hair", "hair"))]

## Cara: cráneo ovoide, nariz, ojos y orejas. A tamaño de juego casi no se distinguen, pero dan sombra de volumen, dirección de la mirada
## y un tono de piel distinto del de la ropa (lo que más delata a un muñeco es que cara, manos y ropa sean del mismo color).
static func _face(parent: Node3D, P: Dictionary, y: float, ears: bool = true) -> void:
	var skin: Material = P.skin
	M.ball(parent, 0.086, Vector3(0, y, 0), skin, Vector3(0.94, 1.07, 1.0)).name = "cabeza"
	M.ball(parent, 0.019, Vector3(0, y - 0.014, 0.084), skin, Vector3(0.8, 1.15, 1.0))
	for s in [-1, 1]:
		M.ball(parent, 0.0105, Vector3(s * 0.033, y + 0.012, 0.078), P.eye)
		if ears:
			M.ball(parent, 0.02, Vector3(s * 0.079, y - 0.006, -0.004), skin, Vector3(0.55, 1.0, 0.85))

## Pelo: casquete + nuca (corto), o con melena (largo). La frente y la cara quedan despejadas.
static func _hair(parent: Node3D, P: Dictionary, sp: Dictionary, y: float, style: String) -> void:
	var hm := _hair_m(P, sp)
	M.ball(parent, 0.095, Vector3(0, y + 0.036, -0.012), hm, Vector3(1.0, 0.72, 1.03))
	M.ball(parent, 0.07, Vector3(0, y - 0.012, -0.05), hm, Vector3(1.08, 1.0, 0.8))
	if style == "long":
		M.ball(parent, 0.075, Vector3(0, y - 0.045, -0.062), hm, Vector3(1.05, 1.3, 0.8))
		M.cyl(parent, 0.052, 0.034, 0.14, Vector3(0, y - 0.105, -0.075), hm, 8)
	if bool(sp.get("beard", false)):
		M.ball(parent, 0.052, Vector3(0, y - 0.058, 0.040), hm, Vector3(1.1, 0.85, 0.9))
		M.ball(parent, 0.03, Vector3(0, y - 0.03, 0.070), hm, Vector3(2.0, 0.5, 0.6))

static func head(parent: Node3D, kind: String, P: Dictionary, y: float, sp: Dictionary = {}) -> void:
	_face(parent, P, y)
	match kind:
		"straw":
			# sombrero de paja pequeño y ladeado: deja ver el pelo, la cara y las orejas
			var hat := Node3D.new()
			hat.position = Vector3(0, y + 0.052, -0.004)
			hat.rotation_degrees = Vector3(-4.0, 0.0, 5.0)
			parent.add_child(hat)
			M.cyl(hat, 0.128, 0.128, 0.011, Vector3.ZERO, P.straw, 18)
			M.cyl(hat, 0.052, 0.072, 0.062, Vector3(0, 0.034, 0), P.straw, 14)
			M.cyl(hat, 0.073, 0.073, 0.014, Vector3(0, 0.012, 0), P.team, 14)
			_hair(parent, P, sp, y - 0.012, "short")
		"bare_short":
			_hair(parent, P, sp, y, "short")
		"bare_long":
			_hair(parent, P, sp, y, "long")
		"cap_linen":
			# gorro de lino: casquete claro con vuelta
			M.ball(parent, 0.096, Vector3(0, y + 0.032, -0.012), P.linen, Vector3(1.0, 0.68, 1.04))
			M.cyl(parent, 0.092, 0.095, 0.026, Vector3(0, y + 0.03, -0.004), P.team, 16)
			M.ball(parent, 0.062, Vector3(0, y - 0.01, -0.056), _hair_m(P, sp), Vector3(1.1, 0.9, 0.8))
		"kerchief":
			# pañuelo de lino anudado atrás, con cinta del color del equipo
			M.ball(parent, 0.098, Vector3(0, y + 0.03, -0.014), P.linen, Vector3(1.0, 0.70, 1.06))
			M.ball(parent, 0.075, Vector3(0, y - 0.02, -0.06), P.linen, Vector3(1.08, 1.25, 0.78))
			M.cyl(parent, 0.092, 0.092, 0.016, Vector3(0, y + 0.036, -0.004), P.team, 16)
			M.ball(parent, 0.034, Vector3(0, y - 0.01, -0.108), P.linen, Vector3(1.0, 1.4, 1.0))
		"kettle":
			M.cyl(parent, 0.127, 0.127, 0.012, Vector3(0, y + 0.05, 0), P.steel, 18)
			M.ball(parent, 0.098, Vector3(0, y + 0.045, 0), P.steel, Vector3(1, 0.85, 1))
		"nasal":
			M.ball(parent, 0.102, Vector3(0, y + 0.035, -0.004), P.steel, Vector3(1, 0.80, 1))
			M.box(parent, Vector3(0.022, 0.07, 0.02), Vector3(0, y - 0.01, 0.09), P.steel)
			M.box(parent, Vector3(0.025, 0.07, 0.07), Vector3(0, y + 0.13, -0.01), P.red)
		"sallet":
			M.ball(parent, 0.105, Vector3(0, y + 0.03, -0.005), P.steel, Vector3(1, 0.92, 1.02))
			M.box(parent, Vector3(0.17, 0.05, 0.05), Vector3(0, y + 0.01, 0.07), P.steel_d)
			M.box(parent, Vector3(0.12, 0.09, 0.07), Vector3(0, y - 0.01, -0.10), P.steel)
		"greathelm":
			M.cyl(parent, 0.104, 0.108, 0.20, Vector3(0, y + 0.01, 0), P.steel, 14)
			M.ball(parent, 0.104, Vector3(0, y + 0.11, 0), P.steel, Vector3(1, 0.7, 1))
			M.box(parent, Vector3(0.12, 0.022, 0.03), Vector3(0, y + 0.03, 0.105), P.black)
			M.box(parent, Vector3(0.022, 0.10, 0.03), Vector3(0, y - 0.03, 0.108), P.black)
			M.box(parent, Vector3(0.03, 0.10, 0.12), Vector3(0, y + 0.19, -0.01), P.team)
		"horned":
			_hair(parent, P, sp, y, "long")
			M.cyl(parent, 0.10, 0.10, 0.04, Vector3(0, y + 0.065, 0), P.steel_d, 14)
			for s in [-1, 1]:
				var hn := M.cyl(parent, 0.0, 0.03, 0.16, Vector3(s * 0.13, y + 0.11, 0), P.bone, 6)
				hn.rotation_degrees.z = -s * 35.0
		"hood":
			M.cyl(parent, 0.0, 0.125, 0.22, Vector3(0, y + 0.085, -0.02), P.team, 12)
			M.ball(parent, 0.12, Vector3(0, y - 0.03, -0.045), P.team, Vector3(1.05, 0.85, 0.85))
		"cap_feather":
			M.ball(parent, 0.098, Vector3(0, y + 0.03, -0.004), P.green, Vector3(1, 0.65, 1))
			M.cyl(parent, 0.12, 0.12, 0.012, Vector3(0, y + 0.04, 0.01), P.green_d, 14)
			var fe := M.box(parent, Vector3(0.014, 0.02, 0.2), Vector3(0.06, y + 0.12, -0.07), P.white)
			fe.rotation_degrees.x = 30.0
		"cap":
			M.ball(parent, 0.095, Vector3(0, y + 0.03, -0.004), P.team, Vector3(1, 0.7, 1))
			M.cyl(parent, 0.10, 0.10, 0.02, Vector3(0, y + 0.01, 0.0), P.team_d, 14)
		"helm_open":
			M.ball(parent, 0.1, Vector3(0, y + 0.04, -0.006), P.steel, Vector3(1, 0.78, 1))
			M.cyl(parent, 0.104, 0.104, 0.03, Vector3(0, y + 0.02, 0), P.leather, 14)
			M.box(parent, Vector3(0.02, 0.06, 0.02), Vector3(0, y + 0.0, 0.1), P.steel)
		"tonsure":
			# corona de pelo con la coronilla rapada
			M.cyl(parent, 0.091, 0.092, 0.05, Vector3(0, y - 0.008, 0), _hair_m(P, sp), 14)
			M.ball(parent, 0.07, Vector3(0, y - 0.012, -0.05), _hair_m(P, sp), Vector3(1.08, 1.0, 0.8))
		"morion":
			M.cyl(parent, 0.14, 0.12, 0.014, Vector3(0, y + 0.05, 0), P.steel, 18)
			M.ball(parent, 0.098, Vector3(0, y + 0.07, -0.004), P.steel, Vector3(1, 0.85, 1))
			M.box(parent, Vector3(0.022, 0.07, 0.17), Vector3(0, y + 0.15, 0), P.steel)
		"turban":
			M.ball(parent, 0.107, Vector3(0, y + 0.04, 0), P.white, Vector3(1.02, 0.85, 1.02))
			M.cyl(parent, 0.108, 0.108, 0.03, Vector3(0, y + 0.015, 0), P.team, 14)
			M.cyl(parent, 0.0, 0.03, 0.07, Vector3(0, y + 0.12, 0), P.white, 8)
		"fur":
			M.cyl(parent, 0.115, 0.12, 0.05, Vector3(0, y + 0.03, 0), P.fur_d, 16)
			M.cyl(parent, 0.04, 0.10, 0.10, Vector3(0, y + 0.10, 0), P.team, 14)
			M.box(parent, Vector3(0.03, 0.08, 0.05), Vector3(0, y + 0.0, -0.11), P.fur_d)
		"coif":
			M.ball(parent, 0.101, Vector3(0, y + 0.0, -0.004), P.mail, Vector3(1, 1.02, 1))
		_:
			_hair(parent, P, sp, y, "short")

# ------------------------------------------------------------------ cuerpo

static func _mat(P: Dictionary, k: String) -> Material:
	return P[k] if P.has(k) else P.cloth_t

## Altura que alcanza la planta del pie bajo la cadera con esas flexiones (para posar el cuerpo con los pies en el suelo).
static func _reach(hip_deg: float, knee_deg: float) -> float:
	return 0.24 * cos(deg_to_rad(hip_deg)) + 0.276 * cos(deg_to_rad(hip_deg + knee_deg))

static func _shoulder(side: float, sp: Dictionary, dy: float) -> Vector3:
	return Vector3(side * (0.134 if bool(sp.get("fem", false)) else 0.152), 0.765 + dy, 0)

static func human(kind: String, team: Color, key: String, seated: bool = false, ov: Dictionary = {}) -> Node3D:
	var sp := spec_of(kind)
	for k in ov:
		sp[k] = ov[k]
	var P := pal(team)
	P.skin = P[String(sp.get("skin", "skin"))]
	var pose := pose_of(sp, key) if not seated else (ov.get("pose") as Dictionary)
	var root := Node3D.new()
	var body := Node3D.new()
	body.scale = Vector3.ONE * BODY_S
	root.add_child(body)
	var top_m: Material = _mat(P, String(sp.top))
	var skirt_m: Material = _mat(P, String(sp.skirt))
	var legs_m: Material = _mat(P, String(sp.get("legs", "brown")))
	var outfit: String = sp.outfit
	var armor := String(sp.get("armor", ""))
	var fem := bool(sp.get("fem", false))
	# ---- piernas: muslo, rodilla, pantorrilla, caña de bota y zapato redondeado
	var ph: float = pose.w
	var spread := float(sp.get("spread", 0.0))
	var stance: Array = pose.get("stance", [0.0, 0.0])
	var reach: Array = [0.0, 0.0]
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(side * (0.062 + spread), HIP_Y, 0)
		body.add_child(hip)
		var si := 0 if side < 0 else 1
		var hip_deg := float(stance[si])
		var knee_deg := 4.0 + absf(hip_deg) * 0.4
		if seated:
			hip_deg = -78.0
			knee_deg = 70.0
		elif ph >= 0.0:
			var a := ph * TAU + (PI if side > 0 else 0.0)
			hip_deg = sin(a) * 30.0
			knee_deg = 8.0 + maxf(0.0, cos(a)) * 40.0
		reach[si] = _reach(hip_deg, knee_deg)
		hip.rotation_degrees.x = hip_deg
		var thigh := M.cyl(hip, 0.060, 0.050, 0.24, Vector3(0, -0.12, 0), legs_m, 10)
		thigh.name = "muslo"
		M.ball(hip, 0.051, Vector3(0, -0.24, 0), legs_m)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.24, 0)
		knee.rotation_degrees.x = knee_deg
		hip.add_child(knee)
		M.cyl(knee, 0.050, 0.040, 0.23, Vector3(0, -0.115, 0), legs_m, 10)
		if bool(sp.get("boots", true)):
			M.cyl(knee, 0.047, 0.043, 0.11, Vector3(0, -0.172, 0), P.leather, 10)
			M.cyl(knee, 0.052, 0.052, 0.018, Vector3(0, -0.122, 0), P.leather_l, 10)
		M.ball(knee, 0.05, Vector3(0, -0.248, 0.042), P.leather, Vector3(0.95, 0.62, 1.95)).name = "pie"
		if armor == "plate":
			M.cyl(knee, 0.056, 0.05, 0.14, Vector3(0, -0.10, 0), P.steel, 8)
	# pies en el suelo: el cuerpo baja lo que el paso levanta la planta (marcha y posturas abiertas)
	var snap := 0.0
	if not seated:
		snap = (maxf(float(reach[0]), float(reach[1])) - _reach(0.0, 4.0)) * BODY_S
	body.position = Vector3(0, float(pose.drop) + snap, 0)
	# ---- falda / túnica / vestido
	if outfit == "robe":
		var rb := M.cyl(body, 0.140, 0.232, 0.50, Vector3(0, 0.25, 0), skirt_m, 18)
		rb.scale = Vector3(1.0, 1.0, 0.92)
		M.cyl(body, 0.234, 0.236, 0.03, Vector3(0, 0.03, 0), P.team_d, 18).scale = Vector3(1.0, 1.0, 0.92)
	elif outfit == "dress":
		var dr := M.cyl(body, 0.128, 0.214, 0.36, Vector3(0, 0.30, 0), skirt_m, 18)
		dr.scale = Vector3(1.0, 1.0, 0.90)
		M.cyl(body, 0.215, 0.216, 0.025, Vector3(0, 0.125, 0), P.cloth_d, 18).scale = Vector3(1.0, 1.0, 0.90)
		var ap := M.box(body, Vector3(0.15, 0.25, 0.012), Vector3(0, 0.33, 0.151), P.linen)
		ap.rotation_degrees.x = -13.0
	elif outfit == "bare":
		M.cyl(body, 0.145, 0.19, 0.16, Vector3(0, 0.40, 0), skirt_m, 16).scale = Vector3(1.0, 1.0, 0.88)
		for k in 8:
			var a2 := TAU * float(k) / 8.0
			M.box(body, Vector3(0.05, 0.10, 0.03), Vector3(cos(a2) * 0.18, 0.32, sin(a2) * 0.165), skirt_m).rotation.y = -a2
	else:
		var sk := M.cyl(body, 0.140, 0.186, 0.21, Vector3(0, 0.395, 0), skirt_m, 16)
		sk.scale = Vector3(1.0, 1.0, 0.9)
		if sp.has("hem"):
			M.cyl(body, 0.188, 0.19, 0.022, Vector3(0, 0.296, 0), _mat(P, String(sp.hem)), 16).scale = Vector3(1.0, 1.0, 0.9)
	# ---- parte alta (inclinable desde la cadera): vientre, pecho ovalado, cuello
	var up := Node3D.new()
	up.position = Vector3(0, HIP_Y, 0)
	up.rotation_degrees = Vector3(-float(pose.lean), float(pose.twist), float(pose.get("roll", 0.0)))
	body.add_child(up)
	var dy := -HIP_Y
	var sw := 0.9 if fem else 1.0
	var bm: Material = P[String(sp.get("belt", "leather"))] if P.has(String(sp.get("belt", "leather"))) else P.leather
	var waist := M.cyl(up, 0.108 * sw, 0.120 * sw, 0.17, Vector3(0, 0.545 + dy, 0), top_m, 14)
	waist.scale = Vector3(1.0, 1.0, 0.84)
	M.ball(up, 0.125, Vector3(0, 0.685 + dy, 0), top_m, Vector3(1.10 * sw, 0.92, 0.80)).name = "pecho"
	if outfit == "bare":
		# bandolera de cuero sobre el pecho desnudo
		var sbd := M.box(up, Vector3(0.05, 0.38, 0.03), Vector3(0.0, 0.655 + dy, 0.092), P.leather)
		sbd.rotation_degrees.z = 32.0
	var belt := M.cyl(up, 0.131 * sw, 0.133 * sw, 0.04, Vector3(0, 0.485 + dy, 0), bm, 14)
	belt.scale = Vector3(1.0, 1.0, 0.84)
	M.box(up, Vector3(0.04, 0.045, 0.012), Vector3(0, 0.485 + dy, 0.112), P.gold)
	if sp.get("arch", "") == "villager" and not fem:
		M.box(up, Vector3(0.07, 0.075, 0.04), Vector3(0.11, 0.44 + dy, 0.045), P.leather_l)   # bolsa al cinto
	if armor == "mail":
		M.ball(up, 0.135, Vector3(0, 0.665 + dy, 0.015), P.mail, Vector3(1.08, 0.95, 0.78))
		for s in [-1, 1]:
			M.ball(up, 0.066, Vector3(s * 0.152, 0.775 + dy, 0), P.mail)
	elif armor == "plate":
		M.ball(up, 0.138, Vector3(0, 0.665 + dy, 0.015), P.steel, Vector3(1.10, 0.95, 0.80))
		for s in [-1, 1]:
			M.ball(up, 0.074, Vector3(s * 0.155, 0.775 + dy, 0), P.steel)
	elif armor == "gambeson":
		M.cyl(up, 0.118, 0.140, 0.30, Vector3(0, 0.63 + dy, 0), P.cloth_w, 12).scale = Vector3(1.05, 1.0, 0.82)
		for yy in [0.54, 0.62, 0.70]:
			M.cyl(up, 0.143, 0.143, 0.012, Vector3(0, yy + dy, 0), top_m, 12).scale = Vector3(1.0, 1.0, 0.84)
	# cuello (con piel a la vista) y cuello de la prenda / pañuelo / gorjal
	M.cyl(up, 0.036, 0.042, 0.085, Vector3(0, 0.815 + dy, 0), P.skin, 10).name = "cuello"
	if armor == "mail" or armor == "plate":
		M.cyl(up, 0.066, 0.092, 0.045, Vector3(0, 0.792 + dy, 0), P.mail if armor == "mail" else P.steel, 12)
	elif sp.has("scarf") and not fem:
		var sc := _mat(P, String(sp.scarf))
		M.cyl(up, 0.060, 0.082, 0.036, Vector3(0, 0.790 + dy, 0), sc, 12)
		var kk := M.box(up, Vector3(0.075, 0.075, 0.012), Vector3(0, 0.745 + dy, 0.096), sc)   # pañuelo en pico sobre el pecho
		kk.rotation_degrees = Vector3(-14.0, 0.0, 45.0)
	else:
		M.cyl(up, 0.058, 0.080, 0.034, Vector3(0, 0.790 + dy, 0), _mat(P, String(sp.get("collar", "cloth_w"))), 12)
	if bool(sp.get("surcoat", false)):
		M.box(up, Vector3(0.23, 0.50, 0.02), Vector3(0, 0.58 + dy, 0.113), P.team)
		M.box(up, Vector3(0.05, 0.28, 0.024), Vector3(0, 0.62 + dy, 0.117), P.black)
		M.box(up, Vector3(0.16, 0.05, 0.024), Vector3(0, 0.66 + dy, 0.117), P.black)
		M.box(body, Vector3(0.23, 0.30, 0.02), Vector3(0, 0.30, 0.172), P.team)
	if bool(sp.get("quiver", false)):
		var qv := M.cyl(up, 0.045, 0.04, 0.34, Vector3(0.05, 0.64 + dy, -0.125), P.leather, 8)
		qv.rotation_degrees.z = -14.0
		for k in 4:
			M.box(up, Vector3(0.012, 0.09, 0.012), Vector3(0.015 + k * 0.022 - 0.01, 0.84 + dy, -0.125), P.cloth_w)
	if bool(sp.get("pack", false)):
		M.box(up, Vector3(0.22, 0.24, 0.10), Vector3(0, 0.62 + dy, -0.14), P.leather_l)
	# cabeza: pivota sobre el cuello (ladeo y giro por postura)
	var hd: Array = pose.get("head", [0.0, 0.0, 0.0])
	var hn := Node3D.new()
	hn.position = Vector3(0, 0.855 + dy, 0)
	hn.rotation_degrees = Vector3(float(hd[0]), float(hd[1]), float(hd[2]))
	up.add_child(hn)
	head(hn, String(sp.head), P, HEAD_Y - 0.855, sp)
	# ---- brazos y armas
	var sleeve: Material = P.mail if armor == "mail" else (P.steel if armor == "plate" else (top_m if outfit != "bare" else P.skin))
	var fore_m: Material = P.skin if String(sp.get("fore", "")) == "skin" else (P.mail if armor == "mail" else sleeve)
	var r_k: Dictionary = {}
	var l_k: Dictionary = {}
	for side in [-1, 1]:
		var key_a: String = "ra" if side > 0 else "la"
		var arm_a: Array = pose[key_a]
		var k := arm_k(float(side), arm_a, _shoulder(float(side), sp, dy))
		if side > 0:
			r_k = k
		else:
			l_k = k
	# arco: vector de tensado (mano derecha respecto a la izquierda en el marco del arco)
	var bow_draw := Vector3.ZERO
	if float(pose.draw) > 0.05:
		var dbw := _dbasis(pose.lw)
		bow_draw = dbw.inverse() * ((r_k.hand as Vector3) - (l_k.hand as Vector3))
	for side in [-1, 1]:
		var sh := Node3D.new()
		sh.position = _shoulder(float(side), sp, dy)
		var k2: Dictionary = r_k if side > 0 else l_k
		sh.basis = k2.upper
		up.add_child(sh)
		M.ball(sh, 0.049, Vector3.ZERO, sleeve)
		M.cyl(sh, 0.046, 0.041, 0.165, Vector3(0, -0.08, 0), sleeve, 10)
		M.ball(sh, 0.041, Vector3(0, -0.16, 0), sleeve)
		var el := Node3D.new()
		el.position = Vector3(0, -0.16, 0)
		el.basis = (k2.upper as Basis).inverse() * (k2.fore as Basis)
		sh.add_child(el)
		M.cyl(el, 0.040, 0.033, 0.165, Vector3(0, -0.08, 0), fore_m, 10)
		M.ball(el, 0.040, Vector3(0, -0.172, 0), P.skin, Vector3(0.85, 1.15, 0.72)).name = "mano"
		# arma o escudo en esta mano
		var wk := ""
		var wo: Array = pose.rw if side > 0 else pose.lw
		var show: bool = bool(pose.rshow) if side > 0 else bool(pose.lshow)
		if String(sp.arch) == "bow":
			wk = String(sp.get("weapon", "")) if side < 0 else ""
		elif side > 0:
			wk = String(sp.get("weapon", ""))
		else:
			wk = String(sp.get("off", ""))
		if wk == "shield" and side < 0:
			var sg := Node3D.new()
			sg.position = Vector3(0, -0.10, 0.02)
			sg.basis = (k2.fore as Basis).inverse() * Basis(Vector3.UP, deg_to_rad(-20.0))
			el.add_child(sg)
			weapon(sg, "shield", P, {})
		elif wk == "buckler" and side < 0:
			var sg2 := Node3D.new()
			sg2.position = Vector3(0, -0.14, 0.05)
			sg2.basis = (k2.fore as Basis).inverse()
			el.add_child(sg2)
			weapon(sg2, "buckler", P, {})
		elif wk != "" and show and not (wk == "buckler"):
			if String(sp.arch) == "xbow" and side < 0:
				continue
			if String(sp.arch) == "gsword" and side < 0:
				continue
			var g := Node3D.new()
			g.position = Vector3(0, -0.16, 0)
			g.basis = (k2.fore as Basis).inverse() * _dbasis(wo)
			el.add_child(g)
			var opts := {"loaded": pose.loaded}
			if wk in ["bow", "longbow"]:
				opts["draw"] = bow_draw
			weapon(g, wk, P, opts)
	return root
