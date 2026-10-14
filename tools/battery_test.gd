extends Node
## Comprueba el modo ahorro de batería: fps, reposo en pausa, auto-pausa, ambiente y perfiles.

var game: Game
var fails := 0
var out := "/tmp/bat"

func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.auto_pause = true
	Settings.apply_display(get_window())
	var cfg := {"size": 128, "seed": 7, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)
	_run()

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _run() -> void:
	while game.load_state != 3:
		await get_tree().process_frame
	await frames(10)
	# 1. en marcha: fps del perfil, pantalla encendida
	check("playing: max_fps = perfil Normal (30)", Engine.max_fps == 30)
	check("low processor mode on", OS.low_processor_usage_mode)
	check("viewport scaling in Normal", get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT)
	var n0 := WorldLayer.prof_n
	await get_tree().create_timer(1.0).timeout
	var dn := WorldLayer.prof_n - n0
	print("INFO entity redraws/s while playing: ", dn)
	check("playing: entities redrawn every frame (>=15/s)", dn >= 15)
	# 2. pausa: reposo
	game.hud.show_pause()
	await frames(5)
	check("paused: max_fps = IDLE", Engine.max_fps == Settings.IDLE_FPS)
	var amb_all_paused := true
	for k in game.audio._amb:
		if not (game.audio._amb[k] as AudioStreamPlayer).stream_paused:
			amb_all_paused = false
	check("paused: ambient streams stopped", amb_all_paused)
	n0 = WorldLayer.prof_n
	await get_tree().create_timer(1.0).timeout
	dn = WorldLayer.prof_n - n0
	print("INFO entity redraws/s while paused: ", dn)
	check("paused: entities not redrawn (<=2/s)", dn <= 2)
	# 3. cambiar de perfil desde la pausa
	game.hud._cycle_perf()   # Normal -> Alta
	await frames(4)
	check("profile Alta, native scaling", Settings.profile == 2 and get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS)
	game.hud._cycle_perf()   # Alta -> Ahorro
	game.hud._cycle_perf()   # Ahorro -> Normal ... (ciclo de 3)
	game.hud._cycle_perf()
	await frames(2)
	check("profile cycles back", Settings.profile == 2 or Settings.profile == 0 or Settings.profile == 1)
	Settings.set_profile(0, get_window())
	game.reset_run_mode()
	game.hud.hide_pause()
	await frames(6)
	check("resumed in Ahorro: max_fps 20", Engine.max_fps == 20)
	check("resumed: ambient playing again", not (game.audio._amb["wind"] as AudioStreamPlayer).stream_paused)
	# 4. auto-pausa por inactividad
	check("not paused before idle", not game.paused)
	game._last_input_ms = Time.get_ticks_msec() - 100000   # 100 s sin tocar; límite de Ahorro = 90 s
	await frames(4)
	check("auto-pause after idle", game.paused and game.hud.pause_ui.visible)
	check("auto-pause title", game.hud._pause_title.text == Lang.t("pause_title_auto"))
	# 5. desactivar auto-pausa
	game.hud._toggle_auto()
	game.hud.hide_pause()
	await frames(4)
	game._last_input_ms = Time.get_ticks_msec() - 400000
	await frames(4)
	check("auto-pause off: keeps playing", not game.paused)
	# 6. perfil Normal otra vez y captura
	Settings.set_profile(1, get_window())
	Settings.auto_pause = true
	Settings.save()
	game.hud.show_pause()
	await frames(4)
	get_viewport().get_texture().get_image().save_png(out + "_pause.png")
	print("DONE fails=", fails)
	get_tree().quit()
