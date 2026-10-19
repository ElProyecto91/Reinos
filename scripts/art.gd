class_name Art
extends RefCounted
## Arte del juego. Los sprites del mundo (edificios, unidades, árboles…) son isométricos y vienen horneados de modelos 3D
## (tools/iso, ver README): `iso` es el atlas. Aquí viven además las texturas pequeñas pintadas por código (sombra,
## humo, iconos de carga) y los iconos de los menús, que se tiñen con el color del equipo al pedirlos.

var iso: IsoArt
var team_mod: Array[Color] = []        # color con el que se tiñen las partes de equipo de los sprites (modulate)
var shadow_tex: ImageTexture           # elipse difusa bajo las unidades
var puff_tex: ImageTexture             # disco blanco suave (humo, brillos): se tiñe al dibujar y se agrupa en una sola llamada
var carry_atlas: ImageTexture          # iconos de carga en fila: oro, comida, madera (pintados a 2x)
var carry_cell := 0                    # lado en píxeles de cada icono del atlas
var _icons: Dictionary = {}
const CARRY_SS := 2.0                  # factor de supersampling de los iconos de carga
const CARRY_HALF := 14.0               # mitad del lado del icono en píxeles de mundo (con k = 1)

func build() -> void:
	for c: Color in Defs.PLAYER_COLORS:
		# ligeramente menos saturado que el color de jugador: la tela teñida no es tan chillona como el icono del HUD
		var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
		var m := Color(lerpf(c.r, lum, 0.10), lerpf(c.g, lum, 0.10), lerpf(c.b, lum, 0.10), 1.0)
		team_mod.append(Color(minf(1.0, m.r * 1.12), minf(1.0, m.g * 1.12), minf(1.0, m.b * 1.12), 1.0))
	iso = IsoArt.new()
	_build_misc()

func _new_img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img

# ------------------------------------------------------------------ iconos de menús

## Icono cuadrado de una unidad con el color de un equipo, para menús e informes.
func unit_icon(type: String, team: int) -> Texture2D:
	return _icon("ic_" + type, team)

## Icono cuadrado de un edificio con el color de un equipo. Los edificios con arquitectura propia (IsoArt.CIV_TYPES, muralla y puerta)
## usan el icono de la civilización `civ` ("" o sin icono: la de por defecto); la granja y la mina son iguales para todos.
func building_icon(type: String, team: int, civ: String = "") -> Texture2D:
	if IsoArt.CIV_TYPES.has(type) or type == "muralla" or type == "puerta":
		var nm := "ic_%s__%s" % [civ, type]
		if civ == "" or not iso.has_icon(nm):
			nm = "ic_%s__%s" % [IsoArt.DEFAULT_CIV, type]
		return _icon(nm, team)
	return _icon("ic_" + type, team)

func _icon(name: String, team: int) -> Texture2D:
	var key := "%s#%d" % [name, team % 4]
	var t: Texture2D = _icons.get(key)
	if t != null:
		return t
	var img := iso.icon_image(name, team_mod[team % 4])
	if img == null:
		img = _placeholder_icon(Defs.PLAYER_COLORS[team % 4])
	t = ImageTexture.create_from_image(img)
	_icons[key] = t
	return t

func _placeholder_icon(col: Color) -> Image:
	var img := _new_img(64, 64)
	Painter.disc(img, 32, 32, 22, Color(0.1, 0.1, 0.1, 0.8))
	Painter.disc(img, 32, 32, 19, col)
	return img

# ------------------------------------------------------------------ texturas pequeñas

func _build_misc() -> void:
	var sh := _new_img(32, 32)
	# elipse con borde difuso (se escala a cada unidad)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var a := clampf((1.0 - d) / 0.55, 0.0, 1.0)
			if a > 0.0:
				sh.set_pixel(x, y, Color(0, 0, 0, 0.34 * a * a * (3.0 - 2.0 * a)))
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

## Icono de lo que lleva un aldeano o pescador (como textura: una sola llamada de dibujo en lugar de 4-6 por unidad).
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
