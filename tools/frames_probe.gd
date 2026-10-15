extends Node
## Cuenta cuántos fotogramas dibuja de verdad el motor (no solo cuántas veces se ejecuta _process) en juego, en pausa y en el menú.
## Uso: xvfb-run -a godot --path . res://tools/frames_probe.tscn --rendering-driver opengl3 --resolution 1280x720
var game: Game

func _ready() -> void:
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.apply_display(get_window())
	var cfg := {"size": 128, "seed": 7, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)
	_run()

func measure(label: String, secs: float) -> void:
	var d0 := Engine.get_frames_drawn()
	var p0 := Engine.get_process_frames()
	await get_tree().create_timer(secs).timeout
	var d := Engine.get_frames_drawn() - d0
	var p := Engine.get_process_frames() - p0
	print("RESULT %s: dibujados %.1f/s, _process %.1f/s (max_fps=%d)" % [label, d / secs, p / secs, Engine.max_fps])

func _run() -> void:
	while game.load_state != 3:
		await get_tree().process_frame
	for i in 10:
		await get_tree().process_frame
	await measure("jugando", 3.0)
	game.hud.show_pause()
	for i in 5:
		await get_tree().process_frame
	await measure("pausa", 3.0)
	game.l_sky.visible = false
	for i in 5:
		await get_tree().process_frame
	await measure("pausa sin nubes", 3.0)
	game.l_terrain.material = null
	for i in 5:
		await get_tree().process_frame
	await measure("pausa sin nubes ni terreno-shader", 3.0)
	get_tree().quit()
