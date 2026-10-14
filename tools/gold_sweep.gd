extends SceneTree
## Barrido: ¿los aldeanos consiguen oro de las minas cercanas a la base en muchas semillas?
func golds_near(sim: Sim, s0: Vector2i, n: int) -> Array:
	var list: Array = []
	for y in sim.H:
		for x in sim.W:
			if sim.rtype[y * sim.W + x] == Defs.R_GOLD:
				list.append([float((Vector2i(x, y) - s0).length()), Vector2i(x, y)])
	list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return list.slice(0, n)

func _initialize() -> void:
	var bad := 0
	var total := 0
	for size_v in [128, 192]:
		for seed_v in range(1, 21):
			for k in 3:
				var sim := Sim.new()
				var cfg := {"size": size_v, "seed": seed_v, "events": false, "players": [
					{"human": true, "team": 0, "diff": 1, "name": "A"},
					{"human": false, "team": 1, "diff": 0, "name": "B"}]}
				if not sim.setup(cfg):
					continue
				sim.ais.clear()
				var p: Player = sim.players[0]
				var gl := golds_near(sim, p.start_tile, 3)
				if gl.size() <= k:
					continue
				var tile: Vector2i = gl[k][1]
				var vs: Array = []
				for u in sim.units:
					if u.owner == 0 and u.type == "aldeano":
						vs.append(u.id)
				sim.cmd_gather(0, vs.slice(0, 3), tile)
				var g0: int = p.res["gold"]
				for step in 1500:
					sim.step()
				var gained: int = int(p.res["gold"]) - g0
				total += 1
				if gained < 20:
					bad += 1
					print("FALLO size ", size_v, " seed ", seed_v, " mina#", k, " ", tile, " dist ", snappedf(gl[k][0], 0.1), " oro ganado ", gained)
	print("RESUMEN fallos ", bad, " de ", total)
	quit()
