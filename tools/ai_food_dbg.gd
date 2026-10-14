extends SceneTree
## Depura por qué una IA no consigue comida: seed=N player=0 sec=400
func _init() -> void:
	var sd := 3
	var pl := 0
	var sec := 400.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): sd = int(a.substr(5))
		elif a.begins_with("player="): pl = int(a.substr(7))
		elif a.begins_with("sec="): sec = float(a.substr(4))
	var sim := Sim.new()
	var plist: Array = []
	for i in 4:
		plist.append({"human": false, "team": i, "diff": 1, "name": "P%d" % i})
	sim.setup({"size": 192, "seed": sd, "events": false, "players": plist})
	for i in int(sec / Sim.DT):
		sim.step()
	var p: Player = sim.players[pl]
	print("start ", p.start_tile, " heat ", sim.heat[p.start_tile.y * sim.W + p.start_tile.x], " res ", p.res)
	var states := {}
	var kinds := {}
	for u in sim.units:
		if u.owner == pl and u.type == "aldeano":
			states[u.state] = int(states.get(u.state, 0)) + 1
			kinds[u.carry_kind] = int(kinds.get(u.carry_kind, 0)) + 1
	var nv := 0
	var nm := 0
	for u in sim.units:
		if u.owner == pl:
			if u.type == "aldeano": nv += 1
			else: nm += 1
	print("age ", p.age, " aging ", p.aging, " vills ", nv, " military ", nm, " res ", p.res)
	print("villager states ", states, " carry kinds ", kinds)
	for u in sim.units:
		if u.owner == pl and u.type == "aldeano" and u.carry_kind == "food":
			var tt: Vector2i = u.target_tile
			var rt := -1
			var ra := -1
			if sim.in_bounds(tt):
				rt = sim.rtype[tt.y * sim.W + tt.x]
				ra = sim.ramt[tt.y * sim.W + tt.x]
			print("  vill ", u.id, " st ", u.state, " tile ", sim.tile_of(u.pos), " tgt ", tt, " rtype ", rt, " amt ", ra, " carry ", u.carry_amt, " d_base ", snappedf(Vector2(tt - p.start_tile).length(), 0.1))
	var gold_d: Array = []
	for i in sim.W * sim.H:
		if sim.rtype[i] == Defs.R_GOLD:
			var gt := Vector2i(i % sim.W, i / sim.W)
			gold_d.append([snappedf(Vector2(gt - p.start_tile).length(), 0.1), gt, sim.comp[i] == sim.comp[p.start_tile.y * sim.W + p.start_tile.x]])
	gold_d.sort_custom(func(a, b): return a[0] < b[0])
	print("gold nearest ", gold_d.slice(0, 4))
	for u in sim.units:
		if u.owner == pl and u.type == "aldeano" and u.carry_kind == "gold":
			print("  gvill ", u.id, " st ", u.state, " tile ", sim.tile_of(u.pos), " tgt ", u.target_tile, " carry ", u.carry_amt)
	var okc := {}
	for dy in range(-20, 21):
		for dx in range(-20, 21):
			var r := int(Vector2(dx, dy).length())
			if sim.can_place("casa", p.start_tile + Vector2i(dx, dy)):
				okc[r / 4 * 4] = int(okc.get(r / 4 * 4, 0)) + 1
	print("casa spots by radius bucket ", okc, " pop ", p.pop, "/", p.pop_cap, " base ", p.start_tile)
	for b in sim.buildings:
		if b.owner == pl and b.progress < 1.0:
			print("  unfinished ", b.type, " tile ", b.tile, " progress ", b.progress, " builders ", b.builders)
	for u in sim.units:
		if u.owner == pl and u.type == "aldeano" and (u.state == Sim.S_BUILD or u.state == Sim.S_BUILD_GO):
			print("  builder ", u.id, " st ", u.state, " at ", sim.tile_of(u.pos), " target_id ", u.target_id, " fails ", u.fails, " path ", u.path.size(), " pos ", u.pos / Defs.TILE, " off ", u.off, " dist_tiles ", (sim.get_ent(u.target_id).dist_to(u.pos) / Defs.TILE if sim.get_ent(u.target_id) != null else -1.0), " goal ", u.goal, " pend ", u.path_pending)
	for y in range(p.start_tile.y - 10, p.start_tile.y + 10):
		var row := ""
		for x in range(p.start_tile.x - 14, p.start_tile.x + 14):
			var i := y * sim.W + x
			var ch := "."
			if sim.terrain[i] == Defs.T_WATER: ch = "~"
			elif sim.terrain[i] == Defs.T_ROCK: ch = "^"
			elif sim.rtype[i] == Defs.R_FARM: ch = "f"
			elif sim.rtype[i] == Defs.R_TREE: ch = "T"
			elif sim.rtype[i] == Defs.R_GOLD: ch = "G"
			elif sim.rtype[i] != 0: ch = "r"
			elif sim.solid[i] == 1: ch = "#"
			elif sim.terrain[i] == Defs.T_SAND: ch = ","
			row += ch
		print("MAP ", row)
	var farms := 0
	var berries := 0
	var fish := 0
	var trees_near := 0
	for i in sim.W * sim.H:
		var t := Vector2i(i % sim.W, i / sim.W)
		if t.distance_to(Vector2(p.start_tile)) > 30.0:
			continue
		if sim.rtype[i] == Defs.R_FARM and sim.rowner[i] == pl:
			farms += 1
		elif sim.rtype[i] == Defs.R_BERRY:
			berries += 1
		elif sim.rtype[i] == Defs.R_FISH:
			fish += 1
		elif sim.rtype[i] == Defs.R_TREE:
			trees_near += 1
	print("farms ", farms, " berries(r<30) ", berries, " fish ", fish, " trees ", trees_near, " gathered ", p.gathered)
	var bl := {}
	for b in sim.buildings:
		if b.owner == pl:
			bl[b.type] = int(bl.get(b.type, 0)) + 1
	print("buildings ", bl)
	quit()
