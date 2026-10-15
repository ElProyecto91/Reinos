class_name SaveGame
extends RefCounted
## Guardado y carga de la partida (un único hueco en el almacenamiento privado de la app).
##
## - Formato: un Diccionario comprimido (zstd) con `store_var(.., false)`: los objetos NO se
##   serializan (no puede entrar código desde el archivo). Las entidades, jugadores e IAs se
##   guardan como diccionarios de campos; los campos que no están en el archivo conservan su valor
##   por defecto, y los que sobran se ignoran, así que una actualización del juego que añada
##   campos sigue leyendo partidas antiguas. Si cambia el significado de algo, subir FORMAT.
## - Escritura segura: se escribe un archivo temporal y se renombra; si algo falla, queda la
##   partida anterior intacta.
## - Se guarda una ficha pequeña (JSON) con el resumen para el menú sin tener que abrir todo.

const MAGIC := "REINOS-SAVE"
const FORMAT := 1
const PATH := "user://partida.sav"
const TMP := "user://partida.tmp"
const META := "user://partida.json"
const MAX_TILES := 512 * 512

const SIM_SCALARS := ["W", "H", "seed_used", "next_id", "time", "step_count", "wall_count", "qcount", "game_over", "winner_team", "human_index", "record_events"]
const SIM_ARRAYS := ["terrain", "rtype", "ramt", "rowner", "solid", "occ", "comp", "dl", "dw", "heat", "wall_tile", "gate_tile"]
const SIM_DICTS := ["map_info", "bad_res", "farm_slots"]
const ENT_SKIP := ["def", "ppos", "cargo"]
const ARRAY_TYPES := {"terrain": TYPE_PACKED_BYTE_ARRAY, "rtype": TYPE_PACKED_BYTE_ARRAY, "ramt": TYPE_PACKED_INT32_ARRAY, "rowner": TYPE_PACKED_BYTE_ARRAY, "solid": TYPE_PACKED_BYTE_ARRAY, "occ": TYPE_PACKED_INT32_ARRAY, "comp": TYPE_PACKED_INT32_ARRAY, "dl": TYPE_PACKED_INT32_ARRAY, "dw": TYPE_PACKED_INT32_ARRAY, "heat": TYPE_PACKED_BYTE_ARRAY, "wall_tile": TYPE_PACKED_BYTE_ARRAY, "gate_tile": TYPE_PACKED_BYTE_ARRAY}

static var _info: Dictionary = {}
static var _thread: Thread
static var last_error: String = ""

# ------------------------------------------------------------------ reflexión de campos

## Nombres de los campos de un tipo (y sus valores por defecto si `sample` es una instancia nueva).
static func _class_info(key: String, sample: Object, skip: Array) -> Dictionary:
	if _info.has(key):
		return _info[key]
	var names: Array = []
	var defaults := {}
	for p in sample.get_property_list():
		if (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var n: String = p["name"]
		if skip.has(n):
			continue
		names.append(n)
		defaults[n] = sample.get(n)
	var out := {"names": names, "defaults": defaults}
	_info[key] = out
	return out

static func _sample(key: String, o: Object) -> Object:
	match key:
		"Ent":
			return Ent.new()
		"Player":
			return Player.new()
	return o

static func _copy(v: Variant) -> Variant:
	if v is Array or v is Dictionary:
		return v.duplicate(true)
	return v

## Campos de `o` como diccionario. Con `sparse` sólo los que difieren de un objeto nuevo del mismo
## tipo (sirve cuando al cargar se parte de otro objeto nuevo idéntico: Ent, Player).
static func _enc_obj(o: Object, key: String, skip: Array, sparse: bool) -> Dictionary:
	var info: Dictionary = _class_info(key, _sample(key, o), skip)
	var defaults: Dictionary = info["defaults"]
	var d := {}
	for n: String in info["names"]:
		var v: Variant = o.get(n)
		if sparse and typeof(v) == typeof(defaults[n]) and v == defaults[n]:
			continue
		d[n] = _copy(v)
	return d

static func _dec_obj(o: Object, d: Dictionary, key: String, skip: Array) -> void:
	var info: Dictionary = _class_info(key, _sample(key, o), skip)
	var names: Array = info["names"]
	for n: String in d:
		if names.has(n):
			o.set(n, _copy(d[n]))

# ------------------------------------------------------------------ instantánea

## Estado de la simulación como datos puros (copiados: se puede escribir en otro hilo).
static func snapshot_sim(s: Sim) -> Dictionary:
	var sd := {}
	for n: String in SIM_SCALARS:
		sd[n] = s.get(n)
	for n: String in SIM_ARRAYS:
		sd[n] = (s.get(n) as Variant).duplicate()    # los Packed*Array se pasan por referencia: copiar
	for n: String in SIM_DICTS:
		sd[n] = (s.get(n) as Dictionary).duplicate(true)
	sd["hostile"] = s.hostile.duplicate(true)
	sd["path_queue"] = s.path_queue.duplicate()
	sd["zones"] = s.zones.duplicate(true)
	sd["rng"] = [s.rng.seed, s.rng.state]
	var ents: Array = []
	for e: Ent in s.ents.values():
		var ed := _enc_obj(e, "Ent", ENT_SKIP, true)
		if not e.cargo.is_empty():
			# los pasajeros ya no están en `ents` (viven sólo en la bodega del barco): se guardan enteros
			var cargo: Array = []
			for c: Ent in e.cargo:
				cargo.append(_enc_obj(c, "Ent", ENT_SKIP, true))
			ed["cargo"] = cargo
		ents.append(ed)
	sd["ents"] = ents
	# cubos de búsqueda tal cual (se rehacen cada 2 pasos: así la partida cargada continúa exactamente igual)
	var bk: Array = []
	for b: Array in s.buckets:
		var ids: Array = []
		for e: Ent in b:
			if e.alive:    # los muertos ya retirados de `ents` (restos hasta el siguiente refresco) no se guardan
				ids.append(e.id)
		bk.append(ids)
	sd["buckets"] = bk
	var uids: Array = []
	for u: Ent in s.units:
		uids.append(u.id)
	sd["units"] = uids
	var bids: Array = []
	for b: Ent in s.buildings:
		bids.append(b.id)
	sd["buildings"] = bids
	var pl: Array = []
	for p: Player in s.players:
		pl.append(_enc_obj(p, "Player", [], true))
	sd["players"] = pl
	var ais: Array = []
	for a: AiPlayer in s.ais:
		var ad := _enc_obj(a, "AiPlayer", ["sim", "rng"], false)
		ad["rng"] = [a.rng.seed, a.rng.state]
		ais.append(ad)
	sd["ais"] = ais
	return sd

static func snapshot(g: Game) -> Dictionary:
	var s := g.sim
	var human: Player = s.players[g.human]
	return {
		"magic": MAGIC,
		"format": FORMAT,
		"saved_at": Time.get_unix_time_from_system(),
		"cfg": g.cfg.duplicate(true),
		"sim": snapshot_sim(s),
		"game": {"cam": g.cam_pos, "zoom": g.zoom, "speed": g.speed, "anim_t": g.anim_t, "fog": g.fog.state.duplicate()},
		"meta": {"time": s.time, "size": s.W, "rivals": s.players.size() - 1, "age": human.age, "pop": human.pop},
	}

# ------------------------------------------------------------------ disco

static func has_save() -> bool:
	return not meta().is_empty()

## Resumen para el menú ({} si no hay partida guardada válida a simple vista).
static func meta() -> Dictionary:
	if not FileAccess.file_exists(PATH) or not FileAccess.file_exists(META):
		return {}
	var f := FileAccess.open(META, FileAccess.READ)
	if f == null:
		return {}
	var v: Variant = JSON.parse_string(f.get_as_text())
	if not (v is Dictionary):
		return {}
	var d: Dictionary = v
	if int(d.get("format", -1)) != FORMAT:
		return {}
	return d

static func delete() -> void:
	wait_idle()
	for p in [PATH, TMP, META]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)

static func wait_idle() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null

static func busy() -> bool:
	return _thread != null and _thread.is_alive()

## Guarda la partida en curso. `wait`: true = escribe ya y devuelve el resultado (pausa, salida);
## false = escribe en otro hilo (guardado periódico, sin tirones).
static func save(g: Game, wait: bool) -> bool:
	if g.load_state != 3 or g.sim.game_over:
		return false
	if _thread != null:
		if _thread.is_alive() and not wait:
			return false
		wait_idle()
	var data := snapshot(g)
	if wait:
		return write_data(data)
	_thread = Thread.new()
	_thread.start(write_data.bind(data))
	return true

static func write_data(data: Dictionary) -> bool:
	last_error = ""
	var f := FileAccess.open_compressed(TMP, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		last_error = "no se pudo crear el archivo (%d)" % FileAccess.get_open_error()
		return false
	f.store_var(data, false)
	var err := f.get_error()
	f = null    # cierra el archivo
	if err != OK:
		last_error = "error de escritura (%d)" % err
		DirAccess.remove_absolute(TMP)
		return false
	var r := DirAccess.rename_absolute(TMP, PATH)
	if r != OK:
		DirAccess.remove_absolute(PATH)
		r = DirAccess.rename_absolute(TMP, PATH)
		if r != OK:
			last_error = "no se pudo renombrar (%d)" % r
			return false
	var m: Dictionary = data["meta"].duplicate()
	m["format"] = FORMAT
	m["saved_at"] = data["saved_at"]
	var mf := FileAccess.open(META, FileAccess.WRITE)
	if mf == null:
		last_error = "no se pudo escribir la ficha"
		return false
	mf.store_string(JSON.stringify(m))
	return true

## Lee y valida el archivo; {} si no existe o está dañado.
static func read_data() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(PATH):
		last_error = "no hay partida guardada"
		return {}
	var f := FileAccess.open_compressed(PATH, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		last_error = "no se pudo abrir"
		return {}
	var v: Variant = f.get_var(false)
	f = null
	if not (v is Dictionary):
		last_error = "contenido no válido"
		return {}
	var d: Dictionary = v
	if d.get("magic", "") != MAGIC:
		last_error = "no es una partida de Reinos"
		return {}
	if int(d.get("format", -1)) != FORMAT:
		last_error = "formato %s (se esperaba %d)" % [str(d.get("format", "?")), FORMAT]
		return {}
	return d

# ------------------------------------------------------------------ restaurar

static func _fail(msg: String) -> Sim:
	last_error = msg
	push_warning("Partida guardada no válida: " + msg)
	return null

## Reconstruye la simulación; null si los datos no son coherentes. Se puede llamar desde un hilo.
static func restore(data: Dictionary) -> Sim:
	var sd: Variant = data.get("sim")
	if not (sd is Dictionary):
		return _fail("sin simulación")
	var d: Dictionary = sd
	for n: String in SIM_SCALARS + SIM_ARRAYS + SIM_DICTS + ["hostile", "path_queue", "rng", "ents", "units", "buildings", "players", "ais", "buckets"]:
		if not d.has(n):
			return _fail("falta " + n)
	var w := int(d["W"])
	var h := int(d["H"])
	if w < 32 or w != h or w * h > MAX_TILES:
		return _fail("tamaño de mapa %dx%d" % [w, h])
	var total := w * h
	for n: String in SIM_ARRAYS:
		var arr: Variant = d[n]
		if typeof(arr) != int(ARRAY_TYPES[n]) or int(arr.size()) != total:
			return _fail("tamaño o tipo de " + n)
	var plist: Array = d["players"]
	if plist.is_empty() or plist.size() > 4:
		return _fail("jugadores")
	var hi := int(d["human_index"])
	if hi < 0 or hi >= plist.size():
		return _fail("jugador humano")
	var s := Sim.new()
	s.record_events = bool(d["record_events"])
	s.W = w
	s.H = h
	s.seed_used = int(d["seed_used"])
	s.terrain = (d["terrain"] as PackedByteArray).duplicate()
	s.rtype = (d["rtype"] as PackedByteArray).duplicate()
	s.ramt = (d["ramt"] as PackedInt32Array).duplicate()
	s.comp = (d["comp"] as PackedInt32Array).duplicate()
	s.dl = (d["dl"] as PackedInt32Array).duplicate()
	s.dw = (d["dw"] as PackedInt32Array).duplicate()
	s.heat = (d["heat"] as PackedByteArray).duplicate()
	s.map_info = (d["map_info"] as Dictionary).duplicate(true)
	s._build_grids()
	# sólido, muros y propietarios de recurso tal como estaban
	s.rowner = (d["rowner"] as PackedByteArray).duplicate()
	s.occ = (d["occ"] as PackedInt32Array).duplicate()
	s.wall_tile = (d["wall_tile"] as PackedByteArray).duplicate()
	s.gate_tile = (d["gate_tile"] as PackedByteArray).duplicate()
	var saved_solid: PackedByteArray = d["solid"]
	for i in total:
		if s.solid[i] != saved_solid[i]:
			s.set_solid(Vector2i(i % w, i / w), saved_solid[i] == 1)
		if s.wall_tile[i] == 1 and s.gate_tile[i] == 0:
			s.astar2.set_point_weight_scale(Vector2i(i % w, i / w), 6.0)
	for n: String in SIM_SCALARS:
		if n != "W" and n != "H" and n != "seed_used" and n != "record_events":
			s.set(n, d[n])
	s.bad_res = (d["bad_res"] as Dictionary).duplicate(true)
	s.farm_slots = (d["farm_slots"] as Dictionary).duplicate(true)
	s.hostile = (d["hostile"] as Array).duplicate(true)
	s.path_queue = (d["path_queue"] as Array).duplicate()
	if d.has("zones"):
		s.zones = (d["zones"] as Array).duplicate(true)
	var rs: Array = d["rng"]
	s.rng.seed = int(rs[0])
	s.rng.state = int(rs[1])
	# jugadores
	for pd: Dictionary in plist:
		var p := Player.new()
		_dec_obj(p, pd, "Player", [])
		s.players.append(p)
	s._setup_civs()
	if s.hostile.size() != s.players.size():
		return _fail("alianzas")
	# entidades
	for ed: Dictionary in d["ents"]:
		var e := _make_ent(ed, s)
		if e == null:
			return null
		s.ents[e.id] = e
		if ed.has("cargo"):
			for cd: Dictionary in ed["cargo"]:
				var c := _make_ent(cd, s)
				if c == null:
					return null
				e.cargo.append(c)
	for id in d["units"]:
		var u: Ent = s.ents.get(int(id))
		if u == null or u.is_building:
			return _fail("lista de unidades")
		s.units.append(u)
	for id in d["buildings"]:
		var b: Ent = s.ents.get(int(id))
		if b == null or not b.is_building:
			return _fail("lista de edificios")
		s.buildings.append(b)
	# IAs
	for ad: Dictionary in d["ais"]:
		var a := AiPlayer.new(s, int(ad.get("pi", 0)), int(ad.get("diff", 1)))
		_dec_obj(a, ad, "AiPlayer", ["sim", "rng"])
		var ar: Array = ad.get("rng", [0, 0])
		a.rng.seed = int(ar[0])
		a.rng.state = int(ar[1])
		s.ais.append(a)
	var bk: Array = d["buckets"]
	if bk.size() != s.buckets.size():
		return _fail("cubos de búsqueda")
	var by_id := {}
	for e: Ent in s.ents.values():
		by_id[e.id] = e
		for c: Ent in e.cargo:
			by_id[c.id] = c
	for i in bk.size():
		for id in bk[i]:
			var e: Ent = by_id.get(int(id))
			if e != null:
				(s.buckets[i] as Array).append(e)
	s.rebuild_bucket_masks()
	s.events.clear()
	return s

static func _make_ent(ed: Dictionary, s: Sim) -> Ent:
	var type := str(ed.get("type", ""))
	var is_b := bool(ed.get("is_building", false))
	var defs: Dictionary = Defs.BUILDINGS if is_b else Defs.UNITS
	if not defs.has(type):
		_fail("tipo desconocido " + type)
		return null
	var id := int(ed.get("id", 0))
	if id <= 0 or s.ents.has(id):
		_fail("identificador no válido")
		return null
	var e := Ent.new()
	_dec_obj(e, ed, "Ent", ENT_SKIP)
	e.def = defs[type]
	e.ppos = e.pos
	if e.owner < 0 or e.owner >= s.players.size():
		_fail("propietario fuera de rango")
		return null
	return e

## Reconstruye también el estado de la niebla guardado (explorado = 1; lo visible lo recalcula Fog.update).
static func restore_fog(g_data: Dictionary, fog: Fog) -> void:
	var st: Variant = g_data.get("fog")
	if st is PackedByteArray and (st as PackedByteArray).size() == fog.W * fog.H:
		fog.load_explored(st)
