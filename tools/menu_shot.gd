extends Node
## Captura del menú en el perfil indicado (arg: perfil=0|1|2) para revisar el aspecto del escalado.
func _ready() -> void:
	var prof := 1
	var out := "/tmp/menu"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("perfil="):
			prof = int(a.substr(7))
		if a.begins_with("out="):
			out = a.substr(4)
	Settings.ensure_loaded()
	Settings.set_profile(prof, get_window())
	var m := MenuScreen.new()
	add_child(m)
	await get_tree().create_timer(0.8).timeout
	var img := get_viewport().get_texture().get_image()
	print("VIEWPORT ", img.get_size(), " window ", get_window().size)
	img.save_png(out + ".png")
	get_tree().quit()
