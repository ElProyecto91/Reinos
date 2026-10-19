extends RefCounted
## Sarracenos: arquitectura islámica de Oriente Próximo. Muros de adobe y sillar arenoso con terrazas planas y parapetos de
## almenas apuntadas, arcos apuntados y de ojiva, cúpulas bulbosas de azulejo turquesa con luna creciente dorada, minaretes con
## balcón, torres de viento (badgir) en los tejados, celosías (mashrabiya), patios con palmeras, toldos y alfombras del color
## del jugador, y camellos, dhows de vela latina y zocos en lugar de pórticos de tejas.

const A = preload("res://tools/iso/iso_arch.gd")
const M = preload("res://tools/iso/iso_models.gd")
const B = preload("res://tools/iso/iso_build.gd")

func build(type: String, team: Color) -> Node3D:
	return call(type, team) as Node3D

func pal(seed_v: int) -> Dictionary:
	var S := A.plain()
	S["plaster"] = A.mat("plaster", seed_v + 1, Color(0.89, 0.77, 0.56), 1.0)
	S["stone"] = A.mat("stone", seed_v + 2, Color(0.80, 0.67, 0.46), 1.1)
	S["stone_l"] = A.mat("stone", seed_v + 3, Color(0.93, 0.84, 0.64), 1.1)
	S["stone_d"] = A.mat("stone", seed_v + 4, Color(0.62, 0.50, 0.34), 1.1)
	S["wood"] = A.mat("wood", seed_v + 5, Color(0.30, 0.19, 0.11), 1.4)
	S["wood_l"] = A.mat("wood", seed_v + 6, Color(0.55, 0.40, 0.22), 1.6)
	S["dome"] = A.mat("tiles", seed_v + 7, Color(0.10, 0.42, 0.50), 1.6, Color(0.24, 0.66, 0.64))
	S["dome_d"] = A.mat("tiles", seed_v + 8, Color(0.08, 0.30, 0.40), 1.6, Color(0.18, 0.50, 0.52))
	S["camel"] = M.fmat(Color(0.74, 0.56, 0.34), 0.95, 0.1)
	S["carpet_r"] = M.fmat(Color(0.62, 0.14, 0.12), 0.95, 0.1)
	S["carpet_b"] = M.fmat(Color(0.14, 0.26, 0.52), 0.95, 0.1)
	var F := A.fort(seed_v + 20, Color(0.84, 0.72, 0.52), Color(0.62, 0.50, 0.34), Color(0.94, 0.85, 0.66), Color(0.12, 0.48, 0.50), Color(0.30, 0.19, 0.11), "plaster")
	S["F"] = F
	return S

func _tm(team: Color) -> StandardMaterial3D:
	return M.fmat(team, 0.85, 0.2)

func _win(root: Node3D, S: Dictionary, pos: Vector3, w: float, h: float, face_x: bool) -> void:
	A.arch_hole(root, pos, w, h, face_x, S.glass, S.stone_l, "pointed", 0.04)

## Celosía de madera (mashrabiya): ventana con retícula de listones.
func _lattice(root: Node3D, S: Dictionary, pos: Vector3, w: float, h: float, face_x: bool) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = 90.0 if face_x else 0.0
	root.add_child(holder)
	M.box(holder, Vector3(w + 0.06, h + 0.06, 0.05), Vector3(0, h * 0.5, 0.01), S.wood)
	M.box(holder, Vector3(w, h, 0.06), Vector3(0, h * 0.5, 0.015), S.dark)
	var n := maxi(2, int(w / 0.07))
	for i in n:
		M.box(holder, Vector3(0.018, h, 0.04), Vector3(-w * 0.5 + w * (float(i) + 0.5) / float(n), h * 0.5, 0.04), S.wood_l)
	var m2 := maxi(2, int(h / 0.07))
	for j in m2:
		M.box(holder, Vector3(w, 0.018, 0.04), Vector3(0, h * (float(j) + 0.5) / float(m2), 0.045), S.wood_l)

## Terraza plana con parapeto bajo en el borde del rectángulo w × d centrado en c, a altura y.
func _roof(root: Node3D, S: Dictionary, c: Vector3, w: float, d: float, y: float, pointed: bool = false) -> void:
	M.box(root, Vector3(w + 0.10, 0.07, d + 0.10), c + Vector3(0, y + 0.035, 0), S.stone_l)
	M.box(root, Vector3(w - 0.04, 0.02, d - 0.04), c + Vector3(0, y + 0.075, 0), S.stone_d)
	if pointed:
		var crown := Node3D.new()
		crown.position = c
		root.add_child(crown)
		A._rim_pointed(crown, w * 0.5 + 0.01, d * 0.5 + 0.01, y + 0.07, S.stone_l, 0.26)
	else:
		M.box(root, Vector3(w + 0.10, 0.10, 0.06), c + Vector3(0, y + 0.12, d * 0.5 + 0.02), S.stone_l)
		M.box(root, Vector3(0.06, 0.10, d + 0.10), c + Vector3(w * 0.5 + 0.02, y + 0.12, 0), S.stone_l)
		M.box(root, Vector3(w + 0.10, 0.10, 0.06), c + Vector3(0, y + 0.12, -d * 0.5 - 0.02), S.stone_l)
		M.box(root, Vector3(0.06, 0.10, d + 0.10), c + Vector3(-w * 0.5 - 0.02, y + 0.12, 0), S.stone_l)

## Cuerpo de adobe con zócalo: devuelve la y de la azotea.
func _body(root: Node3D, S: Dictionary, c: Vector3, w: float, d: float, h: float, m: Material = null) -> float:
	var mm: Material = m if m != null else S.plaster
	M.box(root, Vector3(w + 0.10, 0.12, d + 0.10), c + Vector3(0, 0.06, 0), S.stone_d)
	M.box(root, Vector3(w, h, d), c + Vector3(0, 0.12 + h * 0.5, 0), mm)
	return 0.12 + h

## Cúpula bulbosa de azulejo con luna creciente dorada.
func _onion(root: Node3D, S: Dictionary, pos: Vector3, r: float, h: float, m: Material, crescent: bool = true) -> void:
	A.lathe(root, A.onion_prof(r, h), 16, pos, m)
	if crescent:
		A.crescent_fin(root, pos + Vector3(0, h - 0.01, 0), 0.07 + r * 0.12, S.gold)

## Torre de viento (badgir): cuerpo cuadrado con ranuras y tejadillo.
func _badgir(root: Node3D, S: Dictionary, pos: Vector3, h: float) -> void:
	M.box(root, Vector3(0.26, h, 0.26), pos + Vector3(0, h * 0.5, 0), S.plaster)
	for k in 2:
		A.arch_hole(root, pos + Vector3(0, h * 0.30 + k * h * 0.34, 0.132), 0.10, h * 0.16, false, S.dark, null, "pointed", 0.0)
		A.arch_hole(root, pos + Vector3(0.132, h * 0.30 + k * h * 0.34, 0), 0.10, h * 0.16, true, S.dark, null, "pointed", 0.0)
	M.box(root, Vector3(0.34, 0.05, 0.34), pos + Vector3(0, h + 0.025, 0), S.stone_l)
	A.pyramid(root, 0.32, 0.12, h + 0.05, S.stone_d, pos)

## Minarete: base cuadrada, fuste octogonal, balcón con parapeto y cuerpo superior con cúpula en punta.
func _minaret(root: Node3D, S: Dictionary, c: Vector3, h: float, team: Color) -> float:
	M.box(root, Vector3(0.34, 0.36, 0.34), c + Vector3(0, 0.18, 0), S.stone)
	M.cyl(root, 0.13, 0.15, h, c + Vector3(0, 0.36 + h * 0.5, 0), S.plaster, 8)
	var yb := 0.36 + h
	M.cyl(root, 0.22, 0.17, 0.12, c + Vector3(0, yb + 0.02, 0), S.stone_l, 8)
	M.cyl(root, 0.22, 0.22, 0.08, c + Vector3(0, yb + 0.12, 0), S.stone, 8)
	for k in 8:
		var a := TAU * float(k) / 8.0
		M.cyl(root, 0.012, 0.012, 0.10, c + Vector3(cos(a) * 0.20, yb + 0.20, sin(a) * 0.20), S.stone_l, 5)
	M.cyl(root, 0.20, 0.20, 0.02, c + Vector3(0, yb + 0.25, 0), S.stone_l, 8)
	M.cyl(root, 0.09, 0.10, 0.30, c + Vector3(0, yb + 0.39, 0), S.plaster, 8)
	A.cone(root, 0.13, 0.30, yb + 0.54, S.dome, c, 8)
	A.crescent_fin(root, c + Vector3(0, yb + 0.83, 0), 0.07, S.gold)
	A.arch_hole(root, c + Vector3(0, 0.45, 0.145), 0.10, 0.20, false, S.dark, null, "pointed", 0.0)
	return yb + 0.95

## Camello: cuerpo, joroba, cuello y cabeza, cuatro patas (mira a +x).
func _camel(root: Node3D, S: Dictionary, pos: Vector3, yaw: float = 0.0, s: float = 1.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = yaw
	holder.scale = Vector3.ONE * s
	root.add_child(holder)
	M.ball(holder, 0.15, Vector3(0, 0.34, 0), S.camel, Vector3(1.9, 0.85, 0.8))
	M.ball(holder, 0.075, Vector3(0.02, 0.50, 0), S.camel, Vector3(1.0, 1.0, 0.9))
	for sx in [-0.17, 0.17]:
		for sz in [-0.06, 0.06]:
			M.cyl(holder, 0.018, 0.022, 0.26, Vector3(sx, 0.13, sz), S.camel, 6)
	var neck := M.cyl(holder, 0.03, 0.045, 0.30, Vector3(0.28, 0.50, 0), S.camel, 6)
	neck.rotation_degrees.z = -30.0
	M.ball(holder, 0.04, Vector3(0.38, 0.64, 0), S.camel, Vector3(1.6, 0.9, 0.9))
	M.box(holder, Vector3(0.18, 0.03, 0.16), Vector3(0.0, 0.43, 0), S.carpet_r)

# ------------------------------------------------------------------ casa 2x2: casa de terraza con cúpula y celosía

func casa(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(11)
	var w := 1.36
	var d := 1.20
	var c := Vector3(0.0, 0, -0.10)
	var yr := _body(root, S, c, w, d, 0.80)
	_roof(root, S, c, w, d, yr)
	# cuerpo alto lateral con cúpula bulbosa pequeña
	var yr2 := _body(root, S, c + Vector3(-0.32, 0, -0.20), 0.58, 0.56, 1.20)
	M.box(root, Vector3(0.62, 0.07, 0.60), c + Vector3(-0.32, yr2 + 0.035, -0.20), S.stone_l)
	_onion(root, S, c + Vector3(-0.32, yr2 + 0.07, -0.20), 0.22, 0.38, S.dome)
	var zf := c.z + d * 0.5 + 0.005
	A.arch_hole(root, Vector3(0.22, 0.12, zf), 0.30, 0.34, false, S.wood, S.stone_l, "pointed", 0.05)
	_lattice(root, S, Vector3(-0.34, 0.40, zf), 0.30, 0.26, false)
	_lattice(root, S, Vector3(w * 0.5 + 0.005, 0.44, c.z + 0.10), 0.26, 0.28, true)
	M.box(root, Vector3(0.40, 0.04, 0.30), Vector3(0.22, 0.74, zf + 0.15), _tm(team)).rotation_degrees.x = 14.0
	M.box(root, Vector3(0.04, 0.60, 0.04), Vector3(0.40, 0.42, zf + 0.30), S.wood)
	M.box(root, Vector3(0.04, 0.60, 0.04), Vector3(0.04, 0.42, zf + 0.30), S.wood)
	A.jar(root, Vector3(0.78, 0.0, 0.62), S.clay)
	A.palm(root, Vector3(-0.85, 0.0, 0.78), 0.85, S)
	B.banner(root, Vector3(w * 0.5 + 0.06, 0.82, c.z - 0.28), team, true, 0.14, 0.34)
	return root

# ------------------------------------------------------------------ almacén 2x2: depósito con torre de viento

func almacen(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(101)
	var w := 1.46
	var d := 1.30
	var yr := _body(root, S, Vector3.ZERO, w, d, 0.82)
	_roof(root, S, Vector3.ZERO, w, d, yr, true)
	_badgir(root, S, Vector3(0.42, yr + 0.07, -0.30), 0.62)
	var zf := d * 0.5 + 0.005
	A.arch_hole(root, Vector3(-0.20, 0.12, zf), 0.60, 0.38, false, S.dark, S.stone_l, "pointed", 0.06)
	for sx in [-1, 1]:
		M.box(root, Vector3(0.26, 0.46, 0.04), Vector3(-0.20 + sx * 0.17, 0.36, zf + 0.04), S.wood).rotation_degrees.y = float(sx) * 38.0
	_lattice(root, S, Vector3(0.46, 0.46, zf), 0.24, 0.24, false)
	_lattice(root, S, Vector3(w * 0.5 + 0.005, 0.46, 0.12), 0.24, 0.24, true)
	for k in 3:
		A.jar(root, Vector3(0.72 + k * 0.17, 0.0, 0.86 - (k % 2) * 0.14), S.clay, 0.10)
	B.sack(root, Vector3(-0.82, 0.0, 0.84), S)
	B.sack(root, Vector3(-0.98, 0.0, 0.70), S, 0.10)
	B.banner(root, Vector3(0.52, 0.86, zf + 0.04), team, false, 0.16, 0.40)
	return root

# ------------------------------------------------------------------ cuartel 3x3: ribat fortificado

func cuartel(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(201)
	var F: Dictionary = S.F
	var c := Vector3(-0.30, 0, -0.35)
	var w := 2.10
	var d := 1.50
	var yr := _body(root, S, c, w, d, 1.00)
	_roof(root, S, c, w, d, yr, true)
	var zf := c.z + d * 0.5 + 0.005
	# gran iwán de ingreso: portal alto en arco apuntado con nicho escalonado (mocárabes)
	M.box(root, Vector3(0.80, 1.12, 0.14), Vector3(c.x - 0.30, 0.68, zf + 0.06), S.stone_l)
	A.arch_hole(root, Vector3(c.x - 0.30, 0.12, zf + 0.14), 0.54, 0.56, false, S.dark, S.stone_d, "pointed", 0.06)
	for k in 3:
		A.arch_hole(root, Vector3(c.x - 0.30, 0.74 + k * 0.10, zf + 0.15), 0.36 - k * 0.09, 0.08, false, S.stone, null, "pointed", 0.0)
	for wx in [0.45, 0.80]:
		_lattice(root, S, Vector3(c.x + wx, 0.52, zf), 0.20, 0.34, false)
	for wz in [-0.50, 0.15]:
		_lattice(root, S, Vector3(c.x + w * 0.5 + 0.005, 0.52, c.z + wz), 0.20, 0.34, true)
	# torres cuadradas de esquina con almenas apuntadas
	for sx in [-1, 1]:
		var top := A.tower_sq(root, Vector3(c.x + sx * 1.02, 0, c.z + 0.78), 0.62, 1.60, F, {"pointed": true})
		M._flag(root, Vector3(c.x + sx * 1.02, top, c.z + 0.78), team, 0.5)
	A.shield(root, Vector3(c.x - 0.30, 1.10, zf + 0.22), 0.14, false, S.gold, _tm(team))
	B.banner(root, Vector3(c.x + 0.50, 1.02, zf + 0.04), team, false, 0.18, 0.46)
	A.drill_yard(root, S, 1.20, 1.46)
	return root

# ------------------------------------------------------------------ arquería 3x3: galería de tiro con toldo

func arqueria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(301)
	var c := Vector3(-0.40, 0, -0.45)
	var w := 1.90
	var d := 1.30
	var yr := _body(root, S, c, w, d, 0.78)
	_roof(root, S, c, w, d, yr)
	var zf := c.z + d * 0.5 + 0.005
	A.arcade(root, Vector3(c.x - 0.15, 0.12, zf + 0.12), true, 3, 0.50, 0.46, S.stone_l, S.dark, "pointed")
	_lattice(root, S, Vector3(c.x + 0.62, 0.46, zf), 0.22, 0.28, false)
	for wz in [-0.30, 0.20]:
		_lattice(root, S, Vector3(c.x + w * 0.5 + 0.005, 0.46, c.z + wz), 0.20, 0.30, true)
	_onion(root, S, c + Vector3(0.55, yr + 0.07, -0.30), 0.18, 0.32, S.dome)
	M.box(root, Vector3(1.40, 0.04, 0.36), Vector3(c.x - 0.15, 0.58, zf + 0.34), _tm(team)).rotation_degrees.x = 12.0
	A.archery_field(root, S, _tm(team))
	return root

# ------------------------------------------------------------------ establo 3x3: caravasar con camellos

func establo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(401)
	var c := Vector3(-0.20, 0, -0.45)
	var w := 2.10
	var d := 1.30
	var yr := _body(root, S, c, w, d, 0.82)
	_roof(root, S, c, w, d, yr, true)
	var zf := c.z + d * 0.5 + 0.005
	for sx in [-0.55, 0.30]:
		A.arch_hole(root, Vector3(c.x + sx, 0.12, zf), 0.46, 0.38, false, S.dark, S.stone_l, "pointed", 0.06)
		M.box(root, Vector3(0.025, 0.40, 0.03), Vector3(c.x + sx, 0.34, zf + 0.04), S.wood)
	_lattice(root, S, Vector3(c.x + 0.90, 0.46, zf), 0.20, 0.26, false)
	_badgir(root, S, c + Vector3(-0.50, yr + 0.07, -0.30), 0.50)
	_camel(root, S, Vector3(0.90, 0.0, 0.95), 0.0)
	_camel(root, S, Vector3(0.40, 0.0, 1.20), 25.0, 0.9)
	A.corral(root, S)
	B.banner(root, Vector3(c.x + 0.62, 0.86, zf + 0.04), team, false, 0.16, 0.38)
	return root

# ------------------------------------------------------------------ taller de asedio 3x3

func taller(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(501)
	var c := Vector3(-0.30, 0, -0.40)
	var w := 1.80
	var d := 1.40
	var yr := _body(root, S, c, w, d, 0.90)
	_roof(root, S, c, w, d, yr, true)
	var zf := c.z + d * 0.5 + 0.005
	A.arch_hole(root, Vector3(c.x - 0.30, 0.12, zf), 0.74, 0.46, false, S.dark, S.stone_l, "pointed", 0.06)
	for y in [0.32, 0.58]:
		M.box(root, Vector3(0.74, 0.04, 0.05), Vector3(c.x - 0.30, y, zf + 0.04), S.iron)
	_lattice(root, S, Vector3(c.x + 0.55, 0.50, zf), 0.22, 0.30, false)
	# horno-cúpula
	var kc := Vector3(c.x + w * 0.5 + 0.28, 0, c.z - 0.20)
	M.cyl(root, 0.30, 0.34, 0.50, kc + Vector3(0, 0.25, 0), S.plaster, 14)
	A.lathe(root, A.onion_prof(0.32, 0.36), 12, kc + Vector3(0, 0.50, 0), S.dome_d)
	A.arch_hole(root, kc + Vector3(0.0, 0.0, 0.34), 0.22, 0.20, false, S.dark, S.stone_l, "pointed", 0.04)
	M.box(root, Vector3(0.16, 0.12, 0.03), kc + Vector3(0.0, 0.12, 0.35), S.fire)
	A.siege_yard(root, S)
	B.banner(root, Vector3(c.x + 0.62, 0.94, zf + 0.04), team, false, 0.16, 0.40)
	return root

# ------------------------------------------------------------------ puerto 3x3: almacén y dhow de vela latina

func puerto(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(601)
	var c := Vector3(-0.30, 0, -0.55)
	var w := 1.60
	var d := 1.10
	var yr := _body(root, S, c, w, d, 0.74)
	_roof(root, S, c, w, d, yr)
	_onion(root, S, c + Vector3(-0.40, yr + 0.07, -0.10), 0.22, 0.40, S.dome)
	var zf := c.z + d * 0.5 + 0.005
	A.arcade(root, Vector3(c.x, 0.12, zf + 0.12), true, 3, 0.50, 0.42, S.stone_l, S.dark, "pointed")
	_lattice(root, S, Vector3(c.x + 0.52, 0.46, zf), 0.20, 0.26, false)
	A.pier(root, S)
	# dhow amarrado: casco a lo largo de x con proa alta y vela latina del color del jugador
	var sp := Vector3(0.05, 0.0, 1.62)
	var pts := PackedVector2Array([Vector2(0.95, 0.12), Vector2(0.60, 0.0), Vector2(-0.70, 0.0), Vector2(-0.88, 0.14), Vector2(-0.70, 0.20), Vector2(0.60, 0.20)])
	var hull := Node3D.new()
	hull.position = sp + Vector3(0, 0.10, 0)
	root.add_child(hull)
	A.extrude(hull, PackedVector2Array([Vector2(1.00, 0.30), Vector2(0.70, 0.04), Vector2(-0.62, 0.0), Vector2(-0.92, 0.16), Vector2(-0.70, 0.10), Vector2(0.62, 0.14)]), 0.30, Vector3.ZERO, S.wood)
	M.box(root, Vector3(1.50, 0.05, 0.28), sp + Vector3(0.02, 0.28, 0), S.wood_l)
	M.cyl(root, 0.022, 0.03, 0.95, sp + Vector3(0.10, 0.70, 0), S.wood, 8)
	var sail := Node3D.new()
	sail.position = sp + Vector3(0.10, 0.34, 0.03)
	root.add_child(sail)
	A.extrude(sail, PackedVector2Array([Vector2(-0.62, 0.0), Vector2(0.55, 0.0), Vector2(0.05, 0.95)]), 0.02, Vector3.ZERO, _tm(team))
	var yard := M.box(root, Vector3(1.30, 0.03, 0.03), sp + Vector3(-0.02, 0.56, 0.04), S.wood)
	yard.rotation_degrees.z = 36.0
	for sx in [0.2, 0.55]:
		A.jar(root, Vector3(sx - 0.20, 0.08, 1.12), S.clay, 0.09)
	B.banner(root, Vector3(c.x + 0.62, 0.84, zf + 0.04), team, false, 0.16, 0.40)
	return root

# ------------------------------------------------------------------ torre 2x2: torre de vigía con minarete

func torre(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(210)
	var F: Dictionary = S.F
	var top := A.tower_sq(root, Vector3.ZERO, 1.20, 2.50, F, {"pointed": true, "door": true})
	A.arch_hole(root, Vector3(0.0, 0.22, 0.60 + 0.005), 0.26, 0.30, false, S.wood, S.stone_l, "pointed", 0.04)
	_lattice(root, S, Vector3(0.0, 1.20, 0.60 + 0.01), 0.20, 0.30, false)
	_lattice(root, S, Vector3(0.60 + 0.01, 1.20, 0.0), 0.20, 0.30, true)
	_onion(root, S, Vector3(-0.34, top - 0.02, -0.34), 0.20, 0.34, S.dome)
	A.shield(root, Vector3(0.0, 1.80, 0.64), 0.14, false, S.gold, _tm(team))
	M._flag(root, Vector3(0.30, top, 0.28), team, 0.62)
	return root

# ------------------------------------------------------------------ monasterio 3x3: mezquita con minarete

func monasterio(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(701)
	var c := Vector3(-0.10, 0, -0.10)
	var w := 1.90
	var d := 1.90
	var yr := _body(root, S, c, w, d, 1.00)
	_roof(root, S, c, w, d, yr)
	# gran cúpula bulbosa sobre tambor con ventanas, y cuatro cupulillas en las esquinas
	M.cyl(root, 0.52, 0.55, 0.42, c + Vector3(0, yr + 0.07 + 0.21, 0), S.plaster, 16)
	for k in 8:
		var piv := Node3D.new()
		piv.position = c + Vector3(0, yr + 0.20, 0)
		piv.rotation.y = TAU * float(k) / 8.0
		root.add_child(piv)
		A.arch_hole(piv, Vector3(0, 0, 0.535), 0.12, 0.20, false, S.glass, S.stone_l, "pointed", 0.02)
	_onion(root, S, c + Vector3(0, yr + 0.49, 0), 0.56, 0.78, S.dome)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var dc := c + Vector3(sx * 0.70, yr + 0.07, sz * 0.70)
			M.cyl(root, 0.17, 0.18, 0.12, dc + Vector3(0, 0.06, 0), S.plaster, 10)
			_onion(root, S, dc + Vector3(0, 0.12, 0), 0.19, 0.30, S.dome_d)
	# fachada: iwán con arcos apuntados y ventanas con celosía
	var zf := c.z + d * 0.5 + 0.005
	M.box(root, Vector3(0.80, 1.16, 0.14), Vector3(c.x, 0.70, zf + 0.06), S.stone_l)
	A.arch_hole(root, Vector3(c.x, 0.12, zf + 0.14), 0.52, 0.58, false, S.dark, S.stone_d, "pointed", 0.06)
	for k in 3:
		A.arch_hole(root, Vector3(c.x, 0.76 + k * 0.10, zf + 0.15), 0.34 - k * 0.09, 0.08, false, S.stone, null, "pointed", 0.0)
	for sx in [-0.62, 0.62]:
		_lattice(root, S, Vector3(c.x + sx, 0.56, zf), 0.20, 0.40, false)
	for wz in [-0.55, 0.05, 0.60]:
		_lattice(root, S, Vector3(c.x + w * 0.5 + 0.005, 0.56, c.z + wz), 0.20, 0.40, true)
	# minarete en la esquina trasera derecha
	var mt := _minaret(root, S, Vector3(c.x + 0.95, 0, c.z - 0.95), 1.50, team)
	M._flag(root, Vector3(c.x + 0.95, mt, c.z - 0.95), team, 0.45)
	B.banner(root, Vector3(c.x - 0.45, 0.96, zf + 0.04), team, false, 0.18, 0.50)
	B.banner(root, Vector3(c.x + 0.45, 0.96, zf + 0.04), team, false, 0.18, 0.50)
	A.palm(root, Vector3(-1.10, 0.0, 1.00), 0.90, S)
	return root

# ------------------------------------------------------------------ castillo 4x4: ciudadela

func castillo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(110)
	var F: Dictionary = S.F
	M.box(root, Vector3(3.5, 0.06, 3.5), Vector3(0, 0.03, 0), A.mat("plaster", 119, Color(0.70, 0.58, 0.38), 1.2))
	var wh := 1.30
	A.wall_block(root, F, 3.0, wh, 0.50, Vector3(0, 0, -1.55), true)
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(-1.55, 0, 0), true)
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(1.55, 0, 0), true)
	A.wall_block(root, F, 1.05, wh, 0.50, Vector3(-0.975, 0, 1.55), true)
	A.wall_block(root, F, 1.05, wh, 0.50, Vector3(0.975, 0, 1.55), true)
	# puerta acodada: arco apuntado entre dos torres cuadradas con almenas apuntadas
	M.box(root, Vector3(0.90, 0.38, 0.52), Vector3(0, wh - 0.19, 1.55), F.wall)
	M.box(root, Vector3(0.94, 0.05, 0.56), Vector3(0, wh + 0.025, 1.55), F.light)
	M.box(root, Vector3(0.90, 0.92, 0.30), Vector3(0, 0.46, 1.50), F.slit)
	A.arch_hole(root, Vector3(0, 0.0, 1.805), 0.58, 0.50, false, S.dark, S.stone_l, "pointed", 0.07)
	for k in 5:
		M.box(root, Vector3(0.025, 0.76, 0.03), Vector3(-0.20 + k * 0.10, 0.38, 1.83), S.iron)
	for sx in [-1, 1]:
		A.tower_sq(root, Vector3(sx * 0.70, 0, 1.78), 0.50, 1.70, F, {"pointed": true})
	# cuatro torres cuadradas de esquina con almenas apuntadas y cúpulas bulbosas en las esquinas interiores
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var top := A.tower_sq(root, Vector3(sx * 1.55, 0, sz * 1.55), 1.05, 2.30, F, {"pointed": true})
			_onion(root, S, Vector3(sx * 1.55 - sx * 0.22, top, sz * 1.55 - sz * 0.22), 0.20, 0.34, S.dome_d, false)
	# palacio interior: gran cuerpo con iwán, cúpula bulbosa y minarete
	var kc := Vector3(0.0, 0, -0.30)
	M.box(root, Vector3(1.90, 0.20, 1.70), kc + Vector3(0, 0.10, 0), F.dark)
	M.box(root, Vector3(1.76, 1.70, 1.56), kc + Vector3(0, 1.05, 0), F.wall)
	M.box(root, Vector3(1.94, 0.10, 1.74), kc + Vector3(0, 1.95, 0), S.stone_l)
	var crown := Node3D.new()
	crown.position = kc
	root.add_child(crown)
	A._rim_pointed(crown, 0.96, 0.85, 2.0, S.stone_l, 0.26)
	M.cyl(root, 0.50, 0.53, 0.40, kc + Vector3(0, 2.20, 0), S.plaster, 16)
	_onion(root, S, kc + Vector3(0, 2.40, 0), 0.54, 0.80, S.dome)
	var zf := kc.z + 0.78
	M.box(root, Vector3(0.70, 1.20, 0.12), kc + Vector3(0, 0.80, 0.80), S.stone_l)
	A.arch_hole(root, Vector3(0, 0.20, zf + 0.12), 0.44, 0.60, false, S.dark, S.stone_d, "pointed", 0.06)
	for wx in [-0.55, 0.55]:
		_lattice(root, S, kc + Vector3(wx, 0.86, 0.785), 0.20, 0.36, false)
		_lattice(root, S, kc + Vector3(wx, 1.40, 0.785), 0.18, 0.26, false)
	for wz in [-0.40, 0.30]:
		_lattice(root, S, kc + Vector3(0.885, 0.86, wz), 0.18, 0.36, true)
		_lattice(root, S, kc + Vector3(0.885, 1.40, wz), 0.16, 0.26, true)
	var mt := _minaret(root, S, kc + Vector3(0.72, 0, -0.60), 1.30, team)
	M._flag(root, kc + Vector3(0.72, mt, -0.60), team, 0.5)
	B.banner(root, kc + Vector3(0.55, 1.25, 0.84), team, false, 0.24, 0.70)
	B.banner(root, kc + Vector3(-0.55, 1.25, 0.84), team, false, 0.24, 0.70)
	return root

# ------------------------------------------------------------------ herrería 3x3

func herreria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(801)
	var c := Vector3(-0.20, 0, -0.40)
	var w := 1.80
	var d := 1.40
	var yr := _body(root, S, c, w, d, 0.82)
	_roof(root, S, c, w, d, yr)
	# chimenea de adobe y torre de viento
	M.box(root, Vector3(0.40, 1.10, 0.40), c + Vector3(w * 0.5 + 0.18, 0.55, -0.30), S.plaster)
	M.box(root, Vector3(0.50, 0.06, 0.50), c + Vector3(w * 0.5 + 0.18, 1.12, -0.30), S.stone_l)
	A.pyramid(root, 0.46, 0.18, 1.15, S.stone_d, c + Vector3(w * 0.5 + 0.18, 0, -0.30))
	A.smoke_src(root, c + Vector3(w * 0.5 + 0.18, 1.40, -0.30))
	M.box(root, Vector3(0.10, 0.26, 0.30), c + Vector3(w * 0.5 + 0.42, 0.34, -0.30), S.dark)
	M.box(root, Vector3(0.12, 0.20, 0.22), c + Vector3(w * 0.5 + 0.43, 0.34, -0.30), S.fire)
	var zf := c.z + d * 0.5 + 0.005
	A.arch_hole(root, Vector3(c.x - 0.30, 0.12, zf), 0.74, 0.42, false, S.dark, S.stone_l, "pointed", 0.06)
	M.box(root, Vector3(0.20, 0.20, 0.03), Vector3(c.x - 0.50, 0.28, zf + 0.04), S.fire)
	_lattice(root, S, Vector3(c.x + 0.50, 0.50, zf), 0.22, 0.28, false)
	M.box(root, Vector3(0.80, 0.04, 0.34), Vector3(c.x + 0.45, 0.64, zf + 0.18), _tm(team)).rotation_degrees.x = 12.0
	A.forge_yard(root, S)
	return root

# ------------------------------------------------------------------ mercado 3x3: zoco con toldos y fuente

func mercado(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(901)
	var tm := _tm(team)
	M.box(root, Vector3(2.70, 0.10, 2.70), Vector3(0, 0.05, 0), S.stone_l)
	M.box(root, Vector3(2.50, 0.04, 2.50), Vector3(0, 0.12, 0), S.stone)
	# nave de puestos al fondo con arcada apuntada y terraza
	var bc := Vector3(0.0, 0, -1.02)
	M.box(root, Vector3(2.40, 0.80, 0.46), bc + Vector3(0, 0.54, -0.06), S.plaster)
	A.arcade(root, Vector3(0.0, 0.14, bc.z + 0.34), true, 5, 0.48, 0.52, S.stone_l, S.dark, "pointed")
	M.box(root, Vector3(2.56, 0.07, 0.62), bc + Vector3(0, 0.99, 0.12), S.stone_l)
	var crown := Node3D.new()
	crown.position = bc + Vector3(0, 0, 0.0)
	root.add_child(crown)
	A._rim_pointed(crown, 1.27, 0.30, 1.03, S.stone_l, 0.26)
	_onion(root, S, bc + Vector3(-0.80, 1.03, -0.10), 0.26, 0.44, S.dome)
	_badgir(root, S, bc + Vector3(0.85, 1.03, -0.08), 0.46)
	# toldos del zoco: tres puestos con paño del color del jugador, listado blanco y alfombras
	for k in 3:
		var sx := -0.85 + k * 0.85
		var cloth: Material = tm if k != 1 else S.cloth_w
		M.box(root, Vector3(0.62, 0.05, 0.50), Vector3(sx, 0.66, 0.30), cloth).rotation_degrees.x = 10.0
		for px in [-0.28, 0.28]:
			M.box(root, Vector3(0.04, 0.54, 0.04), Vector3(sx + px, 0.37, 0.52), S.wood)
		M.box(root, Vector3(0.50, 0.22, 0.26), Vector3(sx, 0.23, 0.20), S.wood_l)
		for j in 3:
			M.ball(root, 0.05, Vector3(sx - 0.14 + j * 0.14, 0.38, 0.20), [S.orange_fruit, S.green_fruit, S.red_fruit][(j + k) % 3] as Material, Vector3(1, 0.9, 1))
	M.box(root, Vector3(0.70, 0.02, 0.50), Vector3(-0.50, 0.14, 1.02), S.carpet_r)
	M.box(root, Vector3(0.70, 0.02, 0.50), Vector3(0.60, 0.14, 1.05), S.carpet_b)
	# fuente de pila octogonal
	M.cyl(root, 0.24, 0.28, 0.14, Vector3(0.05, 0.19, 0.95), S.stone_l, 8)
	M.cyl(root, 0.19, 0.19, 0.04, Vector3(0.05, 0.27, 0.95), S.water, 8)
	M.cyl(root, 0.03, 0.04, 0.30, Vector3(0.05, 0.40, 0.95), S.stone_l, 6)
	M._flag(root, Vector3(-1.10, 0.10, 0.95), team, 1.20)
	A.jar(root, Vector3(1.05, 0.10, 0.55), S.clay)
	A.palm(root, Vector3(1.10, 0.10, 1.10), 0.80, S)
	return root

# ------------------------------------------------------------------ centro urbano 3x3: palacio con patio

func centro(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(21)
	var c := Vector3(-0.10, 0, -0.20)
	var w := 2.10
	var d := 1.80
	var yr := _body(root, S, c, w, d, 1.06)
	_roof(root, S, c, w, d, yr, true)
	# cúpula bulbosa central, torre de viento y dos cupulillas
	M.cyl(root, 0.44, 0.47, 0.34, c + Vector3(0, yr + 0.07 + 0.17, 0), S.plaster, 16)
	_onion(root, S, c + Vector3(0, yr + 0.41, 0), 0.50, 0.72, S.dome)
	for sx in [-1, 1]:
		var dc := c + Vector3(sx * 0.74, yr + 0.07, 0.50)
		M.cyl(root, 0.16, 0.18, 0.12, dc + Vector3(0, 0.06, 0), S.plaster, 10)
		_onion(root, S, dc + Vector3(0, 0.12, 0), 0.18, 0.30, S.dome_d)
	_badgir(root, S, c + Vector3(0.72, yr + 0.07, -0.55), 0.50)
	# iwán de ingreso y ventanas con celosía en dos pisos
	var zf := c.z + d * 0.5 + 0.005
	M.box(root, Vector3(0.86, 1.30, 0.14), Vector3(c.x, 0.77, zf + 0.06), S.stone_l)
	A.arch_hole(root, Vector3(c.x, 0.12, zf + 0.14), 0.56, 0.64, false, S.dark, S.stone_d, "pointed", 0.06)
	for k in 3:
		A.arch_hole(root, Vector3(c.x, 0.84 + k * 0.11, zf + 0.15), 0.38 - k * 0.10, 0.09, false, S.stone, null, "pointed", 0.0)
	for wx in [-0.70, 0.70]:
		_lattice(root, S, Vector3(c.x + wx, 0.50, zf), 0.20, 0.34, false)
		_lattice(root, S, Vector3(c.x + wx, 0.94, zf), 0.18, 0.30, false)
	for wz in [-0.50, 0.0, 0.50]:
		_lattice(root, S, Vector3(c.x + w * 0.5 + 0.005, 0.50, c.z + wz), 0.20, 0.34, true)
		_lattice(root, S, Vector3(c.x + w * 0.5 + 0.005, 0.94, c.z + wz), 0.18, 0.30, true)
	A.shield(root, Vector3(c.x, 1.18, zf + 0.22), 0.16, false, S.gold, _tm(team))
	B.banner(root, Vector3(c.x - 0.52, 1.00, zf + 0.04), team, false, 0.20, 0.54)
	B.banner(root, Vector3(c.x + 0.52, 1.00, zf + 0.04), team, false, 0.20, 0.54)
	var mt := _minaret(root, S, Vector3(c.x + 0.98, 0, c.z - 0.95), 1.45, team)
	M._flag(root, Vector3(c.x + 0.98, mt, c.z - 0.95), team, 0.5)
	A.palm(root, Vector3(-1.20, 0.0, 1.15), 0.90, S)
	A.palm(root, Vector3(1.20, 0.0, 1.20), 0.80, S)
	return root

# ------------------------------------------------------------------ murallas: adobe con almenas apuntadas

func wall_post() -> Node3D:
	return A.wall_post(pal(250).F, true)

func wall_arm(d: int) -> Node3D:
	return A.wall_arm(d, pal(250).F, true)

func gate(along_x: bool) -> Node3D:
	var S := pal(260)
	return A.wall_gate(along_x, S.F, S.wood, "pointed", true)
