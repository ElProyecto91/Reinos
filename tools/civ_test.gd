extends SceneTree
## Civilizaciones en la simulación pura: datos coherentes, bonificaciones, unidad única en el Castillo, habilidades,
## guardado/carga y que sin civilización todo siga igual que antes.
## godot --headless --path . --script res://tools/civ_test.gd
var fails := 0
var checks := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FALLO: ", msg)

func make_sim(civs: Array = ["", ""], seed_v: int = 7) -> Sim:
	var sim := Sim.new()
	var pl: Array = []
	for i in civs.size():
		pl.append({"human": i == 0, "team": i, "diff": 1, "name": "J%d" % i, "civ": civs[i]})
	sim.setup({"size": 128, "seed": seed_v, "events": false, "players": pl})
	sim.ais.clear()
	return sim

func run(sim: Sim, secs: float) -> void:
	for i in int(secs / Sim.DT):
		sim.step()

func free_near(sim: Sim, t: Vector2i, type: String, owner: int) -> Vector2i:
	for r in range(0, 24):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := t + Vector2i(dx, dy)
				if sim.can_place(type, q, owner):
					return q
	return Vector2i(-1, -1)

func rich(p: Player) -> void:
	for k in ["food", "wood", "gold", "stone"]:
		p.res[k] = 99999
	p.pop_cap = 200

func _init() -> void:
	test_data()
	test_mods()
	test_unique_training()
	test_abilities()
	test_save()
	test_fog()
	test_no_civ()
	test_random_pick()
	print("civ_test: %d comprobaciones, %d fallos" % [checks, fails])
	quit(1 if fails > 0 else 0)

# --- datos
func test_data() -> void:
	ok(Civs.IDS.size() == 8, "8 civilizaciones")
	var seen := {}
	for id in Civs.IDS:
		ok(Civs.valid(id), "civ válida " + id)
		var u := Civs.unique_of(id)
		ok(Defs.UNITS.has(u), "%s: unidad única inexistente %s" % [id, u])
		ok(not seen.has(u), "unidad única repetida " + u)
		seen[u] = true
		if Defs.UNITS.has(u):
			var d: Dictionary = Defs.UNITS[u]
			ok(String(d.get("building", "")) == "castillo", "%s se entrena en el castillo" % u)
			ok(int(d["age"]) == 2, "%s es de la edad 2" % u)
			ok(Civs.CLS.has(u), "%s tiene clase" % u)
			ok(ArtUnits.CELLS.has(u), "%s tiene hoja" % u)
			if d.has("as"):
				ok(Defs.UNITS.has(d["as"]), "%s: 'as' desconocido" % u)
		var ab := Civs.ability_of(id)
		ok(["buff", "lump", "fire", "reveal", "spawn"].has(String(ab.get("kind", ""))), "%s: tipo de habilidad" % id)
		ok(float(ab.get("cd", 0.0)) >= 60.0, "%s: enfriamiento" % id)
		if String(ab["kind"]) == "spawn":
			ok(Defs.UNITS.has(String(ab["unit"])), "spawn: unidad")
		# textos
		for key in ["civ_%s", "civ_%s_pas", "civ_%s_uni", "abil_%s", "abil_%s_desc"]:
			var k: String = key % id
			ok(Lang.t(k) != k, "falta texto " + k)
	for t in Defs.UNITS:
		var d2: Dictionary = Defs.UNITS[t]
		if bool(d2.get("military", false)) and not Defs.BUILDINGS.has(t):
			pass
	# las únicas no están en la lista base del castillo
	var base: Array = Defs.BUILDINGS["castillo"]["train"]
	for id in Civs.IDS:
		ok(not base.has(Civs.unique_of(id)), "la lista base del castillo no incluye " + Civs.unique_of(id))

# --- multiplicadores
func test_mods() -> void:
	var sim := make_sim(["castellanos", "mongoles"])
	var p0: Player = sim.players[0]
	var p1: Player = sim.players[1]
	rich(p0)
	rich(p1)
	var hp0 := float(Defs.UNITS["caballero"]["hp"])
	var a := sim._spawn_unit("caballero", 0, free_near(sim, p0.start_tile, "casa", 0))
	var b := sim._spawn_unit("caballero", 1, free_near(sim, p1.start_tile, "casa", 1))
	var chp: float = float((Civs.DATA["castellanos"]["hp"] as Dictionary)["cav"])
	ok(absf(a.max_hp - hp0 * chp) < 0.5, "castellanos: caballero ×%.2f de vida (%.1f)" % [chp, a.max_hp])
	ok(absf(b.max_hp - hp0) < 0.5, "mongoles: caballero vida base")
	ok(absf(b.sm - 1.10) < 0.001, "mongoles: caballero +10%% velocidad")
	ok(b.lb == 2, "mongoles: +2 de vista (lb=%d)" % b.lb)
	ok(absf(a.sm - 1.0) < 0.001, "castellanos: velocidad base")
	# coste y tiempo
	var s2 := make_sim(["sarracenos", "mongoles", "vikingos", "bizantinos"])
	var c0: Dictionary = s2.unit_cost(0, "caballero")
	var base_c: Dictionary = Defs.UNITS["caballero"]["cost"]
	for k in base_c:
		ok(int(c0[k]) == int(round(float(base_c[k]) * 0.90)), "sarracenos: caballero -10%% (%s)" % k)
	var t1 := s2.unit_time(1, "caballero")
	var mt: float = float((Civs.DATA["mongoles"]["time"] as Dictionary)["cav"])
	ok(mt < 1.0 and absf(t1 - float(Defs.UNITS["caballero"]["time"]) * mt) < 0.01, "mongoles: caballero entrena más rápido (×%.2f)" % mt)
	ok(s2.unit_cost(1, "caballero") == base_c, "mongoles: coste base")
	var gc: Dictionary = s2.unit_cost(2, "galera")
	var gb: Dictionary = Defs.UNITS["galera"]["cost"]
	for k in gb:
		ok(int(gc[k]) == int(round(float(gb[k]) * 0.85)), "vikingos: galera -15%%")
	var at: float = float(Civs.DATA["bizantinos"]["age_time"])
	ok(at < 1.0 and absf(s2.age_time(3, 1) - float(Defs.AGES[1]["time"]) * at) < 0.01, "bizantinos: edad más rápida (×%.2f)" % at)
	var ac: Dictionary = s2.age_cost(3, 1)
	for k in Defs.AGES[1]["cost"]:
		ok(int(ac[k]) <= int(Defs.AGES[1]["cost"][k]), "bizantinos: edad más barata")
	# recolección
	var vg: Dictionary = Civs.DATA["vikingos"]["gather"]
	ok(absf((s2.civ_mods[2]["gather"] as PackedFloat32Array)[Defs.R_FISH] - float(vg["fish"]) * float(vg["food"])) < 0.001, "vikingos: pesca = pesca × comida")
	ok(absf((s2.civ_mods[0]["gather"] as PackedFloat32Array)[Defs.R_GOLD] - float(Civs.DATA["sarracenos"]["gather"]["gold"])) < 0.001, "sarracenos: bono de oro")
	# Teutones: casas +1 población y edificios +25% vida
	var s3 := make_sim(["teutones", ""])
	var h := s3._spawn_building("casa", 0, free_near(s3, (s3.players[0] as Player).start_tile, "casa", 0), true)
	var h2 := s3._spawn_building("casa", 1, free_near(s3, (s3.players[1] as Player).start_tile, "casa", 1), true)
	ok(absf(h.max_hp - h2.max_hp * 1.25) < 1.0, "teutones: edificios +25%% vida (%.0f vs %.0f)" % [h.max_hp, h2.max_hp])
	ok(s3._bld_pop(h) == s3._bld_pop(h2) + 1, "teutones: casa +1 población")

# --- unidad única
func test_unique_training() -> void:
	for id in Civs.IDS:
		var sim := make_sim([id, "castellanos" if id != "castellanos" else "francos"])
		var p: Player = sim.players[0]
		rich(p)
		p.age = 2
		var t := free_near(sim, p.start_tile, "castillo", 0)
		ok(t.x >= 0, "%s: sitio para castillo" % id)
		if t.x < 0:
			continue
		var cs := sim._spawn_building("castillo", 0, t, true)
		var u := Civs.unique_of(id)
		var r := sim.cmd_train(0, cs.id, u)
		ok(r == Sim.OK, "%s: entrena %s (código %d)" % [id, u, r])
		var other := Civs.unique_of("castellanos" if id != "castellanos" else "francos")
		var r2 := sim.cmd_train(0, cs.id, other)
		ok(r2 != Sim.OK, "%s no puede entrenar la única ajena %s" % [id, other])
		# que salga la unidad
		run(sim, 60.0)
		var found := 0
		for e in sim.units:
			if e.alive and e.owner == 0 and e.type == u:
				found += 1
		ok(found >= 1, "%s: ha salido %s del castillo" % [id, u])

# --- habilidades
func test_abilities() -> void:
	for id in Civs.IDS:
		var sim := make_sim([id, "castellanos" if id != "castellanos" else "francos"])
		var p: Player = sim.players[0]
		var e: Player = sim.players[1]
		rich(p)
		var ab := Civs.ability_of(id)
		var st := sim.ability_state(0)
		ok(bool(st["has"]), "%s tiene habilidad" % id)
		ok(not bool(st["age_ok"]) or int(ab.get("age", 1)) <= p.age, "%s: edad" % id)
		# antes de la Edad Feudal no se puede
		var r0 := sim.cmd_ability(0, p.start_tile)
		ok(r0 == Sim.ERR_AGE, "%s: antes de la edad feudal falla (%d)" % [id, r0])
		p.age = 1
		sim.units.size()
		var tgt := p.start_tile + Vector2i(14, 0)
		# soldados propios para ver el efecto
		var soldier := sim._spawn_unit("espadachin", 0, free_near(sim, p.start_tile + Vector2i(4, 4), "casa", 0))
		var res_before := {"food": int(p.res["food"]), "wood": int(p.res["wood"])}
		var n_units := sim.units.size()
		var kind := String(ab["kind"])
		if kind == "fire":
			ok(sim.cmd_ability(0) == Sim.ERR_NOTARGET, "%s: sin objetivo falla" % id)
			ok(p.abil_ready <= sim.time, "%s: el fallo no gasta enfriamiento" % id)
			# enemigo dentro de la zona
			var etile := free_near(sim, p.start_tile + Vector2i(10, 6), "casa", 0)
			var victim := sim._spawn_unit("espadachin", 1, etile)
			var hp_before := victim.hp
			var r := sim.cmd_ability(0, etile)
			ok(r == Sim.OK, "%s: fuego OK (%d)" % [id, r])
			ok(sim.zones.size() == 1, "%s: hay una zona de fuego" % id)
			run(sim, 4.0)
			ok(victim.hp < hp_before - 10.0 or not victim.alive, "%s: el fuego daña (%.1f → %.1f)" % [id, hp_before, victim.hp])
			# amigos no sufren
			var friend := sim._spawn_unit("espadachin", 0, etile + Vector2i(1, 0))
			var fh := friend.hp
			run(sim, 2.0)
			ok(friend.hp >= fh - 0.01, "%s: el fuego no daña a los propios" % id)
			run(sim, float(ab["dur"]) + 1.0)
			ok(sim.zones.is_empty(), "%s: la zona de fuego se apaga" % id)
		else:
			var r := sim.cmd_ability(0, tgt)
			ok(r == Sim.OK, "%s: habilidad OK (%d)" % [id, r])
			match kind:
				"buff", "reveal":
					ok(p.abil_on, "%s: activa" % id)
					ok(bool(sim.ability_state(0)["active"]), "%s: estado activo" % id)
					ok(p.b_types.has("espadachin") or id == "ingleses", "%s: afecta a soldados" % id)
					run(sim, float(ab["dur"]) + 1.0)
					ok(not p.abil_on, "%s: termina" % id)
					ok(p.b_atk == 1.0 and p.b_spd == 1.0 and p.b_def == 1.0 and p.b_rate == 1.0, "%s: bonos limpios al terminar" % id)
					if kind == "reveal":
						ok(p.reveal_until > 0.0, "%s: revela" % id)
				"lump":
					ok(int(p.res["food"]) > res_before["food"] and int(p.res["wood"]) > res_before["wood"], "%s: recibe recursos" % id)
				"spawn":
					ok(sim.units.size() >= n_units + int(ab["n"]) - 0, "%s: aparecen tropas (%d → %d)" % [id, n_units, sim.units.size()])
		var st2 := sim.ability_state(0)
		ok(not bool(st2["ready"]), "%s: en enfriamiento tras usarla" % id)
		var r3 := sim.cmd_ability(0, tgt)
		ok(r3 == Sim.ERR_COOLDOWN, "%s: segundo uso inmediato falla (%d)" % [id, r3])
		# recarga completa
		run(sim, float(ab["cd"]) + 2.0)
		ok(bool(sim.ability_state(0)["ready"]), "%s: se recarga" % id)
		soldier.hp = soldier.hp

	# Mongoles: sin sitio de población no se gasta el enfriamiento
	var sm := make_sim(["mongoles", "francos"])
	var pm: Player = sm.players[0]
	pm.age = 1
	pm.pop_cap = pm.pop
	var rr := sm.cmd_ability(0)
	ok(rr == Sim.ERR_POP, "mongoles: sin sitio falla con ERR_POP (%d)" % rr)
	ok(pm.abil_ready <= sm.time, "mongoles: no consume enfriamiento sin sitio")

	# Efectos concretos de los buffs sobre el combate
	var sc := make_sim(["teutones", "francos"])
	var pt: Player = sc.players[0]
	pt.age = 1
	var tu := sc._spawn_unit("espadachin", 0, free_near(sc, pt.start_tile + Vector2i(5, 5), "casa", 0))
	var fu := sc._spawn_unit("espadachin", 1, free_near(sc, (sc.players[0] as Player).start_tile + Vector2i(6, 5), "casa", 0))
	var h0 := tu.hp
	sc._damage(tu, 10.0, fu, false)
	var lost_plain := h0 - tu.hp
	ok(sc.cmd_ability(0) == Sim.OK, "teutones: muro de escudos")
	tu.hp = h0
	sc._damage(tu, 10.0, fu, false)
	var lost_buff := h0 - tu.hp
	ok(lost_buff < lost_plain * 0.8, "teutones: daño recibido reducido (%.2f vs %.2f)" % [lost_buff, lost_plain])

# --- guardado y carga
func test_save() -> void:
	var sim := make_sim(["bizantinos", "vikingos"])
	var p: Player = sim.players[0]
	rich(p)
	p.age = 1
	var t := free_near(sim, p.start_tile + Vector2i(8, 3), "casa", 0)
	ok(sim.cmd_ability(0, t) == Sim.OK, "guardado: fuego lanzado")
	var p1: Player = sim.players[1]
	p1.age = 1
	ok(sim.cmd_ability(1) == Sim.OK, "guardado: berserker lanzado")
	run(sim, 3.0)
	var cfg := {"size": 128, "seed": 7, "events": false, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "J0", "civ": "bizantinos"},
		{"human": false, "team": 1, "diff": 1, "name": "J1", "civ": "vikingos"}]}
	var data := {"magic": SaveGame.MAGIC, "format": SaveGame.FORMAT, "saved_at": 0, "cfg": cfg,
		"sim": SaveGame.snapshot_sim(sim), "game": {},
		"meta": {"time": sim.time, "size": sim.W, "rivals": 1, "age": 0, "pop": 0}}
	var s2 := SaveGame.restore(data)
	ok(s2 != null, "guardado: se restaura")
	if s2 == null:
		return
	var q: Player = s2.players[0]
	var q1: Player = s2.players[1]
	ok(q.civ == "bizantinos" and q1.civ == "vikingos", "guardado: civilizaciones")
	ok(absf(q.abil_ready - p.abil_ready) < 0.001, "guardado: enfriamiento de habilidad")
	ok(q1.abil_on == p1.abil_on and absf(q1.b_atk - p1.b_atk) < 0.001, "guardado: buff activo")
	ok(q1.b_types.size() == p1.b_types.size(), "guardado: tipos del buff (%d)" % q1.b_types.size())
	ok(s2.zones.size() == sim.zones.size(), "guardado: zonas de fuego")
	ok(s2.civ_mods.size() == 2 and absf(float((s2.civ_mods[0] as Dictionary)["heal"]) - 1.4) < 0.001, "guardado: tablas de civilización rebuild")
	# ambas partidas deben seguir igual
	run(sim, 20.0)
	run(s2, 20.0)
	ok(var_to_bytes(SaveGame.snapshot_sim(sim)) == var_to_bytes(SaveGame.snapshot_sim(s2)), "guardado: la partida cargada sigue igual que la original")

# --- niebla: Espejismo (sarracenos) y vista +2 (mongoles)
func test_fog() -> void:
	var sim := make_sim(["sarracenos", "francos"])
	var p: Player = sim.players[0]
	var e: Player = sim.players[1]
	var fog := Fog.new(sim.W, sim.H)
	fog.update(sim, 0)
	var et := sim.tile_of(sim.tile_center(e.start_tile))
	ok(fog.state[et.y * fog.W + et.x] == 0, "niebla: la base enemiga empieza sin explorar")
	p.age = 1
	ok(sim.cmd_ability(0) == Sim.OK, "niebla: Espejismo")
	fog.update(sim, 0)
	ok(fog.state[et.y * fog.W + et.x] == 2, "niebla: con Espejismo la base enemiga se ve")
	run(sim, float(Civs.ability_of("sarracenos")["dur"]) + 1.0)
	fog.update(sim, 0)
	ok(fog.state[et.y * fog.W + et.x] != 2, "niebla: al acabar Espejismo deja de verse")
	ok(fog.state[et.y * fog.W + et.x] == 1, "niebla: ... pero queda explorada")
	# los mongoles ven 2 casillas más con la caballería
	var m := make_sim(["mongoles", "francos"], 9)
	var mp: Player = m.players[0]
	var far := m.nearest_free_tile(mp.start_tile + Vector2i(20, 20), 6)
	var u1 := m._spawn_unit("jinete", 0, far)
	var f1 := Fog.new(m.W, m.H)
	f1.update(m, 0)
	var edge := far + Vector2i(int(u1.def["los"]) + 2, 0)
	if edge.x < m.W:
		ok(f1.state[edge.y * f1.W + edge.x] == 2, "niebla: los mongoles ven +2 casillas con el jinete")

# --- sin civilización
func test_no_civ() -> void:
	var sim := make_sim(["", ""])
	for i in 2:
		var p: Player = sim.players[i]
		ok(p.civ == "", "sin civ: vacío")
		ok(sim.cmd_ability(i) == Sim.ERR_INVALID, "sin civ: sin habilidad")
		ok(not bool(sim.ability_state(i)["has"]), "sin civ: ability_state")
	var u := sim._spawn_unit("caballero", 0, free_near(sim, (sim.players[0] as Player).start_tile, "casa", 0))
	ok(absf(u.max_hp - float(Defs.UNITS["caballero"]["hp"])) < 0.01 and u.am == 1.0 and u.sm == 1.0 and u.rm == 1.0 and u.lb == 0, "sin civ: estadísticas base")
	# dos partidas idénticas sin civilización deben coincidir tras simular (determinismo)
	var a := make_sim(["", ""], 11)
	var b := make_sim(["", ""], 11)
	run(a, 30.0)
	run(b, 30.0)
	ok(var_to_bytes(SaveGame.snapshot_sim(a)) == var_to_bytes(SaveGame.snapshot_sim(b)), "determinismo sin civ")
	# y con civ también
	var c := make_sim(["francos", "teutones"], 11)
	var d := make_sim(["francos", "teutones"], 11)
	run(c, 30.0)
	run(d, 30.0)
	ok(var_to_bytes(SaveGame.snapshot_sim(c)) == var_to_bytes(SaveGame.snapshot_sim(d)), "determinismo con civ")

# --- elección al azar sin repetir
func test_random_pick() -> void:
	var sim := make_sim(["random", "random", "random", "castellanos"])
	var seen := {}
	for p in sim.players:
		ok(Civs.valid(p.civ), "random: civ válida (%s)" % p.civ)
		ok(not seen.has(p.civ), "random: sin repetir (%s)" % p.civ)
		seen[p.civ] = true
	ok((sim.players[3] as Player).civ == "castellanos", "random: la elegida se respeta")
