extends Node
## Recolectar oro tocando una mina con aldeanos seleccionados (arg: seed=N perfil=0|1|2).
var game: Game
var fails := 0
var _started := false
var seed_v := 7

func _ready() -> void:
	var prof := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			seed_v = int(a.substr(5))
		if a.begins_with("perfil="):
			prof = int(a.substr(7))
	Settings.ensure_loaded()
	Settings.profile = prof
	Settings.apply_display(get_window())
	var cfg := {"size": 128, "seed": seed_v, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 0, "name": "Rojo"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)

func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1

func touch(pos: Vector2, pressed: bool) -> void:
	# Los eventos inyectados se interpretan en píxeles de ventana (como los táctiles reales):
	# con escalado del viewport hay que convertir desde coordenadas de viewport.
	var k := float(get_window().size.x) / get_viewport().get_visible_rect().size.x
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = pos * k
	t.pressed = pressed
	Input.parse_input_event(t)

func tap(sp: Vector2) -> void:
	touch(sp, true)
	await get_tree().process_frame
	touch(sp, false)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var sim := game.sim
	var h := game.human
	var p: Player = sim.players[h]
	var s0: Vector2i = p.start_tile
	print("window ", get_window().size, " viewport ", get_viewport().get_visible_rect().size, " seed ", seed_v)
	# mina de oro explorada más cercana
	var gold := Vector2i(-1, -1)
	var bd := 1e9
	for dy in range(-16, 17):
		for dx in range(-16, 17):
			var t := s0 + Vector2i(dx, dy)
			if sim.in_bounds(t) and sim.rtype[t.y * sim.W + t.x] == Defs.R_GOLD and game.fog.explored_at(t):
				var d := float(dx * dx + dy * dy)
				if d < bd:
					bd = d
					gold = t
	check("explored gold near start", gold.x >= 0)
	if gold.x < 0:
		print("DONE fails=", fails)
		get_tree().quit()
		return
	var vl: Array = []
	for u in sim.units:
		if u.owner == h and u.type == "aldeano":
			vl.append(u)
	game.select_ents(vl.slice(0, 3))
	await get_tree().create_timer(0.3).timeout
	var sp := game.world_to_screen(sim.tile_center(gold))
	print("gold tile ", gold, " screen ", sp, " over_ui ", game.hud.is_over_ui(sp), " res_at ", game._res_at(game.screen_to_world(sp)))
	get_viewport().get_texture().get_image().save_png("/tmp/gold_before.png")
	print("SHOT gold at viewport px ", sp)
	await tap(sp)
	await get_tree().create_timer(0.3).timeout
	var n := 0
	for u in vl.slice(0, 3):
		if u.target_tile == gold and u.state in [Sim.S_GATHER_GO, Sim.S_GATHER, Sim.S_RETURN]:
			n += 1
	check("tap on gold orders gather (3 villagers)", n == 3)
	var g0: int = p.res["gold"]
	game.speed = 3.0
	var saw_text := false
	var shot := false
	var t_end := Time.get_ticks_msec() + 14000
	while Time.get_ticks_msec() < t_end:
		await get_tree().create_timer(0.1).timeout
		for f: Dictionary in game.fx:
			if f["t"] == "text":
				saw_text = true
		if saw_text and not shot:
			shot = true
			await get_tree().create_timer(0.35).timeout
			get_viewport().get_texture().get_image().save_png("/tmp/gold_deposit.png")
	var g1: int = p.res["gold"]
	print("gold ", g0, " -> ", g1)
	check("gold increased", g1 > g0)
	check("deposit shows +N text", saw_text)
	print("DONE fails=", fails)
	get_tree().quit()
