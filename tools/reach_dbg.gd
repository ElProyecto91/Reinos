extends SceneTree
## ¿Qué recursos son realmente alcanzables a pie desde cada inicio? seed=N size=S
func _init() -> void:
	var sd := 1
	var size := 192
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): sd = int(a.substr(5))
		elif a.begins_with("size="): size = int(a.substr(5))
	var sim := Sim.new()
	var plist: Array = []
	for i in 4:
		plist.append({"human": false, "team": i, "diff": 1, "name": "P%d" % i})
	sim.setup({"size": size, "seed": sd, "events": false, "players": plist})
	for pi in 4:
		var s: Vector2i = sim.players[pi].start_tile
		var seen := PackedInt32Array()
		seen.resize(sim.W * sim.H)
		seen.fill(-1)
		var s0 := s
		var bestd := 1e9
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				var t := s + Vector2i(dx, dy)
				if sim.in_bounds(t) and sim.solid[t.y * sim.W + t.x] == 0 and float(dx * dx + dy * dy) < bestd:
					bestd = float(dx * dx + dy * dy)
					s0 = t
		var q: Array = [s0]
		seen[s0.y * sim.W + s0.x] = 0
		var head := 0
		while head < q.size():
			var c: Vector2i = q[head]
			head += 1
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if not sim.in_bounds(n):
					continue
				var ni := n.y * sim.W + n.x
				if seen[ni] != -1 or sim.solid[ni] == 1:
					continue
				seen[ni] = seen[c.y * sim.W + c.x] + 1
				q.append(n)
		var gold_ok := 0
		var gold_all := 0
		var gold_near: Array = []
		var tree_ok := 0
		var berry_ok := 0
		for i in sim.W * sim.H:
			var rt := sim.rtype[i]
			if rt != Defs.R_GOLD and rt != Defs.R_TREE and rt != Defs.R_BERRY:
				continue
			var t := Vector2i(i % sim.W, i / sim.W)
			var dd := Vector2(t - s).length()
			if dd > 60.0:
				continue
			var ok := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = t + d
				if sim.in_bounds(n) and seen[n.y * sim.W + n.x] >= 0:
					ok = true
			if rt == Defs.R_GOLD:
				gold_all += 1
				if ok:
					gold_ok += 1
					gold_near.append(snappedf(dd, 0.1))
			elif rt == Defs.R_TREE and ok:
				tree_ok += 1
			elif rt == Defs.R_BERRY and ok:
				berry_ok += 1
		gold_near.sort()
		print("P", pi, " start ", s, " reach ", q.size(), " gold(r<60) ", gold_ok, "/", gold_all, " nearest ", gold_near.slice(0, 3), " trees ", tree_ok, " berries ", berry_ok)
	quit()
