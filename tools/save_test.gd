extends SceneTree
## Guardar y cargar: ida y vuelta idéntica, la partida cargada sigue igual que la original,
## carga a bordo de barcos, archivos dañados y tiempos.
## Uso: godot --headless --path . --script res://tools/save_test.gd -- seed=3 size=192 min=10
var fails := 0
func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS  " if ok else "FAIL  "), name, ("  " + extra) if extra != "" else "")
	if not ok:
		fails += 1

func run(sim: Sim, seconds: float) -> void:
	for i in int(seconds / Sim.DT):
		sim.step()

func fake_game_data(sim: Sim, cfg: Dictionary) -> Dictionary:
	return {"magic": SaveGame.MAGIC, "format": SaveGame.FORMAT, "saved_at": Time.get_unix_time_from_system(), "cfg": cfg,
		"sim": SaveGame.snapshot_sim(sim), "game": {},
		"meta": {"time": sim.time, "size": sim.W, "rivals": sim.players.size() - 1, "age": 0, "pop": 0}}

func state_bytes(sim: Sim) -> PackedByteArray:
	return var_to_bytes(SaveGame.snapshot_sim(sim))

## Compara con detalle qué parte difiere (la primera diferencia).
func diff_report(a: Sim, b: Sim) -> String:
	var sa := SaveGame.snapshot_sim(a)
	var sb := SaveGame.snapshot_sim(b)
	var out: Array = []
	for k in sa:
		if k == "ents":
			var ea: Array = sa[k]
			var eb: Array = sb[k]
			if ea.size() != eb.size():
				out.append("ents: %d vs %d" % [ea.size(), eb.size()])
				continue
			var n_diff := 0
			for i in ea.size():
				if var_to_bytes(ea[i]) != var_to_bytes(eb[i]):
					n_diff += 1
					if n_diff > 3:
						continue
					var da: Dictionary = ea[i]
					var db: Dictionary = eb[i]
					var keys := {}
					for q in da: keys[q] = true
					for q in db: keys[q] = true
					for q in keys:
						if str(da.get(q)) != str(db.get(q)):
							out.append("ent %s #%d campo %s: %s vs %s" % [str(da.get("type")), int(da.get("id")), q, str(da.get(q)).left(60), str(db.get(q)).left(60)])
			if n_diff > 0:
				out.append("(%d entidades difieren)" % n_diff)
			continue
		if var_to_bytes(sa[k]) != var_to_bytes(sb[k]):
			out.append("campo %s: %s vs %s" % [k, str(sa[k]).left(100), str(sb[k]).left(100)])
	return " | ".join(out)

func derived_equal(a: Sim, b: Sim) -> String:
	if a.wsol != b.wsol: return "wsol"
	if a.wcomp != b.wcomp: return "wcomp"
	if a.wcomp_size != b.wcomp_size: return "wcomp_size"
	for k in a.chunk_cnt.size():
		if a.chunk_cnt[k] != b.chunk_cnt[k]: return "chunk_cnt %d" % k
	var total := a.W * a.H
	for i in total:
		var t := Vector2i(i % a.W, i / a.W)
		if a.astar.is_point_solid(t) != b.astar.is_point_solid(t): return "astar solid %s" % str(t)
		if a.astar2.is_point_solid(t) != b.astar2.is_point_solid(t): return "astar2 solid %s" % str(t)
		if a.astar_w.is_point_solid(t) != b.astar_w.is_point_solid(t): return "astar_w solid %s" % str(t)
		if a.astar2.get_point_weight_scale(t) != b.astar2.get_point_weight_scale(t): return "astar2 peso %s" % str(t)
	for i in a.buckets.size():
		var ia: Array = []
		for e: Ent in a.buckets[i]:
			if e.alive: ia.append(e.id)
		var ib: Array = []
		for e: Ent in b.buckets[i]:
			if e.alive: ib.append(e.id)
		ia.sort()
		ib.sort()
		if ia != ib:
			var only_a: Array = ia.filter(func(x: int) -> bool: return not ib.has(x))
			var only_b: Array = ib.filter(func(x: int) -> bool: return not ia.has(x))
			var desc := ""
			for x in only_a:
				var en: Ent = a.ents.get(x)
				desc += " A#%d(%s pos=%s alive=%s stowed=%s)" % [x, en.type if en else "?", str(en.pos) if en else "", str(en.alive) if en else "", str(en.stowed) if en else ""]
			for x in only_b:
				var en: Ent = b.ents.get(x)
				desc += " B#%d(%s pos=%s)" % [x, en.type if en else "?", str(en.pos) if en else ""]
			return "cubo %d:%s" % [i, desc]
	return ""

func _init() -> void:
	var seed_v := 3
	var size := 192
	var minutes := 10.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		if a.begins_with("size="): size = int(a.substr(5))
		if a.begins_with("min="): minutes = float(a.substr(4))
	var cfg := {"size": size, "seed": seed_v, "events": false, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 2, "name": "Rojo"},
		{"human": false, "team": 2, "diff": 2, "name": "Verde"},
		{"human": false, "team": 3, "diff": 2, "name": "Amarillo"}]}
	var sim := Sim.new()
	check("setup", sim.setup(cfg))
	# el humano lo juega una IA de pruebas para que haya actividad en su estado también
	var human_ai := AiPlayer.new(sim, 0, 2)
	sim.ais.append(human_ai)
	var t0 := Time.get_ticks_msec()
	run(sim, minutes * 60.0)
	print("INFO simulados %.0f s en %d ms; ents %d (unidades %d, edificios %d); pop %s" % [sim.time, Time.get_ticks_msec() - t0, sim.ents.size(), sim.units.size(), sim.buildings.size(), str(sim.players.map(func(p: Player) -> int: return p.pop))])
	check("la partida sigue en juego", not sim.game_over)
	# --- instantánea en memoria
	var ts := Time.get_ticks_usec()
	var data := fake_game_data(sim, cfg)
	var snap_us := Time.get_ticks_usec() - ts
	print("INFO instantánea: %.1f ms" % (snap_us / 1000.0))
	# --- escribir y leer de verdad
	SaveGame.delete()
	check("sin partida guardada al principio", not SaveGame.has_save())
	ts = Time.get_ticks_usec()
	check("write_data", SaveGame.write_data(data), SaveGame.last_error)
	var w_ms := (Time.get_ticks_usec() - ts) / 1000.0
	var fsize := FileAccess.open(SaveGame.PATH, FileAccess.READ).get_length()
	print("INFO escritura %.1f ms, archivo %d KB" % [w_ms, fsize / 1024])
	check("has_save tras guardar", SaveGame.has_save())
	var meta := SaveGame.meta()
	check("ficha con tiempo y tamaño", absf(float(meta.get("time", -1.0)) - sim.time) < 0.01 and int(meta.get("size", 0)) == size, str(meta))
	ts = Time.get_ticks_usec()
	var loaded := SaveGame.read_data()
	var r_ms := (Time.get_ticks_usec() - ts) / 1000.0
	check("read_data", not loaded.is_empty(), SaveGame.last_error)
	ts = Time.get_ticks_usec()
	var rs := SaveGame.restore(loaded)
	print("INFO lectura %.1f ms, reconstrucción %.1f ms" % [r_ms, (Time.get_ticks_usec() - ts) / 1000.0])
	check("restore", rs != null, SaveGame.last_error)
	if rs == null:
		print("DONE fails=", fails)
		quit(1)
		return
	check("estado idéntico tras guardar y cargar", state_bytes(sim) == state_bytes(rs), diff_report(sim, rs))
	var dd := derived_equal(sim, rs)
	check("rejillas y rutas derivadas idénticas", dd == "", dd)
	check("misma población y reloj", rs.time == sim.time and rs.players[0].pop == sim.players[0].pop)
	# --- la partida cargada evoluciona igual que la original
	rs.ais.clear()
	for a in sim.ais:
		pass
	# las IAs de rs son las restauradas (4 incluida la del humano de pruebas)
	check("IAs restauradas", SaveGame.restore(loaded).ais.size() == sim.ais.size(), "%d" % sim.ais.size())
	rs = SaveGame.restore(loaded)
	var first_div := -1.0
	for chunk in int(300.0 / 10.0):
		run(sim, 10.0)
		run(rs, 10.0)
		if state_bytes(sim) != state_bytes(rs):
			first_div = sim.time
			break
	check("la partida cargada sigue idéntica 300 s más", first_div < 0.0, "primera diferencia hacia t=%.1f: %s" % [first_div, diff_report(sim, rs)] if first_div >= 0.0 else "")
	# --- lo mismo guardando en un paso impar (los cubos de búsqueda están a medio refrescar)
	if sim.game_over:
		print("INFO la partida de esta semilla terminó antes; se rehace sin ella para el paso impar")
		var again := SaveGame.restore(data)
		if again != null:
			sim = again
			sim.game_over = false
	var guard := 0
	while sim.step_count % 2 == 0 and guard < 4:
		sim.step()
		guard += 1
	check("paso impar", sim.step_count % 2 == 1)
	var odd := SaveGame.restore(fake_game_data(sim, cfg))
	check("estado idéntico en paso impar", odd != null and state_bytes(sim) == state_bytes(odd))
	var dd2 := derived_equal(sim, odd)
	check("cubos y rejillas idénticos en paso impar", dd2 == "", dd2)
	var div2 := -1.0
	for st in 300:
		sim.step()
		odd.step()
		if state_bytes(sim) != state_bytes(odd):
			div2 = sim.time
			break
	check("sigue idéntica 30 s más desde un paso impar", div2 < 0.0, "diferencia hacia t=%.1f: %s" % [div2, diff_report(sim, odd)] if div2 >= 0.0 else "")
	# --- archivos dañados
	var good_bytes := FileAccess.get_file_as_bytes(SaveGame.PATH)
	var f := FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	f.store_buffer(good_bytes.slice(0, good_bytes.size() / 2))
	f = null
	check("archivo truncado se rechaza", SaveGame.read_data().is_empty() or SaveGame.restore(SaveGame.read_data()) == null)
	f = FileAccess.open(SaveGame.PATH, FileAccess.WRITE)
	f.store_string("esto no es una partida")
	f = null
	check("basura se rechaza", SaveGame.read_data().is_empty())
	var bad := data.duplicate(true)
	(bad["sim"] as Dictionary).erase("terrain")
	check("datos incompletos se rechazan", SaveGame.restore(bad) == null)
	bad = data.duplicate(true)
	(bad["sim"] as Dictionary)["terrain"] = PackedByteArray([1, 2, 3])
	check("mapa de tamaño erróneo se rechaza", SaveGame.restore(bad) == null)
	bad = data.duplicate(true)
	((bad["sim"] as Dictionary)["ents"] as Array)[0]["type"] = "dragon"
	check("tipo desconocido se rechaza", SaveGame.restore(bad) == null)
	bad = data.duplicate(true)
	bad["format"] = 999
	SaveGame.write_data(bad)
	check("formato distinto se rechaza", SaveGame.read_data().is_empty())
	var mf := FileAccess.open(SaveGame.META, FileAccess.WRITE)
	mf.store_string(JSON.stringify({"format": 999, "time": 1.0}))
	mf = null
	check("ficha de otro formato no cuenta como partida", not SaveGame.has_save())
	# el guardado bueno sustituye al roto
	check("se puede volver a guardar tras un archivo roto", SaveGame.write_data(data) and SaveGame.has_save())
	SaveGame.delete()
	check("delete borra todo", not SaveGame.has_save() and not FileAccess.file_exists(SaveGame.PATH) and not FileAccess.file_exists(SaveGame.TMP))
	# --- carga a bordo de un barco: se conserva y se puede desembarcar tras cargar
	_boats_scenario()
	print("DONE fails=", fails)
	quit(0 if fails == 0 else 1)

func _boats_scenario() -> void:
	var cfg := {"size": 128, "seed": 1, "events": true, "players": [{"human": true, "team": 0}, {"human": false, "team": 1}]}
	var sim := Sim.new()
	sim.setup(cfg)
	sim.ais.clear()
	var p: Player = sim.players[0]
	p.res = {"food": 3000, "wood": 3000, "gold": 3000}
	p.pop_cap = 100
	p.age = 1
	var base: Vector2i = p.start_tile
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
	var vills: Array = []
	for u in sim.units:
		if u.owner == 0 and u.type == "aldeano":
			vills.append(u.id)
	var r := sim.cmd_build(0, vills, "puerto", spot)
	var port: Ent = sim.get_ent(r)
	run(sim, 90.0)
	sim.cmd_train(0, port.id, "barco_transporte")
	run(sim, 40.0)
	var transport: Ent = null
	for u in sim.units:
		if u.owner == 0 and u.type == "barco_transporte":
			transport = u
	check("[barcos] hay transporte", transport != null)
	if transport == null:
		return
	var warriors: Array = []
	for k in 3:
		warriors.append(sim._spawn_unit("piquero", 0, sim.nearest_free_tile(base + Vector2i(k, 4), 6)).id)
	check("[barcos] embarcar", sim.cmd_board(0, warriors, transport.id) == Sim.OK)
	run(sim, 60.0)
	check("[barcos] 3 a bordo antes de guardar", transport.cargo.size() == 3, str(transport.cargo.size()))
	var data := fake_game_data(sim, cfg)
	check("[barcos] guardar", SaveGame.write_data(data))
	var rs := SaveGame.restore(SaveGame.read_data())
	check("[barcos] cargar", rs != null)
	if rs == null:
		return
	var tr2: Ent = rs.ents[transport.id]
	check("[barcos] pasajeros conservados", tr2.cargo.size() == 3, str(tr2.cargo.size()))
	var all_stowed := true
	for c: Ent in tr2.cargo:
		if not c.stowed or rs.units.has(c):
			all_stowed = false
	check("[barcos] los pasajeros siguen fuera de la partida", all_stowed)
	check("[barcos] población igual", rs.players[0].pop == sim.players[0].pop, "%d vs %d" % [rs.players[0].pop, sim.players[0].pop])
	# isla alcanzable (como en naval_test)
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
	check("[barcos] hay isla", best.x >= 0)
	if best.x < 0:
		return
	# se desembarca en la partida cargada y en la original; el resultado debe ser el mismo
	check("[barcos] desembarcar (original)", sim.cmd_unload(0, [transport.id], best) == Sim.OK)
	check("[barcos] desembarcar (cargada)", rs.cmd_unload(0, [tr2.id], best) == Sim.OK)
	run(sim, 120.0)
	run(rs, 120.0)
	check("[barcos] la cargada desembarca a todos", tr2.cargo.is_empty())
	var on_island := 0
	for id in warriors:
		var u: Ent = rs.get_ent(id)
		if u != null and rs.comp[rs.tile_of(u.pos).y * rs.W + rs.tile_of(u.pos).x] == rs.comp[best.y * rs.W + best.x]:
			on_island += 1
	check("[barcos] los 3 llegan a la isla tras cargar", on_island == 3, "%d de 3" % on_island)
	check("[barcos] original y cargada coinciden", state_bytes(sim) == state_bytes(rs), diff_report(sim, rs))
	SaveGame.delete()
