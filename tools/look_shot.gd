extends Node
## Capturas del aspecto del mundo (terreno, árboles, costa, montaña, desierto) a mediodía, sin niebla ni HUD.
## Uso: xvfb-run -a godot --path . res://tools/look_shot.tscn --rendering-driver opengl3 --resolution 1280x720 -- tag=base seed=4 size=192 zoom=1.6 [bench=120]
## Escribe /tmp/look_<tag>_<coast|forest|desert|mountain|snow>.png (sólo los sitios que el mapa tenga).
var game: Game
var _started := false
var tag := "base"
var seed_v := 4
var size_v := 192
var zoom_v := 1.6
var bench_n := 0          # bench=N: además mide ms por fotograma redibujando N veces cada sitio

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tag="): tag = a.substr(4)
		elif a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("size="): size_v = int(a.substr(5))
		elif a.begins_with("zoom="): zoom_v = float(a.substr(5))
		elif a.begins_with("bench="): bench_n = int(a.substr(6))
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.auto_pause = false
	Settings.apply_display(get_window())
	var cfg := {"size": size_v, "seed": seed_v, "events": true, "players": [
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

## Cuenta casillas de cada clase en un cuadrado de radio r alrededor de t (muestreo cada 2).
func _census(sim: Sim, t: Vector2i, r: int) -> Dictionary:
	var c := {"water": 0, "tree": 0, "rock": 0, "sand": 0, "hot": 0, "cold": 0, "n": 0}
	for dy in range(-r, r + 1, 2):
		for dx in range(-r, r + 1, 2):
			var q := t + Vector2i(dx, dy)
			if not sim.in_bounds(q):
				continue
			var i := q.y * sim.W + q.x
			c["n"] += 1
			var ter: int = sim.terrain[i]
			if ter == Defs.T_WATER: c["water"] += 1
			elif ter == Defs.T_ROCK: c["rock"] += 1
			elif ter == Defs.T_SAND: c["sand"] += 1
			if sim.rtype[i] == Defs.R_TREE: c["tree"] += 1
			if sim.heat[i] > 190: c["hot"] += 1
			if sim.heat[i] < 65: c["cold"] += 1
	return c

func _best(sim: Sim, fn: Callable, margin: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bs := 0.0
	for y in range(margin, sim.H - margin, 4):
		for x in range(margin, sim.W - margin, 4):
			var t := Vector2i(x, y)
			if sim.terrain[y * sim.W + x] == Defs.T_WATER:
				continue
			var s: float = fn.call(_census(sim, t, 8))
			if s > bs:
				bs = s
				best = t
	return best if bs > 0.0 else Vector2i(-1, -1)

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var sim := game.sim
	sim.ais.clear()
	var sites := {
		"coast": _best(sim, func(c: Dictionary) -> float: return minf(float(c["water"]), float(c["tree"]) * 1.5) if c["water"] > 12 and c["tree"] > 5 else 0.0, 14),
		"forest": _best(sim, func(c: Dictionary) -> float: return float(c["tree"]) if c["water"] == 0 and c["rock"] == 0 and c["hot"] == 0 and c["cold"] == 0 else 0.0, 14),
		"desert": _best(sim, func(c: Dictionary) -> float: return float(c["hot"]) if c["water"] < 4 and c["hot"] > 20 else 0.0, 14),
		"mountain": _best(sim, func(c: Dictionary) -> float: return minf(float(c["rock"]), float(c["tree"]) * 2.0) if c["rock"] > 10 and c["tree"] > 3 else 0.0, 14),
		"snow": _best(sim, func(c: Dictionary) -> float: return float(c["cold"]) if c["water"] < 4 and c["cold"] > 20 else 0.0, 14),
	}
	# mediodía, cielo despejado, sin niebla ni interfaz
	sim.time = 108.0
	game._atmosphere()
	game.canvas_mod.color = Color(1, 1, 1, 1)
	game._rain_rect.visible = false
	game._sky_mat.set_shader_parameter("cover", 0.0)
	game.night = 0.0
	game.l_fog.visible = false
	game.hud.root.visible = false
	game.paused = true
	game.anim_t = 1.234
	game.interp = 0.5
	for k in sites:
		var s: Vector2i = sites[k]
		if s.x < 0:
			print("INFO sin sitio para ", k)
			continue
		print("INFO ", k, " en ", s)
		game.cam_pos = sim.tile_center(s)
		game.zoom = zoom_v
		game._consume_events()
		game._dirty = 3
		for j in 5:
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		var path := "/tmp/look_%s_%s.png" % [tag, k]
		get_viewport().get_texture().get_image().save_png(path)
		print("INFO captura ", path)
		if bench_n > 0:
			var t0 := Time.get_ticks_usec()
			for j in bench_n:
				game._dirty = 3
				await get_tree().process_frame
			print("BENCH %s %.2f ms/fotograma" % [k, float(Time.get_ticks_usec() - t0) / 1000.0 / float(bench_n)])
	get_tree().quit()
