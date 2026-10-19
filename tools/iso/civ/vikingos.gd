extends RefCounted
## Vikingos: arquitectura de madera nórdica. Casas largas de tablones con techo de turba, cuernos de dragón cruzados en los
## hastiales, hileras de escudos redondos bajo el alero, iglesia de duelas (stavkirke) de tejados escalonados con cabezas de
## dragón, almacén sobre pilotes (stabbur), drakkar con vela a rayas en el puerto, runas, y en lugar de muralla de piedra una
## empalizada de troncos aguzados. Los escudos y la vela llevan el color del jugador.

const A = preload("res://tools/iso/iso_arch.gd")
const M = preload("res://tools/iso/iso_models.gd")
const B = preload("res://tools/iso/iso_build.gd")

func build(type: String, team: Color) -> Node3D:
	return call(type, team) as Node3D

func pal(seed_v: int) -> Dictionary:
	var S := A.plain()
	S["wall"] = A.mat("wood", seed_v + 1, Color(0.47, 0.31, 0.18), 1.3)
	S["wall_d"] = A.mat("wood", seed_v + 2, Color(0.25, 0.16, 0.10), 1.4)
	S["wall_l"] = A.mat("wood", seed_v + 3, Color(0.64, 0.47, 0.28), 1.5)
	S["red"] = A.mat("wood", seed_v + 4, Color(0.50, 0.16, 0.11), 1.4)
	S["turf"] = A.mat("turf", seed_v + 5, Color(0.44, 0.42, 0.18), 1.1)
	S["shingle"] = A.mat("roof", seed_v + 6, Color(0.31, 0.22, 0.15), 1.7)
	S["shingle_l"] = A.mat("roof", seed_v + 7, Color(0.40, 0.29, 0.19), 1.7)
	S["stone"] = A.mat("stone", seed_v + 8, Color(0.52, 0.50, 0.46), 1.2)
	S["stone_d"] = A.mat("stone", seed_v + 9, Color(0.38, 0.37, 0.35), 1.2)
	S["stone_l"] = A.mat("stone", seed_v + 10, Color(0.68, 0.66, 0.60), 1.2)
	S["planks"] = A.mat("planks", seed_v + 11, Color(0.44, 0.31, 0.18), 1.4)
	# nombres que esperan las piezas comunes del kit (corrales, muelles, fraguas, ventanas…)
	S["wood"] = S["wall_d"]
	S["wood_l"] = S["wall_l"]
	S["plaster"] = A.mat("plaster", seed_v + 12, Color(0.80, 0.74, 0.60), 1.0)
	return S

func _tm(team: Color) -> StandardMaterial3D:
	return M.fmat(team, 0.85, 0.2)

## Cuernos cruzados de la cumbre del hastial (cabezas de dragón). Miran a +z o a +x.
func _horns(root: Node3D, S: Dictionary, pos: Vector3, face_x: bool, s: float = 1.0) -> void:
	var th := deg_to_rad(36.0)
	for sg in [-1.0, 1.0]:
		var b := M.box(root, Vector3(0.05, 0.50, 0.05) * s, pos + Vector3(0, 0.16 * s, 0), S.wall_d)
		var tip: Vector3
		if face_x:
			b.rotation_degrees.x = sg * 36.0
			tip = Vector3(0.0, cos(th) * 0.25 * s, sin(th) * 0.25 * s * sg)
		else:
			b.rotation_degrees.z = sg * 36.0
			tip = Vector3(-sin(th) * 0.25 * s * sg, cos(th) * 0.25 * s, 0.0)
		var hp := pos + Vector3(0, 0.16 * s, 0) + tip
		M.ball(root, 0.045 * s, hp, S.wall_l, Vector3(1.0, 1.1, 1.3))
		M.box(root, Vector3(0.03, 0.03, 0.09) * s, hp + (Vector3(0.0, 0.0, 0.05 * s) if not face_x else Vector3(0.05 * s, 0.0, 0.0)), S.wall_l)

## Hilera de escudos redondos (de n) a partir de `from`, avanzando `step`; alternan color de equipo, blanco y amarillo.
func _shields(root: Node3D, S: Dictionary, from: Vector3, step: Vector3, n: int, face_x: bool, r: float, tm: Material) -> void:
	for i in n:
		var f: Material = [tm, S.cloth_w, S.cloth_y, tm, S.cloth_r][i % 5]
		A.shield(root, from + step * float(i), r, face_x, S.iron, f)

## Casa larga: zócalo de piedra, muro de tablones, techo de turba (cumbrera a lo largo de x, aleros anchos), hastial +x cerrado con
## tablones y cuernos de dragón. c = centro de la huella; devuelve la y del alero.
func _long(root: Node3D, S: Dictionary, c: Vector3, w: float, d: float, wh: float, rise: float, roof_m: Material, horns: bool = true) -> float:
	var yb := 0.12 + wh
	M.box(root, Vector3(w + 0.10, 0.12, d + 0.10), c + Vector3(0, 0.06, 0), S.stone_d)
	M.box(root, Vector3(w, wh, d), c + Vector3(0, 0.12 + wh * 0.5, 0), S.wall)
	M.box(root, Vector3(w + 0.05, 0.06, d + 0.05), c + Vector3(0, yb - 0.03, 0), S.wall_d)
	M.box(root, Vector3(w + 0.05, 0.05, d + 0.05), c + Vector3(0, 0.12 + 0.05, 0), S.wall_d)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.09, wh, 0.09), c + Vector3(sx * w * 0.5, 0.12 + wh * 0.5, sz * d * 0.5), S.wall_d)
	var rl := w + 0.36
	var rw := d + 0.40
	B.roof_x(root, rl, rw, rise, yb, roof_m, c)
	M.cyl(root, 0.06, 0.06, rl + 0.04, c + Vector3(0, yb + rise + 0.01, 0), S.wall_d, 8).rotation_degrees.z = 90.0
	# hastial +x de tablones
	var holder := Node3D.new()
	holder.position = c + Vector3(rl * 0.5 + 0.01, yb - 0.01, 0.0)
	holder.rotation_degrees.y = 90.0
	root.add_child(holder)
	A.extrude(holder, PackedVector2Array([Vector2(-rw * 0.5 + 0.03, 0.0), Vector2(rw * 0.5 - 0.03, 0.0), Vector2(0.0, rise - 0.03)]), 0.03, Vector3.ZERO, S.wall)
	# las vigas del hastial
	for sg in [-1.0, 1.0]:
		var rafter := M.box(root, Vector3(0.05, sqrt(rw * rw * 0.25 + rise * rise) + 0.06, 0.05), c + Vector3(rl * 0.5 + 0.035, yb + rise * 0.5, sg * rw * 0.25), S.wall_d)
		rafter.rotation_degrees.x = -sg * rad_to_deg(atan2(rw * 0.5, rise))
	if horns:
		_horns(root, S, c + Vector3(rl * 0.5 + 0.05, yb + rise - 0.02, 0.0), true)
	return yb

func _louvre(root: Node3D, S: Dictionary, pos: Vector3) -> void:
	M.box(root, Vector3(0.22, 0.12, 0.22), pos + Vector3(0, 0.06, 0), S.wall_d)
	A.pyramid(root, 0.30, 0.14, 0.12, S.shingle, pos)
	A.smoke_src(root, pos + Vector3(0, 0.24, 0))

func _door(root: Node3D, S: Dictionary, pos: Vector3, w: float, h: float, face_x: bool = false) -> void:
	A.arch_hole(root, pos, w, h, face_x, S.red, S.wall_d, "flat", 0.05)
	M.box(root, Vector3(0.025, 0.025, 0.05) if not face_x else Vector3(0.05, 0.025, 0.025), pos + (Vector3(w * 0.30, h * 0.5, 0.06) if not face_x else Vector3(0.06, h * 0.5, -w * 0.30)), S.iron)

## Cabeza de dragón (mástil + cuello curvo + cabeza) que mira a +x (dir = 1) o a -x (dir = -1).
func _dragon(root: Node3D, S: Dictionary, pos: Vector3, dir: float, s: float = 1.0) -> void:
	var neck := M.box(root, Vector3(0.06, 0.34, 0.06) * s, pos + Vector3(0.05 * dir * s, 0.15 * s, 0), S.wall_d)
	neck.rotation_degrees.z = -dir * 28.0
	var hd := pos + Vector3(0.12 * dir * s, 0.34 * s, 0)
	M.ball(root, 0.06 * s, hd, S.wall_l, Vector3(1.4, 0.9, 0.9))
	M.box(root, Vector3(0.11, 0.035, 0.05) * s, hd + Vector3(0.07 * dir * s, -0.02 * s, 0), S.wall_l)
	M.cyl(root, 0.0, 0.025 * s, 0.09 * s, hd + Vector3(-0.02 * dir * s, 0.07 * s, 0.03 * s), S.wall_l, 5)
	M.cyl(root, 0.0, 0.025 * s, 0.09 * s, hd + Vector3(-0.02 * dir * s, 0.07 * s, -0.03 * s), S.wall_l, 5)

# ------------------------------------------------------------------ casa 2x2: casa larga pequeña

func casa(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(11)
	var c := Vector3(0.0, 0, -0.05)
	var w := 1.34
	var d := 1.10
	var yb := _long(root, S, c, w, d, 0.50, 0.56, S.turf)
	var zf := c.z + d * 0.5 + 0.005
	_door(root, S, Vector3(c.x - 0.30, 0.12, zf), 0.26, 0.40)
	_shields(root, S, Vector3(c.x + 0.05, 0.50, zf + 0.04), Vector3(0.20, 0, 0), 3, false, 0.075, _tm(team))
	_louvre(root, S, c + Vector3(-0.20, yb + 0.50, 0.0))
	M.box(root, Vector3(0.18, 0.18, 0.03), c + Vector3(w * 0.5 + 0.005, 0.50, 0.30), S.wall_d)
	B.banner(root, Vector3(w * 0.5 + 0.06, 0.72, c.z - 0.28), team, true, 0.16, 0.38)
	B.barrel(root, Vector3(0.82, 0.0, 0.58), S)
	B.crate(root, Vector3(-0.78, 0.0, 0.72), S, 0.22, -10.0)
	return root

# ------------------------------------------------------------------ almacén 2x2: stabbur sobre pilotes

func almacen(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(101)
	var w := 1.20
	var d := 1.20
	var lift := 0.34
	# pilotes de piedra con rompe-ratas (discos) y suelo
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.cyl(root, 0.09, 0.11, lift, Vector3(sx * 0.50, lift * 0.5, sz * 0.50), S.stone_d, 8)
			M.cyl(root, 0.15, 0.15, 0.04, Vector3(sx * 0.50, lift - 0.02, sz * 0.50), S.wall_d, 10)
	M.box(root, Vector3(w + 0.10, 0.07, d + 0.10), Vector3(0, lift + 0.035, 0), S.wall_d)
	var y0 := lift + 0.07
	M.box(root, Vector3(w, 0.72, d), Vector3(0, y0 + 0.36, 0), S.wall)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.09, 0.72, 0.09), Vector3(sx * w * 0.5, y0 + 0.36, sz * d * 0.5), S.wall_d)
	M.box(root, Vector3(w + 0.14, 0.06, d + 0.14), Vector3(0, y0 + 0.72, 0), S.wall_d)
	var yb := y0 + 0.75
	B.roof_x(root, w + 0.40, d + 0.40, 0.60, yb, S.turf)
	M.cyl(root, 0.06, 0.06, w + 0.44, Vector3(0, yb + 0.61, 0), S.wall_d, 8).rotation_degrees.z = 90.0
	var rw := d + 0.40
	var holder := Node3D.new()
	holder.position = Vector3((w + 0.40) * 0.5 + 0.01, yb - 0.01, 0.0)
	holder.rotation_degrees.y = 90.0
	root.add_child(holder)
	A.extrude(holder, PackedVector2Array([Vector2(-rw * 0.5 + 0.03, 0.0), Vector2(rw * 0.5 - 0.03, 0.0), Vector2(0.0, 0.57)]), 0.03, Vector3.ZERO, S.wall)
	_horns(root, S, Vector3((w + 0.40) * 0.5 + 0.05, yb + 0.58, 0.0), true, 0.8)
	# puerta alta con escalera
	_door(root, S, Vector3(-0.15, y0 + 0.04, d * 0.5 + 0.005), 0.30, 0.50)
	for k in 4:
		M.box(root, Vector3(0.30, 0.04, 0.10), Vector3(-0.15, 0.06 + k * 0.095, d * 0.5 + 0.18 - k * 0.04), S.wall_l)
	M.box(root, Vector3(0.05, 0.40, 0.05), Vector3(-0.32, 0.20, d * 0.5 + 0.12), S.wall_d)
	M.box(root, Vector3(0.05, 0.40, 0.05), Vector3(0.02, 0.20, d * 0.5 + 0.12), S.wall_d)
	_shields(root, S, Vector3(0.18, y0 + 0.50, d * 0.5 + 0.04), Vector3(0.17, 0, 0), 3, false, 0.06, _tm(team))
	B.sack(root, Vector3(0.80, 0.0, 0.72), S)
	B.barrel(root, Vector3(0.88, 0.0, 0.46), S)
	B.crate(root, Vector3(-0.82, 0.0, 0.78), S, 0.22, 8.0)
	return root

# ------------------------------------------------------------------ cuartel 3x3: salón de guerreros con muro de escudos

func cuartel(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(201)
	var c := Vector3(-0.25, 0, -0.40)
	var w := 2.30
	var d := 1.40
	var yb := _long(root, S, c, w, d, 0.66, 0.74, S.turf)
	var zf := c.z + d * 0.5 + 0.005
	_door(root, S, Vector3(c.x - 0.55, 0.12, zf), 0.38, 0.50)
	# muro de escudos bajo el alero
	_shields(root, S, Vector3(c.x - 0.10, 0.64, zf + 0.04), Vector3(0.22, 0, 0), 5, false, 0.085, _tm(team))
	for k in 4:
		_shields(root, S, Vector3(c.x + w * 0.5 + 0.04 + 0.16, 0.64, c.z - 0.45 + k * 0.30), Vector3.ZERO, 1, true, 0.085, _tm(team))
	# portal con doble cuerno y poste de armas
	M.box(root, Vector3(0.07, 0.62, 0.07), Vector3(c.x - 0.82, 0.43, zf + 0.10), S.wall_d)
	M.box(root, Vector3(0.07, 0.62, 0.07), Vector3(c.x - 0.28, 0.43, zf + 0.10), S.wall_d)
	M.box(root, Vector3(0.64, 0.06, 0.09), Vector3(c.x - 0.55, 0.76, zf + 0.10), S.wall_d)
	_horns(root, S, Vector3(c.x - 0.55, 0.78, zf + 0.10), false, 0.55)
	_louvre(root, S, c + Vector3(-0.50, yb + 0.72, 0.0))
	_louvre(root, S, c + Vector3(0.40, yb + 0.72, 0.0))
	B.banner(root, Vector3(c.x + 0.68, 0.98, zf + 0.04), team, false, 0.18, 0.44)
	A.drill_yard(root, S, 1.10, 1.40)
	return root

# ------------------------------------------------------------------ arquería 3x3: cobertizo de arqueros con dianas

func arqueria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(301)
	var c := Vector3(-0.45, 0, -0.45)
	var w := 1.90
	var d := 1.30
	var yb := _long(root, S, c, w, d, 0.60, 0.62, S.shingle)
	var zf := c.z + d * 0.5 + 0.005
	# fachada abierta con postes (cobertizo de tiro) y tablón de dianas
	_door(root, S, Vector3(c.x + 0.55, 0.12, zf), 0.30, 0.44)
	for k in 3:
		M.box(root, Vector3(0.24, 0.30, 0.04), Vector3(c.x - 0.70 + k * 0.34, 0.40, zf + 0.02), S.wall_d)
		A.shield(root, Vector3(c.x - 0.70 + k * 0.34, 0.40, zf + 0.06), 0.09, false, S.iron, [_tm(team), S.cloth_w, _tm(team)][k] as Material)
	_louvre(root, S, c + Vector3(0.0, yb + 0.56, 0.0))
	A.archery_field(root, S, _tm(team))
	# aljaba con flechas y arcos largos apoyados
	for k in 4:
		var bw := M.box(root, Vector3(0.025, 0.70, 0.025), Vector3(c.x + 0.10 + k * 0.08, 0.35, zf + 0.22), S.wall_l)
		bw.rotation_degrees.x = -10.0
	B.banner(root, Vector3(c.x + 0.90, 0.78, zf + 0.04), team, false, 0.16, 0.38)
	return root

# ------------------------------------------------------------------ establo 3x3: cuadra larga de turba

func establo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(401)
	var c := Vector3(-0.15, 0, -0.40)
	var w := 2.10
	var d := 1.30
	var yb := _long(root, S, c, w, d, 0.60, 0.70, S.turf)
	var zf := c.z + d * 0.5 + 0.005
	for sx in [-0.55, 0.30]:
		A.arch_hole(root, Vector3(c.x + sx, 0.12, zf), 0.46, 0.46, false, S.dark, S.wall_d, "flat", 0.06)
		M.box(root, Vector3(0.025, 0.40, 0.03), Vector3(c.x + sx, 0.32, zf + 0.04), S.wall_d)
		M.box(root, Vector3(0.46, 0.04, 0.04), Vector3(c.x + sx, 0.42, zf + 0.04), S.wall_d)
	M.box(root, Vector3(0.34, 0.26, 0.04), Vector3(c.x + 0.90, 0.46, zf), S.wall_d)
	A.shield(root, Vector3(c.x + 0.90, 0.46, zf + 0.04), 0.10, false, S.iron, _tm(team))
	_louvre(root, S, c + Vector3(0.0, yb + 0.66, 0.0))
	# cabeza de caballo tallada sobre el hastial
	_dragon(root, S, Vector3(c.x + w * 0.5 + 0.25, yb + 0.70, 0.0), 1.0, 0.7)
	A.corral(root, S)
	B.banner(root, Vector3(c.x + 0.62, 0.84, zf + 0.04), team, false, 0.16, 0.38)
	return root

# ------------------------------------------------------------------ taller de asedio 3x3: astillero con casco en construcción

func taller(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(501)
	var c := Vector3(-0.35, 0, -0.45)
	var w := 1.70
	var d := 1.30
	var yb := _long(root, S, c, w, d, 0.62, 0.66, S.shingle)
	var zf := c.z + d * 0.5 + 0.005
	A.arch_hole(root, Vector3(c.x - 0.25, 0.12, zf), 0.80, 0.46, false, S.dark, S.wall_d, "flat", 0.07)
	for y in [0.30, 0.52]:
		M.box(root, Vector3(0.80, 0.04, 0.05), Vector3(c.x - 0.25, y, zf + 0.04), S.wall_d)
	_louvre(root, S, c + Vector3(0.20, yb + 0.62, 0.0))
	# casco de un drakkar en grada: quilla y cuadernas
	var kc := Vector3(0.55, 0, 1.12)
	M.box(root, Vector3(1.40, 0.06, 0.07), kc + Vector3(0, 0.16, 0), S.wall_l)
	for k in 6:
		var rx := -0.58 + k * 0.232
		var ribh := 0.22 - absf(rx) * 0.12
		for sg in [-1.0, 1.0]:
			var r := M.box(root, Vector3(0.045, 0.34, 0.045), kc + Vector3(rx, 0.30, sg * 0.11 * (1.0 - absf(rx) * 0.4)), S.wall_l)
			r.rotation_degrees.x = sg * -24.0
		M.box(root, Vector3(0.05, 0.05, 0.30), kc + Vector3(rx, 0.12 + ribh * 0.2, 0), S.wall_l)
	_dragon(root, S, kc + Vector3(0.68, 0.18, 0), 1.0, 1.0)
	for sx in [-0.50, 0.30]:
		for sg in [-1.0, 1.0]:
			M.box(root, Vector3(0.05, 0.36, 0.05), kc + Vector3(sx, 0.18, sg * 0.30), S.wall_d)
		M.box(root, Vector3(0.05, 0.05, 0.66), kc + Vector3(sx, 0.34, 0), S.wall_d)
	A.siege_yard(root, S)
	B.banner(root, Vector3(c.x + 0.45, 0.82, zf + 0.04), team, false, 0.16, 0.38)
	return root

# ------------------------------------------------------------------ puerto 3x3: drakkar amarrado y cobertizo de barcos

## Casco de drakkar tendido a lo largo de x, con proa y popa en dragón, escudos en la borda y vela a rayas.
func _longship(root: Node3D, S: Dictionary, pos: Vector3, team: Color, sail: bool = true) -> void:
	var L := 0.98
	var b := 0.26
	var pts := PackedVector2Array([Vector2(L, 0.0), Vector2(L * 0.78, b * 0.62), Vector2(L * 0.40, b * 0.94), Vector2(0.0, b), Vector2(-L * 0.40, b * 0.94), Vector2(-L * 0.78, b * 0.62), Vector2(-L, 0.0),
		Vector2(-L * 0.78, -b * 0.62), Vector2(-L * 0.40, -b * 0.94), Vector2(0.0, -b), Vector2(L * 0.40, -b * 0.94), Vector2(L * 0.78, -b * 0.62)])
	var hull := Node3D.new()
	hull.position = pos + Vector3(0, 0.15, 0)
	hull.rotation_degrees.x = 90.0
	root.add_child(hull)
	A.extrude(hull, pts, 0.14, Vector3.ZERO, S.wall_d)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.84)
	var hull2 := Node3D.new()
	hull2.position = pos + Vector3(0, 0.235, 0)
	hull2.rotation_degrees.x = 90.0
	root.add_child(hull2)
	A.extrude(hull2, pts, 0.07, Vector3.ZERO, S.wall)
	var deck := Node3D.new()
	deck.position = pos + Vector3(0, 0.27, 0)
	deck.rotation_degrees.x = 90.0
	root.add_child(deck)
	A.extrude(deck, inner, 0.02, Vector3.ZERO, S.wall_l)
	# roda y codaste: dragón a proa, cola a popa
	_dragon(root, S, pos + Vector3(L - 0.02, 0.24, 0.0), 1.0, 1.1)
	var tail := M.box(root, Vector3(0.05, 0.34, 0.05), pos + Vector3(-L + 0.06, 0.40, 0.0), S.wall_d)
	tail.rotation_degrees.z = 22.0
	M.ball(root, 0.04, pos + Vector3(-L + 0.0, 0.58, 0.0), S.wall_l)
	# borda con escudos en ambos lados
	for sg in [-1.0, 1.0]:
		for k in 6:
			var sx := -0.62 + k * 0.25
			var field: Material = _tm(team) if k % 2 == 0 else S.cloth_y
			var hz: float = sg * (b * (0.94 - absf(sx) * 0.30) + 0.015)
			A.shield(root, pos + Vector3(sx, 0.30, hz), 0.075, false, S.iron, field)
	if sail:
		M.cyl(root, 0.025, 0.03, 0.95, pos + Vector3(0.05, 0.62, 0.0), S.wall_d, 8)
		M.box(root, Vector3(0.92, 0.04, 0.04), pos + Vector3(0.05, 1.02, 0.0), S.wall_d)
		for k in 5:
			var f: Material = _tm(team) if k % 2 == 0 else S.cloth_w
			M.box(root, Vector3(0.18, 0.62, 0.02), pos + Vector3(0.05 - 0.368 + k * 0.184, 0.69, 0.02), f)

func puerto(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(601)
	var c := Vector3(-0.30, 0, -0.55)
	var w := 1.50
	var d := 1.10
	var yb := _long(root, S, c, w, d, 0.56, 0.60, S.turf)
	var zf := c.z + d * 0.5 + 0.005
	A.arch_hole(root, Vector3(c.x - 0.15, 0.12, zf), 0.70, 0.40, false, S.dark, S.wall_d, "flat", 0.06)
	M.box(root, Vector3(0.025, 0.40, 0.05), Vector3(c.x - 0.15, 0.32, zf + 0.04), S.wall_d)
	_shields(root, S, Vector3(c.x + 0.42, 0.50, zf + 0.04), Vector3(0.18, 0, 0), 3, false, 0.07, _tm(team))
	_louvre(root, S, c + Vector3(0.0, yb + 0.56, 0.0))
	# embarcadero y drakkar amarrado
	A.pier(root, S)
	_longship(root, S, Vector3(0.05, 0.0, 1.62), team)
	B.banner(root, Vector3(c.x + 0.62, 0.78, zf + 0.04), team, false, 0.16, 0.38)
	return root

# ------------------------------------------------------------------ torre 2x2: atalaya de duelas

## Torre escalonada de madera: base de piedra, dos cuerpos que se estrechan y tejadillos con voladizo y cabeza de dragón.
func _stave_tower(root: Node3D, S: Dictionary, c: Vector3, w: float, team: Color, tiers: int = 2) -> float:
	M.box(root, Vector3(w + 0.14, 0.26, w + 0.14), c + Vector3(0, 0.13, 0), S.stone_d)
	var y := 0.26
	var cw := w
	for t in tiers:
		var th := 0.62 if t == 0 else 0.50
		M.box(root, Vector3(cw, th, cw), c + Vector3(0, y + th * 0.5, 0), S.wall)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				M.box(root, Vector3(0.08, th, 0.08), c + Vector3(sx * cw * 0.5, y + th * 0.5, sz * cw * 0.5), S.wall_d)
		A.arch_hole(root, c + Vector3(0, y + 0.18, cw * 0.5 + 0.005), 0.12, 0.16, false, S.dark, S.wall_d, "round", 0.03)
		A.arch_hole(root, c + Vector3(cw * 0.5 + 0.005, y + 0.18, 0), 0.12, 0.16, true, S.dark, S.wall_d, "round", 0.03)
		y += th
		# tejadillo escalonado con voladizo
		A.pyramid(root, cw + 0.38, 0.22 if t < tiers - 1 else 0.60, y, S.shingle, c)
		if t < tiers - 1:
			y += 0.12
			cw *= 0.78
	var yt := y + 0.60
	# cabezas de dragón en las cuatro esquinas del primer tejado y remate
	_dragon(root, S, c + Vector3(w * 0.5 + 0.12, 0.26 + 0.62 + 0.10, 0.0), 1.0, 0.7)
	_dragon(root, S, c + Vector3(-w * 0.5 - 0.12, 0.26 + 0.62 + 0.10, 0.0), -1.0, 0.7)
	M.cyl(root, 0.012, 0.02, 0.30, c + Vector3(0, yt + 0.12, 0), S.wall_d, 6)
	return yt + 0.27

func torre(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(210)
	var w := 1.00
	var top := _stave_tower(root, S, Vector3.ZERO, w, team, 2)
	A.arch_hole(root, Vector3(0.0, 0.26, w * 0.5 + 0.005), 0.26, 0.34, false, S.red, S.wall_d, "flat", 0.05)
	_shields(root, S, Vector3(-0.18, 0.80, w * 0.5 + 0.04), Vector3(0.18, 0, 0), 3, false, 0.075, _tm(team))
	_shields(root, S, Vector3(w * 0.5 + 0.04, 0.80, -0.18), Vector3(0, 0, 0.18), 3, true, 0.075, _tm(team))
	M._flag(root, Vector3(0.0, top - 0.02, 0.0), team, 0.62)
	return root

# ------------------------------------------------------------------ monasterio 3x3: iglesia de duelas (stavkirke)

func monasterio(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(701)
	# base de piedra y galería perimetral (svalgang) de tablones bajos con tejadillo
	M.box(root, Vector3(2.30, 0.16, 2.30), Vector3(0, 0.08, 0), S.stone_d)
	M.box(root, Vector3(2.10, 0.40, 2.10), Vector3(0, 0.36, 0), S.wall_d)
	M.box(root, Vector3(2.24, 0.06, 2.24), Vector3(0, 0.59, 0), S.wall_d)
	A.pyramid(root, 2.48, 0.46, 0.59, S.shingle_l, Vector3.ZERO)
	# naves: cuerpo central (cuatro esquinas altas) y tres tejados escalonados que suben
	var y := 0.60
	var w := 1.30
	M.box(root, Vector3(w, 0.42, w), Vector3(0, y + 0.21 + 0.34, 0), S.wall)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.09, 0.76, 0.09), Vector3(sx * w * 0.5, y + 0.38, sz * w * 0.5), S.wall_d)
	y += 0.76
	A.pyramid(root, w + 0.46, 0.42, y, S.shingle, Vector3.ZERO)
	y += 0.30
	var w2 := 0.86
	M.box(root, Vector3(w2, 0.46, w2), Vector3(0, y + 0.23, 0), S.wall)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.box(root, Vector3(0.07, 0.46, 0.07), Vector3(sx * w2 * 0.5, y + 0.23, sz * w2 * 0.5), S.wall_d)
	y += 0.46
	A.pyramid(root, w2 + 0.36, 0.40, y, S.shingle, Vector3.ZERO)
	y += 0.24
	var w3 := 0.52
	M.box(root, Vector3(w3, 0.48, w3), Vector3(0, y + 0.24, 0), S.wall)
	y += 0.48
	A.pyramid(root, w3 + 0.24, 0.62, y, S.shingle_l, Vector3.ZERO)
	M.cyl(root, 0.012, 0.02, 0.40, Vector3(0, y + 0.62 + 0.15, 0), S.wall_d, 6)
	M._flag(root, Vector3(0.0, y + 0.62 + 0.30, 0.0), team, 0.50)
	# ventanas rojas apuntadas en el cuerpo central y portal con cuernos
	A.arch_hole(root, Vector3(0.0, 0.78, w * 0.5 + 0.005), 0.12, 0.22, false, S.glass, S.wall_d, "round", 0.03)
	A.arch_hole(root, Vector3(w * 0.5 + 0.005, 0.78, 0.0), 0.12, 0.22, true, S.glass, S.wall_d, "round", 0.03)
	A.arch_hole(root, Vector3(0.0, 0.16, 1.055), 0.34, 0.40, false, S.red, S.wall_d, "round", 0.05)
	M.box(root, Vector3(0.62, 0.40, 0.46), Vector3(0.0, 0.52, 1.28), S.wall)
	B.roof_z(root, 0.50, 0.70, 0.30, 0.72, S.shingle, Vector3(0.0, 0, 1.28))
	_horns(root, S, Vector3(0.0, 1.00, 1.52), false, 0.7)
	A.arch_hole(root, Vector3(0.0, 0.30, 1.515), 0.26, 0.34, false, S.red, S.wall_d, "round", 0.04)
	# cabezas de dragón en las esquinas del tejado inferior
	_dragon(root, S, Vector3(1.20, 0.76, 0.0), 1.0, 0.7)
	_dragon(root, S, Vector3(-1.20, 0.76, 0.0), -1.0, 0.7)
	_shields(root, S, Vector3(-0.40, 0.45, 1.065), Vector3(0.80, 0, 0), 2, false, 0.07, _tm(team))
	return root

# ------------------------------------------------------------------ castillo 4x4: fuerte de empalizada con gran salón

## Tronco aguzado.
func _log(root: Node3D, S: Dictionary, p: Vector3, h: float, r: float = 0.075) -> void:
	M.cyl(root, r, r * 1.05, h, p + Vector3(0, h * 0.5, 0), S.wall_l, 6)
	A.cone(root, r * 1.05, 0.20, h, S.wall_l, p, 6)

## Hilera de troncos de a a b (en el plano xz), con travesaño.
func _palisade(root: Node3D, S: Dictionary, a: Vector3, b: Vector3, h: float, step: float = 0.15) -> void:
	var len := a.distance_to(b)
	var n := maxi(1, int(round(len / step)))
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		_log(root, S, p, h + 0.07 * float((i * 7) % 3), 0.07)
	var rail := M.box(root, Vector3(len, 0.06, 0.05), a.lerp(b, 0.5) + Vector3(0, h * 0.48, 0.07), S.wall_d)
	rail.rotation.y = atan2(-(b.z - a.z), b.x - a.x)

func castillo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(110)
	M.box(root, Vector3(3.5, 0.06, 3.5), Vector3(0, 0.03, 0), A.mat("plaster", 119, Color(0.52, 0.45, 0.30), 1.2))
	var ph := 1.05
	var e := 1.62
	_palisade(root, S, Vector3(-e, 0, -e), Vector3(e, 0, -e), ph)
	_palisade(root, S, Vector3(-e, 0, -e), Vector3(-e, 0, e), ph)
	_palisade(root, S, Vector3(e, 0, -e), Vector3(e, 0, e), ph)
	_palisade(root, S, Vector3(-e, 0, e), Vector3(-0.55, 0, e), ph)
	_palisade(root, S, Vector3(0.55, 0, e), Vector3(e, 0, e), ph)
	# puerta: dos postes altos con travesaño y dragones
	for sx in [-1, 1]:
		M.cyl(root, 0.10, 0.12, 1.50, Vector3(sx * 0.55, 0.75, e), S.wall_d, 8)
		_dragon(root, S, Vector3(sx * 0.55, 1.46, e), float(sx), 0.9)
	M.box(root, Vector3(1.20, 0.10, 0.12), Vector3(0, 1.10, e), S.wall_d)
	M.box(root, Vector3(1.00, 0.05, 0.10), Vector3(0, 0.88, e), S.wall_d)
	A.shield(root, Vector3(0.0, 0.99, e + 0.08), 0.12, false, S.iron, _tm(team))
	for sx in [-1, 1]:
		var leaf := M.box(root, Vector3(0.28, 0.80, 0.05), Vector3(sx * 0.28, 0.40, e + 0.02), S.red)
		leaf.rotation_degrees.y = float(sx) * -55.0
	# cuatro atalayas de esquina
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_stave_tower(root, S, Vector3(sx * e, 0, sz * e), 0.62, team, 2)
	# gran salón: casa larga con techo de turba y doble cuerno
	var c := Vector3(-0.05, 0, -0.25)
	var yb := _long(root, S, c, 2.10, 1.40, 0.80, 0.90, S.turf, true)
	var zf := c.z + 0.70 + 0.005
	A.arch_hole(root, Vector3(c.x - 0.30, 0.12, zf), 0.46, 0.58, false, S.red, S.wall_d, "flat", 0.06)
	_horns(root, S, Vector3(c.x - 0.30, 0.74, zf + 0.04), false, 0.6)
	_shields(root, S, Vector3(c.x + 0.20, 0.72, zf + 0.04), Vector3(0.20, 0, 0), 4, false, 0.085, _tm(team))
	_louvre(root, S, c + Vector3(-0.35, yb + 0.90, 0.0))
	_louvre(root, S, c + Vector3(0.45, yb + 0.90, 0.0))
	_dragon(root, S, Vector3(c.x + 1.05 + 0.18, yb + 0.88, 0.0), 1.0, 0.9)
	M._flag(root, Vector3(c.x + 0.0, yb + 0.90, 0.0), team, 0.90)
	B.banner(root, Vector3(c.x + 1.00, 0.95, c.z - 0.40), team, true, 0.20, 0.50)
	return root

# ------------------------------------------------------------------ herrería 3x3: fragua de turba

func herreria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(801)
	var c := Vector3(-0.20, 0, -0.40)
	var w := 1.80
	var d := 1.30
	var yb := _long(root, S, c, w, d, 0.60, 0.62, S.turf)
	var zf := c.z + d * 0.5 + 0.005
	# fragua de piedra con chimenea exenta
	M.box(root, Vector3(0.62, 1.30, 0.62), c + Vector3(w * 0.5 + 0.22, 0.65, -0.10), S.stone)
	M.box(root, Vector3(0.70, 0.07, 0.70), c + Vector3(w * 0.5 + 0.22, 1.30, -0.10), S.stone_d)
	M.cyl(root, 0.10, 0.12, 0.30, c + Vector3(w * 0.5 + 0.22, 1.47, -0.10), S.stone, 8)
	A.smoke_src(root, c + Vector3(w * 0.5 + 0.22, 1.70, -0.10))
	M.box(root, Vector3(0.10, 0.28, 0.34), c + Vector3(w * 0.5 + 0.55, 0.34, -0.10), S.dark)
	M.box(root, Vector3(0.12, 0.22, 0.26), c + Vector3(w * 0.5 + 0.56, 0.34, -0.10), S.fire)
	A.arch_hole(root, Vector3(c.x - 0.30, 0.12, zf), 0.72, 0.46, false, S.dark, S.wall_d, "flat", 0.06)
	M.box(root, Vector3(0.20, 0.20, 0.03), Vector3(c.x - 0.50, 0.28, zf + 0.04), S.fire)
	# hachas colgadas
	for k in 3:
		M.box(root, Vector3(0.03, 0.30, 0.03), Vector3(c.x + 0.40 + k * 0.17, 0.46, zf + 0.04), S.wall_d)
		M.box(root, Vector3(0.12, 0.08, 0.03), Vector3(c.x + 0.44 + k * 0.17, 0.58, zf + 0.04), S.steel)
	A.forge_yard(root, S)
	B.banner(root, Vector3(c.x + 0.80, 0.78, zf + 0.04), team, false, 0.16, 0.38)
	return root

# ------------------------------------------------------------------ mercado 3x3: puesto de comercio con piedra rúnica

func mercado(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(901)
	var tm := _tm(team)
	M.box(root, Vector3(2.70, 0.08, 2.70), Vector3(0, 0.04, 0), S.wall_l)
	M.box(root, Vector3(2.50, 0.04, 2.50), Vector3(0, 0.10, 0), S.wall)
	# lonja abierta: postes tallados y techo de turba sobre las mercancías
	for px in [-1.00, 0.0, 1.00]:
		for pz in [-1.25, -0.30]:
			M.cyl(root, 0.07, 0.08, 0.90, Vector3(px, 0.55, pz), S.wall_d, 8)
	M.box(root, Vector3(2.30, 0.10, 1.20), Vector3(0, 1.04, -0.78), S.wall_d)
	B.roof_x(root, 2.60, 1.46, 0.50, 1.08, S.turf, Vector3(0, 0, -0.78))
	M.cyl(root, 0.06, 0.06, 2.64, Vector3(0, 1.59, -0.78), S.wall_d, 8).rotation_degrees.z = 90.0
	for sx in [-1, 1]:
		_horns(root, S, Vector3(sx * 1.32, 1.06 + 0.46, -0.78), true, 0.55)
	for tx in [-0.80, 0.0, 0.80]:
		M.box(root, Vector3(0.62, 0.26, 0.34), Vector3(tx, 0.26, -0.78), S.wall_l)
		for k in 3:
			M.ball(root, 0.06, Vector3(tx - 0.16 + k * 0.16, 0.44, -0.78), [S.red_fruit, S.cloth_y, S.cloth_w][k] as Material, Vector3(1, 0.9, 1))
	_shields(root, S, Vector3(-0.85, 0.96, -0.20), Vector3(0.85, 0, 0), 3, false, 0.09, tm)
	# piedra rúnica
	var rs := M.box(root, Vector3(0.22, 0.74, 0.12), Vector3(0.0, 0.47, 0.70), S.stone_l)
	rs.rotation_degrees.z = 3.0
	M.box(root, Vector3(0.28, 0.08, 0.18), Vector3(0.0, 0.14, 0.70), S.stone)
	for k in 4:
		M.box(root, Vector3(0.10, 0.025, 0.02), Vector3(0.0, 0.34 + k * 0.14, 0.77), S.red)
	B.puesto(root, Vector3(-0.95, 0.10, 0.80), 90.0, tm, [S.red_fruit, S.green_fruit, S.red_fruit, S.orange_fruit], S)
	B.puesto(root, Vector3(0.95, 0.10, 0.85), -90.0, S.cloth_y, [S.orange_fruit, S.orange_fruit, S.green_fruit, S.red_fruit], S)
	M._flag(root, Vector3(-0.30, 0.10, 1.25), team, 1.30)
	B.barrel(root, Vector3(-1.10, 0.10, 0.20), S)
	B.crate(root, Vector3(1.10, 0.10, 0.20), S, 0.26, 10.0)
	return root

# ------------------------------------------------------------------ centro urbano 3x3: gran salón del jarl

func centro(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(21)
	var c := Vector3(-0.15, 0, -0.30)
	var w := 2.20
	var d := 1.60
	var yb := _long(root, S, c, w, d, 0.82, 0.92, S.turf)
	var zf := c.z + d * 0.5 + 0.005
	# porche con frontón: segundo hastial con cuernos delante de la puerta
	var px := c.x - 0.40
	M.box(root, Vector3(0.80, 0.70, 0.40), Vector3(px, 0.47, zf + 0.20), S.wall)
	for sx in [-1, 1]:
		M.box(root, Vector3(0.09, 0.80, 0.09), Vector3(px + sx * 0.40, 0.52, zf + 0.42), S.wall_d)
	B.roof_z(root, 0.64, 0.98, 0.46, 0.82, S.turf, Vector3(px, 0, zf + 0.22))
	var gh := Node3D.new()
	gh.position = Vector3(px, 0.81, zf + 0.54)
	root.add_child(gh)
	A.extrude(gh, PackedVector2Array([Vector2(-0.46, 0.0), Vector2(0.46, 0.0), Vector2(0.0, 0.42)]), 0.03, Vector3.ZERO, S.wall)
	_horns(root, S, Vector3(px, 1.24, zf + 0.55), false, 0.7)
	A.arch_hole(root, Vector3(px, 0.12, zf + 0.425), 0.40, 0.56, false, S.red, S.wall_d, "flat", 0.06)
	_shields(root, S, Vector3(c.x + 0.28, 0.80, zf + 0.04), Vector3(0.22, 0, 0), 4, false, 0.09, _tm(team))
	_shields(root, S, Vector3(c.x + w * 0.5 + 0.20, 0.82, c.z - 0.40), Vector3(0, 0, 0.27), 4, true, 0.09, _tm(team))
	_louvre(root, S, c + Vector3(-0.45, yb + 0.92, 0.0))
	_louvre(root, S, c + Vector3(0.50, yb + 0.92, 0.0))
	_dragon(root, S, Vector3(c.x + 1.18 + 0.20, yb + 0.90, 0.0), 1.0, 1.0)
	# atalaya de duelas en la parte trasera con bandera
	var top := _stave_tower(root, S, Vector3(0.62, 0, -1.10), 0.58, team, 2)
	M._flag(root, Vector3(0.62, top, -1.10), team, 0.60)
	B.banner(root, Vector3(c.x + 1.10, 0.20 + 0.72, zf + 0.04), team, false, 0.20, 0.50)
	B.barrel(root, Vector3(0.95, 0.0, 0.88), S)
	B.crate(root, Vector3(1.10, 0.0, 0.62), S, 0.24, 14.0)
	return root

# ------------------------------------------------------------------ murallas: empalizada de troncos

func _post_cluster(root: Node3D, S: Dictionary, h: float) -> void:
	for k in 7:
		var a := TAU * float(k) / 6.0
		var p := Vector3(cos(a) * 0.17, 0.0, sin(a) * 0.17) if k < 6 else Vector3.ZERO
		_log(root, S, p, h + 0.10 * float(k % 3), 0.085)
	M.cyl(root, 0.20, 0.20, 0.06, Vector3(0, h * 0.5, 0), S.wall_d, 12)

func wall_post() -> Node3D:
	var root := Node3D.new()
	var S := pal(250)
	_post_cluster(root, S, 1.00)
	var tm := M.fmat(M.TEAM_BASE, 0.7, 0.3)
	A.shield(root, Vector3(0.0, 0.62, 0.24), 0.11, false, S.iron, tm)
	A.shield(root, Vector3(0.24, 0.62, 0.0), 0.11, true, S.iron, tm)
	return root

func wall_arm(d: int) -> Node3D:
	var root := Node3D.new()
	var S := pal(250)
	var dir: Vector2 = M.DIRS8[d]
	var diag := dir.x != 0.0 and dir.y != 0.0
	var L := 0.7071 if diag else 0.5
	var body := Node3D.new()
	root.add_child(body)
	_palisade(body, S, Vector3(0.0, 0, 0.0), Vector3(L, 0, 0.0), 0.95, 0.14)
	_palisade(body, S, Vector3(0.07, 0, -0.10), Vector3(L - 0.07, 0, -0.10), 0.88, 0.14)
	body.rotation.y = atan2(-dir.y, dir.x)
	return root

func gate(along_x: bool) -> Node3D:
	var root := Node3D.new()
	var S := pal(260)
	var body := Node3D.new()
	root.add_child(body)
	for sx in [-1, 1]:
		M.cyl(body, 0.10, 0.12, 1.45, Vector3(sx * 0.38, 0.725, 0.0), S.wall_d, 8)
		_dragon(body, S, Vector3(sx * 0.38, 1.42, 0.0), float(sx), 0.85)
		_palisade(body, S, Vector3(sx * 0.50, 0, 0.0), Vector3(sx * 0.50 + sx * 0.12, 0, 0.0), 0.95, 0.12)
	M.box(body, Vector3(0.96, 0.10, 0.12), Vector3(0, 1.06, 0.0), S.wall_d)
	M.box(body, Vector3(0.80, 0.05, 0.10), Vector3(0, 0.86, 0.0), S.wall_d)
	for sx in [-1, 1]:
		M.box(body, Vector3(0.30, 0.72, 0.06), Vector3(sx * 0.17, 0.36, 0.0), S.red)
		M.box(body, Vector3(0.28, 0.04, 0.08), Vector3(sx * 0.17, 0.30, 0.0), S.iron)
		M.box(body, Vector3(0.28, 0.04, 0.08), Vector3(sx * 0.17, 0.56, 0.0), S.iron)
	A.shield(body, Vector3(0.0, 0.97, 0.09), 0.10, false, S.iron, M.fmat(M.TEAM_BASE, 0.7, 0.3))
	body.rotation_degrees.y = 0.0 if along_x else 90.0
	return root
