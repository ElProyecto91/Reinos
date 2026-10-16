extends SceneTree
## Reglas de la Edad de los Castillos en la simulación pura (sin dibujo).
## godot --headless --path . --script res://tools/age2_test.gd                       (reglas)
## godot --headless --path . --script res://tools/age2_test.gd -- ai=1 min=30 seed=5 diff=1,1   (además, partida IA contra IA)
var fails := 0
var checks := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FALLO: ", msg)

func make_sim(seed_v: int = 7, size: int = 128) -> Sim:
	var sim := Sim.new()
	sim.setup({"size": size, "seed": seed_v, "events": false, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "A"},
		{"human": false, "team": 1, "diff": 1, "name": "B"}]})
	sim.ais.clear()
	return sim

func free_near(sim: Sim, t: Vector2i, type: String, owner: int) -> Vector2i:
	for r in range(0, 20):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := t + Vector2i(dx, dy)
				if sim.can_place(type, q, owner):
					return q
	return Vector2i(-1, -1)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	test_defs()
	test_training_and_age_gate()
	test_age_up_requirements()
	test_splash()
	test_healing()
	test_new_units_stats()
	test_save_age2()
	for a in args:
		if a == "ai=1":
			test_ai_match(args)
	print("age2_test: %d comprobaciones, %d fallos" % [checks, fails])
	quit(1 if fails > 0 else 0)

# --- coherencia de las definiciones: cada unidad se entrena donde dice y viceversa
func test_defs() -> void:
	for ut in Defs.UNITS:
		var ud: Dictionary = Defs.UNITS[ut]
		var bt: String = ud.get("building", "")
		ok(bt != "" and Defs.BUILDINGS.has(bt), "%s: edificio de entrenamiento inexistente (%s)" % [ut, bt])
		if Defs.BUILDINGS.has(bt):
			# las unidades únicas no están en la lista base: las añade Civs.train_list según la civilización
			var is_unique := false
			for cid in Civs.IDS:
				if Civs.unique_of(cid) == ut:
					is_unique = true
					ok(Civs.train_list(bt, cid).has(ut), "%s no está en la lista de entrenamiento de %s (civ %s)" % [ut, bt, cid])
			ok(is_unique or (Defs.BUILDINGS[bt].get("train", []) as Array).has(ut) or ut == "aldeano", "%s no está en la lista de entrenamiento de %s" % [ut, bt])
		ok(int(ud["age"]) <= Defs.AGES.size() - 1, "%s: edad inexistente" % ut)
	for bt in Defs.BUILDINGS:
		for ut in (Defs.BUILDINGS[bt].get("train", []) as Array):
			ok(Defs.UNITS.has(ut), "%s entrena una unidad que no existe: %s" % [bt, ut])
			if Defs.UNITS.has(ut):
				ok(Defs.UNITS[ut].get("building", "") == bt, "%s se entrena en %s pero su ficha dice %s" % [ut, bt, Defs.UNITS[ut].get("building", "")])
	for a in Defs.BONUS:
		ok(Defs.UNITS.has(a), "BONUS: atacante desconocido %s" % a)
		for d in Defs.BONUS[a]:
			ok(Defs.UNITS.has(d), "BONUS: %s → defensor desconocido %s" % [a, d])
	# cada tipo militar terrestre debe poder entrenarse en algún sitio y todos los edificios de Defs deben tener arte
	var art := Art.new()
	art.build()
	for bt in Defs.BUILDINGS:
		if bt != "granja":
			ok(art.building_tex.has(bt), "sin arte de edificio: " + bt)
	for ut in Defs.UNITS:
		ok(ArtUnits.CELLS.has(ut), "sin hoja de unidad: " + ut)

# --- entrenamiento por edades
func test_training_and_age_gate() -> void:
	var sim := make_sim()
	var p: Player = sim.players[0]
	var base: Vector2i = p.start_tile
	var made := {}
	for bt in ["cuartel", "arqueria", "establo", "taller", "monasterio", "castillo"]:
		var t := free_near(sim, base + Vector2i(-6, 6), bt, 0)
		ok(t.x >= 0, "sitio para " + bt)
		if t.x >= 0:
			made[bt] = sim._spawn_building(bt, 0, t, true)
	var expect := {
		"cuartel": ["piquero", "espadachin", "alabardero"],
		"arqueria": ["arquero", "ballestero", "hostigador", "arquero_caballo"],
		"establo": ["explorador", "jinete", "caballero"],
		"taller": ["ariete", "catapulta"],
		"monasterio": ["monje"],
		"castillo": ["trabuquete"],
	}
	for bt in expect:
		var b: Ent = made.get(bt)
		if b == null:
			continue
		ok((Defs.BUILDINGS[bt]["train"] as Array) == expect[bt], "lista de %s: %s" % [bt, str(Defs.BUILDINGS[bt]["train"])])
		for ut in expect[bt]:
			var need: int = Defs.UNITS[ut]["age"]
			p.res = {"food": 9999, "wood": 9999, "gold": 9999, "stone": 9999}
			if need > 0:
				p.age = need - 1
				ok(sim.cmd_train(0, b.id, ut) == Sim.ERR_AGE, "%s debería exigir edad %d" % [ut, need])
			p.age = need
			ok(sim.cmd_train(0, b.id, ut) == Sim.OK, "%s debería poder entrenarse en edad %d" % [ut, need])
			sim.cmd_cancel_train(0, b.id, b.queue.size() - 1)
	# entrenar de verdad y comprobar que sale con la vida de su edad
	p.age = 2
	p.res = {"food": 9999, "wood": 9999, "gold": 9999, "stone": 9999}
	p.pop_cap = 100
	var b: Ent = made.get("cuartel")
	if b != null:
		ok(sim.cmd_train(0, b.id, "alabardero") == Sim.OK, "encolar alabardero")
		for s in int(40.0 / Sim.DT):
			sim.step()
		var found: Ent = null
		for u in sim.units:
			if u.alive and u.owner == 0 and u.type == "alabardero":
				found = u
		ok(found != null, "el alabardero sale del cuartel")
		if found != null:
			ok(is_equal_approx(found.max_hp, 72.0 * 1.30), "vida del alabardero en edad 2: %.1f" % found.max_hp)

# --- requisitos para subir de edad
func test_age_up_requirements() -> void:
	var sim := make_sim()
	var p: Player = sim.players[0]
	p.res = {"food": 9999, "wood": 9999, "gold": 9999, "stone": 9999}
	ok(sim.cmd_age_up(0) == Sim.OK, "edad 0→1 sin edificios militares")
	for s in int(Defs.AGES[1]["time"] / Sim.DT) + 5:
		sim.step()
	ok(p.age == 1, "edad 1 alcanzada")
	p.res = {"food": 9999, "wood": 9999, "gold": 9999, "stone": 9999}
	ok(sim.cmd_age_up(0) == Sim.ERR_REQ, "edad 1→2 sin edificios militares debe dar ERR_REQ")
	var base: Vector2i = p.start_tile
	var t1 := free_near(sim, base + Vector2i(-6, 6), "cuartel", 0)
	sim._spawn_building("cuartel", 0, t1, true)
	ok(sim.military_kinds_done(0) == 1, "un tipo militar")
	ok(sim.cmd_age_up(0) == Sim.ERR_REQ, "con 1 tipo militar sigue faltando")
	var t1b := free_near(sim, base + Vector2i(-2, 8), "cuartel", 0)
	sim._spawn_building("cuartel", 0, t1b, true)
	ok(sim.military_kinds_done(0) == 1, "dos cuarteles siguen contando como un solo tipo")
	ok(sim.cmd_age_up(0) == Sim.ERR_REQ, "dos cuarteles no bastan")
	var t2 := free_near(sim, base + Vector2i(6, 8), "arqueria", 0)
	var inc: Ent = sim._spawn_building("arqueria", 0, t2, false)
	ok(sim.military_kinds_done(0) == 1, "un edificio sin terminar no cuenta")
	ok(sim.cmd_age_up(0) == Sim.ERR_REQ, "arquería a medias no basta")
	inc.progress = 1.0
	ok(sim.military_kinds_done(0) == 2, "dos tipos militares")
	p.res = {"food": 100, "wood": 9999, "gold": 9999, "stone": 9999}
	ok(sim.cmd_age_up(0) == Sim.ERR_COST, "sin comida: ERR_COST")
	p.res = {"food": 9999, "wood": 9999, "gold": 9999, "stone": 9999}
	ok(sim.cmd_age_up(0) == Sim.OK, "edad 1→2 con 2 tipos militares")
	ok(sim.cmd_age_up(0) == Sim.ERR_INVALID, "ya está subiendo de edad")
	for s in int(Defs.AGES[2]["time"] / Sim.DT) + 5:
		sim.step()
	ok(p.age == 2, "edad 2 alcanzada")
	ok(sim.cmd_age_up(0) == Sim.ERR_INVALID, "no hay edad 4")
	var u := sim._spawn_unit("piquero", 0, base + Vector2i(0, 5))
	ok(is_equal_approx(u.max_hp, float(Defs.UNITS["piquero"]["hp"]) * 1.30), "bonificación de edad 2 en unidades nuevas")

# --- la catapulta daña a los que están junto al objetivo
func test_splash() -> void:
	var sim := make_sim()
	sim.players[0].age = 2
	var base: Vector2i = sim.players[0].start_tile
	var c := sim.nearest_free_tile(base + Vector2i(0, 14), 6)
	var cat := sim._spawn_unit("catapulta", 0, c - Vector2i(6, 0))
	var vs: Array[Ent] = []
	for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(6, 6)]:
		vs.append(sim._spawn_unit("aldeano", 1, c + off))
	ok(sim.cmd_attack(0, [cat.id], vs[0].id) >= 0, "orden de ataque de la catapulta")
	for s in int(25.0 / Sim.DT):
		sim.step()
		if not vs[0].alive:
			break
	var hurt := 0
	for i in 4:
		if (not vs[i].alive) or vs[i].hp < vs[i].max_hp - 0.1:
			hurt += 1
	ok(hurt >= 3, "el impacto de la catapulta alcanza a varios (heridos: %d de 4)" % hurt)
	ok(vs[4].hp >= vs[4].max_hp - 0.1, "el aldeano lejano no recibe daño de salpicadura")

# --- el monje cura a aliados y no a enemigos
func test_healing() -> void:
	var sim := make_sim()
	sim.players[0].age = 2
	var base: Vector2i = sim.players[0].start_tile
	var c := sim.nearest_free_tile(base + Vector2i(0, 16), 6)
	var monk := sim._spawn_unit("monje", 0, c)
	var ally := sim._spawn_unit("piquero", 0, c + Vector2i(1, 1))
	ally.hp = ally.max_hp * 0.3
	var hp0 := ally.hp
	var c2 := sim.nearest_free_tile(base + Vector2i(18, 0), 6)
	var monk2 := sim._spawn_unit("monje", 0, c2)
	var foe := sim._spawn_unit("aldeano", 1, c2 + Vector2i(1, 1))
	foe.hp = foe.max_hp * 0.3
	var foe_hp0 := foe.hp
	for s in int(10.0 / Sim.DT):
		sim.step()
	ok(ally.hp > hp0 + 10.0, "el monje cura al aliado (%.1f → %.1f)" % [hp0, ally.hp])
	ok(ally.hp <= ally.max_hp + 0.01, "la curación no pasa de la vida máxima")
	ok(is_equal_approx(foe.hp, foe_hp0), "el monje no cura a enemigos (%.1f → %.1f)" % [foe_hp0, foe.hp])
	ok(monk.alive and monk2.alive, "los monjes siguen vivos")
	# un monje no es unidad militar: no cuenta para el ejército ni ataca
	ok(not monk.is_military(), "el monje no es militar")

# --- sanidad de las fichas: alcance, coste y desventajas
func test_new_units_stats() -> void:
	var u: Dictionary = Defs.UNITS
	ok(float(u["trabuquete"]["range"]) > float(u["catapulta"]["range"]), "el trabuquete alcanza más que la catapulta")
	ok(bool(u["trabuquete"].get("siege", false)), "el trabuquete es de asedio (sólo edificios)")
	ok(float(u["alabardero"]["vs_building"]) >= 0.5, "el alabardero hace algo de daño a edificios")
	ok(float(Defs.BONUS["alabardero"]["caballero"]) > float(Defs.BONUS["piquero"]["caballero"]), "el alabardero es mejor contra caballería que el piquero")
	ok(float(Defs.BONUS["hostigador"]["arquero"]) >= 2.0, "el hostigador gana a los arqueros")
	ok(float(Defs.BONUS["espadachin"]["ariete"]) >= 2.0, "el espadachín ataca a los arietes")
	ok(float(Defs.BONUS["caballero"]["arquero"]) >= 2.0, "el caballero gana a los arqueros")

# --- partida IA contra IA: llegan a la edad 3 y usan las unidades nuevas
func test_ai_match(args: PackedStringArray) -> void:
	var seed_v := 5
	var minutes := 30.0
	var diffs := [1, 1]
	var size := 192
	for a in args:
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("min="): minutes = float(a.substr(4))
		elif a.begins_with("size="): size = int(a.substr(5))
		elif a.begins_with("diff="):
			var parts := a.substr(5).split(",")
			diffs = [int(parts[0]), int(parts[1])]
	var sim := Sim.new()
	sim.setup({"size": size, "seed": seed_v, "events": false, "players": [
		{"human": false, "team": 0, "diff": diffs[0]}, {"human": false, "team": 1, "diff": diffs[1]}]})
	var age2_at := [-1.0, -1.0]
	var seen := [{}, {}]
	var built := [{}, {}]
	var built_at := [{}, {}]
	var steps := int(minutes * 60.0 / Sim.DT)
	var new_types := ["alabardero", "hostigador", "arquero_caballo", "catapulta", "trabuquete", "monje"]
	for s in steps:
		sim.step()
		if s % 50 == 0:
			for i in 2:
				if sim.players[i].age >= 2 and age2_at[i] < 0.0:
					age2_at[i] = sim.time
			for u in sim.units:
				if u.alive and new_types.has(u.type):
					seen[u.owner][u.type] = int(seen[u.owner].get(u.type, 0)) + 1
			for b in sim.buildings:
				if b.alive and (b.type == "monasterio" or b.type == "castillo") and b.progress >= 1.0:
					built[b.owner][b.type] = true
					if not built_at[b.owner].has(b.type):
						built_at[b.owner][b.type] = int(sim.time)
		if sim.game_over:
			break
	print("IA vs IA seed %d diffs %s, %.0f min simulados:" % [seed_v, str(diffs), sim.time / 60.0])
	for i in 2:
		print("  P%d edad 2 a los %s s; edificios 3ª edad (s en que se terminan) %s; unidades nuevas vistas (muestras) %s" % [i, str(snappedf(age2_at[i], 1.0)), str(built_at[i]), str(seen[i])])
	var sm := sim.summary()
	for pl in sm["players"]:
		print("  P%d final: edad %d pop %d (aldeanos %d, militares %d) recursos %s edificios %s" % [pl.i, pl.age, pl.pop, pl.vill, pl.mil, str(pl.res), str(pl.b)])
	var any_age: bool = age2_at[0] >= 0.0 or age2_at[1] >= 0.0
	ok(any_age or sim.game_over, "alguna IA llega a la Edad de los Castillos")
	var kinds := {}
	for i in 2:
		for k in seen[i]:
			kinds[k] = true
	ok(kinds.size() >= 2 or sim.game_over or not any_age, "la IA usa al menos 2 unidades nuevas (%s)" % str(kinds.keys()))

# --- guardar y cargar con contenido de la 3ª edad (monasterio, castillo, unidades nuevas, reserva de la IA)
func test_save_age2() -> void:
	var cfg := {"size": 128, "seed": 4, "events": false, "players": [
		{"human": true, "team": 0, "diff": 2, "name": "A"}, {"human": false, "team": 1, "diff": 2, "name": "B"}]}
	var sim := Sim.new()
	sim.setup(cfg)
	sim.ais.append(AiPlayer.new(sim, 0, 2))       # una IA juega el puesto del humano, como en save_test
	for p in sim.players:
		p.age = 2
		p.res = {"food": 3000, "wood": 3000, "gold": 3000, "stone": 3000}
	for a in sim.ais:
		a.attack_at = 1e12
		a.raid_at = 1e12
		a.navy_at = 1e12
	for i in int(600.0 / Sim.DT):
		sim.step()
	var has_mon := false
	var has_cas := false
	var kinds := {}
	for b in sim.buildings:
		if b.alive and b.progress >= 1.0:
			has_mon = has_mon or b.type == "monasterio"
			has_cas = has_cas or b.type == "castillo"
	for u in sim.units:
		if u.alive:
			kinds[u.type] = true
	ok(has_mon and has_cas, "el escenario guardado contiene monasterio y castillo terminados")
	var new_kinds := 0
	for k in ["alabardero", "hostigador", "arquero_caballo", "catapulta", "trabuquete", "monje"]:
		if kinds.has(k):
			new_kinds += 1
	ok(new_kinds >= 2, "el escenario guardado tiene unidades nuevas (%s)" % str(kinds.keys()))
	var data := {"magic": SaveGame.MAGIC, "format": SaveGame.FORMAT, "saved_at": Time.get_unix_time_from_system(), "cfg": cfg,
		"sim": SaveGame.snapshot_sim(sim), "game": {}, "meta": {"time": sim.time, "size": sim.W, "rivals": 1, "age": 2, "pop": 0}}
	var rs := SaveGame.restore(data)
	ok(rs != null, "restaurar partida con 3ª edad: " + SaveGame.last_error)
	if rs == null:
		return
	ok(var_to_bytes(SaveGame.snapshot_sim(sim)) == var_to_bytes(SaveGame.snapshot_sim(rs)), "estado idéntico tras guardar y cargar (3ª edad)")
	ok(rs.players[0].age == 2, "la edad se conserva")
	var same := true
	for i in int(120.0 / Sim.DT):
		sim.step()
		rs.step()
		if i % 10 == 0 and var_to_bytes(SaveGame.snapshot_sim(sim)) != var_to_bytes(SaveGame.snapshot_sim(rs)):
			same = false
			break
	ok(same, "la partida cargada con 3ª edad sigue idéntica 120 s más")
