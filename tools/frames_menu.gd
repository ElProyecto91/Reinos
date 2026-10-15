extends Node
## Fotogramas que dibuja el motor en el menú principal (debería ser ~0 si nada cambia).
func _ready() -> void:
	Settings.ensure_loaded()
	Settings.apply_display(get_window())
	Settings.set_playing(false)
	var m := MenuScreen.new()
	add_child(m)
	await get_tree().create_timer(1.0).timeout
	var d0 := Engine.get_frames_drawn()
	var p0 := Engine.get_process_frames()
	await get_tree().create_timer(3.0).timeout
	print("RESULT menú: dibujados %.1f/s, _process %.1f/s (max_fps=%d)" % [(Engine.get_frames_drawn() - d0) / 3.0, (Engine.get_process_frames() - p0) / 3.0, Engine.max_fps])
	get_tree().quit()
