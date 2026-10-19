class_name IsoArt
extends RefCounted
## Atlas de sprites isométricos (art/iso/atlas_N.png + mask_N.png + atlas.json, ver tools/iso/iso_atlas.py).
## Cada sprite tiene un ancla (píxel del PNG donde cae el pie / centro de la huella) y, si lleva partes de equipo, máscara.

const DIR := "res://art/iso/"
## Píxeles de pantalla (zoom 1) por píxel de sprite: los sprites se hornean al doble de resolución (casilla de 128 px de ancho).
const SPRITE_SCALE := 0.5

var anchors: Dictionary = {}          # nombre -> Vector2 (ancla en píxeles del sprite)
var rects: Dictionary = {}            # nombre -> [hoja, Rect2]
var sheets: Array[ImageTexture] = []
var masks: Array[ImageTexture] = []
var mats: Array[ShaderMaterial] = []  # un material por hoja (cada una lleva su máscara)
var _atex: Dictionary = {}            # nombre -> AtlasTexture
var _hit_raw: Dictionary = {}         # nombre -> [ancho, alto, hex] de la máscara de toque (edificios)
var _hit: Dictionary = {}             # nombre -> [ancho, alto, bytes por fila, PackedByteArray] ya decodificada
const HIT_CELL := 4
var _noteam_mats: Array[ShaderMaterial] = []

func _init() -> void:
	var jp := DIR + "atlas.json"
	var text := FileAccess.get_file_as_string(jp)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		push_error("IsoArt: no se pudo leer " + jp)
		return
	var sp: Dictionary = (data as Dictionary)["sprites"]
	for nm in sp:
		var r: Array = sp[nm]
		rects[nm] = [int(r[0]), Rect2(float(r[1]), float(r[2]), float(r[3]), float(r[4]))]
		anchors[nm] = Vector2(float(r[5]), float(r[6]))
	var hh: Variant = (data as Dictionary).get("hit", {})
	if hh is Dictionary:
		_hit_raw = hh
	var shader := load("res://shaders/iso_sprite.gdshader") as Shader
	for s: Array in (data as Dictionary)["sheets"]:
		var img := (load(DIR + String(s[0])) as Texture2D).get_image()
		img.generate_mipmaps()
		var t := ImageTexture.create_from_image(img)
		var mimg := (load(DIR + String(s[1])) as Texture2D).get_image()
		if mimg.get_format() != Image.FORMAT_R8:
			mimg.convert(Image.FORMAT_R8)
		mimg.generate_mipmaps()
		var mt := ImageTexture.create_from_image(mimg)
		var m := ShaderMaterial.new()
		m.shader = shader
		m.set_shader_parameter("mask_tex", mt)
		sheets.append(t)
		masks.append(mt)
		mats.append(m)
	_load_icons()

var _icon_img: Image
var _icon_mask: Image
var _icon_rects: Dictionary = {}

func _load_icons() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "icons.json"))
	if not (data is Dictionary):
		return
	for nm in data:
		var r: Array = data[nm]
		_icon_rects[nm] = Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
	var t1 := load(DIR + "icons.png") as Texture2D
	var t2 := load(DIR + "icons_m.png") as Texture2D
	if t1 == null or t2 == null:
		return
	_icon_img = t1.get_image()
	_icon_img.convert(Image.FORMAT_RGBA8)
	_icon_mask = t2.get_image()
	_icon_mask.convert(Image.FORMAT_R8)

## Icono de menú (imagen pequeña) con las partes de equipo teñidas con `team`; null si no existe.
func icon_image(name: String, team: Color) -> Image:
	if not _icon_rects.has(name) or _icon_img == null:
		return null
	var r: Rect2i = _icon_rects[name]
	var col := _icon_img.get_region(r)
	var mk := _icon_mask.get_region(r)
	var tr := team.r * 1.3333
	var tg := team.g * 1.3333
	var tb := team.b * 1.3333
	for y in r.size.y:
		for x in r.size.x:
			var m := mk.get_pixel(x, y).r
			if m > 0.0:
				var p := col.get_pixel(x, y)
				col.set_pixel(x, y, Color(minf(1.0, p.r * lerpf(1.0, tr, m)), minf(1.0, p.g * lerpf(1.0, tg, m)), minf(1.0, p.b * lerpf(1.0, tb, m)), p.a))
	return col

func has(name: String) -> bool:
	return rects.has(name)

## ¿Hay un píxel opaco del sprite `name` a menos de `tol` celdas (de 4 px de sprite) del punto `p` (en píxeles del sprite, con el
## origen en la esquina del PNG recortado)? Sprites sin máscara: se acepta todo el rectángulo.
func hit_test(name: String, p: Vector2, tol: int = 1) -> bool:
	var m: Array = _hit.get(name, [])
	if m.is_empty():
		var raw: Array = _hit_raw.get(name, [])
		if raw.is_empty():
			var r: Rect2 = (rects[name] as Array)[1]
			return Rect2(Vector2.ZERO, r.size).has_point(p)
		var cw := int(raw[0])
		m = [cw, int(raw[1]), (cw + 7) / 8, String(raw[2]).hex_decode()]
		_hit[name] = m
	var cx := floori(p.x / float(HIT_CELL))
	var cy := floori(p.y / float(HIT_CELL))
	var w: int = m[0]
	var h: int = m[1]
	var rb: int = m[2]
	var bytes: PackedByteArray = m[3]
	for y in range(maxi(cy - tol, 0), mini(cy + tol, h - 1) + 1):
		for x in range(maxi(cx - tol, 0), mini(cx + tol, w - 1) + 1):
			if (bytes[y * rb + (x >> 3)] >> (7 - (x & 7))) & 1 == 1:
				return true
	return false

func tex(name: String) -> AtlasTexture:
	var t: AtlasTexture = _atex.get(name)
	if t != null:
		return t
	var r: Array = rects[name]
	t = AtlasTexture.new()
	t.atlas = sheets[int(r[0])]
	t.region = r[1]
	_atex[name] = t
	return t

func mat_of(name: String) -> ShaderMaterial:
	return mats[sheet_of(name)]

func sheet_of(name: String) -> int:
	return int((rects[name] as Array)[0])

## Sprite colocado con su ancla en `pos` (plano isométrico). `sc` escala extra (unidades, árboles de distinto tamaño); flip = espejo.
func make_sprite(name: String, pos: Vector2, sc: float = 1.0, flip: bool = false) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.centered = false
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.position = pos
	set_frame(sp, name, sc, flip)
	return sp

func set_frame(sp: Sprite2D, name: String, sc: float = 1.0, flip: bool = false) -> void:
	var an: Vector2 = anchors[name]
	sp.texture = tex(name)
	sp.offset = -an
	sp.scale = Vector2(SPRITE_SCALE * sc * (-1.0 if flip else 1.0), SPRITE_SCALE * sc)
	var m := mats[sheet_of(name)]
	if sp.material != m:
		sp.material = m
