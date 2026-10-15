extends SceneTree
## Dibuja las hojas de todas las unidades y las guarda como PNG en res://art/units.
## Uso: godot --headless --path . --script res://tools/bake_units.gd   (y después --import)
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/units"))
	var total := 0
	for type in ArtUnits.CELLS:
		var t0 := Time.get_ticks_msec()
		var sheet := ArtUnits.build_sheet(type)
		var path := ProjectSettings.globalize_path("res://art/units/%s.png" % type)
		sheet.save_png(path)
		var sz := FileAccess.get_file_as_bytes(path).size()
		total += sz
		print("%-18s %4dx%-4d %7d bytes  %d ms" % [type, sheet.get_width(), sheet.get_height(), sz, Time.get_ticks_msec() - t0])
	print("total PNG: ", total / 1024, " KB")
	quit()
