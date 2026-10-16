extends SceneTree
# Prueba sin pantalla de la parte marítima: puerto, pesca, transporte, desembarco y combate naval.
var fails := 0
func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS  " if ok else "FAIL  "), name, ("  " + extra) if extra != "" else "")
	if not ok:
		fails += 1

func run(sim: Sim, seconds: float) -> void:
	for i in int(seconds / Sim.DT):
		sim.step()

func _init() -> void:
	var seed_v := 1
	var size := 128
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		if a.begins_with("size="): size = int(a.substr(5))
	var sim := Sim.new()
	var ok := sim.setup({"size": size, "seed": seed_v, "players": [{"human": true, "team": 0}, {"human": false, "team": 1}], "events": true})
	check("setup", ok)
	sim.ais.clear()
	var p: Player = sim.players[0]
	p.res = {"food": 3000, "wood": 3000, "gold": 3000, "stone": 3000}
	p.pop_cap = 80
	sim.players[1].res = {"food": 3000, "wood": 3000, "gold": 3000, "stone": 3000}
	sim.players[1].pop_cap = 80
	p.age = 1
	var base: Vector2i = p.start_tile
	# 1) buscar sitio de puerto
	var spot := Vector2i(-1, -1)
	var bd := 1e9
	for y in range(maxi(1, base.y - 45), mini(sim.H - 4, base.y + 45)):
		for x in range(maxi(1, base.x - 45), mini(sim.W - 4, base.x + 45)):
			var t := Vector2i(x, y)
			if sim.can_place("puerto", t, 0) and sim.can_reach_building(sim.nearest_free_tile(base + Vector2i(0, 3), 6), "puerto", t):
				var d := Vector2(t - base).length()
				if d < bd:
					bd = d
					spot = t
	check("hay sitio de puerto cerca de la base", spot.x >= 0, "spot=%s dist=%.1f" % [str(spot), bd])
	if spot.x < 0:
		quit(1)
		return
	check("no se puede poner un puerto tierra adentro", not sim.can_place("puerto", base + Vector2i(6, 6), 0) or sim.dock_info(base + Vector2i(6, 6), 3)["ok"])
	var vills: Array = []
	for u in sim.units:
		if u.owner == 0 and u.type == "aldeano":
			vills.append(u.id)
	var r := sim.cmd_build(0, vills, "puerto", spot)
	check("cmd_build puerto", r > 0, str(r))
	var port: Ent = sim.get_ent(r)
	run(sim, 90.0)
	check("puerto terminado", port != null and port.progress >= 1.0, "progress=%.2f" % (port.progress if port != null else -1.0))
	check("puerto con casilla de salida al agua", port.dock_tile.x >= 0 and sim.terrain[port.dock_tile.y * sim.W + port.dock_tile.x] == Defs.T_WATER, str(port.dock_tile))
	# 2) pesqueros
	var pop0 := p.pop
	check("entrenar pesquero", sim.cmd_train(0, port.id, "barco_pesca") == Sim.OK)
	check("entrenar pesquero 2", sim.cmd_train(0, port.id, "barco_pesca") == Sim.OK)
	check("entrenar transporte", sim.cmd_train(0, port.id, "barco_transporte") == Sim.OK)
	check("entrenar galera (edad 1)", sim.cmd_train(0, port.id, "galera") == Sim.OK)
	run(sim, 100.0)
	var boats: Array[Ent] = []
	var transport: Ent = null
	var galera: Ent = null
	for u in sim.units:
		if u.owner == 0 and u.naval:
			boats.append(u)
			if u.type == "barco_transporte": transport = u
			if u.type == "galera": galera = u
	check("4 barcos aparecen", boats.size() == 4, str(boats.size()))
	var all_water := true
	for b in boats:
		var t := sim.tile_of(b.pos)
		if sim.terrain[t.y * sim.W + t.x] != Defs.T_WATER: all_water = false
	check("los barcos nacen en el agua", all_water)
	check("población sube con los barcos", p.pop == pop0 + 4, "%d -> %d" % [pop0, p.pop])
	# 3) pesca
	var fishers: Array = []
	for b in boats:
		if b.type == "barco_pesca": fishers.append(b)
	var ft := sim.find_fish(sim.tile_of(fishers[0].pos), 40)
	check("hay peces alcanzables", ft.x >= 0, str(ft))
	var food0: int = p.gathered["food"]
	var ids: Array = []
	for f in fishers: ids.append(f.id)
	sim.cmd_gather(0, ids, ft)
	# los aldeanos no pueden pescar
	sim.cmd_gather(0, [vills[0]], ft)
	check("un aldeano no pesca", sim.get_ent(vills[0]).state != Sim.S_GATHER_GO or sim.get_ent(vills[0]).carry_kind != "food" or sim.get_ent(vills[0]).target_tile != ft)
	run(sim, 150.0)
	var gained: int = int(p.gathered["food"]) - food0
	check("la pesca entrega comida en el puerto", gained >= 20, "+%d" % gained)
	var f0: Ent = fishers[0]
	check("el pesquero sigue en el agua", sim.terrain[sim.tile_of(f0.pos).y * sim.W + sim.tile_of(f0.pos).x] == Defs.T_WATER)
	# 4) transporte
	if transport != null:
		# a la orilla junto al puerto
		var shore := sim.nearest_water_tile(port.dock_tile, sim.water_comp_at(sim.tile_of(transport.pos)), 3)
		sim.cmd_move(0, [transport.id], shore)
		run(sim, 25.0)
		var warriors: Array = []
		for k in 3:
			var ft2 := sim.nearest_free_tile(base + Vector2i(k, 4), 6)
			warriors.append(sim._spawn_unit("piquero", 0, ft2).id)
		var pop1 := p.pop
		var rb := sim.cmd_board(0, warriors, transport.id)
		check("cmd_board acepta", rb == Sim.OK, str(rb))
		run(sim, 60.0)
		for id in warriors:
			var wu: Ent = sim.ents.get(id)
			if wu == null:
				continue
			print("DBG warrior ", id, " tile ", sim.tile_of(wu.pos), " state ", wu.state, " goal ", wu.goal, " fails ", wu.fails, " stowed ", wu.stowed, " pathlen ", wu.path.size(), " distship ", transport.dist_to(wu.pos), " ship ", sim.tile_of(transport.pos))
		check("pasajeros a bordo", transport.cargo.size() == 3, str(transport.cargo.size()))
		check("pasajeros fuera de la partida", sim.get_ent(warriors[0]) == null)
		check("la población no cambia al embarcar", p.pop == pop1)
		# isla más cercana
		var main_c: int = sim.comp[base.y * sim.W + base.x]
		var tw := sim.water_comp_at(sim.tile_of(transport.pos))
		var best := Vector2i(-1, -1)
		var bdist := 1e9
		for y in sim.H:
			for x in sim.W:
				var i := y * sim.W + x
				var c: int = sim.comp[i]
				if c >= 0 and c != main_c and sim.rtype[i] == 0 and not sim.is_solid_tile(Vector2i(x, y)):
					var wt := sim.nearest_water_tile(Vector2i(x, y), tw, 2)
					if wt.x >= 0:
						var d := Vector2(x, y).distance_to(Vector2(sim.tile_of(transport.pos)))
						if d < bdist:
							bdist = d
							best = Vector2i(x, y)
		check("hay una isla alcanzable", best.x >= 0, str(best))
		if best.x >= 0:
			var ru := sim.cmd_unload(0, [transport.id], best)
			check("cmd_unload acepta", ru == Sim.OK, str(ru))
			run(sim, 120.0)
			check("desembarcan todos", transport.cargo.is_empty(), "quedan %d" % transport.cargo.size())
			var on_island := 0
			for id in warriors:
				var u := sim.get_ent(id)
				if u != null and sim.comp[sim.tile_of(u.pos).y * sim.W + sim.tile_of(u.pos).x] == sim.comp[best.y * sim.W + best.x]:
					on_island += 1
			check("están en la isla", on_island == 3, "%d de 3" % on_island)
			check("población intacta al desembarcar", p.pop == pop1)
	# 5) combate naval
	var e_shore := sim.nearest_water_tile(sim.tile_of(galera.pos) + Vector2i(5, 0), sim.water_comp_at(sim.tile_of(galera.pos)), 8)
	var enemy := sim._spawn_unit("galera", 1, e_shore)
	var enemy_fish := sim._spawn_unit("barco_pesca", 1, sim.nearest_water_tile(e_shore + Vector2i(2, 0), sim.water_comp_at(e_shore), 6))
	var pq := sim._spawn_unit("piquero", 0, sim.nearest_free_tile(base, 4))
	var aq := sim._spawn_unit("arquero", 0, sim.nearest_free_tile(base, 4))
	check("piquero no puede atacar barcos", not sim.can_attack(pq, enemy))
	check("arquero sí puede atacar barcos", sim.can_attack(aq, enemy))
	check("galera sí puede atacar barcos", sim.can_attack(galera, enemy))
	check("pesquero no ataca", not sim.can_attack(boats[0], enemy))
	check("cmd_attack con piquero a un barco = 0", sim.cmd_attack(0, [pq.id], enemy.id) == 0)
	var hp0 := enemy.hp
	var n_att := sim.cmd_attack(0, [galera.id], enemy.id)
	check("cmd_attack galera -> galera", n_att == 1)
	run(sim, 40.0)
	check("la galera enemiga recibe daño o se hunde", (not enemy.alive) or enemy.hp < hp0, "hp %.0f -> %.0f alive=%s" % [hp0, enemy.hp, str(enemy.alive)])
	# 6) hundir un transporte con carga
	if transport != null and transport.alive:
		var ctr: Ent = transport
		var w2 := sim._spawn_unit("piquero", 0, sim.nearest_free_tile(base, 4))
		sim.cmd_move(0, [ctr.id], sim.nearest_water_tile(port.dock_tile, sim.water_comp_at(sim.tile_of(ctr.pos)), 3))
		var far_try := sim.cmd_board(0, [w2.id], ctr.id)
		if sim._landing_tile(ctr, sim.tile_of(w2.pos)).x < 0:
			check("no se puede subir a un barco lejos de la orilla", far_try == Sim.ERR_NOSHORE, str(far_try))
		run(sim, 70.0)
		var rb2 := sim.cmd_board(0, [w2.id], ctr.id)
		print('DBG rb2 ', rb2, ' ship tile ', sim.tile_of(ctr.pos), ' land comp w2 ', sim.comp[sim.tile_of(w2.pos).y*sim.W+sim.tile_of(w2.pos).x], ' landing ', sim._landing_tile(ctr, sim.tile_of(w2.pos)))
		run(sim, 40.0)
		var popx := p.pop
		var had := ctr.cargo.size()
		print("DBG ship ", sim.tile_of(ctr.pos), " state ", ctr.state, " w2 ", sim.tile_of(w2.pos), " state ", w2.state, " stowed ", w2.stowed, " port dock ", port.dock_tile)
		check("subió otro", had >= 1, str(had))
		sim._damage(ctr, 9999.0, null)
		sim._cleanup()
		check("se hunde el transporte", not ctr.alive)
		check("la carga se pierde con el barco", p.pop == popx - 1 - had, "%d -> %d (carga %d)" % [popx, p.pop, had])
	# 7) un puerto destruido deja de aceptar entregas y los barcos no quedan atascados
	print("DONE fails=", fails)
	quit(0 if fails == 0 else 1)
