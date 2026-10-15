extends SceneTree
## Hoja de arte: edificios (equipo 0 y 1), unidades y recursos. Salida /tmp/art_sheet.png
func _init():
	var t0 := Time.get_ticks_msec()
	var art := Art.new()
	art.build()
	print("art built in ", Time.get_ticks_msec() - t0, " ms")
	var sheet := Image.create(1500, 900, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.38, 0.58, 0.32))
	var x := 10
	var y := 10
	for type in ["casa", "almacen", "torre", "muralla", "puerta"]:
		var im: Image = art.building_tex[type][0].get_image()
		im.decompress() if im.is_compressed() else null
		im.clear_mipmaps()
		sheet.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(x, y))
		x += im.get_width() + 6
	x = 10
	y = 290
	for type in ["centro", "cuartel", "arqueria", "establo"]:
		var im: Image = art.building_tex[type][1 if type == "cuartel" else 0].get_image()
		im.clear_mipmaps()
		sheet.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(x, y))
		x += im.get_width() + 6
	x = 10
	y = 700
	for type in ["aldeano", "piquero", "arquero", "jinete", "galera"]:
		for team in 2:
			var im: Image = art.unit_icon(type, team).get_image()
			im.clear_mipmaps()
			sheet.blend_rect(im, Rect2i(0, 0, 64, 64), Vector2i(x, y))
			x += 68
	var ri: Image = art.res_atlas.get_image()
	ri.clear_mipmaps()
	sheet.blend_rect(ri, Rect2i(0, 0, ri.get_width(), ri.get_height()), Vector2i(500, 700))
	sheet.save_png("/tmp/art_sheet.png")
	quit()
