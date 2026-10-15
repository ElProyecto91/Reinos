extends SceneTree
## Dibuja edificios sueltos (equipo 0) en /tmp/bld_sheet_<PRE>.png. Uso: PRE=x godot --script ... -- puerto taller [zoom=1.5]
func _init() -> void:
	var art := Art.new()
	art.build()
	var types: Array = []
	var zoom := 1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("zoom="):
			zoom = float(a.substr(5))
		else:
			types.append(a)
	var cell := int(192 * zoom)
	var sheet := Image.create((cell + 8) * types.size() + 8, cell + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.40, 0.58, 0.30))
	var x := 4
	for type in types:
		var im: Image = art.building_tex[type][0].get_image()
		im.clear_mipmaps()
		im.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
		sheet.blend_rect(im, Rect2i(0, 0, cell, cell), Vector2i(x, 4))
		x += cell + 8
	sheet.save_png("/tmp/bld_sheet_" + OS.get_environment("PRE") + ".png")
	quit()
