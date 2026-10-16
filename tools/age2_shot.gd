extends Node
## Captura de la Edad de los Castillos: castillo, monasterio y las unidades nuevas en una aldea.
## Uso: xvfb-run -a godot --path . res://tools/age2_shot.tscn --rendering-driver opengl3 --resolution 1280x720 -- shot=/tmp/a.png zoom=1.5 select=castillo|monasterio|none night=0
var game: Game
var _started := false
var shot_path := "/tmp/age2.png"
var zoom_v := 1.5
var select_t := "none"
var night_v := 0.0
var seed_v := 4
var cam_off := Vector2i(0, -2)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="): shot_path = a.substr(5)
		elif a.begins_with("zoom="): zoom_v = float(a.substr(5))
		elif a.begins_with("select="): select_t = a.substr(7)
		elif a.begins_with("night="): night_v = float(a.substr(6))
		elif a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("cam="):
			var q := a.substr(4).split(",")
			cam_off = Vector2i(int(q[0]), int(q[1]))
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.auto_pause = false
	Settings.apply_display(get_window())
	var cfg := {"size": 128, "seed": seed_v, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 0, "name": "Rojo"}]}
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

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var sim := game.sim
	var h := game.human
	sim.ais.clear()
	var p: Player = sim.players[h]
	p.age = 2
	p.res = {"food": 900, "wood": 900, "gold": 900, "stone": 900}
	p.pop_cap = 300
	var base: Vector2i = p.start_tile
	var spots := {"castillo": Vector2i(8, -9), "monasterio": Vector2i(-11, -8), "cuartel": Vector2i(-12, 5), "arqueria": Vector2i(-6, 9), "establo": Vector2i(2, 10), "taller": Vector2i(10, 6), "torre": Vector2i(15, -2)}
	var made := {}
	for k in spots:
		var t := _free_near(sim, base + spots[k], k, h)
		if t.x >= 0:
			made[k] = sim._spawn_building(k, h, t, true)
		else:
			print("SIN SITIO ", k)
	# unidades de la 3ª edad, en filas de dos equipos
	var types := ["alabardero", "hostigador", "arquero_caballo", "monje", "catapulta", "trabuquete", "espadachin", "ballestero", "caballero"]
	var row := 0
	for owner in [h, 1]:
		var col := 0
		for ty in types:
			var tile := sim.nearest_free_tile(base + Vector2i(-9 + col * 2, 1 + row * 3), 5)
			var u := sim._spawn_unit(ty, owner, tile)
			if u != null and owner == h and col % 2 == 0:
				sim.cmd_move(h, [u.id], tile + Vector2i(2, 1))
			col += 1
		row += 1
	for j in 4:
		sim.step()
	game.cam_pos = sim.tile_center(base + cam_off)
	game.zoom = zoom_v
	game.l_fog.visible = false
	if select_t != "none" and made.has(select_t):
		game.select_ents([made[select_t]])
	game.night = night_v
	game.paused = true
	game.anim_t = 1.234
	game.interp = 0.0
	game._dirty = 3
	for j in 5:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(shot_path)
	print("INFO captura ", shot_path, " edificios ", made.keys())
	get_tree().quit()
