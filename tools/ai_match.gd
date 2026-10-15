extends SceneTree
## Enfrenta dos IAs y mide quién gana y cuánto dura la partida.
## Uso: godot --headless --script res://tools/ai_match.gd -- seed=3 size=128 min=60 p0=new p1=legacy d0=2 d1=2
## p0/p1: new (IA actual), legacy (IA de la versión anterior, tools/ai_legacy.gd).
func _init() -> void:
	var seed_v := 3
	var size := 128
	var minutes := 60.0
	var kinds := ["new", "legacy"]
	var diffs := [2, 2]
	var verbose := false
	var n_players := 2
	var peace := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("size="): size = int(a.substr(5))
		elif a.begins_with("min="): minutes = float(a.substr(4))
		elif a.begins_with("p0="): kinds[0] = a.substr(3)
		elif a.begins_with("p1="): kinds[1] = a.substr(3)
		elif a.begins_with("d0="): diffs[0] = int(a.substr(3))
		elif a.begins_with("d1="): diffs[1] = int(a.substr(3))
		elif a == "v": verbose = true
		elif a == "peace": peace = true       # nadie ataca: partida larguísima para medir deriva de rendimiento y memoria
		elif a.begins_with("n="): n_players = int(a.substr(2))
	var sim := Sim.new()
	var plist: Array = []
	for i in n_players:
		plist.append({"human": false, "team": i, "diff": diffs[i]})
	if not sim.setup({"size": size, "seed": seed_v, "players": plist, "events": false}):
		print("RESULT seed=%d SETUP_FAIL" % seed_v)
		quit(1)
		return
	sim.ais.clear()
	for i in n_players:
		if kinds[i] == "legacy":
			sim.ais.append(AiLegacy.new(sim, i, diffs[i]))
		else:
			sim.ais.append(AiPlayer.new(sim, i, diffs[i]))
	if peace:
		for a in sim.ais:
			a.attack_at = 1e12
			if "raid_at" in a:
				a.raid_at = 1e12
				a.navy_at = 1e12
	var steps := int(minutes * 60.0 / Sim.DT)
	var worst := 0
	var win_us := 0
	var win_n := 0
	var tsum := 0
	for s in steps:
		var t0 := Time.get_ticks_usec()
		sim.step()
		var d := Time.get_ticks_usec() - t0
		tsum += d
		win_us += d
		win_n += 1
		worst = maxi(worst, d)
		if peace and s % int(600.0 / Sim.DT) == 0 and s > 0:
			var sm0 := sim.summary()
			var l0 := "t=%dmin step_avg_us=%.0f mem_MB=%.1f ents=%d " % [int(sm0["time"] / 60.0), float(win_us) / float(win_n), float(OS.get_static_memory_usage()) / 1048576.0, sim.ents.size()]
			for pl in sm0["players"]:
				l0 += "| P%d pop %d/%d v%d m%d f%d w%d g%d b%d " % [pl.i, pl.pop, pl.cap, pl.vill, pl.mil, pl.res.food, pl.res.wood, pl.res.gold, int(str(pl.b).count(":"))]
			print(l0)
			win_us = 0
			win_n = 0
		if verbose and not peace and s % int(120.0 / Sim.DT) == 0 and s > 0:
			var sm := sim.summary()
			var line := "t=%ds " % int(sm["time"])
			for pl in sm["players"]:
				line += "| P%d%s pop %d/%d v%d m%d k%d b%d " % [pl.i, "" if pl.alive else "X", pl.pop, pl.cap, pl.vill, pl.mil, pl.kills, int(str(pl.b).count(":"))]
			print(line)
		if sim.game_over:
			break
	var sm2 := sim.summary()
	var line2 := "RESULT seed=%d size=%d p0=%s(d%d) p1=%s(d%d) over=%s winner=%d t=%.0fs " % [seed_v, size, kinds[0], diffs[0], kinds[1], diffs[1], str(sim.game_over), sim.winner_team, sim.time]
	for pl in sm2["players"]:
		line2 += "| P%d %s pop %d vill %d mil %d kills %d " % [pl.i, "V" if pl.alive else "X", pl.pop, pl.vill, pl.mil, pl.kills]
	line2 += "| avg_step_us %.0f worst_step_us %d" % [float(tsum) / maxf(1.0, float(sim.step_count)), worst]
	print(line2)
	quit()
