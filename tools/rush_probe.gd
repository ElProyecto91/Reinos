extends SceneTree
## ¿Cuándo llegan los primeros enemigos a la base de un jugador que no hace nada? (mide la presión de la IA por dificultad)
## godot --headless --path . --script res://tools/rush_probe.gd -- diff=0 seed=3 size=192 rivals=2 min=30
func _init() -> void:
	var diff := 0
	var seed_v := 3
	var size := 192
	var rivals := 2
	var minutes := 30.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("diff="): diff = int(a.substr(5))
		elif a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("size="): size = int(a.substr(5))
		elif a.begins_with("rivals="): rivals = int(a.substr(7))
		elif a.begins_with("min="): minutes = float(a.substr(4))
	var pl: Array = [{"human": true, "team": 0, "diff": 1, "name": "H", "civ": "random"}]
	for i in rivals:
		pl.append({"human": false, "team": 1, "diff": diff, "name": "R%d" % i, "civ": "random"})
	var sim := Sim.new()
	sim.setup({"size": size, "seed": seed_v, "events": false, "players": pl})
	var hp: Player = sim.players[0]
	var tc: Vector2 = sim.tile_center(hp.start_tile)
	var near_t := -1.0
	var hit_t := -1.0
	var army_at := {}
	for s in int(minutes * 60.0 / Sim.DT):
		sim.step()
		if sim.time >= 60.0 and s % 10 == 0:
			if near_t < 0.0:
				for u in sim.units:
					if u.alive and u.owner > 0 and u.is_military() and not u.naval and u.pos.distance_to(tc) < 14.0 * Defs.TILE:
						near_t = sim.time
						break
			if hit_t < 0.0:
				for b in sim.buildings:
					if b.alive and b.owner == 0 and b.hp < b.max_hp - 1.0 and b.progress >= 1.0:
						hit_t = sim.time
						break
		if int(sim.time) % 300 == 0 and s % 10 == 0 and not army_at.has(int(sim.time)):
			var mil := 0
			for u in sim.units:
				if u.alive and u.owner > 0 and u.is_military() and not u.naval:
					mil += 1
			army_at[int(sim.time)] = mil
		if not hp.alive:
			break
	var line := "PROBE diff=%d seed=%d size=%d rivals=%d | primer enemigo a <14 casillas: %s | primer edificio dañado: %s | humano vivo: %s t=%.0f | ejército rival total cada 5 min: %s" % [diff, seed_v, size, rivals, ("%.0fs" % near_t) if near_t >= 0 else "nunca", ("%.0fs" % hit_t) if hit_t >= 0 else "nunca", str(hp.alive), sim.time, str(army_at)]
	print(line)
	quit()
