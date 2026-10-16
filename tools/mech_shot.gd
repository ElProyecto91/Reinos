extends Node
## Capturas de las mecánicas nuevas: caza, piedra, herrería y mejoras, mercado y guarnición.
## Uso: xvfb-run -a godot --path . res://tools/mech_shot.tscn --rendering-driver opengl3 --resolution 1280x720 -- shot=/tmp/m.png mode=hunt|stone|forge|market|garrison seed=4 zoom=1.5
var game: Game
var _started := false
var shot_path := "/tmp/mech.png"
var mode := "forge"
var zoom_v := 1.5
var seed_v := 4

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="): shot_path = a.substr(5)
		elif a.begins_with("mode="): mode = a.substr(5)
		elif a.begins_with("zoom="): zoom_v = float(a.substr(5))
		elif a.begins_with("seed="): seed_v = int(a.substr(5))
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.auto_pause = false
	Settings.apply_display(get_window())
	var cfg := {"size": 128, "seed": seed_v, "events": true, "players": [
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

func _near(sim: Sim, rt: int, from: Vector2i, reach_from: Vector2i) -> Vector2i:
	## casilla de ese recurso más cercana a `from` a la que se puede llegar andando desde `reach_from`
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for i in sim.W * sim.H:
		if sim.rtype[i] != rt:
			continue
		var t := Vector2i(i % sim.W, i / sim.W)
		var d := Vector2(t - from).length()
		if d < bd and sim.comp[i] == sim.comp[reach_from.y * sim.W + reach_from.x]:
			bd = d
			best = t
	return best

func _spot(sim: Sim, type: String, h: int, base: Vector2i, rmin: int, prefer: Vector2i = Vector2i(0, 0)) -> Ent:
	var best_t := Vector2i(-1, -1)
	var bd := 1e9
	for r in range(rmin, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := base + Vector2i(dx, dy)
				if sim.can_place(type, t, h):
					var d := Vector2(t - (base + prefer)).length()
					if d < bd:
						bd = d
						best_t = t
		if best_t.x >= 0:
			break
	if best_t.x < 0:
		return null
	return sim._spawn_building(type, h, best_t, true)

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var sim := game.sim
	var h := game.human
	sim.ais.clear()
	var p: Player = sim.players[h]
	p.age = 2
	p.res = {"food": 640, "wood": 820, "gold": 410, "stone": 235}
	p.pop_cap = 300
	var base: Vector2i = p.start_tile
	var cam := base
	var sel: Array = []
	if mode == "hunt":
		var d := _near(sim, Defs.R_DEER, base, base)
		if d.x < 0:
			d = _near(sim, Defs.R_BOAR, base, base)
		print("INFO ciervo en ", d, " base ", base)
		for i in 5:
			var tile := sim.nearest_free_tile(d + Vector2i(-3 + i, 3), 6)
			var u := sim._spawn_unit("aldeano", h, tile)
			sim.cmd_gather(h, [u.id], d)
		cam = d
		for j in 140:
			sim.step()
	elif mode == "stone":
		var st := _near(sim, Defs.R_STONE, base, base)
		print("INFO piedra en ", st, " base ", base)
		var alm := _spot(sim, "almacen", h, st, 3)
		for i in 5:
			var tile := sim.nearest_free_tile(st + Vector2i(-2 + i, 2), 6)
			var u := sim._spawn_unit("aldeano", h, tile)
			sim.cmd_gather(h, [u.id], st)
		cam = st
		for j in 220:
			sim.step()
	elif mode == "garrison":
		var tw := _spot(sim, "torre", h, base, 5, Vector2i(6, 0))
		var sold: Array = []
		for i in 5:
			var tile := sim.nearest_free_tile(tw.tile + Vector2i(-3 + i, 3), 5)
			sold.append(sim._spawn_unit("arquero", h, tile).id)
		sim.cmd_garrison(h, sold, tw.id)
		for j in 120:
			sim.step()
		# dos enemigos a tiro de la torre
		for i in 3:
			var tile2 := sim.nearest_free_tile(tw.tile + Vector2i(7 + i, 1), 5)
			var e := sim._spawn_unit("espadachin", 1, tile2)
			sim.cmd_attack(1, [e.id], tw.id)
		for j in 25:
			sim.step()
		sel = [tw]
		cam = tw.tile + Vector2i(3, 1)
	else:
		var fg := _spot(sim, "herreria", h, base, 5, Vector2i(-6, 0))
		var mk := _spot(sim, "mercado", h, base, 5, Vector2i(6, 1))
		for i in 6:
			var tile := sim.nearest_free_tile(base + Vector2i(-2 + i, 7), 5)
			sim._spawn_unit(["espadachin", "arquero", "caballero"][i % 3], h, tile)
		p.techs["forja_1"] = true
		sim._recalc_ups(h)
		sel = [fg if mode == "forge" else mk]
		cam = base + Vector2i(0, 1)
		for j in 10:
			sim.step()
	game.fog.update(sim, h)
	game.cam_pos = sim.tile_center(cam)
	game.zoom = zoom_v
	game.l_fog.visible = false
	if not sel.is_empty():
		game.select_ents(sel)
	game.night = 0.0
	game.paused = true
	game.anim_t = 1.234
	game.interp = 0.5
	game._dirty = 3
	for j in 5:
		await get_tree().process_frame
	game.hud.refresh_now()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(shot_path)
	print("INFO captura ", shot_path)
	get_tree().quit()
