extends SceneTree
# Simula partidas IA contra IA en headless y muestra el progreso.
func _init():
	var args := OS.get_cmdline_user_args()
	var seed_v := 5
	var minutes := 20.0
	var nplayers := 2
	var size := 192
	var diffs := [1, 1, 1, 1]
	for a in args:
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		if a.begins_with("min="): minutes = float(a.substr(4))
		if a.begins_with("n="): nplayers = int(a.substr(2))
		if a.begins_with("size="): size = int(a.substr(5))
		if a.begins_with("diff="):
			var parts := a.substr(5).split(",")
			for i in parts.size(): diffs[i] = int(parts[i])
	var sim := Sim.new()
	sim.profiling = true
	var plist: Array = []
	for i in nplayers:
		plist.append({"human": false, "team": i, "diff": diffs[i]})
	var t0 := Time.get_ticks_msec()
	var ok := sim.setup({"size": size, "seed": seed_v, "players": plist, "events": false})
	print("setup ok=", ok, " in ", Time.get_ticks_msec() - t0, " ms")
	if not ok:
		quit(1)
		return
	var steps := int(minutes * 60.0 / Sim.DT)
	var tstart := Time.get_ticks_msec()
	var worst := 0
	for s in steps:
		var ts := Time.get_ticks_usec()
		sim.step()
		var d := Time.get_ticks_usec() - ts
		if d > worst: worst = d
		if s % int(60.0 / Sim.DT) == 0:
			var sm := sim.summary()
			var line := "t=%ds " % int(sm["time"])
			for pl in sm["players"]:
				line += "| P%d %s a%d pop %d/%d v%d m%d f%d w%d g%d k%d %s " % [pl.i, "V" if pl.alive else "X", pl.age, pl.pop, pl.cap, pl.vill, pl.mil, pl.res.food, pl.res.wood, pl.res.gold, pl.kills, str(pl.b)]
			print(line)
		if sim.game_over:
			print("GAME OVER at t=", sim.time, " winner team ", sim.winner_team)
			break
	var el := Time.get_ticks_msec() - tstart
	print("PROF us: ", sim.prof, " bfs calls ", sim.bfs_calls, " nodes ", sim.bfs_nodes)
	print("wall ms: ", el, " for sim seconds: ", sim.time, " avg step us: ", float(el) * 1000.0 / float(sim.step_count), " worst step us: ", worst, " ents: ", sim.ents.size())
	quit()
