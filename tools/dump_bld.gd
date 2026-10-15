extends SceneTree
## Dibuja edificios sueltos (equipo 0) en /tmp/bld_<tipo>.png (2x). Uso: -- puerto taller
func _init() -> void:
	var art := Art.new()
	art.build()
	var types: Array = OS.get_cmdline_user_args()
	var sheet := Image.create(100 * types.size() * 2 + 8, 200 + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.40, 0.58, 0.30))
	var x := 4
	for type in types:
		var im: Image = art.building_tex[type][0].get_image()
		im.clear_mipmaps()
		im.resize(192, 192, Image.INTERPOLATE_LANCZOS)
		sheet.blend_rect(im, Rect2i(0, 0, 192, 192), Vector2i(x, 4))
		x += 200
	sheet.save_png("/tmp/bld_sheet.png")
	quit()
