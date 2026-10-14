extends SceneTree
## Estadísticas y vista general de mapas: seeds=1,2,3 size=192 out=/tmp/map  (genera PNG por semilla)
func _init() -> void:
	var seeds: Array = [1, 2, 3, 5, 8, 13]
	var size := 192
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = []
			for t in a.substr(6).split(","):
				seeds.append(int(t))
		elif a.begins_with("size="):
			size = int(a.substr(5))
		elif a.begins_with("out="):
			out = a.substr(4)
	for sd in seeds:
		var t0 := Time.get_ticks_msec()
		var m := MapGen.generate(size, sd, 4)
		var dt := Time.get_ticks_msec() - t0
		if not m.get("ok", false):
			print("seed ", sd, " FAIL")
			continue
		var terrain: PackedByteArray = m["terrain"]
		var heat: PackedByteArray = m["heat"]
		var rtype: PackedByteArray = m["rtype"]
		var starts: Array = m["starts"]
		var land := 0
		var rock := 0
		var snow := 0
		var desert := 0
		for i in size * size:
			if terrain[i] == Defs.T_WATER:
				continue
			land += 1
			if terrain[i] == Defs.T_ROCK:
				rock += 1
			elif heat[i] < 72:
				snow += 1
			elif heat[i] > 178:
				desert += 1
		# conectividad independiente (4 vecinos, sin agua ni roca)
		var seen := PackedByteArray()
		seen.resize(size * size)
		var q: Array[int] = [starts[0].y * size + starts[0].x]
		seen[q[0]] = 1
		var head := 0
		while head < q.size():
			var cur := q[head]
			head += 1
			var cx := cur % size
			var cy := cur / size
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = cx + d.x
				var ny: int = cy + d.y
				if nx < 0 or ny < 0 or nx >= size or ny >= size:
					continue
				var ni := ny * size + nx
				if seen[ni] == 0 and terrain[ni] != Defs.T_WATER and terrain[ni] != Defs.T_ROCK:
					seen[ni] = 1
					q.append(ni)
		var ok := true
		for s in starts:
			if seen[s.y * size + s.x] == 0:
				ok = false
		print("seed %d %dms att=%d land=%.1f%% rock=%.1f%% snow=%.1f%% desert=%.1f%% starts_connected=%s" % [sd, dt, m["attempts"], 100.0 * land / (size * size), 100.0 * rock / maxi(land, 1), 100.0 * snow / maxi(land, 1), 100.0 * desert / maxi(land, 1), str(ok)])
		if out != "":
			var img := Image.create(size, size, false, Image.FORMAT_RGB8)
			for i in size * size:
				var c: Color
				match terrain[i]:
					Defs.T_WATER:
						c = Color(0.15, 0.35, 0.6)
					Defs.T_SAND:
						c = Color(0.85, 0.8, 0.55)
					Defs.T_ROCK:
						c = Color(0.4, 0.38, 0.36)
					_:
						var h := heat[i]
						c = Color(0.92, 0.95, 1.0) if h < 72 else (Color(0.85, 0.7, 0.4) if h > 178 else Color(0.35, 0.6, 0.3))
				if rtype[i] == Defs.R_TREE:
					c = c.darkened(0.45)
				elif rtype[i] == Defs.R_GOLD:
					c = Color(1, 0.85, 0.1)
				img.set_pixel(i % size, i / size, c)
			for s in starts:
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						img.set_pixel(clampi(s.x + dx, 0, size - 1), clampi(s.y + dy, 0, size - 1), Color(1, 0.1, 0.1))
			img.resize(size * 4, size * 4, Image.INTERPOLATE_NEAREST)
			img.save_png("%s_%d_%d.png" % [out, size, sd])
	quit()
