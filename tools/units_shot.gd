extends Node
## Captura de gente, caballería, ariete y barcos juntos, y del puerto con su muelle.
## args: seed=N zoom=1.6 out=/tmp/units.png mode=idle|walk
var game: Game
var seed_v := 1
var zoom_v := 1.6
var out := "/tmp/units.png"
var mode := "idle"
var _started := false

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("zoom="): zoom_v = float(a.substr(5))
		elif a.begins_with("out="): out = a.substr(4)
		elif a.begins_with("mode="): mode = a.substr(5)
	Settings.ensure_loaded()
	Settings.auto_pause = false
	Settings.apply_display(get_window())
	var pl: Array = [{"human": true, "team": 0, "diff": 1, "name": "Tú"}, {"human": false, "team": 1, "diff": 1, "name": "IA"}]
	game = Game.new()
	add_child(game)
	game.start({"size": 128, "seed": seed_v, "events": true, "players": pl})

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func _run() -> void:
	await get_tree().create_timer(0.3).timeout
	var sim := game.sim
	sim.ais.clear()
	var p: Player = sim.players[0]
	p.res = {"food": 5000, "wood": 5000, "gold": 5000, "stone": 5000}
	p.pop_cap = 120
	p.age = 1
	var base: Vector2i = p.start_tile
	var spot := Vector2i(-1, -1)
	var bd := 1e9
	for y in range(maxi(1, base.y - 45), mini(sim.H - 4, base.y + 45)):
		for x in range(maxi(1, base.x - 45), mini(sim.W - 4, base.x + 45)):
			var t := Vector2i(x, y)
			if sim.can_place("puerto", t, 0) and sim.can_reach_building(sim.nearest_free_tile(base + Vector2i(0, 3), 6), "puerto", t):
				var d := Vector2(t - base).length()
				if d < bd:
					bd = d
					spot = t
	var vills: Array = []
	for u in sim.units:
		if u.owner == 0 and u.type == "aldeano":
			vills.append(u.id)
	var port: Ent = sim.get_ent(sim.cmd_build(0, vills, "puerto", spot))
	for i in int(90.0 / Sim.DT):
		sim.step()
	for t in ["barco_pesca", "barco_transporte", "galera", "galeon"]:
		sim.cmd_train(0, port.id, t)
	for i in int(120.0 / Sim.DT):
		sim.step()
	# soldados de los dos equipos en fila cerca del puerto
	var types := ["aldeano", "piquero", "espadachin", "arquero", "ballestero", "explorador", "jinete", "caballero", "ariete"]
	var row := 0
	for owner in [0, 1]:
		var col := 0
		for t in types:
			var tile := sim.nearest_free_tile(spot + Vector2i(-6 + col * 2, -5 - row * 3), 4)
			var e := sim._spawn_unit(t, owner, tile)
			if e != null and mode == "walk":
				sim.cmd_move(owner, [e.id], tile + Vector2i(3, 2), false) if owner == 0 else sim.cmd_move(owner, [e.id], tile + Vector2i(-3, 2), false)
			col += 1
		row += 1
	for i in 6:
		sim.step()
	sim.events.clear()
	game.zoom = zoom_v
	game.cam_pos = sim.tile_center(spot + Vector2i(1, -4))
	game.l_fog.visible = false
	game.paused = true
	game.hud.visible = false
	game.hud.set_process(false)
	await get_tree().create_timer(0.5).timeout
	for k in 3:
		game.l_ents.queue_redraw()
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out, " port ", spot, " dock ", port.dock_tile, " orient ", port.orient)
	get_tree().quit()
