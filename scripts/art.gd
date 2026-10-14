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

const RES_TILE_INDEX := {"tree0": 0, "tree1": 1, "tree2": 2, "gold": 3, "berry": 4, "fish0": 5, "fish1": 6}

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
			Painter.ellipse(img, 24, 41, 13, 4.2, Color(0, 0, 0, 0.28))
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
		var base := _new_img(px, px)
		_paint_building_base(base, type, px)
		building_tex[type] = []
		for team in 4:
			var img := base.duplicate() as Image
			_paint_building_team(img, type, px, Defs.PLAYER_COLORS[team])
			building_tex[type].append(ImageTexture.create_from_image(img))

func _stone_lines(img: Image, x: float, y: float, w: float, h: float, col: Color) -> void:
	var yy := y + 6.0
	var row := 0
	while yy < y + h - 2.0:
		Painter.rect(img, x + 1, yy, w - 2, 1, col)
		var off := 0.0 if row % 2 == 0 else 6.0
		var xx := x + 8.0 + off
		while xx < x + w - 3.0:
			Painter.rect(img, xx, yy, 1, 6, col)
			xx += 12.0
		yy += 6.0
		row += 1

func _crenel(img: Image, x: float, y: float, w: float, col: Color) -> void:
	var xx := x
	while xx < x + w - 3.0:
		Painter.rect(img, xx, y - 5, 5, 6, col)
		xx += 9.0

func _paint_building_base(img: Image, type: String, px: int) -> void:
	Painter.ellipse(img, px * 0.5, px * 0.93, px * 0.46, px * 0.07, Color(0, 0, 0, 0.3))
	var stone := Color(0.72, 0.70, 0.66)
	var dark := Color(0.12, 0.1, 0.09)
	match type:
		"muralla":
			Painter.rect(img, 3, 23, 58, 36, dark)
			Painter.rect(img, 4, 24, 56, 34, stone)
			_stone_lines(img, 4, 24, 56, 34, Color(0.56, 0.54, 0.5))
			_crenel(img, 4, 24, 56, stone)
		"puerta":
			Painter.rect(img, 21, 28, 22, 31, dark)
			Painter.rect(img, 22, 29, 20, 30, Color(0.64, 0.62, 0.58))
			for sx in [3, 43]:
				Painter.rect(img, sx, 14, 18, 45, dark)
				Painter.rect(img, sx + 1, 15, 16, 43, Color(0.68, 0.66, 0.62))
				_stone_lines(img, sx + 1, 15, 16, 43, Color(0.54, 0.52, 0.48))
				_crenel(img, sx + 1, 15, 16, Color(0.68, 0.66, 0.62))
			Painter.rect(img, 25, 36, 14, 23, dark)
			Painter.disc(img, 32, 36, 7, dark)
			Painter.rect(img, 26, 37, 12, 22, Color(0.42, 0.26, 0.11))
			Painter.disc(img, 32, 37, 6, Color(0.42, 0.26, 0.11))
			Painter.rect(img, 26, 44, 12, 2, Color(0.22, 0.22, 0.25))
			Painter.rect(img, 26, 52, 12, 2, Color(0.22, 0.22, 0.25))
		"casa":
			Painter.rect(img, 9, 29, 46, 29, dark)
			Painter.rect(img, 10, 30, 44, 27, Color(0.88, 0.78, 0.6))
			Painter.rect(img, 27, 40, 11, 17, Color(0.4, 0.26, 0.14))
			Painter.rect(img, 14, 37, 9, 9, Color(0.25, 0.4, 0.55))
			Painter.rect(img, 41, 37, 9, 9, Color(0.25, 0.4, 0.55))
			Painter.tri(img, 2, 32, 62, 32, 32, 6, dark)
			Painter.tri(img, 5, 31, 59, 31, 32, 9, Color(0.66, 0.27, 0.2))
			Painter.line(img, 8, 30, 32, 10, 1.4, Color(0.8, 0.4, 0.3))
		"almacen":
			Painter.rect(img, 5, 25, 54, 33, dark)
			Painter.rect(img, 6, 26, 52, 31, Color(0.58, 0.4, 0.22))
			for i in 6:
				Painter.rect(img, 6 + i * 9, 26, 1, 31, Color(0.4, 0.27, 0.14))
			Painter.quad(img, Vector2(1, 28), Vector2(63, 28), Vector2(56, 13), Vector2(8, 13), dark)
			Painter.quad(img, Vector2(4, 27), Vector2(60, 27), Vector2(54, 15), Vector2(10, 15), Color(0.42, 0.28, 0.16))
			Painter.rect(img, 11, 40, 13, 13, Color(0.76, 0.56, 0.3))
			Painter.rect(img, 11, 40, 13, 1, dark)
			Painter.rect(img, 11, 46, 13, 1, dark)
			Painter.disc(img, 40, 48, 6, Color(0.88, 0.8, 0.55))
			Painter.disc(img, 49, 49, 5, Color(0.84, 0.74, 0.48))
		"cuartel":
			Painter.rect(img, 7, 39, 82, 52, dark)
			Painter.rect(img, 8, 40, 80, 50, Color(0.78, 0.74, 0.66))
			_stone_lines(img, 8, 40, 80, 50, Color(0.6, 0.56, 0.5))
			Painter.quad(img, Vector2(2, 42), Vector2(94, 42), Vector2(84, 14), Vector2(12, 14), dark)
			Painter.quad(img, Vector2(5, 41), Vector2(91, 41), Vector2(82, 17), Vector2(14, 17), Color(0.42, 0.34, 0.3))
			Painter.rect(img, 38, 58, 20, 32, Color(0.34, 0.22, 0.12))
			Painter.disc(img, 48, 58, 10, Color(0.34, 0.22, 0.12))
			Painter.line(img, 34, 22, 62, 38, 3.4, dark)
			Painter.line(img, 62, 22, 34, 38, 3.4, dark)
			Painter.line(img, 34, 22, 62, 38, 1.8, Color(0.85, 0.86, 0.9))
			Painter.line(img, 62, 22, 34, 38, 1.8, Color(0.85, 0.86, 0.9))
		"arqueria":
			Painter.rect(img, 7, 39, 82, 52, dark)
			Painter.rect(img, 8, 40, 80, 50, Color(0.66, 0.5, 0.3))
			for i in 9:
				Painter.rect(img, 8 + i * 9, 40, 1, 50, Color(0.46, 0.33, 0.18))
			Painter.quad(img, Vector2(2, 42), Vector2(94, 42), Vector2(84, 14), Vector2(12, 14), dark)
			Painter.quad(img, Vector2(5, 41), Vector2(91, 41), Vector2(82, 17), Vector2(14, 17), Color(0.3, 0.42, 0.26))
			Painter.rect(img, 38, 62, 20, 28, Color(0.3, 0.2, 0.11))
			Painter.disc(img, 48, 30, 11, dark)
			Painter.disc(img, 48, 30, 10, Color(0.95, 0.95, 0.92))
			Painter.disc(img, 48, 30, 7, Color(0.8, 0.2, 0.18))
			Painter.disc(img, 48, 30, 4, Color(0.95, 0.95, 0.92))
			Painter.disc(img, 48, 30, 1.8, Color(0.8, 0.2, 0.18))
		"establo":
			Painter.rect(img, 7, 39, 82, 52, dark)
			Painter.rect(img, 8, 40, 80, 50, Color(0.62, 0.3, 0.22))
			for i in 9:
				Painter.rect(img, 8 + i * 9, 40, 1, 50, Color(0.45, 0.2, 0.15))
			Painter.tri(img, 1, 42, 95, 42, 48, 8, dark)
			Painter.tri(img, 5, 41, 91, 41, 48, 12, Color(0.45, 0.36, 0.3))
			Painter.rect(img, 31, 56, 34, 34, dark)
			Painter.rect(img, 32, 57, 32, 33, Color(0.86, 0.78, 0.6))
			Painter.line(img, 32, 57, 64, 90, 2.4, Color(0.45, 0.3, 0.16))
			Painter.line(img, 64, 57, 32, 90, 2.4, Color(0.45, 0.3, 0.16))
			Painter.rect(img, 47, 57, 2, 33, Color(0.45, 0.3, 0.16))
			Painter.ellipse(img, 76, 82, 9, 5, Color(0.92, 0.8, 0.3))
		"torre":
			Painter.rect(img, 17, 17, 30, 42, dark)
			Painter.rect(img, 18, 18, 28, 40, stone)
			_stone_lines(img, 18, 18, 28, 40, Color(0.55, 0.53, 0.5))
			Painter.rect(img, 15, 12, 34, 8, dark)
			Painter.rect(img, 16, 13, 32, 6, Color(0.62, 0.6, 0.56))
			_crenel(img, 16, 13, 32, Color(0.62, 0.6, 0.56))
			Painter.rect(img, 30, 28, 4, 12, dark)
			Painter.rect(img, 26, 46, 12, 12, Color(0.3, 0.2, 0.11))
		"centro":
			Painter.rect(img, 5, 33, 86, 58, dark)
			Painter.rect(img, 6, 34, 84, 56, stone)
			_stone_lines(img, 6, 34, 84, 56, Color(0.56, 0.54, 0.5))
			Painter.rect(img, 25, 8, 46, 44, dark)
			Painter.rect(img, 26, 9, 44, 43, Color(0.8, 0.77, 0.72))
			_stone_lines(img, 26, 9, 44, 43, Color(0.6, 0.57, 0.52))
			_crenel(img, 26, 9, 44, Color(0.8, 0.77, 0.72))
			Painter.rect(img, 3, 22, 20, 44, dark)
			Painter.rect(img, 4, 23, 18, 43, Color(0.68, 0.66, 0.62))
			Painter.rect(img, 73, 22, 20, 44, dark)
			Painter.rect(img, 74, 23, 18, 43, Color(0.68, 0.66, 0.62))
			_crenel(img, 4, 23, 18, Color(0.68, 0.66, 0.62))
			_crenel(img, 74, 23, 18, Color(0.68, 0.66, 0.62))
			Painter.rect(img, 38, 62, 20, 29, dark)
			Painter.disc(img, 48, 62, 10, dark)
			Painter.rect(img, 40, 64, 16, 27, Color(0.3, 0.2, 0.11))
			Painter.disc(img, 48, 64, 8, Color(0.3, 0.2, 0.11))
			Painter.rect(img, 44, 26, 8, 12, Color(0.2, 0.2, 0.25))

func _paint_building_team(img: Image, type: String, px: int, c: Color) -> void:
	var d := Painter.shade(c, 0.55)
	match type:
		"muralla", "puerta":
			Painter.rect(img, 31, 2, 2, 16, Color(0.2, 0.15, 0.1))
			Painter.tri(img, 33, 2, 44, 6, 33, 11, c)
		"casa":
			Painter.rect(img, 51, 6, 2, 22, Color(0.2, 0.15, 0.1))
			Painter.tri(img, 53, 6, 62, 10, 53, 15, c)
		"almacen":
			Painter.rect(img, 6, 26, 52, 4, c)
			Painter.rect(img, 6, 29, 52, 1, d)
		"cuartel":
			Painter.rect(img, 10, 42, 9, 28, c)
			Painter.tri(img, 10, 70, 19, 70, 14.5, 64, Color(0, 0, 0, 0))
			Painter.rect(img, 77, 42, 9, 28, c)
			Painter.rect(img, 10, 42, 9, 2, d)
			Painter.rect(img, 77, 42, 9, 2, d)
		"arqueria":
			Painter.rect(img, 10, 42, 9, 28, c)
			Painter.rect(img, 77, 42, 9, 28, c)
			Painter.rect(img, 10, 42, 9, 2, d)
			Painter.rect(img, 77, 42, 9, 2, d)
		"establo":
			Painter.rect(img, 10, 46, 9, 28, c)
			Painter.rect(img, 77, 46, 9, 28, c)
			Painter.rect(img, 10, 46, 9, 2, d)
			Painter.rect(img, 77, 46, 9, 2, d)
		"torre":
			Painter.rect(img, 31, 0, 2, 14, Color(0.2, 0.15, 0.1))
			Painter.tri(img, 33, 1, 46, 5, 33, 10, c)
			Painter.rect(img, 18, 44, 28, 3, c)
		"centro":
			Painter.rect(img, 47, 0, 2, 12, Color(0.2, 0.15, 0.1))
			Painter.tri(img, 49, 1, 64, 5, 49, 11, c)
			Painter.rect(img, 6, 6, 2, 17, Color(0.2, 0.15, 0.1))
			Painter.tri(img, 8, 6, 20, 10, 8, 15, c)
			Painter.rect(img, 88, 6, 2, 17, Color(0.2, 0.15, 0.1))
			Painter.tri(img, 90, 6, 90, 15, 78, 10, c)
			Painter.rect(img, 6, 90, 84, 0, c)
			Painter.rect(img, 30, 52, 36, 5, c)
			Painter.rect(img, 30, 56, 36, 1, d)

# ------------------------------------------------------------------ recursos

func _build_resources() -> void:
	var atlas := _new_img(32 * 8, 32)
	for v in 3:
		var t := _new_img(32, 32)
		_paint_tree(t, v)
		atlas.blit_rect(t, Rect2i(0, 0, 32, 32), Vector2i(v * 32, 0))
	var g := _new_img(32, 32)
	_paint_gold(g)
	atlas.blit_rect(g, Rect2i(0, 0, 32, 32), Vector2i(3 * 32, 0))
	var b := _new_img(32, 32)
	_paint_berry(b)
	atlas.blit_rect(b, Rect2i(0, 0, 32, 32), Vector2i(4 * 32, 0))
	for v in 2:
		var f := _new_img(32, 32)
		_paint_fish(f, v)
		atlas.blit_rect(f, Rect2i(0, 0, 32, 32), Vector2i((5 + v) * 32, 0))
	res_atlas = ImageTexture.create_from_image(atlas)

func _paint_tree(img: Image, v: int) -> void:
	Painter.ellipse(img, 16, 27, 10, 3.2, Color(0, 0, 0, 0.25))
	if v == 2:
		# conífera
		Painter.rect(img, 14.5, 22, 3, 7, Color(0.36, 0.24, 0.12))
		Painter.tri(img, 16, 2, 5, 17, 27, 17, Color(0.1, 0.34, 0.2))
		Painter.tri(img, 16, 8, 4, 24, 28, 24, Color(0.13, 0.42, 0.25))
		Painter.tri(img, 16, 6, 11, 14, 16, 14, Color(0.2, 0.52, 0.32))
		return
	var dk := Color(0.12, 0.38, 0.17) if v == 0 else Color(0.18, 0.42, 0.14)
	Painter.rect(img, 14, 19, 4, 10, Color(0.38, 0.25, 0.12))
	Painter.disc(img, 16, 14, 12, Color(0.05, 0.16, 0.07, 0.9))
	Painter.disc(img, 16, 14, 11, dk)
	Painter.disc(img, 12.5, 11.5, 7, Painter.shade(dk, 1.25))
	Painter.disc(img, 19.5, 10.5, 5.5, Painter.shade(dk, 1.45))
	Painter.disc(img, 18, 17, 5, Painter.shade(dk, 0.85))

func _paint_gold(img: Image) -> void:
	Painter.ellipse(img, 16, 27, 12, 3.4, Color(0, 0, 0, 0.28))
	Painter.disc(img, 16, 20, 12, Color(0.1, 0.1, 0.11))
	Painter.disc(img, 16, 20, 11, Color(0.46, 0.46, 0.5))
	Painter.disc(img, 11, 17, 4.8, Color(0.98, 0.8, 0.14))
	Painter.disc(img, 21, 14, 5.4, Color(1.0, 0.84, 0.2))
	Painter.disc(img, 16, 23, 4.6, Color(0.92, 0.72, 0.1))
	Painter.disc(img, 19.5, 12, 1.8, Color(1, 0.97, 0.7))
	Painter.disc(img, 9.5, 15.5, 1.5, Color(1, 0.97, 0.7))

func _paint_berry(img: Image) -> void:
	Painter.ellipse(img, 16, 27, 12, 3.2, Color(0, 0, 0, 0.25))
	Painter.disc(img, 16, 19, 11.5, Color(0.07, 0.2, 0.08))
	Painter.disc(img, 16, 19, 10.5, Color(0.2, 0.5, 0.2))
	Painter.disc(img, 9, 21, 7, Color(0.24, 0.56, 0.22))
	Painter.disc(img, 23, 21, 7, Color(0.18, 0.46, 0.18))
	for p in [Vector2(11, 15), Vector2(19, 13), Vector2(23, 20), Vector2(14, 22), Vector2(8, 22), Vector2(20, 24), Vector2(16, 18)]:
		Painter.disc(img, p.x, p.y, 2.0, Color(0.85, 0.12, 0.18))
		Painter.disc(img, p.x - 0.5, p.y - 0.6, 0.7, Color(1, 0.7, 0.7))

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
