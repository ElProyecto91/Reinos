extends SceneTree
## El filtro previo de scan_enemy (máscara de dueños por cubo) debe dar EXACTAMENTE el mismo objetivo que el
## recorrido completo de antes. Se compara en una guerra real entre IAs, en muchos instantes y con todas las unidades.
func _init() -> void:
	var seed_v := 5
	var minutes := 16.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		if a.begins_with("min="): minutes = float(a.substr(4))
	var sim := Sim.new()
	var plist := [{"human": false, "team": 0, "diff": 2}, {"human": false, "team": 1, "diff": 2}, {"human": false, "team": 2, "diff": 1}]
	if not sim.setup({"size": 128, "seed": seed_v, "players": plist, "events": false}):
		quit(1)
		return
	var samples := 0
	var skipped := 0
	var diffs := 0
	var steps := int(minutes * 60.0 / Sim.DT)
	for s in steps:
		sim.step()
		if s % 7 == 0 and s > 600:
			for e in sim.units:
				if not e.alive or e.stowed:
					continue
				var r := float(e.def["los"]) * Defs.TILE
				var a := sim.scan_enemy(e, r)
				var b := _ref(sim, e, r)
				samples += 1
				if a == null and b == null:
					skipped += 1
				if (a == null) != (b == null) or (a != null and a.id != b.id):
					diffs += 1
					if diffs < 5:
						print("DIFERENCIA unidad %d (%s) a=%s b=%s" % [e.id, e.type, str(a.id if a else -1), str(b.id if b else -1)])
		if sim.game_over:
			break
	print("RESULT scan_test muestras=%d sin_objetivo=%d diferencias=%d (t=%.0fs)" % [samples, skipped, diffs, sim.time])
	quit(1 if diffs > 0 else 0)

## Copia literal del recorrido completo (sin filtro previo).
func _ref(sim: Sim, e: Ent, r: float) -> Ent:
	var best: Ent = null
	var bs := 1e9
	for o in sim.query(e.pos, r):
		if o.owner == e.owner or not sim.hostile[e.owner][o.owner]:
			continue
		if o.id == e.ignore_id and sim.time < e.ignore_until:
			continue
		if o.naval and not e.naval:
			if float(e.def["range"]) <= 1.5 or o.dist_to(e.pos) > float(e.def["range"]) * Defs.TILE:
				continue
		if bool(e.def.get("siege", false)) and not o.is_building:
			continue
		var d: float = o.dist_to(e.pos)
		var score := d
		if o.is_building:
			score += 200.0
			if o.progress < 1.0:
				score += 100.0
			if o.def.get("wall", false):
				score += 150.0
		elif not o.is_military():
			score += 60.0
		if score < bs:
			bs = score
			best = o
	return best
