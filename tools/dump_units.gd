extends SceneTree
## Dibuja la hoja de cada tipo de unidad (equipo 0 y 1) en /tmp/units_<tipo>.png para revisarla a ojo.
func _init() -> void:
	var types: Array = []
	var team_c := [Color("2f6fdc"), Color("d6392f")]
	for a in OS.get_cmdline_user_args():
		types.append(a)
	if types.is_empty():
		types = ["aldeano"]
	for type in types:
		var t0 := Time.get_ticks_msec()
		var sheet := ArtUnits.build_sheet(type)
		print(type, " hoja ", sheet.get_size(), " en ", Time.get_ticks_msec() - t0, " ms")
		var cp := ArtUnits.cell_px(type)
		var n: int = ArtUnits.CELLS[type][5]
		var out := Image.create(cp.x * n + 8, cp.y * 2 + 12, false, Image.FORMAT_RGBA8)
		out.fill(Color(0.40, 0.58, 0.30) if type.begins_with("barco") == false and type != "galera" and type != "galeon" else Color(0.18, 0.40, 0.62))
		for team in 1:
			for f in n:
				var back := sheet.get_region(ArtUnits.frame_rect(type, f, 0))
				var tm := sheet.get_region(ArtUnits.frame_rect(type, f, 1))
				var fr := sheet.get_region(ArtUnits.frame_rect(type, f, 2))
				var tc: Color = team_c[team]
				for y in tm.get_height():
					for x in tm.get_width():
						var p := tm.get_pixel(x, y)
						if p.a > 0.0:
							tm.set_pixel(x, y, Color(p.r * tc.r * 1.15, p.g * tc.g * 1.15, p.b * tc.b * 1.15, p.a))
				var dst := Vector2i(4 + f * cp.x, 4 + team * (cp.y + 4))
				out.blend_rect(back, Rect2i(0, 0, cp.x, cp.y), dst)
				out.blend_rect(tm, Rect2i(0, 0, cp.x, cp.y), dst)
				out.blend_rect(fr, Rect2i(0, 0, cp.x, cp.y), dst)
		# ampliar 2x para verlo
		out.resize(out.get_width() * 2, out.get_height() * 2, Image.INTERPOLATE_NEAREST)
		out.save_png("/tmp/units_%s.png" % type)
	quit()
