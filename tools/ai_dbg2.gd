extends SceneTree
func _init() -> void:
	var seed_v := 1
	var size := 192
	var who := 2
	var minutes := 10.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		if a.begins_with("who="): who = int(a.substr(4))
		if a.begins_with("min="): minutes = float(a.substr(4))
	var sim := Sim.new()
	sim.profiling = true
	var plist: Array = []
	for i in 3:
		plist.append({"human": false, "team": i, "diff": 1})
	sim.setup({"size": size, "seed": seed_v, "players": plist, "events": false})
	for s in int(minutes * 60.0 / Sim.DT):
		sim.step()
	var p: Player = sim.players[who]
	print("res ", p.res, " start ", p.start_tile)
	var by_state := {}
	for u in sim.units:
		if u.owner == who and u.type == "aldeano":
			var k := "st%d_%s" % [u.state, u.carry_kind]
			by_state[k] = int(by_state.get(k, 0)) + 1
	print("states ", by_state)
	var n := 0
	for u in sim.units:
		if u.owner == who and u.type == "aldeano" and u.state == Sim.S_GATHER_GO and n < 6:
			n += 1
			print("v ", u.id, " at ", sim.tile_of(u.pos), " target ", u.target_tile, " kind ", u.carry_kind, " rt ", sim.rtype[u.target_tile.y * sim.W + u.target_tile.x], " fails ", u.fails, " pathlen ", u.path.size(), " pending ", u.path_pending, " goal ", u.goal, " comp_v ", sim.comp[sim.tile_of(u.pos).y*sim.W+sim.tile_of(u.pos).x], " comp_t ", sim.comp[u.target_tile.y*sim.W+u.target_tile.x])
	# mapa ASCII alrededor de la base
	var c: Vector2i = p.start_tile
	for y in range(c.y - 16, c.y + 12):
		var line := ""
		for x in range(c.x - 16, c.x + 20):
			var t := Vector2i(x, y)
			if not sim.in_bounds(t):
				line += " "
				continue
			var i := y * sim.W + x
			var ch := "."
			if sim.terrain[i] == Defs.T_WATER: ch = "~"
			elif sim.terrain[i] == Defs.T_ROCK: ch = "^"
			if sim.rtype[i] == Defs.R_TREE: ch = "T"
			elif sim.rtype[i] == Defs.R_GOLD: ch = "g"
			elif sim.rtype[i] == Defs.R_BERRY: ch = "b"
			elif sim.rtype[i] == Defs.R_FARM: ch = "f"
			if sim.occ[i] != 0:
				var b: Ent = sim.ents.get(sim.occ[i])
				ch = String(b.type).substr(0, 1).to_upper() if b != null else "#"
			for u in sim.units:
				if u.alive and sim.tile_of(u.pos) == t and u.owner == who:
					ch = "v" if u.type == "aldeano" else "m"
			line += ch
		print(line)
	quit()
