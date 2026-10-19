extends RefCounted
## Mongoles: campamento de la estepa y ordos del Gran Kan. Yurtas (gers) de fieltro con cintas de color y puerta naranja, estandartes
## con nueve colas de caballo (tuğ), caballos atados, pabellones de lacado rojo con tejados curvos de teja dorada y turquesa
## (influencia Yuan), estupas blancas en el templo, muros de tapia con albardilla de teja, y juncos con velas de listones en el
## puerto. El fieltro de los techos y los paños llevan el color del jugador.

const A = preload("res://tools/iso/iso_arch.gd")
const M = preload("res://tools/iso/iso_models.gd")
const B = preload("res://tools/iso/iso_build.gd")

func build(type: String, team: Color) -> Node3D:
	return call(type, team) as Node3D

func pal(seed_v: int) -> Dictionary:
	var S := A.plain()
	S["felt"] = A.mat("felt", seed_v + 1, Color(0.90, 0.85, 0.72), 1.3)
	S["felt_d"] = A.mat("felt", seed_v + 2, Color(0.60, 0.52, 0.38), 1.3)
	S["red"] = A.mat("wood", seed_v + 3, Color(0.58, 0.14, 0.10), 1.4)
	S["orange"] = A.mat("wood", seed_v + 4, Color(0.82, 0.42, 0.12), 1.4)
	S["wood"] = A.mat("wood", seed_v + 5, Color(0.28, 0.18, 0.10), 1.4)
	S["wood_l"] = A.mat("wood", seed_v + 6, Color(0.56, 0.40, 0.22), 1.6)
	S["gold"] = M.fmat(Color(0.88, 0.64, 0.18), 0.45, 0.7)
	S["teal"] = A.mat("roof", seed_v + 7, Color(0.12, 0.46, 0.52), 1.5)
	S["gold_roof"] = A.mat("roof", seed_v + 8, Color(0.82, 0.60, 0.16), 1.5)
	S["earth"] = A.mat("stone", seed_v + 9, Color(0.64, 0.49, 0.32), 1.2)
	S["earth_d"] = A.mat("stone", seed_v + 10, Color(0.46, 0.35, 0.23), 1.2)
	S["stone"] = A.mat("stone", seed_v + 11, Color(0.66, 0.62, 0.55), 1.2)
	S["stone_d"] = A.mat("stone", seed_v + 12, Color(0.48, 0.45, 0.40), 1.2)
	S["white"] = A.mat("plaster", seed_v + 13, Color(0.94, 0.92, 0.86), 1.0)
	S["horse_b"] = M.fmat(Color(0.48, 0.30, 0.17), 0.95, 0.1)
	S["horse_w"] = M.fmat(Color(0.90, 0.88, 0.80), 0.95, 0.1)
	S["horse_k"] = M.fmat(Color(0.20, 0.14, 0.11), 0.95, 0.1)
	S["tail"] = M.fmat(Color(0.14, 0.10, 0.08), 0.95, 0.1)
	var F := A.fort(seed_v + 20, Color(0.64, 0.49, 0.32), Color(0.46, 0.35, 0.23), Color(0.76, 0.62, 0.42), Color(0.12, 0.46, 0.52), Color(0.28, 0.18, 0.10), "stone")
	S["F"] = F
	return S

func _tm(team: Color) -> StandardMaterial3D:
	return M.fmat(team, 0.85, 0.2)

## Yurta (ger): pared de fieltro, cinta del color del jugador, cintura de cuerda, techo cónico con aro de humo y puerta naranja.
## door_deg: giro de la puerta alrededor del eje y (45° = mira a la cámara entre +x y +z).
func _ger(root: Node3D, S: Dictionary, pos: Vector3, r: float, h: float, roof_h: float, team: Color, door_deg: float = 45.0) -> void:
	M.cyl(root, r * 1.04, r * 1.06, 0.06, pos + Vector3(0, 0.03, 0), S.wood, 18)
	M.cyl(root, r, r, h, pos + Vector3(0, 0.06 + h * 0.5, 0), S.felt, 20)
	M.cyl(root, r * 1.015, r * 1.015, 0.035, pos + Vector3(0, 0.06 + h * 0.45, 0), S.rope, 20)
	M.cyl(root, r * 1.03, r * 1.03, 0.07, pos + Vector3(0, 0.06 + h * 0.92, 0), _tm(team), 20)
	var y0 := 0.06 + h
	A.lathe(root, [Vector2(r * 1.14, 0.0), Vector2(r * 0.96, roof_h * 0.12), Vector2(r * 0.62, roof_h * 0.46), Vector2(r * 0.30, roof_h * 0.78), Vector2(r * 0.19, roof_h * 0.95), Vector2(r * 0.16, roof_h)], 20, pos + Vector3(0, y0, 0), S.felt)
	M.cyl(root, r * 0.18, r * 0.18, 0.025, pos + Vector3(0, y0 + roof_h + 0.005, 0), S.dark, 12)
	M.cyl(root, r * 0.21, r * 0.19, 0.04, pos + Vector3(0, y0 + roof_h - 0.02, 0), S.wood, 12)
	A.smoke_src(root, pos + Vector3(0, y0 + roof_h + 0.06, 0))
	# bandas del techo del color del fieltro oscuro
	for k in 3:
		var a := TAU * (float(k) + 0.5) / 3.0 + deg_to_rad(door_deg)
		var rb := M.box(root, Vector3(0.025, 0.02, roof_h * 1.02), pos + Vector3(sin(a) * r * 0.64, y0 + roof_h * 0.48, cos(a) * r * 0.64), S.rope)
		rb.rotation = Vector3(deg_to_rad(-52.0), a, 0.0)
		rb.rotation_order = EULER_ORDER_YXZ
	# puerta
	var piv := Node3D.new()
	piv.position = pos
	piv.rotation_degrees.y = door_deg
	root.add_child(piv)
	M.box(piv, Vector3(r * 0.46, h * 0.80, 0.05), Vector3(0, 0.06 + h * 0.40, r + 0.012), S.orange)
	M.box(piv, Vector3(r * 0.54, 0.05, 0.06), Vector3(0, 0.06 + h * 0.82, r + 0.012), S.red)
	M.box(piv, Vector3(0.03, h * 0.80, 0.06), Vector3(-r * 0.25, 0.06 + h * 0.40, r + 0.012), S.red)
	M.box(piv, Vector3(0.03, h * 0.80, 0.06), Vector3(r * 0.25, 0.06 + h * 0.40, r + 0.012), S.red)
	M.box(piv, Vector3(0.02, h * 0.80, 0.04), Vector3(0, 0.06 + h * 0.40, r + 0.03), S.red)

## Estandarte con nueve colas de caballo (tuğ) y gallardete del color del jugador.
func _tug(root: Node3D, S: Dictionary, pos: Vector3, h: float, team: Color) -> void:
	M.cyl(root, 0.022, 0.03, h, pos + Vector3(0, h * 0.5, 0), S.wood, 6)
	M.box(root, Vector3(0.30, 0.03, 0.03), pos + Vector3(0, h * 0.84, 0), S.wood)
	M.ball(root, 0.05, pos + Vector3(0, h + 0.03, 0), S.gold)
	A.cone(root, 0.035, 0.12, h + 0.07, S.gold, pos, 6)
	for k in 9:
		var a := TAU * float(k) / 9.0
		var tx := cos(a) * 0.05
		var tz := sin(a) * 0.05
		M.box(root, Vector3(0.022, 0.30, 0.022), pos + Vector3(tx, h * 0.84 - 0.12, tz), S.tail if k % 2 == 0 else S.horse_w)
	M.box(root, Vector3(0.26, 0.15, 0.012), pos + Vector3(0.14, h * 0.66, 0.0), _tm(team))

## Caballo: cuerpo, cuello, cabeza, crin, cola y cuatro patas (mira a +x antes de aplicar yaw).
func _horse(root: Node3D, S: Dictionary, pos: Vector3, yaw: float, coat: Material, s: float = 1.0) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = yaw
	holder.scale = Vector3.ONE * s
	root.add_child(holder)
	M.ball(holder, 0.13, Vector3(0, 0.30, 0), coat, Vector3(1.9, 0.85, 0.75))
	for sx in [-0.17, 0.17]:
		for sz in [-0.05, 0.05]:
			M.cyl(holder, 0.016, 0.022, 0.24, Vector3(sx, 0.12, sz), coat, 6)
	var neck := M.cyl(holder, 0.03, 0.05, 0.26, Vector3(0.24, 0.44, 0), coat, 6)
	neck.rotation_degrees.z = -34.0
	M.ball(holder, 0.04, Vector3(0.34, 0.54, 0), coat, Vector3(1.6, 0.9, 0.8))
	M.box(holder, Vector3(0.04, 0.12, 0.02), Vector3(0.20, 0.52, 0), S.tail)
	var tail := M.box(holder, Vector3(0.03, 0.20, 0.03), Vector3(-0.26, 0.26, 0), S.tail)
	tail.rotation_degrees.z = 25.0
	M.box(holder, Vector3(0.20, 0.025, 0.14), Vector3(0.0, 0.405, 0), S.felt_d)

## Cubierta curva (techo chino de esquinas elevadas) de lado w y altura h sobre el nivel y.
func _pagoda(root: Node3D, pos: Vector3, w: float, h: float, m: Material) -> void:
	A.lathe(root, A.pagoda_prof(w * 0.7071, h), 4, pos, m, false, PI * 0.25)

## Pabellón de lacado rojo: base de piedra, columnas, muros, puerta y tejado doble curvo.
func _pavilion(root: Node3D, S: Dictionary, c: Vector3, w: float, d: float, wh: float, roof_h: float, roof_m: Material, team: Color, doors: bool = true) -> float:
	M.box(root, Vector3(w + 0.24, 0.16, d + 0.24), c + Vector3(0, 0.08, 0), S.stone)
	M.box(root, Vector3(w + 0.30, 0.04, d + 0.30), c + Vector3(0, 0.18, 0), S.stone_d)
	M.box(root, Vector3(w, wh, d), c + Vector3(0, 0.20 + wh * 0.5, 0), S.red)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.cyl(root, 0.06, 0.06, wh + 0.02, c + Vector3(sx * w * 0.5, 0.20 + wh * 0.5, sz * d * 0.5), S.orange, 8)
	M.box(root, Vector3(w + 0.10, 0.07, d + 0.10), c + Vector3(0, 0.20 + wh + 0.035, 0), S.teal)
	var ye := 0.20 + wh + 0.07
	_pagoda(root, c + Vector3(0, ye, 0), maxf(w, d) + 0.60, roof_h, roof_m)
	if doors:
		var zf := c.z + d * 0.5 + 0.005
		M.box(root, Vector3(w * 0.34, wh * 0.78, 0.04), Vector3(c.x, 0.20 + wh * 0.39, zf + 0.02), S.wood)
		M.box(root, Vector3(0.025, wh * 0.78, 0.05), Vector3(c.x, 0.20 + wh * 0.39, zf + 0.04), S.gold)
		for wx in [-0.30, 0.30]:
			M.box(root, Vector3(0.16, 0.20, 0.03), Vector3(c.x + wx * w * 0.9, 0.20 + wh * 0.55, zf + 0.02), S.wood)
		M.box(root, Vector3(0.03, 0.20, 0.16), Vector3(c.x + w * 0.5 + 0.015, 0.20 + wh * 0.55, c.z), S.wood)
	B.banner(root, Vector3(c.x + w * 0.5 - 0.12, 0.20 + wh * 0.94, c.z + d * 0.5 + 0.03), team, false, 0.16, wh * 0.50)
	return ye + roof_h

# ------------------------------------------------------------------ casa 2x2: yurta familiar

func casa(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(11)
	_ger(root, S, Vector3(0.0, 0, -0.10), 0.60, 0.62, 0.40, team)
	_tug(root, S, Vector3(0.78, 0, 0.62), 0.95, team)
	B.barrel(root, Vector3(-0.78, 0.0, 0.62), S)
	B.crate(root, Vector3(-0.64, 0.0, 0.84), S, 0.20, 12.0)
	M.box(root, Vector3(0.30, 0.04, 0.22), Vector3(0.62, 0.02, -0.74), S.cloth_r)
	return root

# ------------------------------------------------------------------ almacén 2x2: yurta de provisiones y carreta

func almacen(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(101)
	_ger(root, S, Vector3(-0.15, 0, -0.18), 0.64, 0.50, 0.34, team)
	# carreta con toldo de fieltro: caja, ruedas y arco de fieltro
	var cc := Vector3(0.62, 0, 0.55)
	M.box(root, Vector3(0.54, 0.10, 0.36), cc + Vector3(0, 0.26, 0), S.wood_l)
	for sz in [-1, 1]:
		M.cyl(root, 0.16, 0.16, 0.04, cc + Vector3(0, 0.16, sz * 0.21), S.wood, 12).rotation_degrees.x = 90.0
	var arc := M.cyl(root, 0.17, 0.17, 0.50, cc + Vector3(0, 0.31, 0), S.felt, 12)
	arc.rotation_degrees.z = 90.0
	arc.scale = Vector3(1.0, 1.0, 0.8)
	M.box(root, Vector3(0.54, 0.16, 0.40), cc + Vector3(0, 0.22, 0), S.felt_d)
	B.sack(root, Vector3(-0.10, 0.0, 0.86), S)
	B.sack(root, Vector3(-0.28, 0.0, 0.78), S, 0.10)
	B.barrel(root, Vector3(0.14, 0.0, 0.86), S)
	_tug(root, S, Vector3(-0.85, 0, 0.70), 0.80, team)
	return root

# ------------------------------------------------------------------ cuartel 3x3: campamento de guerra

func cuartel(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(201)
	_ger(root, S, Vector3(-0.30, 0, -0.35), 0.82, 0.76, 0.52, team)
	_ger(root, S, Vector3(0.95, 0, -0.55), 0.46, 0.44, 0.30, team, 30.0)
	_ger(root, S, Vector3(-1.15, 0, 0.40), 0.42, 0.42, 0.28, team, 60.0)
	_tug(root, S, Vector3(0.45, 0, 0.88), 1.20, team)
	# caballete de lanzas y escudos de mimbre
	for k in 4:
		var sp := M.box(root, Vector3(0.025, 0.80, 0.025), Vector3(-0.20 + k * 0.10, 0.40, 0.95), S.wood_l)
		sp.rotation_degrees.x = -8.0
		M.cyl(root, 0.0, 0.025, 0.10, Vector3(-0.20 + k * 0.10, 0.82, 0.90), S.steel, 4)
	for k in 3:
		A.shield(root, Vector3(0.55 + k * 0.24, 0.20, 0.30 - k * 0.04), 0.09, false, S.wood, _tm(team) if k % 2 == 0 else S.cloth_y)
	_horse(root, S, Vector3(1.05, 0.0, 0.55), 70.0, S.horse_b, 0.9)
	A.drill_yard(root, S, 1.10, 1.40)
	return root

# ------------------------------------------------------------------ arquería 3x3: pabellón abierto de tiro

func arqueria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(301)
	var c := Vector3(-0.45, 0, -0.45)
	M.box(root, Vector3(1.90, 0.12, 1.30), c + Vector3(0, 0.06, 0), S.wood_l)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.cyl(root, 0.05, 0.05, 0.86, c + Vector3(sx * 0.85, 0.55, sz * 0.55), S.red, 8)
	# toldo de fieltro a dos aguas con faldón del color del jugador
	B.roof_x(root, 2.10, 1.50, 0.46, 0.96, S.felt, c)
	M.box(root, Vector3(2.12, 0.05, 0.05), c + Vector3(0, 0.96 + 0.46, 0), S.gold)
	M.box(root, Vector3(2.04, 0.14, 0.03), c + Vector3(0, 0.90, 0.67), _tm(team))
	M.box(root, Vector3(0.03, 0.14, 1.34), c + Vector3(0.96, 0.90, 0.0), _tm(team))
	# armero con arcos y carcajes dentro del pabellón
	for k in 3:
		M.box(root, Vector3(0.03, 0.60, 0.03), c + Vector3(-0.60 + k * 0.12, 0.42, -0.30), S.wood_l)
		M.box(root, Vector3(0.07, 0.24, 0.07), c + Vector3(-0.20 + k * 0.10, 0.26, -0.30), S.felt_d)
	_horse(root, S, Vector3(0.95, 0.0, 1.20), 90.0, S.horse_w, 0.9)
	A.archery_field(root, S, _tm(team))
	_tug(root, S, Vector3(-1.30, 0, 0.40), 0.95, team)
	return root

# ------------------------------------------------------------------ establo 3x3: cerca de caballos y cobertizo

func establo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(401)
	var c := Vector3(-0.30, 0, -0.55)
	# cobertizo de fieltro apoyado en postes, abierto al frente
	for sx in [-1, 1]:
		M.cyl(root, 0.05, 0.05, 0.84, c + Vector3(sx * 0.90, 0.42, 0.45), S.wood, 8)
		M.cyl(root, 0.05, 0.05, 1.10, c + Vector3(sx * 0.90, 0.55, -0.45), S.wood, 8)
	var roof := M.box(root, Vector3(2.10, 0.06, 1.20), c + Vector3(0, 0.98, 0.0), S.felt)
	roof.rotation_degrees.x = 14.0
	M.box(root, Vector3(2.12, 0.07, 0.14), c + Vector3(0, 0.86, 0.60), _tm(team))
	M.box(root, Vector3(1.90, 0.60, 0.04), c + Vector3(0, 0.32, -0.55), S.felt_d)
	M.box(root, Vector3(0.10, 0.60, 1.00), c + Vector3(-0.98, 0.32, 0.0), S.felt_d)
	for k in 3:
		M.box(root, Vector3(0.60, 0.20, 0.30), c + Vector3(-0.50 + k * 0.50, 0.10, -0.30), S.hay)
	# caballos atados
	_horse(root, S, Vector3(-0.60, 0.0, 0.50), 90.0, S.horse_b)
	_horse(root, S, Vector3(0.10, 0.0, 0.62), 80.0, S.horse_w)
	_horse(root, S, Vector3(0.80, 0.0, 0.50), 100.0, S.horse_k)
	A.corral(root, S)
	_tug(root, S, Vector3(-1.20, 0, 0.80), 0.90, team)
	return root

# ------------------------------------------------------------------ taller de asedio 3x3: tienda taller con ingenio

func taller(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(501)
	var c := Vector3(-0.30, 0, -0.40)
	# tienda rectangular de fieltro con cumbrera de madera y faldón del color del jugador
	M.box(root, Vector3(1.80, 0.60, 1.30), c + Vector3(0, 0.30, 0), S.felt)
	B.roof_x(root, 1.98, 1.50, 0.64, 0.60, S.felt, c)
	M.cyl(root, 0.04, 0.04, 2.04, c + Vector3(0, 1.25, 0), S.wood, 6).rotation_degrees.z = 90.0
	M.box(root, Vector3(1.84, 0.10, 1.34), c + Vector3(0, 0.62, 0), _tm(team))
	M.box(root, Vector3(0.66, 0.54, 0.04), c + Vector3(-0.30, 0.28, 0.66), S.dark)
	M.box(root, Vector3(0.70, 0.04, 0.05), c + Vector3(-0.30, 0.58, 0.67), S.red)
	for sx in [-1, 1]:
		M.box(root, Vector3(0.05, 0.58, 0.05), c + Vector3(-0.30 + sx * 0.36, 0.30, 0.68), S.red)
	M.cyl(root, 0.06, 0.06, 0.34, c + Vector3(0.70, 0.99, 0.10), S.iron, 8)
	A.siege_yard(root, S)
	_tug(root, S, Vector3(c.x + 0.80, 0, 0.90), 1.00, team)
	return root

# ------------------------------------------------------------------ puerto 3x3: embarcadero con junco de velas de listones

func puerto(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(601)
	_ger(root, S, Vector3(-0.55, 0, -0.60), 0.66, 0.58, 0.40, team, 50.0)
	A.pier(root, S)
	# junco: casco de fondo plano con popa alta y vela de listones del color del jugador
	var sp := Vector3(0.05, 0.0, 1.62)
	var hull := Node3D.new()
	hull.position = sp + Vector3(0, 0.10, 0)
	root.add_child(hull)
	A.extrude(hull, PackedVector2Array([Vector2(1.00, 0.16), Vector2(0.78, 0.0), Vector2(-0.70, 0.0), Vector2(-0.96, 0.22), Vector2(-0.98, 0.38), Vector2(-0.72, 0.18), Vector2(0.80, 0.18)]), 0.34, Vector3.ZERO, S.red)
	M.box(root, Vector3(1.60, 0.05, 0.30), sp + Vector3(0.0, 0.30, 0), S.wood_l)
	M.cyl(root, 0.025, 0.03, 1.10, sp + Vector3(0.10, 0.80, 0.0), S.wood, 8)
	M.box(root, Vector3(0.78, 0.74, 0.02), sp + Vector3(0.10, 0.78, 0.03), _tm(team))
	for k in 5:
		M.box(root, Vector3(0.80, 0.025, 0.035), sp + Vector3(0.10, 0.50 + k * 0.15, 0.04), S.wood)
	M.box(root, Vector3(0.04, 0.10, 0.04), sp + Vector3(0.10, 1.38, 0.0), S.gold)
	for sx in [-0.55, 0.0, 0.45]:
		B.crate(root, Vector3(sx, 0.08, 1.10), S, 0.18, 8.0)
	_tug(root, S, Vector3(0.20, 0, -0.60), 0.90, team)
	return root

# ------------------------------------------------------------------ torre 2x2: atalaya de lacado rojo con tejado curvo

func torre(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(210)
	M.box(root, Vector3(1.20, 0.30, 1.20), Vector3(0, 0.15, 0), S.stone)
	M.box(root, Vector3(1.28, 0.05, 1.28), Vector3(0, 0.32, 0), S.stone_d)
	M.box(root, Vector3(0.86, 0.74, 0.86), Vector3(0, 0.72, 0), S.red)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.cyl(root, 0.055, 0.055, 0.76, Vector3(sx * 0.43, 0.72, sz * 0.43), S.orange, 8)
	M.box(root, Vector3(0.96, 0.07, 0.96), Vector3(0, 1.12, 0), S.teal)
	_pagoda(root, Vector3(0, 1.15, 0), 1.46, 0.44, S.gold_roof)
	# piso alto, más estrecho, con segundo tejado
	M.box(root, Vector3(0.56, 0.50, 0.56), Vector3(0, 1.48, 0), S.red)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.cyl(root, 0.04, 0.04, 0.52, Vector3(sx * 0.28, 1.48, sz * 0.28), S.orange, 8)
	M.box(root, Vector3(0.66, 0.06, 0.66), Vector3(0, 1.76, 0), S.teal)
	_pagoda(root, Vector3(0, 1.79, 0), 1.02, 0.52, S.gold_roof)
	M.cyl(root, 0.015, 0.02, 0.26, Vector3(0, 2.46, 0), S.gold, 6)
	M.ball(root, 0.04, Vector3(0, 2.62, 0), S.gold)
	A.arch_hole(root, Vector3(0.0, 0.32, 0.435), 0.24, 0.34, false, S.wood, S.gold, "round", 0.03)
	M.box(root, Vector3(0.24, 0.26, 0.03), Vector3(0.0, 1.44, 0.285), S.dark)
	M.box(root, Vector3(0.03, 0.26, 0.24), Vector3(0.285, 1.44, 0.0), S.dark)
	B.banner(root, Vector3(0.43, 1.02, 0.0), team, true, 0.18, 0.46)
	M._flag(root, Vector3(0.0, 2.55, 0.0), team, 0.40)
	return root

# ------------------------------------------------------------------ monasterio 3x3: templo budista con estupas

## Estupa blanca: base escalonada, cúpula, espira y remate dorado.
func _stupa(root: Node3D, S: Dictionary, pos: Vector3, s: float = 1.0) -> void:
	M.box(root, Vector3(0.36, 0.10, 0.36) * s, pos + Vector3(0, 0.05 * s, 0), S.stone)
	M.box(root, Vector3(0.28, 0.08, 0.28) * s, pos + Vector3(0, 0.14 * s, 0), S.white)
	A.lathe(root, A.dome_prof(0.17 * s, 0.22 * s), 12, pos + Vector3(0, 0.18 * s, 0), S.white)
	M.cyl(root, 0.045 * s, 0.07 * s, 0.30 * s, pos + Vector3(0, 0.55 * s, 0), S.white, 8)
	M.cyl(root, 0.07 * s, 0.07 * s, 0.03 * s, pos + Vector3(0, 0.62 * s, 0), S.gold, 8)
	M.ball(root, 0.04 * s, pos + Vector3(0, 0.74 * s, 0), S.gold)

func monasterio(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(701)
	var c := Vector3(-0.15, 0, -0.25)
	# terraza de piedra con escalinata
	M.box(root, Vector3(2.30, 0.14, 2.10), Vector3(0, 0.07, -0.10), S.stone_d)
	M.box(root, Vector3(2.16, 0.12, 1.96), Vector3(0, 0.20, -0.10), S.stone)
	for k in 3:
		M.box(root, Vector3(0.80, 0.06, 0.16), Vector3(c.x, 0.04 + k * 0.05, 1.04 + (2 - k) * 0.10), S.stone)
	# sala principal con dos tejados superpuestos
	var ye := _pavilion(root, S, c + Vector3(0.0, 0.14, 0.0), 1.30, 1.00, 0.70, 0.40, S.gold_roof, team, true)
	M.box(root, Vector3(0.74, 0.40, 0.74), c + Vector3(0, 0.14 + 0.20 + 0.70 + 0.07 + 0.30, 0), S.red)
	M.box(root, Vector3(0.84, 0.06, 0.84), c + Vector3(0, 0.14 + 0.20 + 0.70 + 0.07 + 0.52, 0), S.teal)
	_pagoda(root, c + Vector3(0, 0.14 + 0.20 + 0.70 + 0.07 + 0.55, 0), 1.20, 0.42, S.gold_roof)
	M.cyl(root, 0.015, 0.02, 0.22, c + Vector3(0, 2.20, 0), S.gold, 6)
	M.ball(root, 0.04, c + Vector3(0, 2.34, 0), S.gold)
	# estupas blancas y ruedas de oración
	_stupa(root, S, Vector3(0.95, 0.26, 0.55), 1.0)
	_stupa(root, S, Vector3(0.95, 0.26, -0.65), 0.8)
	_stupa(root, S, Vector3(-1.10, 0.26, -0.65), 0.8)
	M.cyl(root, 0.09, 0.09, 0.16, Vector3(-1.05, 0.34, 0.55), S.red, 10)
	M.cyl(root, 0.10, 0.10, 0.03, Vector3(-1.05, 0.43, 0.55), S.gold, 10)
	M.cyl(root, 0.09, 0.09, 0.16, Vector3(-0.80, 0.34, 0.70), S.red, 10)
	# línea de banderines de oración (colores de equipo, blanco y amarillo)
	for k in 7:
		var f: Material = [_tm(team), S.cloth_w, S.cloth_y, _tm(team), S.cloth_w, S.cloth_y, _tm(team)][k]
		M.box(root, Vector3(0.10, 0.10, 0.012), Vector3(-0.45 + k * 0.16, 1.00 - sin(float(k) / 6.0 * PI) * -0.0 - 0.04 * sin(float(k) / 6.0 * PI), 1.22), f)
	M.cyl(root, 0.015, 0.015, 1.00, Vector3(-0.55, 0.60, 1.22), S.wood, 6)
	M.cyl(root, 0.015, 0.015, 1.00, Vector3(0.65, 0.60, 1.22), S.wood, 6)
	return root

# ------------------------------------------------------------------ castillo 4x4: ordo del Gran Kan

func _earth_tower(root: Node3D, S: Dictionary, c: Vector3, w: float, h: float, roof_m: Material, team: Color) -> void:
	M.box(root, Vector3(w + 0.10, 0.18, w + 0.10), c + Vector3(0, 0.09, 0), S.stone_d)
	M.box(root, Vector3(w, h, w), c + Vector3(0, 0.18 + h * 0.5, 0), S.earth)
	M.box(root, Vector3(w + 0.10, 0.07, w + 0.10), c + Vector3(0, 0.18 + h, 0), S.teal)
	_pagoda(root, c + Vector3(0, 0.25 + h, 0), w + 0.36, 0.38, roof_m)
	for a in [0.0, 90.0]:
		var piv := Node3D.new()
		piv.position = c + Vector3(0, 0.18 + h * 0.60, 0)
		piv.rotation_degrees.y = a
		root.add_child(piv)
		A.arch_hole(piv, Vector3(0, 0, w * 0.5 + 0.005), 0.14, 0.20, false, S.dark, S.stone, "round", 0.03)
	M.cyl(root, 0.012, 0.018, 0.20, c + Vector3(0, 0.25 + h + 0.46, 0), S.gold, 6)

func castillo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(110)
	var F: Dictionary = S.F
	M.box(root, Vector3(3.5, 0.06, 3.5), Vector3(0, 0.03, 0), A.mat("plaster", 119, Color(0.62, 0.52, 0.34), 1.2))
	var wh := 1.05
	var e := 1.55
	for seg in [[Vector3(0, 0, -e), 3.0, 0.50], [Vector3(-e, 0, 0), 0.50, 3.0], [Vector3(e, 0, 0), 0.50, 3.0], [Vector3(-0.975, 0, e), 1.05, 0.50], [Vector3(0.975, 0, e), 1.05, 0.50]]:
		var sx: float = seg[1]
		var sz: float = seg[2]
		var p: Vector3 = seg[0]
		M.box(root, Vector3(sx, 0.16, sz), p + Vector3(0, 0.08, 0), S.stone_d)
		M.box(root, Vector3(sx - 0.06, wh, sz - 0.06), p + Vector3(0, 0.16 + wh * 0.5, 0), S.earth)
		M.box(root, Vector3(sx, 0.08, sz), p + Vector3(0, 0.16 + wh + 0.04, 0), S.teal)
	# puerta: pabellón con tejado curvo y arco de medio punto
	M.box(root, Vector3(1.00, 0.34, 0.56), Vector3(0, wh - 0.10, e), S.earth)
	M.box(root, Vector3(1.00, 0.92, 0.30), Vector3(0, 0.46, e - 0.05), F.slit)
	A.arch_hole(root, Vector3(0, 0.16, e + 0.285), 0.58, 0.46, false, S.dark, S.gold, "round", 0.06)
	for k in 5:
		M.box(root, Vector3(0.025, 0.74, 0.03), Vector3(-0.20 + k * 0.10, 0.38, e + 0.30), S.iron)
	M.box(root, Vector3(1.10, 0.07, 0.66), Vector3(0, wh + 0.10, e), S.teal)
	_pagoda(root, Vector3(0, wh + 0.13, e), 1.30, 0.36, S.gold_roof)
	# cuatro torres de tapia con tejado curvo
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_earth_tower(root, S, Vector3(sx * e, 0, sz * e), 0.95, 1.55, S.teal, team)
	# gran ordo: pabellón rojo con doble tejado dorado, dos yurtas delanteras y tuğ
	var pc := Vector3(0.0, 0, -0.55)
	var ye := _pavilion(root, S, pc, 1.50, 1.10, 0.80, 0.46, S.gold_roof, team, true)
	M.box(root, Vector3(0.86, 0.46, 0.80), pc + Vector3(0, 0.20 + 0.80 + 0.07 + 0.30, 0), S.red)
	M.box(root, Vector3(0.96, 0.06, 0.90), pc + Vector3(0, 0.20 + 0.80 + 0.07 + 0.56, 0), S.teal)
	_pagoda(root, pc + Vector3(0, 0.20 + 0.80 + 0.07 + 0.59, 0), 1.40, 0.46, S.gold_roof)
	M.cyl(root, 0.015, 0.02, 0.26, pc + Vector3(0, 2.30, 0), S.gold, 6)
	M.ball(root, 0.045, pc + Vector3(0, 2.46, 0), S.gold)
	_ger(root, S, Vector3(-0.95, 0, 0.45), 0.42, 0.44, 0.30, team, 40.0)
	_ger(root, S, Vector3(0.95, 0, 0.45), 0.42, 0.44, 0.30, team, 50.0)
	_tug(root, S, Vector3(0.0, 0, 0.62), 1.30, team)
	return root

# ------------------------------------------------------------------ herrería 3x3: yurta-fragua

func herreria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(801)
	_ger(root, S, Vector3(-0.30, 0, -0.35), 0.72, 0.62, 0.42, team, 40.0)
	# tubo de humo y fragua de piedra con fuelle
	M.cyl(root, 0.05, 0.05, 0.50, Vector3(-0.30, 1.30, -0.35), S.iron, 8)
	M.box(root, Vector3(0.50, 0.40, 0.44), Vector3(0.90, 0.20, -0.20), S.stone)
	M.box(root, Vector3(0.30, 0.10, 0.28), Vector3(0.90, 0.45, -0.20), S.fire)
	M.box(root, Vector3(0.12, 0.30, 0.20), Vector3(0.58, 0.25, -0.20), S.wood_l)
	A.forge_yard(root, S)
	_tug(root, S, Vector3(-1.20, 0, 0.60), 0.90, team)
	return root

# ------------------------------------------------------------------ mercado 3x3: bazar de caravanas

func mercado(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(901)
	var tm := _tm(team)
	M.box(root, Vector3(2.70, 0.06, 2.70), Vector3(0, 0.03, 0), S.felt_d)
	M.box(root, Vector3(2.50, 0.03, 2.50), Vector3(0, 0.075, 0), S.felt)
	# tres tiendas pequeñas de fieltro con faldón y toldo del color del jugador
	for k in 3:
		var tx := -0.90 + k * 0.90
		var tc := Vector3(tx, 0, -0.85)
		M.box(root, Vector3(0.66, 0.40, 0.56), tc + Vector3(0, 0.28, 0), S.felt)
		B.roof_x(root, 0.76, 0.66, 0.36, 0.48, S.felt if k != 1 else tm, tc)
		M.box(root, Vector3(0.70, 0.07, 0.04), tc + Vector3(0, 0.50, 0.30), tm if k != 1 else S.felt_d)
		M.box(root, Vector3(0.24, 0.30, 0.03), tc + Vector3(0, 0.25, 0.29), S.dark)
	# bolsas de mercancías y alfombras
	M.box(root, Vector3(0.70, 0.02, 0.50), Vector3(-0.55, 0.10, 0.50), S.cloth_r)
	M.box(root, Vector3(0.70, 0.02, 0.50), Vector3(0.50, 0.10, 0.62), S.cloth_b)
	for k in 4:
		M.box(root, Vector3(0.14, 0.14, 0.20), Vector3(-0.78 + k * 0.10, 0.19, 0.50), [S.cloth_g, S.cloth_y, S.cloth_p, S.cloth_w][k] as Material)
	B.puesto(root, Vector3(1.05, 0.08, 0.00), -90.0, tm, [S.orange_fruit, S.red_fruit, S.green_fruit, S.orange_fruit], S)
	B.puesto(root, Vector3(-1.05, 0.08, 0.10), 90.0, S.cloth_y, [S.red_fruit, S.green_fruit, S.red_fruit, S.orange_fruit], S)
	_horse(root, S, Vector3(0.20, 0.08, 1.12), 20.0, S.horse_b, 0.9)
	B.sack(root, Vector3(0.00, 0.08, 1.02), S)
	_tug(root, S, Vector3(0.0, 0.08, 0.10), 1.40, team)
	B.barrel(root, Vector3(1.10, 0.08, 0.95), S)
	return root

# ------------------------------------------------------------------ centro urbano 3x3: gran yurta del Kan

func centro(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(21)
	# gran yurta dorada con aro y cintas, rodeada de yurtas menores y un estandarte de nueve colas
	_ger(root, S, Vector3(-0.15, 0, -0.25), 1.02, 0.92, 0.70, team, 45.0)
	M.cyl(root, 1.06, 1.06, 0.05, Vector3(-0.15, 0.06 + 0.92 * 0.70, -0.25), S.gold, 22)
	_ger(root, S, Vector3(1.05, 0, -0.80), 0.48, 0.46, 0.30, team, 35.0)
	_ger(root, S, Vector3(-1.15, 0, 0.70), 0.46, 0.44, 0.30, team, 55.0)
	_ger(root, S, Vector3(1.05, 0, 0.55), 0.40, 0.40, 0.26, team, 60.0)
	_tug(root, S, Vector3(0.55, 0, 1.00), 1.50, team)
	_horse(root, S, Vector3(-0.60, 0.0, 1.05), 95.0, S.horse_w, 0.95)
	_horse(root, S, Vector3(-0.15, 0.0, 1.10), 80.0, S.horse_b, 0.95)
	# poste de atadura y cerca baja
	M.cyl(root, 0.03, 0.03, 0.44, Vector3(-0.90, 0.22, 0.95), S.wood, 6)
	M.cyl(root, 0.03, 0.03, 0.44, Vector3(0.10, 0.22, 0.95), S.wood, 6)
	M.box(root, Vector3(1.00, 0.03, 0.03), Vector3(-0.40, 0.38, 0.95), S.wood)
	B.barrel(root, Vector3(0.95, 0.0, 1.05), S)
	return root

# ------------------------------------------------------------------ murallas: tapia con albardilla de teja

func wall_post() -> Node3D:
	var root := Node3D.new()
	var S := pal(250)
	M.box(root, Vector3(0.60, 0.14, 0.60), Vector3(0, 0.07, 0), S.stone_d)
	M.box(root, Vector3(0.50, 0.96, 0.50), Vector3(0, 0.62, 0), S.earth)
	M.box(root, Vector3(0.60, 0.07, 0.60), Vector3(0, 1.13, 0), S.teal)
	_pagoda(root, Vector3(0, 1.16, 0), 0.95, 0.30, S.gold_roof)
	var tm := M.fmat(M.TEAM_BASE, 0.7, 0.3)
	M.box(root, Vector3(0.20, 0.20, 0.03), Vector3(0.0, 0.70, 0.26), tm)
	M.box(root, Vector3(0.03, 0.20, 0.20), Vector3(0.26, 0.70, 0.0), tm)
	return root

func wall_arm(d: int) -> Node3D:
	var root := Node3D.new()
	var S := pal(250)
	var dir: Vector2 = M.DIRS8[d]
	var diag := dir.x != 0.0 and dir.y != 0.0
	var L := 0.7071 if diag else 0.5
	var body := Node3D.new()
	root.add_child(body)
	M.box(body, Vector3(L + 0.04, 0.12, 0.44), Vector3(L * 0.5, 0.06, 0), S.stone_d)
	M.box(body, Vector3(L + 0.04, 0.80, 0.36), Vector3(L * 0.5, 0.52, 0), S.earth)
	M.box(body, Vector3(L + 0.04, 0.07, 0.44), Vector3(L * 0.5, 0.945, 0), S.teal)
	M.box(body, Vector3(L + 0.04, 0.05, 0.30), Vector3(L * 0.5, 1.005, 0), S.gold_roof)
	body.rotation.y = atan2(-dir.y, dir.x)
	return root

func gate(along_x: bool) -> Node3D:
	var root := Node3D.new()
	var S := pal(260)
	var body := Node3D.new()
	root.add_child(body)
	for sx in [-1, 1]:
		M.box(body, Vector3(0.34, 0.14, 0.56), Vector3(sx * 0.33, 0.07, 0), S.stone_d)
		M.box(body, Vector3(0.30, 1.10, 0.50), Vector3(sx * 0.33, 0.69, 0), S.earth)
		M.box(body, Vector3(0.36, 0.06, 0.56), Vector3(sx * 0.33, 1.27, 0), S.teal)
	M.box(body, Vector3(1.00, 0.30, 0.50), Vector3(0, 0.95, 0), S.earth)
	M.box(body, Vector3(1.04, 0.06, 0.56), Vector3(0, 1.13, 0), S.teal)
	_pagoda(body, Vector3(0, 1.16, 0), 1.20, 0.34, S.gold_roof)
	for sz in [-1, 1]:
		A.extrude(body, A.arch_outline(0.64, 0.46, "round"), 0.06, Vector3(0, 0.0, sz * 0.265), S.wood)
	M.box(body, Vector3(0.64, 0.46, 0.46), Vector3(0, 0.23, 0.0), S.dark)
	for yy in [0.20, 0.42]:
		M.box(body, Vector3(0.64, 0.04, 0.5), Vector3(0, yy, 0.0), S.iron)
	M.box(body, Vector3(0.20, 0.20, 0.03), Vector3(0.0, 0.98, 0.265), M.fmat(M.TEAM_BASE, 0.7, 0.3))
	body.rotation_degrees.y = 0.0 if along_x else 90.0
	return root
