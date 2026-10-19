class_name IsoRiders
extends RefCounted
## Caballos con jinete (jinete, explorador, caballero, arquero a caballo, conquistador, catafracta, mameluco, mangudai).
## El caballo mira a +z con el origen en el suelo bajo el centro del cuerpo; el jinete es IsoPeople.human en pose sentada.
## Fotogramas: "idle", "w0".."w3" (paso de cuatro tiempos), "a0".."a2" (ataque, igual que a pie).

const M = preload("res://tools/iso/iso_models.gd")
const P_ = preload("res://tools/iso/iso_people.gd")

const COATS := {
	"bay": [Color(0.42, 0.26, 0.14), Color(0.16, 0.11, 0.08)],
	"chestnut": [Color(0.52, 0.29, 0.12), Color(0.30, 0.16, 0.08)],
	"black": [Color(0.17, 0.14, 0.13), Color(0.07, 0.06, 0.06)],
	"grey": [Color(0.78, 0.76, 0.72), Color(0.46, 0.44, 0.42)],
	"palomino": [Color(0.80, 0.64, 0.38), Color(0.86, 0.78, 0.56)],
	"dark": [Color(0.30, 0.19, 0.11), Color(0.12, 0.08, 0.06)],
	"dun": [Color(0.66, 0.52, 0.34), Color(0.22, 0.16, 0.10)],
}

static func cfg(kind: String) -> Dictionary:
	match kind:
		"jinete":
			return {"coat": "bay", "bard": "cloth", "sc": 1.0, "rider": {"arch": "spear", "outfit": "tunic", "top": "team", "skirt": "team_d", "legs": "brown", "armor": "gambeson", "head": "helm_open", "weapon": "spear", "off": "buckler", "belt": "leather"}}
		"explorador":
			return {"coat": "palomino", "bard": "none", "sc": 0.96, "rider": {"arch": "spear", "outfit": "tunic", "top": "cloth_t", "skirt": "brown", "legs": "brown", "head": "cap", "weapon": "javelin", "belt": "team", "scarf": "team"}}
		"caballero":
			return {"coat": "chestnut", "bard": "plate", "sc": 1.05, "rider": {"arch": "lance", "outfit": "tunic", "top": "team", "skirt": "team_d", "legs": "steel_d", "armor": "plate", "head": "greathelm", "weapon": "lance", "off": "kite", "belt": "leather"}}
		"arquero_caballo":
			return {"coat": "bay", "bard": "none", "sc": 0.98, "rider": {"arch": "bow", "outfit": "tunic", "top": "team", "skirt": "green_d", "legs": "green_d", "head": "hood", "weapon": "bow", "belt": "leather", "quiver": true}}
		"conquistador":
			return {"coat": "black", "bard": "cloth", "sc": 1.0, "rider": {"arch": "gun", "outfit": "tunic", "top": "team", "skirt": "team_d", "legs": "black", "armor": "mail", "head": "morion", "weapon": "arquebus", "belt": "leather"}}
		"catafracta":
			return {"coat": "grey", "bard": "full", "sc": 1.08, "rider": {"arch": "lance2", "outfit": "tunic", "top": "team", "skirt": "team_d", "legs": "steel_d", "armor": "plate", "head": "sallet", "weapon": "lance", "belt": "leather"}}
		"mameluco":
			return {"coat": "dark", "bard": "cloth", "sc": 1.0, "rider": {"arch": "sword", "outfit": "tunic", "top": "team", "skirt": "cloth_w", "legs": "cloth_w", "head": "turban", "weapon": "scimitar", "off": "buckler", "belt": "gold", "skin": "skin_d"}}
		"mangudai":
			return {"coat": "dun", "bard": "none", "sc": 0.90, "rider": {"arch": "bow", "outfit": "tunic", "top": "team", "skirt": "fur_d", "legs": "brown", "head": "fur", "weapon": "bow", "belt": "leather", "quiver": true, "skin": "skin_d"}}
	return {"coat": "bay", "bard": "none", "sc": 1.0, "rider": {"arch": "spear", "outfit": "tunic", "top": "team", "skirt": "team_d", "legs": "brown", "head": "cap", "weapon": "spear", "belt": "leather"}}

static func frames_of(kind: String) -> Array:
	var f := ["idle", "w0", "w1", "w2", "w3"]
	var arch: String = cfg(kind).rider.arch
	if arch in ["bow", "gun"]:
		f.append_array(["a0", "a1", "a2"])
	else:
		f.append_array(["a0", "a1"])
	return f

## Pose del jinete (diccionario como IsoPeople.pose_of, con sentado = true)
static func rider_pose(arch: String, key: String, ph: float) -> Dictionary:
	var sw := 0.0 if ph < 0.0 else sin(ph * TAU)
	var bob := 0.0 if ph < 0.0 else absf(sin(ph * TAU)) * 0.02
	var p := {"w": ph, "ra": [24.0, 40.0, 6.0], "la": [28.0, 50.0, -6.0], "rw": [4.0, 0.0, 0.0], "lw": [0.0, 0.0, 0.0],
		"lean": 3.0 if ph >= 0.0 else 0.0, "twist": 0.0, "drop": bob, "draw": 0.0, "rshow": true, "lshow": true, "loaded": true}
	match arch:
		"spear":
			p.ra = [28.0, 50.0, 6.0]
			p.rw = [6.0 + sw * 3.0, 0.0, 0.0]
			if key == "a0":
				p.ra = [125.0, 55.0, 6.0]
				p.rw = [60.0, 0.0, 0.0]
				p.lean = -4.0
			elif key == "a1":
				p.ra = [78.0, 18.0, 6.0]
				p.rw = [112.0, 0.0, 0.0]
				p.lean = 14.0
		"lance", "lance2":
			p.ra = [30.0, 55.0, 8.0]
			p.rw = [20.0 + sw * 3.0, 0.0, 0.0]
			p.la = [26.0, 46.0, -8.0] if arch == "lance" else [34.0, 56.0, -4.0]
			if key == "a0":
				p.ra = [54.0, 66.0, 8.0]
				p.rw = [78.0, 0.0, 0.0]
				p.la = [46.0, 60.0, -8.0]
				p.lean = 5.0
			elif key == "a1":
				p.ra = [80.0, 16.0, 8.0]
				p.rw = [87.0, 0.0, 0.0]
				p.la = [70.0, 40.0, -8.0]
				p.lean = 12.0
		"sword":
			p.ra = [44.0, 70.0, 8.0]
			p.rw = [38.0, 0.0, 0.0]
			if key == "a0":
				p.ra = [152.0, 60.0, 6.0]
				p.rw = [-15.0, 0.0, 0.0]
				p.lean = -5.0
				p.twist = 12.0
			elif key == "a1":
				p.ra = [88.0, 14.0, 4.0]
				p.rw = [126.0, 0.0, 0.0]
				p.lean = 14.0
				p.twist = -10.0
		"bow":
			p.la = [30.0, 24.0, -6.0]
			p.ra = [10.0, 20.0, 4.0]
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
		"gun":
			p.ra = [32.0, 60.0, 6.0]
			p.la = [34.0, 62.0, -4.0]
			p.rw = [10.0, 0.0, 0.0]
			if key == "a0":
				p.ra = [44.0, 66.0, 6.0]
				p.la = [48.0, 62.0, -4.0]
				p.rw = [56.0, 0.0, 0.0]
				p.lean = 6.0
			elif key == "a2":
				p.ra = [84.0, 48.0, 6.0]
				p.la = [88.0, 20.0, -4.0]
				p.rw = [92.0, 0.0, 0.0]
				p.lean = -1.0
			elif key == "a1":
				p.ra = [84.0, 48.0, 6.0]
				p.la = [88.0, 20.0, -4.0]
				p.rw = [98.0, 0.0, 0.0]
				p.lean = -6.0
	return p

# ------------------------------------------------------------------ caballo

static func _taper(parent: Node3D, a: Vector3, b: Vector3, ra: float, rb: float, m: Material, sides: int = 8) -> MeshInstance3D:
	var d := b - a
	var ln := d.length()
	var mi := M.cyl(parent, rb, ra, maxf(ln, 0.001), (a + b) * 0.5, m, sides)
	if ln > 0.0001:
		mi.basis = Basis(Quaternion(Vector3.UP, d / ln))
	return mi

static func horse(coat_key: String, bard: String, team: Color, ph: float, key: String) -> Node3D:
	var P := P_.pal(team)
	var cc: Array = COATS[coat_key]
	var coat := M.fmat(cc[0], 0.85, 0.25)
	var mane := M.fmat(cc[1], 1.0, 0.05)
	var hoof := M.fmat(Color(0.14, 0.11, 0.09), 0.7, 0.3)
	var root := Node3D.new()
	var bob := 0.0 if ph < 0.0 else absf(sin(ph * TAU)) * 0.018
	var body := Node3D.new()
	body.position = Vector3(0, bob, 0)
	root.add_child(body)
	# cuerpo
	M.ball(body, 0.30, Vector3(0, 0.62, 0.0), coat, Vector3(0.64, 0.80, 1.55))
	M.ball(body, 0.25, Vector3(0, 0.66, 0.31), coat, Vector3(0.80, 1.00, 0.95))
	M.ball(body, 0.25, Vector3(0, 0.66, -0.31), coat, Vector3(0.80, 0.95, 0.95))
	# cuello, cabeza, orejas, crines
	_taper(body, Vector3(0, 0.74, 0.40), Vector3(0, 1.08, 0.58), 0.125, 0.075, coat, 10)
	_taper(body, Vector3(0, 1.08, 0.58), Vector3(0, 0.92, 0.84), 0.082, 0.050, coat, 8)
	M.ball(body, 0.062, Vector3(0, 0.915, 0.87), coat, Vector3(1.0, 0.85, 1.1))
	for s in [-1, 1]:
		M.cyl(body, 0.0, 0.022, 0.07, Vector3(s * 0.04, 1.17, 0.55), coat, 5)
		M.ball(body, 0.012, Vector3(s * 0.055, 1.05, 0.64), M.fmat(Color(0.05, 0.04, 0.04), 0.4, 0.5))
	for k in 6:
		var t := float(k) / 5.0
		M.box(body, Vector3(0.03, 0.07, 0.07), Vector3(0, 1.09 - t * 0.28, 0.42 + (1.0 - t) * 0.17), mane)
	M.box(body, Vector3(0.04, 0.06, 0.05), Vector3(0, 1.16, 0.60), mane)
	# cola
	_taper(body, Vector3(0, 0.76, -0.46), Vector3(0, 0.34, -0.58), 0.045, 0.02, mane, 6)
	_taper(body, Vector3(0, 0.60, -0.50), Vector3(0, 0.30, -0.58), 0.05, 0.012, mane, 6).name = "cola2"
	# patas: paso de cuatro tiempos (trasera izq., delantera izq., trasera der., delantera der.)
	var offs := {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75}
	for leg in ["hl", "fl", "hr", "fr"]:
		var front: bool = leg.begins_with("f")
		var side := -1.0 if leg.ends_with("l") else 1.0
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.115, 0.58, 0.30 if front else -0.30)
		body.add_child(hip)
		var a := 0.0
		var kn := 6.0
		if ph >= 0.0:
			var arg := (ph + float(offs[leg])) * TAU
			a = sin(arg) * 24.0
			kn = 8.0 + maxf(0.0, cos(arg)) * 42.0
		hip.rotation_degrees.x = a
		_taper(hip, Vector3.ZERO, Vector3(0, -0.27, 0), 0.07, 0.048, coat, 8)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.27, 0)
		knee.rotation_degrees.x = kn * (1.0 if front else -1.0)
		hip.add_child(knee)
		_taper(knee, Vector3.ZERO, Vector3(0, -0.28, 0), 0.042, 0.034, coat, 8)
		M.box(knee, Vector3(0.075, 0.06, 0.10), Vector3(0, -0.30, 0.01), hoof)
		M.box(knee, Vector3(0.07, 0.07, 0.07), Vector3(0, -0.22, 0.0), mane if coat_key != "grey" else coat)
	# silla y manta (el color del equipo cae en la manta)
	M.box(body, Vector3(0.46, 0.03, 0.40), Vector3(0, 0.865, -0.02), P.team)
	M.box(body, Vector3(0.23, 0.07, 0.30), Vector3(0, 0.90, -0.04), P.leather)
	M.box(body, Vector3(0.23, 0.12, 0.05), Vector3(0, 0.94, -0.20), P.leather)
	M.box(body, Vector3(0.20, 0.08, 0.05), Vector3(0, 0.93, 0.12), P.leather)
	# bridas
	_taper(body, Vector3(0, 0.95, 0.80), Vector3(0, 0.97, 0.90), 0.05, 0.05, P.leather, 6)
	# barda
	if bard == "cloth" or bard == "plate" or bard == "full":
		for s in [-1, 1]:
			var cl := M.box(body, Vector3(0.025, 0.36, 0.60), Vector3(s * 0.20, 0.55, 0.0), P.team)
			cl.name = "gualdrapa"
			M.box(body, Vector3(0.028, 0.05, 0.62), Vector3(s * 0.20, 0.36, 0.0), P.white)
			if bard != "cloth":
				M.box(body, Vector3(0.025, 0.26, 0.20), Vector3(s * 0.20, 0.55, 0.40), P.team_d)
	if bard == "plate" or bard == "full":
		# testera (placa de la cara), crinera y peto
		M.box(body, Vector3(0.09, 0.05, 0.26), Vector3(0, 1.0, 0.76), P.steel).rotation_degrees.x = 28.0
		for k in 4:
			M.box(body, Vector3(0.10, 0.06, 0.06), Vector3(0, 1.08 - k * 0.06, 0.45 + (3 - k) * 0.04), P.steel)
		M.ball(body, 0.2, Vector3(0, 0.70, 0.43), P.steel, Vector3(0.9, 1.0, 0.45))
	if bard == "full":
		for k in 3:
			M.box(body, Vector3(0.40, 0.02, 0.15), Vector3(0, 0.88 - 0.0 * k, -0.34 + k * 0.18), P.steel)
		M.box(body, Vector3(0.44, 0.25, 0.04), Vector3(0, 0.66, -0.50), P.steel_d)
	return root

# ------------------------------------------------------------------ montado

static func mounted(kind: String, team: Color, key: String) -> Node3D:
	var c := cfg(kind)
	var ph := P_._walk_phase(key)
	var root := Node3D.new()
	var inner := Node3D.new()
	inner.scale = Vector3.ONE * float(c.sc)
	root.add_child(inner)
	inner.add_child(horse(String(c.coat), String(c.bard), team, ph, key))
	var rd: Dictionary = (c.rider as Dictionary).duplicate()
	var bob := 0.0 if ph < 0.0 else absf(sin(ph * TAU)) * 0.018
	var pose := rider_pose(String(rd.arch), key, ph)
	pose["w"] = -1.0
	rd["pose"] = pose
	rd["spread"] = 0.13
	var h := P_.human(kind, team, key, true, rd)
	h.position = Vector3(0, 0.43 + bob, -0.02)
	inner.add_child(h)
	return root
