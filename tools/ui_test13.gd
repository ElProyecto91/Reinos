extends Node
## Plantar árboles y crear minas de oro desde la interfaz: Construir → Recursos, modo de colocación repetible, toques sobre el mapa,
## aviso al terminar la mina y casillas del mapa que cambian (retoño → árbol, obra → filón de oro).
## Uso: xvfb-run -a godot --path . res://tools/ui_test13.tscn --rendering-driver opengl3 --resolution 1280x720
var fails := 0
var game: Game
var _started := false

func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (("  " + extra) if extra != "" else ""))
	if not ok:
		fails += 1

func touch(pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = pos
	t.pressed = pressed
	Input.parse_input_event(t)

func to_window(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p

func tap_control(c: Control) -> void:
	var p := to_window(c.get_global_rect().get_center())
	touch(p, true)
	await get_tree().process_frame
	touch(p, false)
	await get_tree().process_frame
	await get_tree().process_frame

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func find_btn(kind: String, text: String = "") -> UiButton:
	for b in game.hud.grid:
		if b.visible and b.icon_kind == kind and (text == "" or b.text == text):
			return b
	return null

func find_text(text: String) -> UiButton:
	for b in game.hud.grid:
		if b.visible and b.text == text:
			return b
	return null

## Construir → Recursos con toques reales (cualquier cambio de selección o de modo devuelve la rejilla a la página principal).
func goto_resources() -> void:
	game.hud.refresh_now()
	if game.hud.grid_mode == "main":
		await tap_control(find_btn("hammer"))
	if game.hud.grid_mode == "build":
		await tap_control(find_btn("resources"))

func run_secs(secs: float) -> void:
	for i in int(secs / Sim.DT):
		game.sim.step()
	game._consume_events()

func _ready() -> void:
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.auto_pause = false
	Settings.apply_display(get_window())
	var cfg := {"size": 128, "seed": 4, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú", "civ": "castellanos"},
		{"human": false, "team": 1, "diff": 0, "name": "Rojo", "civ": "francos"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)
	game.paused = true

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func _run() -> void:
	await frames(10)
	var sim := game.sim
	var h := game.human
	sim.ais.clear()
	var p: Player = sim.players[h]
	p.age = 0
	p.res = {"food": 500, "wood": 600, "gold": 0, "stone": 300}
	p.pop_cap = 300
	var base: Vector2i = p.start_tile
	game.l_fog.visible = false
	game.cam_pos = sim.tile_center(base + Vector2i(0, 7))
	var v1 := sim._spawn_unit("aldeano", h, sim.nearest_free_tile(base + Vector2i(-2, 5), 5))
	var v2 := sim._spawn_unit("aldeano", h, sim.nearest_free_tile(base + Vector2i(2, 5), 5))
	await frames(3)

	# ---- Construir → Recursos
	game.select_ents([v1])
	game.hud.refresh_now()
	var hb := find_btn("hammer")
	check("aldeano: botón Construir", hb != null)
	await tap_control(hb)
	check("la rejilla pasa a «build»", game.hud.grid_mode == "build")
	var rb := find_btn("resources")
	check("hay un botón «Recursos»", rb != null and rb.text == Lang.t("resources"))
	await tap_control(rb)
	check("la rejilla pasa a «resource»", game.hud.grid_mode == "resource")
	var sb := find_btn("sapling")
	var mb := find_text(Lang.t("b_mina"))
	check("submenú: Plantar árbol", sb != null and sb.text == Lang.t("b_arbol"))
	check("submenú: Mina de oro", mb != null)
	check("el árbol enseña 0/30", sb != null and sb.sub == "0/%d" % Defs.PLANT_MAX, sb.sub if sb != null else "")
	check("la mina pide Edad Feudal en Edad Oscura", mb != null and not mb.enabled and mb.sub == Lang.t("needs_age_1"), mb.sub if mb != null else "")
	check("hay botón «Atrás»", find_btn("back") != null)

	# la mina bloqueada avisa
	await tap_control(mb)
	check("tocar la mina bloqueada no entra en el modo de colocar", game.placing_type == "")

	# ---- Plantar: modo repetible
	var w0 := int(p.res["wood"])
	await tap_control(sb)
	check("Plantar árbol activa el modo", game.placing_type == "arbol")
	check("y el fantasma ocupa 1 casilla", game._ghost_from_world(sim.tile_center(base)) == base)
	game.hud.refresh_now()
	check("la barra de colocar enseña el coste", game.hud.place_label.text.find("12") >= 0, game.hud.place_label.text)
	var spots: Array[Vector2i] = []
	for r in range(3, 14):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := base + Vector2i(dx, dy)
				if maxi(absi(dx), absi(dy)) == r and (dx + dy) % 2 == 0 and spots.size() < 4 and sim.can_plant(q) and sim.query(sim.tile_center(q), 40.0).is_empty():
					spots.append(q)
	check("hay sitio para plantar", spots.size() == 4)
	game.cam_pos = sim.tile_center(spots[0])
	await frames(2)
	game._tap(game.world_to_screen(sim.tile_center(spots[0])))
	check("tocar el mapa planta el primero", sim.rtype[spots[0].y * sim.W + spots[0].x] == Defs.R_SAPLING)
	check("el modo sigue activo", game.placing_type == "arbol")
	check("y se paga la madera", int(p.res["wood"]) == w0 - 12, str(p.res["wood"]))
	game._consume_events()
	check("el mapa de casillas recibe el retoño", game.res_layer.get_cell_atlas_coords(spots[0]) == Vector2i(Art.RES_SAPLING, 0), str(game.res_layer.get_cell_atlas_coords(spots[0])))
	for k in range(1, 3):
		game.cam_pos = sim.tile_center(spots[k])
		await frames(2)
		game._tap(game.world_to_screen(sim.tile_center(spots[k])))
	check("tres retoños en total", sim.sapling_count(h) == 3, str(sim.sapling_count(h)))
	# una casilla inválida (el centro urbano) da error y no cobra
	var tc: Ent = sim.get_ent(sim.occ[base.y * sim.W + base.x])
	var wood_now := int(p.res["wood"])
	game.cam_pos = tc.center()
	await frames(2)
	game._tap(game.world_to_screen(tc.center()))
	check("tocar un edificio no planta", sim.sapling_count(h) == 3 and int(p.res["wood"]) == wood_now)
	game.hud.refresh_now()
	await tap_control(game.hud.place_ok)
	check("«Listo» sale del modo", game.placing_type == "")
	check("tras «Listo» la rejilla vuelve a la página principal", game.hud.grid_mode == "main")
	await goto_resources()
	sb = find_btn("sapling")
	check("el botón enseña 3/30", sb != null and sb.sub == "3/%d" % Defs.PLANT_MAX, sb.sub if sb != null else "")

	# ---- crecimiento visible en el mapa
	run_secs(95.0)
	var all_trees := true
	for k in 3:
		if sim.rtype[spots[k].y * sim.W + spots[k].x] != Defs.R_TREE:
			all_trees = false
	check("a los 95 s son árboles en la simulación", all_trees)
	var painted := true
	for k in 3:
		var ac := game.res_layer.get_cell_atlas_coords(spots[k])
		if ac == Vector2i(Art.RES_SAPLING, 0) or ac.x < 0:
			painted = false
	check("y el mapa de casillas ya dibuja árboles", painted)
	await goto_resources()
	sb = find_btn("sapling")
	check("el contador vuelve a 0/30", sb != null and sb.sub == "0/%d" % Defs.PLANT_MAX, sb.sub if sb != null else "")

	# ---- Mina de oro
	p.age = 1
	await goto_resources()
	mb = find_text(Lang.t("b_mina"))
	check("en Edad Feudal la mina se habilita", mb != null and mb.enabled)
	check("y enseña 0/3", mb != null and mb.sub == "0/%d" % Defs.MINE_MAX, mb.sub if mb != null else "")
	var s0 := int(p.res["stone"])
	var w1 := int(p.res["wood"])
	await tap_control(mb)
	check("tocar la mina entra en el modo de colocar", game.placing_type == "mina")
	var site := Vector2i(-1, -1)
	for r in range(5, 20):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := base + Vector2i(dx, dy)
				if site.x < 0 and maxi(absi(dx), absi(dy)) == r and sim.can_place("mina", q, h) and sim.can_reach_building(sim.tile_of(v1.pos), "mina", q):
					site = q
	check("hay sitio para la mina", site.x >= 0)
	game.cam_pos = sim.tile_center(site)
	await frames(2)
	game.place_tile = site
	await tap_control(game.hud.place_ok)
	check("«Construir» coloca la obra", game.placing_type == "" and sim.mine_count(h) == 1, str(game.placing_type))
	check("y cobra 80 de madera y 70 de piedra", int(p.res["wood"]) == w1 - 80 and int(p.res["stone"]) == s0 - 70, "%d/%d" % [int(p.res["wood"]), int(p.res["stone"])])
	var bld: Ent = null
	for b in sim.buildings:
		if b.type == "mina":
			bld = b
	check("hay una obra de mina", bld != null)
	run_secs(45.0)
	var si := site.y * sim.W + site.x
	check("al terminar hay un filón de oro", sim.rtype[si] == Defs.R_GOLD and int(sim.ramt[si]) > 300)
	check("la obra ha desaparecido", bld != null and not bld.alive)
	check("el mapa de casillas dibuja el oro", game.res_layer.get_cell_atlas_coords(site) == Vector2i(Art.RES_GOLD, 0), str(game.res_layer.get_cell_atlas_coords(site)))
	check("el constructor pica el oro", v1.state == Sim.S_GATHER or v1.state == Sim.S_GATHER_GO or v1.state == Sim.S_RETURN, str(v1.state))
	game.hud.refresh_now()
	await frames(3)
	run_secs(120.0)
	check("entra oro en el almacén", int(p.res["gold"]) > 20, str(p.res["gold"]))

	# ---- tope de minas: tres a la vez
	p.res = {"food": 500, "wood": 2000, "gold": 0, "stone": 2000}
	game.select_ents([v2])
	await goto_resources()
	var placed := 0
	for r in range(5, 24):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := base + Vector2i(dx, dy)
				if placed < 2 and maxi(absi(dx), absi(dy)) == r and maxi(absi(q.x - site.x), absi(q.y - site.y)) > 3 and sim.can_place("mina", q, h) and sim.can_reach_building(sim.tile_of(v2.pos), "mina", q):
					if sim.cmd_build(h, [v2.id], "mina", q) > 0:
						placed += 1
	check("se colocan otras dos obras", placed == 2 and sim.mine_count(h) == 3, "%d / %d" % [placed, sim.mine_count(h)])
	await goto_resources()
	mb = find_text(Lang.t("b_mina"))
	check("el botón enseña 3/3", mb != null and mb.sub == "3/%d" % Defs.MINE_MAX, mb.sub if mb != null else "")
	await tap_control(mb)
	check("con el tope alcanzado no entra en el modo de colocar", game.placing_type == "")
	check("el texto del error es el de las minas", game.err_text(Sim.ERR_LIMIT) != "" and game._limit_kind == "mine", game.err_text(Sim.ERR_LIMIT))

	# ---- Atrás vuelve a Construir
	await tap_control(find_btn("back"))
	check("«Atrás» vuelve a la página de construir", game.hud.grid_mode == "build")
	print("fails=", fails)
	get_tree().quit(1 if fails > 0 else 0)
