extends RefCounted
## Ingleses: arquitectura Tudor y normanda. Casas de entramado oscuro sobre ladrillo rojo, techumbres de paja y de pizarra con
## frontones cruzados, altas chimeneas de ladrillo, ventanas de parteluz, y una fortaleza normanda de piedra gris con keep cuadrado,
## torrecillas y almenas (nada de tejados cónicos). Estandartes del color del jugador; flores en las ventanas.

const A = preload("res://tools/iso/iso_arch.gd")
const M = preload("res://tools/iso/iso_models.gd")
const B = preload("res://tools/iso/iso_build.gd")

func build(type: String, team: Color) -> Node3D:
	return call(type, team) as Node3D

func pal(seed_v: int) -> Dictionary:
	var S := A.plain()
	S["stone"] = A.mat("stone", seed_v, Color(0.60, 0.58, 0.55), 1.1)
	S["stone_d"] = A.mat("stone", seed_v + 1, Color(0.44, 0.43, 0.42), 1.1)
	S["stone_l"] = A.mat("stone", seed_v + 2, Color(0.76, 0.74, 0.70), 1.1)
	S["brick"] = A.mat("brick", seed_v + 3, Color(0.60, 0.26, 0.18), 1.1)
	S["plaster"] = A.mat("plaster", seed_v + 4, Color(0.93, 0.91, 0.84), 1.0)
	S["wood"] = A.mat("wood", seed_v + 5, Color(0.19, 0.13, 0.09), 1.4)
	S["wood_l"] = A.mat("wood", seed_v + 6, Color(0.50, 0.36, 0.20), 1.6)
	S["wood_r"] = A.mat("wood", seed_v + 7, Color(0.18, 0.34, 0.20), 1.4)
	S["roof"] = A.mat("roof", seed_v + 8, Color(0.38, 0.36, 0.37), 1.5)
	S["roof_d"] = A.mat("roof", seed_v + 9, Color(0.28, 0.27, 0.28), 1.5)
	S["thatch"] = A.mat("thatch", seed_v + 10, Color(0.80, 0.66, 0.32), 1.3)
	S["planks"] = A.mat("planks", seed_v + 11, Color(0.46, 0.34, 0.20), 1.4)
	S["F"] = A.fort(seed_v + 20, Color(0.60, 0.58, 0.55), Color(0.42, 0.41, 0.40), Color(0.76, 0.74, 0.70), Color(0.34, 0.32, 0.30), Color(0.30, 0.20, 0.12))
	return S

func _tm(team: Color) -> StandardMaterial3D:
	return M.fmat(team, 0.85, 0.2)

## Chimenea de ladrillo con dos fustes y remates (altura h sobre y).
func _stack(root: Node3D, pos: Vector3, h: float, S: Dictionary) -> void:
	M.box(root, Vector3(0.34, h, 0.22), pos + Vector3(0, h * 0.5, 0), S.brick)
	M.box(root, Vector3(0.40, 0.05, 0.28), pos + Vector3(0, h + 0.025, 0), S.stone_d)
	for dx in [-0.09, 0.09]:
		M.cyl(root, 0.055, 0.06, 0.26, pos + Vector3(dx, h + 0.18, 0), S.brick, 8)
		M.cyl(root, 0.075, 0.07, 0.04, pos + Vector3(dx, h + 0.33, 0), S.stone_d, 8)
	A.smoke_src(root, pos + Vector3(0, h + 0.40, 0))

## Frontón cruzado (hastial que sobresale de un tejado de cumbrera a lo largo de x): z_front = plano de la cara del frontón.
func _cross_gable(root: Node3D, x: float, y_eave: float, z_front: float, w: float, S: Dictionary, roof_m: Material, glass: bool = true) -> void:
	var rise := w * 0.62
	M.prism(root, w, rise, 0.70, Vector3(x, y_eave + rise * 0.5, z_front - 0.35), roof_m)
	var tri := PackedVector2Array([Vector2(-w * 0.5 + 0.05, 0.0), Vector2(w * 0.5 - 0.05, 0.0), Vector2(0.0, rise - 0.08)])
	A.extrude(root, tri, 0.03, Vector3(x, y_eave, z_front - 0.005), S.plaster)
	M.box(root, Vector3(0.05, rise * 0.62, 0.05), Vector3(x, y_eave + rise * 0.31, z_front + 0.02), S.wood)
	M.box(root, Vector3(w * 0.62, 0.05, 0.05), Vector3(x, y_eave + 0.07, z_front + 0.02), S.wood)
	for s in [-1, 1]:
		M.box(root, Vector3(0.05, rise * 0.60, 0.045), Vector3(x + s * w * 0.18, y_eave + rise * 0.27, z_front + 0.02), S.wood).rotation_degrees.z = -s * 33.0
	if glass:
		A.mullion(root, Vector3(x, y_eave + rise * 0.30, z_front + 0.025), 0.20, 0.18, false, S)
	# tablas de viento que rematan el borde del frontón
	for s in [-1, 1]:
		var bd := M.box(root, Vector3(0.05, sqrt(w * w * 0.25 + rise * rise) + 0.04, 0.05), Vector3(x + s * w * 0.25, y_eave + rise * 0.5, z_front + 0.01), S.wood)
		bd.rotation_degrees.z = s * rad_to_deg(atan2(w * 0.5, rise))

## Pináculo de torre: fuste corto con tejadillo piramidal.
func _pinnacle(root: Node3D, pos: Vector3, F: Dictionary, S: Dictionary) -> void:
	M.box(root, Vector3(0.20, 0.34, 0.20), pos + Vector3(0, 0.17, 0), F.light)
	A.pyramid(root, 0.26, 0.28, 0.34, F.dark, pos)

func _flowers(root: Node3D, pos: Vector3, S: Dictionary) -> void:
	M.box(root, Vector3(0.34, 0.08, 0.10), pos + Vector3(0, 0.04, 0), S.wood_l)
	for k in 4:
		M.ball(root, 0.05, pos + Vector3(-0.12 + k * 0.08, 0.12, 0), [S.cloth_y, S.red_fruit, S.cloth_w, S.red_fruit][k] as Material)

# ------------------------------------------------------------------ casa 2x2: cabaña con techumbre de paja

func casa(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(11)
	M.box(root, Vector3(1.56, 0.14, 1.44), Vector3(0, 0.07, 0), S.stone_d)
	M.box(root, Vector3(1.42, 0.64, 1.30), Vector3(0, 0.46, 0), S.plaster)
	A.timber(root, Vector3(0, 0.14, 0.65), 1.42, 0.64, false, S.wood, 0.36)
	A.timber(root, Vector3(0.71, 0.14, 0), 1.30, 0.64, true, S.wood, 0.36)
	B.roof_x(root, 1.84, 1.84, 0.70, 0.78, S.thatch)
	M.cyl(root, 0.08, 0.08, 1.90, Vector3(0, 1.50, 0), S.thatch, 8).rotation_degrees.z = 90.0
	# ceja de paja sobre la puerta
	var brow := M.ball(root, 0.24, Vector3(0.22, 1.00, 0.52), S.thatch, Vector3(1.0, 0.55, 0.9))
	brow.rotation_degrees.x = 18.0
	A.arch_hole(root, Vector3(0.22, 0.14, 0.655), 0.30, 0.42, false, S.wood, S.wood_l, "flat", 0.05)
	A.mullion(root, Vector3(-0.40, 0.52, 0.655), 0.26, 0.22, false, S)
	A.mullion(root, Vector3(0.735, 0.54, 0.22), 0.22, 0.22, true, S)
	A.mullion(root, Vector3(0.735, 0.54, -0.36), 0.22, 0.22, true, S)
	_flowers(root, Vector3(-0.40, 0.30, 0.72), S)
	_stack(root, Vector3(-0.66, 0.96, -0.10), 0.80, S)
	B.banner(root, Vector3(0.50, 0.78, 0.74), team, false, 0.16, 0.38)
	M._flag(root, Vector3(-0.72, 0.0, 0.95), team, 0.95)
	M.ball(root, 0.10, Vector3(0.74, 0.16, 0.90), S.bush, Vector3(1, 0.8, 1))
	return root

# ------------------------------------------------------------------ almacén 2x2: nave de ladrillo con polea

func almacen(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(101)
	M.box(root, Vector3(1.66, 0.14, 1.56), Vector3(0, 0.07, 0), S.stone_d)
	M.box(root, Vector3(1.52, 0.72, 1.40), Vector3(0, 0.50, 0), S.brick)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.10, 0.74, 0.10), Vector3(sx * 0.76, 0.51, sz * 0.70), S.stone_l)
	M.box(root, Vector3(1.60, 0.06, 1.48), Vector3(0, 0.89, 0), S.stone)
	B.roof_x(root, 1.92, 1.84, 0.62, 0.92, S.roof)
	M.box(root, Vector3(1.98, 0.06, 0.08), Vector3(0, 1.55, 0), S.roof_d)
	A.arch_hole(root, Vector3(-0.05, 0.14, 0.705), 0.64, 0.30, false, S.dark, S.stone_l, "round", 0.06)
	for sx in [-1, 1]:
		var leaf := M.box(root, Vector3(0.30, 0.46, 0.04), Vector3(-0.05 + sx * 0.42, 0.38, 0.77), S.wood)
		leaf.rotation_degrees.y = float(sx) * 40.0
	A.mullion(root, Vector3(0.77, 0.56, -0.30), 0.22, 0.20, true, S)
	# polea bajo el alero
	M.box(root, Vector3(0.06, 0.06, 0.44), Vector3(0.50, 1.02, 0.92), S.wood)
	M.cyl(root, 0.045, 0.045, 0.03, Vector3(0.50, 0.98, 1.10), S.iron, 8).rotation_degrees.x = 90.0
	M.box(root, Vector3(0.015, 0.34, 0.015), Vector3(0.50, 0.80, 1.10), S.rope)
	B.barrel(root, Vector3(1.02, 0.0, 0.30), S)
	B.barrel(root, Vector3(1.02, 0.0, 0.58), S)
	B.crate(root, Vector3(0.62, 0.0, 0.92), S, 0.26, 12.0)
	B.sack(root, Vector3(-0.66, 0.0, 0.96), S)
	B.sack(root, Vector3(-0.86, 0.0, 0.86), S, 0.10)
	B.banner(root, Vector3(-0.55, 0.85, 0.80), team, false, 0.18, 0.42)
	M._flag(root, Vector3(-0.72, 0.0, -0.82), team, 0.85)
	return root

# ------------------------------------------------------------------ cuartel 3x3: salón normando con parapeto

func cuartel(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(201)
	var F: Dictionary = S.F
	M.box(root, Vector3(2.46, 0.16, 1.96), Vector3(0, 0.08, -0.28), S.stone_d)
	M.box(root, Vector3(2.34, 0.96, 1.82), Vector3(0, 0.64, -0.28), S.stone)
	M.box(root, Vector3(2.42, 0.07, 1.90), Vector3(0, 1.12, -0.28), S.stone_l)
	M.box(root, Vector3(2.36, 0.03, 1.84), Vector3(0, 1.165, -0.28), F.floor)
	var crown := Node3D.new()
	crown.position = Vector3(0, 0, -0.28)
	root.add_child(crown)
	M._rim(crown, 1.15, 0.90, 1.18, F.light)
	B.roof_x(root, 1.90, 1.20, 0.42, 1.18, S.roof, Vector3(0, 0, -0.28))
	M.box(root, Vector3(1.96, 0.05, 0.07), Vector3(0, 1.62, -0.28), S.roof_d)
	for wz in [-0.85, -0.30, 0.25]:
		A.arch_hole(root, Vector3(1.175, 0.42, wz), 0.14, 0.34, true, S.dark, S.stone_l, "round", 0.03)
	_stack(root, Vector3(0.70, 1.30, -0.60), 0.52, S)
	for sx in [-1, 1]:
		var top := A.tower_sq(root, Vector3(sx * 1.08, 0, 0.84), 0.70, 1.75, F)
		M._flag(root, Vector3(sx * 1.08, top, 0.84), team, 0.55)
	M.box(root, Vector3(1.34, 0.88, 0.34), Vector3(0, 0.58, 0.98), S.stone)
	M.box(root, Vector3(1.40, 0.07, 0.40), Vector3(0, 1.06, 0.98), S.stone_l)
	for k in 5:
		M.box(root, Vector3(0.18, 0.16, 0.34), Vector3(-0.54 + k * 0.27, 1.17, 0.98), S.stone)
	A.arch_hole(root, Vector3(0, 0.14, 1.17), 0.52, 0.34, false, S.dark, S.stone_l, "round", 0.06)
	for k in 5:
		M.box(root, Vector3(0.025, 0.58, 0.03), Vector3(-0.20 + k * 0.10, 0.44, 1.19), S.iron)
	B.banner(root, Vector3(-0.48, 1.0, 1.18), team, false, 0.20, 0.52)
	B.banner(root, Vector3(0.48, 1.0, 1.18), team, false, 0.20, 0.52)
	A.drill_yard(root, S, 1.10, 1.40)
	return root

# ------------------------------------------------------------------ arquería 3x3: salón Tudor y estacas de arqueros

func arqueria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(301)
	var c := Vector3(-0.35, 0, -0.45)
	M.box(root, Vector3(2.10, 0.16, 1.40), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(1.96, 0.34, 1.26), c + Vector3(0, 0.33, 0), S.brick)
	M.box(root, Vector3(2.04, 0.06, 1.32), c + Vector3(0, 0.53, 0), S.wood)
	M.box(root, Vector3(2.02, 0.46, 1.30), c + Vector3(0, 0.79, 0), S.plaster)
	A.timber(root, c + Vector3(0, 0.56, 0.65), 2.02, 0.46, false, S.wood, 0.40)
	A.timber(root, c + Vector3(1.01, 0.56, 0), 1.30, 0.46, true, S.wood, 0.40)
	B.roof_x(root, 2.34, 1.76, 0.66, 1.02, S.roof, c)
	M.box(root, Vector3(2.40, 0.06, 0.08), c + Vector3(0, 1.68, 0), S.roof_d)
	_cross_gable(root, c.x + 0.45, 1.02, c.z + 0.88, 0.80, S, S.roof)
	_stack(root, c + Vector3(-0.80, 1.20, -0.20), 0.58, S)
	A.arch_hole(root, c + Vector3(-0.35, 0.16, 0.635), 0.36, 0.30, false, S.wood, S.stone_l, "flat", 0.05)
	A.mullion(root, c + Vector3(0.0, 0.34, 0.65), 0.22, 0.18, false, S)
	A.mullion(root, c + Vector3(1.015, 0.34, -0.15), 0.22, 0.18, true, S)
	B.banner(root, c + Vector3(-0.80, 0.92, 0.70), team, false, 0.22, 0.46)
	A.archery_field(root, S, _tm(team))
	# estacas de los arqueros ingleses
	for k in 7:
		var st := M.cyl(root, 0.0, 0.035, 0.62, Vector3(-1.30 + k * 0.16, 0.26, 1.28), S.wood_l, 6)
		st.rotation_degrees.x = -22.0
	return root

# ------------------------------------------------------------------ establo 3x3: granero de tablones con paja

func establo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(401)
	var c := Vector3(-0.15, 0, -0.35)
	M.box(root, Vector3(2.30, 0.16, 1.62), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.16, 0.30, 1.48), c + Vector3(0, 0.31, 0), S.stone)
	M.box(root, Vector3(2.16, 0.56, 1.48), c + Vector3(0, 0.74, 0), S.planks)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.10, 0.88, 0.10), c + Vector3(sx * 1.08, 0.60, sz * 0.74), S.wood)
	M.box(root, Vector3(2.24, 0.07, 1.54), c + Vector3(0, 1.04, 0), S.wood)
	B.roof_x(root, 2.50, 1.96, 0.84, 1.06, S.thatch, c)
	M.cyl(root, 0.08, 0.08, 2.54, c + Vector3(0, 1.94, 0), S.thatch, 8).rotation_degrees.z = 90.0
	for sx in [-1, 1]:
		M.box(root, Vector3(0.44, 0.62, 0.05), c + Vector3(sx * 0.24, 0.47, 0.75), S.wood_l)
		M.box(root, Vector3(0.55, 0.04, 0.03), c + Vector3(sx * 0.24, 0.47, 0.79), S.wood).rotation_degrees.z = 50.0 * sx
		M.box(root, Vector3(0.55, 0.04, 0.03), c + Vector3(sx * 0.24, 0.47, 0.79), S.wood).rotation_degrees.z = -50.0 * sx
	M.box(root, Vector3(0.30, 0.26, 0.04), c + Vector3(0.0, 1.28, 0.78), S.dark)
	A.mullion(root, c + Vector3(1.09, 0.62, 0.20), 0.20, 0.20, true, S)
	M.cyl(root, 0.015, 0.015, 0.34, c + Vector3(0.7, 2.26, 0), S.iron, 6)
	M.box(root, Vector3(0.20, 0.12, 0.02), c + Vector3(0.7, 2.44, 0), S.iron)
	A.corral(root, S)
	B.banner(root, c + Vector3(0.70, 0.98, 0.78), team, false, 0.20, 0.48)
	B.banner(root, c + Vector3(-0.78, 0.98, 0.78), team, false, 0.20, 0.48)
	return root

# ------------------------------------------------------------------ taller de asedio 3x3

func taller(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(501)
	var c := Vector3(-0.2, 0, -0.35)
	M.box(root, Vector3(2.30, 0.16, 1.60), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.16, 0.40, 1.46), c + Vector3(0, 0.36, 0), S.brick)
	M.box(root, Vector3(2.22, 0.06, 1.52), c + Vector3(0, 0.59, 0), S.wood)
	M.box(root, Vector3(2.16, 0.50, 1.46), c + Vector3(0, 0.87, 0), S.plaster)
	A.timber(root, c + Vector3(0, 0.62, 0.73), 2.16, 0.50, false, S.wood, 0.42)
	A.timber(root, c + Vector3(1.08, 0.62, 0), 1.46, 0.50, true, S.wood, 0.42)
	B.roof_x(root, 2.46, 1.90, 0.70, 1.12, S.roof, c)
	M.box(root, Vector3(2.52, 0.06, 0.08), c + Vector3(0, 1.82, 0), S.roof_d)
	_stack(root, c + Vector3(0.85, 1.30, -0.30), 0.58, S)
	A.arch_hole(root, c + Vector3(-0.30, 0.16, 0.735), 0.92, 0.36, false, S.wood, S.stone_l, "flat", 0.07)
	for y in [0.30, 0.52]:
		M.box(root, Vector3(0.92, 0.04, 0.06), c + Vector3(-0.30, y, 0.78), S.iron)
	var gear := Node3D.new()
	gear.position = c + Vector3(1.12, 0.84, 0.30)
	gear.rotation_degrees.z = 90.0
	root.add_child(gear)
	M.cyl(gear, 0.26, 0.26, 0.07, Vector3.ZERO, S.wood_l, 20)
	M.cyl(gear, 0.06, 0.06, 0.10, Vector3.ZERO, S.iron, 10)
	for k in 10:
		var a := TAU * float(k) / 10.0
		M.box(gear, Vector3(0.08, 0.07, 0.08), Vector3(cos(a) * 0.28, 0.0, sin(a) * 0.28), S.wood_l).rotation.y = -a
	for k in 4:
		M.box(gear, Vector3(0.50, 0.075, 0.03), Vector3.ZERO, S.wood).rotation.y = float(k) * PI * 0.25
	A.siege_yard(root, S)
	B.banner(root, c + Vector3(0.50, 0.98, 0.80), team, false, 0.20, 0.46)
	B.banner(root, c + Vector3(-1.00, 0.98, 0.80), team, false, 0.20, 0.46)
	return root

# ------------------------------------------------------------------ puerto 3x3: almacén de muelle con grúa de rueda

func puerto(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(601)
	var c := Vector3(0.0, 0, -0.45)
	M.box(root, Vector3(2.30, 0.16, 1.40), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.14, 0.62, 1.26), c + Vector3(0, 0.47, 0), S.brick)
	M.box(root, Vector3(2.20, 0.06, 1.32), c + Vector3(0, 0.81, 0), S.stone)
	B.roof_x(root, 2.46, 1.76, 0.66, 0.84, S.roof, c)
	M.box(root, Vector3(2.52, 0.06, 0.08), c + Vector3(0, 1.52, 0), S.roof_d)
	_cross_gable(root, c.x + 0.45, 0.84, c.z + 0.88, 0.72, S, S.roof, true)
	_stack(root, c + Vector3(-0.85, 1.05, -0.20), 0.52, S)
	for sx in [-1, 1]:
		A.arch_hole(root, c + Vector3(sx * 0.55 - 0.30, 0.16, 0.645), 0.50, 0.30, false, S.dark, S.stone_l, "round", 0.06)
		M.box(root, Vector3(0.40, 0.04, 0.06), c + Vector3(sx * 0.55 - 0.30, 0.40, 0.69), S.wood)
	A.mullion(root, c + Vector3(1.07, 0.52, 0.10), 0.22, 0.22, true, S)
	A.pier(root, S)
	# grúa de rueda (de pisar): rueda de madera con radios junto al muelle
	var wheel := Node3D.new()
	wheel.position = Vector3(-0.95, 0.62, 0.95)
	root.add_child(wheel)
	M.cyl(wheel, 0.40, 0.40, 0.10, Vector3.ZERO, S.wood_l, 18).rotation_degrees.x = 90.0
	M.cyl(wheel, 0.30, 0.30, 0.12, Vector3.ZERO, S.dark, 18).rotation_degrees.x = 90.0
	for k in 6:
		M.box(wheel, Vector3(0.80, 0.05, 0.14), Vector3.ZERO, S.wood).rotation.z = float(k) * PI / 6.0
	for sx in [-1, 1]:
		M.box(root, Vector3(0.07, 1.00, 0.07), Vector3(-0.95 + sx * 0.0, 0.50, 0.95 + sx * 0.14), S.wood)
	B.banner(root, c + Vector3(-0.30, 0.82, 0.70), team, false, 0.22, 0.50)
	M._flag(root, Vector3(1.20, 0.0, 1.30), team, 0.95)
	return root

# ------------------------------------------------------------------ torre 2x2: torre normanda

func torre(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(210)
	var F: Dictionary = S.F
	var top := A.tower_sq(root, Vector3.ZERO, 1.25, 2.6, F, {"door": true})
	var hw := 0.625
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_pinnacle(root, Vector3(sx * (hw + 0.06), top - 0.05, sz * (hw + 0.06)), F, S)
	A.arch_hole(root, Vector3(0.0, 0.20, 0.64), 0.30, 0.22, false, S.wood, F.light, "round", 0.04)
	M._flag(root, Vector3(0.0, top, 0.0), team, 0.75)
	B.banner(root, Vector3(0.0, 2.0, 0.66), team, false, 0.22, 0.60)
	return root

# ------------------------------------------------------------------ monasterio 3x3: iglesia parroquial con torre cuadrada

func _perp_tower(root: Node3D, c: Vector3, w: float, h: float, S: Dictionary, F: Dictionary) -> void:
	M.box(root, Vector3(w + 0.12, 0.18, w + 0.12), c + Vector3(0, 0.09, 0), S.stone_d)
	M.box(root, Vector3(w, h, w), c + Vector3(0, 0.18 + h * 0.5, 0), S.stone_l)
	for k in [0.30, 0.62]:
		M.box(root, Vector3(w + 0.06, 0.05, w + 0.06), c + Vector3(0, 0.18 + h * k, 0), S.stone)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.12, h * 0.98, 0.12), c + Vector3(sx * (w * 0.5), 0.18 + h * 0.49, sz * (w * 0.5)), S.stone)
	var yb := 0.18 + h * 0.74
	A.arch_hole(root, c + Vector3(0, yb, w * 0.5 + 0.005), w * 0.40, h * 0.14, false, S.dark, S.stone, "pointed", 0.03)
	A.arch_hole(root, c + Vector3(w * 0.5 + 0.005, yb, 0), w * 0.40, h * 0.14, true, S.dark, S.stone, "pointed", 0.03)
	A.arch_hole(root, c + Vector3(0, 0.18 + h * 0.40, w * 0.5 + 0.005), w * 0.20, h * 0.16, false, S.glass, S.stone, "pointed", 0.02)
	A.arch_hole(root, c + Vector3(w * 0.5 + 0.005, 0.18 + h * 0.40, 0), w * 0.20, h * 0.16, true, S.glass, S.stone, "pointed", 0.02)
	var yt := 0.18 + h
	M.box(root, Vector3(w + 0.20, 0.10, w + 0.20), c + Vector3(0, yt + 0.05, 0), S.stone)
	var crown := Node3D.new()
	crown.position = c
	root.add_child(crown)
	var hh := (w + 0.20) * 0.5 - 0.065
	M._rim(crown, hh, hh, yt + 0.10, F.light)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_pinnacle(root, c + Vector3(sx * (w * 0.5 + 0.02), yt + 0.05, sz * (w * 0.5 + 0.02)), F, S)

func monasterio(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(701)
	var F: Dictionary = S.F
	var nx := -0.30
	M.box(root, Vector3(1.26, 0.16, 2.30), Vector3(nx, 0.08, -0.35), S.stone_d)
	M.box(root, Vector3(1.12, 0.90, 2.16), Vector3(nx, 0.61, -0.35), S.stone_l)
	M.box(root, Vector3(1.20, 0.06, 2.22), Vector3(nx, 1.09, -0.35), S.stone)
	B.roof_z(root, 2.30, 1.40, 0.56, 1.12, S.roof, Vector3(nx, 0, -0.35))
	M.box(root, Vector3(0.07, 0.05, 2.34), Vector3(nx, 1.70, -0.35), S.roof_d)
	# presbiterio más bajo al fondo
	M.box(root, Vector3(0.86, 0.72, 0.80), Vector3(nx, 0.52, -1.55), S.stone_l)
	B.roof_z(root, 0.90, 1.00, 0.40, 0.88, S.roof, Vector3(nx, 0, -1.55))
	A.arch_hole(root, Vector3(nx, 0.34, -1.145), 0.26, 0.34, false, S.glass, S.stone, "pointed", 0.04)
	# ventanas perpendiculares de parteluz y contrafuertes en la cara +x
	for wz in [-1.00, -0.40, 0.20]:
		A.arch_hole(root, Vector3(nx + 0.565, 0.40, wz), 0.26, 0.40, true, S.glass, S.stone, "pointed", 0.04)
		M.box(root, Vector3(0.12, 0.94, 0.12), Vector3(nx + 0.60, 0.63, wz + 0.30), S.stone)
	# pórtico sur con frontón
	M.box(root, Vector3(0.50, 0.56, 0.50), Vector3(nx + 0.80, 0.44, 0.70), S.stone_l)
	B.roof_x(root, 0.56, 0.58, 0.30, 0.72, S.roof, Vector3(nx + 0.80, 0, 0.70))
	A.arch_hole(root, Vector3(nx + 0.80, 0.16, 0.955), 0.26, 0.26, false, S.wood, S.stone, "pointed", 0.04)
	# torre occidental con almenas y pináculos
	_perp_tower(root, Vector3(nx, 0, 1.00), 0.86, 1.85, S, F)
	A.arch_hole(root, Vector3(nx, 0.18, 1.435), 0.40, 0.40, false, S.wood, S.stone, "pointed", 0.06)
	M._flag(root, Vector3(nx, 2.25, 1.00), team, 0.70)
	B.banner(root, Vector3(nx - 0.58, 0.90, 1.38), team, false, 0.16, 0.54)
	B.banner(root, Vector3(nx + 0.58, 0.90, 1.38), team, false, 0.16, 0.54)
	# cementerio: muro bajo, lápidas y tejo
	M.box(root, Vector3(0.90, 0.04, 1.10), Vector3(1.05, 0.02, -0.40), S.stone_d)
	for k in 5:
		var gx := 0.80 + (k % 2) * 0.35
		var gz := -0.80 + k * 0.30
		M.box(root, Vector3(0.10, 0.20, 0.04), Vector3(gx, 0.14, gz), S.stone_l)
	M.lump(root, 0.28, Vector3(1.28, 0.40, -0.95), M.fmat(Color(0.10, 0.26, 0.12), 0.95, 0.1), 77, 0.25, 1.3)
	return root

# ------------------------------------------------------------------ castillo 4x4: fortaleza normanda

func castillo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(110)
	var F: Dictionary = S.F
	M.box(root, Vector3(3.5, 0.06, 3.5), Vector3(0, 0.03, 0), A.mat("plaster", 119, Color(0.60, 0.55, 0.40), 1.2))
	var wh := 1.30
	A.wall_block(root, F, 3.0, wh, 0.50, Vector3(0, 0, -1.55))
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(-1.55, 0, 0))
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(1.55, 0, 0))
	A.wall_block(root, F, 1.05, wh, 0.50, Vector3(-0.975, 0, 1.55))
	A.wall_block(root, F, 1.05, wh, 0.50, Vector3(0.975, 0, 1.55))
	# portal de entrada con rastrillo y dos torrecillas
	M.box(root, Vector3(0.90, 0.38, 0.52), Vector3(0, wh - 0.19, 1.55), F.wall)
	M.box(root, Vector3(0.94, 0.05, 0.56), Vector3(0, wh + 0.025, 1.55), F.light)
	M.box(root, Vector3(0.90, 0.92, 0.30), Vector3(0, 0.46, 1.50), F.slit)
	for sx in [-1, 1]:
		var leaf := M.box(root, Vector3(0.40, 0.84, 0.05), Vector3(sx * 0.30, 0.43, 1.79), F.wood)
		leaf.rotation_degrees.y = float(sx) * -62.0
		A.tower_sq(root, Vector3(sx * 0.66, 0, 1.78), 0.50, 1.80, F)
	for k in 5:
		M.box(root, Vector3(0.025, 0.86, 0.03), Vector3(-0.20 + k * 0.10, 0.45, 1.50), F.trim)
	# torres cuadradas de las esquinas
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			A.tower_sq(root, Vector3(sx * 1.55, 0, sz * 1.55), 1.05, 2.30, F)
	# keep normando: bloque macizo con contrafuertes de esquina más altos, ventanas de medio punto y antepuerta
	var kc := Vector3(0.0, 0, -0.30)
	M.box(root, Vector3(2.00, 0.22, 1.80), kc + Vector3(0, 0.11, 0), F.dark)
	M.box(root, Vector3(1.86, 2.50, 1.66), kc + Vector3(0, 1.47, 0), F.wall)
	M.box(root, Vector3(2.04, 0.14, 1.84), kc + Vector3(0, 2.76, 0), F.dark)
	M.box(root, Vector3(1.96, 0.04, 1.76), kc + Vector3(0, 2.85, 0), F.floor)
	var crown := Node3D.new()
	crown.position = kc
	root.add_child(crown)
	M._rim(crown, 0.98, 0.88, 2.85, F.light)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var tp := kc + Vector3(sx * 0.93, 0, sz * 0.83)
			M.box(root, Vector3(0.40, 3.10, 0.40), tp + Vector3(0, 1.55, 0), F.wall)
			M.box(root, Vector3(0.50, 0.12, 0.50), tp + Vector3(0, 3.16, 0), F.dark)
			var tr := Node3D.new()
			tr.position = tp
			root.add_child(tr)
			M._rim(tr, 0.20, 0.20, 3.22, F.light, 0.20)
	for wx in [-0.45, 0.45]:
		A.arch_hole(root, kc + Vector3(wx, 1.30, 0.835), 0.18, 0.40, false, S.dark, F.light, "round", 0.04)
		A.arch_hole(root, kc + Vector3(wx, 2.05, 0.835), 0.16, 0.30, false, S.dark, F.light, "round", 0.04)
	for wz in [-0.30, 0.35]:
		A.arch_hole(root, kc + Vector3(0.935, 1.30, wz), 0.18, 0.40, true, S.dark, F.light, "round", 0.04)
		A.arch_hole(root, kc + Vector3(0.935, 2.05, wz), 0.16, 0.30, true, S.dark, F.light, "round", 0.04)
	# antepuerta con escalera
	M.box(root, Vector3(0.70, 1.00, 0.50), kc + Vector3(-0.20, 0.50, 1.05), F.wall)
	for k in 4:
		M.box(root, Vector3(0.70, 0.12 * (k + 1), 0.14), kc + Vector3(-0.20, 0.06 * (k + 1), 1.38 + k * 0.10), F.dark)
	A.arch_hole(root, kc + Vector3(-0.20, 0.55, 1.305), 0.30, 0.36, false, S.wood, F.light, "round", 0.05)
	M._flag(root, kc + Vector3(0.0, 2.85, 0.0), team, 1.1)
	B.banner(root, kc + Vector3(0.45, 2.10, 0.86), team, false, 0.28, 0.80)
	B.banner(root, kc + Vector3(-0.60, 2.10, 0.86), team, false, 0.28, 0.80)
	M._flag(root, Vector3(-1.2, 1.30, 1.55), team, 0.9)
	return root

# ------------------------------------------------------------------ herrería 3x3

func herreria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(801)
	var c := Vector3(-0.2, 0, -0.35)
	M.box(root, Vector3(2.20, 0.16, 1.56), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.04, 0.90, 1.40), c + Vector3(0, 0.61, 0), S.brick)
	M.box(root, Vector3(2.10, 0.06, 1.46), c + Vector3(0, 1.09, 0), S.stone)
	B.roof_x(root, 2.34, 1.80, 0.60, 1.12, S.roof, c)
	M.box(root, Vector3(2.40, 0.06, 0.08), c + Vector3(0, 1.74, 0), S.roof_d)
	# gran chimenea de ladrillo con dos fustes
	M.box(root, Vector3(0.56, 1.90, 0.56), c + Vector3(1.20, 0.95, -0.30), S.brick)
	M.box(root, Vector3(0.66, 0.07, 0.66), c + Vector3(1.20, 1.90, -0.30), S.stone_d)
	for dz in [-0.13, 0.13]:
		M.cyl(root, 0.09, 0.10, 0.34, c + Vector3(1.20, 2.10, -0.30 + dz), S.brick, 8)
		M.cyl(root, 0.12, 0.11, 0.04, c + Vector3(1.20, 2.29, -0.30 + dz), S.stone_d, 8)
	A.smoke_src(root, c + Vector3(1.20, 2.40, -0.30))
	M.box(root, Vector3(0.10, 0.30, 0.34), c + Vector3(1.50, 0.34, -0.30), S.fire)
	M.box(root, Vector3(0.10, 0.36, 0.40), c + Vector3(1.49, 0.32, -0.30), S.dark)
	M.box(root, Vector3(0.12, 0.26, 0.28), c + Vector3(1.51, 0.34, -0.30), S.fire)
	A.arch_hole(root, c + Vector3(-0.40, 0.16, 0.705), 0.80, 0.36, false, S.dark, S.stone_l, "flat", 0.07)
	M.box(root, Vector3(0.20, 0.20, 0.03), c + Vector3(-0.60, 0.30, 0.70), S.fire)
	A.mullion(root, c + Vector3(0.45, 0.66, 0.705), 0.26, 0.24, false, S)
	for k in 3:
		M.box(root, Vector3(0.025, 0.34, 0.012), c + Vector3(1.0, 0.64, 0.20 + k * 0.14), S.steel)
	A.forge_yard(root, S)
	B.banner(root, c + Vector3(0.40, 0.98, 0.72), team, false, 0.20, 0.42)
	B.banner(root, c + Vector3(-1.00, 0.98, 0.72), team, false, 0.20, 0.42)
	return root

# ------------------------------------------------------------------ mercado 3x3: casa del mercado con cruz

func mercado(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(901)
	var tm := _tm(team)
	M.box(root, Vector3(2.70, 0.10, 2.70), Vector3(0, 0.05, 0), S.stone_l)
	M.box(root, Vector3(2.50, 0.04, 2.50), Vector3(0, 0.12, 0), S.stone)
	# casa del mercado: piso alto de entramado sobre postes de piedra (soportal abierto)
	for px in [-1.05, -0.35, 0.35, 1.05]:
		for pz in [-1.30, -0.35]:
			M.cyl(root, 0.07, 0.08, 0.80, Vector3(px, 0.54, pz), S.stone_d, 8)
	M.box(root, Vector3(2.50, 0.10, 1.20), Vector3(0, 0.99, -0.82), S.wood)
	M.box(root, Vector3(2.40, 0.50, 1.10), Vector3(0, 1.29, -0.82), S.plaster)
	A.timber(root, Vector3(0, 1.04, -0.27), 2.40, 0.50, false, S.wood, 0.40)
	A.timber(root, Vector3(1.20, 1.04, -0.82), 1.10, 0.50, true, S.wood, 0.40)
	B.roof_x(root, 2.62, 1.50, 0.58, 1.54, S.roof, Vector3(0, 0, -0.82))
	M.box(root, Vector3(2.68, 0.06, 0.08), Vector3(0, 2.12, -0.82), S.roof_d)
	for wx in [-0.80, 0.0, 0.80]:
		A.mullion(root, Vector3(wx, 1.30, -0.265), 0.28, 0.26, false, S)
	for tx in [-0.70, 0.70]:
		M.box(root, Vector3(0.70, 0.24, 0.30), Vector3(tx, 0.26, -0.82), S.wood_l)
		for k in 4:
			M.ball(root, 0.06, Vector3(tx - 0.24 + k * 0.16, 0.42, -0.82), [S.red_fruit, S.green_fruit, S.orange_fruit, S.red_fruit][k] as Material, Vector3(1, 0.9, 1))
	# cruz del mercado: peldaños, fuste y cruz
	for k in 3:
		M.box(root, Vector3(0.80 - k * 0.20, 0.08, 0.80 - k * 0.20), Vector3(0.0, 0.16 + k * 0.08, 0.55), S.stone if k % 2 == 0 else S.stone_d)
	M.cyl(root, 0.06, 0.08, 0.80, Vector3(0.0, 0.76, 0.55), S.stone_l, 8)
	M.box(root, Vector3(0.28, 0.06, 0.28), Vector3(0.0, 1.18, 0.55), S.stone)
	A.cross_fin(root, Vector3(0.0, 1.20, 0.55), 0.34, S.stone_l)
	B.puesto(root, Vector3(-0.95, 0.10, 0.80), 90.0, tm, [S.red_fruit, S.green_fruit, S.red_fruit, S.orange_fruit], S)
	B.puesto(root, Vector3(0.95, 0.10, 0.85), -90.0, S.cloth_g, [S.orange_fruit, S.orange_fruit, S.green_fruit, S.red_fruit], S)
	M._flag(root, Vector3(-0.30, 0.10, 1.25), team, 1.30)
	B.crate(root, Vector3(1.10, 0.10, 0.20), S, 0.26, 12.0)
	B.barrel(root, Vector3(-1.10, 0.10, 0.25), S)
	B.sack(root, Vector3(0.60, 0.10, 1.15), S)
	B.sack(root, Vector3(0.38, 0.10, 1.10), S, 0.10)
	return root

# ------------------------------------------------------------------ centro urbano 3x3: casa solariega Tudor

func centro(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(21)
	var F: Dictionary = S.F
	M.box(root, Vector3(2.62, 0.20, 2.50), Vector3(0, 0.10, 0), S.stone_d)
	M.box(root, Vector3(2.42, 0.72, 2.28), Vector3(0, 0.56, 0), S.brick)
	M.box(root, Vector3(2.50, 0.08, 2.36), Vector3(0, 0.96, 0), S.wood)
	M.box(root, Vector3(2.46, 0.58, 2.32), Vector3(0, 1.29, 0), S.plaster)
	A.timber(root, Vector3(0, 1.00, 1.16), 2.46, 0.58, false, S.wood, 0.36)
	A.timber(root, Vector3(1.23, 1.00, 0), 2.32, 0.58, true, S.wood, 0.36)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.12, 0.70, 0.12), Vector3(sx * 1.23, 1.25, sz * 1.16), S.wood)
	B.roof_x(root, 2.70, 2.50, 0.90, 1.58, S.roof)
	M.box(root, Vector3(2.76, 0.07, 0.09), Vector3(0, 2.48, 0), S.roof_d)
	_cross_gable(root, -0.62, 1.58, 1.20, 0.86, S, S.roof)
	_cross_gable(root, 0.55, 1.58, 1.20, 0.86, S, S.roof)
	_stack(root, Vector3(-0.90, 1.80, -0.40), 0.95, S)
	_stack(root, Vector3(0.80, 1.80, -0.40), 0.95, S)
	# portal de piedra con arco apuntado, ventanas de parteluz y mirador (oriel) en el piso alto
	A.arch_hole(root, Vector3(-0.05, 0.20, 1.145), 0.50, 0.34, false, S.wood, S.stone_l, "round", 0.07)
	for wx in [-0.80, 0.70]:
		A.mullion(root, Vector3(wx, 0.62, 1.145), 0.30, 0.28, false, S)
	for wz in [-0.7, 0.0, 0.7]:
		A.mullion(root, Vector3(1.215, 0.62, wz), 0.24, 0.28, true, S)
		A.mullion(root, Vector3(1.235, 1.28, wz), 0.24, 0.26, true, S)
	M.box(root, Vector3(0.70, 0.44, 0.22), Vector3(-0.62, 1.30, 1.27), S.wood)
	A.mullion(root, Vector3(-0.62, 1.30, 1.385), 0.50, 0.28, false, S)
	A.shield(root, Vector3(-0.05, 0.86, 1.15), 0.14, false, S.gold, _tm(team))
	# torre de entrada de ladrillo con almenas y pináculos
	var tc := Vector3(0.82, 0, -0.80)
	M.box(root, Vector3(0.80, 1.74, 0.80), tc + Vector3(0, 1.0, 0), S.brick)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.12, 1.74, 0.12), tc + Vector3(sx * 0.40, 1.0, sz * 0.40), S.stone_l)
	M.box(root, Vector3(0.92, 0.10, 0.92), tc + Vector3(0, 1.92, 0), S.stone)
	var crown := Node3D.new()
	crown.position = tc
	root.add_child(crown)
	M._rim(crown, 0.40, 0.40, 1.97, F.light, 0.20)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_pinnacle(root, tc + Vector3(sx * 0.40, 1.95, sz * 0.40), F, S)
	A.mullion(root, tc + Vector3(0.405, 1.30, 0.0), 0.20, 0.26, true, S)
	A.mullion(root, tc + Vector3(0.0, 1.30, 0.405), 0.20, 0.26, false, S)
	M._flag(root, tc + Vector3(0, 2.0, 0), team, 0.9)
	B.banner(root, Vector3(0.50, 0.90, 1.18), team, false, 0.20, 0.50)
	M._flag(root, Vector3(1.18, 0.0, 1.35), team, 1.2)
	return root

# ------------------------------------------------------------------ murallas

func wall_post() -> Node3D:
	return A.wall_post(pal(250).F)

func wall_arm(d: int) -> Node3D:
	return A.wall_arm(d, pal(250).F)

func gate(along_x: bool) -> Node3D:
	var S := pal(260)
	return A.wall_gate(along_x, S.F, S.wood, "round")
