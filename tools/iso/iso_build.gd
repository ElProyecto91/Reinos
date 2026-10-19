class_name IsoBuild
extends RefCounted
## Edificios del juego (almacén, cuartel, arquería, establo, taller, puerto, monasterio, herrería, mercado, mina) como
## modelos 3D procedurales. Mismas convenciones que IsoModels: 1 unidad = 1 casilla, origen en el centro de la huella a
## nivel del suelo; la cámara ve las caras +x y +z, así que ahí van puertas, ventanas y adornos.
## `team` es el gris neutro de IsoModels.TEAM_BASE: lo que se construye con fmat(team) se tiñe con el color del jugador.

const M = preload("res://tools/iso/iso_models.gd")

# ------------------------------------------------------------------ materiales y piezas comunes

static func mats(seed_v: int) -> Dictionary:
	return {
		"stone": M.tmat(M.tex_stone(seed_v, Color(0.64, 0.60, 0.54)), 1.1),
		"stone_d": M.tmat(M.tex_stone(seed_v + 1, Color(0.50, 0.47, 0.43)), 1.1),
		"stone_l": M.tmat(M.tex_stone(seed_v + 2, Color(0.74, 0.71, 0.65)), 1.1),
		"plaster": M.tmat(M.tex_plaster(seed_v + 3, Color(0.93, 0.87, 0.72)), 1.0),
		"wood": M.tmat(M.tex_wood(seed_v + 4, Color(0.34, 0.22, 0.12)), 1.4),
		"wood_l": M.tmat(M.tex_wood(seed_v + 5, Color(0.62, 0.46, 0.26)), 1.6),
		"wood_r": M.tmat(M.tex_wood(seed_v + 6, Color(0.55, 0.24, 0.16)), 1.4),
		"roof_r": M.tmat(M.tex_roof(seed_v + 7, Color(0.66, 0.26, 0.17)), 1.5),
		"roof_b": M.tmat(M.tex_roof(seed_v + 8, Color(0.46, 0.33, 0.22)), 1.5),
		"roof_s": M.tmat(M.tex_roof(seed_v + 9, Color(0.36, 0.40, 0.48)), 1.5),
		"roof_g": M.tmat(M.tex_roof(seed_v + 10, Color(0.30, 0.45, 0.28)), 1.5),
		"thatch": M.tmat(M.tex_roof(seed_v + 11, Color(0.80, 0.66, 0.30)), 1.3),
		"iron": M.fmat(Color(0.25, 0.25, 0.28), 0.6, 0.5),
		"steel": M.fmat(Color(0.56, 0.58, 0.64), 0.4, 0.7),
		"dark": M.fmat(Color(0.07, 0.06, 0.08), 0.9, 0.1),
		"glass": M.fmat(Color(0.10, 0.14, 0.22), 0.3, 0.8),
		"hay": M.fmat(Color(0.84, 0.72, 0.34), 0.95, 0.1),
		"straw": M.fmat(Color(0.88, 0.78, 0.45), 0.95, 0.1),
		"sack": M.fmat(Color(0.74, 0.64, 0.46), 0.95, 0.1),
		"rope": M.fmat(Color(0.62, 0.52, 0.34), 0.95, 0.1),
		"cloth_w": M.fmat(Color(0.94, 0.92, 0.84), 0.9, 0.1),
		"cloth_r": M.fmat(Color(0.76, 0.18, 0.14), 0.9, 0.1),
		"cloth_b": M.fmat(Color(0.20, 0.34, 0.66), 0.9, 0.1),
		"cloth_g": M.fmat(Color(0.28, 0.55, 0.26), 0.9, 0.1),
		"cloth_y": M.fmat(Color(0.92, 0.74, 0.20), 0.9, 0.1),
		"gold": M.fmat(Color(0.88, 0.70, 0.22), 0.35, 0.9),
		"fire": _glow(Color(1.0, 0.55, 0.12)),
		"red_fruit": M.fmat(Color(0.82, 0.16, 0.12), 0.8, 0.2),
		"green_fruit": M.fmat(Color(0.30, 0.52, 0.18), 0.8, 0.2),
		"bush": M.fmat(Color(0.20, 0.38, 0.16), 0.95, 0.1),
		"orange_fruit": M.fmat(Color(0.92, 0.56, 0.12), 0.8, 0.2),
	}

static func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

## Tejado a dos aguas con la cumbrera a lo largo de x. `wid` = ancho en z (con alero), `len` = largo en x.
static func roof_x(parent: Node3D, len: float, wid: float, rise: float, y_base: float, m: Material, pos: Vector3 = Vector3.ZERO) -> void:
	var rp := M.prism(parent, wid, rise, len, pos + Vector3(0, y_base + rise * 0.5, 0), m)
	rp.rotation_degrees.y = 90.0

## Tejado a dos aguas con la cumbrera a lo largo de z.
static func roof_z(parent: Node3D, len: float, wid: float, rise: float, y_base: float, m: Material, pos: Vector3 = Vector3.ZERO) -> void:
	M.prism(parent, wid, rise, len, pos + Vector3(0, y_base + rise * 0.5, 0), m)

## Tejado piramidal (cuatro aguas) sobre un cuadrado de lado `w`.
static func roof_pyr(parent: Node3D, w: float, h: float, y_base: float, m: Material, pos: Vector3 = Vector3.ZERO) -> void:
	var c := M.cyl(parent, 0.0, w * 0.7071, h, pos + Vector3(0, y_base + h * 0.5, 0), m, 4)
	c.rotation_degrees.y = 45.0

static func barrel(parent: Node3D, pos: Vector3, S: Dictionary, r: float = 0.11, h: float = 0.26) -> void:
	M.cyl(parent, r, r * 0.9, h, pos + Vector3(0, h * 0.5, 0), S.wood_l, 12)
	for k in [0.28, 0.72]:
		M.cyl(parent, r * 1.03, r * 1.0, 0.018, pos + Vector3(0, h * k, 0), S.iron, 12)
	M.cyl(parent, r * 0.86, r * 0.86, 0.01, pos + Vector3(0, h + 0.003, 0), S.wood, 12)

static func crate(parent: Node3D, pos: Vector3, S: Dictionary, s: float = 0.24, yaw: float = 0.0) -> void:
	var b := M.box(parent, Vector3(s, s, s), pos + Vector3(0, s * 0.5, 0), S.wood_l)
	b.rotation_degrees.y = yaw
	for sx in [-1, 1]:
		var st := M.box(parent, Vector3(s * 0.09, s * 1.02, s * 1.02), pos + Vector3(sx * s * 0.34, s * 0.5, 0), S.wood)
		st.rotation_degrees.y = yaw

static func sack(parent: Node3D, pos: Vector3, S: Dictionary, r: float = 0.11) -> void:
	M.ball(parent, r, pos + Vector3(0, r * 0.8, 0), S.sack, Vector3(1.0, 1.1, 0.9))
	M.ball(parent, r * 0.38, pos + Vector3(0, r * 1.75, 0), S.rope)

static func hay_bale(parent: Node3D, pos: Vector3, S: Dictionary, along_x: bool = true) -> void:
	var c := M.cyl(parent, 0.14, 0.14, 0.30, pos + Vector3(0, 0.14, 0), S.hay, 12)
	c.rotation_degrees.z = 90.0 if along_x else 0.0
	if not along_x:
		c.rotation_degrees.x = 90.0
	var band := M.cyl(parent, 0.145, 0.145, 0.02, pos + Vector3(0, 0.14, 0), S.rope, 12)
	band.rotation_degrees.z = 90.0 if along_x else 0.0
	if not along_x:
		band.rotation_degrees.x = 90.0

## Valla de postes y travesaños entre dos puntos (en el plano xz) a nivel del suelo.
static func fence(parent: Node3D, a: Vector3, b: Vector3, S: Dictionary, h: float = 0.30) -> void:
	var d := b - a
	var n := maxi(2, int(d.length() / 0.30))
	for i in n + 1:
		var p := a + d * (float(i) / float(n))
		M.box(parent, Vector3(0.05, h, 0.05), p + Vector3(0, h * 0.5, 0), S.wood)
	for y in [h * 0.42, h * 0.82]:
		var rail := M.box(parent, Vector3(d.length(), 0.035, 0.035), (a + b) * 0.5 + Vector3(0, y, 0), S.wood_l)
		rail.rotation.y = -atan2(d.z, d.x)

## Arco redondo de puerta (disco de madera/oscuro) sobre una puerta rectangular, en la cara +z o +x.
static func arched_door(parent: Node3D, pos: Vector3, w: float, h: float, face_x: bool, door_m: Material, frame_m: Material) -> void:
	var th := 0.07
	var sz := Vector3(th, h, w) if face_x else Vector3(w, h, th)
	M.box(parent, sz, pos + Vector3(0, h * 0.5, 0), door_m)
	var arch := M.cyl(parent, w * 0.5, w * 0.5, th, pos + Vector3(0, h, 0), door_m, 16)
	if face_x:
		arch.rotation_degrees.z = 90.0
	else:
		arch.rotation_degrees.x = 90.0
	# jambas y dintel de piedra
	for sgn in [-1, 1]:
		var o := Vector3(0, 0, sgn * (w * 0.5 + 0.035)) if face_x else Vector3(sgn * (w * 0.5 + 0.035), 0, 0)
		var jb := Vector3(th * 1.5, h + w * 0.5, 0.07) if face_x else Vector3(0.07, h + w * 0.5, th * 1.5)
		M.box(parent, jb, pos + o + Vector3(0, (h + w * 0.5) * 0.5, 0), frame_m)

static func window_s(parent: Node3D, pos: Vector3, w: float, h: float, face_x: bool, S: Dictionary) -> void:
	M._window(parent, pos, Vector3(0.03, h, w) if face_x else Vector3(w, h, 0.03), S.wood)

## Bandera de equipo colgante (paño vertical) sobre la cara +z (face_x = false) o +x
static func banner(parent: Node3D, pos: Vector3, team: Color, face_x: bool, w: float = 0.18, h: float = 0.50) -> void:
	var cloth := M.fmat(team, 0.9, 0.1)
	var pole := M.fmat(Color(0.30, 0.20, 0.10), 0.8, 0.3)
	var sz := Vector3(0.025, h, w) if face_x else Vector3(w, h, 0.025)
	var off := Vector3(0.04, 0, 0) if face_x else Vector3(0, 0, 0.04)
	M.box(parent, sz, pos + off + Vector3(0, -h * 0.5, 0), cloth)
	var rod := M.box(parent, Vector3(0.03, 0.03, w + 0.1) if face_x else Vector3(w + 0.1, 0.03, 0.03), pos + off + Vector3(0, 0.0, 0), pole)
	rod.name = "rod"
	var tip := M.box(parent, Vector3(0.035, h * 0.16, w * 0.55) if face_x else Vector3(w * 0.55, h * 0.16, 0.035), pos + off + Vector3(0.012 if face_x else 0.0, -h - h * 0.04, 0.0 if face_x else 0.012), M.fmat(Color(0.95, 0.92, 0.80), 0.9, 0.1))
	tip.name = "tip"

# ------------------------------------------------------------------ almacén 2x2

static func almacen(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := mats(101)
	M.box(root, Vector3(1.66, 0.14, 1.56), Vector3(0, 0.07, 0), S.stone)
	M.box(root, Vector3(1.52, 0.60, 1.40), Vector3(0, 0.14 + 0.30, 0), S.wood_l)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.09, 0.64, 0.09), Vector3(sx * 0.77, 0.46, sz * 0.72), S.wood)
	M.box(root, Vector3(1.60, 0.06, 0.07), Vector3(0, 0.76, 0.72), S.wood)
	M.box(root, Vector3(0.07, 0.06, 1.48), Vector3(0.77, 0.76, 0), S.wood)
	roof_x(root, 1.90, 1.84, 0.62, 0.76, S.roof_b)
	M.box(root, Vector3(1.96, 0.05, 0.06), Vector3(0, 1.40, 0), S.wood)
	# portón abierto en la cara +z: hueco oscuro, hojas a los lados y un travesaño
	M.box(root, Vector3(0.70, 0.50, 0.04), Vector3(-0.05, 0.14 + 0.25, 0.72), S.dark)
	for sx in [-1, 1]:
		var leaf := M.box(root, Vector3(0.34, 0.50, 0.04), Vector3(-0.05 + sx * 0.42, 0.14 + 0.25, 0.78), S.wood)
		leaf.rotation_degrees.y = float(sx) * 38.0
	M.box(root, Vector3(0.82, 0.05, 0.07), Vector3(-0.05, 0.68, 0.74), S.wood)
	# ventana alta en la cara +x y viga con polea
	window_s(root, Vector3(0.77, 0.50, -0.30), 0.22, 0.20, true, S)
	M.box(root, Vector3(0.06, 0.06, 0.40), Vector3(-0.05, 0.92, 0.88), S.wood)
	# mercancía fuera: barriles, cajas y sacos
	barrel(root, Vector3(1.02, 0.0, 0.30), S)
	barrel(root, Vector3(1.02, 0.0, 0.58), S)
	barrel(root, Vector3(0.90, 0.0, 0.44), S, 0.10, 0.22)
	crate(root, Vector3(0.62, 0.0, 0.92), S, 0.26, 12.0)
	crate(root, Vector3(0.90, 0.0, 0.92), S, 0.24, -8.0)
	crate(root, Vector3(0.76, 0.26, 0.92), S, 0.20, 25.0)
	sack(root, Vector3(-0.60, 0.0, 0.95), S)
	sack(root, Vector3(-0.78, 0.0, 0.85), S, 0.10)
	sack(root, Vector3(-0.68, 0.20, 0.92), S, 0.09)
	M._flag(root, Vector3(-0.70, 0.0, -0.80), team, 0.85)
	return root

# ------------------------------------------------------------------ cuartel 3x3

static func cuartel(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := mats(201)
	# sala larga de piedra con tejado rojo, cumbrera en x
	M.box(root, Vector3(2.56, 0.16, 1.96), Vector3(-0.0, 0.08, -0.22), S.stone_d)
	M.box(root, Vector3(2.40, 0.92, 1.80), Vector3(0, 0.16 + 0.46, -0.22), S.stone)
	M.box(root, Vector3(2.46, 0.06, 1.86), Vector3(0, 1.10, -0.22), S.stone_d)
	roof_x(root, 2.62, 2.06, 0.74, 1.12, S.roof_r, Vector3(0, 0, -0.22))
	M.box(root, Vector3(2.66, 0.07, 0.07), Vector3(0, 1.88, -0.22), S.roof_b)
	# torres redondas delanteras con techo cónico de equipo
	for sx in [-1, 1]:
		M.cyl(root, 0.40, 0.44, 0.14, Vector3(sx * 1.06, 0.07, 0.86), S.stone_d, 18)
		M.cyl(root, 0.34, 0.38, 1.40, Vector3(sx * 1.06, 0.14 + 0.70, 0.86), S.stone, 18)
		M.cyl(root, 0.42, 0.36, 0.16, Vector3(sx * 1.06, 1.60, 0.86), S.stone_d, 18)
		M.cyl(root, 0.0, 0.46, 0.62, Vector3(sx * 1.06, 1.99, 0.86), M.fmat(team, 0.8, 0.3), 18)
		for h in [0.55, 1.05]:
			M.box(root, Vector3(0.05, 0.22, 0.06), Vector3(sx * 1.06 + 0.35, h, 0.86), S.dark)
	# cuerpo de la puerta entre las torres: muro bajo con arco y rastrillo
	M.box(root, Vector3(1.50, 0.86, 0.34), Vector3(0, 0.14 + 0.43, 1.00), S.stone)
	M.box(root, Vector3(1.56, 0.07, 0.40), Vector3(0, 1.04, 1.00), S.stone_d)
	for k in 5:
		M.box(root, Vector3(0.20, 0.16, 0.34), Vector3(-0.64 + k * 0.32, 1.15, 1.00), S.stone)
	arched_door(root, Vector3(0, 0.14, 1.19), 0.56, 0.52, false, S.wood, S.stone_l)
	for k in 5:
		M.box(root, Vector3(0.025, 0.46, 0.03), Vector3(-0.20 + k * 0.10, 0.45, 1.22), S.iron)
	# estandartes y escudos
	banner(root, Vector3(-0.50, 0.98, 1.20), team, false, 0.20, 0.50)
	banner(root, Vector3(0.50, 0.98, 1.20), team, false, 0.20, 0.50)
	# ventanas de la sala (cara +x) y chimenea
	for wz in [-0.75, -0.25, 0.25]:
		window_s(root, Vector3(1.21, 0.62, wz), 0.20, 0.26, true, S)
	M.box(root, Vector3(0.24, 0.60, 0.24), Vector3(0.70, 1.65, -0.60), S.stone)
	M.box(root, Vector3(0.30, 0.05, 0.30), Vector3(0.70, 1.96, -0.60), S.stone_d)
	# patio: maniquí de entrenamiento y soporte de lanzas
	var post := M.box(root, Vector3(0.05, 0.62, 0.05), Vector3(1.20, 0.31, 1.15), S.wood)
	M.box(root, Vector3(0.40, 0.05, 0.05), Vector3(1.20, 0.50, 1.15), S.wood)
	M.ball(root, 0.08, Vector3(1.20, 0.70, 1.15), S.sack)
	M.box(root, Vector3(0.20, 0.20, 0.10), Vector3(1.20, 0.38, 1.15), S.sack)
	for k in 4:
		var sp := M.box(root, Vector3(0.02, 0.78, 0.02), Vector3(-1.05 + k * 0.08, 0.40, 1.42), S.wood_l)
		sp.rotation_degrees.x = -8.0
		M.box(root, Vector3(0.03, 0.08, 0.03), Vector3(-1.05 + k * 0.08, 0.80, 1.40), S.steel)
	M.box(root, Vector3(0.42, 0.04, 0.05), Vector3(-0.96, 0.22, 1.43), S.wood)
	M._flag(root, Vector3(-1.2, 0.0, -1.1), team, 1.0)
	return root

# ------------------------------------------------------------------ arquería 3x3

static func arqueria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := mats(301)
	# edificio principal (entramado) al fondo-izquierda
	var c := Vector3(-0.35, 0, -0.45)
	M.box(root, Vector3(2.10, 0.18, 1.40), c + Vector3(0, 0.09, 0), S.stone)
	M.box(root, Vector3(1.96, 0.70, 1.26), c + Vector3(0, 0.18 + 0.35, 0), S.plaster)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.10, 0.72, 0.10), c + Vector3(sx * 0.98, 0.54, sz * 0.63), S.wood)
	for k in [-0.5, 0.0, 0.5]:
		M.box(root, Vector3(0.07, 0.70, 0.07), c + Vector3(k * 1.5, 0.54, 0.65), S.wood)
		M.box(root, Vector3(0.07, 0.70, 0.07), c + Vector3(1.0, 0.54, k * 1.0), S.wood)
	M.box(root, Vector3(2.04, 0.07, 0.07), c + Vector3(0, 0.90, 0.65), S.wood)
	M.box(root, Vector3(0.07, 0.07, 1.30), c + Vector3(1.0, 0.90, 0), S.wood)
	roof_x(root, 2.30, 1.74, 0.74, 0.90, S.roof_g, c)
	M.box(root, Vector3(2.34, 0.06, 0.06), c + Vector3(0, 1.64, 0), S.wood)
	arched_door(root, c + Vector3(-0.30, 0.18, 0.64), 0.40, 0.46, false, S.wood, S.stone_l)
	window_s(root, c + Vector3(0.50, 0.58, 0.64), 0.30, 0.22, false, S)
	window_s(root, c + Vector3(1.00, 0.58, -0.15), 0.22, 0.24, true, S)
	banner(root, c + Vector3(0.0, 0.88, 0.70), team, false, 0.22, 0.46)
	# campo de tiro: valla y dianas de paja con anillos y flechas
	fence(root, Vector3(0.70, 0, 1.40), Vector3(1.40, 0, 1.40), S)
	fence(root, Vector3(1.40, 0, 1.40), Vector3(1.40, 0, 0.0), S)
	fence(root, Vector3(-1.40, 0, 1.40), Vector3(0.30, 0, 1.40), S)
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
		M.cyl(tgt, 0.145, 0.145, 0.08, Vector3.ZERO, M.fmat(team, 0.85, 0.2), 20)
		M.cyl(tgt, 0.075, 0.075, 0.085, Vector3.ZERO, S.cloth_w, 20)
		for a in [Vector2(0.03, 0.06), Vector2(-0.10, -0.05), Vector2(0.12, -0.08)]:
			var ar := M.box(tgt, Vector3(0.02, 0.36, 0.02), Vector3(a.x, 0.0, a.y), S.wood_l)
			ar.rotation_degrees.x = 90.0
			ar.position = Vector3(a.x, -0.14, a.y)
	# carcaj de flechas y fardos junto a la entrada
	barrel(root, Vector3(-1.30, 0.0, 0.30), S, 0.10, 0.26)
	for k in 4:
		var ar2 := M.box(root, Vector3(0.015, 0.44, 0.015), Vector3(-1.30 + (k - 1.5) * 0.025, 0.46, 0.30), S.wood_l)
		ar2.rotation_degrees.z = (k - 1.5) * 4.0
	hay_bale(root, Vector3(-0.90, 0.0, 1.05), S)
	hay_bale(root, Vector3(-0.60, 0.0, 1.05), S)
	return root

# ------------------------------------------------------------------ establo 3x3

static func establo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := mats(401)
	var c := Vector3(-0.15, 0, -0.35)
	M.box(root, Vector3(2.30, 0.16, 1.62), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.16, 0.78, 1.48), c + Vector3(0, 0.16 + 0.39, 0), S.wood_r)
	# tablas y refuerzos
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.10, 0.82, 0.10), c + Vector3(sx * 1.08, 0.57, sz * 0.74), S.wood)
	M.box(root, Vector3(2.24, 0.07, 0.07), c + Vector3(0, 0.96, 0.75), S.wood)
	M.box(root, Vector3(0.07, 0.07, 1.54), c + Vector3(1.09, 0.96, 0), S.wood)
	roof_x(root, 2.46, 1.92, 0.86, 0.94, S.thatch, c)
	M.box(root, Vector3(2.50, 0.07, 0.08), c + Vector3(0, 1.82, 0), S.thatch)
	# portón doble con aspas (cara +z) y ventanuco del pajar
	for sx in [-1, 1]:
		M.box(root, Vector3(0.46, 0.62, 0.05), c + Vector3(sx * 0.25, 0.16 + 0.31, 0.75), S.wood)
		var d1 := M.box(root, Vector3(0.55, 0.04, 0.03), c + Vector3(sx * 0.25, 0.16 + 0.31, 0.79), S.wood_l)
		d1.rotation_degrees.z = 48.0 * sx
		var d2 := M.box(root, Vector3(0.55, 0.04, 0.03), c + Vector3(sx * 0.25, 0.16 + 0.31, 0.79), S.wood_l)
		d2.rotation_degrees.z = -48.0 * sx
	M.box(root, Vector3(0.30, 0.26, 0.04), c + Vector3(0, 1.20, 0.80), S.dark)
	window_s(root, c + Vector3(1.09, 0.60, 0.20), 0.30, 0.26, true, S)
	window_s(root, c + Vector3(1.09, 0.60, -0.40), 0.30, 0.26, true, S)
	# veleta con caballo estilizado
	M.cyl(root, 0.015, 0.015, 0.34, c + Vector3(0.7, 2.00, 0), S.iron, 6)
	M.box(root, Vector3(0.20, 0.12, 0.02), c + Vector3(0.7, 2.18, 0), S.iron)
	M.box(root, Vector3(0.07, 0.12, 0.02), c + Vector3(0.78, 2.26, 0), S.iron)
	# cercado con abrevadero y fardos
	fence(root, Vector3(0.95, 0, 1.45), Vector3(1.45, 0, 1.45), S)
	fence(root, Vector3(1.45, 0, 1.45), Vector3(1.45, 0, 0.35), S)
	fence(root, Vector3(-1.40, 0, 1.45), Vector3(0.20, 0, 1.45), S)
	var tr := M.box(root, Vector3(0.50, 0.12, 0.16), Vector3(1.22, 0.10, 1.15), S.wood)
	M.box(root, Vector3(0.44, 0.02, 0.10), Vector3(1.22, 0.17, 1.15), M.fmat(Color(0.25, 0.50, 0.65), 0.2, 0.9))
	hay_bale(root, Vector3(1.20, 0.0, 0.62), S, false)
	hay_bale(root, Vector3(1.22, 0.30, 0.64), S, false)
	hay_bale(root, Vector3(-1.05, 0.0, 1.00), S)
	hay_bale(root, Vector3(-0.72, 0.0, 1.05), S)
	banner(root, c + Vector3(0.62, 0.92, 0.78), team, false, 0.20, 0.48)
	return root

# ------------------------------------------------------------------ taller de asedio 3x3

static func taller(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := mats(501)
	var c := Vector3(-0.2, 0, -0.35)
	M.box(root, Vector3(2.30, 0.16, 1.60), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.16, 0.30, 1.46), c + Vector3(0, 0.16 + 0.15, 0), S.stone)
	# armazón de vigas con relleno de yeso y gran puerta
	M.box(root, Vector3(2.16, 0.72, 1.46), c + Vector3(0, 0.46 + 0.36, 0), S.plaster)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.12, 0.76, 0.12), c + Vector3(sx * 1.08, 0.84, sz * 0.73), S.wood)
	for k in [-0.7, -0.35, 0.0, 0.35, 0.7]:
		M.box(root, Vector3(0.06, 0.72, 0.06), c + Vector3(k * 1.4, 0.82, 0.75), S.wood)
	for k in [-0.5, 0.0, 0.5]:
		M.box(root, Vector3(0.06, 0.72, 0.06), c + Vector3(1.09, 0.82, k), S.wood)
	roof_x(root, 2.46, 1.90, 0.70, 1.22, S.roof_s, c)
	M.box(root, Vector3(2.50, 0.06, 0.07), c + Vector3(0, 1.94, 0), S.wood)
	# portón ancho
	M.box(root, Vector3(0.96, 0.66, 0.05), c + Vector3(-0.30, 0.16 + 0.33, 0.74), S.wood)
	M.box(root, Vector3(0.03, 0.66, 0.06), c + Vector3(-0.30, 0.49, 0.77), S.iron)
	for y in [0.30, 0.62]:
		M.box(root, Vector3(0.96, 0.04, 0.06), c + Vector3(-0.30, y, 0.77), S.iron)
	# rueda dentada en la cara +x
	var gear := Node3D.new()
	gear.position = c + Vector3(1.12, 0.74, 0.30)
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
	window_s(root, c + Vector3(1.09, 0.74, -0.40), 0.26, 0.24, true, S)
	# grúa de madera con cuerda y gancho junto a la fachada
	M.box(root, Vector3(0.10, 1.40, 0.10), Vector3(0.95, 0.70, 1.15), S.wood)
	var jib := M.box(root, Vector3(0.80, 0.07, 0.07), Vector3(0.62, 1.38, 1.15), S.wood)
	var brace := M.box(root, Vector3(0.50, 0.05, 0.05), Vector3(0.78, 1.14, 1.15), S.wood)
	brace.rotation_degrees.z = 40.0
	M.box(root, Vector3(0.015, 0.56, 0.015), Vector3(0.38, 1.10, 1.15), S.rope)
	M.box(root, Vector3(0.07, 0.07, 0.07), Vector3(0.38, 0.80, 1.15), S.iron)
	# troncos apilados y bastidor de ariete a medio hacer
	for k in 3:
		var lg := M.cyl(root, 0.08, 0.08, 0.80, Vector3(-1.20, 0.08 + (k % 2) * 0.12, 0.45 + (k / 2) * 0.16 + (k % 2) * 0.08), S.wood_l, 10)
		lg.rotation_degrees.x = 90.0
	for k in 2:
		var lg2 := M.cyl(root, 0.08, 0.08, 0.80, Vector3(-1.20, 0.20, 0.55 + k * 0.18), S.wood_l, 10)
		lg2.rotation_degrees.x = 90.0
	var fr := Vector3(-0.30, 0, 1.30)
	for sx in [-0.40, 0.40]:
		M.box(root, Vector3(0.06, 0.34, 0.06), fr + Vector3(sx, 0.17, 0.0), S.wood)
	M.box(root, Vector3(0.90, 0.06, 0.07), fr + Vector3(0, 0.34, 0.0), S.wood)
	var ram := M.cyl(root, 0.05, 0.05, 0.78, fr + Vector3(0, 0.22, 0.0), S.wood_l, 8)
	ram.rotation_degrees.z = 90.0
	M.box(root, Vector3(0.10, 0.10, 0.10), fr + Vector3(0.40, 0.22, 0.0), S.iron)
	banner(root, c + Vector3(0.45, 1.00, 0.78), team, false, 0.20, 0.44)
	return root

# ------------------------------------------------------------------ puerto 3x3 (mira al agua por +z; se gira en el horneado)

static func puerto(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := mats(601)
	var c := Vector3(0.0, 0, -0.45)
	M.box(root, Vector3(2.30, 0.16, 1.40), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.14, 0.76, 1.26), c + Vector3(0, 0.16 + 0.38, 0), S.wood_l)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.11, 0.80, 0.11), c + Vector3(sx * 1.07, 0.56, sz * 0.63), S.wood)
	M.box(root, Vector3(2.22, 0.07, 0.07), c + Vector3(0, 0.94, 0.64), S.wood)
	M.box(root, Vector3(0.07, 0.07, 1.30), c + Vector3(1.08, 0.94, 0), S.wood)
	roof_x(root, 2.44, 1.72, 0.74, 0.94, S.roof_s, c)
	M.box(root, Vector3(2.48, 0.06, 0.07), c + Vector3(0, 1.70, 0), S.wood)
	# portones al muelle
	for sx in [-1, 1]:
		M.box(root, Vector3(0.44, 0.60, 0.05), c + Vector3(sx * 0.26 - 0.40, 0.16 + 0.30, 0.64), S.wood)
	M.box(root, Vector3(0.05, 0.60, 0.06), c + Vector3(-0.40, 0.46, 0.67), S.iron)
	window_s(root, c + Vector3(1.07, 0.62, 0.10), 0.26, 0.24, true, S)
	window_s(root, c + Vector3(1.07, 0.62, -0.40), 0.26, 0.24, true, S)
	# plataforma de tablones al frente (muelle)
	M.box(root, Vector3(2.20, 0.08, 0.70), Vector3(0, 0.04, 1.00), S.wood_l)
	for k in 8:
		M.box(root, Vector3(0.015, 0.09, 0.70), Vector3(-1.05 + k * 0.30, 0.045, 1.00), S.wood)
	for sx in [-1.05, 0.0, 1.05]:
		M.cyl(root, 0.07, 0.07, 0.30, Vector3(sx, 0.15, 1.34), S.wood, 8)
	# grúa de carga con cuerda
	M.box(root, Vector3(0.10, 1.30, 0.10), Vector3(0.95, 0.65, 0.85), S.wood)
	M.box(root, Vector3(0.90, 0.07, 0.08), Vector3(0.52, 1.28, 0.85), S.wood)
	var br2 := M.box(root, Vector3(0.50, 0.05, 0.05), Vector3(0.70, 1.04, 0.85), S.wood)
	br2.rotation_degrees.z = 40.0
	M.box(root, Vector3(0.015, 0.50, 0.015), Vector3(0.12, 1.02, 0.85), S.rope)
	M.box(root, Vector3(0.16, 0.14, 0.16), Vector3(0.12, 0.72, 0.85), S.wood_l)
	# barriles, cajas, rollo de cuerda y bote pequeño
	barrel(root, Vector3(-0.85, 0.08, 0.95), S)
	barrel(root, Vector3(-0.60, 0.08, 1.05), S, 0.10, 0.22)
	crate(root, Vector3(-0.30, 0.08, 1.08), S, 0.26, 10.0)
	crate(root, Vector3(-0.10, 0.08, 1.12), S, 0.22, -12.0)
	var coil := M.cyl(root, 0.12, 0.12, 0.08, Vector3(0.40, 0.12, 1.08), S.rope, 14)
	M.cyl(root, 0.05, 0.05, 0.09, Vector3(0.40, 0.12, 1.08), S.dark, 10)
	banner(root, c + Vector3(-0.85, 1.05, 0.70), team, false, 0.22, 0.50)
	M._flag(root, Vector3(1.20, 0.0, 1.30), team, 0.95)
	return root

# ------------------------------------------------------------------ monasterio 3x3

static func monasterio(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := mats(701)
	# nave: piedra clara con tejado azul pizarra, cumbrera en x
	var c := Vector3(-0.1, 0, -0.45)
	M.box(root, Vector3(2.40, 0.18, 1.60), c + Vector3(0, 0.09, 0), S.stone_d)
	M.box(root, Vector3(2.24, 1.02, 1.46), c + Vector3(0, 0.18 + 0.51, 0), S.stone_l)
	M.box(root, Vector3(2.30, 0.07, 1.52), c + Vector3(0, 1.22, 0), S.stone)
	roof_x(root, 2.52, 1.84, 0.82, 1.24, S.roof_s, c)
	M.box(root, Vector3(2.56, 0.07, 0.07), c + Vector3(0, 2.06, 0), S.stone_d)
	# contrafuertes y ventanales de arco (cara +x)
	for wz in [-0.50, 0.05, 0.60]:
		M.box(root, Vector3(0.12, 0.96, 0.12), c + Vector3(1.16, 0.66, wz - 0.28), S.stone)
		var win := M.box(root, Vector3(0.04, 0.46, 0.20), c + Vector3(1.13, 0.80, wz), S.glass)
		var wa := M.cyl(root, 0.10, 0.10, 0.04, c + Vector3(1.13, 1.03, wz), S.glass, 12)
		wa.rotation_degrees.z = 90.0
	# campanario cuadrado al frente con aguja y reloj
	var tc := Vector3(0.0, 0, 0.78)
	M.box(root, Vector3(0.90, 1.9, 0.90), tc + Vector3(0, 0.95, 0), S.stone_l)
	M.box(root, Vector3(1.0, 0.08, 1.0), tc + Vector3(0, 1.92, 0), S.stone)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.12, 0.50, 0.12), tc + Vector3(sx * 0.34, 2.21, sz * 0.34), S.stone)
	M.box(root, Vector3(0.26, 0.26, 0.26), tc + Vector3(0, 2.15, 0), S.gold)
	roof_pyr(root, 1.04, 1.05, 2.42, S.roof_s, tc)
	M.cyl(root, 0.012, 0.012, 0.40, tc + Vector3(0, 3.70, 0), S.gold, 6)
	M.box(root, Vector3(0.20, 0.03, 0.03), tc + Vector3(0, 3.78, 0), S.gold)
	M.box(root, Vector3(0.03, 0.20, 0.03), tc + Vector3(0, 3.74, 0), S.gold)
	# portal con arco y rosetón sobre él
	arched_door(root, tc + Vector3(0, 0.18, 0.46), 0.42, 0.52, false, S.wood, S.stone)
	M.box(root, Vector3(0.62, 0.07, 0.10), tc + Vector3(0, 0.18, 0.50), S.stone_d)
	var rose := M.cyl(root, 0.18, 0.18, 0.04, tc + Vector3(0, 1.30, 0.46), S.glass, 20)
	rose.rotation_degrees.x = 90.0
	var rose2 := M.cyl(root, 0.075, 0.075, 0.05, tc + Vector3(0, 1.30, 0.465), M.fmat(team, 0.4, 0.5), 12)
	rose2.rotation_degrees.x = 90.0
	M.box(root, Vector3(0.04, 0.40, 0.04), tc + Vector3(0, 1.30, 0.485), S.stone)
	M.box(root, Vector3(0.40, 0.04, 0.04), tc + Vector3(0, 1.30, 0.485), S.stone)
	# huerto-claustro: seto con cruz y estandarte
	M.box(root, Vector3(0.50, 0.10, 0.50), Vector3(1.05, 0.05, 1.05), S.stone)
	M.ball(root, 0.20, Vector3(1.05, 0.22, 1.05), S.bush, Vector3(1, 0.7, 1))
	banner(root, tc + Vector3(-0.50, 1.00, 0.46), team, false, 0.18, 0.55)
	banner(root, tc + Vector3(0.50, 1.00, 0.46), team, false, 0.18, 0.55)
	return root

# ------------------------------------------------------------------ herrería 3x3

static func herreria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := mats(801)
	var c := Vector3(-0.2, 0, -0.35)
	M.box(root, Vector3(2.20, 0.16, 1.56), c + Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.04, 0.86, 1.40), c + Vector3(0, 0.16 + 0.43, 0), S.stone)
	M.box(root, Vector3(2.10, 0.06, 1.46), c + Vector3(0, 1.05, 0), S.stone_d)
	roof_x(root, 2.30, 1.76, 0.62, 1.06, S.roof_s, c)
	M.box(root, Vector3(2.34, 0.06, 0.07), c + Vector3(0, 1.68, 0), S.wood)
	# gran chimenea de piedra en la cara +x con brasas
	M.box(root, Vector3(0.52, 1.80, 0.52), c + Vector3(1.20, 0.90, -0.30), S.stone_d)
	M.box(root, Vector3(0.60, 0.07, 0.60), c + Vector3(1.20, 1.80, -0.30), S.stone)
	M.box(root, Vector3(0.30, 0.04, 0.30), c + Vector3(1.20, 1.84, -0.30), S.dark)
	M.box(root, Vector3(0.10, 0.30, 0.34), c + Vector3(1.48, 0.34, -0.30), S.fire)
	M.box(root, Vector3(0.10, 0.36, 0.40), c + Vector3(1.47, 0.32, -0.30), S.dark)
	M.box(root, Vector3(0.12, 0.26, 0.28), c + Vector3(1.49, 0.34, -0.30), S.fire)
	# puerta con fachada abierta en +z: forja a la vista
	M.box(root, Vector3(0.80, 0.62, 0.04), c + Vector3(-0.40, 0.16 + 0.31, 0.71), S.dark)
	M.box(root, Vector3(0.84, 0.05, 0.07), c + Vector3(-0.40, 0.82, 0.72), S.wood)
	for sx in [-1, 1]:
		M.box(root, Vector3(0.07, 0.66, 0.07), c + Vector3(-0.40 + sx * 0.42, 0.50, 0.73), S.wood)
	M.box(root, Vector3(0.20, 0.20, 0.03), c + Vector3(-0.60, 0.30, 0.70), S.fire)
	window_s(root, c + Vector3(0.40, 0.62, 0.71), 0.26, 0.24, false, S)
	# yunque, tajo y cubo de agua fuera; espadas colgadas
	var ay := Vector3(0.45, 0, 1.05)
	M.box(root, Vector3(0.18, 0.18, 0.18), ay + Vector3(0, 0.09, 0), S.wood_l)
	M.box(root, Vector3(0.30, 0.07, 0.12), ay + Vector3(0, 0.215, 0), S.iron)
	M.box(root, Vector3(0.10, 0.05, 0.10), ay + Vector3(0.18, 0.21, 0), S.iron)
	barrel(root, Vector3(-0.30, 0.0, 1.12), S, 0.13, 0.30)
	M.box(root, Vector3(0.24, 0.015, 0.24), Vector3(-0.30, 0.295, 1.12), M.fmat(Color(0.25, 0.50, 0.65), 0.2, 0.9))
	for k in 3:
		M.box(root, Vector3(0.025, 0.34, 0.012), c + Vector3(1.0 + 0.0, 0.64, 0.20 + k * 0.14), S.steel)
		M.box(root, Vector3(0.012, 0.16, 0.006), c + Vector3(1.0 + 0.0, 0.46, 0.20 + k * 0.14), S.wood)
	# montón de carbón y lingotes
	M.ball(root, 0.14, Vector3(-1.10, 0.10, 1.00), S.dark, Vector3(1.4, 0.7, 1.1))
	M.box(root, Vector3(0.18, 0.05, 0.08), Vector3(-0.88, 0.03, 1.12), S.steel)
	M.box(root, Vector3(0.18, 0.05, 0.08), Vector3(-0.88, 0.08, 1.12), S.steel)
	banner(root, c + Vector3(0.40, 0.95, 0.75), team, false, 0.20, 0.42)
	return root

# ------------------------------------------------------------------ mercado 3x3

static func puesto(parent: Node3D, pos: Vector3, yaw: float, awning: Material, goods: Array, S: Dictionary) -> void:
	var st := Node3D.new()
	st.position = pos
	st.rotation_degrees.y = yaw
	parent.add_child(st)
	# mostrador, postes y toldo a rayas inclinado
	M.box(st, Vector3(0.78, 0.30, 0.34), Vector3(0, 0.15, 0.0), S.wood_l)
	M.box(st, Vector3(0.82, 0.03, 0.38), Vector3(0, 0.315, 0.0), S.wood)
	for sx in [-1, 1]:
		M.box(st, Vector3(0.04, 0.86, 0.04), Vector3(sx * 0.38, 0.43, -0.16), S.wood)
		M.box(st, Vector3(0.04, 0.70, 0.04), Vector3(sx * 0.38, 0.35, 0.16), S.wood)
	var aw := M.box(st, Vector3(0.90, 0.03, 0.54), Vector3(0, 0.80, 0.0), awning)
	aw.rotation_degrees.x = 14.0
	for k in 5:
		var strip := M.box(st, Vector3(0.09, 0.034, 0.54), Vector3(-0.36 + k * 0.18, 0.80, 0.0), S.cloth_w)
		strip.rotation_degrees.x = 14.0
	M.box(st, Vector3(0.90, 0.10, 0.03), Vector3(0, 0.70, 0.26), awning)
	# género sobre el mostrador
	var i := 0
	for g: Material in goods:
		M.ball(st, 0.07, Vector3(-0.28 + i * 0.14, 0.40, 0.0), g, Vector3(1, 0.9, 1))
		M.ball(st, 0.07, Vector3(-0.28 + i * 0.14, 0.40, 0.11), g, Vector3(1, 0.9, 1))
		i += 1

static func mercado(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := mats(901)
	# plaza empedrada con borde
	M.box(root, Vector3(2.70, 0.10, 2.70), Vector3(0, 0.05, 0), S.stone_l)
	M.box(root, Vector3(2.50, 0.04, 2.50), Vector3(0, 0.12, 0), S.stone)
	var tm := M.fmat(team, 0.85, 0.2)
	# cuatro puestos alrededor de la plaza con toldos de colores
	puesto(root, Vector3(-0.60, 0.10, -1.05), 0.0, tm, [S.red_fruit, S.green_fruit, S.red_fruit, S.orange_fruit], S)
	puesto(root, Vector3(0.55, 0.10, -1.05), 0.0, S.cloth_b, [S.orange_fruit, S.orange_fruit, S.green_fruit, S.red_fruit], S)
	puesto(root, Vector3(-1.05, 0.10, 0.35), 90.0, S.cloth_g, [S.red_fruit, S.orange_fruit, S.red_fruit, S.green_fruit], S)
	puesto(root, Vector3(1.05, 0.10, 0.55), -90.0, S.cloth_y, [S.green_fruit, S.red_fruit, S.orange_fruit, S.red_fruit], S)
	# pozo central con asta y bandera de equipo
	M.cyl(root, 0.26, 0.26, 0.26, Vector3(0.0, 0.26, 0.10), S.stone_d, 16)
	M.cyl(root, 0.20, 0.20, 0.03, Vector3(0.0, 0.40, 0.10), M.fmat(Color(0.25, 0.50, 0.65), 0.2, 0.9), 16)
	for sx in [-1, 1]:
		M.box(root, Vector3(0.04, 0.50, 0.04), Vector3(sx * 0.22, 0.65, 0.10), S.wood)
	M.box(root, Vector3(0.52, 0.04, 0.05), Vector3(0.0, 0.90, 0.10), S.wood)
	roof_x(root, 0.60, 0.46, 0.14, 0.92, S.roof_r, Vector3(0, 0, 0.10))
	M._flag(root, Vector3(0.0, 0.10, 1.12), team, 1.30)
	# cajas, barriles y sacos de mercancía
	crate(root, Vector3(1.05, 0.10, -0.15), S, 0.26, 12.0)
	crate(root, Vector3(1.10, 0.10, 0.10), S, 0.22, -9.0)
	barrel(root, Vector3(-0.95, 0.10, -0.50), S)
	barrel(root, Vector3(-0.70, 0.10, -0.45), S, 0.10, 0.22)
	sack(root, Vector3(0.60, 0.10, 1.10), S)
	sack(root, Vector3(0.80, 0.10, 1.00), S, 0.10)
	sack(root, Vector3(-0.60, 0.10, 1.10), S, 0.10)
	crate(root, Vector3(-0.85, 0.10, 0.95), S, 0.24, 20.0)
	return root

# ------------------------------------------------------------------ mina 2x2 (sólo visible durante la obra: el edificio terminado se convierte en la mina de oro)

static func mina(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := mats(1001)
	var rock := M.tmat(M.tex_stone(1002, Color(0.46, 0.45, 0.47)), 1.8)
	# montículo de roca con la boca de la mina
	M.lump(root, 0.62, Vector3(-0.10, 0.34, -0.30), rock, 1003, 0.30, 0.8)
	M.lump(root, 0.44, Vector3(0.45, 0.26, -0.20), rock, 1004, 0.30, 0.8)
	M.lump(root, 0.40, Vector3(-0.50, 0.22, 0.20), rock, 1005, 0.30, 0.8)
	# marco de entibación de madera
	M.box(root, Vector3(0.64, 0.52, 0.30), Vector3(0.0, 0.26, 0.28), S.dark)
	for sx in [-1, 1]:
		M.box(root, Vector3(0.08, 0.62, 0.10), Vector3(sx * 0.34, 0.31, 0.46), S.wood)
	M.box(root, Vector3(0.84, 0.09, 0.12), Vector3(0.0, 0.62, 0.46), S.wood)
	roof_x(root, 0.70, 0.46, 0.14, 0.67, S.wood_l, Vector3(0, 0, 0.46))
	# vagoneta con oro y carriles
	M.box(root, Vector3(0.30, 0.16, 0.22), Vector3(0.0, 0.14, 0.88), S.wood_l)
	M.box(root, Vector3(0.34, 0.03, 0.26), Vector3(0.0, 0.07, 0.88), S.iron)
	for sx in [-1, 1]:
		M.cyl(root, 0.06, 0.06, 0.03, Vector3(sx * 0.15, 0.06, 0.88), S.iron, 10).rotation_degrees.x = 90.0
	M.ball(root, 0.10, Vector3(0.0, 0.26, 0.88), S.gold, Vector3(1.2, 0.8, 1.0))
	for k in 3:
		M.box(root, Vector3(0.04, 0.02, 0.60), Vector3(-0.16 + k * 0.02, 0.02, 0.62), S.wood)
	# pico y pala clavados + bandera
	var pk := M.box(root, Vector3(0.03, 0.46, 0.03), Vector3(0.62, 0.23, 0.70), S.wood_l)
	pk.rotation_degrees.z = 10.0
	M.box(root, Vector3(0.22, 0.03, 0.03), Vector3(0.58, 0.46, 0.70), S.iron)
	M._flag(root, Vector3(-0.72, 0.0, 0.70), team, 0.80)
	return root
