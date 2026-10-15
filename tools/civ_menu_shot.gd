extends Node
## Captura del panel de elección de civilización del menú. Uso: ... res://tools/civ_menu_shot.tscn -- out=/tmp/civ_menu.png
func _ready() -> void:
	var out := "/tmp/civ_menu.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	Settings.ensure_loaded()
	Settings.set_profile(1, get_window())
	Settings.civ = "vikingos"
	var m := MenuScreen.new()
	add_child(m)
	await get_tree().create_timer(0.6).timeout
	(m._civ_panel as MenuScreen.CivPanel).open()
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
