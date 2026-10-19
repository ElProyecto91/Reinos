extends RefCounted
## Teutones: gótico de ladrillo de la Orden y de la Hansa. Muros de ladrillo rojo oscuro con hiladas vidriadas negras, grandes
## hastiales escalonados (Treppengiebel) con arcos apuntados ciegos, tejados empinados de teja verde vidriada, vigas de izado
## bajo el hastial, torres redondas almenadas y escudos blancos con cruz sobre el color del jugador. Nada de entramado ni de conos
## en las torres de guerra: la silueta son las escaleras de los hastiales.

const A = preload("res://tools/iso/iso_arch.gd")
const M = preload("res://tools/iso/iso_models.gd")
const B = preload("res://tools/iso/iso_build.gd")

func build(type: String, team: Color) -> Node3D:
	return call(type, team) as Node3D

func pal(seed_v: int) -> Dictionary:
	var S := A.plain()
	S["brick"] = A.mat("brick", seed_v + 3, Color(0.47, 0.20, 0.15), 1.1)
	S["brick_d"] = A.mat("brick", seed_v + 4, Color(0.24, 0.14, 0.13), 1.1)
	S["stone"] = A.mat("stone", seed_v, Color(0.62, 0.58, 0.52), 1.1)
	S["stone_d"] = A.mat("stone", seed_v + 1, Color(0.44, 0.41, 0.38), 1.1)
	S["stone_l"] = A.mat("stone", seed_v + 2, Color(0.82, 0.79, 0.72), 1.1)
	S["plaster"] = A.mat("plaster", seed_v + 5, Color(0.92, 0.89, 0.80), 1.0)
	S["wood"] = A.mat("wood", seed_v + 6, Color(0.22, 0.15, 0.10), 1.4)
	S["wood_l"] = A.mat("wood", seed_v + 7, Color(0.50, 0.36, 0.20), 1.6)
	S["planks"] = A.mat("planks", seed_v + 8, Color(0.42, 0.30, 0.18), 1.4)
	S["roof"] = A.mat("roof", seed_v + 9, Color(0.17, 0.35, 0.29), 1.5)
	S["roof_d"] = A.mat("roof", seed_v + 10, Color(0.11, 0.24, 0.20), 1.5)
	var F := A.fort(seed_v + 20, Color(0.47, 0.20, 0.15), Color(0.30, 0.15, 0.12), Color(0.82, 0.79, 0.72), Color(0.17, 0.13, 0.12), Color(0.30, 0.20, 0.12), "brick")
	F["light"] = S.stone_l
	S["F"] = F
	return S

func _tm(team: Color) -> StandardMaterial3D:
	return M.fmat(team, 0.85, 0.2)

## Ventana apuntada con marco blanco (sobre un muro que mira a +z, o a +x con face_x).
func _win(root: Node3D, S: Dictionary, pos: Vector3, w: float, h: float, face_x: bool) -> void:
	A.arch_hole(root, pos, w, h, face_x, S.glass, S.plaster, "pointed", 0.04)

## Hastial escalonado sobre el extremo +z (o +x si face_x) de un tejado a dos aguas de ancho `wid`; `rise` = altura del tejado.
## El hastial nace en `base` (alero) y sobresale del tejado; devuelve su altura total. Lleva arcos ciegos apuntados y una ventana.
func _gable(root: Node3D, S: Dictionary, base: Vector3, wid: float, rise: float, face_x: bool = false, steps: int = 3, win: bool = true) -> float:
	var h := rise * float(steps + 1) / float(steps)
	A.stepped_gable(root, base, wid, h, steps, S.brick, face_x, 0.16, 0.16)
	var out := Vector3(0.0, 0.0, 0.085) if not face_x else Vector3(0.085, 0.0, 0.0)
	var side := Vector3(1.0, 0.0, 0.0) if not face_x else Vector3(0.0, 0.0, -1.0)
	# banda vidriada negra a media altura del hastial
	var band_w := wid * 0.80
	M.box(root, Vector3(band_w, 0.045, 0.19) if not face_x else Vector3(0.19, 0.045, band_w), base + Vector3(0.0, rise * 0.62, 0.0), S.brick_d)
	if win:
		_win(root, S, base + out + Vector3(0.0, rise * 0.14, 0.0), minf(0.24, wid * 0.20), rise * 0.24, face_x)
	# arcos ciegos apuntados en los escalones
	for s in [-1.0, 1.0]:
		A.arch_hole(root, base + out + side * (s * wid * 0.29) + Vector3(0.0, rise * 0.10, 0.0), minf(0.14, wid * 0.11), rise * 0.20, face_x, S.brick_d, null, "pointed", 0.0)
	return h

## Viga de izado bajo la cumbre del hastial (Kranbalken) con polea, cuerda y carga.
func _hoist(root: Node3D, S: Dictionary, pos: Vector3, face_x: bool = false, load_sack: bool = true) -> void:
	var d := Vector3(0.0, 0.0, 1.0) if not face_x else Vector3(1.0, 0.0, 0.0)
	M.box(root, Vector3(0.06, 0.06, 0.52) if not face_x else Vector3(0.52, 0.06, 0.06), pos + d * 0.26, S.wood)
	M.box(root, Vector3(0.05, 0.22, 0.05) if not face_x else Vector3(0.05, 0.22, 0.05), pos + d * 0.12 + Vector3(0, -0.11, 0), S.wood)
	var pul := M.cyl(root, 0.05, 0.05, 0.03, pos + d * 0.50 + Vector3(0, -0.04, 0), S.iron, 8)
	if face_x:
		pul.rotation_degrees.x = 90.0
	else:
		pul.rotation_degrees.z = 90.0
	M.box(root, Vector3(0.012, 0.36, 0.012), pos + d * 0.50 + Vector3(0, -0.22, 0), S.rope)
	if load_sack:
		B.sack(root, pos + d * 0.50 + Vector3(0, -0.44, 0), S, 0.08)

## Escudo de la Orden: campo del color del jugador y cruz blanca.
func _order_shield(root: Node3D, S: Dictionary, pos: Vector3, w: float, team: Color, face_x: bool = false) -> void:
	A.heater(root, pos, w, face_x, _tm(team), S.cloth_w)

## Torrecilla de cumbrera con aguja verde (Dachreiter).
func _spirelet(root: Node3D, S: Dictionary, pos: Vector3, h: float = 0.32) -> void:
	M.box(root, Vector3(0.16, h, 0.16), pos + Vector3(0, h * 0.5, 0), S.brick_d)
	A.cone(root, 0.15, h * 1.5, h, S.roof_d, pos, 8)

## Cuerpo de nave: zócalo de piedra, muro de ladrillo con banda vidriada y tejado empinado a dos aguas con hastial escalonado
## en +z (gable_x = false, cumbrera a lo largo de z) o en +x (gable_x = true, cumbrera a lo largo de x).
## c = centro de la huella; devuelve la y del alero.
func _hall(root: Node3D, S: Dictionary, c: Vector3, w: float, d: float, wh: float, rise: float, gable_x: bool, steps: int = 3, win: bool = true) -> float:
	var yb := 0.14 + wh
	M.box(root, Vector3(w + 0.12, 0.14, d + 0.12), c + Vector3(0, 0.07, 0), S.stone_d)
	M.box(root, Vector3(w, wh, d), c + Vector3(0, 0.14 + wh * 0.5, 0), S.brick)
	M.box(root, Vector3(w + 0.05, 0.05, d + 0.05), c + Vector3(0, 0.14 + wh * 0.50, 0), S.brick_d)
	M.box(root, Vector3(w + 0.05, 0.05, d + 0.05), c + Vector3(0, 0.14 + 0.12, 0), S.stone)
	if gable_x:
		# cumbrera a lo largo de x; hastial en la cara +x
		B.roof_x(root, w, d, rise, yb, S.roof, c)
		_gable(root, S, c + Vector3(w * 0.5, yb, 0.0), d, rise, true, steps, win)
	else:
		B.roof_z(root, d, w, rise, yb, S.roof, c)
		_gable(root, S, c + Vector3(0.0, yb, d * 0.5), w, rise, false, steps, win)
	return yb

# ------------------------------------------------------------------ casa 2x2: casa de mercader hanseática

func casa(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(11)
	var w := 1.30
	var d := 1.46
	var wh := 0.96
	var yb := _hall(root, S, Vector3.ZERO, w, d, wh, 0.66, false, 3)
	var zf := d * 0.5 + 0.005
	A.arch_hole(root, Vector3(-0.30, 0.14, zf), 0.28, 0.20, false, S.wood, S.plaster, "pointed", 0.05)
	_win(root, S, Vector3(0.26, 0.30, zf), 0.20, 0.16, false)
	_win(root, S, Vector3(-0.30, 0.74, zf), 0.20, 0.18, false)
	_win(root, S, Vector3(0.26, 0.74, zf), 0.20, 0.18, false)
	for wz in [-0.32, 0.30]:
		_win(root, S, Vector3(w * 0.5 + 0.005, 0.30, wz), 0.20, 0.16, true)
		_win(root, S, Vector3(w * 0.5 + 0.005, 0.74, wz), 0.20, 0.18, true)
	_hoist(root, S, Vector3(0.0, yb + 0.56, zf + 0.06))
	_order_shield(root, S, Vector3(0.0, 0.66, zf + 0.03), 0.18, team)
	B.barrel(root, Vector3(0.88, 0.0, 0.52), S)
	B.crate(root, Vector3(0.86, 0.0, 0.84), S, 0.24, 14.0)
	M._flag(root, Vector3(-0.78, 0.0, 0.92), team, 0.90)
	return root

# ------------------------------------------------------------------ almacén 2x2: granero de la Hansa con grúa de izado

func almacen(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(101)
	var w := 1.40
	var d := 1.44
	var yb := _hall(root, S, Vector3.ZERO, w, d, 0.78, 0.74, true, 3)
	# la cara +x lleva el hastial; la cara +z, el portón de carga con arco apuntado
	var zf := d * 0.5 + 0.005
	A.arch_hole(root, Vector3(-0.15, 0.14, zf), 0.64, 0.30, false, S.dark, S.plaster, "pointed", 0.05)
	for sx in [-1, 1]:
		M.box(root, Vector3(0.28, 0.46, 0.04), Vector3(-0.15 + sx * 0.18, 0.37, zf + 0.04), S.wood).rotation_degrees.y = float(sx) * 36.0
	_win(root, S, Vector3(0.40, 0.58, zf), 0.18, 0.14, false)
	_win(root, S, Vector3(-0.55, 0.58, zf), 0.18, 0.14, false)
	_hoist(root, S, Vector3(w * 0.5 + 0.06, yb + 0.56, 0.0), true)
	B.sack(root, Vector3(0.95, 0.0, 0.86), S)
	B.sack(root, Vector3(0.80, 0.0, 0.98), S, 0.10)
	B.barrel(root, Vector3(1.00, 0.0, 0.50), S)
	B.crate(root, Vector3(-0.78, 0.0, 0.96), S, 0.24, -10.0)
	B.banner(root, Vector3(0.45, 0.88, zf + 0.03), team, false, 0.16, 0.40)
	M._flag(root, Vector3(-0.90, 0.0, -0.78), team, 0.85)
	return root

# ------------------------------------------------------------------ cuartel 3x3: castillo de encomienda con torre redonda

func cuartel(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(201)
	var F: Dictionary = S.F
	var c := Vector3(-0.28, 0, -0.30)
	var w := 2.00
	var d := 1.60
	var yb := _hall(root, S, c, w, d, 1.00, 0.66, true, 3)
	M.box(root, Vector3(w, 0.05, 0.07), c + Vector3(0, yb + 0.66, 0), S.roof_d)
	# ventanas largas en la cara +z y troneras en la +x
	for wx in [-0.55, 0.10, 0.75]:
		A.arch_hole(root, c + Vector3(wx, 0.52, d * 0.5 + 0.005), 0.18, 0.34, false, S.dark, S.plaster, "pointed", 0.04)
	A.arch_hole(root, c + Vector3(-0.0, 0.14, d * 0.5 + 0.005), 0.46, 0.26, false, S.wood, S.plaster, "pointed", 0.05)
	# torre redonda almenada en la esquina delantera, con bandera
	var top := A.tower_round(root, Vector3(0.95, 0, 0.82), 0.46, 1.60, F, null, 1.0, true)
	M._flag(root, Vector3(0.95, top, 0.82), team, 0.60)
	_order_shield(root, S, Vector3(0.62, 0.84, 1.18), 0.20, team)
	_spirelet(root, S, c + Vector3(-0.45, yb + 0.60, 0.0))
	A.drill_yard(root, S, 1.20, 1.46)
	B.banner(root, c + Vector3(-0.62, 0.92, d * 0.5 + 0.03), team, false, 0.18, 0.46)
	return root

# ------------------------------------------------------------------ arquería 3x3: casa de ballesteros

func arqueria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(301)
	var c := Vector3(-0.40, 0, -0.45)
	var w := 1.50
	var d := 1.90
	var yb := _hall(root, S, c, w, d, 0.84, 0.74, false, 3)
	var zf := c.z + d * 0.5 + 0.005
	A.arch_hole(root, Vector3(c.x - 0.38, 0.14, zf), 0.30, 0.22, false, S.wood, S.plaster, "pointed", 0.05)
	_win(root, S, Vector3(c.x + 0.28, 0.34, zf), 0.22, 0.18, false)
	_win(root, S, Vector3(c.x - 0.38, 0.62, zf), 0.18, 0.12, false)
	_win(root, S, Vector3(c.x + 0.28, 0.66, zf), 0.18, 0.12, false)
	for wz in [-0.40, 0.20, 0.80]:
		_win(root, S, Vector3(c.x + w * 0.5 + 0.005, 0.40, c.z + wz), 0.18, 0.20, true)
	_spirelet(root, S, c + Vector3(0.0, yb + 0.70, -0.30))
	_order_shield(root, S, Vector3(c.x, 0.70, zf + 0.03), 0.20, team)
	A.archery_field(root, S, _tm(team))
	# ballestas apoyadas junto a la puerta
	for k in 3:
		M.box(root, Vector3(0.04, 0.04, 0.34), Vector3(c.x + 0.10 + k * 0.10, 0.28, zf + 0.20), S.wood_l).rotation_degrees.x = -12.0
		M.box(root, Vector3(0.30, 0.03, 0.03), Vector3(c.x + 0.10 + k * 0.10, 0.34, zf + 0.30), S.iron)
	B.banner(root, Vector3(c.x + 0.50, 0.92, zf + 0.03), team, false, 0.16, 0.40)
	return root

# ------------------------------------------------------------------ establo 3x3: cuadra de ladrillo con pajar

func establo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(401)
	var c := Vector3(-0.15, 0, -0.35)
	var w := 2.00
	var d := 1.50
	var yb := _hall(root, S, c, w, d, 0.80, 0.70, true, 3)
	var zf := c.z + d * 0.5 + 0.005
	# portones de cuadra con arco apuntado en +z; pajar con polea en el hastial +x
	for sx in [-0.50, 0.40]:
		A.arch_hole(root, Vector3(c.x + sx, 0.14, zf), 0.46, 0.24, false, S.wood, S.plaster, "pointed", 0.05)
		M.box(root, Vector3(0.025, 0.58, 0.03), Vector3(c.x + sx, 0.43, zf + 0.04), S.wood_l)
	_win(root, S, Vector3(c.x - 0.05, 0.62, zf), 0.18, 0.14, false)
	_hoist(root, S, c + Vector3(w * 0.5 + 0.06, yb + 0.56, 0.0), true, false)
	M.box(root, Vector3(0.34, 0.30, 0.12), c + Vector3(w * 0.5 + 0.10, yb + 0.28, 0.0), S.hay)
	A.corral(root, S)
	B.banner(root, Vector3(c.x + 0.90, 0.88, zf + 0.03), team, false, 0.16, 0.40)
	_order_shield(root, S, Vector3(c.x - 0.05, 0.84, zf + 0.03), 0.16, team)
	return root

# ------------------------------------------------------------------ taller de asedio 3x3

func taller(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(501)
	var c := Vector3(-0.20, 0, -0.35)
	var w := 1.90
	var d := 1.50
	var yb := _hall(root, S, c, w, d, 0.92, 0.72, false, 3)
	var zf := c.z + d * 0.5 + 0.005
	A.arch_hole(root, Vector3(c.x - 0.30, 0.14, zf), 0.70, 0.40, false, S.dark, S.plaster, "pointed", 0.06)
	for y in [0.30, 0.58]:
		M.box(root, Vector3(0.70, 0.04, 0.05), Vector3(c.x - 0.30, y, zf + 0.04), S.iron)
	_win(root, S, Vector3(c.x + 0.50, 0.40, zf), 0.20, 0.20, false)
	_win(root, S, Vector3(c.x + 0.50, 0.80, zf), 0.18, 0.14, false)
	# rueda de pisar de madera en el costado +x
	var gear := Node3D.new()
	gear.position = c + Vector3(w * 0.5 + 0.10, 0.72, 0.10)
	gear.rotation_degrees.z = 90.0
	root.add_child(gear)
	M.cyl(gear, 0.30, 0.30, 0.08, Vector3.ZERO, S.wood_l, 20)
	M.cyl(gear, 0.07, 0.07, 0.12, Vector3.ZERO, S.iron, 10)
	for k in 5:
		M.box(gear, Vector3(0.60, 0.09, 0.03), Vector3.ZERO, S.wood).rotation.y = float(k) * PI * 0.2
	_hoist(root, S, Vector3(c.x, yb + 0.58, zf + 0.06), false)
	A.siege_yard(root, S)
	B.banner(root, Vector3(c.x + 0.62, 0.92, zf + 0.03), team, false, 0.16, 0.40)
	_order_shield(root, S, Vector3(c.x - 0.30, 0.90, zf + 0.03), 0.16, team)
	return root

# ------------------------------------------------------------------ puerto 3x3: almacén con grúa de pisar (Krantor)

func puerto(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(601)
	var c := Vector3(-0.30, 0, -0.50)
	var w := 1.60
	var d := 1.40
	var yb := _hall(root, S, c, w, d, 0.84, 0.70, false, 3)
	var zf := c.z + d * 0.5 + 0.005
	for sx in [-1, 1]:
		A.arch_hole(root, Vector3(c.x + sx * 0.38, 0.14, zf), 0.40, 0.24, false, S.dark, S.plaster, "pointed", 0.05)
	_win(root, S, Vector3(c.x, 0.64, zf), 0.20, 0.16, false)
	A.pier(root, S)
	# Krantor: torre de madera con tejado verde, brazo volado sobre el agua y rueda de pisar
	var kc := Vector3(1.00, 0, 0.30)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.10, 1.40, 0.10), kc + Vector3(sx * 0.26, 0.70, sz * 0.26), S.wood)
	for y in [0.40, 0.90]:
		M.box(root, Vector3(0.62, 0.07, 0.62), kc + Vector3(0, y, 0), S.wood_l)
	M.box(root, Vector3(0.56, 0.50, 0.56), kc + Vector3(0, 1.12, 0), S.planks)
	A.pyramid(root, 0.80, 0.55, 1.37, S.roof, kc)
	M.box(root, Vector3(0.08, 0.08, 1.10), kc + Vector3(0, 1.20, 0.80), S.wood)
	M.box(root, Vector3(0.012, 0.50, 0.012), kc + Vector3(0, 0.95, 1.25), S.rope)
	B.crate(root, kc + Vector3(0, 0.55, 1.25), S, 0.18, 0.0)
	var wheel := Node3D.new()
	wheel.position = kc + Vector3(0.34, 0.70, 0.0)
	wheel.rotation_degrees.z = 90.0
	root.add_child(wheel)
	M.cyl(wheel, 0.34, 0.34, 0.08, Vector3.ZERO, S.wood_l, 18)
	M.cyl(wheel, 0.06, 0.06, 0.12, Vector3.ZERO, S.iron, 8)
	for k in 5:
		M.box(wheel, Vector3(0.68, 0.09, 0.03), Vector3.ZERO, S.wood).rotation.y = float(k) * PI * 0.2
	_hoist(root, S, Vector3(c.x, yb + 0.55, zf + 0.06), false)
	B.banner(root, Vector3(c.x + 0.62, 0.92, zf + 0.03), team, false, 0.16, 0.40)
	M._flag(root, Vector3(-1.10, 0.0, 1.20), team, 0.90)
	return root

# ------------------------------------------------------------------ torre 2x2: torre de la Hansa con corona de hastiales

func torre(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(210)
	var F: Dictionary = S.F
	var w := 1.20
	var top := A.tower_sq(root, Vector3.ZERO, w, 2.35, F, {"cap": "pyramid", "cap_m": S.roof, "cap_h": 1.15, "door": true})
	# corona de cuatro hastiales escalonados al pie del chapitel
	var g := w * 0.5 + 0.09
	var gw := w * 0.78
	A.stepped_gable(root, Vector3(0.0, top, g), gw, 0.62, 3, S.brick, false, 0.12, 0.12)
	A.stepped_gable(root, Vector3(0.0, top, -g), gw, 0.62, 3, S.brick, false, 0.12, 0.12)
	A.stepped_gable(root, Vector3(g, top, 0.0), gw, 0.62, 3, S.brick, true, 0.12, 0.12)
	A.stepped_gable(root, Vector3(-g, top, 0.0), gw, 0.62, 3, S.brick, true, 0.12, 0.12)
	_win(root, S, Vector3(0.0, top + 0.10, g + 0.065), 0.14, 0.16, false)
	_win(root, S, Vector3(g + 0.065, top + 0.10, 0.0), 0.14, 0.16, true)
	A.arch_hole(root, Vector3(0.0, 0.20, w * 0.5 + 0.005), 0.30, 0.22, false, S.wood, S.plaster, "pointed", 0.04)
	_order_shield(root, S, Vector3(0.0, 1.45, w * 0.5 + 0.03), 0.28, team)
	M._flag(root, Vector3(0.0, top + 1.15, 0.0), team, 0.70)
	return root

# ------------------------------------------------------------------ monasterio 3x3: iglesia-salón de ladrillo con hastial de cinco escalones

func monasterio(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(701)
	var F: Dictionary = S.F
	var c := Vector3(-0.30, 0, -0.30)
	var w := 1.30
	var d := 2.30
	var yb := _hall(root, S, c, w, d, 1.15, 0.84, false, 4, false)
	var zf := c.z + d * 0.5 + 0.005
	# fachada: gran ventana apuntada, portal y rosetón ciego bajo el hastial
	A.arch_hole(root, Vector3(c.x, 0.14, zf), 0.36, 0.34, false, S.wood, S.plaster, "pointed", 0.06)
	A.arch_hole(root, Vector3(c.x, 0.72, zf), 0.34, 0.50, false, S.glass, S.plaster, "pointed", 0.05)
	A.arch_hole(root, Vector3(c.x, yb + 0.12, zf + 0.085), 0.24, 0.40, false, S.glass, S.plaster, "pointed", 0.04)
	for gx in [-0.40, 0.40]:
		A.arch_hole(root, Vector3(c.x + gx, 0.72, zf), 0.16, 0.34, false, S.glass, S.plaster, "pointed", 0.03)
	# costado +x: ventanas altas y contrafuertes
	for wz in [-0.80, -0.20, 0.40, 1.00]:
		A.arch_hole(root, Vector3(c.x + w * 0.5 + 0.005, 0.52, c.z + wz), 0.20, 0.52, true, S.glass, S.plaster, "pointed", 0.04)
		M.box(root, Vector3(0.14, 1.10, 0.14), Vector3(c.x + w * 0.5 + 0.06, 0.69, c.z + wz + 0.30), S.stone)
		M.box(root, Vector3(0.14, 0.14, 0.14), Vector3(c.x + w * 0.5 + 0.06, 1.28, c.z + wz + 0.30), S.stone_d).scale = Vector3(1.0, 0.6, 1.0)
	# campanario cuadrado con chapitel verde de ocho aguas y garitas
	var tc := Vector3(c.x + 0.92, 0, c.z - 0.80)
	var top := A.tower_sq(root, tc, 0.70, 2.30, F, {"cap": "pyramid", "cap_m": S.roof, "cap_h": 0.95})
	A.arch_hole(root, tc + Vector3(0.0, 1.65, 0.355), 0.18, 0.34, false, S.dark, S.plaster, "pointed", 0.03)
	A.arch_hole(root, tc + Vector3(0.355, 1.65, 0.0), 0.18, 0.34, true, S.dark, S.plaster, "pointed", 0.03)
	M._flag(root, tc + Vector3(0, top + 0.95, 0), team, 0.62)
	_spirelet(root, S, c + Vector3(0.0, yb + 0.84, 0.40), 0.30)
	_order_shield(root, S, Vector3(c.x - 0.46, 1.05, zf + 0.03), 0.20, team)
	_order_shield(root, S, Vector3(c.x + 0.46, 1.05, zf + 0.03), 0.20, team)
	return root

# ------------------------------------------------------------------ castillo 4x4: Ordensburg tipo Marienburg

func castillo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(110)
	var F: Dictionary = S.F
	M.box(root, Vector3(3.5, 0.06, 3.5), Vector3(0, 0.03, 0), A.mat("plaster", 119, Color(0.58, 0.52, 0.38), 1.2))
	var wh := 1.20
	A.wall_block(root, F, 3.0, wh, 0.50, Vector3(0, 0, -1.55))
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(-1.55, 0, 0))
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(1.55, 0, 0))
	A.wall_block(root, F, 1.00, wh, 0.50, Vector3(-1.00, 0, 1.55))
	A.wall_block(root, F, 1.00, wh, 0.50, Vector3(1.00, 0, 1.55))
	# portal con ojiva y dos garitas redondas
	M.box(root, Vector3(1.00, 0.34, 0.50), Vector3(0, wh - 0.17, 1.55), F.wall)
	M.box(root, Vector3(1.04, 0.05, 0.54), Vector3(0, wh + 0.025, 1.55), F.light)
	M.box(root, Vector3(0.92, 0.90, 0.30), Vector3(0, 0.45, 1.50), F.slit)
	A.arch_hole(root, Vector3(0, 0.0, 1.805), 0.62, 0.50, false, S.dark, S.stone_l, "pointed", 0.07)
	for k in 5:
		M.box(root, Vector3(0.025, 0.74, 0.03), Vector3(-0.20 + k * 0.10, 0.37, 1.83), S.iron)
	for sx in [-1, 1]:
		A.tower_round(root, Vector3(sx * 0.68, 0, 1.76), 0.26, 1.35, F)
	# cuatro torres redondas almenadas en las esquinas
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			A.tower_round(root, Vector3(sx * 1.55, 0, sz * 1.55), 0.54, 1.95, F)
	# palacio del Maestre: gran sala con tejado verde empinado, hastial escalonado de cuatro peldaños y torre-campanario
	var kc := Vector3(-0.05, 0, -0.35)
	var kw := 1.70
	var kd := 1.60
	var kh := 1.45
	M.box(root, Vector3(kw + 0.16, 0.18, kd + 0.16), kc + Vector3(0, 0.09, 0), F.dark)
	M.box(root, Vector3(kw, kh, kd), kc + Vector3(0, 0.18 + kh * 0.5, 0), F.wall)
	M.box(root, Vector3(kw + 0.05, 0.05, kd + 0.05), kc + Vector3(0, 0.18 + kh * 0.62, 0), S.brick_d)
	M.box(root, Vector3(kw + 0.05, 0.05, kd + 0.05), kc + Vector3(0, 0.18 + kh, 0), S.brick_d)
	var yk := 0.18 + kh
	B.roof_z(root, kd, kw, 1.10, yk, S.roof, kc)
	M.box(root, Vector3(0.07, 0.06, kd + 0.04), kc + Vector3(0, yk + 1.10, 0), S.roof_d)
	var gh := _gable(root, S, kc + Vector3(0.0, yk, kd * 0.5), kw, 1.10, false, 4, false)
	A.arch_hole(root, kc + Vector3(0.0, yk + 0.28, kd * 0.5 + 0.085), 0.30, 0.50, false, S.glass, S.stone_l, "pointed", 0.05)
	# ventanas apuntadas de dos pisos en la fachada y en el costado
	for wx in [-0.55, 0.55]:
		A.arch_hole(root, kc + Vector3(wx, 0.56, kd * 0.5 + 0.005), 0.20, 0.38, false, S.glass, S.stone_l, "pointed", 0.04)
		A.arch_hole(root, kc + Vector3(wx, 1.18, kd * 0.5 + 0.005), 0.18, 0.30, false, S.glass, S.stone_l, "pointed", 0.04)
	for wz in [-0.50, 0.10, 0.60]:
		A.arch_hole(root, kc + Vector3(kw * 0.5 + 0.005, 0.56, wz), 0.18, 0.40, true, S.glass, S.stone_l, "pointed", 0.04)
		A.arch_hole(root, kc + Vector3(kw * 0.5 + 0.005, 1.18, wz), 0.16, 0.30, true, S.glass, S.stone_l, "pointed", 0.03)
	A.arch_hole(root, kc + Vector3(0.0, 0.18, kd * 0.5 + 0.005), 0.40, 0.34, false, S.wood, S.stone_l, "pointed", 0.06)
	_spirelet(root, S, kc + Vector3(0.0, yk + 1.10, -0.35), 0.40)
	var kt := A.tower_round(root, kc + Vector3(-0.78, 0, -0.74), 0.34, 2.42, F, S.roof, 0.95, true)
	M._flag(root, kc + Vector3(-0.78, kt + 1.0, -0.74), team, 0.9)
	_order_shield(root, S, kc + Vector3(0.0, 0.90, kd * 0.5 + 0.03), 0.34, team)
	B.banner(root, kc + Vector3(0.50, 0.20 + 0.55, kd * 0.5 + 0.03), team, false, 0.24, 0.66)
	B.banner(root, kc + Vector3(-0.50, 0.20 + 0.55, kd * 0.5 + 0.03), team, false, 0.24, 0.66)
	return root

# ------------------------------------------------------------------ herrería 3x3

func herreria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(801)
	var c := Vector3(-0.20, 0, -0.35)
	var w := 1.80
	var d := 1.50
	var yb := _hall(root, S, c, w, d, 0.90, 0.70, false, 2)
	var zf := c.z + d * 0.5 + 0.005
	# chimenea de ladrillo de tres fustes pegada al muro +x
	M.box(root, Vector3(0.50, 1.80, 0.50), c + Vector3(w * 0.5 + 0.16, 0.90, -0.25), S.brick)
	M.box(root, Vector3(0.60, 0.07, 0.60), c + Vector3(w * 0.5 + 0.16, 1.80, -0.25), S.stone_d)
	for dz in [-0.14, 0.0, 0.14]:
		M.cyl(root, 0.07, 0.08, 0.40, c + Vector3(w * 0.5 + 0.16, 2.03, -0.25 + dz), S.brick, 8)
	A.smoke_src(root, c + Vector3(w * 0.5 + 0.16, 2.30, -0.25))
	M.box(root, Vector3(0.10, 0.30, 0.34), c + Vector3(w * 0.5 + 0.42, 0.34, -0.25), S.dark)
	M.box(root, Vector3(0.12, 0.24, 0.26), c + Vector3(w * 0.5 + 0.43, 0.34, -0.25), S.fire)
	A.arch_hole(root, Vector3(c.x - 0.30, 0.14, zf), 0.74, 0.36, false, S.dark, S.plaster, "pointed", 0.06)
	M.box(root, Vector3(0.20, 0.20, 0.03), Vector3(c.x - 0.50, 0.30, zf + 0.04), S.fire)
	_win(root, S, Vector3(c.x + 0.45, 0.50, zf), 0.20, 0.18, false)
	_win(root, S, Vector3(c.x + 0.45, 0.80, zf), 0.18, 0.12, false)
	A.forge_yard(root, S)
	_order_shield(root, S, Vector3(c.x - 0.30, 0.82, zf + 0.03), 0.18, team)
	B.banner(root, Vector3(c.x + 0.62, 0.92, zf + 0.03), team, false, 0.16, 0.40)
	return root

# ------------------------------------------------------------------ mercado 3x3: casa de la Hansa con soportal y columna de Roland

func mercado(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(901)
	var tm := _tm(team)
	M.box(root, Vector3(2.70, 0.10, 2.70), Vector3(0, 0.05, 0), S.stone_l)
	M.box(root, Vector3(2.50, 0.04, 2.50), Vector3(0, 0.12, 0), S.stone)
	# lonja: soportal de ladrillo con arcos apuntados, piso alto de ladrillo y hastial escalonado
	var c := Vector3(0.0, 0, -0.85)
	M.box(root, Vector3(2.30, 0.06, 1.14), c + Vector3(0, 0.15, 0), S.stone_d)
	M.box(root, Vector3(2.30, 0.30, 0.04), c + Vector3(0, 0.30, -0.54), S.brick)
	A.arcade(root, c + Vector3(0.0, 0.18, 0.46), true, 4, 0.56, 0.42, S.brick, S.dark, "pointed", false)
	M.box(root, Vector3(2.26, 0.62, 1.10), c + Vector3(0, 0.98, 0), S.brick)
	M.box(root, Vector3(2.30, 0.05, 1.14), c + Vector3(0, 1.03, 0), S.brick_d)
	var yb := 1.29
	B.roof_z(root, 1.10, 2.26, 0.60, yb, S.roof, c)
	M.box(root, Vector3(0.07, 0.06, 1.16), c + Vector3(0, yb + 0.60, 0), S.roof_d)
	_gable(root, S, c + Vector3(0.0, yb, 0.55), 2.26, 0.60, false, 4, false)
	for wx in [-0.80, -0.27, 0.27, 0.80]:
		_win(root, S, c + Vector3(wx, 0.76, 0.555), 0.20, 0.24, false)
	_win(root, S, c + Vector3(1.135, 0.78, 0.0), 0.20, 0.24, true)
	_order_shield(root, S, c + Vector3(0.0, 1.62, 0.64), 0.26, team)
	# columna de Roland: peldaños, fuste y caballero con escudo
	for k in 3:
		M.box(root, Vector3(0.74 - k * 0.18, 0.07, 0.74 - k * 0.18), Vector3(0.0, 0.17 + k * 0.07, 0.62), S.stone if k % 2 == 0 else S.stone_d)
	M.cyl(root, 0.07, 0.09, 0.62, Vector3(0.0, 0.62, 0.62), S.stone_l, 8)
	M.cyl(root, 0.10, 0.08, 0.06, Vector3(0.0, 0.96, 0.62), S.stone, 8)
	M.cyl(root, 0.06, 0.07, 0.26, Vector3(0.0, 1.12, 0.62), S.steel, 8)
	M.ball(root, 0.07, Vector3(0.0, 1.30, 0.62), S.steel)
	M.box(root, Vector3(0.015, 0.30, 0.015), Vector3(0.12, 1.20, 0.62), S.steel)
	A.heater(root, Vector3(0.0, 1.12, 0.72), 0.12, false, tm, S.cloth_w)
	B.puesto(root, Vector3(-0.95, 0.10, 0.70), 90.0, tm, [S.red_fruit, S.green_fruit, S.red_fruit, S.orange_fruit], S)
	B.puesto(root, Vector3(0.95, 0.10, 0.80), -90.0, S.cloth_w, [S.orange_fruit, S.orange_fruit, S.green_fruit, S.red_fruit], S)
	M._flag(root, Vector3(-0.30, 0.10, 1.22), team, 1.30)
	B.crate(root, Vector3(1.10, 0.10, 0.10), S, 0.26, 12.0)
	B.barrel(root, Vector3(-1.10, 0.10, 0.10), S)
	B.sack(root, Vector3(0.60, 0.10, 1.12), S)
	return root

# ------------------------------------------------------------------ centro urbano 3x3: ayuntamiento de ladrillo con torre redonda

func centro(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(21)
	var F: Dictionary = S.F
	# sala principal (hastial de cinco peldaños) y ala menor a la derecha con su propio hastial
	var yb := _hall(root, S, Vector3(-0.38, 0, -0.05), 1.60, 2.30, 1.14, 0.96, false, 4, false)
	var zf := -0.05 + 2.30 * 0.5 + 0.005
	var yb2 := _hall(root, S, Vector3(0.85, 0, -0.45), 1.00, 1.50, 0.88, 0.58, false, 3, false)
	var zf2 := -0.45 + 1.50 * 0.5 + 0.005
	# fachada principal
	A.arch_hole(root, Vector3(-0.38, 0.14, zf), 0.46, 0.34, false, S.wood, S.plaster, "pointed", 0.06)
	A.arch_hole(root, Vector3(-0.38, 0.84, zf), 0.30, 0.42, false, S.glass, S.plaster, "pointed", 0.05)
	A.arch_hole(root, Vector3(-0.38, yb + 0.26, zf + 0.085), 0.26, 0.46, false, S.glass, S.plaster, "pointed", 0.04)
	for wx in [-0.85, 0.09]:
		_win(root, S, Vector3(wx, 0.40, zf), 0.20, 0.22, false)
		_win(root, S, Vector3(wx, 0.86, zf), 0.18, 0.22, false)
	A.arch_hole(root, Vector3(0.85, 0.14, zf2), 0.32, 0.26, false, S.wood, S.plaster, "pointed", 0.05)
	_win(root, S, Vector3(0.85, 0.62, zf2), 0.18, 0.20, false)
	for wz in [-0.9, -0.3, 0.3]:
		_win(root, S, Vector3(0.805 + 0.545, 0.40, -0.45 + wz * 0.7), 0.18, 0.20, true)
	# torre redonda con aguja verde detrás del ala menor
	var top := A.tower_round(root, Vector3(0.95, 0, -1.05), 0.40, 1.95, F, S.roof, 1.18, true)
	M._flag(root, Vector3(0.95, top + 1.30, -1.05), team, 0.80)
	_spirelet(root, S, Vector3(-0.38, yb + 0.96, -0.60), 0.36)
	_hoist(root, S, Vector3(-0.38, yb + 0.80, zf + 0.06))
	_order_shield(root, S, Vector3(-0.38, 0.62, zf + 0.03), 0.20, team)
	B.banner(root, Vector3(-0.85, 0.80, zf + 0.03), team, false, 0.20, 0.52)
	B.banner(root, Vector3(0.09, 0.80, zf + 0.03), team, false, 0.20, 0.52)
	M._flag(root, Vector3(1.12, 0.0, 1.30), team, 1.20)
	return root

# ------------------------------------------------------------------ murallas

func wall_post() -> Node3D:
	return A.wall_post(pal(250).F)

func wall_arm(d: int) -> Node3D:
	return A.wall_arm(d, pal(250).F)

func gate(along_x: bool) -> Node3D:
	var S := pal(260)
	return A.wall_gate(along_x, S.F, S.wood, "pointed", false)
