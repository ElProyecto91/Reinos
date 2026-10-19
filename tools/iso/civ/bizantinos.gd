extends RefCounted
## Bizantinos: mampostería a bandas (hiladas de sillar claro alternadas con triples hiladas de ladrillo rojo), arcos de medio
## punto, cúpulas de plomo y de teja sobre tambores con ventanas, iglesias de cruz inscrita con cinco cúpulas, ábsides
## semicirculares, columnas de mármol, cruces doradas, torres redondas con cúpula (Teodosio) y mercado con pórtico y fuente
## cubierta. Banderas y toldos llevan el color del jugador; nada de arcos apuntados ni cubiertas cónicas.

const A = preload("res://tools/iso/iso_arch.gd")
const M = preload("res://tools/iso/iso_models.gd")
const B = preload("res://tools/iso/iso_build.gd")

func build(type: String, team: Color) -> Node3D:
	return call(type, team) as Node3D

## Textura de bandas: 2 × (hilada de sillares + cuatro hiladas de ladrillo) en 128 px.
func _tex_banded(seed_v: int, stone: Color, brick: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var fine := M._noise_img(seed_v + 5, 0.22)
	var mortar := stone.lerp(Color(0.92, 0.90, 0.82), 0.55)
	img.fill(mortar)
	for band in 2:
		var y0 := band * 64
		# hilada de sillares: 28 px de alto, bloques de 32 px, junta a tresbolillo entre bandas
		var off := band * 16
		for k in 4:
			var tone := rng.randf_range(0.90, 1.10)
			for yy in range(y0 + 1, y0 + 27):
				for xx in range(k * 32 + 1, k * 32 + 31):
					var px := posmod(xx + off, n)
					var v := 1.0 + (fine.get_pixel(px, yy).r - 0.5) * 0.20
					var bev := 1.06 if yy == y0 + 1 else (0.88 if yy == y0 + 26 else 1.0)
					img.set_pixel(px, yy, M._mul(stone, tone * v * bev))
		# cuatro hiladas de ladrillo de 8 px
		for r in 4:
			var ry := y0 + 30 + r * 8
			var boff := 16 if r % 2 == 1 else 0
			for k in 4:
				var tone2 := rng.randf_range(0.84, 1.14)
				for yy in range(ry + 1, ry + 7):
					for xx in range(k * 32 + 1, k * 32 + 31):
						var px2 := posmod(xx + boff, n)
						var v2 := 1.0 + (fine.get_pixel(px2, yy).r - 0.5) * 0.22
						img.set_pixel(px2, yy, M._mul(brick, tone2 * v2))
	return M._to_tex(img)

func pal(seed_v: int) -> Dictionary:
	var S := A.plain()
	S["band"] = M.tmat(_tex_banded(seed_v + 1, Color(0.86, 0.80, 0.66), Color(0.62, 0.27, 0.18)), 0.95)
	S["band_d"] = M.tmat(_tex_banded(seed_v + 2, Color(0.70, 0.64, 0.52), Color(0.50, 0.21, 0.15)), 0.95)
	S["stone"] = A.mat("stone", seed_v + 3, Color(0.82, 0.77, 0.64), 1.1)
	S["stone_l"] = A.mat("stone", seed_v + 4, Color(0.93, 0.89, 0.78), 1.1)
	S["stone_d"] = A.mat("stone", seed_v + 5, Color(0.62, 0.56, 0.46), 1.1)
	S["marble"] = A.mat("marble", seed_v + 6, Color(0.94, 0.92, 0.88), 1.0)
	S["wood"] = A.mat("wood", seed_v + 7, Color(0.30, 0.20, 0.12), 1.4)
	S["wood_l"] = A.mat("wood", seed_v + 8, Color(0.52, 0.38, 0.22), 1.6)
	S["roof"] = A.mat("roof", seed_v + 9, Color(0.68, 0.34, 0.21), 1.5)
	S["roof_d"] = A.mat("roof", seed_v + 10, Color(0.54, 0.25, 0.16), 1.5)
	S["lead"] = A.mat("roof", seed_v + 11, Color(0.50, 0.54, 0.57), 1.8)
	S["plaster"] = A.mat("plaster", seed_v + 12, Color(0.90, 0.85, 0.72), 1.0)
	var F := A.fort(seed_v + 20, Color(0.86, 0.80, 0.66), Color(0.62, 0.56, 0.46), Color(0.93, 0.89, 0.78), Color(0.58, 0.24, 0.16), Color(0.30, 0.20, 0.12))
	F["wall"] = S.band
	F["dark"] = S.stone_d
	S["F"] = F
	return S

func _tm(team: Color) -> StandardMaterial3D:
	return M.fmat(team, 0.85, 0.2)

func _win(root: Node3D, S: Dictionary, pos: Vector3, w: float, h: float, face_x: bool) -> void:
	A.arch_hole(root, pos, w, h, face_x, S.glass, S.stone_l, "round", 0.04)

## Tambor con ventanas de medio punto y cúpula (de plomo o de teja) con cruz dorada. c.y = base del tambor.
func _dome(root: Node3D, S: Dictionary, c: Vector3, r: float, drum_h: float, dome_h: float, dome_m: Material, n: int = 8, cross: bool = true) -> float:
	M.cyl(root, r, r * 1.03, drum_h, c + Vector3(0, drum_h * 0.5, 0), S.band, 16)
	M.cyl(root, r * 1.08, r * 1.08, 0.05, c + Vector3(0, 0.025, 0), S.stone_l, 16)
	M.cyl(root, r * 1.08, r * 1.08, 0.05, c + Vector3(0, drum_h, 0), S.stone_l, 16)
	for k in n:
		var piv := Node3D.new()
		piv.position = c + Vector3(0, drum_h * 0.18, 0)
		piv.rotation.y = TAU * float(k) / float(n)
		root.add_child(piv)
		A.arch_hole(piv, Vector3(0, 0, r * 1.0 + 0.012), r * 0.30, drum_h * 0.36, false, S.glass, S.stone_l, "round", 0.03)
	A.lathe(root, A.dome_prof(r * 1.08, dome_h), 16, c + Vector3(0, drum_h + 0.025, 0), dome_m)
	var top := c.y + drum_h + 0.025 + dome_h
	if cross:
		A.cross_fin(root, Vector3(c.x, top - 0.01, c.z), 0.26, S.gold)
	return top

## Bloque de planta rectangular: zócalo, cuerpo a bandas y cornisa. Devuelve la y del alero.
func _block(root: Node3D, S: Dictionary, c: Vector3, w: float, d: float, h: float, m: Material = null) -> float:
	var mm: Material = m if m != null else S.band
	M.box(root, Vector3(w + 0.12, 0.14, d + 0.12), c + Vector3(0, 0.07, 0), S.stone_d)
	M.box(root, Vector3(w, h, d), c + Vector3(0, 0.14 + h * 0.5, 0), mm)
	M.box(root, Vector3(w + 0.10, 0.07, d + 0.10), c + Vector3(0, 0.14 + h + 0.035, 0), S.stone_l)
	return 0.14 + h + 0.07

## Pórtico de n arcos sobre columnas de mármol a lo largo de x (cara +z) con tejadillo plano, en o.
func _portico(root: Node3D, S: Dictionary, o: Vector3, n: int, span: float, h: float, depth: float = 0.30, roof: bool = true) -> void:
	A.arcade(root, o, true, n, span, h, S.marble, S.dark, "round")
	if roof:
		M.box(root, Vector3(span * float(n) + 0.18, 0.06, depth + 0.10), o + Vector3(0, h + 0.19, depth * 0.5 - 0.05), S.stone_l)

# ------------------------------------------------------------------ casa 2x2: casa de bandas con pórtico

func casa(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(11)
	var w := 1.36
	var d := 1.30
	var ye := _block(root, S, Vector3(0, 0, -0.05), w, d, 0.74)
	A.hip(root, w + 0.22, d + 0.22, 0.46, ye, S.roof, Vector3(0, 0, -0.05))
	M.box(root, Vector3(0.40, 0.05, 0.05), Vector3(0, ye + 0.46, -0.05), S.roof_d)
	var zf := -0.05 + d * 0.5 + 0.005
	A.arch_hole(root, Vector3(-0.28, 0.14, zf), 0.30, 0.34, false, S.wood, S.stone_l, "round", 0.05)
	_win(root, S, Vector3(0.30, 0.44, zf), 0.20, 0.22, false)
	_win(root, S, Vector3(w * 0.5 + 0.005, 0.46, -0.30), 0.20, 0.24, true)
	_win(root, S, Vector3(w * 0.5 + 0.005, 0.46, 0.20), 0.20, 0.24, true)
	# pórtico de dos columnas
	for sx in [-0.52, 0.0]:
		M.cyl(root, 0.045, 0.055, 0.60, Vector3(sx - 0.14, 0.44, zf + 0.20), S.marble, 10)
		M.cyl(root, 0.075, 0.075, 0.05, Vector3(sx - 0.14, 0.14 + 0.60, zf + 0.20), S.marble, 10)
	M.box(root, Vector3(0.74, 0.06, 0.30), Vector3(-0.40, 0.14 + 0.66, zf + 0.15), S.stone_l)
	B.banner(root, Vector3(0.50, 0.80, zf + 0.04), team, false, 0.16, 0.40)
	A.jar(root, Vector3(0.70, 0.0, 0.80), S.clay)
	A.jar(root, Vector3(0.88, 0.0, 0.66), S.clay, 0.09)
	M._flag(root, Vector3(-0.80, 0.0, 0.82), team, 0.85)
	return root

# ------------------------------------------------------------------ almacén 2x2: granero con bóveda y ánforas

func almacen(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(101)
	var w := 1.50
	var d := 1.30
	var ye := _block(root, S, Vector3.ZERO, w, d, 0.70)
	# techo de tejas en cuatro aguas bajo, con lucernario cupulado
	A.hip(root, w + 0.22, d + 0.22, 0.40, ye, S.roof)
	_dome(root, S, Vector3(0.0, ye + 0.30, 0.0), 0.20, 0.14, 0.18, S.lead, 6, false)
	var zf := d * 0.5 + 0.005
	A.arch_hole(root, Vector3(-0.20, 0.14, zf), 0.62, 0.34, false, S.dark, S.stone_l, "round", 0.06)
	for sx in [-1, 1]:
		M.box(root, Vector3(0.28, 0.44, 0.04), Vector3(-0.20 + sx * 0.18, 0.36, zf + 0.04), S.wood).rotation_degrees.y = float(sx) * 38.0
	_win(root, S, Vector3(0.45, 0.50, zf), 0.18, 0.18, false)
	_win(root, S, Vector3(w * 0.5 + 0.005, 0.50, 0.10), 0.18, 0.18, true)
	for k in 3:
		A.jar(root, Vector3(0.70 + k * 0.17, 0.0, 0.84 - (k % 2) * 0.14), S.clay, 0.10)
	A.jar(root, Vector3(-0.78, 0.0, 0.84), S.clay)
	B.sack(root, Vector3(-0.92, 0.0, 0.62), S)
	B.banner(root, Vector3(0.50, 0.86, zf + 0.04), team, false, 0.16, 0.40)
	return root

# ------------------------------------------------------------------ cuartel 3x3: acuartelamiento (tagma) con torres cupuladas

func cuartel(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(201)
	var F: Dictionary = S.F
	var c := Vector3(-0.30, 0, -0.35)
	var w := 2.10
	var d := 1.50
	var ye := _block(root, S, c, w, d, 0.94)
	A.hip(root, w + 0.20, d + 0.20, 0.46, ye, S.roof, c)
	var zf := c.z + d * 0.5 + 0.005
	# arcada de piedra a lo largo de la fachada
	A.arcade(root, Vector3(c.x, 0.14, zf + 0.12), true, 4, 0.50, 0.44, S.marble, S.dark, "round")
	for wx in [-0.60, 0.0, 0.60]:
		_win(root, S, Vector3(c.x + wx, 0.78, zf), 0.18, 0.22, false)
	for wz in [-0.50, 0.15]:
		_win(root, S, Vector3(c.x + w * 0.5 + 0.005, 0.60, c.z + wz), 0.20, 0.30, true)
	# dos torres redondas con cúpula en las esquinas delanteras
	for sx in [-1, 1]:
		var tc := Vector3(c.x + sx * 1.02, 0, c.z + 0.78)
		M.cyl(root, 0.34, 0.38, 1.35, tc + Vector3(0, 0.675, 0), S.band, 18)
		M.cyl(root, 0.42, 0.42, 0.07, tc + Vector3(0, 1.38, 0), S.stone_l, 18)
		A.lathe(root, A.dome_prof(0.42, 0.34), 16, tc + Vector3(0, 1.415, 0), S.lead)
		M._flag(root, tc + Vector3(0, 1.74, 0), team, 0.55)
		A.arch_hole(root, tc + Vector3(0, 0.80, 0.36), 0.12, 0.24, false, S.dark, S.stone_l, "round", 0.03)
	A.shield(root, Vector3(c.x, 0.88, zf + 0.04), 0.14, false, S.gold, _tm(team))
	B.banner(root, Vector3(c.x - 0.50, 0.86, zf + 0.30), team, false, 0.16, 0.46)
	B.banner(root, Vector3(c.x + 0.50, 0.86, zf + 0.30), team, false, 0.16, 0.46)
	A.drill_yard(root, S, 1.20, 1.46)
	return root

# ------------------------------------------------------------------ arquería 3x3: sala con galería de columnas

func arqueria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(301)
	var c := Vector3(-0.40, 0, -0.45)
	var w := 1.90
	var d := 1.30
	var ye := _block(root, S, c, w, d, 0.72)
	A.hip(root, w + 0.22, d + 0.22, 0.44, ye, S.roof, c)
	var zf := c.z + d * 0.5 + 0.005
	_portico(root, S, Vector3(c.x - 0.15, 0.14, zf + 0.12), 3, 0.50, 0.40)
	_win(root, S, Vector3(c.x + 0.62, 0.50, zf), 0.20, 0.24, false)
	for wz in [-0.30, 0.20]:
		_win(root, S, Vector3(c.x + w * 0.5 + 0.005, 0.50, c.z + wz), 0.20, 0.26, true)
	_dome(root, S, Vector3(c.x + 0.55, ye + 0.28, c.z - 0.30), 0.20, 0.12, 0.17, S.lead, 6, false)
	A.archery_field(root, S, _tm(team))
	B.banner(root, Vector3(c.x + 0.90, 0.74, zf + 0.04), team, false, 0.16, 0.38)
	return root

# ------------------------------------------------------------------ establo 3x3: caballeriza con caballo de bronce

func establo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(401)
	var c := Vector3(-0.15, 0, -0.40)
	var w := 2.10
	var d := 1.30
	var ye := _block(root, S, c, w, d, 0.70)
	A.hip(root, w + 0.22, d + 0.22, 0.42, ye, S.roof, c)
	var zf := c.z + d * 0.5 + 0.005
	for sx in [-0.55, 0.30]:
		A.arch_hole(root, Vector3(c.x + sx, 0.14, zf), 0.46, 0.34, false, S.dark, S.stone_l, "round", 0.06)
		M.box(root, Vector3(0.025, 0.46, 0.03), Vector3(c.x + sx, 0.36, zf + 0.04), S.wood)
	_win(root, S, Vector3(c.x + 0.85, 0.50, zf), 0.18, 0.20, false)
	# pilar con cabeza de caballo de bronce (hipódromo)
	M.cyl(root, 0.07, 0.09, 0.70, Vector3(1.05, 0.35, 0.95), S.marble, 10)
	M.box(root, Vector3(0.20, 0.06, 0.20), Vector3(1.05, 0.73, 0.95), S.stone_l)
	var bronze := M.fmat(Color(0.62, 0.42, 0.18), 0.4, 0.8)
	M.ball(root, 0.07, Vector3(1.05, 0.88, 0.95), bronze, Vector3(1.3, 0.9, 0.8))
	M.box(root, Vector3(0.05, 0.16, 0.05), Vector3(1.01, 0.94, 0.95), bronze).rotation_degrees.z = -25.0
	A.corral(root, S)
	B.banner(root, Vector3(c.x + 0.62, 0.80, zf + 0.04), team, false, 0.16, 0.38)
	return root

# ------------------------------------------------------------------ taller de asedio 3x3: arsenal de fuego griego

func taller(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(501)
	var c := Vector3(-0.30, 0, -0.40)
	var w := 1.80
	var d := 1.40
	var ye := _block(root, S, c, w, d, 0.84)
	A.hip(root, w + 0.22, d + 0.22, 0.42, ye, S.roof, c)
	var zf := c.z + d * 0.5 + 0.005
	A.arch_hole(root, Vector3(c.x - 0.30, 0.14, zf), 0.74, 0.42, false, S.dark, S.stone_l, "round", 0.06)
	for y in [0.32, 0.56]:
		M.box(root, Vector3(0.74, 0.04, 0.05), Vector3(c.x - 0.30, y, zf + 0.04), S.iron)
	_win(root, S, Vector3(c.x + 0.55, 0.56, zf), 0.20, 0.24, false)
	# horno cupulado con boca de fuego griego
	var kc := Vector3(c.x + w * 0.5 + 0.30, 0, c.z - 0.20)
	M.cyl(root, 0.32, 0.36, 0.50, kc + Vector3(0, 0.25, 0), S.band, 16)
	A.lathe(root, A.dome_prof(0.34, 0.26), 14, kc + Vector3(0, 0.50, 0), S.lead)
	A.arch_hole(root, kc + Vector3(0.0, 0.0, 0.36), 0.22, 0.20, false, S.dark, S.stone_l, "round", 0.04)
	M.box(root, Vector3(0.16, 0.14, 0.03), kc + Vector3(0.0, 0.14, 0.37), S.fire)
	# sifones de bronce y tinajas de la mezcla
	var bronze := M.fmat(Color(0.62, 0.42, 0.18), 0.4, 0.8)
	for k in 2:
		var sp := M.cyl(root, 0.035, 0.045, 0.70, Vector3(0.65 + k * 0.20, 0.34, 1.10), bronze, 8)
		sp.rotation_degrees.x = -58.0
	for k in 3:
		A.jar(root, Vector3(1.15, 0.0, 0.84 + k * 0.17), S.clay, 0.11)
	A.siege_yard(root, S)
	B.banner(root, Vector3(c.x + 0.62, 0.92, zf + 0.04), team, false, 0.16, 0.40)
	return root

# ------------------------------------------------------------------ puerto 3x3: almacén con arcos y faro (Faros)

func puerto(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(601)
	var c := Vector3(-0.30, 0, -0.55)
	var w := 1.60
	var d := 1.10
	var ye := _block(root, S, c, w, d, 0.68)
	A.hip(root, w + 0.22, d + 0.22, 0.40, ye, S.roof, c)
	var zf := c.z + d * 0.5 + 0.005
	A.arcade(root, Vector3(c.x, 0.14, zf + 0.12), true, 3, 0.50, 0.42, S.marble, S.dark, "round")
	_win(root, S, Vector3(c.x + 0.50, 0.60, zf), 0.16, 0.18, false)
	_dome(root, S, Vector3(c.x - 0.45, ye + 0.30, c.z), 0.18, 0.10, 0.16, S.lead, 6, false)
	A.pier(root, S)
	# faro: fuste a bandas, linterna abierta con fuego y cúpula
	var fc := Vector3(1.00, 0, -0.30)
	M.box(root, Vector3(0.60, 0.20, 0.60), fc + Vector3(0, 0.10, 0), S.stone_d)
	M.box(root, Vector3(0.46, 1.30, 0.46), fc + Vector3(0, 0.85, 0), S.band)
	M.box(root, Vector3(0.58, 0.07, 0.58), fc + Vector3(0, 1.52, 0), S.stone_l)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.cyl(root, 0.035, 0.035, 0.40, fc + Vector3(sx * 0.17, 1.75, sz * 0.17), S.marble, 8)
	M.box(root, Vector3(0.20, 0.30, 0.20), fc + Vector3(0, 1.70, 0), S.fire)
	A.lathe(root, A.dome_prof(0.30, 0.22), 14, fc + Vector3(0, 1.95, 0), S.lead)
	A.cross_fin(root, fc + Vector3(0, 2.16, 0), 0.22, S.gold)
	A.arch_hole(root, fc + Vector3(0, 0.20, 0.235), 0.16, 0.26, false, S.dark, S.stone_l, "round", 0.03)
	B.banner(root, Vector3(c.x + 0.62, 0.84, zf + 0.04), team, false, 0.16, 0.40)
	M._flag(root, Vector3(-1.10, 0.0, 1.25), team, 0.9)
	return root

# ------------------------------------------------------------------ torre 2x2: torre redonda de Teodosio con cúpula

func torre(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(210)
	var F: Dictionary = S.F
	M.cyl(root, 0.64, 0.72, 0.22, Vector3(0, 0.11, 0), S.stone_d, 22)
	M.cyl(root, 0.56, 0.62, 2.10, Vector3(0, 1.27, 0), S.band, 22)
	M.cyl(root, 0.68, 0.60, 0.12, Vector3(0, 2.38, 0), S.stone_l, 22)
	M.cyl(root, 0.68, 0.68, 0.14, Vector3(0, 2.50, 0), S.band, 22)
	M.cyl(root, 0.70, 0.70, 0.06, Vector3(0, 2.60, 0), S.stone_l, 22)
	A.lathe(root, A.dome_prof(0.64, 0.50), 18, Vector3(0, 2.63, 0), S.lead)
	A.cross_fin(root, Vector3(0, 3.12, 0), 0.30, S.gold)
	for yy in [1.0, 1.70]:
		for a in [PI * 0.25, PI * 0.75]:
			var piv := Node3D.new()
			piv.position = Vector3(0, yy, 0)
			piv.rotation.y = -a
			root.add_child(piv)
			A.arch_hole(piv, Vector3(0, 0, 0.60), 0.12, 0.26, false, S.dark, S.stone_l, "round", 0.03)
	A.arch_hole(root, Vector3(0.0, 0.20, 0.70), 0.30, 0.30, false, S.wood, S.stone_l, "round", 0.05)
	A.shield(root, Vector3(0.0, 1.34, 0.60), 0.14, false, S.gold, _tm(team))
	M._flag(root, Vector3(0.0, 3.30, 0.0), team, 0.55)
	return root

# ------------------------------------------------------------------ monasterio 3x3: iglesia de cruz inscrita con cinco cúpulas

func monasterio(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(701)
	var c := Vector3(-0.15, 0, -0.20)
	var w := 1.90
	var d := 1.90
	var ye := _block(root, S, c, w, d, 1.00)
	A.hip(root, w + 0.12, d + 0.12, 0.22, ye, S.roof, c)
	# ábside semicircular al fondo (−z) con cuarto de cúpula
	M.cyl(root, 0.62, 0.62, 0.84, c + Vector3(0, 0.56, -d * 0.5 - 0.02), S.band, 16)
	A.lathe(root, A.dome_prof(0.64, 0.32), 14, c + Vector3(0, 0.98, -d * 0.5 - 0.02), S.roof)
	# cúpula central sobre tambor alto, y cuatro cupulillas en las esquinas
	var top := _dome(root, S, c + Vector3(0.0, ye + 0.10, 0.0), 0.46, 0.46, 0.46, S.lead, 8, true)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_dome(root, S, c + Vector3(sx * 0.62, ye + 0.10, sz * 0.62), 0.20, 0.16, 0.20, S.roof, 6, true)
	# narthex con arcos y portal
	var zf := c.z + d * 0.5
	A.arcade(root, Vector3(c.x, 0.14, zf + 0.12), true, 4, 0.46, 0.50, S.marble, S.dark, "round")
	A.arch_hole(root, Vector3(c.x, 0.14, zf + 0.005), 0.34, 0.40, false, S.wood, S.stone_l, "round", 0.05)
	for sx in [-0.62, 0.62]:
		_win(root, S, Vector3(c.x + sx, 0.62, zf + 0.005), 0.18, 0.30, false)
	for wz in [-0.50, 0.10, 0.60]:
		_win(root, S, Vector3(c.x + w * 0.5 + 0.005, 0.62, c.z + wz), 0.20, 0.34, true)
	M._flag(root, Vector3(c.x + 0.62, ye + 0.10 + 0.16 + 0.20 + 0.26, c.z - 0.62), team, 0.50)
	B.banner(root, Vector3(c.x - 0.46, 0.86, zf + 0.30), team, false, 0.18, 0.50)
	B.banner(root, Vector3(c.x + 0.46, 0.86, zf + 0.30), team, false, 0.18, 0.50)
	# campanario exento a la izquierda
	M.box(root, Vector3(0.34, 1.60, 0.34), Vector3(-1.30, 0.94, 0.85), S.band)
	M.box(root, Vector3(0.44, 0.06, 0.44), Vector3(-1.30, 1.77, 0.85), S.stone_l)
	A.arch_hole(root, Vector3(-1.30, 1.30, 1.025), 0.14, 0.26, false, S.dark, S.stone_l, "round", 0.03)
	A.arch_hole(root, Vector3(-1.125, 1.30, 0.85), 0.14, 0.26, true, S.dark, S.stone_l, "round", 0.03)
	A.pyramid(root, 0.50, 0.30, 1.80, S.roof, Vector3(-1.30, 0, 0.85))
	A.cross_fin(root, Vector3(-1.30, 2.08, 0.85), 0.20, S.gold)
	return root

# ------------------------------------------------------------------ castillo 4x4: kastron con torres cupuladas

func _round_tower(root: Node3D, S: Dictionary, c: Vector3, r: float, h: float, team: Color, dome_m: Material) -> float:
	M.cyl(root, r * 1.12, r * 1.18, 0.20, c + Vector3(0, 0.10, 0), S.stone_d, 20)
	M.cyl(root, r, r * 1.06, h - 0.20, c + Vector3(0, 0.20 + (h - 0.20) * 0.5, 0), S.band, 20)
	M.cyl(root, r * 1.16, r * 1.04, 0.14, c + Vector3(0, h + 0.07, 0), S.stone_l, 20)
	M.cyl(root, r * 1.16, r * 1.16, 0.16, c + Vector3(0, h + 0.22, 0), S.band, 20)
	M.cyl(root, r * 1.22, r * 1.22, 0.05, c + Vector3(0, h + 0.33, 0), S.stone_l, 20)
	A.lathe(root, A.dome_prof(r * 1.18, r * 0.95), 16, c + Vector3(0, h + 0.355, 0), dome_m)
	for yy in [h * 0.38, h * 0.70]:
		for a in [PI * 0.25, PI * 0.75]:
			var piv := Node3D.new()
			piv.position = c + Vector3(0, yy, 0)
			piv.rotation.y = -a
			root.add_child(piv)
			A.arch_hole(piv, Vector3(0, 0, r * 1.02 + 0.005), 0.10, 0.22, false, S.dark, S.stone_l, "round", 0.025)
	var top := h + 0.355 + r * 0.95
	A.cross_fin(root, c + Vector3(0, top - 0.01, 0), 0.22, S.gold)
	return top

func castillo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(110)
	var F: Dictionary = S.F
	M.box(root, Vector3(3.5, 0.06, 3.5), Vector3(0, 0.03, 0), A.mat("plaster", 119, Color(0.62, 0.55, 0.40), 1.2))
	var wh := 1.20
	A.wall_block(root, F, 3.0, wh, 0.50, Vector3(0, 0, -1.55))
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(-1.55, 0, 0))
	A.wall_block(root, F, 0.50, wh, 3.0, Vector3(1.55, 0, 0))
	A.wall_block(root, F, 1.05, wh, 0.50, Vector3(-0.975, 0, 1.55))
	A.wall_block(root, F, 1.05, wh, 0.50, Vector3(0.975, 0, 1.55))
	# puerta de arco de medio punto con dos torres cupuladas menores
	M.box(root, Vector3(0.90, 0.36, 0.52), Vector3(0, wh - 0.18, 1.55), F.wall)
	M.box(root, Vector3(0.94, 0.05, 0.56), Vector3(0, wh + 0.025, 1.55), F.light)
	M.box(root, Vector3(0.90, 0.92, 0.30), Vector3(0, 0.46, 1.50), F.slit)
	A.arch_hole(root, Vector3(0, 0.0, 1.805), 0.58, 0.46, false, S.dark, S.stone_l, "round", 0.07)
	for k in 5:
		M.box(root, Vector3(0.025, 0.72, 0.03), Vector3(-0.20 + k * 0.10, 0.36, 1.83), S.iron)
	for sx in [-1, 1]:
		_round_tower(root, S, Vector3(sx * 0.68, 0, 1.76), 0.26, 1.35, team, S.roof)
	# cuatro torres redondas de esquina con cúpula
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_round_tower(root, S, Vector3(sx * 1.55, 0, sz * 1.55), 0.50, 1.95, team, S.lead)
	# iglesia-torre del Tagma: cuerpo cuadrado con gran cúpula central
	var kc := Vector3(0.0, 0, -0.30)
	M.box(root, Vector3(1.80, 0.20, 1.80), kc + Vector3(0, 0.10, 0), F.dark)
	M.box(root, Vector3(1.64, 1.60, 1.64), kc + Vector3(0, 1.0, 0), S.band)
	M.box(root, Vector3(1.78, 0.08, 1.78), kc + Vector3(0, 1.84, 0), S.stone_l)
	var top := _dome(root, S, kc + Vector3(0, 1.88, 0), 0.62, 0.50, 0.62, S.lead, 8, true)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_dome(root, S, kc + Vector3(sx * 0.62, 1.88, sz * 0.62), 0.18, 0.12, 0.18, S.roof, 6, false)
	for wx in [-0.45, 0.45]:
		A.arch_hole(root, kc + Vector3(wx, 0.80, 0.825), 0.18, 0.40, false, S.glass, S.stone_l, "round", 0.04)
		A.arch_hole(root, kc + Vector3(wx, 1.35, 0.825), 0.16, 0.26, false, S.glass, S.stone_l, "round", 0.04)
	for wz in [-0.40, 0.30]:
		A.arch_hole(root, kc + Vector3(0.825, 0.80, wz), 0.18, 0.40, true, S.glass, S.stone_l, "round", 0.04)
		A.arch_hole(root, kc + Vector3(0.825, 1.35, wz), 0.16, 0.26, true, S.glass, S.stone_l, "round", 0.04)
	A.arch_hole(root, kc + Vector3(0.0, 0.20, 0.825), 0.36, 0.44, false, S.wood, S.stone_l, "round", 0.06)
	M._flag(root, Vector3(0.5, top - 0.1, kc.z + 0.5), team, 0.7)
	B.banner(root, kc + Vector3(0.55, 1.25, 0.84), team, false, 0.26, 0.74)
	B.banner(root, kc + Vector3(-0.55, 1.25, 0.84), team, false, 0.26, 0.74)
	return root

# ------------------------------------------------------------------ herrería 3x3

func herreria(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(801)
	var c := Vector3(-0.20, 0, -0.40)
	var w := 1.80
	var d := 1.40
	var ye := _block(root, S, c, w, d, 0.80)
	A.hip(root, w + 0.22, d + 0.22, 0.40, ye, S.roof, c)
	var zf := c.z + d * 0.5 + 0.005
	# chimenea-cúpula de la fragua
	M.cyl(root, 0.20, 0.24, 0.80, c + Vector3(w * 0.5 + 0.12, 0.54, -0.30), S.band, 12)
	A.lathe(root, A.dome_prof(0.24, 0.20), 12, c + Vector3(w * 0.5 + 0.12, 0.94, -0.30), S.lead)
	A.smoke_src(root, c + Vector3(w * 0.5 + 0.12, 1.22, -0.30))
	M.box(root, Vector3(0.10, 0.26, 0.30), c + Vector3(w * 0.5 + 0.34, 0.34, -0.30), S.dark)
	M.box(root, Vector3(0.12, 0.20, 0.22), c + Vector3(w * 0.5 + 0.35, 0.34, -0.30), S.fire)
	A.arch_hole(root, Vector3(c.x - 0.30, 0.14, zf), 0.74, 0.40, false, S.dark, S.stone_l, "round", 0.06)
	M.box(root, Vector3(0.20, 0.20, 0.03), Vector3(c.x - 0.50, 0.30, zf + 0.04), S.fire)
	_win(root, S, Vector3(c.x + 0.50, 0.56, zf), 0.20, 0.22, false)
	A.forge_yard(root, S)
	B.banner(root, Vector3(c.x + 0.70, 0.80, zf + 0.04), team, false, 0.16, 0.40)
	return root

# ------------------------------------------------------------------ mercado 3x3: estoa con fuente cubierta

func mercado(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(901)
	var tm := _tm(team)
	M.box(root, Vector3(2.70, 0.10, 2.70), Vector3(0, 0.05, 0), S.stone_l)
	M.box(root, Vector3(2.50, 0.04, 2.50), Vector3(0, 0.12, 0), S.stone)
	# estoa: pórtico de arcos de mármol delante de un muro a bandas con tejado de teja
	var bc := Vector3(0.0, 0, -1.08)
	M.box(root, Vector3(2.40, 0.74, 0.40), bc + Vector3(0, 0.53, -0.10), S.band)
	M.box(root, Vector3(2.50, 0.06, 0.50), bc + Vector3(0, 0.93, -0.10), S.stone_l)
	A.arcade(root, Vector3(0.0, 0.14, bc.z + 0.34), true, 5, 0.48, 0.50, S.marble, S.dark, "round")
	M.box(root, Vector3(2.58, 0.06, 0.62), Vector3(0, 0.14 + 0.50 + 0.19, bc.z + 0.24), S.stone_l)
	B.roof_x(root, 2.60, 1.00, 0.34, 0.97, S.roof, Vector3(0, 0, bc.z + 0.14))
	for wx in [-0.96, -0.48, 0.0, 0.48, 0.96]:
		M.box(root, Vector3(0.26, 0.20, 0.16), Vector3(wx, 0.26, bc.z + 0.10), S.wood_l)
	# fuente cubierta (fiale): cuatro columnas, arquitrabe y cúpula, con pila octogonal
	var fc := Vector3(0.0, 0, 0.35)
	M.cyl(root, 0.40, 0.44, 0.16, fc + Vector3(0, 0.16, 0), S.stone_l, 8)
	M.cyl(root, 0.34, 0.34, 0.06, fc + Vector3(0, 0.26, 0), S.water, 8)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			M.cyl(root, 0.035, 0.04, 0.62, fc + Vector3(sx * 0.26, 0.55, sz * 0.26), S.marble, 8)
	M.box(root, Vector3(0.68, 0.06, 0.68), fc + Vector3(0, 0.89, 0), S.stone_l)
	A.lathe(root, A.dome_prof(0.36, 0.30), 12, fc + Vector3(0, 0.92, 0), S.lead)
	A.cross_fin(root, fc + Vector3(0, 1.21, 0), 0.20, S.gold)
	B.puesto(root, Vector3(-1.00, 0.10, 0.70), 90.0, tm, [S.red_fruit, S.green_fruit, S.red_fruit, S.orange_fruit], S)
	B.puesto(root, Vector3(1.00, 0.10, 0.80), -90.0, S.cloth_p, [S.orange_fruit, S.orange_fruit, S.green_fruit, S.red_fruit], S)
	M._flag(root, Vector3(-0.60, 0.10, 1.22), team, 1.30)
	A.jar(root, Vector3(0.72, 0.10, 1.12), S.clay)
	A.jar(root, Vector3(0.90, 0.10, 1.00), S.clay, 0.09)
	B.crate(root, Vector3(-1.10, 0.10, 0.10), S, 0.24, 10.0)
	return root

# ------------------------------------------------------------------ centro urbano 3x3: palacio con gran cúpula

func centro(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := pal(21)
	var c := Vector3(0.0, 0, -0.20)
	var w := 2.00
	var d := 1.90
	var ye := _block(root, S, c, w, d, 1.06)
	A.hip(root, w + 0.12, d + 0.12, 0.20, ye, S.roof, c)
	# ábside trasero y gran cúpula central con cuatro cupulillas en las esquinas
	M.cyl(root, 0.56, 0.56, 0.90, c + Vector3(0, 0.59, -d * 0.5 - 0.02), S.band, 16)
	A.lathe(root, A.dome_prof(0.58, 0.30), 14, c + Vector3(0, 1.04, -d * 0.5 - 0.02), S.roof)
	var top := _dome(root, S, c + Vector3(0.0, ye + 0.08, 0.0), 0.52, 0.52, 0.52, S.lead, 8, true)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_dome(root, S, c + Vector3(sx * 0.70, ye + 0.08, sz * 0.70), 0.20, 0.14, 0.20, S.roof, 6, true)
	# fachada: arcada de mármol, portal y ventanas en dos pisos
	var zf := c.z + d * 0.5
	A.arcade(root, Vector3(c.x, 0.14, zf + 0.12), true, 4, 0.50, 0.50, S.marble, S.dark, "round")
	A.arch_hole(root, Vector3(c.x, 0.14, zf + 0.005), 0.36, 0.44, false, S.wood, S.stone_l, "round", 0.06)
	for wx in [-0.70, 0.70]:
		_win(root, S, Vector3(c.x + wx, 0.62, zf + 0.005), 0.18, 0.28, false)
		_win(root, S, Vector3(c.x + wx, 1.00, zf + 0.005), 0.16, 0.24, false)
	for wz in [-0.55, 0.0, 0.55]:
		_win(root, S, Vector3(c.x + w * 0.5 + 0.005, 0.62, c.z + wz), 0.20, 0.28, true)
		_win(root, S, Vector3(c.x + w * 0.5 + 0.005, 1.02, c.z + wz), 0.16, 0.22, true)
	A.shield(root, Vector3(c.x, 0.96, zf + 0.04), 0.16, false, S.gold, _tm(team))
	B.banner(root, Vector3(c.x - 0.50, 0.90, zf + 0.30), team, false, 0.20, 0.56)
	B.banner(root, Vector3(c.x + 0.50, 0.90, zf + 0.30), team, false, 0.20, 0.56)
	M._flag(root, Vector3(c.x + 0.70, ye + 0.08 + 0.14 + 0.20 + 0.20, c.z - 0.70), team, 0.55)
	A.jar(root, Vector3(1.20, 0.0, 1.30), S.clay)
	return root

# ------------------------------------------------------------------ murallas

func wall_post() -> Node3D:
	return A.wall_post(pal(250).F)

func wall_arm(d: int) -> Node3D:
	return A.wall_arm(d, pal(250).F)

func gate(along_x: bool) -> Node3D:
	var S := pal(260)
	return A.wall_gate(along_x, S.F, S.wood, "round")
