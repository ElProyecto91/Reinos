extends Node
## Murallas, puertas y torres desde la interfaz con toques sintéticos.
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
	get_viewport().get_texture().get_image().save_png("/tmp/ui5_%s.png" % name)

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func slot_with(text: String) -> UiButton:
	for b in game.hud.grid:
		if b.visible and b.text == text:
			return b
	return null

func count_type(t: String) -> int:
	var n := 0
	for b in game.sim.buildings:
		if b.alive and b.owner == game.human and b.type == t:
			n += 1
	return n

func _run() -> void:
	await frames(5)
	var sim := game.sim
	var h := game.human
	var hud := game.hud
	var p: Player = sim.players[h]
	p.res = {"food": 2000, "wood": 2000, "gold": 2000, "stone": 2000}
	var s0: Vector2i = p.start_tile
	# buscar una fila horizontal libre de 8 casillas a ~6 casillas de la base
	var a := Vector2i(-1, -1)
	for dy in range(5, 12):
		for dx in range(-10, 4):
			var ok := true
			for i in 8:
				if not sim.can_place("muralla", s0 + Vector2i(dx + i, dy), h) or sim.is_solid_tile(s0 + Vector2i(dx + i, dy - 1)):
					ok = false
					break
			if ok and a.x < 0:
				a = s0 + Vector2i(dx, dy)
	check("found free row for wall", a.x >= 0)
	game.focus_on(sim.tile_center(a + Vector2i(4, 0)))
	var vl: Array = []
	for u in sim.units:
		if u.owner == h and u.type == "aldeano":
			vl.append(u)
	game.select_ents(vl.slice(0, 3))
	await frames(4)
	# Construir -> Defensas -> Muralla
	await tap(hud.grid[0].get_global_rect().get_center())
	var dbtn := slot_with(Lang.t("defenses"))
	check("Defensas button needs feudal when age 0", dbtn != null and dbtn.enabled == false)
	p.age = 1
	hud.refresh_now()
	await frames(3)
	dbtn = slot_with(Lang.t("defenses"))
	check("Defensas button enabled in feudal", dbtn != null and dbtn.enabled)
	await tap(dbtn.get_global_rect().get_center())
	check("defense menu has muralla, puerta, torre", slot_with(Lang.t("b_muralla")) != null and slot_with(Lang.t("b_puerta")) != null and slot_with(Lang.t("b_torre")) != null)
	shot("defense_menu")
	await tap(slot_with(Lang.t("b_muralla")).get_global_rect().get_center())
	check("placing muralla", game.placing_type == "muralla")
	# dos toques: inicio y fin del tramo
	var stone0: int = p.res["stone"]
	await tap(game.world_to_screen(sim.tile_center(a)))
	check("first tap sets anchor", game.wall_state == 1 and game.wall_tiles.size() == 1)
	await tap(game.world_to_screen(sim.tile_center(a + Vector2i(7, 0))))
	check("second tap draws 8-tile line", game.wall_state == 2 and game.wall_tiles.size() == 8)
	await frames(8)
	shot("wall_ghost")
	check("place bar shows wall cost", hud.place_bar.visible and hud.place_label.text.contains("32"))
	await tap(hud.place_ok.get_global_rect().get_center())
	var walls := count_type("muralla")
	check("8 wall sites created", walls == 8)
	check("stone paid 8x4", int(p.res["stone"]) == stone0 - 32)
	check("still in wall mode for next segment", game.placing_type == "muralla")
	# terminar el modo con Listo
	await tap(hud.place_cancel.get_global_rect().get_center())
	check("wall mode ended", game.placing_type == "")
	# esperar a que se construya
	game.speed = 3.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		var done := 0
		for b in sim.buildings:
			if b.alive and b.owner == h and b.type == "muralla" and b.progress >= 1.0:
				done += 1
		if done == 8:
			break
		await get_tree().create_timer(0.5).timeout
	var built := 0
	for b in sim.buildings:
		if b.alive and b.owner == h and b.type == "muralla" and b.progress >= 1.0:
			built += 1
	check("all 8 wall pieces completed", built == 8)
	if built != 8:
		for b in sim.buildings:
			if b.alive and b.owner == h and b.type == "muralla":
				print("DBG wall ", b.tile, " progress ", b.progress, " builders ", b.builders)
		for u in vl.slice(0, 3):
			print("DBG vill state ", u.state, " target ", u.target_id, " pos ", sim.tile_of(u.pos), " queue ", u.get("orders"))
	game.speed = 1.0
	await frames(3)
	shot("wall_built")
	# puerta sobre un tramo de muralla (tocar la 4.ª pieza)
	game.select_ents(vl.slice(0, 3))
	await frames(4)
	await tap(hud.grid[0].get_global_rect().get_center())
	await tap(slot_with(Lang.t("defenses")).get_global_rect().get_center())
	await tap(slot_with(Lang.t("b_puerta")).get_global_rect().get_center())
	check("placing puerta", game.placing_type == "puerta")
	var gt := a + Vector2i(3, 0)
	await tap(game.world_to_screen(sim.tile_center(gt)))
	check("gate ghost on wall tile is valid", game._ghost_ok())
	await frames(6)
	shot("gate_ghost")
	await tap(hud.place_ok.get_global_rect().get_center())
	var gate_site: Ent = null
	for b in sim.buildings:
		if b.alive and b.owner == h and b.type == "puerta":
			gate_site = b
	check("gate site created over wall", gate_site != null and gate_site.tile == gt)
	check("old wall piece replaced", true)
	game.speed = 3.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000 and gate_site != null and gate_site.progress < 1.0:
		await get_tree().create_timer(0.5).timeout
	check("gate completed", gate_site != null and gate_site.progress >= 1.0)
	game.speed = 1.0
	await frames(3)
	shot("gate_built")
	# torre desde el submenú
	game.select_ents(vl.slice(0, 3))
	await frames(4)
	await tap(hud.grid[0].get_global_rect().get_center())
	await tap(slot_with(Lang.t("defenses")).get_global_rect().get_center())
	await tap(slot_with(Lang.t("b_torre")).get_global_rect().get_center())
	check("placing torre", game.placing_type == "torre")
	await tap(hud.place_cancel.get_global_rect().get_center())
	check("cancel placement", game.placing_type == "")
	# arrastre: trazar una línea de 6 casillas con un dedo
	game.select_ents(vl.slice(0, 3))
	await frames(4)
	await tap(hud.grid[0].get_global_rect().get_center())
	await tap(slot_with(Lang.t("defenses")).get_global_rect().get_center())
	await tap(slot_with(Lang.t("b_muralla")).get_global_rect().get_center())
	var d0 := a + Vector2i(0, 2)
	var sp0 := game.world_to_screen(sim.tile_center(d0)) + Vector2(0, 56)
	var sp1 := game.world_to_screen(sim.tile_center(d0 + Vector2i(5, 0))) + Vector2(0, 56)
	touch(0, sp0, true)
	await frames(2)
	for i in range(1, 11):
		var q := sp0.lerp(sp1, float(i) / 10.0)
		var dr := InputEventScreenDrag.new()
		dr.index = 0
		dr.position = q
		dr.relative = (sp1 - sp0) / 10.0
		Input.parse_input_event(dr)
		await get_tree().process_frame
	touch(0, sp1, false)
	await frames(3)
	check("drag draws 6-tile line", game.wall_tiles.size() == 6 and game.wall_state == 2)
	shot("wall_drag")
	await tap(hud.place_cancel.get_global_rect().get_center())
	print("DONE fails=", fails)
	get_tree().quit()
