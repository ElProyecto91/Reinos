extends SceneTree
func _initialize() -> void:
	var sim := Sim.new()
	var cfg := {"size": 128, "seed": 7, "events": false, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "A"},
		{"human": false, "team": 1, "diff": 1, "name": "B"}]}
	sim.setup(cfg)
	sim.ais.clear()
	var tcA: Ent = null
	for bd in sim.buildings:
		if bd.owner == 0: tcA = bd
	var c := sim.tile_of(tcA.center())
	var R := 6
	var gate_tile := c + Vector2i(0, R)
	for x in range(-R, R + 1):
		for y in range(-R, R + 1):
			var t := c + Vector2i(x, y)
			if maxi(absi(x), absi(y)) == R and sim.can_place("muralla", t):
				if t == gate_tile:
					sim._spawn_building("puerta", 0, t, true)
				else:
					sim._spawn_building("muralla", 0, t, true)
	for y in range(-R - 7, R + 9):
		var line := ""
		for x in range(-R - 4, R + 5):
			var t := c + Vector2i(x, y)
			var i := t.y * sim.W + t.x
			var ch := "."
			if sim.terrain[i] == 0: ch = "~"
			elif sim.rtype[i] == 1: ch = "t"
			elif sim.rtype[i] == 2: ch = "g"
			elif sim.rtype[i] == 3: ch = "b"
			if sim.wall_tile[i] == 1: ch = "G" if sim.gate_tile[i] == 1 else "#"
			elif sim.occ[i] != 0: ch = "T"
			line += ch
		print(line)
	var out_tile := c + Vector2i(0, R + 5)
	print("c=", c, " out=", out_tile, " solid=", sim.is_solid_tile(out_tile))
	var p := sim.astar.get_id_path(c + Vector2i(0, 3), out_tile, false)
	print("path len ", p.size())
	quit(0)
