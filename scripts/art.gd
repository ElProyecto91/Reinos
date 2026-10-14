class_name Art
extends RefCounted
## Sprites generados por código con Painter.
## unit_tex[tipo][equipo], building_tex[tipo][equipo], res_atlas (casillas de 32x32).

const UNIT_PX := 48
const SKIN := Color(0.96, 0.80, 0.62)
const BROWN := Color(0.45, 0.30, 0.16)
const OUTLINE := Color(0.08, 0.07, 0.06, 0.9)

var unit_tex: Dictionary = {}
var building_tex: Dictionary = {}
var res_atlas: ImageTexture
var farm_tex: Array = []
var shadow_tex: ImageTexture


func build() -> void:
	_build_units()
	_build_buildings()
	_build_resources()
	_build_misc()

func _new_img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

# ------------------------------------------------------------------ unidades

func _o_disc(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	Painter.disc(img, cx, cy, r + 1.3, OUTLINE)
	Painter.disc(img, cx, cy, r, col)

func _o_ell(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	Painter.ellipse(img, cx, cy, rx + 1.3, ry + 1.3, OUTLINE)
	Painter.ellipse(img, cx, cy, rx, ry, col)

func _build_units() -> void:
	for type in Defs.UNITS:
		unit_tex[type] = []
		for team in 4:
			var img := _new_img(UNIT_PX, UNIT_PX)
			var c: Color = Defs.PLAYER_COLORS[team]
			match type:
				"aldeano":
					Painter.line(img, 34, 21, 38, 41, 3.8, OUTLINE)
					Painter.line(img, 34, 21, 38, 41, 2.2, BROWN)
					Painter.tri(img, 31, 20, 40, 18, 36, 25, Color(0.7, 0.7, 0.72))
					_o_ell(img, 24, 30, 9, 11, c)
					Painter.rect(img, 15, 33, 18, 3, Painter.shade(c, 0.7))
					_o_disc(img, 24, 15.5, 6.6, SKIN)
					Painter.ellipse(img, 24, 11.2, 8.4, 3.2, Color(0.78, 0.62, 0.3))
					Painter.ellipse(img, 24, 8.8, 5.2, 4.2, Color(0.78, 0.62, 0.3))
				"piquero":
					Painter.line(img, 34, 4, 34, 45, 3.6, OUTLINE)
					Painter.line(img, 34, 6, 34, 45, 2.0, BROWN)
					Painter.tri(img, 34, 1, 31, 9, 37, 9, Color(0.85, 0.86, 0.9))
					_o_ell(img, 25, 30, 9, 11, Painter.shade(c, 0.9))
					_o_disc(img, 25, 15.5, 6.6, SKIN)
					Painter.ellipse(img, 25, 12.2, 7.6, 5.4, Color(0.62, 0.64, 0.68))
					Painter.rect(img, 24, 12, 2, 6, Color(0.5, 0.52, 0.56))
					_o_disc(img, 16, 30, 8, Color(0.72, 0.72, 0.76))
					Painter.disc(img, 16, 30, 3.2, c)
				"arquero":
					_o_ell(img, 24, 30, 9, 11, Painter.shade(c, 0.85))
					Painter.rect(img, 15, 22, 4, 13, BROWN)
					Painter.line(img, 16, 21, 16, 18, 1.4, Color(0.9, 0.9, 0.9))
					Painter.line(img, 18, 21, 18, 17, 1.4, Color(0.9, 0.9, 0.9))
					_o_disc(img, 24, 15, 7.4, Painter.shade(c, 0.7))
					Painter.disc(img, 25.5, 16.5, 4.3, SKIN)
					Painter.arc(img, 31, 26, 13, -1.25, 1.25, 4.0, OUTLINE)
					Painter.arc(img, 31, 26, 13, -1.25, 1.25, 2.2, Color(0.55, 0.36, 0.18))
					Painter.line(img, 31 + cos(-1.25) * 13, 26 + sin(-1.25) * 13, 31 + cos(1.25) * 13, 26 + sin(1.25) * 13, 1.0, Color(0.95, 0.95, 0.9))
				"jinete":
					var horse := Color(0.55, 0.36, 0.2)
					for lx in [11.0, 15.0, 29.0, 33.0]:
						Painter.line(img, lx, 32, lx + (1.0 if lx > 20 else -1.0), 43, 3.4, OUTLINE)
						Painter.line(img, lx, 32, lx + (1.0 if lx > 20 else -1.0), 43, 2.0, Painter.shade(horse, 0.8))
					_o_ell(img, 22, 31, 14, 7.5, horse)
					Painter.line(img, 31, 27, 37, 16, 8.0, OUTLINE)
					Painter.line(img, 31, 27, 37, 16, 6.0, horse)
					_o_ell(img, 40, 15, 5.4, 3.4, horse)
					Painter.line(img, 33, 15, 36, 26, 2.4, Color(0.2, 0.14, 0.09))
					Painter.line(img, 8, 29, 4, 38, 2.6, Color(0.2, 0.14, 0.09))
					Painter.line(img, 27, 21, 46, 6, 2.6, OUTLINE)
					Painter.line(img, 27, 21, 46, 6, 1.4, Color(0.85, 0.86, 0.9))
					_o_ell(img, 22, 20, 5.6, 7.4, c)
					_o_disc(img, 22, 10.6, 4.6, SKIN)
					Painter.ellipse(img, 22, 8.2, 5.2, 3.6, Color(0.62, 0.64, 0.68))
			var tex := ImageTexture.create_from_image(img)
			unit_tex[type].append(tex)

# ------------------------------------------------------------------ edificios

func _build_buildings() -> void:
	var sizes := {"centro": 96, "casa": 64, "almacen": 64, "cuartel": 96, "arqueria": 96, "establo": 96, "torre": 64, "muralla": 64, "puerta": 64}
	for type in sizes:
		var px: int = sizes[type]
		var ss := ArtBuildings.SS
		var base := _new_img(px * ss, px * ss)
		ArtBuildings.paint_base(ArtBuildings.Cv.new(base, float(ss)), type)
		building_tex[type] = []
		for team in 4:
			var img := base.duplicate() as Image
			ArtBuildings.paint_team(ArtBuildings.Cv.new(img, float(ss)), type, Defs.PLAYER_COLORS[team])
			img.generate_mipmaps()
			building_tex[type].append(ImageTexture.create_from_image(img))

# ------------------------------------------------------------------ recursos
# Cada casilla del atlas mide 64x64 (el doble que la rejilla): el pie del árbol cae en la parte
# baja de la casilla y la copa sobresale hacia arriba. El mapa de casillas dibuja por filas,
# así que los árboles de abajo tapan correctamente a los de arriba.

const RES_CELL := 64
const TREE_OAK_A := 0
const TREE_OAK_B := 1
const TREE_PINE := 2
const RES_GOLD := 3
const RES_BERRY := 4
const RES_FISH0 := 5
const RES_FISH1 := 6
const TREE_SNOW := 7
const TREE_PALM := 8
const TREE_DRY := 9
const TREE_AUTUMN := 10
const TREE_PINE_B := 11
const ATLAS_N := 12

func _build_resources() -> void:
	var atlas := _new_img(RES_CELL * ATLAS_N, RES_CELL)
	var put := func(idx: int, painter: Callable) -> void:
		var t := _new_img(RES_CELL, RES_CELL)
		painter.call(t)
		atlas.blit_rect(t, Rect2i(0, 0, RES_CELL, RES_CELL), Vector2i(idx * RES_CELL, 0))
	put.call(TREE_OAK_A, func(t: Image) -> void: _paint_oak(t, 0))
	put.call(TREE_OAK_B, func(t: Image) -> void: _paint_oak(t, 1))
	put.call(TREE_AUTUMN, func(t: Image) -> void: _paint_oak(t, 2))
	put.call(TREE_PINE, func(t: Image) -> void: _paint_pine(t, false, 0))
	put.call(TREE_PINE_B, func(t: Image) -> void: _paint_pine(t, false, 1))
	put.call(TREE_SNOW, func(t: Image) -> void: _paint_pine(t, true, 0))
	put.call(TREE_PALM, func(t: Image) -> void: _paint_palm(t))
	put.call(TREE_DRY, func(t: Image) -> void: _paint_dry(t))
	put.call(RES_GOLD, func(t: Image) -> void: _paint_gold(t))
	# bayas y peces se dibujan en 32x32 y se centran en la casilla de 64
	var small := func(idx: int, painter: Callable) -> void:
		var s := _new_img(32, 32)
		painter.call(s)
		var t := _new_img(RES_CELL, RES_CELL)
		t.blit_rect(s, Rect2i(0, 0, 32, 32), Vector2i(16, 16))
		atlas.blit_rect(t, Rect2i(0, 0, RES_CELL, RES_CELL), Vector2i(idx * RES_CELL, 0))
	small.call(RES_BERRY, func(s: Image) -> void: _paint_berry(s))
	small.call(RES_FISH0, func(s: Image) -> void: _paint_fish(s, 0))
	small.call(RES_FISH1, func(s: Image) -> void: _paint_fish(s, 1))
	atlas.generate_mipmaps()
	res_atlas = ImageTexture.create_from_image(atlas)

const LEAF_OUT := Color(0.03, 0.10, 0.04, 0.85)

func _trunk(img: Image, x: float, y0: float, y1: float, w: float, col: Color) -> void:
	Painter.rect(img, x - w * 0.5 - 1.0, y0, w + 2.0, y1 - y0, Color(0.1, 0.07, 0.04, 0.9))
	Painter.rect(img, x - w * 0.5, y0, w, y1 - y0, col)
	Painter.rect(img, x - w * 0.5, y0, maxf(1.2, w * 0.35), y1 - y0, Painter.shade(col, 1.3))
	Painter.rect(img, x + w * 0.5 - 1.4, y0, 1.4, y1 - y0, Painter.shade(col, 0.7))

func _paint_oak(img: Image, v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + v
	var bases := [Color(0.17, 0.42, 0.16), Color(0.25, 0.47, 0.15), Color(0.62, 0.44, 0.13)]
	var base: Color = bases[v]
	Painter.ellipse(img, 36, 47, 18, 5.5, Color(0, 0, 0, 0.30))
	Painter.tri(img, 27, 48, 34, 41, 31, 48, Color(0.30, 0.20, 0.10))
	_trunk(img, 32, 34, 47, 6.0, Color(0.40, 0.27, 0.14))
	var lobes := [Vector3(32, 22, 14), Vector3(20.5, 28, 10), Vector3(43.5, 28, 10.5), Vector3(26, 13, 9.5), Vector3(38.5, 14, 9.0), Vector3(32, 32, 10.0)]
	for l: Vector3 in lobes:
		Painter.disc(img, l.x, l.y, l.z + 1.4, LEAF_OUT)
	for l: Vector3 in lobes:
		Painter.disc(img, l.x, l.y, l.z, Painter.shade(base, 0.72))
	for l: Vector3 in lobes:
		Painter.disc(img, l.x - 1.8, l.y - 2.2, l.z * 0.84, base)
	for l: Vector3 in lobes:
		Painter.disc(img, l.x - 3.4, l.y - 4.2, l.z * 0.5, Painter.shade(base, 1.32))
	# follaje: puntos claros y oscuros repartidos por la copa
	for i in 60:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 1.0
		var px := 32.0 + cos(a) * d * 18.0
		var py := 23.0 + sin(a) * d * 15.0
		if py > 36.0:
			continue
		var k := rng.randf_range(0.65, 1.55)
		Painter.disc(img, px, py, rng.randf_range(1.0, 2.1), Painter.shade(base, k))
	# base de la copa más oscura (sombra propia)
	Painter.ellipse(img, 35, 34.5, 13, 4.5, Color(0.02, 0.07, 0.03, 0.38))

func _paint_pine(img: Image, snowy: bool, v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + v
	var base := Color(0.10, 0.33, 0.20) if v == 0 else Color(0.08, 0.28, 0.17)
	Painter.ellipse(img, 36, 47, 14, 5.0, Color(0, 0, 0, 0.30))
	_trunk(img, 32, 40, 47, 4.0, Color(0.36, 0.24, 0.12))
	var tiers := 4 if v == 0 else 5
	for i in tiers:
		var bot := 44.0 - i * (30.0 / tiers) * 0.95
		var top := bot - 17.0
		var w := (15.0 - i * (11.0 / tiers))
		Painter.tri(img, 32, top - 1.3, 32 - w - 1.4, bot + 1.1, 32 + w + 1.4, bot + 1.1, LEAF_OUT)
		Painter.tri(img, 32, top, 32 - w, bot, 32 + w, bot, Painter.shade(base, 0.75))
		Painter.tri(img, 32, top, 32 - w, bot, 32 - w * 0.05, bot, Painter.shade(base, 1.30))      # mitad iluminada (noroeste)
		Painter.tri(img, 32, top + 3, 32 - w * 0.55, bot - 1, 32 - w * 0.1, bot - 1, Painter.shade(base, 1.55))
		for k in 7:
			var t := rng.randf()
			var px := 32.0 + (rng.randf() * 2.0 - 1.0) * w * t * 0.85
			Painter.disc(img, px, top + (bot - top) * t, rng.randf_range(0.8, 1.5), Painter.shade(base, rng.randf_range(0.6, 1.6)))
		if snowy:
			var snow := Color(0.95, 0.97, 1.0)
			Painter.tri(img, 32, top, 32 - w * 0.60, top + (bot - top) * 0.60, 32 + w * 0.60, top + (bot - top) * 0.60, snow)
			Painter.tri(img, 32, top, 32 - w * 0.60, top + (bot - top) * 0.60, 32 - w * 0.02, top + (bot - top) * 0.60, Color(0.80, 0.88, 0.97, 0.9))
			for k in 3:
				Painter.disc(img, 32 - w * 0.55 + k * w * 0.55, top + (bot - top) * 0.62, 2.2, snow)

func _paint_palm(img: Image) -> void:
	Painter.ellipse(img, 37, 47, 14, 4.5, Color(0, 0, 0, 0.28))
	var pts: Array[Vector2] = []
	for i in 9:
		var t := i / 8.0
		var p0 := Vector2(31, 47)
		var c0 := Vector2(26, 32)
		var p1 := Vector2(35, 17)
		pts.append(p0 * (1 - t) * (1 - t) + c0 * 2.0 * t * (1 - t) + p1 * t * t)
	for i in range(pts.size() - 1):
		Painter.line(img, pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y, 5.6 - i * 0.2, Color(0.1, 0.07, 0.04, 0.9))
	for i in range(pts.size() - 1):
		var col := Color(0.62, 0.48, 0.28) if i % 2 == 0 else Color(0.53, 0.40, 0.23)
		Painter.line(img, pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y, 4.2 - i * 0.2, col)
	var top := pts[8]
	var leaf := Color(0.20, 0.50, 0.18)
	var angs := [-2.9, -2.35, -1.8, -1.2, -0.7, -0.2, 0.2]
	for a: float in angs:
		var dir := Vector2(cos(a), sin(a))
		var prev := top
		for j in range(1, 6):
			var t := j / 5.0
			var p := top + dir * 18.0 * t + Vector2(0, 11.0 * t * t)
			Painter.line(img, prev.x, prev.y, p.x, p.y, 4.4 - t * 3.2, LEAF_OUT)
			prev = p
		prev = top
		for j in range(1, 6):
			var t := j / 5.0
			var p := top + dir * 18.0 * t + Vector2(0, 11.0 * t * t)
			Painter.line(img, prev.x, prev.y, p.x, p.y, 3.4 - t * 2.6, Painter.shade(leaf, 1.25 if a < -1.5 else 0.9))
			prev = p
	Painter.disc(img, top.x - 1.5, top.y + 2.0, 2.2, Color(0.35, 0.24, 0.12))
	Painter.disc(img, top.x + 1.8, top.y + 2.6, 2.0, Color(0.30, 0.20, 0.10))

func _paint_dry(img: Image) -> void:
	# arbusto seco / árbol muerto del desierto
	Painter.ellipse(img, 35, 46, 14, 4.2, Color(0, 0, 0, 0.26))
	var wood := Color(0.42, 0.32, 0.20)
	var branches := [[32, 46, 31, 30], [31, 36, 22, 24], [31, 33, 41, 22], [32, 30, 28, 15], [37, 27, 46, 20], [24, 28, 17, 26]]
	for b in branches:
		Painter.line(img, b[0], b[1], b[2], b[3], 3.8, Color(0.1, 0.07, 0.04, 0.85))
	for b in branches:
		Painter.line(img, b[0], b[1], b[2], b[3], 2.4, wood)
	for p in [Vector2(28, 15), Vector2(22, 24), Vector2(41, 22), Vector2(46, 20), Vector2(17, 26)]:
		Painter.disc(img, p.x, p.y, 2.8, Color(0.55, 0.52, 0.22))
		Painter.disc(img, p.x - 0.8, p.y - 0.8, 1.6, Color(0.70, 0.66, 0.30))

func _paint_gold(img: Image) -> void:
	Painter.ellipse(img, 33, 47, 20, 6.0, Color(0, 0, 0, 0.30))
	var rock := Color(0.46, 0.45, 0.48)
	var blobs := [Vector3(32, 36, 14), Vector3(20, 40, 9), Vector3(44, 40, 9.5), Vector3(28, 28, 9), Vector3(38, 29, 8)]
	for b: Vector3 in blobs:
		Painter.disc(img, b.x, b.y, b.z + 1.4, Color(0.07, 0.07, 0.08, 0.9))
	for b: Vector3 in blobs:
		Painter.disc(img, b.x, b.y, b.z, Painter.shade(rock, 0.72))
	for b: Vector3 in blobs:
		Painter.disc(img, b.x - 1.6, b.y - 2.2, b.z * 0.82, rock)
	for b: Vector3 in blobs:
		Painter.disc(img, b.x - 3.2, b.y - 4.0, b.z * 0.42, Painter.shade(rock, 1.3))
	# vetas y pepitas de oro con brillo
	var nug := [Vector3(26, 31, 4.6), Vector3(37, 27, 5.2), Vector3(33, 38, 4.4), Vector3(44, 38, 3.4), Vector3(19, 41, 3.2), Vector3(31, 22, 3.0)]
	for n: Vector3 in nug:
		Painter.disc(img, n.x, n.y, n.z + 1.1, Color(0.38, 0.24, 0.02, 0.9))
		Painter.disc(img, n.x, n.y, n.z, Color(0.96, 0.76, 0.12))
		Painter.disc(img, n.x - n.z * 0.28, n.y - n.z * 0.30, n.z * 0.62, Color(1.0, 0.88, 0.28))
		Painter.disc(img, n.x - n.z * 0.38, n.y - n.z * 0.42, n.z * 0.28, Color(1.0, 0.98, 0.78))

func _paint_berry(img: Image) -> void:
	Painter.ellipse(img, 17, 27, 12, 3.4, Color(0, 0, 0, 0.28))
	Painter.disc(img, 16, 19, 11.8, Color(0.05, 0.14, 0.06, 0.9))
	Painter.disc(img, 16, 19, 10.5, Color(0.15, 0.40, 0.16))
	Painter.disc(img, 9, 21, 7, Color(0.20, 0.50, 0.19))
	Painter.disc(img, 23, 21, 7, Color(0.16, 0.42, 0.17))
	Painter.disc(img, 13, 15, 6.5, Color(0.28, 0.58, 0.24))
	for p in [Vector2(11, 15), Vector2(19, 13), Vector2(23, 20), Vector2(14, 22), Vector2(8, 22), Vector2(20, 24), Vector2(16, 18), Vector2(6, 18), Vector2(26, 23)]:
		Painter.disc(img, p.x, p.y, 2.1, Color(0.38, 0.03, 0.08))
		Painter.disc(img, p.x, p.y, 1.7, Color(0.88, 0.12, 0.18))
		Painter.disc(img, p.x - 0.5, p.y - 0.6, 0.65, Color(1, 0.75, 0.75))

func _paint_fish(img: Image, v: int) -> void:
	Painter.ring(img, 16, 17, 11, 1.2, Color(1, 1, 1, 0.28))
	var s := 1.0 if v == 0 else -1.0
	var cx := 14.0 if v == 0 else 18.0
	Painter.ellipse(img, cx, 15, 7, 3.6, Color(0.82, 0.88, 0.95))
	Painter.tri(img, cx - 6 * s, 15, cx - 11 * s, 11, cx - 11 * s, 19, Color(0.7, 0.8, 0.9))
	Painter.disc(img, cx + 4 * s, 14, 0.9, Color(0.1, 0.1, 0.15))
	Painter.ellipse(img, cx + 14 * s * 0.0 + (6 if v == 0 else -6), 23, 4, 2, Color(0.75, 0.84, 0.92))

func _build_misc() -> void:
	var sh := _new_img(32, 32)
	Painter.ellipse(sh, 16, 16, 14, 14, Color(0, 0, 0, 0.3))
	shadow_tex = ImageTexture.create_from_image(sh)
