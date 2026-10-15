extends SceneTree
## Depura a la IA: ejecuta N minutos y muestra, por IA, ejército, oleadas y estado de las unidades.
func _init() -> void:
	var seed_v := 3
	var minutes := 16.0
	var size := 128
	var diffs := [2, 2]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		if a.begins_with("min="): minutes = float(a.substr(4))
		if a.begins_with("size="): size = int(a.substr(5))
		if a.begins_with("diff="):
			var parts := a.substr(5).split(",")
			for i in parts.size(): diffs[i] = int(parts[i])
	var sim := Sim.new()
	var plist: Array = []
	for i in diffs.size():
		plist.append({"human": false, "team": i, "diff": diffs[i]})
	if not sim.setup({"size": size, "seed": seed_v, "players": plist, "events": false}):
		quit(1)
		return
	var steps := int(minutes * 60.0 / Sim.DT)
	for s in steps:
		sim.step()
		if sim.game_over:
			break
		if s % int(120.0 / Sim.DT) == 0 and s > 0:
			_report(sim)
	_report(sim)
	quit()

func _report(sim: Sim) -> void:
	print("--- t=%d" % int(sim.time))
	for ai in sim.ais:
		var st := {}
		var army := 0
		var cx := 0.0
		var cy := 0.0
		for u in sim.units:
			if u.alive and u.owner == ai.pi and not u.naval and u.is_military():
				army += 1
				st[u.state] = int(st.get(u.state, 0)) + 1
				cx += u.pos.x
				cy += u.pos.y
		if army > 0:
			cx /= army * 32.0
			cy /= army * 32.0
		var p: Player = sim.players[ai.pi]
		print("AI%d diff%d army %d states %s centro(%.0f,%.0f) start %s wave %d active %s attack_at %.0f need %d target %d kills %d" % [ai.pi, ai.diff, army, str(st), cx, cy, str(p.start_tile), ai.wave, str(ai.wave_active), ai.attack_at, ai.need_army, ai.target_pi, p.kills])
