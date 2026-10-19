extends RefCounted
## Castellanos: arquitectura castellana y mudéjar. Arenisca dorada y encalado blanco, tejas curvas de barro cocido en tejados
## de poca pendiente, esquinas de sillería, arcos de medio punto y de herradura, soportales, espadañas, garitas en las torres,
## cipreses y tinajas. El color del jugador va en toldos, estandartes y banderas.

const A = preload("res://tools/iso/iso_arch.gd")
const M = preload("res://tools/iso/iso_models.gd")
const B = preload("res://tools/iso/iso_build.gd")

func build(type: String, team: Color) -> Node3D:
	return call(type, team) as Node3D

func pal(seed_v: int) -> Dictionary:
	var S := A.plain()
	S["stone"] = A.mat("stone", seed_v, Color(0.80, 0.68, 0.46), 1.1)
	S["stone_d"] = A.mat("stone", seed_v + 1, Color(0.62, 0.50, 0.34), 1.1)
	S["stone_l"] = A.mat("stone", seed_v + 2, Color(0.90, 0.80, 0.60), 1.1)
	S["plaster"] = A.mat("plaster", seed_v + 3, Color(0.95, 0.92, 0.82), 1.0)
	S["brick"] = A.mat("brick", seed_v + 4, Color(0.68, 0.36, 0.24), 1.1)
	S["wood"] = A.mat("wood", seed_v + 5, Color(0.30, 0.19, 0.10), 1.4)
	S["wood_l"] = A.mat("wood", seed_v + 6, Color(0.58, 0.40, 0.22), 1.6)
	S["wood_r"] = A.mat("wood", seed_v + 7, Color(0.50, 0.22, 0.14), 1.4)
	S["roof"] = A.mat("barrel", seed_v + 8, Color(0.78, 0.40, 0.24), 1.3)
	S["roof_d"] = A.mat("barrel", seed_v + 9, Color(0.62, 0.30, 0.18), 1.3)
	S["F"] = A.fort(seed_v + 20, Color(0.80, 0.68, 0.46), Color(0.60, 0.48, 0.32), Color(0.90, 0.80, 0.60), Color(0.62, 0.34, 0.22), Color(0.34, 0.22, 0.12))
	return S

func _tm(team: Color) -> StandardMaterial3D:
	return M.fmat(team, 0.85, 0.2)

func _awning(root: Node3D, pos: Vector3, w: float, d: float, team: Color, S: Dictionary) -> void:
	A.awning(root, pos, w, d, _tm(team), S)

## Ventana con reja y postigos en la cara +z (face_x = false) o +x.
func _window_reja(root: Node3D, pos: Vector3, w: float, h: float, face_x: bool, S: Dictionary) -> void:
	M._window(root, pos, Vector3(0.03, h, w) if face_x else Vector3(w, h, 0.03), S.wood)
	for k in 3:
		var o := (float(k) - 1.0) * w * 0.32
		if face_x:
			M.box(root, Vector3(0.02, h * 1.05, 0.012), pos + Vector3(0.02, 0, o), S.iron)
		else:
			M.box(root, Vector3(0.012, h * 1.05, 0.02), pos + Vector3(o, 0, 0.02), S.iron)
	for sd in [-1, 1]:
		var po := float(sd) * (w * 0.5 + 0.06)
		if face_x:
			M.box(root, Vector3(0.025, h * 1.05, 0.10), pos + Vector3(0.012, 0, po), S.wood_r)
		else:
			M.box(root, Vector3(0.10, h * 1.05, 0.025), pos + Vector3(po, 0, 0.012), S.wood_r)

func _cypress(root: Node3D, pos: Vector3, h: float, S: Dictionary) -> void:
	A.cypress(root, pos, h, S)

# ------------------------------------------------------------------ casa 2x2

func casa(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(11)
	M.box(root, Vector3(1.58, 0.14, 1.46), Vector3(0, 0.07, 0), S.stone_d)
	M.box(root, Vector3(1.46, 0.72, 1.32), Vector3(0, 0.50, 0), S.plaster)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.12, 0.74, 0.12), Vector3(sx * 0.73, 0.51, sz * 0.66), S.stone)
	M.box(root, Vector3(1.56, 0.06, 1.40), Vector3(0, 0.89, 0), S.brick)
	B.roof_x(root, 1.78, 1.66, 0.44, 0.92, S.roof)
	M.box(root, Vector3(1.84, 0.06, 0.09), Vector3(0, 1.37, 0), S.roof_d)
	A.arch_hole(root, Vector3(0.22, 0.14, 0.665), 0.36, 0.36, false, S.wood, S.stone_l, "round")
	_awning(root, Vector3(0.22, 0.70, 0.80), 0.58, 0.30, team, S)
	_window_reja(root, Vector3(-0.42, 0.52, 0.665), 0.22, 0.28, false, S)
	_window_reja(root, Vector3(0.735, 0.54, 0.22), 0.22, 0.26, true, S)
	_window_reja(root, Vector3(0.735, 0.54, -0.38), 0.22, 0.26, true, S)
	A.chimney(root, Vector3(-0.50, 1.08, -0.22), 0.20, 0.52, S.plaster, S.stone_d)
	A.jar(root, Vector3(0.68, 0.0, 0.92), S.clay, 0.11)
	A.jar(root, Vector3(0.90, 0.0, 0.76), S.clay, 0.09)
	M.ball(root, 0.12, Vector3(-0.72, 0.17, 0.82), S.bush, Vector3(1, 0.8, 1))
	M._flag(root, Vector3(-0.70, 0.0, 0.95), team, 0.95)
	return root

# ------------------------------------------------------------------ almacén 2x2

func almacen(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(101)
	M.box(root, Vector3(1.66, 0.14, 1.56), Vector3(0, 0.07, 0), S.stone_d)
	M.box(root, Vector3(1.52, 0.66, 1.40), Vector3(0, 0.47, 0), S.plaster)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.11, 0.68, 0.11), Vector3(sx * 0.76, 0.48, sz * 0.70), S.stone)
	M.box(root, Vector3(1.60, 0.06, 1.48), Vector3(0, 0.82, 0), S.brick)
	B.roof_x(root, 1.92, 1.82, 0.42, 0.85, S.roof)
	M.box(root, Vector3(1.98, 0.06, 0.09), Vector3(0, 1.30, 0), S.roof_d)
	# portón de medio punto abierto: hueco oscuro y hojas
	A.arch_hole(root, Vector3(-0.05, 0.14, 0.705), 0.74, 0.30, false, S.dark, S.stone_l, "round")
	for sx in [-1, 1]:
		var leaf := M.box(root, Vector3(0.30, 0.46, 0.04), Vector3(-0.05 + sx * 0.46, 0.38, 0.77), S.wood)
		leaf.rotation_degrees.y = float(sx) * 40.0
	_awning(root, Vector3(-0.05, 0.80, 0.84), 0.70, 0.26, team, S)
	B.window_s(root, Vector3(0.77, 0.52, -0.30), 0.22, 0.20, true, S)
	M.box(root, Vector3(0.06, 0.06, 0.40), Vector3(0.50, 1.00, 0.92), S.wood)
	M.cyl(root, 0.04, 0.04, 0.03, Vector3(0.50, 0.96, 1.08), S.iron, 8).rotation_degrees.x = 90.0
	M.box(root, Vector3(0.015, 0.30, 0.015), Vector3(0.50, 0.80, 1.08), S.rope)
	A.jar(root, Vector3(1.00, 0.0, 0.34), S.clay, 0.13)
	A.jar(root, Vector3(1.04, 0.0, 0.66), S.clay, 0.12)
	A.jar(root, Vector3(0.88, 0.0, 0.50), S.clay, 0.10)
	B.barrel(root, Vector3(0.80, 0.0, 0.95), S)
	B.crate(root, Vector3(0.50, 0.0, 0.95), S, 0.26, 12.0)
	B.sack(root, Vector3(-0.66, 0.0, 0.96), S)
	B.sack(root, Vector3(-0.86, 0.0, 0.86), S, 0.10)
	B.sack(root, Vector3(-0.74, 0.20, 0.94), S, 0.09)
	M._flag(root, Vector3(-0.72, 0.0, -0.82), team, 0.85)
	return root

# ------------------------------------------------------------------ cuartel 3x3

func cuartel(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(201)
	var F: Dictionary = S.F
	# sala larga de sillería con tejado a cuatro aguas
	M.box(root, Vector3(2.56, 0.16, 1.96), Vector3(0, 0.08, -0.22), S.stone_d)
	M.box(root, Vector3(2.40, 0.92, 1.80), Vector3(0, 0.62, -0.22), S.stone)
	M.box(root, Vector3(2.48, 0.07, 1.88), Vector3(0, 1.11, -0.22), S.stone_l)
	A.hip(root, 2.70, 2.14, 0.66, 1.14, S.roof, Vector3(0, 0, -0.22))
	M.box(root, Vector3(1.20, 0.06, 0.07), Vector3(0, 1.82, -0.22), S.roof_d)
	# arquería en la cara +x
	A.arcade(root, Vector3(1.22, 0.16, -0.35), false, 3, 0.52, 0.44, S.stone_l, S.dark, "round")
	# torres cuadradas delanteras con tejado piramidal
	for sx in [-1, 1]:
		A.tower_sq(root, Vector3(sx * 1.06, 0, 0.88), 0.72, 1.60, F, {"cap": "pyramid", "cap_m": S.roof, "cap_h": 0.60})
	# muro de la puerta entre las torres, con arco de herradura y rastrillo
	M.box(root, Vector3(1.40, 0.86, 0.34), Vector3(0, 0.57, 1.00), S.stone)
	M.box(root, Vector3(1.46, 0.07, 0.40), Vector3(0, 1.04, 1.00), S.stone_l)
	for k in 5:
		M.box(root, Vector3(0.20, 0.16, 0.34), Vector3(-0.60 + k * 0.30, 1.15, 1.00), S.stone)
	A.arch_hole(root, Vector3(0, 0.14, 1.19), 0.56, 0.42, false, S.dark, S.stone_l, "horseshoe")
	for k in 5:
		M.box(root, Vector3(0.025, 0.50, 0.03), Vector3(-0.20 + k * 0.10, 0.44, 1.21), S.iron)
	B.banner(root, Vector3(-0.50, 0.98, 1.20), team, false, 0.20, 0.50)
	B.banner(root, Vector3(0.50, 0.98, 1.20), team, false, 0.20, 0.50)
	# patio: maniquí y soporte de lanzas
	M.box(root, Vector3(0.05, 0.62, 0.05), Vector3(1.20, 0.31, 1.40), S.wood)
	M.box(root, Vector3(0.40, 0.05, 0.05), Vector3(1.20, 0.50, 1.40), S.wood)
	M.ball(root, 0.08, Vector3(1.20, 0.70, 1.40), S.sack)
	M.box(root, Vector3(0.20, 0.20, 0.10), Vector3(1.20, 0.38, 1.40), S.sack)
	for k in 4:
		var sp := M.box(root, Vector3(0.02, 0.78, 0.02), Vector3(-1.05 + k * 0.08, 0.40, 1.46), S.wood_l)
		sp.rotation_degrees.x = -8.0
		M.box(root, Vector3(0.03, 0.08, 0.03), Vector3(-1.05 + k * 0.08, 0.80, 1.44), S.steel)
	M.box(root, Vector3(0.42, 0.04, 0.05), Vector3(-0.96, 0.22, 1.47), S.wood)
	M.box(root, Vector3(0.24, 0.60, 0.24), Vector3(0.70, 1.65, -0.60), S.plaster)
	M.box(root, Vector3(0.30, 0.05, 0.30), Vector3(0.70, 1.96, -0.60), S.stone_d)
	M._flag(root, Vector3(-1.2, 0.0, -1.1), team, 1.0)
	return root

# ------------------------------------------------------------------ arquería 3x3

func arqueria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(301)
	var c := Vector3(-0.35, 0, -0.45)
	M.box(root, Vector3(2.10, 0.18, 1.40), c + Vector3(0, 0.09, 0), S.stone_d)
	M.box(root, Vector3(1.96, 0.74, 1.26), c + Vector3(0, 0.55, 0), S.plaster)
	# bandas de ladrillo (mudéjar) y esquinas de sillería
	for yy in [0.30, 0.86]:
		M.box(root, Vector3(2.0, 0.07, 1.30), c + Vector3(0, yy, 0), S.brick)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.12, 0.76, 0.12), c + Vector3(sx * 0.98, 0.56, sz * 0.63), S.stone)
	A.hip(root, 2.34, 1.70, 0.62, 0.90, S.roof, c)
	M.box(root, Vector3(0.80, 0.06, 0.07), c + Vector3(0, 1.52, 0), S.roof_d)
	A.arch_hole(root, c + Vector3(-0.30, 0.18, 0.64), 0.40, 0.34, false, S.wood, S.stone_l, "round")
	# tres arcos ciegos de ladrillo con ventana
	for k in [0.35, 0.80]:
		A.arch_hole(root, c + Vector3(k, 0.40, 0.635), 0.22, 0.20, false, S.glass, S.brick, "round", 0.04)
	A.arch_hole(root, c + Vector3(1.0, 0.40, -0.15), 0.22, 0.20, true, S.glass, S.brick, "round", 0.04)
	B.banner(root, c + Vector3(0.0, 0.88, 0.70), team, false, 0.22, 0.46)
	# campo de tiro: valla y dianas de paja
	B.fence(root, Vector3(0.70, 0, 1.40), Vector3(1.40, 0, 1.40), S)
	B.fence(root, Vector3(1.40, 0, 1.40), Vector3(1.40, 0, 0.0), S)
	B.fence(root, Vector3(-1.40, 0, 1.40), Vector3(0.30, 0, 1.40), S)
	for tz in [0.2, 0.85]:
		var tp := Vector3(0.82 if tz == 0.2 else 0.80, 0, tz)
		for lx in [-0.15, 0.15]:
			var leg := M.box(root, Vector3(0.04, 0.55, 0.04), tp + Vector3(0.05, 0.27, lx), S.wood)
			leg.rotation_degrees.z = 8.0 * signf(lx)
		var tgt := Node3D.new()
		tgt.position = tp + Vector3(0.0, 0.50, 0)
		tgt.rotation_degrees.z = 90.0
		root.add_child(tgt)
		M.cyl(tgt, 0.25, 0.25, 0.07, Vector3.ZERO, S.straw, 20)
		M.cyl(tgt, 0.20, 0.20, 0.075, Vector3.ZERO, S.cloth_w, 20)
		M.cyl(tgt, 0.145, 0.145, 0.08, Vector3.ZERO, _tm(team), 20)
		M.cyl(tgt, 0.075, 0.075, 0.085, Vector3.ZERO, S.cloth_w, 20)
		for a in [Vector2(0.03, 0.06), Vector2(-0.10, -0.05), Vector2(0.12, -0.08)]:
			var ar := M.box(tgt, Vector3(0.02, 0.36, 0.02), Vector3(a.x, -0.14, a.y), S.wood_l)
			ar.rotation_degrees.x = 90.0
	B.barrel(root, Vector3(-1.30, 0.0, 0.30), S, 0.10, 0.26)
	for k in 4:
		var ar2 := M.box(root, Vector3(0.015, 0.44, 0.015), Vector3(-1.30 + (k - 1.5) * 0.025, 0.46, 0.30), S.wood_l)
		ar2.rotation_degrees.z = (k - 1.5) * 4.0
	B.hay_bale(root, Vector3(-0.90, 0.0, 1.05), S)
	B.hay_bale(root, Vector3(-0.60, 0.0, 1.05), S)
	return root

# ------------------------------------------------------------------ establo 3x3

func establo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(401)
	var c := Vector3(-0.15, 0, -0.35)
	M.box(root, Vector3(2.30, 0.16, 1.62), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.16, 0.80, 1.48), c + Vector3(0, 0.56, 0), S.plaster)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.12, 0.82, 0.12), c + Vector3(sx * 1.08, 0.57, sz * 0.74), S.stone)
	M.box(root, Vector3(2.24, 0.06, 1.54), c + Vector3(0, 0.98, 0), S.brick)
	B.roof_x(root, 2.46, 1.94, 0.50, 1.00, S.roof, c)
	M.box(root, Vector3(2.52, 0.07, 0.09), c + Vector3(0, 1.52, 0), S.roof_d)
	# tres cuadras con arco de herradura (cara +z) y medias puertas
	for k in [-0.62, 0.0, 0.62]:
		A.arch_hole(root, c + Vector3(k, 0.16, 0.745), 0.40, 0.34, false, S.dark, S.stone_l, "horseshoe", 0.05)
		M.box(root, Vector3(0.32, 0.24, 0.04), c + Vector3(k, 0.28, 0.78), S.wood_r)
	M.box(root, Vector3(0.30, 0.26, 0.04), c + Vector3(0, 1.20, 0.76), S.dark)
	A.arch_hole(root, c + Vector3(1.09, 0.40, 0.20), 0.26, 0.24, true, S.glass, S.stone_l, "round", 0.04)
	A.arch_hole(root, c + Vector3(1.09, 0.40, -0.40), 0.26, 0.24, true, S.glass, S.stone_l, "round", 0.04)
	# veleta con caballo
	M.cyl(root, 0.015, 0.015, 0.34, c + Vector3(0.7, 1.70, 0), S.iron, 6)
	M.box(root, Vector3(0.20, 0.12, 0.02), c + Vector3(0.7, 1.88, 0), S.iron)
	M.box(root, Vector3(0.07, 0.12, 0.02), c + Vector3(0.78, 1.96, 0), S.iron)
	# cercado con abrevadero y fardos
	B.fence(root, Vector3(0.95, 0, 1.45), Vector3(1.45, 0, 1.45), S)
	B.fence(root, Vector3(1.45, 0, 1.45), Vector3(1.45, 0, 0.35), S)
	B.fence(root, Vector3(-1.40, 0, 1.45), Vector3(0.20, 0, 1.45), S)
	M.box(root, Vector3(0.50, 0.12, 0.16), Vector3(1.22, 0.10, 1.15), S.wood)
	M.box(root, Vector3(0.44, 0.02, 0.10), Vector3(1.22, 0.17, 1.15), S.water)
	B.hay_bale(root, Vector3(1.20, 0.0, 0.62), S, false)
	B.hay_bale(root, Vector3(1.22, 0.30, 0.64), S, false)
	B.hay_bale(root, Vector3(-1.05, 0.0, 1.00), S)
	B.hay_bale(root, Vector3(-0.72, 0.0, 1.05), S)
	_awning(root, c + Vector3(0.62, 0.92, 0.80), 0.50, 0.22, team, S)
	B.banner(root, c + Vector3(-0.90, 0.95, 0.78), team, false, 0.18, 0.46)
	return root

# ------------------------------------------------------------------ taller de asedio 3x3

func taller(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(501)
	var c := Vector3(-0.2, 0, -0.35)
	M.box(root, Vector3(2.30, 0.16, 1.60), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.16, 0.40, 1.46), c + Vector3(0, 0.36, 0), S.stone)
	M.box(root, Vector3(2.16, 0.72, 1.46), c + Vector3(0, 0.92, 0), S.plaster)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.12, 1.12, 0.12), c + Vector3(sx * 1.08, 0.72, sz * 0.73), S.stone)
	M.box(root, Vector3(2.24, 0.06, 1.54), c + Vector3(0, 1.30, 0), S.brick)
	B.roof_x(root, 2.48, 1.92, 0.54, 1.32, S.roof, c)
	M.box(root, Vector3(2.54, 0.07, 0.09), c + Vector3(0, 1.88, 0), S.roof_d)
	# portón ancho con arco rebajado y herrajes
	A.arch_hole(root, c + Vector3(-0.30, 0.16, 0.735), 0.96, 0.46, false, S.wood, S.stone_l, "round", 0.07)
	for y in [0.30, 0.56]:
		M.box(root, Vector3(0.96, 0.04, 0.06), c + Vector3(-0.30, y, 0.78), S.iron)
	M.box(root, Vector3(0.03, 0.62, 0.06), c + Vector3(-0.30, 0.50, 0.78), S.iron)
	# rueda dentada en la cara +x
	var gear := Node3D.new()
	gear.position = c + Vector3(1.12, 0.84, 0.30)
	gear.rotation_degrees.z = 90.0
	root.add_child(gear)
	M.cyl(gear, 0.26, 0.26, 0.07, Vector3.ZERO, S.wood_l, 20)
	M.cyl(gear, 0.06, 0.06, 0.10, Vector3.ZERO, S.iron, 10)
	for k in 10:
		var a := TAU * float(k) / 10.0
		var tooth := M.box(gear, Vector3(0.08, 0.07, 0.08), Vector3(cos(a) * 0.28, 0.0, sin(a) * 0.28), S.wood_l)
		tooth.rotation.y = -a
	for k in 4:
		var sp := M.box(gear, Vector3(0.50, 0.075, 0.03), Vector3.ZERO, S.wood)
		sp.rotation.y = float(k) * PI * 0.25
	_window_reja(root, c + Vector3(1.09, 0.80, -0.45), 0.24, 0.24, true, S)
	# grúa de madera con cuerda y gancho junto a la fachada
	M.box(root, Vector3(0.10, 1.40, 0.10), Vector3(0.95, 0.70, 1.15), S.wood)
	M.box(root, Vector3(0.80, 0.07, 0.07), Vector3(0.62, 1.38, 1.15), S.wood)
	M.box(root, Vector3(0.50, 0.05, 0.05), Vector3(0.78, 1.14, 1.15), S.wood).rotation_degrees.z = 40.0
	M.box(root, Vector3(0.015, 0.56, 0.015), Vector3(0.38, 1.10, 1.15), S.rope)
	M.box(root, Vector3(0.07, 0.07, 0.07), Vector3(0.38, 0.80, 1.15), S.iron)
	# troncos y bastidor de ariete
	for k in 3:
		var lg := M.cyl(root, 0.08, 0.08, 0.80, Vector3(-1.20, 0.08 + (k % 2) * 0.12, 0.45 + (k / 2) * 0.16 + (k % 2) * 0.08), S.wood_l, 10)
		lg.rotation_degrees.x = 90.0
	var fr := Vector3(-0.30, 0, 1.30)
	for sx in [-0.40, 0.40]:
		M.box(root, Vector3(0.06, 0.34, 0.06), fr + Vector3(sx, 0.17, 0.0), S.wood)
	M.box(root, Vector3(0.90, 0.06, 0.07), fr + Vector3(0, 0.34, 0.0), S.wood)
	M.cyl(root, 0.05, 0.05, 0.78, fr + Vector3(0, 0.22, 0.0), S.wood_l, 8).rotation_degrees.z = 90.0
	M.box(root, Vector3(0.10, 0.10, 0.10), fr + Vector3(0.40, 0.22, 0.0), S.iron)
	_awning(root, c + Vector3(0.62, 0.90, 0.82), 0.46, 0.22, team, S)
	B.banner(root, c + Vector3(-1.00, 1.05, 0.78), team, false, 0.18, 0.46)
	return root

# ------------------------------------------------------------------ puerto 3x3 (mira al agua por +z)

func puerto(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(601)
	var c := Vector3(0.0, 0, -0.45)
	M.box(root, Vector3(2.30, 0.16, 1.40), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.14, 0.78, 1.26), c + Vector3(0, 0.55, 0), S.plaster)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.12, 0.80, 0.12), c + Vector3(sx * 1.07, 0.56, sz * 0.63), S.stone)
	M.box(root, Vector3(2.22, 0.06, 1.34), c + Vector3(0, 0.96, 0), S.brick)
	B.roof_x(root, 2.46, 1.74, 0.48, 0.98, S.roof, c)
	M.box(root, Vector3(2.52, 0.07, 0.09), c + Vector3(0, 1.48, 0), S.roof_d)
	# dos portones con arco hacia el muelle
	for sx in [-1, 1]:
		A.arch_hole(root, c + Vector3(sx * 0.55 - 0.15, 0.16, 0.645), 0.50, 0.36, false, S.dark, S.stone_l, "round", 0.06)
		M.box(root, Vector3(0.40, 0.04, 0.06), c + Vector3(sx * 0.55 - 0.15, 0.40, 0.69), S.wood)
	A.arch_hole(root, c + Vector3(1.07, 0.42, 0.10), 0.24, 0.22, true, S.glass, S.stone_l, "round", 0.04)
	A.arch_hole(root, c + Vector3(1.07, 0.42, -0.40), 0.24, 0.22, true, S.glass, S.stone_l, "round", 0.04)
	# trasera (se ve cuando el agua queda al norte u oeste): ventanucos con rejas y una portezuela
	for wx in [-0.65, 0.0, 0.65]:
		A.arch_hole(root, c + Vector3(wx, 0.42, -0.635), 0.24, 0.22, false, S.glass, S.stone_l, "round", 0.04)
	M.box(root, Vector3(0.40, 0.05, 0.05), c + Vector3(-1.07, 0.84, 0.0), S.stone_l)
	# muelle de tablones
	M.box(root, Vector3(2.20, 0.08, 0.70), Vector3(0, 0.04, 1.00), S.wood_l)
	for k in 8:
		M.box(root, Vector3(0.015, 0.09, 0.70), Vector3(-1.05 + k * 0.30, 0.045, 1.00), S.wood)
	for sx in [-1.05, 0.0, 1.05]:
		M.cyl(root, 0.07, 0.07, 0.30, Vector3(sx, 0.15, 1.34), S.wood, 8)
	# grúa de carga con cuerda
	M.box(root, Vector3(0.10, 1.30, 0.10), Vector3(0.95, 0.65, 0.85), S.wood)
	M.box(root, Vector3(0.90, 0.07, 0.08), Vector3(0.52, 1.28, 0.85), S.wood)
	M.box(root, Vector3(0.50, 0.05, 0.05), Vector3(0.70, 1.04, 0.85), S.wood).rotation_degrees.z = 40.0
	M.box(root, Vector3(0.015, 0.50, 0.015), Vector3(0.12, 1.02, 0.85), S.rope)
	M.box(root, Vector3(0.16, 0.14, 0.16), Vector3(0.12, 0.72, 0.85), S.wood_l)
	# ánforas, barriles y cajas
	A.jar(root, Vector3(-0.85, 0.08, 0.95), S.clay, 0.11)
	A.jar(root, Vector3(-0.62, 0.08, 1.06), S.clay, 0.09)
	B.barrel(root, Vector3(-0.40, 0.08, 1.05), S, 0.10, 0.22)
	B.crate(root, Vector3(-0.15, 0.08, 1.10), S, 0.24, -10.0)
	M.cyl(root, 0.12, 0.12, 0.08, Vector3(0.40, 0.12, 1.08), S.rope, 14)
	_awning(root, c + Vector3(-0.15, 0.96, 0.78), 0.80, 0.26, team, S)
	M._flag(root, Vector3(1.20, 0.0, 1.30), team, 0.95)
	return root

# ------------------------------------------------------------------ torre 2x2

func torre(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(210)
	var F: Dictionary = S.F
	var top := A.tower_sq(root, Vector3.ZERO, 1.25, 2.7, F, {"bartizans": true, "bart_m": S.roof, "door": true})
	for sx in [-1, 1]:
		A.arch_hole(root, Vector3(sx * 0.25, 1.30, 0.63), 0.12, 0.30, false, S.dark, null, "round", 0.0)
	M._flag(root, Vector3(0.0, top, 0.0), team, 0.75)
	return root

# ------------------------------------------------------------------ monasterio 3x3

func monasterio(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(701)
	var nx := -0.30
	# nave a lo largo de z, tejado a dos aguas
	M.box(root, Vector3(1.50, 0.16, 2.50), Vector3(nx, 0.08, -0.15), S.stone_d)
	M.box(root, Vector3(1.30, 1.00, 2.30), Vector3(nx, 0.66, -0.15), S.stone_l)
	M.box(root, Vector3(1.40, 0.07, 2.40), Vector3(nx, 1.18, -0.15), S.stone)
	B.roof_z(root, 2.50, 1.58, 0.62, 1.20, S.roof, Vector3(nx, 0, -0.15))
	M.box(root, Vector3(0.09, 0.06, 2.54), Vector3(nx, 1.82, -0.15), S.roof_d)
	# ábside
	M.cyl(root, 0.66, 0.70, 0.18, Vector3(nx, 0.09, -1.30), S.stone_d, 20)
	M.cyl(root, 0.62, 0.62, 1.0, Vector3(nx, 0.66, -1.30), S.stone_l, 20)
	A.lathe(root, [Vector2(0.72, 1.16), Vector2(0.55, 1.34), Vector2(0.0, 1.78)], 20, Vector3(nx, 0, -1.30), S.roof_d)
	# ventanas de arco y contrafuertes en la cara +x
	for wz in [-0.80, -0.15, 0.50]:
		A.arch_hole(root, Vector3(nx + 0.655, 0.52, wz), 0.16, 0.30, true, S.glass, S.stone, "round", 0.03)
		M.box(root, Vector3(0.14, 0.96, 0.10), Vector3(nx + 0.70, 0.66, wz + 0.32), S.stone)
	# fachada con espadaña: muro que sube sobre el tejado con dos huecos de campana
	M.box(root, Vector3(1.30, 0.86, 0.20), Vector3(nx, 1.59, 1.00), S.stone_l)
	M.box(root, Vector3(1.38, 0.06, 0.26), Vector3(nx, 2.05, 1.00), S.stone)
	var gable := PackedVector2Array([Vector2(-0.30, 0.0), Vector2(0.30, 0.0), Vector2(0.0, 0.34)])
	A.extrude(root, gable, 0.20, Vector3(nx, 2.08, 1.00), S.stone_l)
	for bx in [-0.30, 0.30]:
		A.arch_hole(root, Vector3(nx + bx, 1.36, 1.105), 0.24, 0.36, false, S.dark, S.stone, "round", 0.04)
		M.ball(root, 0.07, Vector3(nx + bx, 1.50, 1.07), S.gold, Vector3(1, 1.2, 1))
	A.cross_fin(root, Vector3(nx, 2.40, 1.00), 0.30, S.iron)
	# portal con arquivoltas y rosetón
	A.arch_hole(root, Vector3(nx, 0.16, 1.105), 0.66, 0.50, false, S.stone_d, S.stone, "round", 0.06)
	A.arch_hole(root, Vector3(nx, 0.16, 1.12), 0.44, 0.40, false, S.wood, null, "round", 0.0)
	var rose := M.cyl(root, 0.15, 0.15, 0.04, Vector3(nx, 0.98, 1.105), S.glass, 20)
	rose.rotation_degrees.x = 90.0
	var ring := M.cyl(root, 0.19, 0.19, 0.03, Vector3(nx, 0.98, 1.10), S.stone, 20)
	ring.rotation_degrees.x = 90.0
	M.box(root, Vector3(0.04, 0.32, 0.04), Vector3(nx, 0.98, 1.13), S.stone)
	M.box(root, Vector3(0.32, 0.04, 0.04), Vector3(nx, 0.98, 1.13), S.stone)
	B.banner(root, Vector3(nx - 0.55, 1.05, 1.12), team, false, 0.18, 0.55)
	B.banner(root, Vector3(nx + 0.55, 1.05, 1.12), team, false, 0.18, 0.55)
	# claustro: patio con fuente, cipreses y arquería
	M.box(root, Vector3(1.0, 0.06, 1.50), Vector3(0.98, 0.03, 0.55), S.plaster)
	M.cyl(root, 0.18, 0.20, 0.16, Vector3(0.95, 0.14, 0.50), S.stone, 14)
	M.cyl(root, 0.15, 0.15, 0.03, Vector3(0.95, 0.225, 0.50), S.water, 14)
	M.cyl(root, 0.03, 0.04, 0.24, Vector3(0.95, 0.30, 0.50), S.stone, 8)
	_cypress(root, Vector3(0.68, 0.06, 1.12), 0.95, S)
	_cypress(root, Vector3(1.28, 0.06, 0.05), 0.80, S)
	A.arcade(root, Vector3(0.98, 0.0, 1.32), true, 2, 0.50, 0.30, S.stone_l, S.dark, "round")
	return root

# ------------------------------------------------------------------ castillo 4x4

func castillo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(110)
	var F: Dictionary = S.F
	M.box(root, Vector3(3.5, 0.06, 3.5), Vector3(0, 0.03, 0), A.mat("plaster", 119, Color(0.72, 0.62, 0.42), 1.2))
	var wh := 1.30
	A.wall_block(root, F, 3.0, wh, 0.50, Vector3(0, 0, -1.55))
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(-1.55, 0, 0))
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(1.55, 0, 0))
	A.wall_block(root, F, 1.05, wh, 0.50, Vector3(-0.975, 0, 1.55))
	A.wall_block(root, F, 1.05, wh, 0.50, Vector3(0.975, 0, 1.55))
	# puerta con arco de herradura, rastrillo y hojas abiertas
	M.box(root, Vector3(0.90, 0.38, 0.52), Vector3(0, wh - 0.19, 1.55), F.wall)
	M.box(root, Vector3(0.94, 0.05, 0.56), Vector3(0, wh + 0.025, 1.55), F.light)
	M.box(root, Vector3(0.90, 0.92, 0.30), Vector3(0, 0.46, 1.50), F.slit)
	for sx in [-1, 1]:
		M.box(root, Vector3(0.05, 0.86, 0.34), Vector3(sx * 0.46, 0.43, 1.55), F.trim)
		var leaf := M.box(root, Vector3(0.40, 0.84, 0.05), Vector3(sx * 0.30, 0.43, 1.79), F.wood)
		leaf.rotation_degrees.y = float(sx) * -62.0
	# torres de esquina con garitas
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			A.tower_sq(root, Vector3(sx * 1.55, 0, sz * 1.55), 1.05, 2.35, F)
	# torre del homenaje con cuatro torrecillas de teja
	var kc := Vector3(0.0, 0, -0.45)
	M.box(root, Vector3(1.90, 0.20, 1.60), kc + Vector3(0, 0.10, 0), F.dark)
	M.box(root, Vector3(1.94, 0.04, 1.64), kc + Vector3(0, 0.22, 0), F.trim)
	M.box(root, Vector3(1.80, 1.70, 1.50), kc + Vector3(0, 1.05, 0), F.wall)
	M.box(root, Vector3(1.98, 0.16, 1.68), kc + Vector3(0, 1.98, 0), F.dark)
	M.box(root, Vector3(2.04, 0.05, 1.74), kc + Vector3(0, 2.08, 0), F.trim)
	M.box(root, Vector3(1.86, 0.03, 1.56), kc + Vector3(0, 2.10, 0), F.floor)
	M._rim(root, 0.93, 0.78, 2.10, F.light)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var tc := kc + Vector3(sx * 0.88, 2.10, sz * 0.72)
			M.cyl(root, 0.20, 0.22, 0.60, tc + Vector3(0, 0.30, 0), F.wall, 14)
			M.cyl(root, 0.24, 0.24, 0.06, tc + Vector3(0, 0.63, 0), F.trim, 14)
			A.lathe(root, A.flare_prof(0.30, 0.46), 14, tc + Vector3(0, 0.66, 0), S.roof)
	for wx in [-0.55, 0.45]:
		A.arch_hole(root, kc + Vector3(wx, 1.0, 0.755), 0.24, 0.34, false, S.glass, F.light, "round", 0.04)
	for wz in [-0.35, 0.40]:
		A.arch_hole(root, kc + Vector3(0.905, 1.2, wz), 0.24, 0.34, true, S.glass, F.light, "round", 0.04)
	A.arch_hole(root, kc + Vector3(-0.1, 1.35, 0.755), 0.24, 0.30, false, S.glass, F.light, "horseshoe", 0.04)
	B.banner(root, kc + Vector3(-0.55, 1.78, 0.78), team, false, 0.24, 0.62)
	B.banner(root, kc + Vector3(0.45, 1.78, 0.78), team, false, 0.24, 0.62)
	M._flag(root, kc + Vector3(0.0, 2.10, 0.0), team, 1.0)
	M._flag(root, Vector3(-1.2, 1.35, 1.55), team, 0.9)
	return root

# ------------------------------------------------------------------ herrería 3x3

func herreria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(801)
	var c := Vector3(-0.2, 0, -0.35)
	M.box(root, Vector3(2.20, 0.16, 1.56), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.04, 0.88, 1.40), c + Vector3(0, 0.60, 0), S.stone)
	M.box(root, Vector3(2.12, 0.07, 1.48), c + Vector3(0, 1.07, 0), S.stone_l)
	A.hip(root, 2.34, 1.80, 0.52, 1.10, S.roof, c)
	M.box(root, Vector3(0.90, 0.06, 0.07), c + Vector3(0, 1.62, 0), S.roof_d)
	# gran chimenea de sillería con brasas en la cara +x
	M.box(root, Vector3(0.52, 1.90, 0.52), c + Vector3(1.20, 0.95, -0.30), S.stone_d)
	M.box(root, Vector3(0.62, 0.07, 0.62), c + Vector3(1.20, 1.90, -0.30), S.stone)
	M.box(root, Vector3(0.30, 0.04, 0.30), c + Vector3(1.20, 1.94, -0.30), S.dark)
	A.smoke_src(root, c + Vector3(1.20, 2.00, -0.30))
	M.box(root, Vector3(0.10, 0.30, 0.34), c + Vector3(1.48, 0.34, -0.30), S.fire)
	M.box(root, Vector3(0.10, 0.36, 0.40), c + Vector3(1.47, 0.32, -0.30), S.dark)
	M.box(root, Vector3(0.12, 0.26, 0.28), c + Vector3(1.49, 0.34, -0.30), S.fire)
	# fragua a la vista bajo un arco
	A.arch_hole(root, c + Vector3(-0.40, 0.16, 0.705), 0.80, 0.36, false, S.dark, S.stone_l, "round", 0.07)
	M.box(root, Vector3(0.20, 0.20, 0.03), c + Vector3(-0.60, 0.30, 0.70), S.fire)
	_window_reja(root, c + Vector3(0.45, 0.66, 0.705), 0.26, 0.24, false, S)
	# yunque, tajo, cubo de agua y espadas colgadas
	var ay := Vector3(0.45, 0, 1.05)
	M.box(root, Vector3(0.18, 0.18, 0.18), ay + Vector3(0, 0.09, 0), S.wood_l)
	M.box(root, Vector3(0.30, 0.07, 0.12), ay + Vector3(0, 0.215, 0), S.iron)
	M.box(root, Vector3(0.10, 0.05, 0.10), ay + Vector3(0.18, 0.21, 0), S.iron)
	B.barrel(root, Vector3(-0.30, 0.0, 1.12), S, 0.13, 0.30)
	M.box(root, Vector3(0.24, 0.015, 0.24), Vector3(-0.30, 0.295, 1.12), S.water)
	for k in 3:
		M.box(root, Vector3(0.025, 0.34, 0.012), c + Vector3(1.0, 0.64, 0.20 + k * 0.14), S.steel)
		M.box(root, Vector3(0.012, 0.16, 0.006), c + Vector3(1.0, 0.46, 0.20 + k * 0.14), S.wood)
	M.ball(root, 0.14, Vector3(-1.10, 0.10, 1.00), S.dark, Vector3(1.4, 0.7, 1.1))
	M.box(root, Vector3(0.18, 0.05, 0.08), Vector3(-0.88, 0.03, 1.12), S.steel)
	M.box(root, Vector3(0.18, 0.05, 0.08), Vector3(-0.88, 0.08, 1.12), S.steel)
	_awning(root, c + Vector3(0.45, 0.98, 0.80), 0.50, 0.22, team, S)
	B.banner(root, c + Vector3(-1.00, 0.95, 0.74), team, false, 0.18, 0.44)
	return root

# ------------------------------------------------------------------ mercado 3x3

func mercado(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(901)
	M.box(root, Vector3(2.70, 0.10, 2.70), Vector3(0, 0.05, 0), S.stone_l)
	M.box(root, Vector3(2.50, 0.04, 2.50), Vector3(0, 0.12, 0), S.stone)
	var tm := _tm(team)
	# soportal al fondo (z−) y cuatro puestos con toldos
	A.arcade(root, Vector3(0.0, 0.10, -1.30), true, 5, 0.50, 0.46, S.stone_l, S.wood, "round")
	B.puesto(root, Vector3(-0.60, 0.10, -0.70), 0.0, tm, [S.red_fruit, S.green_fruit, S.red_fruit, S.orange_fruit], S)
	B.puesto(root, Vector3(0.55, 0.10, -0.70), 0.0, S.cloth_r, [S.orange_fruit, S.orange_fruit, S.green_fruit, S.red_fruit], S)
	B.puesto(root, Vector3(-1.05, 0.10, 0.45), 90.0, S.cloth_y, [S.red_fruit, S.orange_fruit, S.red_fruit, S.green_fruit], S)
	B.puesto(root, Vector3(1.05, 0.10, 0.55), -90.0, tm, [S.green_fruit, S.red_fruit, S.orange_fruit, S.red_fruit], S)
	# fuente de pilón en el centro, con taza y surtidor
	M.cyl(root, 0.34, 0.36, 0.20, Vector3(0.0, 0.22, 0.20), S.stone, 18)
	M.cyl(root, 0.29, 0.29, 0.03, Vector3(0.0, 0.325, 0.20), S.water, 18)
	M.cyl(root, 0.06, 0.08, 0.40, Vector3(0.0, 0.52, 0.20), S.stone_l, 10)
	M.cyl(root, 0.17, 0.10, 0.07, Vector3(0.0, 0.74, 0.20), S.stone_l, 14)
	M.cyl(root, 0.04, 0.05, 0.14, Vector3(0.0, 0.82, 0.20), S.stone_l, 8)
	M._flag(root, Vector3(0.0, 0.10, 1.15), team, 1.30)
	B.crate(root, Vector3(1.05, 0.10, -0.15), S, 0.26, 12.0)
	A.jar(root, Vector3(-0.95, 0.10, -0.15), S.clay, 0.10)
	A.jar(root, Vector3(-0.74, 0.10, -0.10), S.clay, 0.08)
	B.barrel(root, Vector3(0.95, 0.10, 1.00), S)
	B.sack(root, Vector3(0.60, 0.10, 1.10), S)
	B.sack(root, Vector3(-0.60, 0.10, 1.10), S, 0.10)
	B.crate(root, Vector3(-0.85, 0.10, 0.95), S, 0.24, 20.0)
	return root

# ------------------------------------------------------------------ centro urbano 3x3

func centro(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(21)
	var F: Dictionary = S.F
	M.box(root, Vector3(2.62, 0.20, 2.50), Vector3(0, 0.10, 0), S.stone_d)
	M.box(root, Vector3(2.42, 0.80, 2.28), Vector3(0, 0.60, 0), S.stone)
	M.box(root, Vector3(2.48, 0.07, 2.34), Vector3(0, 1.015, 0), S.stone_l)
	M.box(root, Vector3(2.22, 0.66, 2.06), Vector3(0, 1.38, 0), S.plaster)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.14, 0.68, 0.14), Vector3(sx * 1.11, 1.38, sz * 1.0), S.stone)
	M.box(root, Vector3(2.30, 0.07, 2.14), Vector3(0, 1.74, 0), S.brick)
	A.hip(root, 2.70, 2.46, 0.80, 1.77, S.roof)
	M.box(root, Vector3(0.50, 0.07, 0.08), Vector3(0, 2.57, 0), S.roof_d)
	# soportal en la planta baja (cara +z) y portal central
	A.arcade(root, Vector3(0, 0.20, 1.20), true, 4, 0.56, 0.46, S.stone_l, S.dark, "round")
	A.arch_hole(root, Vector3(0, 0.20, 1.14), 0.44, 0.36, false, S.wood, null, "round", 0.0)
	# balcón corrido de madera en la planta alta con tres ventanas y postigos
	M.box(root, Vector3(1.90, 0.05, 0.30), Vector3(0, 1.09, 1.20), S.wood)
	for k in 9:
		M.box(root, Vector3(0.03, 0.22, 0.03), Vector3(-0.90 + k * 0.225, 1.22, 1.34), S.wood)
	M.box(root, Vector3(1.90, 0.04, 0.04), Vector3(0, 1.34, 1.34), S.wood)
	for wx in [-0.62, 0.0, 0.62]:
		A.arch_hole(root, Vector3(wx, 1.10, 1.035), 0.24, 0.34, false, S.glass, S.stone_l, "round", 0.04)
		M.box(root, Vector3(0.09, 0.40, 0.025), Vector3(wx - 0.20, 1.34, 1.045), S.wood_r)
		M.box(root, Vector3(0.09, 0.40, 0.025), Vector3(wx + 0.20, 1.34, 1.045), S.wood_r)
	for wz in [-0.6, 0.0, 0.6]:
		A.arch_hole(root, Vector3(1.115, 1.10, wz), 0.24, 0.34, true, S.glass, S.stone_l, "round", 0.04)
		A.arch_hole(root, Vector3(1.215, 0.45, wz), 0.20, 0.30, true, S.glass, S.stone_l, "round", 0.04)
	# escudo de armas del color del jugador sobre el soportal
	A.shield(root, Vector3(0.0, 1.78, 1.075), 0.16, false, S.gold, _tm(team))
	# campanario en la esquina trasera derecha
	var tc := Vector3(0.80, 0, -0.80)
	M.box(root, Vector3(0.76, 1.70, 0.76), tc + Vector3(0, 1.05, 0), S.stone)
	M.box(root, Vector3(0.86, 0.07, 0.86), tc + Vector3(0, 1.93, 0), S.stone_d)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.10, 0.50, 0.10), tc + Vector3(sx * 0.30, 2.22, sz * 0.30), S.stone)
	M.ball(root, 0.10, tc + Vector3(0, 2.18, 0), S.gold, Vector3(1, 1.2, 1))
	M.box(root, Vector3(0.80, 0.06, 0.80), tc + Vector3(0, 2.50, 0), S.stone_d)
	A.pyramid(root, 0.92, 0.70, 2.52, S.roof, tc)
	A.cross_fin(root, tc + Vector3(0, 3.20, 0), 0.30, S.iron)
	A.arch_hole(root, tc + Vector3(0.385, 1.25, 0.0), 0.16, 0.30, true, S.glass, null, "round", 0.0)
	A.arch_hole(root, tc + Vector3(0.0, 1.25, 0.385), 0.16, 0.30, false, S.glass, null, "round", 0.0)
	M._flag(root, Vector3(-1.18, 0.0, 1.35), team, 1.2)
	M._flag(root, tc + Vector3(0, 3.40, 0), team, 0.5)
	return root

# ------------------------------------------------------------------ murallas

func wall_post() -> Node3D:
	return A.wall_post(pal(250).F)

func wall_arm(d: int) -> Node3D:
	return A.wall_arm(d, pal(250).F)

func gate(along_x: bool) -> Node3D:
	var S := pal(260)
	return A.wall_gate(along_x, S.F, S.wood, "horseshoe")
