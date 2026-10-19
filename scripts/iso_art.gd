class_name IsoArt
extends RefCounted
## Atlas de sprites isométricos (art/iso/atlas_N.png + mask_N.png + atlas.json, ver tools/iso/iso_atlas.py).
## Cada sprite tiene un ancla (píxel del PNG donde cae el pie / centro de la huella) y, si lleva partes de equipo, máscara.
## Los edificios de cada civilización viven en su propio paquete (civ_<id>.json + atlas_<id>_N.png): se cargan con `ensure_civ`
## sólo para las civilizaciones que juegan la partida. Sus sprites se llaman «<civ>__<tipo>» (ver `civ_sprite`).

const DIR := "res://art/iso/"
## Píxeles de pantalla (zoom 1) por píxel de sprite: los sprites se hornean al doble de resolución (casilla de 128 px de ancho).
const SPRITE_SCALE := 0.5
## Edificios con arquitectura propia de cada civilización (los mismos que IsoCivs.TYPES + murallas, puerta y puerto en las 4 orientaciones).
const CIV_TYPES := ["casa", "centro", "almacen", "cuartel", "arqueria", "establo", "taller", "puerto", "torre", "monasterio", "castillo", "herreria", "mercado"]
## Civilización por defecto: partidas antiguas, pruebas y civilizaciones sin paquete de sprites.
const DEFAULT_CIV := "castellanos"

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
var _shader: Shader
var _civ_loaded: Dictionary = {}      # civilización -> ¿paquete cargado?
var _smoke: Dictionary = {}           # civilización -> {tipo de edificio: [Vector2 (px de pantalla desde el centro de la huella)]}
var _glow := 0.0                      # brillo de ventanas vigente (se aplica también a los paquetes que se carguen después)
var _glow_col := Vector3.ONE

func _init() -> void:
	_shader = load("res://shaders/iso_sprite.gdshader") as Shader
	if not _load_pack(DIR + "atlas.json"):
		return
	_load_icons()

## Añade las hojas y sprites de un paquete (atlas.json o civ_<id>.json). Las hojas se numeran a continuación de las ya cargadas.
func _load_pack(jp: String) -> bool:
	var text := FileAccess.get_file_as_string(jp)
	var data: Variant = JSON.parse_string(text)
	if not (data is Dictionary):
		push_error("IsoArt: no se pudo leer " + jp)
		return false
	var first := sheets.size()
	var sp: Dictionary = (data as Dictionary)["sprites"]
	for nm in sp:
		var r: Array = sp[nm]
		rects[nm] = [first + int(r[0]), Rect2(float(r[1]), float(r[2]), float(r[3]), float(r[4]))]
		anchors[nm] = Vector2(float(r[5]), float(r[6]))
	var hh: Variant = (data as Dictionary).get("hit", {})
	if hh is Dictionary:
		_hit_raw.merge(hh as Dictionary, true)
	for s: Array in (data as Dictionary)["sheets"]:
		var img := (load(DIR + String(s[0])) as Texture2D).get_image()
		img.generate_mipmaps()
		var t := ImageTexture.create_from_image(img)
		var mimg := (load(DIR + String(s[1])) as Texture2D).get_image()
		if mimg.get_format() != Image.FORMAT_RG8:
			mimg.convert(Image.FORMAT_RG8)
		mimg.generate_mipmaps()
		var mt := ImageTexture.create_from_image(mimg)
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.set_shader_parameter("mask_tex", mt)
		m.set_shader_parameter("glow", _glow)
		m.set_shader_parameter("glow_col", _glow_col)
		sheets.append(t)
		masks.append(mt)
		mats.append(m)
	return true

## Nombre del sprite de un edificio de una civilización («<civ>__<tipo>»; puerto: «<civ>__puerto_<lado>»; murallas: «<civ>__muralla_poste»,
## «<civ>__muralla_a0..7», «<civ>__puerta_x», «<civ>__puerta_z»).
static func civ_sprite(civ: String, type: String) -> String:
	return civ + "__" + type

## ¿Existe el paquete de sprites de esa civilización (cargado o por cargar)?
func has_civ_pack(civ: String) -> bool:
	if civ == "":
		return false
	return _civ_loaded.get(civ, false) or FileAccess.file_exists(DIR + "civ_%s.json" % civ)

## Carga el paquete de una civilización si aún no lo está. Devuelve false si no existe (el juego usa entonces DEFAULT_CIV).
func ensure_civ(civ: String) -> bool:
	if civ == "":
		return false
	if _civ_loaded.has(civ):
		return _civ_loaded[civ]
	var ok := false
	if FileAccess.file_exists(DIR + "civ_%s.json" % civ):
		ok = _load_pack(DIR + "civ_%s.json" % civ)
		if ok:
			_load_civ_meta(civ)
	_civ_loaded[civ] = ok
	return ok

## Civilización cuyos sprites se usan para `civ` (ella misma si tiene paquete; si no, DEFAULT_CIV). Carga el paquete.
func resolve_civ(civ: String) -> String:
	if ensure_civ(civ):
		return civ
	ensure_civ(DEFAULT_CIV)
	return DEFAULT_CIV

func _load_civ_meta(civ: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "civ_%s_meta.json" % civ))
	var out := {}
	if data is Dictionary:
		var sm: Variant = (data as Dictionary).get("smoke", {})
		if sm is Dictionary:
			for t in sm:
				var pts: Array = []
				for q: Array in (sm[t] as Array):
					pts.append(Vector2(float(q[0]), float(q[1])))
				out[t] = pts
	_smoke[civ] = out

## Puntos de humo (px de pantalla respecto al centro de la huella) de un tipo de edificio de una civilización; vacío si no echa humo.
func smoke_points(civ: String, type: String) -> Array:
	var m: Dictionary = _smoke.get(civ, {})
	return m.get(type, [])

## Brillo de las ventanas: `night` 0 día .. 1 noche; `tint` es el tinte global del lienzo (el brillo se compensa para que no se apague).
func set_night(night: float, tint: Color) -> void:
	var warm := Color(1.0, 0.80, 0.42)
	var g := Vector3(warm.r / maxf(tint.r, 0.35), warm.g / maxf(tint.g, 0.35), warm.b / maxf(tint.b, 0.35))
	var glow := smoothstep(0.12, 0.55, night)
	_glow = glow
	_glow_col = g
	for m in mats:
		m.set_shader_parameter("glow", glow)
		m.set_shader_parameter("glow_col", g)

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

func has_icon(name: String) -> bool:
	return _icon_rects.has(name)

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
