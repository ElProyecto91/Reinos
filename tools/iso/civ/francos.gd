extends RefCounted
## Francos: arquitectura gótica y de entramado. Piedra caliza clara, casas de entramado de roble con el piso alto en voladizo,
## tejados de pizarra azulada muy empinados con buhardillas, torreones redondos con tejado cónico (el del color del jugador),
## ventanas y puertas apuntadas, flores de lis doradas, catedral con dos torres de aguja y contrafuertes.

const A = preload("res://tools/iso/iso_arch.gd")
const M = preload("res://tools/iso/iso_models.gd")
const B = preload("res://tools/iso/iso_build.gd")

func build(type: String, team: Color) -> Node3D:
	return call(type, team) as Node3D

func pal(seed_v: int) -> Dictionary:
	var S := A.plain()
	S["stone"] = A.mat("stone", seed_v, Color(0.84, 0.80, 0.70), 1.1)
	S["stone_d"] = A.mat("stone", seed_v + 1, Color(0.64, 0.60, 0.52), 1.1)
	S["stone_l"] = A.mat("stone", seed_v + 2, Color(0.93, 0.90, 0.82), 1.1)
	S["plaster"] = A.mat("plaster", seed_v + 3, Color(0.94, 0.90, 0.78), 1.0)
	S["wood"] = A.mat("wood", seed_v + 4, Color(0.24, 0.16, 0.10), 1.4)
	S["wood_l"] = A.mat("wood", seed_v + 5, Color(0.52, 0.38, 0.22), 1.6)
	S["wood_r"] = A.mat("wood", seed_v + 6, Color(0.20, 0.30, 0.56), 1.4)
	S["roof"] = A.mat("roof", seed_v + 7, Color(0.34, 0.39, 0.48), 1.5)
	S["roof_d"] = A.mat("roof", seed_v + 8, Color(0.25, 0.29, 0.37), 1.5)
	S["blue"] = M.fmat(Color(0.18, 0.28, 0.60), 0.8, 0.2)
	S["F"] = A.fort(seed_v + 20, Color(0.84, 0.80, 0.70), Color(0.62, 0.58, 0.50), Color(0.93, 0.90, 0.82), Color(0.76, 0.62, 0.26), Color(0.30, 0.20, 0.12))
	return S

func _tm(team: Color) -> StandardMaterial3D:
	return M.fmat(team, 0.85, 0.2)

## Frontón (triángulo de yeso con entramado) delante de una cubierta con la cumbrera a lo largo de z: z = cara del tejado.
func _gable(root: Node3D, x: float, y: float, z: float, wid: float, rise: float, S: Dictionary) -> void:
	var tri := PackedVector2Array([Vector2(-wid * 0.5 + 0.06, 0.0), Vector2(wid * 0.5 - 0.06, 0.0), Vector2(0.0, rise - 0.10)])
	A.extrude(root, tri, 0.03, Vector3(x, y, z), S.plaster)
	M.box(root, Vector3(0.06, rise * 0.6, 0.05), Vector3(x, y + rise * 0.3, z + 0.02), S.wood)
	M.box(root, Vector3(wid * 0.55, 0.05, 0.05), Vector3(x, y + 0.08, z + 0.02), S.wood)
	var l := M.box(root, Vector3(0.05, rise * 0.62, 0.045), Vector3(x - wid * 0.17, y + rise * 0.25, z + 0.02), S.wood)
	l.rotation_degrees.z = 32.0
	var r := M.box(root, Vector3(0.05, rise * 0.62, 0.045), Vector3(x + wid * 0.17, y + rise * 0.25, z + 0.02), S.wood)
	r.rotation_degrees.z = -32.0

## Buhardilla sobre la vertiente +z de un tejado con la cumbrera a lo largo de x (ancho W, altura rise, arranque y0).
func _dormer(root: Node3D, x: float, y0: float, W: float, rise: float, S: Dictionary) -> void:
	var zs := W * 0.5 * 0.55
	var ys := y0 + rise * 0.45
	M.box(root, Vector3(0.30, 0.32, 0.34), Vector3(x, ys + 0.08, zs), S.plaster)
	A.arch_hole(root, Vector3(x, ys - 0.04, zs + 0.172), 0.16, 0.14, false, S.glass, S.wood, "pointed", 0.03)
	M.prism(root, 0.40, 0.22, 0.46, Vector3(x, ys + 0.24 + 0.11, zs), S.roof_d)
	M.box(root, Vector3(0.05, 0.05, 0.06), Vector3(x, ys + 0.50, zs + 0.18), S.gold)

## Cumbrera con flores de lis en los extremos.
func _ridge_fleur(root: Node3D, y: float, len: float, along_x: bool, S: Dictionary, pos: Vector3 = Vector3.ZERO) -> void:
	for s in [-1, 1]:
		var p := pos + (Vector3(s * len * 0.5, y, 0) if along_x else Vector3(0, y, s * len * 0.5))
		A.fleur_fin(root, p, 0.26, S.gold)

# ------------------------------------------------------------------ casa 2x2

func casa(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(11)
	M.box(root, Vector3(1.56, 0.14, 1.44), Vector3(0, 0.07, 0), S.stone_d)
	M.box(root, Vector3(1.40, 0.48, 1.28), Vector3(0, 0.38, 0), S.plaster)
	A.timber(root, Vector3(0, 0.14, 0.64), 1.40, 0.48, false, S.wood)
	A.timber(root, Vector3(0.70, 0.14, 0), 1.28, 0.48, true, S.wood)
	# piso alto en voladizo
	M.box(root, Vector3(1.54, 0.07, 1.42), Vector3(0, 0.655, 0), S.wood)
	M.box(root, Vector3(1.52, 0.42, 1.40), Vector3(0, 0.885, 0), S.plaster)
	A.timber(root, Vector3(0, 0.69, 0.70), 1.52, 0.42, false, S.wood, 0.38)
	A.timber(root, Vector3(0.76, 0.69, 0), 1.40, 0.42, true, S.wood, 0.38)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.09, 0.98, 0.09), Vector3(sx * 0.76, 0.58, sz * 0.70), S.wood)
	B.roof_z(root, 1.74, 1.74, 0.80, 1.10, S.roof)
	_gable(root, 0.0, 1.10, 0.88, 1.60, 0.80, S)
	M.box(root, Vector3(0.08, 0.06, 1.80), Vector3(0, 1.91, 0), S.roof_d)
	A.fleur_fin(root, Vector3(0, 1.92, 0.88), 0.26, S.gold)
	A.arch_hole(root, Vector3(0.22, 0.14, 0.655), 0.30, 0.22, false, S.wood, S.stone_l, "pointed", 0.05)
	for wx in [-0.45, 0.45]:
		A.arch_hole(root, Vector3(wx, 0.74, 0.715), 0.18, 0.16, false, S.glass, S.wood, "pointed", 0.03)
		M.box(root, Vector3(0.07, 0.30, 0.025), Vector3(wx - 0.16, 0.86, 0.725), S.blue)
		M.box(root, Vector3(0.07, 0.30, 0.025), Vector3(wx + 0.16, 0.86, 0.725), S.blue)
	A.arch_hole(root, Vector3(-0.35, 0.28, 0.655), 0.20, 0.12, false, S.glass, S.wood, "pointed", 0.03)
	A.arch_hole(root, Vector3(0.775, 0.76, 0.20), 0.18, 0.16, true, S.glass, S.wood, "pointed", 0.03)
	A.arch_hole(root, Vector3(0.775, 0.76, -0.35), 0.18, 0.16, true, S.glass, S.wood, "pointed", 0.03)
	A.chimney(root, Vector3(0.50, 1.10, -0.38), 0.22, 0.90, S.stone, S.stone_d)
	B.banner(root, Vector3(-0.45, 0.62, 0.80), team, false, 0.18, 0.40)
	M._flag(root, Vector3(-0.70, 0.0, 0.95), team, 0.95)
	M.ball(root, 0.10, Vector3(0.75, 0.15, 0.88), S.bush, Vector3(1, 0.8, 1))
	return root

# ------------------------------------------------------------------ almacén 2x2

func almacen(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(101)
	M.box(root, Vector3(1.66, 0.14, 1.56), Vector3(0, 0.07, 0), S.stone_d)
	M.box(root, Vector3(1.50, 0.50, 1.40), Vector3(0, 0.39, 0), S.stone)
	M.box(root, Vector3(1.56, 0.06, 1.46), Vector3(0, 0.67, 0), S.stone_l)
	M.box(root, Vector3(1.44, 0.40, 1.30), Vector3(0, 0.90, 0), S.plaster)
	A.timber(root, Vector3(0, 0.70, 0.65), 1.44, 0.40, false, S.wood, 0.36)
	A.timber(root, Vector3(0.72, 0.70, 0), 1.30, 0.40, true, S.wood, 0.36)
	B.roof_z(root, 1.80, 1.66, 0.78, 1.10, S.roof)
	_gable(root, 0.0, 1.10, 0.90, 1.56, 0.78, S)
	M.box(root, Vector3(0.08, 0.06, 1.86), Vector3(0, 1.90, 0), S.roof_d)
	# portón apuntado y cargadero con polea
	A.arch_hole(root, Vector3(-0.05, 0.14, 0.705), 0.50, 0.18, false, S.wood, S.stone_l, "pointed", 0.06)
	M.box(root, Vector3(0.04, 0.46, 0.05), Vector3(-0.05, 0.40, 0.75), S.iron)
	M.box(root, Vector3(0.30, 0.34, 0.04), Vector3(0.0, 1.00, 0.67), S.dark)
	M.box(root, Vector3(0.06, 0.06, 0.46), Vector3(0.0, 1.33, 0.90), S.wood)
	M.cyl(root, 0.045, 0.045, 0.03, Vector3(0.0, 1.27, 1.12), S.iron, 8).rotation_degrees.x = 90.0
	M.box(root, Vector3(0.015, 0.40, 0.015), Vector3(0.0, 1.05, 1.12), S.rope)
	M.box(root, Vector3(0.07, 0.07, 0.07), Vector3(0.0, 0.84, 1.12), S.iron)
	A.arch_hole(root, Vector3(0.755, 0.78, -0.25), 0.18, 0.16, true, S.glass, S.wood, "pointed", 0.03)
	B.barrel(root, Vector3(1.02, 0.0, 0.30), S)
	B.barrel(root, Vector3(1.02, 0.0, 0.58), S)
	B.crate(root, Vector3(0.62, 0.0, 0.92), S, 0.26, 12.0)
	B.crate(root, Vector3(0.90, 0.0, 0.92), S, 0.24, -8.0)
	B.sack(root, Vector3(-0.62, 0.0, 0.96), S)
	B.sack(root, Vector3(-0.80, 0.0, 0.86), S, 0.10)
	B.banner(root, Vector3(-0.55, 0.62, 0.80), team, false, 0.18, 0.40)
	M._flag(root, Vector3(-0.72, 0.0, -0.82), team, 0.85)
	return root

# ------------------------------------------------------------------ cuartel 3x3

func cuartel(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(201)
	var F: Dictionary = S.F
	var tm := _tm(team)
	M.box(root, Vector3(2.46, 0.16, 1.86), Vector3(0, 0.08, -0.32), S.stone_d)
	M.box(root, Vector3(2.30, 0.84, 1.70), Vector3(0, 0.58, -0.32), S.stone)
	M.box(root, Vector3(2.38, 0.07, 1.78), Vector3(0, 1.035, -0.32), S.stone_l)
	B.roof_x(root, 2.56, 2.00, 0.90, 1.07, S.roof, Vector3(0, 0, -0.32))
	M.box(root, Vector3(2.62, 0.07, 0.08), Vector3(0, 1.98, -0.32), S.roof_d)
	for dx in [-0.70, 0.0, 0.70]:
		_dormer(root, dx, 1.07, 2.00, 0.90, S)
	_ridge_fleur(root, 1.99, 2.56, true, S, Vector3(0, 0, -0.32))
	for wz in [-0.80, -0.30, 0.20]:
		A.arch_hole(root, Vector3(1.155, 0.40, wz), 0.16, 0.30, true, S.glass, S.stone_l, "pointed", 0.03)
	A.chimney(root, Vector3(0.80, 1.20, -0.75), 0.26, 0.95, S.stone, S.stone_d)
	# torreones redondos con tejado cónico del color del jugador
	for sx in [-1, 1]:
		A.tower_round(root, Vector3(sx * 1.08, 0, 0.82), 0.40, 1.50, F, tm, 1.0)
	# puerta entre los torreones: muro con arco apuntado, rastrillo y almenas
	M.box(root, Vector3(1.34, 0.86, 0.34), Vector3(0, 0.57, 0.96), S.stone)
	M.box(root, Vector3(1.40, 0.07, 0.40), Vector3(0, 1.04, 0.96), S.stone_l)
	for k in 5:
		M.box(root, Vector3(0.18, 0.16, 0.34), Vector3(-0.54 + k * 0.27, 1.15, 0.96), S.stone)
	A.arch_hole(root, Vector3(0, 0.14, 1.145), 0.50, 0.30, false, S.dark, S.stone_l, "pointed", 0.06)
	for k in 5:
		M.box(root, Vector3(0.025, 0.55, 0.03), Vector3(-0.20 + k * 0.10, 0.44, 1.17), S.iron)
	B.banner(root, Vector3(-0.50, 0.98, 1.16), team, false, 0.20, 0.50)
	B.banner(root, Vector3(0.50, 0.98, 1.16), team, false, 0.20, 0.50)
	# patio: maniquí y lanzas
	M.box(root, Vector3(0.05, 0.62, 0.05), Vector3(1.10, 0.31, 1.40), S.wood)
	M.box(root, Vector3(0.40, 0.05, 0.05), Vector3(1.10, 0.50, 1.40), S.wood)
	M.ball(root, 0.08, Vector3(1.10, 0.70, 1.40), S.sack)
	M.box(root, Vector3(0.20, 0.20, 0.10), Vector3(1.10, 0.38, 1.40), S.sack)
	for k in 4:
		var sp := M.box(root, Vector3(0.02, 0.78, 0.02), Vector3(-1.00 + k * 0.08, 0.40, 1.42), S.wood_l)
		sp.rotation_degrees.x = -8.0
		M.box(root, Vector3(0.03, 0.08, 0.03), Vector3(-1.00 + k * 0.08, 0.80, 1.40), S.steel)
	M._flag(root, Vector3(-1.2, 0.0, -1.2), team, 1.0)
	return root

# ------------------------------------------------------------------ arquería 3x3

func arqueria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(301)
	var tm := _tm(team)
	var c := Vector3(-0.35, 0, -0.45)
	M.box(root, Vector3(2.10, 0.16, 1.40), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(1.96, 0.38, 1.26), c + Vector3(0, 0.35, 0), S.stone)
	M.box(root, Vector3(1.96, 0.46, 1.26), c + Vector3(0, 0.77, 0), S.plaster)
	A.timber(root, c + Vector3(0, 0.54, 0.63), 1.96, 0.46, false, S.wood, 0.45)
	A.timber(root, c + Vector3(0.98, 0.54, 0), 1.26, 0.46, true, S.wood, 0.42)
	B.roof_x(root, 2.30, 1.74, 0.78, 1.00, S.roof, c)
	M.box(root, Vector3(2.36, 0.06, 0.08), c + Vector3(0, 1.80, 0), S.roof_d)
	_dormer(root, -0.35 + 0.35, 1.00, 1.74, 0.78, S)
	_ridge_fleur(root, 1.80, 2.30, true, S, c)
	A.arch_hole(root, c + Vector3(-0.30, 0.16, 0.635), 0.36, 0.22, false, S.wood, S.stone_l, "pointed", 0.05)
	A.arch_hole(root, c + Vector3(0.55, 0.70, 0.655), 0.20, 0.18, false, S.glass, S.wood, "pointed", 0.03)
	A.arch_hole(root, c + Vector3(0.995, 0.70, -0.15), 0.20, 0.18, true, S.glass, S.wood, "pointed", 0.03)
	# torrecilla de arqueros con tejado cónico de equipo
	A.tower_round(root, Vector3(0.60, 0, -1.10), 0.26, 1.30, S.F, tm, 0.75)
	B.banner(root, c + Vector3(0.0, 0.92, 0.68), team, false, 0.22, 0.46)
	# campo de tiro
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
		M.cyl(tgt, 0.145, 0.145, 0.08, Vector3.ZERO, tm, 20)
		M.cyl(tgt, 0.075, 0.075, 0.085, Vector3.ZERO, S.cloth_w, 20)
		for a in [Vector2(0.03, 0.06), Vector2(-0.10, -0.05), Vector2(0.12, -0.08)]:
			M.box(tgt, Vector3(0.02, 0.36, 0.02), Vector3(a.x, -0.14, a.y), S.wood_l).rotation_degrees.x = 90.0
	B.barrel(root, Vector3(-1.30, 0.0, 0.30), S, 0.10, 0.26)
	for k in 4:
		M.box(root, Vector3(0.015, 0.44, 0.015), Vector3(-1.30 + (k - 1.5) * 0.025, 0.46, 0.30), S.wood_l).rotation_degrees.z = (k - 1.5) * 4.0
	B.hay_bale(root, Vector3(-0.90, 0.0, 1.05), S)
	B.hay_bale(root, Vector3(-0.60, 0.0, 1.05), S)
	return root

# ------------------------------------------------------------------ establo 3x3

func establo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(401)
	var c := Vector3(-0.15, 0, -0.35)
	M.box(root, Vector3(2.30, 0.16, 1.62), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.16, 0.84, 1.48), c + Vector3(0, 0.58, 0), S.plaster)
	A.timber(root, c + Vector3(0, 0.16, 0.74), 2.16, 0.84, false, S.wood, 0.46)
	A.timber(root, c + Vector3(1.08, 0.16, 0), 1.48, 0.84, true, S.wood, 0.46)
	B.roof_x(root, 2.46, 1.94, 0.90, 1.00, S.roof, c)
	M.box(root, Vector3(2.52, 0.07, 0.08), c + Vector3(0, 1.92, 0), S.roof_d)
	_dormer(root, c.x + 0.55, 1.00, 1.94, 0.90, S)
	_ridge_fleur(root, 1.93, 2.46, true, S, c)
	# portón doble con aspas y heno en el pajar
	for sx in [-1, 1]:
		M.box(root, Vector3(0.44, 0.66, 0.05), c + Vector3(sx * 0.24, 0.50, 0.75), S.wood_l)
		M.box(root, Vector3(0.55, 0.04, 0.03), c + Vector3(sx * 0.24, 0.50, 0.79), S.wood).rotation_degrees.z = 50.0 * sx
		M.box(root, Vector3(0.55, 0.04, 0.03), c + Vector3(sx * 0.24, 0.50, 0.79), S.wood).rotation_degrees.z = -50.0 * sx
	A.arch_hole(root, c + Vector3(0, 0.16, 0.745), 0.88, 0.12, false, S.dark, S.stone_l, "flat", 0.05)
	A.arch_hole(root, c + Vector3(1.09, 0.60, 0.20), 0.18, 0.18, true, S.glass, S.wood, "pointed", 0.03)
	A.arch_hole(root, c + Vector3(1.09, 0.60, -0.40), 0.18, 0.18, true, S.glass, S.wood, "pointed", 0.03)
	M.box(root, Vector3(0.06, 0.06, 0.42), c + Vector3(-0.55, 1.15, 0.95), S.wood)
	B.fence(root, Vector3(0.95, 0, 1.45), Vector3(1.45, 0, 1.45), S)
	B.fence(root, Vector3(1.45, 0, 1.45), Vector3(1.45, 0, 0.35), S)
	B.fence(root, Vector3(-1.40, 0, 1.45), Vector3(0.20, 0, 1.45), S)
	M.box(root, Vector3(0.50, 0.12, 0.16), Vector3(1.22, 0.10, 1.15), S.wood)
	M.box(root, Vector3(0.44, 0.02, 0.10), Vector3(1.22, 0.17, 1.15), S.water)
	B.hay_bale(root, Vector3(1.20, 0.0, 0.62), S, false)
	B.hay_bale(root, Vector3(1.22, 0.30, 0.64), S, false)
	B.hay_bale(root, Vector3(-1.05, 0.0, 1.00), S)
	B.banner(root, c + Vector3(0.70, 0.98, 0.78), team, false, 0.20, 0.48)
	B.banner(root, c + Vector3(-0.78, 0.98, 0.78), team, false, 0.20, 0.48)
	return root

# ------------------------------------------------------------------ taller de asedio 3x3

func taller(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(501)
	var c := Vector3(-0.2, 0, -0.35)
	M.box(root, Vector3(2.30, 0.16, 1.60), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.16, 0.46, 1.46), c + Vector3(0, 0.39, 0), S.stone)
	M.box(root, Vector3(2.22, 0.06, 1.52), c + Vector3(0, 0.65, 0), S.stone_l)
	M.box(root, Vector3(2.10, 0.50, 1.40), c + Vector3(0, 0.93, 0), S.plaster)
	A.timber(root, c + Vector3(0, 0.68, 0.70), 2.10, 0.50, false, S.wood, 0.42)
	A.timber(root, c + Vector3(1.05, 0.68, 0), 1.40, 0.50, true, S.wood, 0.42)
	B.roof_x(root, 2.46, 1.90, 0.84, 1.18, S.roof, c)
	M.box(root, Vector3(2.52, 0.07, 0.08), c + Vector3(0, 2.07, 0), S.roof_d)
	_ridge_fleur(root, 2.08, 2.46, true, S, c)
	A.arch_hole(root, c + Vector3(-0.30, 0.16, 0.735), 0.84, 0.18, false, S.wood, S.stone_l, "pointed", 0.07)
	for y in [0.30, 0.52]:
		M.box(root, Vector3(0.84, 0.04, 0.06), c + Vector3(-0.30, y, 0.79), S.iron)
	var gear := Node3D.new()
	gear.position = c + Vector3(1.12, 0.92, 0.30)
	gear.rotation_degrees.z = 90.0
	root.add_child(gear)
	M.cyl(gear, 0.26, 0.26, 0.07, Vector3.ZERO, S.wood_l, 20)
	M.cyl(gear, 0.06, 0.06, 0.10, Vector3.ZERO, S.iron, 10)
	for k in 10:
		var a := TAU * float(k) / 10.0
		M.box(gear, Vector3(0.08, 0.07, 0.08), Vector3(cos(a) * 0.28, 0.0, sin(a) * 0.28), S.wood_l).rotation.y = -a
	for k in 4:
		M.box(gear, Vector3(0.50, 0.075, 0.03), Vector3.ZERO, S.wood).rotation.y = float(k) * PI * 0.25
	A.arch_hole(root, c + Vector3(1.075, 0.40, -0.45), 0.18, 0.18, true, S.glass, S.stone_l, "pointed", 0.03)
	# grúa y bastidor de ariete
	M.box(root, Vector3(0.10, 1.40, 0.10), Vector3(0.95, 0.70, 1.15), S.wood)
	M.box(root, Vector3(0.80, 0.07, 0.07), Vector3(0.62, 1.38, 1.15), S.wood)
	M.box(root, Vector3(0.50, 0.05, 0.05), Vector3(0.78, 1.14, 1.15), S.wood).rotation_degrees.z = 40.0
	M.box(root, Vector3(0.015, 0.56, 0.015), Vector3(0.38, 1.10, 1.15), S.rope)
	M.box(root, Vector3(0.07, 0.07, 0.07), Vector3(0.38, 0.80, 1.15), S.iron)
	for k in 3:
		M.cyl(root, 0.08, 0.08, 0.80, Vector3(-1.20, 0.08 + (k % 2) * 0.12, 0.45 + (k / 2) * 0.16 + (k % 2) * 0.08), S.wood_l, 10).rotation_degrees.x = 90.0
	var fr := Vector3(-0.30, 0, 1.30)
	for sx in [-0.40, 0.40]:
		M.box(root, Vector3(0.06, 0.34, 0.06), fr + Vector3(sx, 0.17, 0.0), S.wood)
	M.box(root, Vector3(0.90, 0.06, 0.07), fr + Vector3(0, 0.34, 0.0), S.wood)
	M.cyl(root, 0.05, 0.05, 0.78, fr + Vector3(0, 0.22, 0.0), S.wood_l, 8).rotation_degrees.z = 90.0
	M.box(root, Vector3(0.10, 0.10, 0.10), fr + Vector3(0.40, 0.22, 0.0), S.iron)
	B.banner(root, c + Vector3(0.50, 0.98, 0.80), team, false, 0.20, 0.46)
	B.banner(root, c + Vector3(-1.00, 0.98, 0.80), team, false, 0.20, 0.46)
	return root

# ------------------------------------------------------------------ puerto 3x3 (mira al agua por +z)

func puerto(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(601)
	var c := Vector3(0.0, 0, -0.45)
	M.box(root, Vector3(2.30, 0.16, 1.40), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.14, 0.46, 1.26), c + Vector3(0, 0.39, 0), S.stone)
	M.box(root, Vector3(2.20, 0.06, 1.32), c + Vector3(0, 0.65, 0), S.stone_l)
	M.box(root, Vector3(2.08, 0.46, 1.20), c + Vector3(0, 0.91, 0), S.plaster)
	A.timber(root, c + Vector3(0, 0.68, 0.60), 2.08, 0.46, false, S.wood, 0.45)
	A.timber(root, c + Vector3(1.04, 0.68, 0), 1.20, 0.46, true, S.wood, 0.45)
	B.roof_x(root, 2.46, 1.76, 0.80, 1.14, S.roof, c)
	M.box(root, Vector3(2.52, 0.07, 0.08), c + Vector3(0, 1.96, 0), S.roof_d)
	_dormer(root, c.x - 0.50, 1.14, 1.76, 0.80, S)
	_dormer(root, c.x + 0.60, 1.14, 1.76, 0.80, S)
	for sx in [-1, 1]:
		A.arch_hole(root, c + Vector3(sx * 0.55 - 0.1, 0.16, 0.645), 0.46, 0.18, false, S.dark, S.stone_l, "pointed", 0.06)
	A.arch_hole(root, c + Vector3(1.075, 0.42, 0.10), 0.18, 0.18, true, S.glass, S.stone_l, "pointed", 0.03)
	M.box(root, Vector3(2.20, 0.08, 0.70), Vector3(0, 0.04, 1.00), S.wood_l)
	for k in 8:
		M.box(root, Vector3(0.015, 0.09, 0.70), Vector3(-1.05 + k * 0.30, 0.045, 1.00), S.wood)
	for sx in [-1.05, 0.0, 1.05]:
		M.cyl(root, 0.07, 0.07, 0.30, Vector3(sx, 0.15, 1.34), S.wood, 8)
	M.box(root, Vector3(0.10, 1.30, 0.10), Vector3(0.95, 0.65, 0.85), S.wood)
	M.box(root, Vector3(0.90, 0.07, 0.08), Vector3(0.52, 1.28, 0.85), S.wood)
	M.box(root, Vector3(0.50, 0.05, 0.05), Vector3(0.70, 1.04, 0.85), S.wood).rotation_degrees.z = 40.0
	M.box(root, Vector3(0.015, 0.50, 0.015), Vector3(0.12, 1.02, 0.85), S.rope)
	M.box(root, Vector3(0.16, 0.14, 0.16), Vector3(0.12, 0.72, 0.85), S.wood_l)
	B.barrel(root, Vector3(-0.85, 0.08, 0.95), S)
	B.barrel(root, Vector3(-0.60, 0.08, 1.05), S, 0.10, 0.22)
	B.crate(root, Vector3(-0.30, 0.08, 1.08), S, 0.26, 10.0)
	B.crate(root, Vector3(-0.10, 0.08, 1.12), S, 0.22, -12.0)
	M.cyl(root, 0.12, 0.12, 0.08, Vector3(0.40, 0.12, 1.08), S.rope, 14)
	B.banner(root, c + Vector3(-0.85, 0.98, 0.68), team, false, 0.22, 0.50)
	M._flag(root, Vector3(1.20, 0.0, 1.30), team, 0.95)
	return root

# ------------------------------------------------------------------ torre 2x2 (torreón redondo con tejado cónico)

func torre(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(210)
	var top := A.tower_round(root, Vector3.ZERO, 0.58, 2.2, S.F, S.roof, 1.30)
	M.box(root, Vector3(0.30, 0.46, 0.06), Vector3(0.0, 0.20 + 0.23, 0.62), S.wood)
	A.arch_hole(root, Vector3(0.0, 1.30, 0.60), 0.12, 0.30, false, S.dark, null, "pointed", 0.0)
	A.fleur_fin(root, Vector3(0, top + 1.28, 0), 0.30, S.gold)
	M._flag(root, Vector3(-0.0, top + 1.12, 0.0), team, 0.40)
	# banderas de equipo colgadas del adarve
	B.banner(root, Vector3(0.0, 2.2, 0.72), team, false, 0.20, 0.55)
	return root

# ------------------------------------------------------------------ monasterio 3x3: catedral gótica

func _gothic_tower(root: Node3D, c: Vector3, w: float, h: float, S: Dictionary) -> void:
	M.box(root, Vector3(w + 0.12, 0.18, w + 0.12), c + Vector3(0, 0.09, 0), S.stone_d)
	M.box(root, Vector3(w, h, w), c + Vector3(0, 0.18 + h * 0.5, 0), S.stone_l)
	for k in [0.38, 0.68]:
		M.box(root, Vector3(w + 0.06, 0.05, w + 0.06), c + Vector3(0, 0.18 + h * k, 0), S.stone)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.09, h + 0.1, 0.09), c + Vector3(sx * (w * 0.5 + 0.02), 0.18 + h * 0.5, sz * (w * 0.5 + 0.02)), S.stone)
	var yb := 0.18 + h * 0.72
	A.arch_hole(root, c + Vector3(0, yb, w * 0.5 + 0.005), w * 0.34, h * 0.14, false, S.dark, S.stone, "pointed", 0.03)
	A.arch_hole(root, c + Vector3(w * 0.5 + 0.005, yb, 0), w * 0.34, h * 0.14, true, S.dark, S.stone, "pointed", 0.03)
	A.arch_hole(root, c + Vector3(0, 0.18 + h * 0.42, w * 0.5 + 0.005), w * 0.18, h * 0.12, false, S.glass, S.stone, "pointed", 0.02)
	A.arch_hole(root, c + Vector3(w * 0.5 + 0.005, 0.18 + h * 0.42, 0), w * 0.18, h * 0.12, true, S.glass, S.stone, "pointed", 0.02)
	M.box(root, Vector3(w + 0.16, 0.06, w + 0.16), c + Vector3(0, 0.18 + h + 0.03, 0), S.stone)
	A.pyramid(root, w + 0.12, 1.15, 0.18 + h + 0.06, S.roof, c)
	A.cross_fin(root, c + Vector3(0, 0.18 + h + 1.18, 0), 0.26, S.gold)

func monasterio(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(701)
	var nx := -0.22
	M.box(root, Vector3(1.34, 0.16, 2.40), Vector3(nx, 0.08, -0.25), S.stone_d)
	M.box(root, Vector3(1.20, 1.06, 2.28), Vector3(nx, 0.69, -0.25), S.stone_l)
	M.box(root, Vector3(1.28, 0.06, 2.34), Vector3(nx, 1.25, -0.25), S.stone)
	B.roof_z(root, 2.44, 1.46, 0.86, 1.28, S.roof, Vector3(nx, 0, -0.25))
	M.box(root, Vector3(0.08, 0.06, 2.50), Vector3(nx, 2.16, -0.25), S.roof_d)
	# ábside poligonal con tejado cónico
	M.cyl(root, 0.60, 0.64, 0.16, Vector3(nx, 0.08, -1.45), S.stone_d, 8)
	M.cyl(root, 0.56, 0.56, 1.06, Vector3(nx, 0.69, -1.45), S.stone_l, 8)
	A.lathe(root, [Vector2(0.66, 1.22), Vector2(0.45, 1.65), Vector2(0.0, 2.20)], 8, Vector3(nx, 0, -1.45), S.roof_d, false)
	# vidrieras apuntadas y arbotantes en la cara +x
	for wz in [-0.95, -0.30, 0.35]:
		A.arch_hole(root, Vector3(nx + 0.605, 0.44, wz), 0.16, 0.42, true, S.glass, S.stone, "pointed", 0.03)
		M.box(root, Vector3(0.12, 1.00, 0.12), Vector3(nx + 0.86, 0.66, wz + 0.32), S.stone)
		var arm := M.box(root, Vector3(0.34, 0.07, 0.07), Vector3(nx + 0.70, 1.12, wz + 0.32), S.stone)
		arm.rotation_degrees.z = -38.0
		M.box(root, Vector3(0.08, 0.14, 0.08), Vector3(nx + 0.86, 1.26, wz + 0.32), S.stone_l)
	# fachada con dos torres de aguja, portal apuntado con arquivoltas y rosetón
	_gothic_tower(root, Vector3(nx - 0.42, 0, 1.12), 0.52, 1.70, S)
	_gothic_tower(root, Vector3(nx + 0.42, 0, 1.12), 0.52, 1.70, S)
	M.box(root, Vector3(0.36, 1.20, 0.30), Vector3(nx, 0.78, 1.04), S.stone_l)
	A.arch_hole(root, Vector3(nx, 0.16, 1.205), 0.62, 0.30, false, S.stone_d, S.stone, "pointed", 0.06)
	A.arch_hole(root, Vector3(nx, 0.16, 1.215), 0.40, 0.22, false, S.wood, null, "pointed", 0.0)
	var rose := M.cyl(root, 0.17, 0.17, 0.04, Vector3(nx, 0.98, 1.205), S.glass, 20)
	rose.rotation_degrees.x = 90.0
	var ring := M.cyl(root, 0.21, 0.21, 0.03, Vector3(nx, 0.98, 1.20), S.stone, 20)
	ring.rotation_degrees.x = 90.0
	M.box(root, Vector3(0.04, 0.36, 0.04), Vector3(nx, 0.98, 1.23), S.stone)
	M.box(root, Vector3(0.36, 0.04, 0.04), Vector3(nx, 0.98, 1.23), S.stone)
	var gtri := PackedVector2Array([Vector2(-0.22, 0.0), Vector2(0.22, 0.0), Vector2(0.0, 0.42)])
	A.extrude(root, gtri, 0.30, Vector3(nx, 1.26, 1.04), S.stone_l)
	A.cross_fin(root, Vector3(nx, 1.66, 1.04), 0.26, S.gold)
	B.banner(root, Vector3(nx - 0.30, 0.78, 1.22), team, false, 0.14, 0.46)
	B.banner(root, Vector3(nx + 0.30, 0.78, 1.22), team, false, 0.14, 0.46)
	# jardín con setos, rosales y cruz
	M.box(root, Vector3(0.80, 0.04, 1.30), Vector3(1.08, 0.02, 0.50), S.stone)
	for hz in [-0.10, 0.50, 1.10]:
		M.box(root, Vector3(0.62, 0.14, 0.14), Vector3(1.08, 0.11, hz), S.bush)
		M.ball(root, 0.05, Vector3(0.90, 0.20, hz), S.red_fruit)
		M.ball(root, 0.05, Vector3(1.20, 0.20, hz), S.cloth_y)
	M.box(root, Vector3(0.05, 0.50, 0.05), Vector3(1.08, 0.29, 0.30), S.wood)
	M.box(root, Vector3(0.26, 0.05, 0.05), Vector3(1.08, 0.42, 0.30), S.wood)
	root.position.z = 0.28     # el ábside quedaba medio metro fuera de la huella
	return root

# ------------------------------------------------------------------ castillo 4x4: château

func castillo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(110)
	var F: Dictionary = S.F
	var tm := _tm(team)
	M.box(root, Vector3(3.5, 0.06, 3.5), Vector3(0, 0.03, 0), A.mat("plaster", 119, Color(0.70, 0.64, 0.48), 1.2))
	var wh := 1.20
	A.wall_block(root, F, 3.0, wh, 0.50, Vector3(0, 0, -1.55))
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(-1.55, 0, 0))
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(1.55, 0, 0))
	A.wall_block(root, F, 1.05, wh, 0.50, Vector3(-0.975, 0, 1.55))
	A.wall_block(root, F, 1.05, wh, 0.50, Vector3(0.975, 0, 1.55))
	# puerta apuntada con torrecillas
	M.box(root, Vector3(0.90, 0.36, 0.52), Vector3(0, wh - 0.18, 1.55), F.wall)
	M.box(root, Vector3(0.94, 0.05, 0.56), Vector3(0, wh + 0.025, 1.55), F.light)
	M.box(root, Vector3(0.90, 0.86, 0.30), Vector3(0, 0.43, 1.50), F.slit)
	for sx in [-1, 1]:
		var leaf := M.box(root, Vector3(0.40, 0.80, 0.05), Vector3(sx * 0.30, 0.41, 1.79), F.wood)
		leaf.rotation_degrees.y = float(sx) * -62.0
		A.tower_round(root, Vector3(sx * 0.62, 0, 1.70), 0.24, 1.45, F, S.roof, 0.80)
	# torres de las esquinas con tejado cónico de pizarra
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			A.tower_round(root, Vector3(sx * 1.55, 0, sz * 1.55), 0.58, 2.05, F, S.roof, 1.05)
			A.fleur_fin(root, Vector3(sx * 1.55, 3.35, sz * 1.55), 0.26, S.gold)
	# palacio (logis) contra el muro del fondo con buhardillas y chimeneas
	var pc := Vector3(-0.30, 0, -0.95)
	M.box(root, Vector3(2.20, 0.16, 0.95), pc + Vector3(0, 0.08, 0), F.dark)
	M.box(root, Vector3(2.10, 1.10, 0.85), pc + Vector3(0, 0.71, 0), F.wall)
	M.box(root, Vector3(2.16, 0.07, 0.91), pc + Vector3(0, 1.285, 0), F.light)
	B.roof_x(root, 2.30, 1.14, 0.75, 1.32, S.roof, pc)
	M.box(root, Vector3(2.36, 0.06, 0.08), pc + Vector3(0, 2.08, 0), S.roof_d)
	for dx in [-0.65, 0.0, 0.65]:
		var ys := 1.32 + 0.75 * 0.45
		M.box(root, Vector3(0.28, 0.30, 0.30), pc + Vector3(dx, ys + 0.08, 0.31), S.plaster)
		A.arch_hole(root, pc + Vector3(dx, ys - 0.04, 0.462), 0.14, 0.12, false, S.glass, S.wood, "pointed", 0.03)
		M.prism(root, 0.36, 0.20, 0.40, pc + Vector3(dx, ys + 0.34, 0.31), S.roof_d)
	for dx in [-0.9, 0.8]:
		A.chimney(root, pc + Vector3(dx, 1.60, -0.20), 0.22, 0.75, F.wall, F.dark)
	for wx in [-0.7, 0.0, 0.7]:
		A.arch_hole(root, pc + Vector3(wx, 0.55, 0.425), 0.18, 0.40, false, S.glass, F.light, "pointed", 0.03)
	# torre del homenaje redonda con cono del color del jugador
	var dc := Vector3(0.75, 0, -0.10)
	A.tower_round(root, dc, 0.74, 2.60, F, tm, 1.50)
	A.fleur_fin(root, dc + Vector3(0, 4.60, 0), 0.34, S.gold)
	B.banner(root, dc + Vector3(0.0, 2.30, 0.84), team, false, 0.26, 0.70)
	M._flag(root, Vector3(-1.2, 1.20, 1.55), team, 0.9)
	return root

# ------------------------------------------------------------------ herrería 3x3

func herreria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(801)
	var c := Vector3(-0.2, 0, -0.35)
	M.box(root, Vector3(2.20, 0.16, 1.56), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.04, 0.60, 1.40), c + Vector3(0, 0.46, 0), S.stone)
	M.box(root, Vector3(2.10, 0.06, 1.46), c + Vector3(0, 0.79, 0), S.stone_l)
	M.box(root, Vector3(1.98, 0.40, 1.34), c + Vector3(0, 1.02, 0), S.plaster)
	A.timber(root, c + Vector3(0, 0.82, 0.67), 1.98, 0.40, false, S.wood, 0.45)
	A.timber(root, c + Vector3(0.99, 0.82, 0), 1.34, 0.40, true, S.wood, 0.45)
	B.roof_x(root, 2.30, 1.76, 0.80, 1.22, S.roof, c)
	M.box(root, Vector3(2.36, 0.06, 0.08), c + Vector3(0, 2.04, 0), S.roof_d)
	M.box(root, Vector3(0.52, 2.20, 0.52), c + Vector3(1.20, 1.10, -0.30), S.stone_d)
	M.box(root, Vector3(0.62, 0.07, 0.62), c + Vector3(1.20, 2.20, -0.30), S.stone)
	M.box(root, Vector3(0.30, 0.04, 0.30), c + Vector3(1.20, 2.24, -0.30), S.dark)
	A.smoke_src(root, c + Vector3(1.20, 2.30, -0.30))
	M.box(root, Vector3(0.10, 0.30, 0.34), c + Vector3(1.48, 0.34, -0.30), S.fire)
	M.box(root, Vector3(0.10, 0.36, 0.40), c + Vector3(1.47, 0.32, -0.30), S.dark)
	M.box(root, Vector3(0.12, 0.26, 0.28), c + Vector3(1.49, 0.34, -0.30), S.fire)
	A.arch_hole(root, c + Vector3(-0.40, 0.16, 0.705), 0.78, 0.22, false, S.dark, S.stone_l, "pointed", 0.07)
	M.box(root, Vector3(0.20, 0.20, 0.03), c + Vector3(-0.60, 0.30, 0.70), S.fire)
	A.arch_hole(root, c + Vector3(0.45, 0.84, 0.675), 0.18, 0.16, false, S.glass, S.wood, "pointed", 0.03)
	var ay := Vector3(0.45, 0, 1.05)
	M.box(root, Vector3(0.18, 0.18, 0.18), ay + Vector3(0, 0.09, 0), S.wood_l)
	M.box(root, Vector3(0.30, 0.07, 0.12), ay + Vector3(0, 0.215, 0), S.iron)
	M.box(root, Vector3(0.10, 0.05, 0.10), ay + Vector3(0.18, 0.21, 0), S.iron)
	B.barrel(root, Vector3(-0.30, 0.0, 1.12), S, 0.13, 0.30)
	M.box(root, Vector3(0.24, 0.015, 0.24), Vector3(-0.30, 0.295, 1.12), S.water)
	for k in 3:
		M.box(root, Vector3(0.025, 0.34, 0.012), c + Vector3(1.0, 0.64, 0.20 + k * 0.14), S.steel)
	M.ball(root, 0.14, Vector3(-1.10, 0.10, 1.00), S.dark, Vector3(1.4, 0.7, 1.1))
	M.box(root, Vector3(0.18, 0.05, 0.08), Vector3(-0.88, 0.03, 1.12), S.steel)
	B.banner(root, c + Vector3(0.40, 0.98, 0.72), team, false, 0.20, 0.42)
	B.banner(root, c + Vector3(-1.00, 0.98, 0.72), team, false, 0.20, 0.42)
	return root

# ------------------------------------------------------------------ mercado 3x3: halle cubierta y plaza

func mercado(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(901)
	var tm := _tm(team)
	M.box(root, Vector3(2.70, 0.10, 2.70), Vector3(0, 0.05, 0), S.stone_l)
	M.box(root, Vector3(2.50, 0.04, 2.50), Vector3(0, 0.12, 0), S.stone)
	# halle: dos hileras de postes y gran tejado de pizarra
	for px in [-1.05, -0.35, 0.35, 1.05]:
		for pz in [-1.20, -0.20]:
			M.cyl(root, 0.06, 0.07, 1.0, Vector3(px, 0.64, pz), S.wood, 8)
			M.box(root, Vector3(0.16, 0.06, 0.16), Vector3(px, 0.16, pz), S.stone_d)
	M.box(root, Vector3(2.40, 0.07, 0.08), Vector3(0, 1.17, -1.20), S.wood)
	M.box(root, Vector3(2.40, 0.07, 0.08), Vector3(0, 1.17, -0.20), S.wood)
	for px in [-1.05, 0.35, 1.05]:
		M.box(root, Vector3(0.08, 0.07, 1.10), Vector3(px, 1.17, -0.70), S.wood)
	B.roof_x(root, 2.60, 1.40, 0.62, 1.20, S.roof, Vector3(0, 0, -0.70))
	M.box(root, Vector3(2.66, 0.06, 0.08), Vector3(0, 1.82, -0.70), S.roof_d)
	_ridge_fleur(root, 1.83, 2.60, true, S, Vector3(0, 0, -0.70))
	# mostradores bajo la halle
	for tx in [-0.70, 0.70]:
		M.box(root, Vector3(0.70, 0.24, 0.30), Vector3(tx, 0.26, -0.70), S.wood_l)
		for k in 4:
			M.ball(root, 0.06, Vector3(tx - 0.24 + k * 0.16, 0.42, -0.70), [S.red_fruit, S.green_fruit, S.orange_fruit, S.red_fruit][k], Vector3(1, 0.9, 1))
	# puestos con toldos y pozo en la plaza
	B.puesto(root, Vector3(-0.85, 0.10, 0.60), 0.0, tm, [S.red_fruit, S.green_fruit, S.red_fruit, S.orange_fruit], S)
	B.puesto(root, Vector3(0.95, 0.10, 0.65), -90.0, S.cloth_b, [S.orange_fruit, S.orange_fruit, S.green_fruit, S.red_fruit], S)
	M.cyl(root, 0.26, 0.26, 0.26, Vector3(0.0, 0.26, 0.55), S.stone_d, 16)
	M.cyl(root, 0.20, 0.20, 0.03, Vector3(0.0, 0.40, 0.55), S.water, 16)
	for sx in [-1, 1]:
		M.box(root, Vector3(0.04, 0.50, 0.04), Vector3(sx * 0.22, 0.65, 0.55), S.wood)
	M.box(root, Vector3(0.52, 0.04, 0.05), Vector3(0.0, 0.90, 0.55), S.wood)
	B.roof_x(root, 0.60, 0.46, 0.14, 0.92, S.roof, Vector3(0, 0, 0.55))
	M._flag(root, Vector3(0.0, 0.10, 1.20), team, 1.30)
	B.crate(root, Vector3(1.05, 0.10, -0.15), S, 0.26, 12.0)
	B.barrel(root, Vector3(-1.10, 0.10, 0.05), S)
	B.sack(root, Vector3(0.60, 0.10, 1.15), S)
	B.sack(root, Vector3(-0.60, 0.10, 1.15), S, 0.10)
	return root

# ------------------------------------------------------------------ centro urbano 3x3: ayuntamiento

func centro(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(21)
	var F: Dictionary = S.F
	M.box(root, Vector3(2.62, 0.20, 2.50), Vector3(0, 0.10, 0), S.stone_d)
	M.box(root, Vector3(2.42, 0.78, 2.28), Vector3(0, 0.59, 0), S.stone)
	M.box(root, Vector3(2.50, 0.07, 2.36), Vector3(0, 1.015, 0), S.stone_l)
	M.box(root, Vector3(2.40, 0.56, 2.24), Vector3(0, 1.32, 0), S.plaster)
	A.timber(root, Vector3(0, 1.05, 1.12), 2.40, 0.56, false, S.wood, 0.48)
	A.timber(root, Vector3(1.20, 1.05, 0), 2.24, 0.56, true, S.wood, 0.48)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.12, 0.58, 0.12), Vector3(sx * 1.20, 1.32, sz * 1.12), S.wood)
	B.roof_x(root, 2.70, 2.46, 1.00, 1.60, S.roof)
	M.box(root, Vector3(2.76, 0.07, 0.09), Vector3(0, 2.62, 0), S.roof_d)
	_ridge_fleur(root, 2.63, 2.76, true, S)
	for dx in [-0.75, 0.75]:
		_dormer(root, dx, 1.60, 2.46, 1.00, S)
	# portal y ventanas apuntadas
	A.arch_hole(root, Vector3(0.0, 0.20, 1.145), 0.56, 0.34, false, S.wood, S.stone_l, "pointed", 0.07)
	for wx in [-0.85, 0.85]:
		A.arch_hole(root, Vector3(wx, 0.36, 1.145), 0.22, 0.30, false, S.glass, S.stone_l, "pointed", 0.04)
	for wx in [-0.80, 0.0, 0.80]:
		A.arch_hole(root, Vector3(wx, 1.10, 1.125), 0.22, 0.26, false, S.glass, S.wood, "pointed", 0.03)
		M.box(root, Vector3(0.08, 0.34, 0.025), Vector3(wx - 0.19, 1.24, 1.13), S.blue)
		M.box(root, Vector3(0.08, 0.34, 0.025), Vector3(wx + 0.19, 1.24, 1.13), S.blue)
	for wz in [-0.7, 0.0, 0.7]:
		A.arch_hole(root, Vector3(1.215, 0.36, wz), 0.20, 0.30, true, S.glass, S.stone_l, "pointed", 0.04)
		A.arch_hole(root, Vector3(1.205, 1.10, wz), 0.20, 0.26, true, S.glass, S.wood, "pointed", 0.03)
	A.shield(root, Vector3(0.0, 0.86, 1.15), 0.16, false, S.gold, _tm(team))
	# torreón de escalera redondo (esquina delantera izquierda) con cono y campanario cuadrado con aguja (fondo derecho)
	A.tower_round(root, Vector3(-1.14, 0, 1.06), 0.30, 1.90, F, S.roof, 0.90)
	var tc := Vector3(0.80, 0, -0.78)
	M.box(root, Vector3(0.76, 1.64, 0.76), tc + Vector3(0, 1.0, 0), S.stone_l)
	M.box(root, Vector3(0.86, 0.07, 0.86), tc + Vector3(0, 1.86, 0), S.stone)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.10, 0.50, 0.10), tc + Vector3(sx * 0.30, 2.14, sz * 0.30), S.stone)
	M.ball(root, 0.10, tc + Vector3(0, 2.10, 0), S.gold, Vector3(1, 1.2, 1))
	M.box(root, Vector3(0.80, 0.06, 0.80), tc + Vector3(0, 2.42, 0), S.stone)
	A.pyramid(root, 0.92, 1.05, 2.45, S.roof, tc)
	A.fleur_fin(root, tc + Vector3(0, 3.46, 0), 0.34, S.gold)
	A.arch_hole(root, tc + Vector3(0.385, 1.25, 0.0), 0.16, 0.32, true, S.glass, null, "pointed", 0.0)
	A.arch_hole(root, tc + Vector3(0.0, 1.25, 0.385), 0.16, 0.32, false, S.glass, null, "pointed", 0.0)
	B.banner(root, Vector3(-0.55, 0.90, 1.18), team, false, 0.20, 0.50)
	B.banner(root, Vector3(0.55, 0.90, 1.18), team, false, 0.20, 0.50)
	M._flag(root, Vector3(1.18, 0.0, 1.35), team, 1.2)
	return root

# ------------------------------------------------------------------ murallas

func wall_post() -> Node3D:
	return A.wall_post(pal(250).F)

func wall_arm(d: int) -> Node3D:
	return A.wall_arm(d, pal(250).F)

func gate(along_x: bool) -> Node3D:
	var S := pal(260)
	return A.wall_gate(along_x, S.F, S.wood, "pointed")
