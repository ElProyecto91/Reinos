extends SceneTree
func _init():
	var t0 := Time.get_ticks_msec()
	var art := Art.new()
	art.build()
	print("art built in ", Time.get_ticks_msec() - t0, " ms")
	var sheet := Image.create(1100, 520, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.35, 0.55, 0.3))
	var x := 10
	for type in ["aldeano", "piquero", "arquero", "jinete"]:
		for team in 4:
			var im: Image = art.unit_tex[type][team].get_image()
			sheet.blend_rect(im, Rect2i(0, 0, 48, 48), Vector2i(x, 10))
			x += 52
	x = 10
	for type in ["casa", "almacen", "torre", "cuartel", "arqueria", "establo", "centro"]:
		var im: Image = art.building_tex[type][0].get_image()
		sheet.blend_rect(im, Rect2i(0, 0, im.get_width(), im.get_height()), Vector2i(x, 70))
		x += im.get_width() + 6
	x = 10
	var ti: Image = art.building_tex["centro"][1].get_image()
	sheet.blend_rect(ti, Rect2i(0, 0, 96, 96), Vector2i(x, 180))
	var ti2: Image = art.building_tex["cuartel"][2].get_image()
	sheet.blend_rect(ti2, Rect2i(0, 0, 96, 96), Vector2i(x + 100, 180))
	var ri: Image = art.res_atlas.get_image()
	var water := Image.create(256, 32, false, Image.FORMAT_RGBA8)
	water.fill(Color(0.2, 0.5, 0.7))
	water.blend_rect(ri, Rect2i(0, 0, 256, 32), Vector2i(0, 0))
	# escala x2 para ver los recursos
	water.resize(512, 64, Image.INTERPOLATE_NEAREST)
	sheet.blend_rect(water, Rect2i(0, 0, 512, 64), Vector2i(10, 290))
	sheet.save_png("/tmp/art_sheet.png")
	quit()
