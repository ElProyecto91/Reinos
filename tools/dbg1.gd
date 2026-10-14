extends SceneTree
func _init():
	var sim := Sim.new()
	sim.setup({"size": 192, "seed": 5, "players": [{"human": false, "team": 0, "diff": 1}, {"human": false, "team": 1, "diff": 1}], "events": false})
	for s in int(300.0 / Sim.DT):
		sim.step()
	for b in sim.buildings:
		if b.owner == 1:
			print("B ", b.type, " tile ", b.tile, " prog ", snappedf(b.progress, 0.01), " hp ", int(b.hp), " builders ", b.builders)
	var st := {}
	for u in sim.units:
		if u.owner == 1 and u.type == "aldeano":
			var k := "%d:%s" % [u.state, u.carry_kind]
			st[k] = int(st.get(k, 0)) + 1
			if u.state == Sim.S_BUILD_GO or u.state == Sim.S_BUILD:
				print("builder ", u.id, " state ", u.state, " pos ", sim.tile_of(u.pos), " target ", u.target_id, " goal ", u.goal, " path ", u.path.size(), " fails ", u.fails)
	print("villager states ", st)
	var p = sim.players[1]
	print("res ", p.res, " pop ", p.pop, "/", p.pop_cap, " reserved ", p.reserved)
	quit()
