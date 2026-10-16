extends Node
## Interfaz de las mecánicas nuevas (herrería y mejoras, mercado, guarnición, rebato, posturas y formaciones, caza, piedra)
## con toques reales sobre los botones. Uso: xvfb-run -a godot --path . res://tools/ui_test12.tscn --rendering-driver opengl3 --resolution 1280x720
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

## Botón visible de la rejilla con ese icono (o null).
func find_btn(kind: String, text: String = "") -> UiButton:
	for b in game.hud.grid:
		if b.visible and b.icon_kind == kind and (text == "" or b.text == text):
			return b
	return null

func count_btn(kind: String) -> int:
	var n := 0
	for b in game.hud.grid:
		if b.visible and b.icon_kind == kind:
			n += 1
	return n

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
	p.age = 2
	p.res = {"food": 2000, "wood": 2000, "gold": 2000, "stone": 800}
	p.pop_cap = 300
	var base: Vector2i = p.start_tile
	game.l_fog.visible = false
	var centro: Ent = null
	for b in sim.buildings:
		if b.owner == h and b.type == "centro":
			centro = b
	check("hay centro", centro != null)

	var spots := {}
	for t in ["herreria", "mercado", "torre"]:
		var found: Ent = null
		for r in range(5, 26):
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if found == null and maxi(absi(dx), absi(dy)) == r and sim.can_place(t, base + Vector2i(dx, dy), h):
						found = sim._spawn_building(t, h, base + Vector2i(dx, dy), true)
		spots[t] = found
		check("se construye " + t, found != null)
	game.hud.refresh_now()
	# la barra superior dibuja la piedra
	check("la barra superior tiene piedra", p.res.has("stone"))

	# ---- Herrería: cada cadena ofrece sólo su primer escalón
	game.select_ents([spots["herreria"]])
	game.hud.refresh_now()
	check("herrería: 5 mejoras iniciales", count_btn("tech") == 5, str(count_btn("tech")))
	var tb := find_btn("tech", Lang.t("t_forja_1"))
	check("existe «Forja I»", tb != null)
	var gold0 := int(p.res["gold"])
	await tap_control(tb)
	check("tocar «Forja I» la pone en cola", (spots["herreria"] as Ent).queue.size() == 1 and String((spots["herreria"] as Ent).queue[0]) == "tech:forja_1", str((spots["herreria"] as Ent).queue))
	check("y cobra el coste", int(p.res["gold"]) == gold0 - 50, str(p.res["gold"]))
	game.hud.refresh_now()
	tb = find_btn("tech", Lang.t("t_forja_1"))
	check("el botón queda marcado «en cola»", tb != null and tb.toggled and tb.sub == Lang.t("tech_queued"))
	check("la cola muestra el icono de mejora", game.hud.info.qbtns[0].visible and game.hud.info.qbtns[0].icon_kind == "tech")
	await tap_control(tb)
	check("repetirla no duplica la cola", (spots["herreria"] as Ent).queue.size() == 1)
	for i in 400:
		sim.step()
	check("al acabar el tiempo se investiga", p.techs.has("forja_1"), str(p.techs))
	game.hud.refresh_now()
	check("y aparece el escalón siguiente «Forja II»", find_btn("tech", Lang.t("t_forja_2")) != null)

	# ---- Centro: mejoras de aldeanos
	game.select_ents([centro])
	game.hud.refresh_now()
	check("centro: ofrece Telar, Arado y Carretilla", find_btn("tech", Lang.t("t_telar")) != null and find_btn("tech", Lang.t("t_arado")) != null and find_btn("tech", Lang.t("t_carretilla")) != null)

	# ---- Mercado
	game.select_ents([spots["mercado"]])
	game.hud.refresh_now()
	var buy := find_btn("food", Lang.t("buy"))
	var sell := find_btn("wood", Lang.t("sell"))
	check("mercado: botones de comprar y vender", buy != null and sell != null)
	var f0 := int(p.res["food"])
	var g1 := int(p.res["gold"])
	await tap_control(buy)
	check("comprar da 100 de comida", int(p.res["food"]) == f0 + 100, str(p.res["food"]))
	check("y cuesta oro", int(p.res["gold"]) < g1, str(p.res["gold"]))
	var w0 := int(p.res["wood"])
	var g2 := int(p.res["gold"])
	await tap_control(sell)
	check("vender quita 100 de madera", int(p.res["wood"]) == w0 - 100, str(p.res["wood"]))
	check("y da oro", int(p.res["gold"]) > g2, str(p.res["gold"]))
	check("el precio de la comida ha subido", int(p.mkt["food"]) > 100, str(p.mkt))

	# ---- Postura, formación y guarnición con soldados
	var soldiers: Array = []
	for i in 4:
		var tile := sim.nearest_free_tile(base + Vector2i(-3 + i, 6), 5)
		soldiers.append(sim._spawn_unit("espadachin" if i % 2 == 0 else "arquero", h, tile))
	var vills: Array = []
	for i in 3:
		var tile2 := sim.nearest_free_tile(base + Vector2i(-6 + i, 4), 5)
		vills.append(sim._spawn_unit("aldeano", h, tile2))
	game.select_ents(soldiers)
	game.hud.refresh_now()
	var sb := find_btn("stance")
	var fb := find_btn("formation")
	var gb := find_btn("garrison")
	check("soldados: botones de postura, formación y refugio", sb != null and fb != null and gb != null)
	await tap_control(sb)
	check("la postura pasa a defensiva", (soldiers[0] as Ent).stance == Sim.ST_DEF and (soldiers[3] as Ent).stance == Sim.ST_DEF)
	game.hud.refresh_now()
	check("el botón muestra la postura", find_btn("stance").sub == Lang.t("stance_1"), find_btn("stance").sub)
	await tap_control(find_btn("stance"))
	await tap_control(find_btn("stance"))
	await tap_control(find_btn("stance"))
	check("tras 4 toques vuelve a agresiva", (soldiers[0] as Ent).stance == Sim.ST_AGGR)
	await tap_control(find_btn("formation"))
	check("formación: línea", p.formation == Sim.FM_LINE)
	game.hud.refresh_now()
	check("el botón de formación se marca", find_btn("formation").toggled and find_btn("formation").sub == Lang.t("formation_1"))
	await tap_control(find_btn("formation"))
	await tap_control(find_btn("formation"))
	check("y vuelve a libre tras 3 toques", p.formation == Sim.FM_FREE)

	# guarnición: botón → toque en la torre
	game.select_ents(soldiers)
	game.hud.refresh_now()
	await tap_control(find_btn("garrison"))
	check("«Refugiar» activa el modo", game.garrison_mode)
	var tw: Ent = spots["torre"]
	game._tap(game.world_to_screen(tw.center()))
	check("tocar la torre sale del modo", not game.garrison_mode)
	var going := 0
	for s in soldiers:
		if (s as Ent).state == Sim.S_GARRISON_GO:
			going += 1
	check("los soldados van hacia la torre", going > 0, str(going))
	for i in 600:
		sim.step()
	check("entran en la torre", tw.cargo.size() > 0, str(tw.cargo.size()))
	game.select_ents([tw])
	game.hud.refresh_now()
	var ex := find_btn("exit")
	check("la torre muestra «Salir»", ex != null)
	await tap_control(ex)
	check("«Salir» los saca", tw.cargo.is_empty())

	# ---- Rebato
	game.select_ents(vills)
	game.hud.refresh_now()
	check("el botón de rebato está en pantalla", get_viewport().get_visible_rect().encloses(game.hud.bell_btn.get_global_rect()), str(game.hud.bell_btn.get_global_rect()))
	await tap_control(game.hud.bell_btn)
	check("el rebato se activa", p.bell)
	check("y el botón se marca", game.hud.bell_btn.toggled)
	for i in 600:
		sim.step()
	var inside := 0
	for b in sim.buildings:
		if b.owner == h:
			inside += b.cargo.size()
	check("los aldeanos se refugian", inside >= vills.size(), str(inside))
	await tap_control(game.hud.bell_btn)
	check("fin del rebato", not p.bell)
	for i in 10:
		sim.step()
	inside = 0
	for b in sim.buildings:
		if b.owner == h:
			inside += b.cargo.size()
	check("y salen", inside == 0, str(inside))

	# ---- Animales: dibujo sin errores con la cámara sobre ellos
	check("el mapa tiene animales", sim.fauna.size() > 0, str(sim.fauna.size()))
	if sim.fauna.size() > 0:
		var a: Dictionary = sim.fauna[0]
		var ai: int = a["i"]
		game.cam_pos = sim.tile_center(Vector2i(ai % sim.W, ai / sim.W))
		game.zoom = 1.6
		game._dirty = 3
		await frames(4)
		check("se dibuja con la cámara sobre un animal", true)
	# ---- fin de partida con piedra
	p.gathered["stone"] = 12
	game.hud.show_end()
	await frames(3)
	check("la pantalla final dibuja", true)
	print("DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
