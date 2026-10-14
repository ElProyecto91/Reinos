extends Node
## Prueba de flujos reales de interfaz con toques sintéticos (con comprobaciones PASS/FAIL).

var game: Game
var out := "/tmp/ui2"
var fails := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	var cfg := {"size": 128, "seed": 7, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)

func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1

func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, name])

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

func move_touch(idx: int, a: Vector2, b: Vector2) -> void:
	var m := InputEventScreenDrag.new()
	m.index = idx
	m.position = b
	m.relative = b - a
	Input.parse_input_event(m)

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()
var _started := false

func btn_center(b: Control) -> Vector2:
	return b.get_global_rect().get_center()

func _run() -> void:
	await frames(8)
	var sim := game.sim
	var h := game.human
	var hud := game.hud
	var p: Player = sim.players[h]
	var tc: Ent = null
	for b in sim.buildings:
		if b.owner == h:
			tc = b
	# 1. caja con pulsación larga: mantener 0.6 s y arrastrar
	var c := game.world_to_screen(tc.center())
	touch(0, c + Vector2(-200, 60), true)
	await get_tree().create_timer(0.7).timeout
	check("long press activates box", game.box_active)
	for i in 5:
		move_touch(0, c, c + Vector2(260, 220))
		await get_tree().process_frame
	touch(0, c + Vector2(260, 220), false)
	await frames(4)
	check("box selects villagers", game.sel.size() == 5)
	# 2. botón Construir por toque real
	var hammer: UiButton = hud.grid[0]
	check("hammer visible", hammer.visible)
	print("hammer rect ", hammer.get_global_rect(), " text=", hammer.text, " mouse_filter=", hammer.mouse_filter)
	hud.game.sel_changed.connect(func() -> void: print("sel_changed emitted"))
	await tap(btn_center(hammer))
	await frames(3)
	print("mode after tap: ", hud.grid_mode, " ", hud.grid[0].text)
	check("grid in build mode", hud.grid_mode == "build")
	shot("a_menu")
	# 3. Casa
	var casa_slot: UiButton = null
	for b in hud.grid:
		if b.visible and b.text == Lang.t("b_casa"):
			casa_slot = b
	check("casa slot", casa_slot != null)
	await tap(btn_center(casa_slot))
	await frames(3)
	print("after casa tap: placing=", game.placing_type, " toasts=", hud.toasts.list, " sel=", game.sel.size(), " own units=", game.sel_own_units().size())
	check("placing casa", game.placing_type == "casa")
	# buscar casilla válida cerca del centro
	var tile := Vector2i(-1, -1)
	var s0: Vector2i = p.start_tile
	for r in range(4, 12):
		for dx in range(-r, r + 1):
			var t := s0 + Vector2i(dx, r)
			if sim.can_place("casa", t) and sim.can_place("casa", t + Vector2i(0, 0)):
				tile = t
				break
		if tile.x >= 0:
			break
	var wp := (Vector2(tile) + Vector2(1, 1)) * Defs.TILE
	await tap(game.world_to_screen(wp))
	await frames(3)
	check("ghost moved to tile", game.place_tile == tile)
	shot("b_ghost")
	var wood0: int = p.res["wood"]
	await tap(btn_center(hud.place_ok))
	await frames(5)
	check("house placed (wood paid)", int(p.res["wood"]) == wood0 - 30)
	check("placing finished", game.placing_type == "")
	# 4. recolectar: tocar un árbol con aldeanos seleccionados
	var tree := Vector2i(-1, -1)
	var best := 1e9
	for dy in range(-12, 13):
		for dx in range(-12, 13):
			var t := s0 + Vector2i(dx, dy)
			if sim.in_bounds(t) and sim.rtype[t.y * sim.W + t.x] == Defs.R_TREE:
				var d := float(dx * dx + dy * dy)
				if d < best and game.fog.explored_at(t):
					best = d
					tree = t
	var vl: Array = []
	for u in sim.units:
		if u.owner == h and u.type == "aldeano":
			vl.append(u)
	game.select_ents(vl.slice(2))
	check("villagers selected", game.sel.size() == 3)
	var tsp := game.world_to_screen(sim.tile_center(tree))
	await tap(tsp)
	await frames(2)
	var gathering := 0
	for u in sim.units:
		if u.owner == h and u.type == "aldeano" and u.target_tile == tree and u.state in [Sim.S_GATHER_GO, Sim.S_GATHER, Sim.S_RETURN]:
			gathering += 1
	check("tap on tree orders gather", gathering > 0)
	# 5. seleccionar TC por toque y entrenar por botón
	await tap(game.world_to_screen(tc.center()))
	await frames(3)
	check("tc selected", game.sel.size() == 1 and game.sel[0] == tc.id)
	var train: UiButton = hud.grid[0]
	check("train button visible", train.visible)
	var food0: int = p.res["food"]
	await tap(btn_center(train))
	await frames(3)
	check("trained queued", tc.queue.size() == 1 and int(p.res["food"]) == food0 - 50)
	shot("c_tc")
	# 6. minimapa: tocar la esquina superior izquierda
	var mm := hud.minimap
	await tap(mm.get_global_rect().position + Vector2(20, 20))
	await frames(4)
	check("minimap moves camera", game.cam_pos.x < 2000)
	# 7. pinch: dos dedos separándose
	var z0 := game.zoom
	var m0 := Vector2(640, 300)
	touch(0, m0 + Vector2(-50, 0), true)
	touch(1, m0 + Vector2(50, 0), true)
	await get_tree().process_frame
	for i in 6:
		move_touch(0, m0, m0 + Vector2(-50 - i * 25, 0))
		await get_tree().process_frame
		move_touch(1, m0, m0 + Vector2(50 + i * 25, 0))
		await get_tree().process_frame
	touch(0, m0, false)
	touch(1, m0, false)
	await frames(3)
	check("pinch zooms in", game.zoom > z0 * 1.5)
	# 8. arrastre con un dedo mueve cámara
	game.ui_goto_base()
	await frames(2)
	var cp := game.cam_pos
	touch(0, Vector2(600, 300), true)
	await get_tree().process_frame
	for i in 6:
		move_touch(0, Vector2(600, 300), Vector2(600 - i * 20, 300))
		await get_tree().process_frame
	touch(0, Vector2(500, 300), false)
	await frames(3)
	check("drag pans camera", game.cam_pos.distance_to(cp) > 30.0)
	# 9. avanzar la simulación 40 s a x3 y ver la casa terminada
	game.speed = 3.0
	await get_tree().create_timer(14.0).timeout
	var houses := 0
	for b in sim.buildings:
		if b.owner == h and b.type == "casa" and b.progress >= 1.0:
			houses += 1
	check("house completed", houses == 1)
	check("pop cap 15", p.pop_cap == 15)
	check("wood gathered", int(p.gathered["wood"]) > 0)
	print("gathered ", p.gathered, " res ", p.res, " pop ", p.pop)
	game.ui_goto_base()
	await frames(4)
	shot("d_later")
	print("RESULT fails=", fails)
	get_tree().quit()
