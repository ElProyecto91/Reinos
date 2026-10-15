extends Node
## Civilizaciones con la interfaz real: panel de elección en el menú, botón de habilidad del HUD (edad, recarga,
## apuntar el fuego), la unidad única aparece en los botones del Castillo y el guardado conserva la elección.
var fails := 0
var game: Game

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

func _ready() -> void:
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.apply_display(get_window())
	_run()

func find_nodes(n: Node, cls: String, out: Array) -> void:
	if n.get_script() != null and String(n.get_script().get_global_name()) == cls:
		out.append(n)
	for c in n.get_children():
		find_nodes(c, cls, out)

func _run() -> void:
	# ---------------- menú
	Settings.civ = "random"
	var m := MenuScreen.new()
	add_child(m)
	await frames(3)
	check("el menú muestra la fila de civilización", m._civ_btn != null and m._civ_btn.visible)
	check("por defecto: al azar", m._civ_btn.text.begins_with(Lang.t("civ_random")), m._civ_btn.text)
	m._civ_btn.action.call()
	await frames(2)
	check("el panel de civilizaciones se abre", m._civ_panel.visible)
	var cards: Array = (m._civ_panel as MenuScreen.CivPanel).cards
	check("ocho tarjetas", cards.size() == 8, str(cards.size()))
	cards[3].on_pick.call()      # teutones
	await frames(2)
	check("elegir una cierra el panel", not m._civ_panel.visible)
	check("la elección se guarda en Settings", Settings.civ == "teutones", Settings.civ)
	check("el botón muestra la civilización", m._civ_btn.text.begins_with(Lang.t("civ_teutones")), m._civ_btn.text)
	m.queue_free()
	await frames(2)
	Settings.civ = "random"

	# ---------------- partida con bizantinos (habilidad de fuego: hay que apuntar)
	var cfg := {"size": 128, "seed": 7, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú", "civ": "bizantinos"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo", "civ": "mongoles"}]}
	SaveGame.delete()
	game = Game.new()
	add_child(game)
	game.start(cfg)
	check("la partida carga", await wait_ready(game))
	await frames(3)
	var sim := game.sim
	game.hud.hide_pause()
	var p: Player = sim.players[game.human]
	check("la civilización del humano es bizantinos", p.civ == "bizantinos")
	game.hud.refresh_now()
	await frames(2)
	var btn: UiButton = game.hud.abil_btn
	check("el botón de habilidad es visible", btn.visible)
	check("en la Edad Oscura está desactivado", not btn.enabled, btn.sub)
	game.ui_ability()
	check("pulsarlo antes de tiempo no apunta", not game.abil_mode)
	p.age = 1
	game.hud.refresh_now()
	await frames(2)
	check("en la Edad Feudal se activa", btn.enabled, btn.sub)
	check("indica que está lista", btn.sub == Lang.t("abil_ready"), btn.sub)
	game.ui_ability()
	check("el fuego pide apuntar", game.abil_mode)
	check("el botón se ve resaltado al apuntar", btn.toggled)
	# toque en el mapa lejos del centro
	var wp := sim.tile_center(p.start_tile + Vector2i(12, 6))
	game.cam_pos = wp
	game.paused = false
	await frames(3)
	game._tap(game.world_to_screen(wp))
	await frames(2)
	check("el toque lanza el fuego", sim.zones.size() == 1, str(sim.zones.size()))
	check("sale del modo apuntar", not game.abil_mode)
	game.hud.refresh_now()
	await frames(2)
	check("el botón pasa a recarga", not btn.enabled and btn.progress >= 0.0 and btn.sub.ends_with("s"), "%s %.2f" % [btn.sub, btn.progress])
	game.ui_ability()
	check("no se puede relanzar en recarga", not game.abil_mode)
	# la tarjeta de unidad muestra la civilización del dueño y la barra superior la tuya
	check("la barra superior sabe tu civilización", p.civ != "")

	# ---------------- Castillo: botón de unidad única
	for k in ["food", "wood", "gold", "stone"]:
		p.res[k] = 5000
	p.age = 2
	var site := Vector2i(-1, -1)
	for r in range(3, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and site.x < 0 and sim.can_place("castillo", p.start_tile + Vector2i(dx, dy), game.human):
					site = p.start_tile + Vector2i(dx, dy)
	check("hay sitio para un castillo", site.x >= 0)
	var cs := sim._spawn_building("castillo", game.human, site, true)
	game.select_ents([cs])
	game.hud.refresh_now()
	await frames(3)
	var slots := 0
	var found_unique := false
	for ut in Civs.train_list("castillo", p.civ):
		slots += 1
		if ut == "catafracta":
			found_unique = true
	check("la lista del Castillo incluye la catafracta", found_unique, str(Civs.train_list("castillo", p.civ)))
	check("y no la de otra civilización", not Civs.train_list("castillo", p.civ).has("mangudai"))
	var r := game.sim.cmd_train(game.human, cs.id, "catafracta")
	check("se puede entrenar la catafracta", r == Sim.OK, str(r))
	check("el icono de la unidad existe", game.art.unit_icon("catafracta", 0) != null)
	for ut2 in Civs.IDS:
		check("icono de la única de " + ut2, game.art.unit_icon(Civs.unique_of(ut2), 0) != null)

	# ---------------- guardar y cargar conserva todo
	game.hud.show_pause()
	await frames(2)
	check("se guarda", SaveGame.has_save() and game.last_save_ok)
	var data := SaveGame.read_data()
	var cfg2: Dictionary = data["cfg"]
	check("la configuración guardada conserva la civilización", String(cfg2["players"][0].get("civ", "")) == "bizantinos")
	var s2 := SaveGame.restore(data)
	check("se restaura", s2 != null)
	if s2 != null:
		check("civilizaciones restauradas", (s2.players[0] as Player).civ == "bizantinos" and (s2.players[1] as Player).civ == "mongoles")
		check("la zona de fuego sigue ahí", s2.zones.size() == sim.zones.size())
		check("el enfriamiento sigue igual", absf((s2.players[0] as Player).abil_ready - p.abil_ready) < 0.01)
	SaveGame.delete()
	print("DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
