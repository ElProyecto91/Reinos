extends SceneTree
## Depuración: aldeanos recolectando oro cerca de la base.
func _initialize() -> void:
	for seed_v in [7, 11, 3]:
		var sim := Sim.new()
		var cfg := {"size": 128, "seed": seed_v, "events": false, "players": [
			{"human": true, "team": 0, "diff": 1, "name": "A"},
			{"human": false, "team": 1, "diff": 0, "name": "B"}]}
		sim.setup(cfg)
		sim.ais.clear()
		var p: Player = sim.players[0]
		var s0: Vector2i = p.start_tile
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for y in sim.H:
			for x in sim.W:
				if sim.rtype[y * sim.W + x] == Defs.R_GOLD:
					var d := float((Vector2i(x, y) - s0).length())
					if d < bd:
						bd = d
						best = Vector2i(x, y)
		var vs: Array = []
		for u in sim.units:
			if u.owner == 0 and u.type == "aldeano":
				vs.append(u.id)
		print("seed ", seed_v, " start ", s0, " nearest gold ", best, " dist ", bd, " amt ", sim.ramt[best.y * sim.W + best.x])
		sim.cmd_gather(0, vs, best)
		var g0: int = p.res["gold"]
		for step in 1500:
			sim.step()
			if step % 300 == 0:
				var u: Ent = sim.get_ent(vs[0])
				print("  step ", step, " gold ", p.res["gold"], " u0 st", u.state, " carry ", u.carry_kind, " ", snappedf(u.carry_amt, 0.1), " pos ", sim.tile_of(u.pos), " tgt ", u.target_tile, " fails ", u.fails)
		print("  gold gained ", int(p.res["gold"]) - g0)
		var st: Dictionary = {}
		for id in vs:
			var uu: Ent = sim.get_ent(id)
			st[uu.state] = int(st.get(uu.state, 0)) + 1
		print("  states after: ", st, " of ", vs.size(), " villagers")
	quit()
