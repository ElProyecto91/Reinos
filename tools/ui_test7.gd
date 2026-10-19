extends Node
## Flujo marítimo con toques reales: construir puerto, entrenar barcos, pescar, embarcar y desembarcar.
## Uso: xvfb-run -a godot --path . res://tools/ui_test7.tscn --rendering-driver opengl3 --resolution 1280x720 -- seed=1 out=/tmp/ui7
var game: Game
var fails := 0
var out := "/tmp/ui7"
var seed_v := 1
var _started := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			seed_v = int(a.substr(5))
		if a.begins_with("out="):
			out = a.substr(4)
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.apply_display(get_window())
	var cfg := {"size": 128, "seed": seed_v, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 0, "name": "Rojo"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)

func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (("  " + extra) if extra != "" else ""))
	if not ok:
		fails += 1

func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, name])

func touch(pos: Vector2, pressed: bool) -> void:
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

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func run_sim(seconds: float) -> void:
	for i in int(seconds / Sim.DT):
		game.sim.step()
	game.hud.refresh_now()
	await frames(2)

func find_slot(text: String) -> UiButton:
	for b in game.hud.grid:
		if b.visible and b.text == text:
			return b
	return null

func tap_slot(text: String) -> bool:
	var b := find_slot(text)
	if b == null:
		return false
	await tap(b.get_global_rect().get_center())
	return true

func tap_world(wp: Vector2) -> void:
	game.focus_on(wp)
	await frames(3)
	await tap(game.world_to_screen(wp))

## Casilla de peces cercana (de la misma agua que el puerto) a la que tocar sin pillar ningún barco propio ni el puerto: con las bases
## más al interior el banco más próximo queda pegado al muelle y el toque seleccionaría el barco en vez de mandarlo a pescar.
func _fish_to_tap(sim: Sim, from: Vector2i, port: Ent) -> Vector2i:
	var wc: int = sim.water_comp_at(from)
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for y in range(maxi(0, from.y - 40), mini(sim.H, from.y + 41)):
		for x in range(maxi(0, from.x - 40), mini(sim.W, from.x + 41)):
			var i: int = y * sim.W + x
			if sim.rtype[i] != Defs.R_FISH or sim.ramt[i] <= 0:
				continue
			var t := Vector2i(x, y)
			if sim.water_comp_at(t) != wc:
				continue
			if Vector2(t).distance_to(Vector2(port.dock_tile)) < 4.5:
				continue
			var near_ship := false
			for u in sim.units:
				if u.alive and u.owner == game.human and Vector2(sim.tile_of(u.pos)).distance_to(Vector2(t)) < 3.5:
					near_ship = true
					break
			if near_ship:
				continue
			var d := Vector2(t).distance_to(Vector2(from))
			if d < bd:
				bd = d
				best = t
	return best

## Toque sobre el cuerpo de una unidad (en isométrico el punto del suelo de un barco puede caer sobre otro que va delante)
func tap_unit(u: Ent) -> void:
	game.focus_on(u.pos)
	await frames(3)
	await tap(game.world_to_screen(u.pos) + Vector2(0, -game.view.unit_top(u) * 0.5 * game.zoom))

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var sim := game.sim
	var h := game.human
	var p: Player = sim.players[h]
	sim.ais.clear()
	p.res = {"food": 3000, "wood": 3000, "gold": 3000, "stone": 3000}
	p.pop_cap = 100
	p.age = 1
	var base: Vector2i = p.start_tile
	# --- 1) construir un puerto desde el menú de aldeanos
	var spot := Vector2i(-1, -1)
	var bd := 1e9
	for y in range(maxi(1, base.y - 45), mini(sim.H - 4, base.y + 45)):
		for x in range(maxi(1, base.x - 45), mini(sim.W - 4, base.x + 45)):
			var t := Vector2i(x, y)
			if sim.can_place("puerto", t, h) and sim.can_reach_building(sim.nearest_free_tile(base + Vector2i(0, 3), 6), "puerto", t):
				var d := Vector2(t - base).length()
				if d < bd:
					bd = d
					spot = t
	check("hay sitio de puerto", spot.x >= 0, str(spot))
	if spot.x < 0:
		print("DONE fails=", fails)
		get_tree().quit()
		return
	var vl: Array = []
	for u in sim.units:
		if u.owner == h and u.type == "aldeano":
			vl.append(u)
	game.select_ents(vl.slice(0, 4))
	game.focus_on(sim.tile_center(spot))
	await frames(4)
	check("botón Construir", await tap_slot(Lang.t("build")))
	await frames(3)
	var pb := find_slot(Lang.t("b_puerto"))
	check("el menú de construcción ofrece Puerto", pb != null)
	if pb != null:
		check("Puerto asequible", pb.enabled)
	shot("1_menu")
	check("tocar Puerto", await tap_slot(Lang.t("b_puerto")))
	check("modo colocación de puerto", game.placing_type == "puerto", game.placing_type)
	game.place_tile = spot
	await frames(3)
	check("fantasma válido", game._ghost_ok())
	shot("2_ghost")
	await tap(game.hud.place_ok.get_global_rect().get_center())
	check("colocación confirmada", game.placing_type == "")
	var port: Ent = null
	for b in sim.buildings:
		if b.owner == h and b.type == "puerto":
			port = b
	check("puerto en construcción", port != null)
	if port == null:
		print("DONE fails=", fails)
		get_tree().quit()
		return
	await run_sim(90.0)
	check("puerto terminado", port.progress >= 1.0, "%.2f" % port.progress)
	# --- 2) entrenar barcos desde el panel del puerto
	await tap_world(port.center())
	check("tocar el puerto lo selecciona", game.sel_building() == port)
	await frames(3)
	check("botón barco de pesca", find_slot(Lang.t("us_barco_pesca")) != null)
	check("botón barco de transporte", find_slot(Lang.t("us_barco_transporte")) != null)
	check("botón galera", find_slot(Lang.t("us_galera")) != null)
	shot("3_port")
	check("entrenar pesquero", await tap_slot(Lang.t("us_barco_pesca")))
	check("entrenar pesquero 2", await tap_slot(Lang.t("us_barco_pesca")))
	check("entrenar transporte", await tap_slot(Lang.t("us_barco_transporte")))
	check("entrenar galera", await tap_slot(Lang.t("us_galera")))
	check("cola con 4 barcos", port.queue.size() == 4, str(port.queue.size()))
	await run_sim(100.0)
	var fishers: Array[Ent] = []
	var transport: Ent = null
	var galera: Ent = null
	for u in sim.units:
		if u.owner == h and u.naval:
			if u.type == "barco_pesca": fishers.append(u)
			if u.type == "barco_transporte": transport = u
			if u.type == "galera": galera = u
	check("2 pesqueros, transporte y galera", fishers.size() == 2 and transport != null and galera != null, "%d" % fishers.size())
	if fishers.size() < 2 or transport == null or galera == null:
		print("DONE fails=", fails)
		get_tree().quit()
		return
	# --- 3) pescar tocando el banco de peces
	game.select_ents(fishers)
	await frames(3)
	check("pesqueros sin botón Construir", find_slot(Lang.t("build")) == null)
	var ft := _fish_to_tap(sim, sim.tile_of(fishers[0].pos), port)
	check("hay peces", ft.x >= 0)
	if ft.x >= 0:
		var food0: int = p.gathered["food"]
		if not game.fog.explored_at(ft):
			print("INFO el banco de peces no estaba explorado; se marca como explorado")
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var q := ft + Vector2i(dx, dy)
					if sim.in_bounds(q):
						game.fog.state[q.y * sim.W + q.x] = maxi(game.fog.state[q.y * sim.W + q.x], 1)
		await tap_world(sim.tile_center(ft))
		var heading := 0
		for f in fishers:
			if f.state == Sim.S_GATHER_GO or f.state == Sim.S_GATHER:
				heading += 1
		check("tocar peces manda a pescar", heading >= 1, "%d de 2" % heading)
		await run_sim(150.0)
		var gained: int = int(p.gathered["food"]) - food0
		check("la pesca entrega comida", gained >= 20, "+%d" % gained)
	# --- 4) embarcar tocando el transporte con soldados seleccionados
	var shore := sim.nearest_water_tile(port.dock_tile, sim.water_comp_at(sim.tile_of(transport.pos)), 3)
	sim.cmd_move(h, [transport.id], shore)
	await run_sim(40.0)
	var warriors: Array[Ent] = []
	for k in 3:
		warriors.append(sim._spawn_unit("piquero", h, sim.nearest_free_tile(base + Vector2i(k, 4), 6)))
	game.select_ents(warriors)
	await frames(3)
	await tap_unit(transport)
	var going := 0
	for w in warriors:
		if w.state == Sim.S_BOARD_GO or w.stowed:
			going += 1
	check("tocar el transporte manda a embarcar", going >= 2, "%d de 3" % going)
	await run_sim(60.0)
	check("3 pasajeros a bordo", transport.cargo.size() == 3, str(transport.cargo.size()))
	# --- 5) panel del transporte con botón Desembarcar
	game.select_ents([transport])
	await frames(4)
	check("botón Desembarcar visible", find_slot(Lang.t("unload")) != null)
	shot("4_transport")
	# isla alcanzable
	var main_c: int = sim.comp[base.y * sim.W + base.x]
	var tw := sim.water_comp_at(sim.tile_of(transport.pos))
	var best := Vector2i(-1, -1)
	var bdist := 1e9
	for y in sim.H:
		for x in sim.W:
			var i := y * sim.W + x
			var c: int = sim.comp[i]
			if c >= 0 and c != main_c and sim.rtype[i] == 0 and not sim.is_solid_tile(Vector2i(x, y)):
				if sim.nearest_water_tile(Vector2i(x, y), tw, 2).x >= 0:
					var d := Vector2(x, y).distance_to(Vector2(sim.tile_of(transport.pos)))
					if d < bdist:
						bdist = d
						best = Vector2i(x, y)
	check("isla alcanzable", best.x >= 0, str(best))
	if best.x >= 0:
		await tap_world(sim.tile_center(best))
		await run_sim(120.0)
		check("desembarcan todos en la isla", transport.cargo.is_empty(), "quedan %d" % transport.cargo.size())
		var on_island := 0
		for w in warriors:
			var tt := sim.tile_of(w.pos)
			if w.alive and sim.comp[tt.y * sim.W + tt.x] == sim.comp[best.y * sim.W + best.x]:
				on_island += 1
		check("los 3 están en la isla", on_island == 3, "%d" % on_island)
		shot("5_island")
	# --- 6) botón Desembarcar (orilla más cercana) tras volver a cargar
	sim.cmd_move(h, [transport.id], shore)
	await run_sim(120.0)
	var w2: Array[Ent] = []
	for k in 2:
		w2.append(sim._spawn_unit("arquero", h, sim.nearest_free_tile(base + Vector2i(k, 5), 6)))
	game.select_ents(w2)
	await frames(2)
	await tap_unit(transport)
	await run_sim(60.0)
	check("2 arqueros a bordo", transport.cargo.size() == 2, str(transport.cargo.size()))
	game.select_ents([transport])
	await frames(4)
	check("tocar Desembarcar", await tap_slot(Lang.t("unload")))
	await run_sim(60.0)
	check("el botón descarga a la orilla", transport.cargo.is_empty(), str(transport.cargo.size()))
	# --- 7) combate: la galera ataca a un barco enemigo tocándolo
	var e_shore := sim.nearest_water_tile(sim.tile_of(galera.pos) + Vector2i(5, 0), sim.water_comp_at(sim.tile_of(galera.pos)), 8)
	var enemy := sim._spawn_unit("galera", 1, e_shore)
	game.select_ents([galera])
	await frames(3)
	check("la galera tiene botón de atacar-mover", find_slot(Lang.t("attack_move")) != null)
	var hp0 := enemy.hp
	await tap_unit(enemy)
	await run_sim(40.0)
	check("tocar al barco enemigo lo ataca", (not enemy.alive) or enemy.hp < hp0, "hp %.0f -> %.0f" % [hp0, enemy.hp])
	print("DONE fails=", fails)
	get_tree().quit()
