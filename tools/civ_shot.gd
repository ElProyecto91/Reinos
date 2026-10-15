extends Node
## Capturas de civilizaciones en juego: las 8 unidades únicas, el botón de habilidad y el fuego de los bizantinos.
## Uso: xvfb-run -a godot --path . res://tools/civ_shot.tscn --rendering-driver opengl3 --resolution 1280x720 -- shot=/tmp/c.png civ=bizantinos mode=units|fire|ready zoom=1.6
var game: Game
var _started := false
var shot_path := "/tmp/civ.png"
var civ := "bizantinos"
var mode := "units"
var zoom_v := 1.6
var seed_v := 4

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="): shot_path = a.substr(5)
		elif a.begins_with("civ="): civ = a.substr(4)
		elif a.begins_with("mode="): mode = a.substr(5)
		elif a.begins_with("zoom="): zoom_v = float(a.substr(5))
		elif a.begins_with("seed="): seed_v = int(a.substr(5))
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.auto_pause = false
	Settings.apply_display(get_window())
	var cfg := {"size": 128, "seed": seed_v, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú", "civ": civ},
		{"human": false, "team": 1, "diff": 0, "name": "Rojo", "civ": "mongoles" if civ != "mongoles" else "francos"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)
	game.paused = true

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var sim := game.sim
	var h := game.human
	sim.ais.clear()
	var p: Player = sim.players[h]
	p.age = 2
	p.res = {"food": 900, "wood": 900, "gold": 900}
	p.pop_cap = 300
	var base: Vector2i = p.start_tile
	var made_c: Ent = null
	for r in range(6, 24):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if made_c == null and maxi(absi(dx), absi(dy)) == r and sim.can_place("castillo", base + Vector2i(dx, dy - 4), h):
					made_c = sim._spawn_building("castillo", h, base + Vector2i(dx, dy - 4), true)
	var cam := base + Vector2i(0, -2)
	if mode == "units":
		# las 8 únicas, una fila con el color propio y otra con el del rival
		var row := 0
		for owner in [h, 1]:
			var col := 0
			for id in Civs.IDS:
				var tile := sim.nearest_free_tile(base + Vector2i(-9 + col * 2, 2 + row * 3), 5)
				sim._spawn_unit(Civs.unique_of(id), owner, tile)
				col += 1
			row += 1
		cam = base + Vector2i(-1, 3)
	elif mode == "fire":
		# un grupo enemigo dentro de una zona de fuego y el botón de habilidad recargando
		var c := base + Vector2i(7, 3)
		for i in 8:
			var tile := sim.nearest_free_tile(c + Vector2i(i % 4 - 2, i / 4 - 1), 4)
			sim._spawn_unit("espadachin" if i % 2 == 0 else "arquero", 1, tile)
		for i in 5:
			var tile2 := sim.nearest_free_tile(base + Vector2i(-2 + i, 2), 4)
			sim._spawn_unit("caballero" if i % 2 == 0 else "alabardero", h, tile2)
		for j in 3:
			sim.step()
		var res := sim.cmd_ability(h, c)
		print("INFO habilidad ", res)
		for j in 18:
			sim.step()
		cam = base + Vector2i(3, 1)
	else:
		for i in 6:
			var tile3 := sim.nearest_free_tile(base + Vector2i(-3 + i * 2, 3), 4)
			sim._spawn_unit(Civs.unique_of(civ) if i % 2 == 0 else "espadachin", h, tile3)
		cam = base + Vector2i(0, 1)
	for j in 4:
		sim.step()
	game.cam_pos = sim.tile_center(cam)
	game.zoom = zoom_v
	game.l_fog.visible = false
	if made_c != null and mode == "ready":
		game.select_ents([made_c])
	game.hud.refresh_now()
	game.night = 0.0
	game.paused = true
	game.anim_t = 1.234
	game.interp = 0.0
	game._dirty = 3
	for j in 5:
		await get_tree().process_frame
	game.hud.refresh_now()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(shot_path)
	print("INFO captura ", shot_path)
	get_tree().quit()
