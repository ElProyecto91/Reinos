extends SceneTree
## Economía y mecánicas nuevas en la simulación pura: piedra, caza, mercado, mejoras, guarnición, rebato, posturas, formaciones.
## godot --headless --path . --script res://tools/eco_test.gd
var fails := 0
var checks := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FALLO: ", msg)

func make_sim(seed_v: int = 7, size: int = 128, civs: Array = ["", ""]) -> Sim:
	var sim := Sim.new()
	sim.setup({"size": size, "seed": seed_v, "events": false, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "A", "civ": civs[0]},
		{"human": false, "team": 1, "diff": 1, "name": "B", "civ": civs[1]}]})
	sim.ais.clear()
	return sim

func run(sim: Sim, secs: float) -> void:
	for i in int(secs / Sim.DT):
		sim.step()

func place(sim: Sim, type: String, owner: int, near: Vector2i) -> Ent:
	for r in range(0, 24):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := near + Vector2i(dx, dy)
				if sim.can_place(type, q, owner):
					return sim._spawn_building(type, owner, q, true)
	return null

func rich(sim: Sim, pidx: int, age: int = 3) -> Player:
	var p: Player = sim.players[pidx]
	p.age = age
	p.res = {"food": 5000, "wood": 5000, "gold": 5000, "stone": 5000}
	p.pop_cap = 200
	return p

func _init() -> void:
	test_map_resources()
	test_stone_mining()
	test_hunting()
	test_market()
	test_research()
	test_garrison()
	test_bell_and_flee()
	test_stances()
	test_formation()
	test_save()
	print("eco_test: %d comprobaciones, %d fallos" % [checks, fails])
	quit(1 if fails > 0 else 0)

func count_near(sim: Sim, t: Vector2i, r: int, rts: Array) -> int:
	var n := 0
	for y in range(maxi(0, t.y - r), mini(sim.H, t.y + r + 1)):
		for x in range(maxi(0, t.x - r), mini(sim.W, t.x + r + 1)):
			if rts.has(int(sim.rtype[y * sim.W + x])):
				n += 1
	return n

func test_map_resources() -> void:
	for sd in [3, 7, 11]:
		var sim := make_sim(sd)
		for p in sim.players:
			var st := count_near(sim, p.start_tile, 20, [Defs.R_STONE])
			var an := count_near(sim, p.start_tile, 26, [Defs.R_DEER, Defs.R_BOAR])
			ok(st >= 3, "semilla %d: piedra cerca del inicio de %d (%d)" % [sd, p.idx, st])
			ok(an >= 3, "semilla %d: caza cerca del inicio de %d (%d)" % [sd, p.idx, an])
		ok(sim.fauna.size() > 10, "semilla %d: hay animales (%d)" % [sd, sim.fauna.size()])
		var n_an := 0
		for i in sim.W * sim.H:
			if Defs.is_animal(sim.rtype[i]):
				n_an += 1
		ok(n_an == sim.fauna.size(), "semilla %d: fauna registrada (%d/%d)" % [sd, n_an, sim.fauna.size()])

func nearest_res(sim: Sim, from: Vector2i, rt: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for y in sim.H:
		for x in sim.W:
			if sim.rtype[y * sim.W + x] == rt:
				var d := Vector2(from - Vector2i(x, y)).length()
				if d < bd:
					bd = d
					best = Vector2i(x, y)
	return best

func test_stone_mining() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 1)
	p.res["stone"] = 0
	var st := nearest_res(sim, p.start_tile, Defs.R_STONE)
	ok(st.x >= 0, "hay piedra en el mapa")
	var almacen := place(sim, "almacen", 0, st + Vector2i(0, 2))
	ok(almacen != null, "almacén junto a la cantera")
	var v := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(st + Vector2i(1, 1), 5))
	sim.cmd_gather(0, [v.id], st)
	run(sim, 90.0)
	ok(int(p.res["stone"]) > 20, "el aldeano extrae piedra (%d)" % int(p.res["stone"]))
	ok(int(p.gathered.get("stone", 0)) > 0, "la piedra cuenta en lo recolectado")
	# agotar una casilla: deja de ser sólida
	var idx := st.y * sim.W + st.x
	if sim.rtype[idx] == Defs.R_STONE:
		sim.ramt[idx] = 1
		var v2 := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(st + Vector2i(1, 1), 5))
		sim.cmd_gather(0, [v2.id], st)
		run(sim, 20.0)
	ok(sim.rtype[idx] == 0 and not sim.is_solid_tile(st), "casilla de piedra agotada queda libre")

func reachable_animal(sim: Sim, from: Vector2i, rts: Array) -> Vector2i:
	var cands: Array = []
	for a in sim.fauna:
		var i: int = a["i"]
		if rts.has(int(sim.rtype[i])):
			cands.append(Vector2i(i % sim.W, i / sim.W))
	cands.sort_custom(func(x: Vector2i, y: Vector2i) -> bool: return Vector2(x - from).length() < Vector2(y - from).length())
	for t: Vector2i in cands:
		if sim.astar.get_id_path(from, t, false).size() > 0:
			return t
	return Vector2i(-1, -1)

func test_hunting() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 1)
	p.res["food"] = 0
	var from := sim.nearest_free_tile(p.start_tile + Vector2i(0, 4), 4)
	var an := reachable_animal(sim, from, [Defs.R_DEER])
	ok(an.x >= 0, "hay ciervos al alcance")
	var f0 := sim.fauna.size()
	var v := sim._spawn_unit("aldeano", 0, from)
	sim.cmd_gather(0, [v.id], an)
	run(sim, 150.0)
	ok(int(p.res["food"]) > 30, "cazar da comida (%d)" % int(p.res["food"]))
	ok(sim.fauna.size() <= f0, "la fauna no crece")
	# paseo: sin nadie cerca los animales se mueven; con alguien al lado, no
	var sim2 := make_sim()
	var moved := 0
	var before: Array = []
	for a in sim2.fauna:
		before.append(int(a["i"]))
	run(sim2, 120.0)
	for k in sim2.fauna.size():
		if int(sim2.fauna[k]["i"]) != before[k]:
			moved += 1
	ok(moved >= 5, "los animales deambulan (%d de %d)" % [moved, sim2.fauna.size()])
	for a in sim2.fauna:
		var rt := int(sim2.rtype[int(a["i"])])
		ok(Defs.is_animal(rt), "cada registro de fauna está sobre un animal")
		break
	var hold: Dictionary = sim2.fauna[0]
	var hi: int = hold["i"]
	var guard := sim2._spawn_unit("aldeano", 0, sim2.nearest_free_tile(Vector2i(hi % sim2.W, hi / sim2.W) + Vector2i(2, 0), 4))
	run(sim2, 60.0)
	ok(int(hold["i"]) == hi, "un animal con gente cerca se queda quieto")
	ok(f0 > 0, "fauna inicial")

func test_market() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 1)
	ok(sim.cmd_trade(0, "wood", true) == Sim.ERR_NOMARKET, "sin mercado no se comercia")
	var m := place(sim, "mercado", 0, p.start_tile + Vector2i(6, 6))
	m.progress = 1.0
	ok(sim.has_market(0), "mercado terminado")
	var g0 := int(p.res["gold"])
	var s0 := int(p.res["stone"])
	var cost := sim.market_buy_cost(0, "stone")
	ok(sim.cmd_trade(0, "stone", true) == Sim.OK, "comprar piedra")
	ok(int(p.res["stone"]) == s0 + Sim.MKT_LOT and int(p.res["gold"]) == g0 - cost, "compra: +%d piedra, −%d oro" % [Sim.MKT_LOT, cost])
	ok(int(p.mkt["stone"]) > 100, "comprar sube el precio")
	var sell := sim.market_sell_gain(0, "stone")
	ok(sell < cost, "vender da menos que cuesta comprar (%d < %d)" % [sell, cost])
	var p1 := int(p.mkt["stone"])
	ok(sim.cmd_trade(0, "stone", false) == Sim.OK, "vender piedra")
	ok(int(p.mkt["stone"]) < p1, "vender baja el precio")
	p.res["gold"] = 0
	ok(sim.cmd_trade(0, "wood", true) == Sim.ERR_COST, "sin oro no se compra")
	p.res["food"] = 50
	ok(sim.cmd_trade(0, "food", false) == Sim.ERR_COST, "sin existencias no se vende")
	ok(sim.cmd_trade(0, "gold", true) == Sim.ERR_INVALID, "el oro no se compra con oro")
	p.mkt["wood"] = 160
	run(sim, 100.0)
	ok(int(p.mkt["wood"]) < 160, "el precio vuelve poco a poco a 100 (%d)" % int(p.mkt["wood"]))
	for i in 80:
		p.res["wood"] = 500
		sim.cmd_trade(0, "wood", false)
	ok(int(p.mkt["wood"]) >= 20, "el precio nunca baja de 20")

func test_research() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 0)
	var h := place(sim, "centro", 0, p.start_tile + Vector2i(14, 0))
	var c := h
	ok(sim.cmd_research(0, c.id, "telar") == Sim.OK, "telar se encola en el Centro")
	ok(sim.cmd_research(0, c.id, "telar") == Sim.ERR_DONE, "no se encola dos veces")
	ok(sim.cmd_research(0, c.id, "arado_2") == Sim.ERR_AGE, "arado_2 pide la edad Feudal")
	ok(sim.cmd_research(0, c.id, "forja_1") == Sim.ERR_INVALID, "forja_1 no se investiga en el Centro")
	var food0 := int(p.res["food"])
	ok(sim.cmd_research(0, c.id, "arado") == Sim.OK, "arado se encola")
	sim.cmd_cancel_train(0, c.id, 1)
	ok(int(p.res["food"]) == food0, "cancelar devuelve el coste")
	ok(not p.techs.has("arado"), "cancelada: sin efecto")
	var v := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(p.start_tile + Vector2i(3, 3), 5))
	var hp0 := v.max_hp
	var res0 := p.reserved
	run(sim, 5.0)
	ok(c.producing and c.prod_tech, "el Centro investiga")
	ok(p.reserved == res0, "investigar no reserva población")
	run(sim, 30.0)
	ok(p.techs.has("telar"), "telar investigado")
	ok(absf(v.max_hp - hp0 * 1.4) < 0.01, "telar da +40%% de vida a los aldeanos existentes (%s→%s)" % [hp0, v.max_hp])
	var v2 := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(p.start_tile + Vector2i(3, 4), 5))
	ok(absf(v2.max_hp - hp0 * 1.4) < 0.01, "…y a los nuevos")
	ok(sim.cmd_research(0, c.id, "telar") == Sim.ERR_DONE, "ya investigada")
	# herrería: ataque, alcance y armadura
	p.age = 2
	var hb := place(sim, "herreria", 0, p.start_tile + Vector2i(-12, 6))
	ok(hb != null, "herrería colocada")
	hb.progress = 1.0
	ok(sim.cmd_research(0, hb.id, "forja_2") == Sim.ERR_REQ, "forja_2 pide forja_1")
	var sw := sim._spawn_unit("espadachin", 0, sim.nearest_free_tile(p.start_tile + Vector2i(-6, 0), 5))
	var ar := sim._spawn_unit("arquero", 0, sim.nearest_free_tile(p.start_tile + Vector2i(-6, 1), 5))
	var r0 := sim.eff_range(ar)
	var a0 := sim._up_atk(sw)
	for t in ["forja_1", "flechas_1", "arm_inf_1"]:
		ok(sim.cmd_research(0, hb.id, t) == Sim.OK, "encolar " + t)
	run(sim, 130.0)
	ok(p.techs.has("forja_1") and p.techs.has("flechas_1") and p.techs.has("arm_inf_1"), "las tres terminan en cola")
	ok(sim._up_atk(sw) > a0 + 0.09, "forja_1: más daño de infantería")
	ok(sim.eff_range(ar) > r0 + 0.4, "flechas_1: más alcance de arqueros")
	var en := sim._spawn_unit("espadachin", 1, sim.nearest_free_tile(p.start_tile + Vector2i(-5, 0), 5))
	var hp_a := sw.hp
	sim._damage(sw, 10.0, en)
	ok(absf((hp_a - sw.hp) - 9.0) < 0.01, "arm_inf_1 recorta un 10%% el daño (%s)" % [hp_a - sw.hp])
	var hp_b := sw.hp
	sim._damage(sw, 10.0, en, true)
	ok(absf((hp_b - sw.hp) - 10.0) < 0.01, "el daño directo ignora la armadura")
	# recolección más rápida con hacha
	var sim2 := make_sim()
	var q := rich(sim2, 0, 0)
	var al := place(sim2, "almacen", 0, q.start_tile + Vector2i(10, 0))
	ok(sim2.cmd_research(0, al.id, "hacha") == Sim.OK, "hacha en el almacén")
	run(sim2, 40.0)
	ok(q.techs.has("hacha"), "hacha investigada")
	ok(sim2.up_mods[0]["gather"][Defs.R_TREE] > 1.19, "hacha: +20%% a la madera")

func test_garrison() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 2)
	var tw := place(sim, "torre", 0, p.start_tile + Vector2i(12, 0))
	tw.progress = 1.0
	var us: Array = []
	for i in 6:
		us.append(sim._spawn_unit("arquero" if i < 4 else "aldeano", 0, sim.nearest_free_tile(tw.tile + Vector2i(-3, i), 6)).id)
	ok(sim.cmd_garrison(0, us, tw.id) == Sim.OK, "orden de refugiarse")
	run(sim, 15.0)
	ok(tw.cargo.size() == 5, "la torre admite 5 (%d)" % tw.cargo.size())
	var out := 0
	for id in us:
		var u := sim.get_ent(id)
		if u != null and not u.stowed:
			out += 1
	ok(out == 1, "el sexto se queda fuera (%d)" % out)
	ok(sim.cmd_garrison(0, [sim._spawn_unit("aldeano", 0, tw.tile + Vector2i(-2, 0)).id], tw.id) == Sim.ERR_FULL, "torre llena")
	# flechas: más cadencia con arqueros dentro
	var foe := sim._spawn_unit("espadachin", 1, sim.nearest_free_tile(tw.tile + Vector2i(5, 0), 4))
	foe.max_hp = 100000.0
	foe.hp = 100000.0
	sim.cmd_stance(1, [foe.id], Sim.ST_PASSIVE)
	var hp0 := foe.hp
	run(sim, 12.0)
	var dmg_garrison := hp0 - foe.hp
	var inside: Array = tw.cargo.duplicate()
	tw.cargo.clear()                    # sin refugiados la torre dispara a su ritmo normal
	foe.hp = hp0
	run(sim, 12.0)
	var dmg_alone := hp0 - foe.hp
	tw.cargo.append_array(inside)
	ok(dmg_garrison > dmg_alone * 1.8, "los arqueros refugiados suman flechas (%.0f vs %.0f)" % [dmg_garrison, dmg_alone])
	# curación
	var sim2 := make_sim()
	var q := rich(sim2, 0, 1)
	var c2 := place(sim2, "centro", 0, q.start_tile + Vector2i(14, 0))
	var hurt := sim2._spawn_unit("espadachin", 0, sim2.nearest_free_tile(c2.tile + Vector2i(-2, 0), 5))
	hurt.hp = hurt.max_hp * 0.3
	sim2.cmd_garrison(0, [hurt.id], c2.id)
	run(sim2, 12.0)
	ok(hurt.stowed and hurt.hp > hurt.max_hp * 0.3, "se cura dentro (%.0f/%.0f)" % [hurt.hp, hurt.max_hp])
	var pop0 := q.pop
	ok(sim2.cmd_ungarrison(0, c2.id) == Sim.OK, "salir")
	ok(not hurt.stowed and sim2.units.has(hurt) and sim2.get_ent(hurt.id) == hurt, "vuelve al mapa")
	ok(q.pop == pop0, "la población no cambia al entrar y salir")
	# edificio destruido: los refugiados salen vivos
	sim2.cmd_garrison(0, [hurt.id], c2.id)
	run(sim2, 8.0)
	ok(hurt.stowed, "dentro otra vez")
	sim2._kill(c2, null)
	sim2.step()
	ok(not hurt.stowed and hurt.alive, "si cae el edificio salen a pie")

func stowed_count(us: Array) -> int:
	var n := 0
	for u: Ent in us:
		if u.stowed:
			n += 1
	return n

func test_bell_and_flee() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 1)
	var c := place(sim, "centro", 0, p.start_tile + Vector2i(14, 0))
	var vs: Array = []
	for i in 8:
		var v := sim._spawn_unit("aldeano", 0, sim.nearest_free_tile(c.tile + Vector2i(-3 + i % 4, 4 + i / 4), 6))
		vs.append(v)
	ok(sim.cmd_bell(0, true) == Sim.OK, "rebato")
	run(sim, 12.0)
	ok(stowed_count(vs) >= 7, "los aldeanos se refugian (%d de 8)" % stowed_count(vs))
	run(sim, 20.0)
	ok(stowed_count(vs) >= 7, "siguen dentro mientras suena el rebato")
	ok(sim.cmd_bell(0, false) == Sim.OK, "fin del rebato")
	ok(stowed_count(vs) == 0, "salen todos (%d dentro)" % stowed_count(vs))
	# huida automática
	var raider := sim._spawn_unit("espadachin", 1, sim.nearest_free_tile(c.tile + Vector2i(-3, 6), 6))
	var victim: Ent = vs[0]
	victim.pos = sim.tile_center(sim.nearest_free_tile(c.tile + Vector2i(-2, 5), 5))
	sim._damage(victim, 1.0, raider)
	ok(victim.state == Sim.S_GARRISON_GO, "atacado, huye al refugio")
	raider.alive = false
	raider.hp = 0
	sim._kill(raider, null)
	run(sim, 30.0)
	ok(not victim.stowed, "pasado el peligro, sale solo")

## Punto cercano a `want` desde el que todas las posiciones de prueba de las posturas (hasta 16 casillas al sur) son terreno libre:
## el reparto de las bases cambia con el generador de mapas y no debe decidir si la prueba coloca a las unidades en el mar.
func _open_field(sim: Sim, want: Vector2i) -> Vector2i:
	var offs := [Vector2i(0, 0), Vector2i(5, 0), Vector2i(0, 8), Vector2i(1, 8), Vector2i(0, 16), Vector2i(3, 16)]
	for r in range(0, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var b := want + Vector2i(dx, dy)
				var good := true
				for o: Vector2i in offs:
					var t := b + o
					if not sim.in_bounds(t) or sim.is_solid_tile(t):
						good = false
						break
				if good:
					return b
	return want

func test_stances() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 2)
	var base := _open_field(sim, p.start_tile + Vector2i(12, 12))
	var mk := func(type: String, owner: int, off: Vector2i) -> Ent:
		return sim._spawn_unit(type, owner, sim.nearest_free_tile(base + off, 6))
	# mantener posición: no persigue
	var holder: Ent = mk.call("espadachin", 0, Vector2i(0, 0))
	sim.cmd_stance(0, [holder.id], Sim.ST_HOLD)
	var lure: Ent = mk.call("arquero", 1, Vector2i(5, 0))
	lure.max_hp = 9999.0
	lure.hp = 9999.0
	sim.cmd_stance(1, [lure.id], Sim.ST_PASSIVE)
	var h0 := holder.pos
	run(sim, 6.0)
	ok(holder.pos.distance_to(h0) < 3.0, "mantener posición: no sale a por el enemigo")
	# pasiva: ni se defiende
	var pas: Ent = mk.call("espadachin", 0, Vector2i(0, 8))
	sim.cmd_stance(0, [pas.id], Sim.ST_PASSIVE)
	var foe: Ent = mk.call("espadachin", 1, Vector2i(1, 8))
	sim.cmd_stance(1, [foe.id], Sim.ST_PASSIVE)
	sim._damage(pas, 1.0, foe)
	run(sim, 3.0)
	ok(pas.state == Sim.S_IDLE, "pasiva: no responde")
	# agresiva por defecto: sí
	var agg: Ent = mk.call("espadachin", 0, Vector2i(0, 16))
	var foe2: Ent = mk.call("espadachin", 1, Vector2i(3, 16))
	sim.cmd_stance(1, [foe2.id], Sim.ST_PASSIVE)
	run(sim, 4.0)
	ok(agg.state == Sim.S_ATTACK_GO or agg.state == Sim.S_ATTACK or not foe2.alive, "agresiva: va a por el enemigo cercano")
	ok(sim.cmd_stance(0, [agg.id], 9) == Sim.ERR_INVALID, "postura inválida")
	var vil: Ent = mk.call("aldeano", 0, Vector2i(6, 6))
	ok(sim.cmd_stance(0, [vil.id], Sim.ST_DEF) == Sim.ERR_NOUNITS, "los aldeanos no tienen postura")

## Una casilla libre a `dist` casillas de `from` a la que se puede llegar andando.
func reachable_goal(sim: Sim, from: Vector2i, dist: int) -> Vector2i:
	for k in 16:
		var a := TAU * float(k) / 16.0
		var q := sim.nearest_free_tile(from + Vector2i(roundi(cos(a) * dist), roundi(sin(a) * dist)), 3)
		if q.x >= 0 and Vector2(q - from).length() > dist * 0.6 and sim.astar.get_id_path(from, q, false).size() > 0:
			return q
	return Vector2i(-1, -1)

func test_formation() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 2)
	var base := sim.nearest_free_tile(p.start_tile + Vector2i(0, 6), 6)
	var us: Array = []
	var types := ["piquero", "piquero", "espadachin", "espadachin", "arquero", "arquero", "arquero", "jinete"]
	for i in types.size():
		us.append(sim._spawn_unit(types[i], 0, sim.nearest_free_tile(base + Vector2i(i % 4, i / 4), 6)))
	var goal := reachable_goal(sim, base, 18)
	ok(goal.x >= 0, "hay un destino alcanzable a 18 casillas")
	ok(sim.comp[goal.y * sim.W + goal.x] >= 0, "destino de la formación en tierra firme")
	ok(sim.cmd_formation(0, 1) == Sim.OK, "formación en línea")
	var ids: Array = []
	for u in us:
		ids.append(u.id)
	sim.cmd_move(0, ids, goal)
	var slow := 99.0
	for u in us:
		slow = minf(slow, float(u.def["speed"]) * u.sm)
		ok(u.fspd > 0.0, "cada uno lleva tope de velocidad")
		break
	run(sim, 1.0)
	var jinete: Ent = us[7]
	ok(jinete.fspd <= float(jinete.def["speed"]) + 0.001 and jinete.fspd >= slow - 0.001, "el jinete marcha al paso del más lento")
	run(sim, 40.0)
	var front_d := 0.0
	var back_d := 0.0
	var nf := 0
	var nb := 0
	var gp := sim.tile_center(goal)
	for u: Ent in us:
		if float(u.def["range"]) <= 1.5:
			front_d += u.pos.distance_to(gp)
			nf += 1
		else:
			back_d += u.pos.distance_to(gp)
			nb += 1
	ok(nf > 0 and nb > 0 and back_d / nb >= front_d / nf - 4.0, "los arqueros quedan detrás de la infantería (%.0f vs %.0f)" % [back_d / nb, front_d / nf])
	var all_near := true
	for u: Ent in us:
		if u.pos.distance_to(gp) > 6.0 * Defs.TILE:
			all_near = false
	ok(all_near, "todos llegan al destino")
	# libre: sin tope
	sim.cmd_formation(0, 0)
	sim.cmd_move(0, ids, base)
	ok((us[0] as Ent).fspd == 0.0, "formación libre: sin tope")
	ok(sim.cmd_formation(0, 7) == Sim.ERR_INVALID, "formación inválida")

func test_save() -> void:
	var sim := make_sim()
	var p := rich(sim, 0, 2)
	var tw := place(sim, "torre", 0, p.start_tile + Vector2i(12, 0))
	tw.progress = 1.0
	var a := sim._spawn_unit("arquero", 0, sim.nearest_free_tile(tw.tile + Vector2i(-2, 0), 5))
	sim.cmd_garrison(0, [a.id], tw.id)
	var c := place(sim, "centro", 0, p.start_tile + Vector2i(-14, 0))
	sim.cmd_research(0, c.id, "telar")
	run(sim, 45.0)
	var m := place(sim, "mercado", 0, p.start_tile + Vector2i(0, 12))
	m.progress = 1.0
	sim.cmd_trade(0, "wood", true)
	sim.cmd_formation(0, 2)
	var data := SaveGame.snapshot_sim(sim)
	var back := SaveGame.restore({"sim": data})
	ok(back != null, "la partida se restaura")
	if back == null:
		return
	ok(back.fauna.size() == sim.fauna.size(), "fauna restaurada (%d)" % back.fauna.size())
	ok((back.players[0] as Player).techs.has("telar"), "mejoras restauradas")
	ok(int(back.up_mods[0]["hp"].get("aldeano", 1.0) * 100) == 140, "efecto de las mejoras restaurado")
	ok(int(back.players[0].mkt["wood"]) == int(sim.players[0].mkt["wood"]), "precios del mercado restaurados")
	ok(back.players[0].formation == 2, "formación restaurada")
	var tw2: Ent = back.ents[tw.id]
	ok(tw2.cargo.size() == 1 and tw2.cargo[0].stowed, "guarnición restaurada")
	run(back, 20.0)
	run(sim, 20.0)
	ok(back.step_count == sim.step_count, "ambas siguen")
	var same := true
	for i in sim.fauna.size():
		if int(sim.fauna[i]["i"]) != int(back.fauna[i]["i"]):
			same = false
	ok(same, "la fauna evoluciona igual tras cargar")
