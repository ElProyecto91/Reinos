extends SceneTree
## Mide lo pegadas que quedan las bases a la costa: para cada posición inicial, distancia real (euclídea) al agua más cercana.
## Un galeón dispara a 7 casillas y una galera a 6: una base a menos de ~8 casillas del agua se puede bombardear desde el mar.
## También mide la separación entre bases (distancia a la base rival más cercana), que es lo que marca cuándo llega el primer ataque.
## Uso: godot --headless --script res://tools/coast_probe.gd -- seeds=25 sizes=128,192,256 players=2,3,4 [min_d=10 (falla si alguna base está más cerca)] [goal=12 (0 = criterio antiguo)]
func _init() -> void:
	var nseeds := 25
	var sizes: Array = [128, 192, 256]
	var plays: Array = [2, 3, 4]
	var min_d := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="): nseeds = int(a.substr(6))
		if a.begins_with("min_d="): min_d = float(a.substr(6))
		if a.begins_with("goal="): MapGen.start_water_goal = float(a.substr(5))
		if a.begins_with("sizes="):
			sizes = []
			for s in a.substr(6).split(","): sizes.append(int(s))
		if a.begins_with("players="):
			plays = []
			for s in a.substr(8).split(","): plays.append(int(s))
	var all: Array[float] = []
	var bad := 0
	var failed_maps := 0
	var attempts_sum := 0
	var maps := 0
	for size in sizes:
		for n in plays:
			var ds: Array[float] = []
			var near := [0, 0, 0, 0]       # bases a < 6, < 7, < 8.5, < 10 casillas del agua
			var seps: Array[float] = []
			for sd in range(1, nseeds + 1):
				var m := MapGen.generate(size, sd, n)
				maps += 1
				if not m.get("ok", false):
					failed_maps += 1
					continue
				attempts_sum += int(m.get("attempts", 1))
				var terrain: PackedByteArray = m["terrain"]
				seps.append(MapGen._min_separation(m["starts"]))
				for s: Vector2i in m["starts"]:
					var d := _dist_water(terrain, size, s)
					ds.append(d)
					all.append(d)
					for k in 4:
						if d < [6.0, 7.0, 8.5, 10.0][k]:
							near[k] += 1
					if min_d > 0.0 and d < min_d:
						bad += 1
			ds.sort()
			seps.sort()
			print("size=%3d n=%d bases=%3d  agua: mín %.1f  p10 %.1f  med %.1f  máx %.1f   <6: %d  <7: %d  <8,5: %d  <10: %d   | rival más cercano: mín %.0f  med %.0f  máx %.0f" % [
				size, n, ds.size(), ds[0], ds[ds.size() / 10], ds[ds.size() / 2], ds[ds.size() - 1], near[0], near[1], near[2], near[3],
				seps[0], seps[seps.size() / 2], seps[seps.size() - 1]])
	all.sort()
	print("TOTAL bases=%d mapas=%d (sin generar: %d, intentos medios %.2f) mediana %.1f p10 %.1f mín %.1f; por debajo de min_d: %d" % [
		all.size(), maps, failed_maps, float(attempts_sum) / float(maxi(1, maps - failed_maps)), all[all.size() / 2], all[all.size() / 10], all[0], bad])
	quit(1 if bad > 0 else 0)

## Distancia euclídea desde la base hasta la casilla de agua más cercana (busca en anillos crecientes hasta 40).
func _dist_water(terrain: PackedByteArray, size: int, s: Vector2i) -> float:
	var best := 999.0
	for r in range(1, 41):
		if float(r) > best + 1.0:
			break
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var x := s.x + dx
				var y := s.y + dy
				if x < 0 or y < 0 or x >= size or y >= size:
					continue
				if terrain[y * size + x] == Defs.T_WATER:
					best = minf(best, sqrt(float(dx * dx + dy * dy)))
	return best
