extends Node
## Granjas, reunión, atacar-mover, subir de edad y cola de entrenamiento desde la interfaz.
var game: Game
var fails := 0
var _started := false

func _ready() -> void:
	var cfg := {"size": 128, "seed": 11, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 0, "name": "Rojo"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)

func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1

func touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = idx
	t.position = pos
	t.pressed = pressed
	Input.parse_input_event(t)

func tap(sp: Vector2) -> void:
	touch(0, sp, true)
	await get_tree().process_frame
	touch(0, sp, false)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("/tmp/ui4_%s.png" % name)

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func slot_with(text: String) -> UiButton:
	for b in game.hud.grid:
		if b.visible and b.text == text:
			return b
	return null

func _run() -> void:
	await frames(5)
	var sim := game.sim
	var h := game.human
	var hud := game.hud
	var p: Player = sim.players[h]
	var tc: Ent = null
	for b in sim.buildings:
		if b.owner == h:
			tc = b
	p.res = {"food": 2000, "wood": 2000, "gold": 2000}
	var vl: Array = []
	for u in sim.units:
		if u.owner == h:
			vl.append(u)
	game.select_ents(vl.slice(0, 3))
	await frames(4)
	# granja: Construir -> Granja -> tocar 2 casillas -> Listo
	await tap(hud.grid[0].get_global_rect().get_center())
	var farm := slot_with(Lang.t("b_granja"))
	check("farm slot", farm != null)
	await tap(farm.get_global_rect().get_center())
	check("placing farm", game.placing_type == "granja")
	var s0: Vector2i = p.start_tile
	var spots: Array = []
	for dy in range(3, 8):
		for dx in range(-4, 5):
			var t := s0 + Vector2i(dx, dy)
			if sim.can_place_farm(t) and spots.size() < 2 and (spots.is_empty() or t.distance_to(spots[0]) > 1.5):
				spots.append(t)
	for t in spots:
		await tap(game.world_to_screen(sim.tile_center(t)))
	await frames(3)
	var farms := 0
	for i in sim.rtype.size():
		if sim.rtype[i] == Defs.R_FARM:
			farms += 1
	check("2 farms planted by tapping", farms == 2)
	check("farm tiles tracked", game.farm_tiles.size() == 2)
	print("wood after farms ", p.res["wood"])
	await tap(hud.place_ok.get_global_rect().get_center())
	check("farm mode ended with Listo", game.placing_type == "")
	await get_tree().create_timer(0.5).timeout
	shot("farms")
	# TC: reunión
	game.select_ents([tc])
	await frames(4)
	await tap(slot_with(Lang.t("rally")).get_global_rect().get_center())
	check("rally mode", game.rally_mode)
	var rt := s0 + Vector2i(6, -3)
	await tap(game.world_to_screen(sim.tile_center(rt)))
	check("rally set", tc.rally.x >= 0 and not game.rally_mode)
	# entrenar 3 y cancelar uno
	for i in 3:
		await tap(hud.grid[0].get_global_rect().get_center())
	check("3 queued", tc.queue.size() == 3)
	var food_before: int = p.res["food"]
	await tap(hud.info.qbtns[2].get_global_rect().get_center())
	check("queue cancel refunds", tc.queue.size() == 2 and int(p.res["food"]) == food_before + 50)
	shot("queue")
	# subir de edad
	var age_btn := slot_with(Lang.t("age_up"))
	check("age up button", age_btn != null)
	await tap(age_btn.get_global_rect().get_center())
	check("aging started", p.aging)
	game.speed = 3.0
	await get_tree().create_timer(16.0).timeout
	check("reached feudal", p.age == 1)
	# cuartel + arquería: construir con UI y entrenar arqueros directamente por sim para probar atacar-mover
	var archers: Array = []
	for i in 5:
		archers.append(sim._spawn_unit("arquero", h, sim.nearest_free_tile(s0 + Vector2i(-3 + i, 4), 5)))
	game.select_ents(archers)
	await frames(4)
	var am := slot_with(Lang.t("attack_move"))
	check("attack-move button", am != null)
	await tap(am.get_global_rect().get_center())
	check("amove mode", game.amove_mode)
	await tap(game.world_to_screen(sim.tile_center(s0 + Vector2i(10, -4))))
	check("amove issued", archers[0].amove and not game.amove_mode)
	await get_tree().create_timer(2.0).timeout
	# detener
	await tap(slot_with(Lang.t("stop")).get_global_rect().get_center())
	await frames(4)
	check("stop issued", archers[0].state == Sim.S_IDLE or archers[0].state == Sim.S_MOVE)
	# pausa y reanudar con el botón de menú
	await tap(hud.menu_btn.get_global_rect().get_center())
	check("paused", game.paused and hud.pause_ui.visible)
	await tap((hud._pause_btns["resume"] as UiButton).get_global_rect().get_center())
	check("resumed", not game.paused)
	# velocidad
	await tap(hud.speed_btn.get_global_rect().get_center())
	check("speed cycle", is_equal_approx(game.speed, 1.0))
	game.ui_goto_base()
	await frames(5)
	shot("final")
	print("RESULT fails=", fails)
	get_tree().quit()
