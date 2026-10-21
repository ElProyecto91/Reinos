extends Node
## Captura de una partida de verdad (mapa + interfaz) con la cámara en la base: sirve para comparar el aspecto antes y después de tocar
## arte, terreno o interfaz. Monta un pueblo (casas, cuartel, establo...) y unas tropas alrededor del centro urbano.
## Uso: xvfb-run -a godot --path . res://tools/view_shot.tscn --rendering-driver opengl3 --resolution 2000x900 -- shot=/tmp/v.png zoom=1.5 select=centro|none|<unidad>
##        [seed=4] [size=128] [civ=castellanos] [rival=francos] [cam=0,0 (desplazamiento en casillas)] [fog=0|1] [night=0] [age=2] [hud=1|0] [town=1|0]
##        [ui=pause|help|end|multi|queue|place|toasts  (estado de la interfaz que se fotografía)] [skin=0 (sin piel de madera)]
var game: Game
var _started := false
var shot_path := "/tmp/view.png"
var zoom_v := 1.5
var select_t := "centro"
var seed_v := 4
var size_v := 128
var civ_v := "castellanos"
var rival_v := "francos"
var cam_off := Vector2i(0, 0)
var fog_v := false
var night_v := 0.0
var age_v := 2
var hud_v := true
var town_v := true
var ui_v := ""
var skin_v := true

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="): shot_path = a.substr(5)
		elif a.begins_with("zoom="): zoom_v = float(a.substr(5))
		elif a.begins_with("select="): select_t = a.substr(7)
		elif a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("size="): size_v = int(a.substr(5))
		elif a.begins_with("civ="): civ_v = a.substr(4)
		elif a.begins_with("rival="): rival_v = a.substr(6)
		elif a.begins_with("fog="): fog_v = a.substr(4) == "1"
		elif a.begins_with("night="): night_v = float(a.substr(6))
		elif a.begins_with("age="): age_v = int(a.substr(4))
		elif a.begins_with("hud="): hud_v = a.substr(4) == "1"
		elif a.begins_with("town="): town_v = a.substr(5) == "1"
		elif a.begins_with("ui="): ui_v = a.substr(3)
		elif a.begins_with("skin="): skin_v = a.substr(5) == "1"
		elif a.begins_with("cam="):
			var q := a.substr(4).split(",")
			cam_off = Vector2i(int(q[0]), int(q[1]))
	if not skin_v:
		UiSkin._ready_state = 0   # sin piel: el estilo plano de antes (para comparar el coste de dibujo)
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.auto_pause = false
	Settings.apply_display(get_window())
	var cfg := {"size": size_v, "seed": seed_v, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú", "civ": civ_v},
		{"human": false, "team": 1, "diff": 0, "name": "Rojo", "civ": rival_v}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)
	game.paused = true

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func _free_near(sim: Sim, t: Vector2i, type: String, h: int) -> Vector2i:
	for r in range(0, 16):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := t + Vector2i(dx, dy)
				if sim.can_place(type, q, h):
					return q
	return Vector2i(-1, -1)

func _ui_state(made: Dictionary) -> void:
	var hud: Hud = game.hud
	match ui_v:
		"pause":
			hud.show_pause()
		"help":
			hud.help_ui.visible = true
		"end":
			hud.show_end()
		"multi":
			var mine: Array = []
			for u in game.sim.units:
				if u.owner == game.human:
					mine.append(u)
			game.select_ents(mine)
		"queue":
			if made.get("cuartel") != null:
				game.select_ents([made["cuartel"]])
				for t in ["alabardero", "espadachin", "alabardero"]:
					game.ui_train(t)
		"place":
			game.ui_begin_place("casa")
		"toasts":
			hud.toast("Falta madera", Color(1.0, 0.55, 0.45))
			hud.toast("Tu aldeano ha terminado la casa", Color(0.85, 1.0, 0.8))
			hud.toast("¡Te atacan en la base!", Color(1.0, 0.45, 0.4))
	await get_tree().process_frame

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var sim := game.sim
	var h := game.human
	sim.ais.clear()
	var p: Player = sim.players[h]
	p.age = age_v
	p.res = {"food": 900, "wood": 900, "gold": 900, "stone": 900}
	p.pop_cap = 300
	var base: Vector2i = p.start_tile
	var made := {"centro": null}
	for b in sim.buildings:
		if b.owner == h and b.type == "centro":
			made["centro"] = b
	if town_v:
		var spots := [["casa", Vector2i(-6, -7)], ["casa", Vector2i(-9, -4)], ["casa", Vector2i(-9, 0)], ["almacen", Vector2i(6, -8)], ["cuartel", Vector2i(8, 3)],
			["arqueria", Vector2i(-3, 8)], ["establo", Vector2i(4, 9)], ["herreria", Vector2i(-10, 6)], ["mercado", Vector2i(11, -5)], ["torre", Vector2i(13, 8)],
			["monasterio", Vector2i(-13, -9)], ["castillo", Vector2i(13, -13)]]
		for s in spots:
			var t := _free_near(sim, base + (s[1] as Vector2i), s[0], h)
			if t.x >= 0:
				var bb: Ent = sim._spawn_building(s[0], h, t, true)
				if not made.has(s[0]):
					made[s[0]] = bb
		var types := ["alabardero", "arquero", "caballero", "espadachin", "monje", "aldeano", "aldeano", "aldeano"]
		var col := 0
		for ty in types:
			var tile := sim.nearest_free_tile(base + Vector2i(-5 + col * 2, 4), 5)
			if Defs.UNITS.has(ty):
				sim._spawn_unit(ty, h, tile)
			col += 1
		for ty in ["espadachin", "arquero"]:
			var tile := sim.nearest_free_tile(base + Vector2i(-2 + col, 6), 5)
			if Defs.UNITS.has(ty):
				sim._spawn_unit(ty, 1, tile)
			col += 1
	for j in 4:
		sim.step()
	game.focus_on(sim.tile_center(base + cam_off))
	game.zoom = zoom_v
	game.l_fog.visible = fog_v
	if select_t != "none" and made.has(select_t) and made[select_t] != null:
		game.select_ents([made[select_t]])
	elif select_t != "none":
		var found: Array = []
		for u in sim.units:
			if u.owner == h and u.type == select_t:
				found.append(u)
				break
		if not found.is_empty():
			game.select_ents(found)
	game.night = night_v
	game.hud.visible = hud_v
	await _ui_state(made)
	game.paused = true
	game.anim_t = 1.234
	game.interp = 0.0
	game._dirty = 3
	for j in 5:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(shot_path)
	print("INFO captura ", shot_path, " edificios ", made.keys())
	print("INFO llamadas de dibujo en el último fotograma: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "  objetos: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	get_tree().quit()
