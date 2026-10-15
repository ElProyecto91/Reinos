extends SceneTree
## Coste de la simulación en partida larga: deja crecer a dos IAs en paz hasta `min` minutos y mide 300 pasos desglosados.
## Uso: godot --headless --script res://tools/late_prof.gd -- seed=3 size=192 min=25
func _init() -> void:
	var seed_v := 3
	var size := 192
	var minutes := 25.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		if a.begins_with("size="): size = int(a.substr(5))
		if a.begins_with("min="): minutes = float(a.substr(4))
	var sim := Sim.new()
	var plist := [{"human": false, "team": 0, "diff": 2}, {"human": false, "team": 1, "diff": 2}]
	sim.setup({"size": size, "seed": seed_v, "players": plist, "events": false})
	for a in sim.ais:
		a.attack_at = 1e12
		a.raid_at = 1e12
		a.navy_at = 1e12
	for s in int(minutes * 60.0 / Sim.DT):
		sim.step()
	print("t=%.0f ents=%d units=%d buildings=%d" % [sim.time, sim.ents.size(), sim.units.size(), sim.buildings.size()])
	sim.profiling = true
	sim.prof.clear()
	var t0 := Time.get_ticks_usec()
	var n := 300
	for s in n:
		sim.step()
	var tot := Time.get_ticks_usec() - t0
	print("PASO medio %.2f ms (profiling activo)" % (float(tot) / n / 1000.0))
	var keys: Array = []
	for k in sim.prof:
		if not str(k).ends_with("_n") and not str(k).begins_with("gg_") and not str(k).begins_with("st") and not str(k).begins_with("slow"):
			keys.append(k)
	keys.sort_custom(func(a, b) -> bool: return int(sim.prof[a]) > int(sim.prof[b]))
	for k in keys.slice(0, 22):
		var cnt := int(sim.prof.get(str(k) + "_n", 0))
		print("  %-28s %7.3f ms/paso  %s" % [k, float(sim.prof[k]) / n / 1000.0, ("(%d llamadas, %.1f us cada una)" % [cnt, float(sim.prof[k]) / maxf(1.0, cnt)]) if cnt > 0 else ""])
	quit()
