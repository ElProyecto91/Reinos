extends Node
## Guardar y continuar con la interfaz real: pausa guarda, el menú ofrece Continuar, la carga
## restaura mundo, niebla y cámara y arranca en pausa, ganar/perder borra, un archivo roto no bloquea.
var fails := 0
var game: Game
var _failed_signal := false

func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (("  " + extra) if extra != "" else ""))
	if not ok:
		fails += 1

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func wait_ready(g: Game, secs: float = 60.0) -> bool:
	var t_end := Time.get_ticks_msec() + int(secs * 1000.0)
	while g.load_state != 3 and g.load_state >= 0 and Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
	return g.load_state == 3

func explored_count(g: Game) -> int:
	var n := 0
	for v in g.fog.state:
		if v >= 1:
			n += 1
	return n

func _ready() -> void:
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.apply_display(get_window())
	_run()

func _run() -> void:
	SaveGame.delete()
	var cfg := {"size": 128, "seed": 7, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)
	check("la partida nueva carga", await wait_ready(game))
	await frames(3)
	var sim := game.sim
	game.hud.hide_pause()
	check("sin partida guardada al empezar", not SaveGame.has_save())
	# jugar un rato (la IA rival avanza; el humano no hace nada) y mover la cámara
	for i in 2400:
		sim.step()
	game.fog.update(sim, game.human)
	game.cam_pos = sim.tile_center(sim.players[game.human].start_tile) + Vector2(300, 220)
	game.zoom = 1.4
	game.speed = 2.0
	game.hud.hide_pause()
	game.paused = true      # la cámara se ajusta a los límites en el siguiente fotograma
	await frames(4)
	var t0 := sim.time
	var pop0: int = sim.players[game.human].pop
	var res0: Dictionary = (sim.players[game.human].res as Dictionary).duplicate()
	var nb0 := sim.buildings.size()
	var nu0 := sim.units.size()
	var ex0 := explored_count(game)
	var cam0 := game.cam_pos
	game.hud.show_pause()
	await frames(2)
	check("pausar guarda la partida", SaveGame.has_save() and game.last_save_ok)
	check("el título de pausa avisa de que se guardó", game.hud._pause_title.text.contains("guardada"), game.hud._pause_title.text)
	var meta := SaveGame.meta()
	check("ficha con el tiempo de juego", absf(float(meta.get("time", -1.0)) - t0) < 0.5, str(meta.get("time")))
	game.queue_free()
	await frames(4)
	# --- el menú ofrece continuar
	var m := MenuScreen.new()
	add_child(m)
	await frames(3)
	check("el menú muestra Continuar", m._continue.visible and m._continue.text == Lang.t("menu_continue"))
	check("el botón Continuar enseña el tiempo jugado", m._continue.sub.begins_with("%d:" % int(t0 / 60.0)), m._continue.sub)
	check("el botón de jugar pasa a «Nueva partida»", m._play.text == Lang.t("menu_new"))
	var started := [false]
	m.play_pressed.connect(func(_c: Dictionary) -> void: started[0] = true)
	m._on_play()
	check("empezar de nuevo pide confirmación", m._play.text == Lang.t("menu_new_confirm") and not started[0])
	m.queue_free()
	await frames(3)
	# --- cargar
	game = Game.new()
	add_child(game)
	game.start_load()
	check("la partida guardada carga", await wait_ready(game))
	await frames(3)
	sim = game.sim
	check("mismo tiempo de juego", absf(sim.time - t0) < 0.01, "%.1f vs %.1f" % [sim.time, t0])
	check("misma población", sim.players[game.human].pop == pop0)
	check("mismos recursos", sim.players[game.human].res == res0)
	check("mismos edificios y unidades", sim.buildings.size() == nb0 and sim.units.size() == nu0, "%d/%d vs %d/%d" % [sim.buildings.size(), sim.units.size(), nb0, nu0])
	check("misma niebla explorada", explored_count(game) == ex0, "%d vs %d" % [explored_count(game), ex0])
	check("misma cámara y zoom", game.cam_pos.distance_to(cam0) < 1.0 and is_equal_approx(game.zoom, 1.4), "%s z=%.2f" % [str(game.cam_pos), game.zoom])
	check("misma velocidad", is_equal_approx(game.speed, 2.0))
	check("la partida cargada empieza en pausa", game.paused and game.hud.pause_ui.visible)
	var t1 := sim.time
	await get_tree().create_timer(0.6).timeout
	check("en pausa no avanza el tiempo", sim.time == t1)
	game.hud.hide_pause()
	await get_tree().create_timer(1.5).timeout
	check("al reanudar avanza el tiempo", sim.time > t1 + 0.5, "%.1f -> %.1f" % [t1, sim.time])
	# --- los sprites de recursos coinciden con la simulación (los árboles talados no reaparecen)
	var depleted_ok := true
	for i in sim.W * sim.H:
		if sim.rtype[i] == 0 and game.view.res_name_at(Vector2i(i % sim.W, i / sim.W)) != "":
			depleted_ok = false
			break
	check("sin recursos fantasma dibujados", depleted_ok)
	# --- guardado periódico en otro hilo
	game._autosave_t = 0.0
	await frames(3)
	SaveGame.wait_idle()
	var meta2 := SaveGame.meta()
	check("el guardado periódico actualiza la ficha", float(meta2.get("time", 0.0)) > t1 + 0.4, str(meta2.get("time")))
	# --- terminar la partida borra el guardado
	sim.game_over = true
	game.ui_exit()
	check("terminar la partida borra el guardado", not SaveGame.has_save())
	game.queue_free()
	await frames(3)
	# --- un archivo roto no bloquea
	var f := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	f.store_string("no es una partida")
	f = null
	var mf := FileAccess.open(SaveGame.META, FileAccess.WRITE)
	mf.store_string(JSON.stringify({"format": SaveGame.FORMAT, "time": 5.0, "size": 128, "rivals": 1}))
	mf = null
	game = Game.new()
	add_child(game)
	game.load_failed.connect(func() -> void: _failed_signal = true)
	game.start_load()
	var t_end := Time.get_ticks_msec() + 20000
	while not _failed_signal and Time.get_ticks_msec() < t_end:
		await get_tree().process_frame
	check("un archivo roto avisa en vez de colgarse", _failed_signal)
	game.queue_free()
	SaveGame.delete()
	print("DONE fails=", fails)
	get_tree().quit()
