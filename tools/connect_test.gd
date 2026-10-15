extends SceneTree
## Comprueba que desde cada base se puede llegar andando (con las rutas reales: árboles, minas y bayas son sólidos)
## a todas las demás. Uso: godot --headless --script res://tools/connect_test.gd -- seeds=30 sizes=128,192,256 players=2,3,4
func _init() -> void:
	var nseeds := 30
	var sizes: Array = [128, 192, 256]
	var plays: Array = [2, 3, 4]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="): nseeds = int(a.substr(6))
		if a.begins_with("sizes="):
			sizes = []
			for s in a.substr(6).split(","): sizes.append(int(s))
		if a.begins_with("players="):
			plays = []
			for s in a.substr(8).split(","): plays.append(int(s))
	var total := 0
	var bad := 0
	var carved := 0
	for size in sizes:
		for n in plays:
			for sd in range(1, nseeds + 1):
				var plist: Array = []
				for i in n:
					plist.append({"human": i == 0, "team": i, "diff": 1})
				var sim := Sim.new()
				if not sim.setup({"size": size, "seed": sd, "players": plist, "events": false}):
					continue
				total += 1
				carved += int(sim.map_info.get("carved_trees", 0))
				var fails := _check(sim)
				if fails > 0:
					bad += 1
					print("SIN CAMINO size=%d n=%d seed=%d pares_rotos=%d" % [size, n, sd, fails])
	print("RESULT mapas=%d sin_camino=%d arboles_talados_en_total=%d" % [total, bad, carved])
	quit(0 if bad == 0 else 1)

func _check(sim: Sim) -> int:
	## Todas las casillas libres de la corona del centro urbano de cada base deben estar conectadas entre sí y con las demás bases.
	var fails := 0
	var ref := Vector2i(-1, -1)
	for p in sim.players:
		var s: Vector2i = p.start_tile
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if maxi(absi(dx), absi(dy)) != 2:
					continue
				var q := s + Vector2i(dx, dy)
				if not sim.in_bounds(q) or sim.astar.is_point_solid(q):
					continue
				if ref.x < 0:
					ref = q
				elif sim.astar.get_id_path(ref, q, false).is_empty():
					fails += 1
	return fails
