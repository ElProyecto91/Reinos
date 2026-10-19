class_name IsoMachines
extends RefCounted
## Máquinas de asedio (ariete, catapulta, trabuquete), barcos y animales (ciervo, jabalí). Todos miran a +z (el horneado los gira).
## Fotogramas: "idle", "w0".."w3" (marcha: giran las ruedas / dan pasos), "a0", "a1" (ataque: cargada / disparo o golpe).

const M = preload("res://tools/iso/iso_models.gd")
const P_ = preload("res://tools/iso/iso_people.gd")

static func frames_of(kind: String) -> Array:
	match kind:
		"ariete", "catapulta", "trabuquete":
			return ["idle", "w0", "w1", "w2", "w3", "a0", "a1"]
		"ciervo", "jabali":
			return ["idle", "w0", "w1", "w2", "w3"]
	return ["idle"]

static func _wood(seed_v: int, c: Color) -> StandardMaterial3D:
	return M.tmat(M.tex_wood(seed_v, c), 1.8)

static func _wheel(parent: Node3D, pos: Vector3, r: float, rot_deg: float, m_wood: Material, m_iron: Material, spokes: int = 8) -> void:
	# rueda con eje en x: llanta, cubo y radios (giran con rot_deg)
	var w := Node3D.new()
	w.position = pos
	parent.add_child(w)
	var rim := M.cyl(w, r, r, 0.07, Vector3.ZERO, m_wood, 16)
	rim.rotation_degrees.z = 90.0
	var core := M.cyl(w, r * 0.84, r * 0.84, 0.075, Vector3.ZERO, m_iron, 16)
	core.rotation_degrees.z = 90.0
	var inner := M.cyl(w, r * 0.80, r * 0.80, 0.08, Vector3.ZERO, m_wood, 16)
	inner.rotation_degrees.z = 90.0
	for k in spokes:
		var sp := M.box(w, Vector3(0.09, r * 1.72, 0.035), Vector3.ZERO, m_iron)
		sp.rotation_degrees.x = rot_deg + float(k) * 180.0 / float(spokes)
	var hub := M.cyl(w, 0.05, 0.05, 0.14, Vector3.ZERO, m_iron, 8)
	hub.rotation_degrees.z = 90.0

static func build(kind: String, team: Color, key: String) -> Node3D:
	match kind:
		"ariete":
			return ariete(team, key)
		"catapulta":
			return catapulta(team, key)
		"trabuquete":
			return trabuquete(team, key)
		"ciervo":
			return ciervo(key)
		"jabali":
			return jabali(key)
	return barco(kind, team)

# ------------------------------------------------------------------ ariete

static func ariete(team: Color, key: String) -> Node3D:
	var root := Node3D.new()
	var P := P_.pal(team)
	var wood := _wood(300, Color(0.62, 0.46, 0.26))
	var wood_d := _wood(301, Color(0.42, 0.30, 0.17))
	var roof_m := M.tmat(M.tex_roof(302, Color(0.52, 0.38, 0.24)), 1.6)
	var ph := P_._walk_phase(key)
	var sw := 0.0 if ph < 0.0 else sin(ph * TAU)
	var bob := 0.0 if ph < 0.0 else absf(sin(ph * TAU)) * 0.012
	var b := Node3D.new()
	b.position = Vector3(0, bob, 0)
	root.add_child(b)
	# bastidor, postes y ruedas
	for s in [-1, 1]:
		M.box(b, Vector3(0.07, 0.10, 1.70), Vector3(s * 0.34, 0.26, 0), wood_d)
		for z in [-0.62, 0.62]:
			M.box(b, Vector3(0.08, 0.70, 0.08), Vector3(s * 0.34, 0.62, z), wood)
		M.box(b, Vector3(0.07, 0.07, 1.50), Vector3(s * 0.34, 0.95, 0), wood)
		for z in [-0.55, 0.55]:
			_wheel(b, Vector3(s * 0.40, 0.17, z), 0.17, ph * 45.0 if ph >= 0.0 else 0.0, wood, P.steel_d, 6)
	for z in [-0.62, 0.62]:
		M.box(b, Vector3(0.78, 0.07, 0.07), Vector3(0, 0.95, z), wood)
	# techo a dos aguas con tejas y franjas del equipo
	var roof := M.prism(b, 0.96, 0.34, 1.78, Vector3(0, 1.15, 0), roof_m)
	roof.name = "techo"
	M.box(b, Vector3(0.05, 0.04, 1.80), Vector3(0, 1.33, 0), wood_d)
	for z in [-0.50, 0.0, 0.50]:
		for s in [-1, 1]:
			var st := M.box(b, Vector3(0.20, 0.03, 0.16), Vector3(s * 0.22, 1.16, z), P.team)
			st.rotation_degrees.z = float(s) * 30.0
	# viga con cadenas y cabeza de hierro
	var kick := 0.0
	if key == "a0":
		kick = -0.30
	elif key == "a1":
		kick = 0.34
	elif ph >= 0.0:
		kick = sw * 0.04
	var ram := Node3D.new()
	ram.position = Vector3(0, 0.0, kick)
	b.add_child(ram)
	M.cyl(ram, 0.075, 0.075, 1.80, Vector3(0, 0.70, 0.12), wood, 10).rotation_degrees.x = 90.0
	var head := M.cyl(ram, 0.0, 0.10, 0.22, Vector3(0, 0.70, 1.10), P.steel_d, 8)
	head.rotation_degrees.x = 90.0
	M.cyl(ram, 0.095, 0.095, 0.06, Vector3(0, 0.70, 0.94), P.steel_d, 10).rotation_degrees.x = 90.0
	for z in [-0.30, 0.50]:
		for s in [-1, 1]:
			var ch := P_.seg(ram, Vector3(s * 0.12, 0.70, z + 0.12), Vector3(s * 0.30, 0.97, z + 0.12), 0.012, P.steel_d, 4)
			ch.name = "cadena"
	# soldados empujando: botas bajo el techo (se ven a los lados) y brazos
	for s in [-1, 1]:
		for k in 2:
			var step := sin((ph + 0.5 * float(k) + (0.25 if s > 0 else 0.0)) * TAU) * 0.10 if ph >= 0.0 else 0.0
			M.box(b, Vector3(0.09, 0.09, 0.16), Vector3(s * 0.20, 0.07, -0.30 + float(k) * 0.80 + step), P.leather)
			M.cyl(b, 0.05, 0.05, 0.40, Vector3(s * 0.20, 0.30, -0.32 + float(k) * 0.80 + step * 0.6), P.brown, 8)
	# banderín
	M.box(b, Vector3(0.02, 0.18, 0.22), Vector3(0, 1.50, -0.74), P.team)
	M.cyl(b, 0.01, 0.01, 0.36, Vector3(0, 1.45, -0.62), wood_d, 5)
	return root

# ------------------------------------------------------------------ catapulta

static func catapulta(team: Color, key: String) -> Node3D:
	var root := Node3D.new()
	var P := P_.pal(team)
	var wood := _wood(310, Color(0.64, 0.48, 0.28))
	var wood_d := _wood(311, Color(0.46, 0.33, 0.18))
	var stone := M.tmat(M.tex_stone(312, Color(0.55, 0.54, 0.56)), 3.0)
	var ph := P_._walk_phase(key)
	var bob := 0.0 if ph < 0.0 else absf(sin(ph * TAU)) * 0.012
	var b := Node3D.new()
	b.position = Vector3(0, bob, 0)
	root.add_child(b)
	M.box(b, Vector3(0.64, 0.12, 1.14), Vector3(0, 0.30, 0), wood_d)
	for s in [-1, 1]:
		for z in [-0.38, 0.38]:
			_wheel(b, Vector3(s * 0.38, 0.19, z), 0.19, ph * 45.0 if ph >= 0.0 else 0.0, wood, P.steel_d, 8)
		M.box(b, Vector3(0.10, 0.62, 0.10), Vector3(s * 0.25, 0.62, 0.10), wood)
	M.box(b, Vector3(0.62, 0.10, 0.10), Vector3(0, 0.92, 0.10), wood_d)
	# brazo: cargado (atrás) o disparado (adelante)
	var ang := -56.0
	var with_stone := true
	if key == "a1":
		ang = 38.0
		with_stone = false
	var arm := Node3D.new()
	arm.position = Vector3(0, 0.92, 0.10)
	arm.rotation_degrees.x = ang
	b.add_child(arm)
	M.box(arm, Vector3(0.10, 1.10, 0.09), Vector3(0, 0.40, 0), wood)
	M.box(arm, Vector3(0.22, 0.22, 0.10), Vector3(0, 0.98, 0), wood_d)
	M.box(arm, Vector3(0.20, 0.06, 0.20), Vector3(0, -0.20, 0), P.steel_d)
	if with_stone:
		M.ball(arm, 0.10, Vector3(0, 1.10, 0), stone)
	M.box(b, Vector3(0.30, 0.36, 0.05), Vector3(0, 0.42, -0.40), P.team)
	return root

# ------------------------------------------------------------------ trabuquete

static func trabuquete(team: Color, key: String) -> Node3D:
	var root := Node3D.new()
	var P := P_.pal(team)
	var wood := _wood(320, Color(0.64, 0.48, 0.28))
	var wood_d := _wood(321, Color(0.46, 0.33, 0.18))
	var stone := M.tmat(M.tex_stone(322, Color(0.55, 0.54, 0.56)), 3.0)
	var ph := P_._walk_phase(key)
	var bob := 0.0 if ph < 0.0 else absf(sin(ph * TAU)) * 0.012
	var b := Node3D.new()
	b.position = Vector3(0, bob, 0)
	root.add_child(b)
	# bastidor bajo con cuatro ruedas pequeñas
	for s in [-0.34, 0.34]:
		M.box(b, Vector3(0.12, 0.12, 1.60), Vector3(s, 0.20, 0.05), wood_d)
		for z in [-0.55, 0.60]:
			_wheel(b, Vector3(s * 1.25, 0.12, z), 0.12, ph * 60.0 if ph >= 0.0 else 0.0, wood, P.steel_d, 6)
	for z in [-0.55, 0.0, 0.55]:
		M.box(b, Vector3(0.80, 0.10, 0.12), Vector3(0, 0.27, z), wood_d)
	# caballetes en A
	var th := atan2(0.50, 1.05)
	var plen := sqrt(0.50 * 0.50 + 1.05 * 1.05)
	for s in [-0.30, 0.30]:
		for sz in [-1, 1]:
			var post := M.box(b, Vector3(0.10, plen, 0.10), Vector3(s, 0.12 + 0.525, sz * 0.25), wood)
			post.rotation.x = -float(sz) * th
		M.box(b, Vector3(0.07, 0.07, 0.62), Vector3(s, 0.78, 0), wood_d)
	var pivot := Vector3(0, 1.20, 0)
	M.box(b, Vector3(0.80, 0.07, 0.07), pivot, P.steel_d)
	# brazo: cargado (extremo largo abajo-atrás, contrapeso arriba) o disparado
	var ang := -128.0
	var with_stone := true
	if key == "a1":
		ang = 30.0
		with_stone = false
	var arm := Node3D.new()
	arm.position = pivot
	arm.rotation_degrees.x = ang
	b.add_child(arm)
	M.box(arm, Vector3(0.12, 1.90, 0.10), Vector3(0, 0.0, 0), wood)
	M.box(arm, Vector3(0.16, 0.14, 0.14), Vector3(0, 0.95, 0), P.steel_d)
	M.box(arm, Vector3(0.34, 0.34, 0.36), Vector3(0, -1.02, 0), wood_d)
	M.box(arm, Vector3(0.36, 0.06, 0.38), Vector3(0, -0.82, 0), P.team)
	M.box(arm, Vector3(0.36, 0.06, 0.38), Vector3(0, -1.22, 0), P.team)
	if with_stone:
		M.box(arm, Vector3(0.025, 0.40, 0.025), Vector3(0, 1.15, 0), P.cloth_d)
		M.ball(arm, 0.09, Vector3(0, 1.38, 0), stone)
	M.box(b, Vector3(0.02, 0.10, 0.22), Vector3(0, 1.50, 0.0), P.team)
	return root

# ------------------------------------------------------------------ barcos

## Casco por secciones: perfil en V suave, popa recta y proa en punta que sube. L = eslora, W = manga, H = francobordo.
static func _hull(parent: Node3D, L: float, W: float, H: float, m: Material, deck_m: Material, bow_rise: float = 0.18, stern_w: float = 0.62) -> void:
	var n := 14
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var secs: Array = []
	for i in n + 1:
		var t := float(i) / float(n)          # 0 = popa, 1 = proa
		var z := -L * 0.5 + L * t
		var w := W * 0.5 * (lerpf(stern_w, 1.0, minf(t * 3.0, 1.0)) if t < 0.33 else lerpf(1.0, 0.0, pow((t - 0.33) / 0.67, 1.6)))
		var rise := bow_rise * pow(t, 3.0) * H
		var h := H + rise
		var keel := 0.10 + 0.05 * (1.0 - t)
		secs.append([z, w, h, keel])
	var prof := [Vector2(-1.0, 1.0), Vector2(-0.90, 0.42), Vector2(0.0, 0.0), Vector2(0.90, 0.42), Vector2(1.0, 1.0)]
	for i in n:
		var a: Array = secs[i]
		var c: Array = secs[i + 1]
		for j in prof.size() - 1:
			var p0: Vector2 = prof[j]
			var p1: Vector2 = prof[j + 1]
			var va0 := Vector3(p0.x * a[1], lerpf(a[3], a[2], p0.y), a[0])
			var va1 := Vector3(p1.x * a[1], lerpf(a[3], a[2], p1.y), a[0])
			var vb0 := Vector3(p0.x * c[1], lerpf(c[3], c[2], p0.y), c[0])
			var vb1 := Vector3(p1.x * c[1], lerpf(c[3], c[2], p1.y), c[0])
			for v in [va0, vb0, va1, va1, vb0, vb1]:
				st.add_vertex(v)
	# popa (espejo de la primera sección)
	var s0: Array = secs[0]
	for j in prof.size() - 1:
		var p0b: Vector2 = prof[j]
		var p1b: Vector2 = prof[j + 1]
		var q0 := Vector3(p0b.x * s0[1], lerpf(s0[3], s0[2], p0b.y), s0[0])
		var q1 := Vector3(p1b.x * s0[1], lerpf(s0[3], s0[2], p1b.y), s0[0])
		var qc := Vector3(0, lerpf(s0[3], s0[2], 0.5), s0[0])
		for v in [qc, q0, q1]:
			st.add_vertex(v)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mm: StandardMaterial3D = (m as StandardMaterial3D).duplicate()
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mm
	parent.add_child(mi)
	# cubierta
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a2: Array = secs[i]
		var c2: Array = secs[i + 1]
		var ya: float = float(a2[2]) - 0.03
		var yc: float = float(c2[2]) - 0.03
		var wa: float = float(a2[1]) * 0.94
		var wc: float = float(c2[1]) * 0.94
		for v in [Vector3(-wa, ya, a2[0]), Vector3(-wc, yc, c2[0]), Vector3(wa, ya, a2[0]), Vector3(wa, ya, a2[0]), Vector3(-wc, yc, c2[0]), Vector3(wc, yc, c2[0])]:
			st2.add_vertex(v)
	st2.generate_normals()
	var di := MeshInstance3D.new()
	di.mesh = st2.commit()
	var dm: StandardMaterial3D = (deck_m as StandardMaterial3D).duplicate()
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	di.material_override = dm
	parent.add_child(di)

static func _sail(parent: Node3D, pos: Vector3, w: float, h: float, m: Material, bulge: float = 0.10) -> void:
	# vela cuadra: rectángulo combado hacia proa (+z) hecho con cinco tiras
	var n := 5
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var x := -w * 0.5 + w * t
		var zb := bulge * (1.0 - pow(2.0 * t - 1.0, 2.0))
		var strip := M.box(parent, Vector3(w / float(n) * 1.06, h, 0.025), pos + Vector3(x, 0.0, zb), m)
		strip.rotation.y = (t - 0.5) * 0.5

static func _mast(parent: Node3D, base: Vector3, h: float, wood: Material, yard_w: float = 0.0, yard_y: float = 0.0, ym: Material = null) -> void:
	M.cyl(parent, 0.025, 0.04, h, base + Vector3(0, h * 0.5, 0), wood, 8)
	if yard_w > 0.0:
		var y := M.cyl(parent, 0.016, 0.016, yard_w, base + Vector3(0, yard_y, 0), ym if ym != null else wood, 6)
		y.rotation_degrees.z = 90.0

## Franjas del equipo a lo largo de las dos bandas (la cubierta queda de madera)
static func _rails(parent: Node3D, x: float, y: float, z0: float, z1: float, m: Material) -> void:
	for s in [-1, 1]:
		M.box(parent, Vector3(0.035, 0.045, z1 - z0), Vector3(s * x, y, (z0 + z1) * 0.5), m)

static func barco(kind: String, team: Color) -> Node3D:
	var root := Node3D.new()
	var P := P_.pal(team)
	var hull_m := _wood(330, Color(0.46, 0.30, 0.16))
	var hull_d := _wood(331, Color(0.34, 0.22, 0.12))
	var deck_m := _wood(332, Color(0.68, 0.52, 0.30))
	var sail_w := M.fmat(Color(0.93, 0.90, 0.80), 0.95, 0.1)
	var sail_t: Material = P.team
	match kind:
		"barco_pesca":
			_hull(root, 1.30, 0.50, 0.26, hull_m, deck_m, 0.30, 0.55)
			_rails(root, 0.22, 0.27, -0.45, 0.30, P.team_d)
			_mast(root, Vector3(0, 0.24, 0.10), 1.15, hull_d)
			# vela latina: triángulo de dos tiras + botavara
			var boom := M.cyl(root, 0.014, 0.014, 0.80, Vector3(0, 0.50, -0.22), hull_d, 6)
			boom.rotation_degrees.x = 90.0
			for k in 5:
				var t := float(k) / 5.0
				var hh := lerpf(0.78, 0.10, t)
				M.box(root, Vector3(0.02, hh, 0.16), Vector3(0.03, 0.50 + hh * 0.5, -0.50 + t * 0.62 + 0.08), sail_w)
			M.box(root, Vector3(0.026, 0.10, 0.34), Vector3(0.04, 0.80, -0.22), sail_t)
			# aparejos de pesca: red y cajas
			M.ball(root, 0.13, Vector3(0, 0.30, -0.40), M.fmat(Color(0.56, 0.50, 0.34), 0.95, 0.1), Vector3(1.3, 0.5, 1.2))
			M.box(root, Vector3(0.16, 0.10, 0.16), Vector3(0.12, 0.31, 0.32), hull_d)
			M.cyl(root, 0.01, 0.01, 0.34, Vector3(-0.14, 0.45, 0.36), hull_d, 5).rotation_degrees.x = 60.0
		"barco_transporte":
			_hull(root, 1.55, 0.74, 0.34, hull_m, deck_m, 0.22, 0.70)
			_rails(root, 0.33, 0.36, -0.60, 0.40, P.team_d)
			_mast(root, Vector3(0, 0.34, 0.05), 1.55, hull_d, 0.86, 1.28, hull_d)
			_sail(root, Vector3(0, 0.88, 0.07), 0.80, 0.78, sail_w, 0.10)
			M.box(root, Vector3(0.82, 0.14, 0.03), Vector3(0, 0.62, 0.17), sail_t)
			# castillo de popa, bultos de carga y barriles
			M.box(root, Vector3(0.64, 0.20, 0.38), Vector3(0, 0.46, -0.58), hull_d)
			M.box(root, Vector3(0.68, 0.04, 0.42), Vector3(0, 0.57, -0.58), deck_m)
			for k in 3:
				M.box(root, Vector3(0.22, 0.18, 0.22), Vector3(-0.17 + k * 0.17, 0.44, 0.52 - (k % 2) * 0.12), hull_m)
			M.cyl(root, 0.08, 0.08, 0.17, Vector3(0.22, 0.43, 0.30), hull_d, 10)
			M.box(root, Vector3(0.025, 0.20, 0.17), Vector3(0, 1.64, -0.04), P.team)
		"galera":
			_hull(root, 2.05, 0.60, 0.30, hull_m, deck_m, 0.26, 0.58)
			_rails(root, 0.27, 0.32, -0.80, 0.70, P.team_d)
			# remos a ambas bandas
			for s in [-1, 1]:
				for k in 9:
					var z := -0.75 + float(k) * 0.19
					var oar := P_.seg(root, Vector3(s * 0.28, 0.32, z), Vector3(s * 0.70, 0.07, z - 0.06), 0.012, hull_d, 4)
					oar.name = "remo"
					M.box(root, Vector3(0.10, 0.012, 0.05), Vector3(s * 0.71, 0.065, z - 0.06), hull_d)
			_mast(root, Vector3(0, 0.30, 0.10), 1.30, hull_d, 0.80, 1.05, hull_d)
			_sail(root, Vector3(0, 0.76, 0.12), 0.74, 0.62, sail_t, 0.09)
			M.box(root, Vector3(0.62, 0.05, 0.03), Vector3(0, 0.46, 0.18), sail_w)
			# espolón a proa y toldilla a popa
			var ram := M.cyl(root, 0.0, 0.05, 0.34, Vector3(0, 0.16, 1.18), P.steel_d, 6)
			ram.rotation_degrees.x = 90.0
			M.box(root, Vector3(0.46, 0.16, 0.34), Vector3(0, 0.40, -0.78), hull_d)
			M.box(root, Vector3(0.50, 0.03, 0.38), Vector3(0, 0.49, -0.78), P.team)
			M.cyl(root, 0.012, 0.012, 0.40, Vector3(0, 0.70, -0.86), hull_d, 5)
			M.box(root, Vector3(0.02, 0.12, 0.20), Vector3(0, 0.84, -0.96), P.team)
		"galeon":
			_hull(root, 2.05, 0.82, 0.38, hull_m, deck_m, 0.20, 0.78)
			_rails(root, 0.36, 0.40, -0.80, 0.70, P.team_d)
			# franja de cañoneras
			for s in [-1, 1]:
				for k in 5:
					M.box(root, Vector3(0.02, 0.07, 0.10), Vector3(s * 0.40 * (1.0 - 0.0), 0.28, -0.60 + k * 0.30), P.black)
					M.box(root, Vector3(0.03, 0.025, 0.12), Vector3(s * 0.405, 0.325, -0.60 + k * 0.30), P.gold)
			# tres palos con velas
			_mast(root, Vector3(0, 0.38, 0.42), 1.40, hull_d, 0.62, 1.12, hull_d)
			_sail(root, Vector3(0, 0.84, 0.44), 0.58, 0.56, sail_w, 0.09)
			M.box(root, Vector3(0.60, 0.12, 0.03), Vector3(0, 0.66, 0.50), sail_t)
			_mast(root, Vector3(0, 0.38, -0.06), 1.80, hull_d, 0.78, 1.46, hull_d)
			_sail(root, Vector3(0, 1.04, -0.04), 0.74, 0.72, sail_w, 0.10)
			M.box(root, Vector3(0.76, 0.16, 0.03), Vector3(0, 0.80, 0.04), sail_t)
			_mast(root, Vector3(0, 0.66, -0.66), 1.00, hull_d)
			M.box(root, Vector3(0.02, 0.50, 0.40), Vector3(0, 1.02, -0.88), sail_w).rotation_degrees.x = -12.0
			# castillo de popa alto y de proa bajo, bauprés
			M.box(root, Vector3(0.74, 0.30, 0.48), Vector3(0, 0.52, -0.74), hull_d)
			M.box(root, Vector3(0.78, 0.04, 0.52), Vector3(0, 0.68, -0.74), deck_m)
			M.box(root, Vector3(0.70, 0.07, 0.46), Vector3(0, 0.45, -0.74), P.gold)
			M.box(root, Vector3(0.56, 0.18, 0.30), Vector3(0, 0.46, 0.80), hull_d)
			var spr := M.cyl(root, 0.015, 0.025, 0.55, Vector3(0, 0.52, 1.28), hull_d, 6)
			spr.rotation_degrees.x = 75.0
			M.box(root, Vector3(0.02, 0.14, 0.22), Vector3(0, 1.54, 0.42), P.team)
	return root

# ------------------------------------------------------------------ animales

static func _leg(parent: Node3D, pos: Vector3, up_len: float, lo_len: float, r: float, ph: float, off: float, front: bool, coat: Material, hoof: Material) -> void:
	var hip := Node3D.new()
	hip.position = pos
	parent.add_child(hip)
	var a := 0.0
	var kn := 8.0
	if ph >= 0.0:
		var arg := (ph + off) * TAU
		a = sin(arg) * 26.0
		kn = 8.0 + maxf(0.0, cos(arg)) * 40.0
	hip.rotation_degrees.x = a
	M.cyl(hip, r * 0.7, r, up_len, Vector3(0, -up_len * 0.5, 0), coat, 8)
	var knee := Node3D.new()
	knee.position = Vector3(0, -up_len, 0)
	knee.rotation_degrees.x = kn * (1.0 if front else -1.0)
	hip.add_child(knee)
	M.cyl(knee, r * 0.5, r * 0.7, lo_len, Vector3(0, -lo_len * 0.5, 0), coat, 8)
	M.box(knee, Vector3(r * 1.3, 0.045, r * 1.6), Vector3(0, -lo_len, 0.008), hoof)

static func ciervo(key: String) -> Node3D:
	var root := Node3D.new()
	var ph := P_._walk_phase(key)
	var coat := M.fmat(Color(0.62, 0.44, 0.26), 0.9, 0.15)
	var belly := M.fmat(Color(0.86, 0.76, 0.58), 0.9, 0.1)
	var dark := M.fmat(Color(0.20, 0.14, 0.10), 0.8, 0.2)
	var antler := M.fmat(Color(0.76, 0.68, 0.52), 0.8, 0.2)
	var spots := M.fmat(Color(0.88, 0.80, 0.66), 0.9, 0.1)
	var bob := 0.0 if ph < 0.0 else absf(sin(ph * TAU)) * 0.012
	var b := Node3D.new()
	b.position = Vector3(0, bob, 0)
	root.add_child(b)
	M.ball(b, 0.22, Vector3(0, 0.50, 0.0), coat, Vector3(0.58, 0.78, 1.50))
	M.ball(b, 0.18, Vector3(0, 0.50, -0.20), coat, Vector3(0.80, 0.95, 1.0))
	M.ball(b, 0.15, Vector3(0, 0.40, 0.0), belly, Vector3(0.7, 0.5, 1.5))
	for k in 5:
		M.ball(b, 0.018, Vector3((k % 2 - 0.5) * 0.14, 0.62 + (k % 3) * 0.02, -0.12 + k * 0.08), spots)
	P_.seg(b, Vector3(0, 0.62, 0.26), Vector3(0, 0.88, 0.40), 0.065, coat, 8)
	M.ball(b, 0.075, Vector3(0, 0.93, 0.44), coat, Vector3(0.9, 1.0, 1.15))
	M.ball(b, 0.045, Vector3(0, 0.90, 0.54), coat, Vector3(0.9, 0.9, 1.2))
	M.ball(b, 0.018, Vector3(0, 0.90, 0.585), dark)
	for s in [-1, 1]:
		M.cyl(b, 0.0, 0.03, 0.09, Vector3(s * 0.07, 0.99, 0.40), coat, 5).rotation_degrees.z = -s * 30.0
		# cornamenta con dos puntas
		var a0 := Vector3(s * 0.03, 1.00, 0.42)
		var a1 := Vector3(s * 0.12, 1.20, 0.38)
		P_.seg(b, a0, a1, 0.012, antler, 5)
		P_.seg(b, a1, Vector3(s * 0.10, 1.32, 0.42), 0.010, antler, 5)
		P_.seg(b, a1, Vector3(s * 0.19, 1.28, 0.36), 0.010, antler, 5)
		P_.seg(b, Vector3(s * 0.08, 1.10, 0.40), Vector3(s * 0.13, 1.16, 0.50), 0.010, antler, 5)
	M.box(b, Vector3(0.05, 0.08, 0.04), Vector3(0, 0.62, -0.36), spots)
	var offs := {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75}
	for leg in ["hl", "fl", "hr", "fr"]:
		var front: bool = leg.begins_with("f")
		var side := -1.0 if leg.ends_with("l") else 1.0
		_leg(b, Vector3(side * 0.07, 0.44, 0.22 if front else -0.24), 0.22, 0.26, 0.04, ph, float(offs[leg]), front, coat, dark)
	return root

static func jabali(key: String) -> Node3D:
	var root := Node3D.new()
	var ph := P_._walk_phase(key)
	var coat := M.fmat(Color(0.26, 0.20, 0.16), 1.0, 0.05)
	var coat_l := M.fmat(Color(0.40, 0.32, 0.24), 1.0, 0.05)
	var dark := M.fmat(Color(0.08, 0.06, 0.05), 0.8, 0.2)
	var tusk := M.fmat(Color(0.92, 0.88, 0.76), 0.6, 0.3)
	var bob := 0.0 if ph < 0.0 else absf(sin(ph * TAU * 2.0)) * 0.012
	var b := Node3D.new()
	b.position = Vector3(0, bob, 0)
	root.add_child(b)
	M.ball(b, 0.22, Vector3(0, 0.34, 0.0), coat, Vector3(0.82, 0.85, 1.35))
	M.ball(b, 0.22, Vector3(0, 0.38, 0.14), coat, Vector3(0.90, 0.95, 1.0))
	M.ball(b, 0.17, Vector3(0, 0.32, -0.20), coat, Vector3(0.9, 0.9, 1.0))
	# cresta de cerdas
	for k in 7:
		M.box(b, Vector3(0.03, 0.08, 0.06), Vector3(0, 0.56 - absf(float(k) - 3.0) * 0.012, -0.18 + k * 0.075), coat_l)
	# cabeza, hocico, colmillos, orejas
	M.ball(b, 0.14, Vector3(0, 0.33, 0.36), coat, Vector3(0.9, 0.9, 1.0))
	M.cyl(b, 0.05, 0.075, 0.18, Vector3(0, 0.27, 0.50), coat_l, 8).rotation_degrees.x = 90.0
	M.ball(b, 0.04, Vector3(0, 0.27, 0.59), dark)
	for s in [-1, 1]:
		var tk := M.cyl(b, 0.0, 0.018, 0.12, Vector3(s * 0.06, 0.25, 0.54), tusk, 5)
		tk.rotation_degrees = Vector3(-35.0, 0.0, -s * 18.0)
		M.cyl(b, 0.0, 0.03, 0.08, Vector3(s * 0.08, 0.46, 0.34), coat, 4).rotation_degrees.z = -s * 25.0
		M.ball(b, 0.014, Vector3(s * 0.07, 0.38, 0.47), dark)
	M.cyl(b, 0.012, 0.012, 0.12, Vector3(0, 0.40, -0.36), coat, 5).rotation_degrees.x = 40.0
	var offs := {"hl": 0.0, "fl": 0.25, "hr": 0.5, "fr": 0.75}
	for leg in ["hl", "fl", "hr", "fr"]:
		var front: bool = leg.begins_with("f")
		var side := -1.0 if leg.ends_with("l") else 1.0
		_leg(b, Vector3(side * 0.10, 0.22, 0.20 if front else -0.22), 0.11, 0.12, 0.05, ph, float(offs[leg]), front, coat, dark)
	return root
