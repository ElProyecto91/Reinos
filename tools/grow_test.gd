extends SceneTree
## Plantar árboles y crear minas de oro, en la simulación pura.
## godot --headless --path . --script res://tools/grow_test.gd
var fails := 0
var checks := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FALLO: ", msg)

func make_sim(seed_v: int = 7, size: int = 128) -> Sim:
	var sim := Sim.new()
	sim.setup({"size": size, "seed": seed_v, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "A", "civ": ""},
		{"human": false, "team": 1, "diff": 1, "name": "B", "civ": ""}]})
	sim.ais.clear()
	return sim

func run(sim: Sim, secs: float) -> void:
	for i in int(secs / Sim.DT):
		sim.step()

func rich(sim: Sim, pidx: int, age: int = 1) -> Player:
	var p: Player = sim.players[pidx]
	p.age = age
	p.res = {"food": 5000, "wood": 5000, "gold": 0, "stone": 5000}
	p.pop_cap = 200
	return p

## Casillas donde se puede plantar, de cerca a lejos de `near`, separadas entre sí (para no taparse unas a otras).
func plant_spots(sim: Sim, near: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(2, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r or (dx + dy) % 2 != 0:
					continue
				var q := near + Vector2i(dx, dy)
				if sim.can_plant(q):
					out.append(q)
					if out.size() >= n:
						return out
	return out

func count_chunk(sim: Sim, rt: int) -> int:
	var n := 0
	for c in sim.chunk_cnt[rt]:
		n += int(c)
	return n

func count_rt(sim: Sim, rt: int) -> int:
	var n := 0
	for i in sim.W * sim.H:
		if sim.rtype[i] == rt:
			n += 1
	return n

func _init() -> void:
	test_plant_rules()
	test_growth()
	test_growth_waits_for_units()
	test_harvest_grown_tree()
	test_mine_build()
	test_mine_limit_and_depletion()
	test_save()
	print("grow_test: %d comprobaciones, %d fallos" % [checks, fails])
	quit(1 if fails > 0 else 0)

func test_plant_rules() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 0)
	var v := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(p.start_tile + Vector2i(0, 5), 5))
	var spots := plant_spots(sim, p.start_tile + Vector2i(0, 6), 40)
	ok(spots.size() >= 35, "hay sitio para plantar (%d)" % spots.size())
	var wood0 := int(p.res["wood"])
	var r := sim.cmd_build(0, [v.id], "arbol", spots[0])
	ok(r == Sim.OK, "plantar devuelve OK (%d)" % r)
	var idx := spots[0].y * sim.W + spots[0].x
	ok(sim.rtype[idx] == Defs.R_SAPLING, "queda un retoño en la casilla")
	ok(int(p.res["wood"]) == wood0 - int(Defs.PLANT_COST["wood"]), "se paga la madera (%d)" % (wood0 - int(p.res["wood"])))
	ok(int(sim.ramt[idx]) == Defs.PLANT_GROW and sim.rowner[idx] == 0, "crecimiento y dueño anotados")
	ok(not sim.is_solid_tile(spots[0]), "el retoño no es sólido")
	ok(sim.saplings.has(idx) and sim.sapling_count(0) == 1, "figura en la lista de retoños")
	ok(count_chunk(sim, Defs.R_SAPLING) == 1, "el recuento por fragmentos lo ve")
	# no se recolecta
	var before := int(sim.ramt[idx])
	sim.cmd_gather(0, [v.id], spots[0])
	ok(v.state == Sim.S_IDLE, "una orden de recolectar sobre el retoño se ignora")
	ok(sim.find_resource(spots[0], sim.res_mask_for("wood"), 0, v.id, 3, 200).x != spots[0].x or sim.find_resource(spots[0], sim.res_mask_for("wood"), 0, v.id, 3, 200).y != spots[0].y, "la búsqueda de madera no devuelve el retoño")
	ok(int(sim.ramt[idx]) == before, "nadie lo toca")
	# reglas
	ok(sim.cmd_build(0, [v.id], "arbol", spots[0]) == Sim.ERR_PLACE, "no se planta dos veces en la misma casilla")
	var water := Vector2i(-1, -1)
	for i in sim.W * sim.H:
		if sim.terrain[i] == Defs.T_WATER:
			water = Vector2i(i % sim.W, i / sim.W)
			break
	if water.x >= 0:
		ok(sim.cmd_build(0, [v.id], "arbol", water) == Sim.ERR_PLACE, "no se planta en el agua")
	ok(sim.cmd_build(0, [v.id], "arbol", Vector2i(-3, 5)) == Sim.ERR_PLACE, "fuera del mapa no se planta")
	# pegado a un edificio no (el centro ocupa 3x3 desde start_tile)
	var tc := sim.get_ent(sim.occ[p.start_tile.y * sim.W + p.start_tile.x])
	var side := Vector2i(tc.tile.x + tc.size, tc.tile.y)
	ok(not sim.can_plant(side), "no se planta pegado a un edificio")
	var q := p.res.duplicate()
	p.res["wood"] = 5
	ok(sim.cmd_build(0, [v.id], "arbol", spots[1]) == Sim.ERR_COST, "sin madera no se planta")
	p.res = q
	# tope de retoños
	var n := 1
	for i in range(1, spots.size()):
		var rr := sim.cmd_build(0, [v.id], "arbol", spots[i])
		if rr == Sim.OK:
			n += 1
		elif rr == Sim.ERR_LIMIT:
			break
	ok(n == Defs.PLANT_MAX, "el tope son %d retoños a la vez (%d)" % [Defs.PLANT_MAX, n])
	ok(sim.cmd_build(0, [v.id], "arbol", spots[spots.size() - 1]) == Sim.ERR_LIMIT, "el siguiente da ERR_LIMIT")
	# el rival no cuenta en mi tope
	ok(sim.sapling_count(1) == 0, "los retoños de otro jugador se cuentan aparte")
	# sin aldeanos no se planta
	var sim2 := make_sim()
	rich(sim2, 0, 0)
	ok(sim2.cmd_build(0, [], "arbol", plant_spots(sim2, sim2.players[0].start_tile, 1)[0]) == Sim.ERR_NOUNITS, "hace falta un aldeano")

func test_growth() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 0)
	var v := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(p.start_tile + Vector2i(0, 5), 5))
	var spots := plant_spots(sim, p.start_tile + Vector2i(0, 8), 6)
	for t in spots:
		sim.cmd_build(0, [v.id], "arbol", t)
	var trees0 := count_rt(sim, Defs.R_TREE)
	var ch0 := count_chunk(sim, Defs.R_TREE)
	run(sim, 60.0)
	ok(count_rt(sim, Defs.R_SAPLING) == spots.size(), "a los 60 s siguen siendo retoños")
	var idx0 := spots[0].y * sim.W + spots[0].x
	ok(int(sim.ramt[idx0]) > 0 and int(sim.ramt[idx0]) < Defs.PLANT_GROW, "el contador avanza (%d)" % int(sim.ramt[idx0]))
	run(sim, 35.0)
	ok(count_rt(sim, Defs.R_SAPLING) == 0, "a los 95 s ya no queda ninguno (%d)" % count_rt(sim, Defs.R_SAPLING))
	ok(count_rt(sim, Defs.R_TREE) == trees0 + spots.size(), "todos son árboles (%d → %d)" % [trees0, count_rt(sim, Defs.R_TREE)])
	var i0 := spots[0].y * sim.W + spots[0].x
	ok(sim.rtype[i0] == Defs.R_TREE and int(sim.ramt[i0]) == int(Defs.RES_INFO[Defs.R_TREE]["amount"]), "el árbol trae su madera completa")
	ok(sim.is_solid_tile(spots[0]), "el árbol crecido es sólido")
	ok(sim.rowner[i0] == 255, "ya no tiene dueño")
	ok(sim.saplings.is_empty(), "la lista de retoños se vacía")
	ok(count_chunk(sim, Defs.R_TREE) == ch0 + spots.size() and count_chunk(sim, Defs.R_SAPLING) == 0, "los fragmentos cuadran")
	# el evento de crecimiento llega
	var grown := 0
	for ev: Dictionary in sim.events:
		if ev["t"] == "grown":
			grown += 1
	ok(grown == spots.size(), "un evento 'grown' por árbol (%d)" % grown)
	# se pueden volver a plantar tras crecer (el tope cuenta sólo retoños)
	ok(sim.sapling_count(0) == 0, "ya hay hueco para otros")

func test_growth_waits_for_units() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 0)
	var v := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(p.start_tile + Vector2i(0, 5), 5))
	var spots := plant_spots(sim, p.start_tile + Vector2i(0, 9), 1)
	var t := spots[0]
	ok(sim.cmd_build(0, [v.id], "arbol", t) == Sim.OK, "planta")
	var idx := t.y * sim.W + t.x
	sim.ramt[idx] = 10
	# alguien se planta encima: no crece
	var w := sim._spawn_unit("aldeano", 1, t)
	w.pos = sim.tile_center(t)
	w.ppos = w.pos
	var steps := 0
	while steps < 60:
		w.pos = sim.tile_center(t)
		w.ppos = w.pos
		sim.step()
		steps += 1
	ok(sim.rtype[idx] == Defs.R_SAPLING, "con un aldeano encima sigue siendo retoño")
	ok(not sim.is_solid_tile(t), "y no es sólido")
	# se aparta y entonces crece
	w.pos = sim.tile_center(t + Vector2i(4, 0))
	w.ppos = w.pos
	run(sim, 8.0)
	ok(sim.rtype[idx] == Defs.R_TREE, "al apartarse, crece")
	ok(sim.is_solid_tile(t), "ya es sólido")

func test_harvest_grown_tree() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 0)
	p.res["wood"] = 100
	var v := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(p.start_tile + Vector2i(0, 5), 5))
	var spots := plant_spots(sim, p.start_tile + Vector2i(5, 5), 1)
	var t := spots[0]
	sim.cmd_build(0, [v.id], "arbol", t)
	sim.ramt[t.y * sim.W + t.x] = 5
	run(sim, 3.0)
	ok(sim.rtype[t.y * sim.W + t.x] == Defs.R_TREE, "crece (forzado)")
	var wood0 := int(p.res["wood"])
	var gathered0 := int(p.gathered.get("wood", 0))
	sim.cmd_gather(0, [v.id], t)
	run(sim, 200.0)
	ok(int(p.gathered.get("wood", 0)) >= gathered0 + 90, "el aldeano saca la madera del árbol plantado (+%d)" % (int(p.gathered.get("wood", 0)) - gathered0))
	ok(int(p.res["wood"]) > wood0, "y la entrega")
	ok(sim.rtype[t.y * sim.W + t.x] == 0 and not sim.is_solid_tile(t), "al talarlo queda el suelo libre")

func mine_site(sim: Sim, near: Vector2i, taken: Array[Vector2i] = []) -> Vector2i:
	for r in range(0, 24):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := near + Vector2i(dx, dy)
				if not sim.can_place("mina", q, 0) or not sim.can_reach_building(sim.players[0].start_tile + Vector2i(0, 5), "mina", q):
					continue
				var clash := false
				for t in taken:
					if maxi(absi(t.x - q.x), absi(t.y - q.y)) < 4:
						clash = true
				if not clash:
					return q
	return Vector2i(-1, -1)

func test_mine_build() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 0)
	var v := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(p.start_tile + Vector2i(0, 5), 5))
	var site := mine_site(sim, p.start_tile + Vector2i(7, 3))
	ok(site.x >= 0, "hay sitio para una mina")
	ok(sim.cmd_build(0, [v.id], "mina", site) == Sim.ERR_AGE, "la mina pide la Edad Feudal")
	p.age = 1
	p.res["stone"] = 10
	ok(sim.cmd_build(0, [v.id], "mina", site) == Sim.ERR_COST, "sin piedra no hay mina")
	p.res["stone"] = 500
	var w0 := int(p.res["wood"])
	var s0 := int(p.res["stone"])
	var gold0 := int(p.res["gold"])
	var bid := sim.cmd_build(0, [v.id], "mina", site)
	ok(bid > 0, "la obra se coloca (%d)" % bid)
	ok(w0 - int(p.res["wood"]) == 80 and s0 - int(p.res["stone"]) == 70, "cuesta 80 madera y 70 piedra")
	var b := sim.get_ent(bid)
	ok(b != null and b.type == "mina" and b.progress < 1.0, "es un edificio en obras")
	ok(sim.mine_count(0) == 1, "cuenta como mina (en obras)")
	run(sim, 20.0)
	ok(sim.get_ent(bid) != null and sim.rtype[site.y * sim.W + site.x] == 0, "a media obra aún no hay oro")
	run(sim, 25.0)
	var si := site.y * sim.W + site.x
	ok(sim.rtype[si] == Defs.R_GOLD, "al terminar queda un depósito de oro")
	ok(sim.get_ent(bid) == null and not b.alive, "el edificio desaparece")
	ok(sim.rowner[si] == 0 and sim.mines.has(si), "el depósito es mío")
	ok(sim.is_solid_tile(site), "el depósito es sólido")
	var free := 0
	for dy in 2:
		for dx in 2:
			var t := site + Vector2i(dx, dy)
			if t != site and not sim.is_solid_tile(t) and sim.occ[t.y * sim.W + t.x] == 0:
				free += 1
	ok(free == 3, "las otras 3 casillas de la obra quedan libres (%d)" % free)
	ok(sim.occ[si] == 0, "ya no hay edificio en la casilla")
	ok(int(sim.ramt[si]) <= Defs.MINE_YIELD and int(sim.ramt[si]) > Defs.MINE_YIELD - 60, "trae unos %d de oro (quedan %d)" % [Defs.MINE_YIELD, int(sim.ramt[si])])
	ok(count_chunk(sim, Defs.R_GOLD) == count_rt(sim, Defs.R_GOLD), "los fragmentos cuadran")
	ok(v.state == Sim.S_GATHER or v.state == Sim.S_GATHER_GO or v.state == Sim.S_RETURN, "el constructor se pone a picar (estado %d)" % v.state)
	var opened := 0
	for ev: Dictionary in sim.events:
		if ev["t"] == "mine_open":
			opened += 1
	ok(opened == 1, "un evento 'mine_open'")
	run(sim, 150.0)
	ok(int(p.res["gold"]) > gold0 + 30, "el oro llega al almacén (+%d)" % (int(p.res["gold"]) - gold0))
	ok(not sim.game_over, "la partida sigue")

func test_mine_limit_and_depletion() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 1)
	var v := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(p.start_tile + Vector2i(0, 5), 5))
	var sites: Array[Vector2i] = []
	for k in 4:
		var s := mine_site(sim, p.start_tile + Vector2i(6, 8), sites)
		sites.append(s)
		if k < Defs.MINE_MAX:
			var rr := sim.cmd_build(0, [v.id], "mina", s)
			ok(rr > 0, "mina %d (resultado %d, sitio %s)" % [k + 1, rr, str(s)])
	ok(sim.mine_count(0) == Defs.MINE_MAX, "tres a la vez")
	ok(sim.cmd_build(0, [v.id], "mina", sites[3]) == Sim.ERR_LIMIT, "la cuarta da ERR_LIMIT")
	# terminar una y agotarla: se libera el hueco
	for b in sim.buildings.duplicate():
		if b.type == "mina" and b.progress < 1.0:
			b.progress = 1.0
			sim._on_building_complete(b, true)
	run(sim, 1.0)
	var open_ := 0
	for s in sites:
		if s.x >= 0 and sim.rtype[s.y * sim.W + s.x] == Defs.R_GOLD:
			open_ += 1
	ok(open_ == Defs.MINE_MAX, "al terminar pasan a ser depósitos (%d)" % open_)
	ok(sim.mine_count(0) == Defs.MINE_MAX, "los depósitos con oro siguen contando")
	var si := sites[0].y * sim.W + sites[0].x
	sim.ramt[si] = 1
	v.pos = sim.tile_center(sites[0] + Vector2i(-1, 0))
	v.ppos = v.pos
	sim.cmd_gather(0, [v.id], sites[0])
	run(sim, 15.0)
	ok(sim.rtype[si] == 0 and not sim.mines.has(si) and not sim.is_solid_tile(sites[0]), "agotada: desaparece de la lista y queda libre")
	ok(sim.mine_count(0) < Defs.MINE_MAX, "se libera un hueco (%d)" % sim.mine_count(0))
	ok(sim.cmd_build(0, [v.id], "mina", sites[3]) > 0, "ya se puede hacer otra")
	# el mapa trae oro natural: ese no cuenta
	ok(count_rt(sim, Defs.R_GOLD) > sim.mines.size(), "el oro natural no es de nadie")

func test_save() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 1)
	var v := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(p.start_tile + Vector2i(0, 5), 5))
	var spots := plant_spots(sim, p.start_tile + Vector2i(0, 9), 5)
	for t in spots:
		sim.cmd_build(0, [v.id], "arbol", t)
	run(sim, 30.0)
	var s := mine_site(sim, p.start_tile + Vector2i(8, 3))
	sim.cmd_build(0, [v.id], "mina", s)
	run(sim, 45.0)
	var s2 := mine_site(sim, p.start_tile + Vector2i(-9, 3))
	sim.cmd_build(0, [v.id], "mina", s2)
	run(sim, 5.0)
	var data := SaveGame.snapshot_sim(sim)
	var back := SaveGame.restore({"sim": data})
	ok(back != null, "la partida se restaura")
	if back == null:
		return
	ok(back.saplings.size() == sim.saplings.size() and back.saplings.size() == spots.size(), "retoños restaurados (%d)" % back.saplings.size())
	ok(back.mines.size() == sim.mines.size() and back.mines.size() == 1, "minas restauradas (%d)" % back.mines.size())
	ok(back.mine_count(0) == sim.mine_count(0) and back.mine_count(0) == 2, "mine_count igual (%d)" % back.mine_count(0))
	ok(back.sapling_count(0) == sim.sapling_count(0), "sapling_count igual")
	ok(count_chunk(back, Defs.R_SAPLING) == spots.size(), "fragmentos de retoños bien")
	run(back, 70.0)
	run(sim, 70.0)
	ok(count_rt(back, Defs.R_SAPLING) == 0 and count_rt(back, Defs.R_TREE) == count_rt(sim, Defs.R_TREE), "los retoños crecen igual tras cargar")
	ok(back.mines.size() == sim.mines.size(), "la segunda mina también se convierte tras cargar")
	ok(int(back.players[0].res["gold"]) == int(sim.players[0].res["gold"]), "el oro coincide (%d / %d)" % [int(back.players[0].res["gold"]), int(sim.players[0].res["gold"])])
