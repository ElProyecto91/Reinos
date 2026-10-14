extends SceneTree
## Depuración: 3 aldeanos construyen una fila de 8 murallas.
func _initialize() -> void:
	var sim := Sim.new()
	var cfg := {"size": 128, "seed": 11, "events": false, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "A"},
		{"human": false, "team": 1, "diff": 0, "name": "B"}]}
	sim.setup(cfg)
	sim.ais.clear()
	var p: Player = sim.players[0]
	p.res = {"food": 2000, "wood": 2000, "gold": 2000}
	p.age = 1
	var s0: Vector2i = p.start_tile
	var a := Vector2i(-1, -1)
	for dy in range(5, 12):
		for dx in range(-10, 4):
			var ok := true
			for i in 8:
				if not sim.can_place("muralla", s0 + Vector2i(dx + i, dy), 0):
					ok = false
					break
			if ok and a.x < 0:
				a = s0 + Vector2i(dx, dy)
	var vs: Array = []
	for u in sim.units:
		if u.owner == 0 and u.type == "aldeano":
			vs.append(u.id)
	vs = vs.slice(0, 3)
	var tiles: Array = []
	for i in 8:
		tiles.append(a + Vector2i(i, 0))
	print("start ", s0, " row ", a, " units ", vs)
	for id in vs:
		print("  unit ", id, " at ", sim.tile_of(sim.get_ent(id).pos))
	print("placed ", sim.cmd_build_wall(0, vs, "muralla", tiles))
	for step in 600:
		sim.step()
		if step == 66:
			var u3: Ent = sim.get_ent(vs[0])
			var st := sim.tile_of(u3.pos)
			var g := Vector2i(32, 29)
			print("DBG occ ", sim.occ[g.y * sim.W + g.x], " solid32,29 ", sim.solid[g.y * sim.W + g.x], " solid31,29 ", sim.solid[29 * sim.W + 31], " solid 32,28 ", sim.solid[28 * sim.W + 32], " e.fail_goal ", u3.fail_goal, " fail_time ", u3.fail_time, " time ", sim.time)
			print("DBG comp start ", sim.comp[st.y * sim.W + st.x], " goal ", sim.comp[g.y * sim.W + g.x])
			print("DBG path_into ", sim._path_into(st, g), " astar_solid(32,28) ", sim.astar.is_point_solid(Vector2i(32, 28)), " diag ", sim.astar.diagonal_mode)
		if step >= 20 and step <= 100 and step % 4 == 0:
			var u2: Ent = sim.get_ent(vs[0])
			print("  s", step, " u2 st", u2.state, " tgt ", u2.target_id, " pos ", u2.pos / Defs.TILE, " path ", u2.path, " pend ", u2.path_pending, " fails ", u2.fails, " goal ", u2.goal)
		if step % 100 == 0:
			var info := ""
			for id in vs:
				var u: Ent = sim.get_ent(id)
				info += " [st%d t%d %s fails%d]" % [u.state, u.target_id, str(sim.tile_of(u.pos)), u.fails]
			var pr := ""
			for b in sim.buildings:
				if b.owner == 0 and b.type == "muralla":
					pr += " %.2f" % b.progress
			print("step ", step, info, " |", pr)
	quit()
