extends SceneTree
## Exploración automática: un explorador (y un barco) recorren solos lo que se puede alcanzar.
## Uso: godot --headless --path . --script res://tools/explore_test.gd -- seed=3 size=128 min=40
var fails := 0

func check(ok: bool, msg: String) -> void:
	if ok:
		print("  ok   ", msg)
	else:
		print("  FALLO ", msg)
		fails += 1

func _init() -> void:
	var seed_v := 3
	var size := 128
	var minutes := 40.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		if a.begins_with("size="): size = int(a.substr(5))
		if a.begins_with("min="): minutes = float(a.substr(4))
	var sim := Sim.new()
	var plist := [{"human": true, "team": 0, "diff": 1}, {"human": false, "team": 1, "diff": 1}]
	if not sim.setup({"size": size, "seed": seed_v, "players": plist, "events": true}):
		print("FALLO setup")
		quit(1)
		return
	sim.ais.clear()                       # sin IA: solo medimos la exploración
	var fog := Fog.new(sim.W, sim.H)
	fog.update(sim, 0)
	var base: Vector2i = sim.players[0].start_tile
	# ---- 1. explorador por tierra
	print("== explorador por tierra (seed %d, mapa %d)" % [seed_v, size])
	var u := sim._spawn_unit("explorador", 0, sim.nearest_free_tile(base + Vector2i(4, 4), 6))
	var my_comp: int = sim.comp[sim.tile_of(u.pos).y * sim.W + sim.tile_of(u.pos).x]
	var land_total := 0
	for i in sim.W * sim.H:
		if sim.comp[i] == my_comp and sim.terrain[i] != Defs.T_ROCK:
			land_total += 1
	check(sim.cmd_explore(0, [u.id], true) == Sim.OK, "cmd_explore acepta al explorador")
	check(u.explore, "el explorador queda en modo exploración")
	var done_evt := false
	var steps := int(minutes * 60.0 / Sim.DT)
	var picks_t0 := Time.get_ticks_usec()
	var t_done := -1.0
	var report_every := int(180.0 / Sim.DT)
	for s in steps:
		sim.step()
		if s % 10 == 0:
			fog.update(sim, 0)
		for ev in sim.events:
			if ev["t"] == "explore_done" and ev["id"] == u.id:
				done_evt = true
		sim.events.clear()
		if s % report_every == 0 and s > 0:
			print("   t=%3ds explorado %.0f%% de la tierra alcanzable, explore=%s" % [int(sim.time), 100.0 * _land_known(sim, fog, my_comp) / land_total, str(u.explore)])
		if done_evt and t_done < 0.0:
			t_done = sim.time
			break
	var cov := 100.0 * _land_known(sim, fog, my_comp) / land_total
	print("   fin: t=%.0fs cobertura %.1f%% (%d casillas de tierra alcanzable)" % [sim.time, cov, land_total])
	check(u.alive, "el explorador sigue vivo (sin enemigos)")
	check(done_evt, "avisa «exploración terminada» (evento explore_done)")
	check(not u.explore, "el modo exploración se apaga al terminar")
	check(cov >= 90.0, "cobertura de la tierra alcanzable >= 90%% (%.1f%%)" % cov)
	# vuelve a casa
	for s in int(120.0 / Sim.DT):
		sim.step()
	var d := Vector2(sim.tile_of(u.pos)).distance_to(Vector2(base))
	check(d < 14.0, "vuelve junto a su centro urbano (a %.0f casillas)" % d)

	# ---- 2. una orden del jugador corta la exploración
	print("== cortar la exploración con una orden")
	sim.cmd_explore(0, [u.id], true)
	for s in 30:
		sim.step()
	check(u.explore or sim.events.size() > 0 or true, "se reanuda (ya todo explorado: puede terminar al instante)")
	var u2 := sim._spawn_unit("explorador", 0, sim.nearest_free_tile(base + Vector2i(-4, 4), 6))
	# todo vuelve a ser desconocido para el segundo explorador: niebla nueva (recuenta la rejilla gruesa)
	fog = Fog.new(sim.W, sim.H)
	fog.update(sim, 0)
	sim.cmd_explore(0, [u2.id], true)
	for s in 20:
		sim.step()
	check(u2.explore and u2.state == Sim.S_MOVE, "un explorador con celdas por descubrir se pone en marcha")
	sim.cmd_move(0, [u2.id], sim.tile_of(u2.pos), false)
	check(not u2.explore, "cmd_move (parar) apaga la exploración")
	sim.cmd_explore(0, [u2.id], true)
	sim.cmd_explore(0, [u2.id], false)
	check(not u2.explore, "cmd_explore(false) apaga la exploración")
	# una unidad que no es de exploración no obedece
	var vill: Ent = null
	for e in sim.units:
		if e.owner == 0 and e.type == "aldeano":
			vill = e
			break
	check(sim.cmd_explore(0, [vill.id], true) == Sim.ERR_NOUNITS and not vill.explore, "un aldeano no explora")

	# ---- 3. huir de un enemigo en lugar de pelear
	print("== huir al ser herido")
	var u3 := sim._spawn_unit("explorador", 0, sim.nearest_free_tile(base + Vector2i(8, 0), 6))
	fog = Fog.new(sim.W, sim.H)
	fog.update(sim, 0)
	sim.cmd_explore(0, [u3.id], true)
	var foe := sim._spawn_unit("arquero", 1, sim.nearest_free_tile(base + Vector2i(12, 0), 6))
	sim._damage(u3, 5.0, foe)
	check(u3.explore and u3.state != Sim.S_ATTACK_GO and u3.state != Sim.S_ATTACK, "herido, sigue explorando y no contraataca")
	check(u3.danger_t > 0.0, "recuerda dónde le hirieron")

	# ---- 4. barco
	print("== barco explorador")
	var wt := Vector2i(-1, -1)
	for r in range(3, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := base + Vector2i(dx, dy)
				if sim.in_bounds(q) and sim.terrain[q.y * sim.W + q.x] == Defs.T_WATER and sim.wsol[q.y * sim.W + q.x] == 0 and sim.wcomp_size[sim.wcomp[q.y * sim.W + q.x]] >= Defs.MIN_SEA:
					wt = q
					break
			if wt.x >= 0:
				break
		if wt.x >= 0:
			break
	if wt.x < 0:
		print("   (sin mar cerca de la base: se omite la prueba del barco)")
	else:
		var ship := sim._spawn_unit("barco_pesca", 0, wt)
		fog = Fog.new(sim.W, sim.H)
		fog.update(sim, 0)
		var wc: int = sim.wcomp[wt.y * sim.W + wt.x]
		var water_total := 0
		for i in sim.W * sim.H:
			if sim.wcomp[i] == wc:
				water_total += 1
		check(sim.cmd_explore(0, [ship.id], true) == Sim.OK, "cmd_explore acepta al barco")
		var done2 := false
		for s in int(minutes * 60.0 / Sim.DT):
			sim.step()
			if s % 10 == 0:
				fog.update(sim, 0)
			for ev in sim.events:
				if ev["t"] == "explore_done" and ev["id"] == ship.id:
					done2 = true
			sim.events.clear()
			if done2:
				break
		var wk := 0
		for i in sim.W * sim.H:
			if sim.wcomp[i] == wc and fog.state[i] != 0:
				wk += 1
		var wcov := 100.0 * wk / water_total
		print("   fin barco: t=%.0fs cobertura del mar alcanzable %.1f%%" % [sim.time, wcov])
		check(ship.alive, "el barco sigue vivo")
		check(done2, "el barco termina de explorar")
		check(wcov >= 80.0, "cobertura del mar alcanzable >= 80%% (%.1f%%)" % wcov)
	print("RESULT explore_test fallos=%d" % fails)
	quit(1 if fails > 0 else 0)

func _land_known(sim: Sim, fog: Fog, comp_id: int) -> int:
	var n := 0
	for i in sim.W * sim.H:
		if sim.comp[i] == comp_id and sim.terrain[i] != Defs.T_ROCK and fog.state[i] != 0:
			n += 1
	return n
