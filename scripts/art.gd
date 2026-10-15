class_name Art
extends RefCounted
## Sprites generados por código con Painter.
## sheet(tipo) = hoja de fotogramas (3 capas), unit_icon(tipo, equipo), building_tex[tipo][equipo], res_atlas.

const SKIN := Color(0.96, 0.80, 0.62)
const BROWN := Color(0.45, 0.30, 0.16)
const OUTLINE := Color(0.08, 0.07, 0.06, 0.9)

var unit_sheets: Dictionary = {}     # tipo -> hoja con mipmaps (se carga la primera vez que hace falta)
var _icons: Dictionary = {}
var team_mod: Array[Color] = []        # color con el que se tiñe la capa de equipo de las hojas
var building_tex: Dictionary = {}
var res_atlas: ImageTexture
var farm_tex: Array = []
var shadow_tex: ImageTexture
var puff_tex: ImageTexture             # disco blanco suave (humo, brillos): se tiñe al dibujar y se agrupa en una sola llamada
var carry_atlas: ImageTexture          # iconos de carga en fila: oro, comida, madera (pintados a 2x)
var carry_cell := 0                    # lado en píxeles de cada icono del atlas
var _rings: Dictionary = {}            # anillos de selección ya pintados (clave = radio y achatamiento)
const CARRY_SS := 2.0                  # factor de supersampling de los iconos de carga
const CARRY_HALF := 14.0               # mitad del lado del icono en píxeles de mundo (con k = 1)


func build() -> void:
	for c: Color in Defs.PLAYER_COLORS:
		# ligeramente menos saturado que el color de jugador: la tela teñida no es tan chillona como el icono del HUD
		var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		var m := Color(lerpf(c.r, lum, 0.10), lerpf(c.g, lum, 0.10), lerpf(c.b, lum, 0.10), 1.0)
		team_mod.append(Color(minf(1.0, m.r * 1.12), minf(1.0, m.g * 1.12), minf(1.0, m.b * 1.12), 1.0))
	_build_buildings()
	_build_resources()
	_build_misc()

func _new_img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

# ------------------------------------------------------------------ unidades

## Las hojas de unidades se dibujan una vez con tools/bake_units.gd y viajan como PNG (res://art/units).
## Si no existe el PNG (o aún no está importado) se pintan en el momento con ArtUnits.
func sheet(type: String) -> Texture2D:
	var t: Texture2D = unit_sheets.get(type)
	if t != null:
		return t
	var img: Image = null
	var path := "res://art/units/%s.png" % type
	if ResourceLoader.exists(path):
		var src := load(path) as Texture2D
		if src != null:
			img = src.get_image()
			if img != null and img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
	if img == null:
		img = ArtUnits.build_sheet(type)
	img.generate_mipmaps()
	t = ImageTexture.create_from_image(img)
	unit_sheets[type] = t
	return t

## Icono cuadrado (64x64) de una unidad con el color de un equipo, para menús e informes.
func unit_icon(type: String, team: int) -> Texture2D:
	var key := "%s#%d" % [type, team]
	var t: Texture2D = _icons.get(key)
	if t != null:
		return t
	var sh := sheet(type).get_image()
	var cp := ArtUnits.cell_px(type)
	var layers: Array[Image] = []
	for l in 3:
		layers.append(sh.get_region(ArtUnits.frame_rect(type, 0, l)))
	var tc: Color = Defs.PLAYER_COLORS[team % 4]
	var tm := layers[1]
	for y in tm.get_height():
		for x in tm.get_width():
			var p := tm.get_pixel(x, y)
			if p.a > 0.0:
				tm.set_pixel(x, y, Color(minf(1.0, p.r * tc.r * 1.15), minf(1.0, p.g * tc.g * 1.15), minf(1.0, p.b * tc.b * 1.15), p.a))
	var out := Image.create(cp.x, cp.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for l in 3:
		out.blend_rect(layers[l], Rect2i(0, 0, cp.x, cp.y), Vector2i.ZERO)
	var used := out.get_used_rect()
	if used.size.x < 2 or used.size.y < 2:
		used = Rect2i(0, 0, cp.x, cp.y)
	var crop := out.get_region(used)
	var side := 64
	var k := minf(float(side - 4) / float(crop.get_width()), float(side - 4) / float(crop.get_height()))
	var w := maxi(1, int(round(crop.get_width() * k)))
	var h := maxi(1, int(round(crop.get_height() * k)))
	crop.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var icon := Image.create(side, side, false, Image.FORMAT_RGBA8)
	icon.fill(Color(0, 0, 0, 0))
	icon.blend_rect(crop, Rect2i(0, 0, w, h), Vector2i((side - w) / 2, (side - h) / 2))
	t = ImageTexture.create_from_image(icon)
	_icons[key] = t
	return t

# ------------------------------------------------------------------ edificios

func _build_buildings() -> void:
	var sizes := {"centro": 96, "casa": 64, "almacen": 64, "cuartel": 96, "arqueria": 96, "establo": 96, "taller": 96, "puerto": 96, "torre": 64, "muralla": 64, "puerta": 64, "monasterio": 96, "castillo": 128}
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
	var pf := _new_img(32, 32)
	Painter.disc(pf, 16, 16, 15.0, Color(1, 1, 1, 1))
	puff_tex = ImageTexture.create_from_image(pf)
	var kinds := ["gold", "food", "wood"]
	carry_cell = int(CARRY_HALF * 2.0 * CARRY_SS)
	var at := _new_img(carry_cell * kinds.size(), carry_cell)
	for i in kinds.size():
		at.blit_rect(_paint_carry(kinds[i]), Rect2i(0, 0, carry_cell, carry_cell), Vector2i(i * carry_cell, 0))
	carry_atlas = ImageTexture.create_from_image(at)

## Icono de lo que lleva un aldeano o pescador (mismos trazos que se dibujaban con primitivas, pero como textura:
## una sola llamada de dibujo en lugar de 4-6 por unidad).
func _paint_carry(kind: String) -> Image:
	var n := int(CARRY_HALF * 2.0 * CARRY_SS)
	var img := _new_img(n, n)
	var c := Vector2(n, n) * 0.5
	var s := CARRY_SS
	Painter.disc(img, c.x, c.y, 8.0 * s, Color(0, 0, 0, 0.45))
	match kind:
		"gold":
			var raw := [Vector2(-6, 3), Vector2(-3, -4), Vector2(2, -5), Vector2(6, 1), Vector2(4, 4)]
			var pts: Array[Vector2] = []
			for q: Vector2 in raw:
				pts.append(c + q * s)
			for i in range(1, 4):
				Painter.tri(img, pts[0].x, pts[0].y, pts[i].x, pts[i].y, pts[i + 1].x, pts[i + 1].y, Color(1.0, 0.84, 0.18))
			for i in 5:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[(i + 1) % 5]
				Painter.line(img, a.x, a.y, b.x, b.y, 1.5 * s, Color(0.45, 0.3, 0.0))
			Painter.line(img, c.x - 3.0 * s, c.y - 1.0 * s, c.x, c.y - 3.0 * s, 1.5 * s, Color(1, 1, 0.8))
		"food":
			Painter.disc(img, c.x, c.y + 1.0 * s, 5.5 * s, Color(0.3, 0.05, 0.05))
			Painter.disc(img, c.x, c.y + 1.0 * s, 4.3 * s, Color(0.88, 0.15, 0.15))
			Painter.disc(img, c.x - 1.5 * s, c.y - 0.5 * s, 1.3 * s, Color(1, 0.7, 0.65))
			Painter.line(img, c.x, c.y - 3.0 * s, c.x + 2.0 * s, c.y - 6.0 * s, 1.8 * s, Color(0.2, 0.5, 0.15))
		_:
			for dy in [-2.5, 2.5]:
				var r := Rect2(c + Vector2(-6.5, dy - 2.2) * s, Vector2(13, 4.4) * s)
				var g := r.grow(1.0 * s)
				Painter.rect(img, g.position.x, g.position.y, g.size.x, g.size.y, Color(0.2, 0.1, 0.03))
				Painter.rect(img, r.position.x, r.position.y, r.size.x, r.size.y, Color(0.62, 0.4, 0.18))
				Painter.disc(img, r.end.x - 1.5 * s, r.get_center().y, 1.6 * s, Color(0.85, 0.65, 0.4))
	return img

## Anillo de selección elíptico (verde) de radio rr; ky = achatamiento vertical (0,55 a pie, 0,30 barcos).
## Devuelve la textura; se dibuja en un rectángulo de (2·(rr+3)) × (2·(rr+3)·ky) centrado en el anillo.
func ring_tex(rr: float, ky: float) -> ImageTexture:
	var key := "%d_%d" % [int(round(rr * 2.0)), int(round(ky * 100.0))]
	var t: ImageTexture = _rings.get(key)
	if t != null:
		return t
	var ss := 2
	var side := int(ceil((rr + 3.0) * 2.0)) * ss
	var img := _new_img(side, side)
	Painter.ring(img, side * 0.5, side * 0.5, rr * ss, 2.2 * ss, Color(0.2, 1.0, 0.3, 0.95))
	img.resize(side, maxi(2, int(round(side * ky))), Image.INTERPOLATE_LANCZOS)
	t = ImageTexture.create_from_image(img)
	_rings[key] = t
	return t
