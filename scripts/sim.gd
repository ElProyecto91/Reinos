class_name Sim
extends RefCounted
## Motor de simulación del juego (sin dibujo ni interfaz).
## Se avanza con step() a paso fijo DT. La vista lee entidades y vacía `events`.

const DT := 0.1
const BUCKET := 8
const PATHS_PER_STEP := 14
const CARRY_CAP := 10.0

const S_IDLE := 0
const S_MOVE := 1
const S_GATHER_GO := 2
const S_GATHER := 3
const S_RETURN := 4
const S_BUILD_GO := 5
const S_BUILD := 6
const S_ATTACK_GO := 7
const S_ATTACK := 8
const S_BOARD_GO := 9       # caminando hacia un barco de transporte para subir
const S_GARRISON_GO := 10   # caminando hacia un edificio para refugiarse dentro

# Códigos de resultado de órdenes (negativos = error)
const OK := 1
const ERR_PLACE := -1
const ERR_COST := -2
const ERR_AGE := -3
const ERR_QUEUE := -4
const ERR_NOUNITS := -5
const ERR_INVALID := -6
const ERR_UNREACHABLE := -7
const ERR_NOSHORE := -8     # no hay orilla cerca para desembarcar
const ERR_CANT := -9        # esas unidades no pueden hacer eso
const ERR_FULL := -10       # el barco va lleno
const ERR_REQ := -11        # falta un requisito (p. ej. edificios militares para la Edad de los Castillos)
const ERR_COOLDOWN := -12   # la habilidad de civilización aún se está recargando
const ERR_NOTARGET := -13   # la habilidad necesita un punto del mapa
const ERR_POP := -14        # no cabe en la población
const ERR_NOMARKET := -15   # hace falta un mercado terminado
const ERR_DONE := -16       # esa mejora ya está investigada o en cola
const ERR_NOGAR := -17      # ese edificio no admite guarnición
const ERR_LIMIT := -18      # ya tienes el máximo de retoños o de minas a la vez

# Posturas de combate (Ent.stance)
const ST_AGGR := 0          # persigue a lo que vea (lo de siempre)
const ST_DEF := 1           # ataca a lo que se acerca y vuelve a su sitio si se aleja demasiado
const ST_HOLD := 2          # no se mueve: sólo dispara/golpea a lo que tenga a tiro
const ST_PASSIVE := 3       # no ataca por su cuenta
const FAUNA_WALK := 1.8     # segundos que tarda un animal en pasar a la casilla contigua
const MKT_TAX := 0.25       # diferencia entre el precio de compra y el de venta del mercado
const MKT_LOT := 100        # unidades por operación
const MKT_STEP := 4         # cuánto se mueve el precio con cada operación
const GAR_ARROW := 0.4      # daño extra por soldado refugiado en una torre, castillo o centro (fracción del disparo)
const FM_FREE := 0          # formaciones (Player.formation)
const FM_LINE := 1
const FM_COLUMN := 2
const FLEE_R := 9.0         # casillas: hasta dónde corre un aldeano atacado en busca de refugio
const BELL_R := 40.0        # casillas: el rebato llama a los aldeanos de hasta tan lejos
const GAR_HEAL := 0.02      # fracción de vida por segundo que se cura quien está refugiado
const GAR_ARROW_MAX := 8    # soldados que cuentan para el daño extra

var W: int = 0
var H: int = 0
var seed_used: int = 0
var terrain := PackedByteArray()
var rtype := PackedByteArray()
var ramt := PackedInt32Array()
var rowner := PackedByteArray()
var solid := PackedByteArray()
var occ := PackedInt32Array()
var astar: AStarGrid2D
var ents: Dictionary = {}
var units: Array[Ent] = []
var buildings: Array[Ent] = []
var players: Array[Player] = []
var ais: Array = []                      # IAs (AiPlayer; en tools/ai_match.gd también la copia AiLegacy)
var hostile: Array = []
var next_id: int = 1
var time: float = 0.0
var events: Array = []
var record_events: bool = true
var buckets: Array = []
var bucket_mask := PackedInt32Array()   # por cubo: bit (1 << dueño) de quién tiene algo allí (filtro previo de scan_enemy)
var hostile_bits := PackedInt32Array()  # por jugador: bits de los jugadores hostiles
var bw: int = 0
var bh: int = 0
var qcount: int = 0
var step_count: int = 0
var path_queue: Array = []
var farm_slots: Dictionary = {}
var game_over: bool = false
var winner_team: int = -1
var human_index: int = -1
var rng := RandomNumberGenerator.new()
var map_info: Dictionary = {}
var bfs_mark := PackedInt32Array()
var bfs_dist := PackedInt32Array()
var bfs_stamp: int = 0
var bad_res: Dictionary = {}
var comp := PackedInt32Array()
var dl := PackedInt32Array()
var dw := PackedInt32Array()
var heat := PackedByteArray()          # 0 frío .. 255 calor (aspecto y vegetación)
var chunk_cnt: Array = []
var cw: int = 0
var wall_tile := PackedByteArray()      # 1 = casilla con muralla o puerta
var gate_tile := PackedByteArray()      # 1 = puerta terminada (no sólida para aliados)
var astar2: AStarGrid2D                 # rejilla de asedio: las murallas se pueden atravesar con coste alto
var wall_count: int = 0
# --- exploración automática: la niebla (Fog) cuenta, por celda de 4×4 casillas, cuántas conoce el jugador humano
const EX_CELL := 4
const EX_DONE := 11                    # una celda con 11 de sus 16 casillas conocidas cuenta como explorada
var ex_w: int = 0
var explore_known := PackedByteArray()
var ex_rep := PackedInt32Array()       # por celda: casilla de tierra andable cercana a su centro (−1 si no hay)
var ex_rep_w := PackedInt32Array()     # por celda: casilla de agua navegable cercana a su centro (−1 si no hay)
var wsol := PackedByteArray()           # rejilla de agua (barcos): 1 = tierra, orilla o casilla con peces
var wcomp := PackedInt32Array()         # masa de agua conectada (−1 = tierra)
var wcomp_size: Array = []
var astar_w: AStarGrid2D                # rutas de barcos
var stowed_list: Array[Ent] = []        # unidades que acaban de subir a un barco (se retiran al final del paso)
var civ_mods: Array = []                # por jugador: tablas de multiplicadores de su civilización (Civs.build_mods; no se guarda)
var zones: Array = []                   # zonas de fuego activas (habilidad de los bizantinos): {p, r, dps, until, owner}
var fauna: Array = []                   # animales de caza: {i: casilla, home: casilla de origen, fx: salida (px), t0/t1: paseo, nx: próximo paseo, face}
var fauna_at: Dictionary = {}           # casilla -> registro de fauna (los mismos diccionarios que en `fauna`)
var up_mods: Array = []                 # por jugador: efecto de sus mejoras ya convertido en multiplicadores (no se guarda; ver _build_ups)
var saplings: Array = []                # casillas con retoño (en ramt queda lo que falta para ser árbol, en pasos); se rehace al cargar
var mines: Array = []                   # casillas de oro creadas por jugadores con una mina (rowner = dueño); se rehace al cargar

# ------------------------------------------------------------------ preparación

func setup(cfg: Dictionary) -> bool:
	var size: int = cfg.get("size", 192)
	var sd: int = cfg.get("seed", 1)
	var plist: Array = cfg.get("players", [])
	record_events = cfg.get("events", true)
	rng.seed = sd
	var m := MapGen.generate(size, sd, plist.size())
	if not m.get("ok", false):
		return false
	W = size
	H = size
	seed_used = m["seed_used"]
	terrain = m["terrain"]
	rtype = m["rtype"]
	ramt = m["ramt"]
	comp = m["comp"]
	dl = m["dl"]
	dw = m["dw"]
	heat = m["heat"]
	map_info = {"main_size": m["main_size"], "islands": m["islands"], "land_count": m["land_count"], "rock_count": m["rock_count"]}
	_build_grids()
	# Jugadores
	var starts: Array = m["starts"].duplicate()
	for i in range(starts.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = starts[i]
		starts[i] = starts[j]
		starts[j] = tmp
	for i in plist.size():
		var pc: Dictionary = plist[i]
		var p := Player.new()
		p.idx = i
		p.is_human = pc.get("human", false)
		p.team = pc.get("team", i)
		p.difficulty = pc.get("diff", 1)
		p.name = pc.get("name", Defs.PLAYER_COLOR_NAMES[i % 4])
		p.color = Defs.PLAYER_COLORS[i % 4]
		p.res = Defs.START_RES.duplicate()
		p.start_tile = starts[i]
		p.gather_mult = 1.0 if p.is_human else [0.8, 1.0, 1.2][clampi(p.difficulty, 0, 2)]
		p.civ = String(pc.get("civ", ""))
		players.append(p)
		if p.is_human and human_index < 0:
			human_index = i
	for a in players.size():
		var row: Array = []
		for b in players.size():
			row.append(players[a].team != players[b].team)
		hostile.append(row)
	_pick_civs()
	_setup_civs()
	_init_fauna()
	for p in players:
		_spawn_building("centro", p.idx, p.start_tile - Vector2i(1, 1), true)
	map_info["carved_trees"] = _ensure_routes()
	for p in players:
		var s: Vector2i = p.start_tile
		for k in 5:
			var ft := nearest_free_tile(s + Vector2i(k - 2, 3), 6)
			_spawn_unit("aldeano", p.idx, ft)
		if not p.is_human:
			ais.append(AiPlayer.new(self, p.idx, p.difficulty))
	_rebuild_buckets()
	return true


## "random" -> una civilización al azar (sin repetir mientras queden libres); cualquier valor no válido -> sin civilización.
func _pick_civs() -> void:
	var taken := {}
	for p in players:
		if Civs.valid(p.civ):
			taken[p.civ] = true
	for p in players:
		if p.civ == "random":
			var free: Array = []
			for c: String in Civs.IDS:
				if not taken.has(c):
					free.append(c)
			if free.is_empty():
				free = Civs.IDS.duplicate()
			p.civ = free[rng.randi_range(0, free.size() - 1)]
			taken[p.civ] = true
		elif not Civs.valid(p.civ):
			p.civ = ""

## Tablas de multiplicadores de cada jugador (se rehacen al cargar una partida: no se guardan).
func _setup_civs() -> void:
	civ_mods.clear()
	up_mods.clear()
	for p in players:
		civ_mods.append(Civs.build_mods(p.civ))
		up_mods.append(_build_ups(p))

## Convierte las mejoras investigadas en tablas por tipo de unidad: atk (×), arm (× al daño recibido), rng (+casillas),
## hp (×), gather (× por tipo de recurso) y carry (+unidades). Se rehace al terminar una mejora y al cargar la partida.
func _build_ups(p: Player) -> Dictionary:
	var out := {"atk": {}, "arm": {}, "rng": {}, "hp": {}, "gather": PackedFloat32Array(), "carry": 0.0}
	var g := PackedFloat32Array()
	g.resize(Defs.RES_N)
	g.fill(1.0)
	var sel_rt := {"wood": [Defs.R_TREE], "gold": [Defs.R_GOLD], "stone": [Defs.R_STONE], "farm": [Defs.R_FARM],
		"berry": [Defs.R_BERRY], "hunt": [Defs.R_DEER, Defs.R_BOAR], "fish": [Defs.R_FISH]}
	for tid: String in p.techs:
		var t: Dictionary = Defs.TECHS.get(tid, {})
		if t.is_empty():
			continue
		for stat in ["atk", "rng", "hp"]:
			var rules: Dictionary = t.get(stat, {})
			for ut: String in Defs.UNITS:
				for sel: String in rules:
					if Civs.sel_matches(sel, ut):
						var d: Dictionary = out[stat]
						var base := 0.0 if stat == "rng" else 1.0
						d[ut] = float(d.get(ut, base)) + float(rules[sel])
		var arm: Dictionary = t.get("arm", {})
		for ut2: String in Defs.UNITS:
			for sel2: String in arm:
				if Civs.sel_matches(sel2, ut2):
					var da: Dictionary = out["arm"]
					da[ut2] = maxf(0.4, float(da.get(ut2, 1.0)) - float(arm[sel2]))
		var gm: Dictionary = t.get("gather", {})
		for sel3: String in gm:
			for rt: int in sel_rt.get(sel3, []):
				g[rt] += float(gm[sel3])
		out["carry"] = float(out["carry"]) + float(t.get("carry", 0.0))
	out["gather"] = g
	return out

func _recalc_ups(pidx: int) -> void:
	while up_mods.size() <= pidx:
		up_mods.append({})
	up_mods[pidx] = _build_ups(players[pidx])

## Alcance efectivo en casillas: el de la unidad por su civilización más lo que den las mejoras (sólo a las de distancia).
func eff_range(e: Ent) -> float:
	var r := float(e.def["range"]) * e.rm
	if r > 1.5 and e.owner < up_mods.size():
		r += float((up_mods[e.owner]["rng"] as Dictionary).get(e.type, 0.0))
	return r

func _up_atk(e: Ent) -> float:
	if e.owner >= up_mods.size():
		return 1.0
	return float((up_mods[e.owner]["atk"] as Dictionary).get(e.type, 1.0))

func _apply_up_hp(e: Ent) -> void:
	if e.owner >= up_mods.size():
		return
	var f: Variant = (up_mods[e.owner]["hp"] as Dictionary).get(e.type)
	if f != null:
		e.max_hp *= float(f)
		e.hp = e.max_hp

## Fija en la unidad recién creada los multiplicadores de su civilización (vida, daño, velocidad, alcance, vista).
func _apply_civ(e: Ent) -> void:
	if e.owner >= civ_mods.size():
		return
	var cm: Dictionary = civ_mods[e.owner]
	var f: Variant = (cm["hp"] as Dictionary).get(e.type)
	if f != null:
		e.max_hp *= float(f)
		e.hp = e.max_hp
	f = (cm["atk"] as Dictionary).get(e.type)
	if f != null:
		e.am = float(f)
	f = (cm["spd"] as Dictionary).get(e.type)
	if f != null:
		e.sm = float(f)
	f = (cm["rng"] as Dictionary).get(e.type)
	if f != null:
		e.rm = float(f)
	f = (cm["los"] as Dictionary).get(e.type)
	if f != null:
		e.lb = int(f)

## Coste de entrenar `utype` para este jugador (con el descuento de su civilización).
func unit_cost(pidx: int, utype: String) -> Dictionary:
	var base: Dictionary = Defs.UNITS[utype]["cost"]
	if pidx < 0 or pidx >= civ_mods.size():
		return base
	var f: Variant = (civ_mods[pidx]["cost"] as Dictionary).get(utype)
	if f == null:
		return base
	var out := {}
	for k in base:
		out[k] = int(round(float(base[k]) * float(f)))
	return out

## Segundos que tarda `utype` en entrenarse para este jugador.
func unit_time(pidx: int, utype: String) -> float:
	var base := float(Defs.UNITS[utype]["time"])
	if pidx < 0 or pidx >= civ_mods.size():
		return base
	var f: Variant = (civ_mods[pidx]["time"] as Dictionary).get(utype)
	return base * float(f) if f != null else base

## Coste y duración de la siguiente edad para este jugador.
func age_cost(pidx: int, age: int) -> Dictionary:
	var base: Dictionary = Defs.AGES[age]["cost"]
	var f := float(civ_mods[pidx]["age_cost"]) if pidx < civ_mods.size() else 1.0
	if f == 1.0:
		return base
	var out := {}
	for k in base:
		out[k] = int(round(float(base[k]) * f))
	return out

func age_time(pidx: int, age: int) -> float:
	var f := float(civ_mods[pidx]["age_time"]) if pidx < civ_mods.size() else 1.0
	return float(Defs.AGES[age]["time"]) * f

func _bld_pop(b: Ent) -> int:
	var n := int(b.def.get("pop", 0))
	if b.type == "casa" and b.owner < civ_mods.size():
		n += int(civ_mods[b.owner]["pop_house"])
	return n

## Garantiza que desde cualquier casilla libre junto al centro urbano de cada base se pueda ir andando a las demás bases.
## Los árboles, las minas y las bayas son sólidos, así que un bosque denso puede cortar el paso por completo (los
## ejércitos no llegarían a verse: la IA no ataca y tú tampoco) o dejar un hueco cerrado junto al centro donde
## aparecerían las unidades. Si no hay ruta, se busca la que cruza menos árboles (o, si no hay otra, un paso de
## montaña) y se abre un claro de unas 3 casillas de ancho. Devuelve cuántas casillas se despejaron.
func _ensure_routes() -> int:
	var opened := 0
	var tmp: AStarGrid2D = null
	var anchors: Array[Vector2i] = []
	var pockets: Array = []          # [casilla de un hueco cerrado, ancla de su base]
	for p in players:
		var s: Vector2i = p.start_tile
		var ring: Array[Vector2i] = []
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if maxi(absi(dx), absi(dy)) == 2:
					var q := s + Vector2i(dx, dy)
					if in_bounds(q) and not astar.is_point_solid(q):
						ring.append(q)
		# Componentes de la corona (sólo se cuentan hasta 2500 casillas: basta para distinguir «mundo» de «hueco»)
		var seen: Dictionary = {}
		var comps: Array = []        # [casilla, tamaño]
		for q in ring:
			if seen.has(q):
				continue
			var stack: Array[Vector2i] = [q]
			seen[q] = true
			var cnt := 0
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				cnt += 1
				if cnt >= 2500:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if in_bounds(n) and not seen.has(n) and not astar.is_point_solid(n):
						seen[n] = true
						stack.append(n)
			comps.append([q, cnt])
		if comps.is_empty():
			anchors.append(Vector2i(-1, -1))
			continue
		var best := 0
		for k in comps.size():
			if int(comps[k][1]) > int(comps[best][1]):
				best = k
		anchors.append(comps[best][0])
		for k in comps.size():
			if k != best:
				pockets.append([comps[k][0], comps[best][0]])
	var links: Array = []
	for i in range(1, anchors.size()):
		if anchors[0].x >= 0 and anchors[i].x >= 0:
			links.append([anchors[i], anchors[0]])
	links.append_array(pockets)
	for l in links:
		var a: Vector2i = l[0]
		var b: Vector2i = l[1]
		if not astar.get_id_path(a, b, false).is_empty():
			continue
		if tmp == null:
			tmp = AStarGrid2D.new()
			tmp.region = Rect2i(0, 0, W, H)
			tmp.cell_size = Vector2(1, 1)
			tmp.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
			tmp.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
			tmp.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
			tmp.update()
			for k in W * H:
				var rt := rtype[k]
				var pt := Vector2i(k % W, k / W)
				if terrain[k] == Defs.T_WATER or rt == Defs.R_GOLD or rt == Defs.R_BERRY or rt == Defs.R_STONE or occ[k] != 0:
					tmp.set_point_solid(pt, true)
				elif terrain[k] == Defs.T_ROCK:
					tmp.set_point_weight_scale(pt, 30.0)     # un paso de montaña sólo si no hay otra salida
				elif rt == Defs.R_TREE:
					tmp.set_point_weight_scale(pt, 6.0)
		var path: Array = tmp.get_id_path(a, b, false)
		for t in path:
			var rocky: bool = terrain[t.y * W + t.x] == Defs.T_ROCK
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var q: Vector2i = t + Vector2i(dx, dy)
					if not in_bounds(q):
						continue
					var qi := q.y * W + q.x
					if rtype[qi] == Defs.R_TREE:
						_fell_tree(q)
						opened += 1
					elif rocky and terrain[qi] == Defs.T_ROCK:
						_open_pass(q)
						opened += 1
	return opened

## Abre un paso en una cordillera: la casilla de roca pasa a hierba.
func _open_pass(q: Vector2i) -> void:
	var i := q.y * W + q.x
	terrain[i] = Defs.T_GRASS
	solid[i] = 0
	astar.set_point_solid(q, false)
	astar2.set_point_solid(q, false)

func _fell_tree(q: Vector2i) -> void:
	var i := q.y * W + q.x
	rtype[i] = Defs.R_NONE
	ramt[i] = 0
	solid[i] = 0
	astar.set_point_solid(q, false)
	astar2.set_point_solid(q, false)
	var ci := (q.y / 8) * cw + q.x / 8
	chunk_cnt[Defs.R_TREE][ci] = maxi(0, int(chunk_cnt[Defs.R_TREE][ci]) - 1)

## Rejillas derivadas del terreno (sólido, rutas, agua, cubos de búsqueda). La usan setup() y SaveGame.
func _build_grids() -> void:
	var total := W * H
	rowner.resize(total)
	rowner.fill(255)
	solid.resize(total)
	occ.resize(total)
	bfs_mark.resize(total)
	bfs_dist.resize(total)
	solid.fill(0)
	occ.fill(0)
	bfs_mark.fill(0)
	bfs_dist.fill(0)
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	astar2 = AStarGrid2D.new()
	astar2.region = Rect2i(0, 0, W, H)
	astar2.cell_size = Vector2(1, 1)
	astar2.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar2.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar2.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar2.update()
	wall_tile.resize(total)
	gate_tile.resize(total)
	wall_tile.fill(0)
	gate_tile.fill(0)
	for i in total:
		var rt := rtype[i]
		if terrain[i] == Defs.T_WATER or terrain[i] == Defs.T_ROCK or Defs.solid_res(rt):
			solid[i] = 1
			astar.set_point_solid(Vector2i(i % W, i / W), true)
			astar2.set_point_solid(Vector2i(i % W, i / W), true)
	_setup_water()
	cw = (W + 7) / 8
	for k in Defs.RES_N:
		var arr := PackedInt32Array()
		arr.resize(cw * cw)
		chunk_cnt.append(arr)
	for i in total:
		if rtype[i] != 0:
			chunk_cnt[rtype[i]][((i / W) / 8) * cw + (i % W) / 8] += 1
	bw = (W + BUCKET - 1) / BUCKET
	bh = (H + BUCKET - 1) / BUCKET
	for i in bw * bh:
		buckets.append([])


func _setup_water() -> void:
	var total := W * H
	wsol.resize(total)
	wsol.fill(0)
	wcomp.resize(total)
	wcomp.fill(-1)
	astar_w = AStarGrid2D.new()
	astar_w.region = Rect2i(0, 0, W, H)
	astar_w.cell_size = Vector2(1, 1)
	astar_w.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar_w.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_w.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar_w.update()
	for i in total:
		if terrain[i] != Defs.T_WATER or rtype[i] == Defs.R_FISH:
			wsol[i] = 1
			astar_w.set_point_solid(Vector2i(i % W, i / W), true)
	var wid := 0
	for i in total:
		if terrain[i] != Defs.T_WATER or wcomp[i] >= 0:
			continue
		var q := PackedInt32Array([i])
		wcomp[i] = wid
		var head := 0
		while head < q.size():
			var cur: int = q[head]
			head += 1
			var cx := cur % W
			var cy := cur / W
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var nx: int = cx + d.x
				var ny: int = cy + d.y
				if nx < 0 or ny < 0 or nx >= W or ny >= H:
					continue
				var ni := ny * W + nx
				if terrain[ni] == Defs.T_WATER and wcomp[ni] < 0:
					wcomp[ni] = wid
					q.append(ni)
		wcomp_size.append(q.size())
		wid += 1

# ------------------------------------------------------------------ utilidades

func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(p.x / Defs.TILE), 0, W - 1), clampi(int(p.y / Defs.TILE), 0, H - 1))

func tile_center(t: Vector2i) -> Vector2:
	return (Vector2(t) + Vector2(0.5, 0.5)) * Defs.TILE

func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H

func is_solid_tile(t: Vector2i) -> bool:
	return (not in_bounds(t)) or solid[t.y * W + t.x] == 1

func set_solid(t: Vector2i, v: bool) -> void:
	var i := t.y * W + t.x
	solid[i] = 1 if v else 0
	astar.set_point_solid(t, v)
	astar2.set_point_solid(t, v and wall_tile[i] == 0)

func get_ent(id: int) -> Ent:
	var e: Ent = ents.get(id)
	if e != null and e.alive and not e.stowed:
		return e
	return null

func _ev(d: Dictionary) -> void:
	if record_events:
		events.append(d)

func nearest_free_tile(center: Vector2i, maxr: int = 10) -> Vector2i:
	if in_bounds(center) and not is_solid_tile(center):
		return center
	for r in range(1, maxr + 1):
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := center + Vector2i(dx, dy)
				if in_bounds(t) and not is_solid_tile(t):
					var d := float(dx * dx + dy * dy)
					if d < bd:
						bd = d
						best = t
		if best.x >= 0:
			return best
	return center

func free_tiles_around(center: Vector2i, count: int, maxr: int = 8) -> Array:
	var out: Array = []
	if in_bounds(center) and not is_solid_tile(center):
		out.append(center)
	var r := 1
	while out.size() < count and r <= maxr:
		var ring: Array = []
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := center + Vector2i(dx, dy)
				if in_bounds(t) and not is_solid_tile(t):
					ring.append(t)
		ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2(a - center).length_squared() < Vector2(b - center).length_squared())
		for t in ring:
			if out.size() < count:
				out.append(t)
		r += 1
	return out

func water_comp_at(t: Vector2i) -> int:
	return wcomp[t.y * W + t.x] if in_bounds(t) else -1

func is_free_water(t: Vector2i, wc: int) -> bool:
	return in_bounds(t) and wsol[t.y * W + t.x] == 0 and wcomp[t.y * W + t.x] == wc

func nearest_water_tile(center: Vector2i, wc: int, maxr: int = 8) -> Vector2i:
	## Casilla de agua libre de la masa `wc` más cercana a `center` (o la propia si ya lo es).
	if wc < 0:
		return Vector2i(-1, -1)
	if is_free_water(center, wc):
		return center
	for r in range(1, maxr + 1):
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := center + Vector2i(dx, dy)
				if is_free_water(t, wc):
					var d := float(dx * dx + dy * dy)
					if d < bd:
						bd = d
						best = t
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)

func free_water_around(center: Vector2i, count: int, maxr: int, wc: int) -> Array:
	var out: Array = []
	if is_free_water(center, wc):
		out.append(center)
	var r := 1
	while out.size() < count and r <= maxr:
		var ring: Array = []
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and is_free_water(center + Vector2i(dx, dy), wc):
					ring.append(center + Vector2i(dx, dy))
		ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2(a - center).length_squared() < Vector2(b - center).length_squared())
		for t in ring:
			if out.size() < count:
				out.append(t)
		r += 1
	return out

func dock_info(tile: Vector2i, size: int) -> Dictionary:
	## Puerto en `tile`: lado con más agua abierta junto a la huella (0 norte, 1 este, 2 sur, 3 oeste)
	## y casilla de agua donde aparecerán los barcos. Hace falta mar de verdad (no una charca).
	var best_n := 0
	var best_side := 2
	var best_spawn := Vector2i(-1, -1)
	for side in [2, 1, 3, 0]:
		var n := 0
		var sp := Vector2i(-1, -1)
		var spd := 99
		for k in size:
			var t := tile
			match side:
				0: t = tile + Vector2i(k, -1)
				1: t = tile + Vector2i(size, k)
				2: t = tile + Vector2i(k, size)
				_: t = tile + Vector2i(-1, k)
			if not in_bounds(t):
				continue
			var i := t.y * W + t.x
			if terrain[i] == Defs.T_WATER and wsol[i] == 0 and int(wcomp_size[wcomp[i]]) >= Defs.MIN_SEA:
				n += 1
				var d := absi(k - size / 2)
				if d < spd:
					spd = d
					sp = t
		if n > best_n:
			best_n = n
			best_side = side
			best_spawn = sp
	return {"ok": best_n >= 2, "orient": best_side, "spawn": best_spawn}

func is_hostile(a: int, b: int) -> bool:
	return hostile[a][b]

# ------------------------------------------------------------------ creación

func _spawn_unit(type: String, owner: int, tile: Vector2i) -> Ent:
	var d: Dictionary = Defs.UNITS[type]
	var e := Ent.new()
	e.id = next_id
	next_id += 1
	e.type = type
	e.owner = owner
	e.def = d
	e.is_building = false
	e.pos = tile_center(tile)
	e.ppos = e.pos
	e.max_hp = float(d["hp"]) * float(Defs.AGE_STAT_MULT[players[owner].age])
	e.hp = e.max_hp
	_apply_civ(e)
	_apply_up_hp(e)
	e.radius = d["radius"]
	e.naval = bool(d.get("naval", false))
	e.off = Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0))
	e.home = e.pos
	e.scan_t = rng.randf() * 0.5
	ents[e.id] = e
	units.append(e)
	players[owner].pop += 1
	return e

func _spawn_building(type: String, owner: int, tile: Vector2i, complete: bool) -> Ent:
	var d: Dictionary = Defs.BUILDINGS[type]
	var e := Ent.new()
	e.id = next_id
	next_id += 1
	e.type = type
	e.owner = owner
	e.def = d
	e.is_building = true
	e.size = d["size"]
	e.tile = tile
	e.pos = e.center()
	e.ppos = e.pos
	e.max_hp = float(d["hp"])
	if owner < civ_mods.size():
		e.max_hp *= float(civ_mods[owner]["bld_hp"])
	e.progress = 1.0 if complete else 0.0
	e.hp = e.max_hp if complete else e.max_hp * 0.1
	e.radius = e.size * Defs.TILE * 0.5
	if bool(d.get("dock", false)):
		var di := dock_info(tile, e.size)
		e.orient = di["orient"]
		e.dock_tile = di["spawn"]
	var is_wall: bool = d.get("wall", false)
	for dy in e.size:
		for dx in e.size:
			var t := tile + Vector2i(dx, dy)
			occ[t.y * W + t.x] = e.id
			if is_wall:
				wall_tile[t.y * W + t.x] = 1
				astar2.set_point_weight_scale(t, 6.0)
				wall_count += 1
			set_solid(t, true)
	ents[e.id] = e
	buildings.append(e)
	if complete:
		_on_building_complete(e, false)
	return e

func _on_building_complete(b: Ent, announce: bool) -> void:
	if bool(b.def.get("mine", false)):
		_convert_mine(b)
		return
	var p: Player = players[b.owner]
	if b.def.get("gate", false):
		# la puerta terminada deja de ser sólida: pasan los aliados; al enemigo lo frena _follow
		gate_tile[b.tile.y * W + b.tile.x] = 1
		astar2.set_point_weight_scale(b.tile, 1.0)
		set_solid(b.tile, false)
	p.pop_cap = mini(Defs.MAX_POP, p.pop_cap + _bld_pop(b))
	if announce:
		_ev({"t": "built", "pos": b.pos, "owner": b.owner, "type": b.type})

## La mina terminada deja de ser un edificio: queda un depósito de oro (MINE_YIELD) en su casilla de arriba a la
## izquierda, el resto de la obra vuelve a ser suelo libre y los albañiles se ponen a picar.
func _convert_mine(b: Ent) -> void:
	var keep := b.tile
	for dy in b.size:
		for dx in b.size:
			var t := b.tile + Vector2i(dx, dy)
			occ[t.y * W + t.x] = 0
			if t != keep:
				set_solid(t, false)
	var ki := keep.y * W + keep.x
	rtype[ki] = Defs.R_GOLD
	ramt[ki] = Defs.MINE_YIELD
	rowner[ki] = b.owner
	chunk_cnt[Defs.R_GOLD][((ki / W) / 8) * cw + (ki % W) / 8] += 1
	mines.append(ki)
	b.alive = false
	b.progress = 1.0
	dead.append(b)
	for u in units:
		if u.alive and u.target_id == b.id and (u.state == S_BUILD or u.state == S_BUILD_GO):
			_assign_gather(u, keep, "gold")
	_ev({"t": "mine_open", "pos": tile_center(keep), "owner": b.owner, "tile": keep})

# ------------------------------------------------------------------ búsqueda espacial

func _rebuild_buckets() -> void:
	for b in buckets:
		b.clear()
	if bucket_mask.size() != buckets.size():
		bucket_mask.resize(buckets.size())
	bucket_mask.fill(0)
	var bs := float(BUCKET * Defs.TILE)
	for e in units:
		if e.alive:
			var bx := clampi(int(e.pos.x / bs), 0, bw - 1)
			var by := clampi(int(e.pos.y / bs), 0, bh - 1)
			var bi := by * bw + bx
			buckets[bi].append(e)
			bucket_mask[bi] |= 1 << e.owner
	for e in buildings:
		if e.alive:
			var r := e.rect()
			var x0 := clampi(int(r.position.x / bs), 0, bw - 1)
			var x1 := clampi(int((r.end.x - 1.0) / bs), 0, bw - 1)
			var y0 := clampi(int(r.position.y / bs), 0, bh - 1)
			var y1 := clampi(int((r.end.y - 1.0) / bs), 0, bh - 1)
			var bit := 1 << e.owner
			for by in range(y0, y1 + 1):
				for bx in range(x0, x1 + 1):
					buckets[by * bw + bx].append(e)
					bucket_mask[by * bw + bx] |= bit

## Recalcula el filtro por dueño a partir de los cubos (tras cargar una partida guardada).
func rebuild_bucket_masks() -> void:
	bucket_mask.resize(buckets.size())
	bucket_mask.fill(0)
	for i in buckets.size():
		for e: Ent in buckets[i]:
			if e.alive:
				bucket_mask[i] |= 1 << e.owner

func _calc_hostile_bits() -> void:
	hostile_bits.resize(players.size())
	for a in players.size():
		var bits := 0
		for b in players.size():
			if hostile[a][b]:
				bits |= 1 << b
		hostile_bits[a] = bits

func query(pos: Vector2, r: float) -> Array[Ent]:
	## Entidades vivas cuyo borde está a menos de r píxeles de pos.
	qcount += 1
	var out: Array[Ent] = []
	var bs := float(BUCKET * Defs.TILE)
	var x0 := clampi(int((pos.x - r) / bs), 0, bw - 1)
	var x1 := clampi(int((pos.x + r) / bs), 0, bw - 1)
	var y0 := clampi(int((pos.y - r) / bs), 0, bh - 1)
	var y1 := clampi(int((pos.y + r) / bs), 0, bh - 1)
	for by in range(y0, y1 + 1):
		for bx in range(x0, x1 + 1):
			for e: Ent in buckets[by * bw + bx]:
				if e.qmark == qcount or not e.alive:
					continue
				e.qmark = qcount
				if e.dist_to(pos) <= r:
					out.append(e)
	return out

func scan_enemy(e: Ent, r: float) -> Ent:
	# Filtro previo: si en los cubos que cubre el alcance no hay nadie hostil, no hace falta recorrer a nadie
	# (la gran mayoría de los escaneos de soldados parados en su base acaban aquí).
	if hostile_bits.size() != players.size():
		_calc_hostile_bits()
	var hb: int = hostile_bits[e.owner]
	if hb == 0:
		return null
	var bsz := float(BUCKET * Defs.TILE)
	var qx0 := clampi(int((e.pos.x - r) / bsz), 0, bw - 1)
	var qx1 := clampi(int((e.pos.x + r) / bsz), 0, bw - 1)
	var qy0 := clampi(int((e.pos.y - r) / bsz), 0, bh - 1)
	var qy1 := clampi(int((e.pos.y + r) / bsz), 0, bh - 1)
	var seen_mask := 0
	for qy in range(qy0, qy1 + 1):
		for qx in range(qx0, qx1 + 1):
			seen_mask |= bucket_mask[qy * bw + qx]
	if seen_mask & hb == 0:
		return null
	var best: Ent = null
	var bs := 1e9
	for o in query(e.pos, r):
		if o.owner == e.owner or not hostile[e.owner][o.owner]:
			continue
		if o.id == e.ignore_id and time < e.ignore_until:
			continue
		if o.naval and not e.naval:
			# a los barcos sólo se les dispara desde la orilla: los de cuerpo a cuerpo no pueden, y los
			# arqueros no salen a perseguirlos mar adentro
			if float(e.def["range"]) <= 1.5 or o.dist_to(e.pos) > eff_range(e) * Defs.TILE:
				continue
		if bool(e.def.get("siege", false)) and not o.is_building:
			continue
		var d: float = o.dist_to(e.pos)
		var score := d
		if o.is_building:
			score += 200.0
			if o.progress < 1.0:
				score += 100.0
			if o.def.get("wall", false):
				score += 150.0
		elif not o.is_military():
			score += 60.0
		if score < bs:
			bs = score
			best = o
	return best

# ------------------------------------------------------------------ rutas

func _request_path(e: Ent, goal: Vector2i) -> void:
	e.goal = goal
	e.path = []
	e.path_i = 0
	if not e.path_pending:
		e.path_pending = true
		path_queue.append(e.id)

func _footprint_of(goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var bid := occ[goal.y * W + goal.x]
	if bid != 0:
		var b: Ent = ents.get(bid)
		if b != null:
			for dy in b.size:
				for dx in b.size:
					out.append(b.tile + Vector2i(dx, dy))
			return out
	out.append(goal)
	return out

func _path_into(start: Vector2i, goal: Vector2i) -> Array:
	## Camino hasta quedar junto a una casilla sólida (árbol, mina, edificio):
	## se desbloquea un instante la huella, se calcula la ruta óptima hasta ella
	## y se recorta el tramo que entra en la huella.
	var tiles := _footprint_of(goal)
	for t in tiles:
		astar.set_point_solid(t, false)
	var p: Array = []
	if start == goal:
		p = [start]
	else:
		p = astar.get_id_path(start, goal, false)
	for t in tiles:
		astar.set_point_solid(t, true)
	while p.size() > 1 and tiles.has(p[p.size() - 1]):
		p.pop_back()
	if p.size() == 1 and tiles.has(p[0]):
		return [start] if not tiles.has(start) else []
	return p

func _naval_path(start: Vector2i, goal: Vector2i) -> Array:
	## Ruta de un barco por agua. Si la meta es una casilla con peces (sólida), se llega junto a ella.
	if not in_bounds(start) or not in_bounds(goal):
		return []
	var si := start.y * W + start.x
	var gi := goal.y * W + goal.x
	if wcomp[si] < 0 or wcomp[gi] < 0 or wcomp[si] != wcomp[gi]:
		return []
	if start == goal:
		return [start]
	if wsol[gi] == 1:
		# meta sólida (peces): se desbloquea un instante y se recorta el último tramo
		astar_w.set_point_solid(goal, false)
		var p: Array = astar_w.get_id_path(start, goal, false)
		astar_w.set_point_solid(goal, true)
		while p.size() > 1 and p[p.size() - 1] == goal:
			p.pop_back()
		if p.size() == 1 and p[0] == goal:
			return [start]
		return p
	if wsol[si] == 1:
		# salió de su casilla (borde de la orilla): sólo vale si la meta es esa misma
		return []
	return astar_w.get_id_path(start, goal, false)

func _siege_path(start: Vector2i, goal: Vector2i) -> Array:
	## Ruta que atraviesa murallas (con coste alto) cuando no hay camino libre; el que la sigue
	## romperá la muralla que le cierre el paso (ver _follow / _blocked_by).
	var tiles := _footprint_of(goal)
	var restore: Array = []
	for t in tiles:
		if astar2.is_point_solid(t):
			astar2.set_point_solid(t, false)
			restore.append(t)
	var p: Array = []
	if start == goal:
		p = [start]
	else:
		p = astar2.get_id_path(start, goal, false)
	for t in restore:
		astar2.set_point_solid(t, true)
	while p.size() > 1 and tiles.has(p[p.size() - 1]):
		p.pop_back()
	if p.size() == 1 and tiles.has(p[0]):
		return [start] if not tiles.has(start) else []
	return p

func _blocked_by(e: Ent, w: Ent) -> int:
	## Una unidad topa con una muralla o puerta enemiga: los soldados la atacan.
	if e.is_military() and (e.state == S_ATTACK_GO or (e.state == S_MOVE and e.amove)):
		if e.state == S_ATTACK_GO and e.target_id != w.id and e.resume_id == 0:
			e.resume_id = e.target_id
		_engage(e, w, true)
		return 0
	return 2

func _process_path_queue() -> void:
	var n := 0
	while n < PATHS_PER_STEP and path_queue.size() > 0:
		var id: int = path_queue.pop_front()
		var e: Ent = ents.get(id)
		if e == null or not e.alive or not e.path_pending:
			continue
		e.path_pending = false
		n += 1
		var tp0 := 0
		if profiling:
			tp0 = Time.get_ticks_usec()
		var start := tile_of(e.pos)
		var goal := e.goal
		var p: Array = []
		if e.naval:
			if not (e.goal == e.fail_goal and time - e.fail_time < 10.0):
				p = _naval_path(start, goal)
		else:
			var same_comp := in_bounds(goal) and comp[start.y * W + start.x] >= 0 and comp[start.y * W + start.x] == comp[goal.y * W + goal.x]
			if e.goal == e.fail_goal and time - e.fail_time < 10.0:
				p = []
			elif same_comp:
				if is_solid_tile(goal):
					p = _path_into(start, goal)
				elif start == goal:
					p = [start]
				else:
					p = astar.get_id_path(start, goal, false)
			if p.is_empty() and same_comp and wall_count > 0 and e.is_military() and (e.state == S_ATTACK_GO or (e.state == S_MOVE and e.amove)):
				p = _siege_path(start, goal)
		e.path = p
		e.path_i = 1 if p.size() > 1 else p.size()
		if p.is_empty():
			e.fails += 1
			e.fail_goal = goal
			e.fail_time = time
		if profiling:
			var dtp := Time.get_ticks_usec() - tp0
			var key := "st%d_%s" % [e.state, e.type]
			prof[key + "_n"] = int(prof.get(key + "_n", 0)) + 1
			prof[key + "_us"] = int(prof.get(key + "_us", 0)) + dtp
			if dtp > 3000:
				prof["slow_n"] = int(prof.get("slow_n", 0)) + 1
				if not prof.has("slow_sample"):
					prof["slow_sample"] = "from %s to %s len %d state %d type %s" % [str(start), str(goal), p.size(), e.state, e.type]

func _follow(e: Ent, step_px: float) -> int:
	## 0 = moviéndose o esperando ruta, 1 = ruta terminada, 2 = sin ruta
	if e.path_pending:
		return 0
	if e.path.is_empty():
		return 2
	var guard := 0
	while step_px > 0.0 and e.path_i < e.path.size() and guard < 8:
		guard += 1
		var t: Vector2i = e.path[e.path_i]
		var tidx := t.y * W + t.x
		if wall_tile[tidx] == 1 and (gate_tile[tidx] == 1 or solid[tidx] == 1) and e.path_i < e.path.size() - 1 + (1 if gate_tile[tidx] == 1 else 0):
			var wb: Ent = ents.get(occ[tidx])
			if wb != null and wb.alive and hostile[e.owner][wb.owner]:
				return _blocked_by(e, wb)
		if (wsol[tidx] if e.naval else solid[tidx]) == 1 and e.path_i < e.path.size() - 1:
			# El camino se bloqueó (edificio nuevo): recalcular
			if e.repath_t <= 0.0:
				e.repath_t = 0.5
				_request_path(e, e.goal)
			return 0
		var wp := tile_center(t) + e.off
		if e.path_i == e.path.size() - 1:
			wp = tile_center(t) + e.off * 0.5
		var to := wp - e.pos
		var dist := to.length()
		if dist <= step_px:
			e.pos = wp
			step_px -= dist
			e.path_i += 1
		else:
			e.pos += to / dist * step_px
			step_px = 0.0
	if e.path_i >= e.path.size():
		return 1
	return 0

# ------------------------------------------------------------------ búsqueda de recursos

func res_mask_for(kind: String) -> int:
	match kind:
		"wood":
			return 1 << Defs.R_TREE
		"gold":
			return 1 << Defs.R_GOLD
		"stone":
			return 1 << Defs.R_STONE
		"food":
			return (1 << Defs.R_BERRY) | (1 << Defs.R_FARM) | (1 << Defs.R_DEER) | (1 << Defs.R_BOAR)
	return 0

func kind_of_tile(t: Vector2i) -> String:
	var rt := rtype[t.y * W + t.x]
	if rt == 0:
		return ""
	return Defs.RES_INFO[rt]["kind"]

func _farm_slot_free(idx: int, uid: int) -> bool:
	var occupant: int = farm_slots.get(idx, 0)
	if occupant == 0 or occupant == uid:
		return true
	var o: Ent = get_ent(occupant)
	if o == null:
		return true
	return o.target_tile != Vector2i(idx % W, idx / W)

func _res_usable(idx: int, mask: int, owner: int, uid: int) -> bool:
	var rt := rtype[idx]
	if rt == 0 or ((1 << rt) & mask) == 0 or ramt[idx] <= 0:
		return false
	if bad_res.size() > 0 and float(bad_res.get(idx, 0.0)) > time:
		return false
	if rt == Defs.R_FARM:
		if rowner[idx] != owner:
			return false
		return _farm_slot_free(idx, uid)
	return true

func find_resource(from: Vector2i, mask: int, owner: int, uid: int, maxd: int = 16, max_nodes: int = 1400) -> Vector2i:
	## Recurso más cercano por camino real (BFS por casillas transitables).
	bfs_stamp += 1
	bfs_calls += 1
	var q := PackedInt32Array()
	var start := clampi(from.y, 0, H - 1) * W + clampi(from.x, 0, W - 1)
	q.append(start)
	bfs_mark[start] = bfs_stamp
	bfs_dist[start] = 0
	if _res_usable(start, mask, owner, uid):
		return Vector2i(start % W, start / W)
	var head := 0
	while head < q.size() and q.size() < max_nodes:
		var cur: int = q[head]
		head += 1
		var cx := cur % W
		var cy := cur / W
		var d: int = bfs_dist[cur]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx := cx + dx
				var ny := cy + dy
				if nx < 0 or ny < 0 or nx >= W or ny >= H:
					continue
				if dx != 0 and dy != 0:
					continue
				var ni := ny * W + nx
				if _res_usable(ni, mask, owner, uid):
					return Vector2i(nx, ny)
				if solid[ni] == 0 and bfs_mark[ni] != bfs_stamp and d < maxd:
					bfs_mark[ni] = bfs_stamp
					bfs_dist[ni] = d + 1
					q.append(ni)
	bfs_nodes += q.size()
	return find_resource_far(from, mask)

func find_resource_far(from: Vector2i, mask: int) -> Vector2i:
	## Búsqueda global por fragmentos de 8x8 (árboles, oro y bayas), misma masa de tierra.
	var fcomp: int = comp[clampi(from.y, 0, H - 1) * W + clampi(from.x, 0, W - 1)]
	if fcomp < 0:
		return Vector2i(-1, -1)
	var kinds: Array = []
	for rt in [Defs.R_TREE, Defs.R_GOLD, Defs.R_BERRY, Defs.R_STONE, Defs.R_DEER, Defs.R_BOAR]:
		if (mask & (1 << rt)) != 0:
			kinds.append(rt)
	if kinds.is_empty():
		return Vector2i(-1, -1)
	var cx0 := from.x / 8
	var cy0 := from.y / 8
	var best := Vector2i(-1, -1)
	var bd := 1e12
	for r in range(0, cw):
		if best.x >= 0 and float(r - 1) * 8.0 > sqrt(bd):
			break
		for cy in range(cy0 - r, cy0 + r + 1):
			if cy < 0 or cy >= cw:
				continue
			for cx in range(cx0 - r, cx0 + r + 1):
				if cx < 0 or cx >= cw:
					continue
				if maxi(absi(cx - cx0), absi(cy - cy0)) != r:
					continue
				var has := false
				for rt in kinds:
					if chunk_cnt[rt][cy * cw + cx] > 0:
						has = true
						break
				if not has:
					continue
				for ty in range(cy * 8, mini(cy * 8 + 8, H)):
					for tx in range(cx * 8, mini(cx * 8 + 8, W)):
						var ti := ty * W + tx
						var rt2 := rtype[ti]
						if rt2 != 0 and ((1 << rt2) & mask) != 0 and ramt[ti] > 0 and comp[ti] == fcomp and float(bad_res.get(ti, 0.0)) <= time:
							var d := float((tx - from.x) * (tx - from.x) + (ty - from.y) * (ty - from.y))
							if d < bd and _exposed(tx, ty):
								bd = d
								best = Vector2i(tx, ty)
	return best

func _exposed(tx: int, ty: int) -> bool:
	## ¿Tiene alguna casilla vecina (ortogonal) transitable? Descarta árboles del interior del bosque.
	if tx > 0 and solid[ty * W + tx - 1] == 0:
		return true
	if tx < W - 1 and solid[ty * W + tx + 1] == 0:
		return true
	if ty > 0 and solid[(ty - 1) * W + tx] == 0:
		return true
	if ty < H - 1 and solid[(ty + 1) * W + tx] == 0:
		return true
	return false

func find_fish(from: Vector2i, maxd: int = 16, max_nodes: int = 1800) -> Vector2i:
	## Casilla de peces más cercana navegando por agua (BFS); si no hay cerca, búsqueda por fragmentos.
	bfs_stamp += 1
	bfs_calls += 1
	var q := PackedInt32Array()
	var start := clampi(from.y, 0, H - 1) * W + clampi(from.x, 0, W - 1)
	q.append(start)
	bfs_mark[start] = bfs_stamp
	bfs_dist[start] = 0
	var head := 0
	while head < q.size() and q.size() < max_nodes:
		var cur: int = q[head]
		head += 1
		var cx := cur % W
		var cy := cur / W
		var d: int = bfs_dist[cur]
		for dd in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
			var nx: int = cx + dd.x
			var ny: int = cy + dd.y
			if nx < 0 or ny < 0 or nx >= W or ny >= H:
				continue
			var ni := ny * W + nx
			if rtype[ni] == Defs.R_FISH and ramt[ni] > 0 and float(bad_res.get(ni, 0.0)) <= time:
				return Vector2i(nx, ny)
			if wsol[ni] == 0 and bfs_mark[ni] != bfs_stamp and d < maxd:
				bfs_mark[ni] = bfs_stamp
				bfs_dist[ni] = d + 1
				q.append(ni)
	return find_fish_far(from)

func find_fish_far(from: Vector2i) -> Vector2i:
	var fi := clampi(from.y, 0, H - 1) * W + clampi(from.x, 0, W - 1)
	var fwc: int = wcomp[fi]
	if fwc < 0:
		return Vector2i(-1, -1)
	var cx0 := from.x / 8
	var cy0 := from.y / 8
	var best := Vector2i(-1, -1)
	var bd := 1e12
	for r in range(0, cw):
		if best.x >= 0 and float(r - 1) * 8.0 > sqrt(bd):
			break
		for cy in range(cy0 - r, cy0 + r + 1):
			if cy < 0 or cy >= cw:
				continue
			for cx in range(cx0 - r, cx0 + r + 1):
				if cx < 0 or cx >= cw or maxi(absi(cx - cx0), absi(cy - cy0)) != r:
					continue
				if chunk_cnt[Defs.R_FISH][cy * cw + cx] <= 0:
					continue
				for ty in range(cy * 8, mini(cy * 8 + 8, H)):
					for tx in range(cx * 8, mini(cx * 8 + 8, W)):
						var ti := ty * W + tx
						if rtype[ti] == Defs.R_FISH and ramt[ti] > 0 and wcomp[ti] == fwc and float(bad_res.get(ti, 0.0)) <= time:
							var d := float((tx - from.x) * (tx - from.x) + (ty - from.y) * (ty - from.y))
							if d < bd and _fish_exposed(tx, ty):
								bd = d
								best = Vector2i(tx, ty)
	return best

func _fish_exposed(tx: int, ty: int) -> bool:
	if tx > 0 and wsol[ty * W + tx - 1] == 0:
		return true
	if tx < W - 1 and wsol[ty * W + tx + 1] == 0:
		return true
	if ty > 0 and wsol[(ty - 1) * W + tx] == 0:
		return true
	if ty < H - 1 and wsol[(ty + 1) * W + tx] == 0:
		return true
	return false

func _gmask(e: Ent) -> int:
	## Qué recursos puede recoger esta unidad con lo que lleva (los barcos de pesca, sólo peces).
	if e.naval:
		return 1 << Defs.R_FISH
	return res_mask_for(e.carry_kind)

func _ring_tiles(b: Ent) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k in range(-1, b.size + 1):
		out.append(b.tile + Vector2i(k, -1))
		out.append(b.tile + Vector2i(k, b.size))
	for k in range(0, b.size):
		out.append(b.tile + Vector2i(-1, k))
		out.append(b.tile + Vector2i(b.size, k))
	return out

func _return_goal(e: Ent, d: Ent) -> Vector2i:
	## Meta para entregar en `d`: los barcos atracan en una casilla de agua junto al edificio.
	if not e.naval:
		return d.tile + Vector2i(d.size / 2, d.size / 2)
	var wc := water_comp_at(tile_of(e.pos))
	var best := d.dock_tile
	var bd := 1e18
	for t in _ring_tiles(d):
		if is_free_water(t, wc):
			var dd := tile_center(t).distance_squared_to(e.pos)
			if dd < bd:
				bd = dd
				best = t
	return best

func nearest_dropoff(e: Ent) -> Ent:
	var best: Ent = null
	var bd := 1e12
	var wc := wcomp[tile_of(e.pos).y * W + tile_of(e.pos).x] if e.naval else -1
	for b in buildings:
		if b.alive and b.owner == e.owner and b.progress >= 1.0 and bool(b.def.get("drop", false)):
			var kinds: Array = b.def.get("drop_kinds", [])
			if not kinds.is_empty() and not kinds.has(e.carry_kind):
				continue
			if e.naval and (not bool(b.def.get("dock", false)) or b.dock_tile.x < 0 or water_comp_at(b.dock_tile) != wc):
				continue
			var d := b.dist_to(e.pos)
			if d < bd:
				bd = d
				best = b
	return best

# ------------------------------------------------------------------ órdenes

func _clear_orders(e: Ent) -> void:
	if e.target_tile.x >= 0:
		var idx := e.target_tile.y * W + e.target_tile.x
		if farm_slots.get(idx, 0) == e.id:
			farm_slots.erase(idx)
	e.state = S_IDLE
	e.path = []
	e.path_i = 0
	e.path_pending = false
	e.target_id = 0
	e.target_tile = Vector2i(-1, -1)
	e.amove = false
	e.auto_target = false
	e.fails = 0
	e.resume_id = 0
	e.unload_at = Vector2i(-1, -1)
	e.explore = false          # cualquier orden del jugador corta la exploración automática
	e.fspd = 0.0

func _own_units(pidx: int, ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var e: Ent = get_ent(id)
		if e != null and e.owner == pidx and not e.is_building:
			out.append(e)
	return out

func cmd_move(pidx: int, ids: Array, tile: Vector2i, attack_move: bool = false) -> void:
	var us := _own_units(pidx, ids)
	if us.is_empty():
		return
	tile = Vector2i(clampi(tile.x, 0, W - 1), clampi(tile.y, 0, H - 1))
	var land: Array = []
	var sea: Array = []
	for e: Ent in us:
		if e.naval:
			sea.append(e)
		else:
			land.append(e)
	if not land.is_empty():
		_move_group(land, tile, attack_move)
	if not sea.is_empty():
		_move_fleet(sea, tile, attack_move)

# ------------------------------------------------------------------ exploración automática

## Prepara la rejilla gruesa de exploración (una vez): por celda de 4×4 casillas, una casilla andable y otra de agua.
func ensure_explore_grid() -> void:
	if ex_w > 0:
		return
	ex_w = (W + EX_CELL - 1) / EX_CELL
	var n := ex_w * ex_w
	explore_known.resize(n)
	explore_known.fill(0)
	ex_rep.resize(n)
	ex_rep.fill(-1)
	ex_rep_w.resize(n)
	ex_rep_w.fill(-1)
	for cy in ex_w:
		for cx in ex_w:
			var mx := cx * EX_CELL + EX_CELL / 2
			var my := cy * EX_CELL + EX_CELL / 2
			var bl := 1 << 30
			var bw := 1 << 30
			for dy in EX_CELL:
				var y := cy * EX_CELL + dy
				if y >= H:
					break
				for dx in EX_CELL:
					var x := cx * EX_CELL + dx
					if x >= W:
						break
					var i := y * W + x
					var d := (x - mx) * (x - mx) + (y - my) * (y - my)
					if terrain[i] == Defs.T_WATER:
						if wsol[i] == 0 and d < bw:
							bw = d
							ex_rep_w[cy * ex_w + cx] = i
					elif terrain[i] != Defs.T_ROCK and solid[i] == 0 and d < bl:
						bl = d
						ex_rep[cy * ex_w + cx] = i

## Zonas peligrosas conocidas para `e`: torres y centros enemigos cuya casilla ya se ha visto (centro y radio en casillas²).
func _explore_danger_zones(e: Ent) -> Array:
	var out: Array = []
	for b in buildings:
		if not b.alive or not is_hostile(e.owner, b.owner) or not b.def.has("atk") or b.progress < 1.0:
			continue
		var c := b.tile + Vector2i(b.size / 2, b.size / 2)
		if explore_known[(c.y / EX_CELL) * ex_w + c.x / EX_CELL] < 6:
			continue                    # nunca se ha visto: no se sabe que está ahí
		var r := float(b.def["range"]) + 4.0
		out.append([c, r * r])
	return out

## Elige la celda sin explorar más cercana a la que se pueda llegar y evita zonas peligrosas. Falso si no queda ninguna.
func _explore_pick(e: Ent) -> bool:
	ensure_explore_grid()
	var t0 := tile_of(e.pos)
	var ti := t0.y * W + t0.x
	var my_comp: int = wcomp[ti] if e.naval else comp[ti]
	var reps := ex_rep_w if e.naval else ex_rep
	var zones := _explore_danger_zones(e)
	var avoid_hit: bool = time - e.danger_t < 90.0 and e.danger_pos.x >= 0.0
	var dp := tile_of(e.danger_pos) if avoid_hit else Vector2i(-1, -1)
	var best := -1
	var bs := 1e18
	for c in ex_w * ex_w:
		var kn: int = explore_known[c]
		if kn >= EX_DONE:
			continue
		var rep: int = reps[c]
		if rep < 0 or e.xp_bad.has(c):
			continue
		if (wcomp[rep] if e.naval else comp[rep]) != my_comp:
			continue
		var rx := rep % W
		var ry := rep / W
		if avoid_hit and (rx - dp.x) * (rx - dp.x) + (ry - dp.y) * (ry - dp.y) < 144:
			continue
		var unsafe := false
		for z in zones:
			var zc: Vector2i = z[0]
			if float((rx - zc.x) * (rx - zc.x) + (ry - zc.y) * (ry - zc.y)) < float(z[1]):
				unsafe = true
				break
		if unsafe:
			continue
		var sc := float((rx - t0.x) * (rx - t0.x) + (ry - t0.y) * (ry - t0.y)) + float(kn) * 3.0
		if sc < bs:
			bs = sc
			best = c
	if best < 0:
		return false
	e.xp_cell = best
	e.xp_t = 1.5
	var goal_i: int = reps[best]
	var goal := Vector2i(goal_i % W, goal_i / W)
	e.state = S_MOVE
	e.amove = false
	e.amove_goal = goal
	e.home = tile_center(goal)
	e.fails = 0
	e.ignore_id = 0
	_request_path(e, goal)
	return true

## Siguiente destino de un explorador; si ya no queda nada accesible por descubrir, vuelve a casa y avisa.
func _explore_next(e: Ent) -> void:
	if _explore_pick(e):
		return
	e.explore = false
	e.xp_cell = -1
	e.state = S_IDLE
	e.path = []
	var home := Vector2i(-1, -1)
	var bd := 1e18
	for b in buildings:
		if not (b.alive and b.owner == e.owner and b.progress >= 1.0):
			continue
		if (bool(b.def.get("dock", false)) if e.naval else b.type == "centro"):
			var d := b.center().distance_squared_to(e.pos)
			if d < bd:
				bd = d
				home = b.dock_tile if e.naval else _spawn_tile_near(b)
	if home.x >= 0:
		if e.naval:
			_move_fleet([e], home, false)
		else:
			_move_group([e], home, false)
	_ev({"t": "explore_done", "owner": e.owner, "pos": e.pos, "id": e.id})

## Orden «explorar» (activar) o «dejar de explorar». Sólo la obedecen las unidades de exploración (`scout`).
func cmd_explore(pidx: int, ids: Array, on: bool = true) -> int:
	var n := 0
	for e: Ent in _own_units(pidx, ids):
		if not bool(e.def.get("scout", false)) or e.stowed or not e.cargo.is_empty():
			continue
		if on:
			_clear_orders(e)
			e.xp_bad = []
			e.danger_t = -1000.0
			e.explore = true
			_explore_next(e)
			n += 1
		elif e.explore:
			_clear_orders(e)
			n += 1
	return OK if n > 0 else ERR_NOUNITS

func _move_group(us: Array, tile: Vector2i, attack_move: bool) -> void:
	var fm: int = players[(us[0] as Ent).owner].formation
	if fm != FM_FREE and us.size() >= 3 and not is_solid_tile(tile) and comp[tile.y * W + tile.x] >= 0:
		_move_formation(us, tile, attack_move, fm)
		return
	var center := tile_center(tile)
	us.sort_custom(func(a: Ent, b: Ent) -> bool:
		return a.pos.distance_squared_to(center) < b.pos.distance_squared_to(center))
	var spots: Array = []
	if is_solid_tile(tile):
		spots = [tile]
	else:
		spots = free_tiles_around(tile, us.size(), 9)
		if spots.is_empty():
			spots = [tile]
	for i in us.size():
		var e: Ent = us[i]
		_clear_orders(e)
		e.state = S_MOVE
		e.amove = attack_move
		e.amove_goal = tile
		e.home = center
		_request_path(e, spots[i % spots.size()])

func _move_fleet(us: Array, tile: Vector2i, attack_move: bool) -> void:
	## Los barcos van a la casilla de agua más cercana al punto pedido (si tocan tierra, a la orilla).
	var wc := water_comp_at(tile_of((us[0] as Ent).pos))
	var gt := nearest_water_tile(tile, wc, 8)
	if gt.x < 0:
		return
	var center := tile_center(gt)
	us.sort_custom(func(a: Ent, b: Ent) -> bool:
		return a.pos.distance_squared_to(center) < b.pos.distance_squared_to(center))
	var spots := free_water_around(gt, us.size(), 8, wc)
	if spots.is_empty():
		spots = [gt]
	for i in us.size():
		var e: Ent = us[i]
		_clear_orders(e)
		e.state = S_MOVE
		e.amove = attack_move
		e.amove_goal = gt
		e.home = center
		_request_path(e, spots[i % spots.size()])

func can_attack(a: Ent, t: Ent) -> bool:
	if float(a.def["atk"]) <= 0.0:
		return false
	if t.naval and not a.naval and float(a.def["range"]) <= 1.5:
		return false                      # a un barco sólo se le alcanza a distancia
	if bool(a.def.get("siege", false)) and not t.is_building:
		return false                      # los arietes sólo rompen edificios
	return true

func cmd_attack(pidx: int, ids: Array, target_id: int) -> int:
	## Devuelve cuántas unidades han recibido la orden.
	var t := get_ent(target_id)
	if t == null or not is_hostile(pidx, t.owner):
		return 0
	var n := 0
	for e in _own_units(pidx, ids):
		if not can_attack(e, t):
			continue
		_clear_orders(e)
		e.target_id = target_id
		e.state = S_ATTACK_GO
		e.auto_target = false
		e.repath_t = 0.0
		_request_path(e, _target_goal(t, e))
		n += 1
	return n

func _target_goal(t: Ent, a: Ent = null) -> Vector2i:
	if a != null and a.naval:
		if t.naval:
			return tile_of(t.pos)
		# a un blanco en tierra se le dispara desde el agua más cercana
		var c := t.tile + Vector2i(t.size / 2, t.size / 2) if t.is_building else tile_of(t.pos)
		var g := nearest_water_tile(c, water_comp_at(tile_of(a.pos)), 10)
		return g if g.x >= 0 else tile_of(a.pos)
	if t.is_building:
		return t.tile + Vector2i(t.size / 2, t.size / 2)
	return tile_of(t.pos)

func cmd_gather(pidx: int, ids: Array, tile: Vector2i) -> void:
	if not in_bounds(tile):
		return
	var idx := tile.y * W + tile.x
	var rt := rtype[idx]
	if rt == 0:
		return
	if rt == Defs.R_SAPLING:
		return
	if rt == Defs.R_FARM and rowner[idx] != pidx:
		return
	var kind: String = Defs.RES_INFO[rt]["kind"]
	for e in _own_units(pidx, ids):
		if rt == Defs.R_FISH:
			if bool(e.def.get("fisher", false)):
				_assign_gather(e, tile, kind)
		elif e.type == "aldeano":
			_assign_gather(e, tile, kind)

func _assign_gather(e: Ent, tile: Vector2i, kind: String) -> void:
	_clear_orders(e)
	if e.carry_kind != kind:
		e.carry_amt = 0.0
	e.carry_kind = kind
	e.target_tile = tile
	var idx := tile.y * W + tile.x
	if rtype[idx] == Defs.R_FARM:
		farm_slots[idx] = e.id
	e.state = S_GATHER_GO
	_request_path(e, tile)

func cmd_build(pidx: int, ids: Array, type: String, tile: Vector2i) -> int:
	var p: Player = players[pidx]
	var vs: Array = []
	for e in _own_units(pidx, ids):
		if e.type == "aldeano":
			vs.append(e)
	if vs.is_empty():
		return ERR_NOUNITS
	if type == "granja":
		if not Defs.can_afford(p.res, Defs.FARM_COST):
			return ERR_COST
		if not can_place_farm(tile):
			return ERR_PLACE
		Defs.pay(p.res, Defs.FARM_COST)
		var idx := tile.y * W + tile.x
		rtype[idx] = Defs.R_FARM
		chunk_cnt[Defs.R_FARM][((idx / W) / 8) * cw + (idx % W) / 8] += 1
		ramt[idx] = Defs.RES_INFO[Defs.R_FARM]["amount"]
		rowner[idx] = pidx
		_ev({"t": "placed", "pos": tile_center(tile), "owner": pidx, "farm": tile})
		_assign_gather(vs[0], tile, "food")
		for i in range(1, vs.size()):
			var other := find_resource(tile, res_mask_for("food"), pidx, vs[i].id)
			if other.x >= 0:
				_assign_gather(vs[i], other, "food")
		return OK
	if type == "arbol":
		return _plant(pidx, tile)
	if not Defs.BUILDINGS.has(type):
		return ERR_INVALID
	var d: Dictionary = Defs.BUILDINGS[type]
	if d.get("wall", false):
		return cmd_build_wall(pidx, ids, type, [tile])
	if p.age < int(d["age"]):
		return ERR_AGE
	if not Defs.can_afford(p.res, d["cost"]):
		return ERR_COST
	if d.get("mine", false) and mine_count(pidx) >= Defs.MINE_MAX:
		return ERR_LIMIT
	if not can_place(type, tile, pidx):
		return ERR_PLACE
	if not can_reach_building(tile_of(vs[0].pos), type, tile):
		return ERR_UNREACHABLE
	Defs.pay(p.res, d["cost"])
	var b := _spawn_building(type, pidx, tile, false)
	_nudge_units_from(b)
	_ev({"t": "placed", "pos": b.pos, "owner": pidx})
	for e in vs:
		_assign_build(e, b)
	return b.id

func cmd_build_wall(pidx: int, ids: Array, type: String, tiles: Array) -> int:
	## Construye un tramo de muralla (o una puerta). Devuelve el nº de piezas colocadas (>0) o un error (<0).
	var p: Player = players[pidx]
	var vs: Array = []
	for e in _own_units(pidx, ids):
		if e.type == "aldeano":
			vs.append(e)
	if vs.is_empty():
		return ERR_NOUNITS
	if not Defs.BUILDINGS.has(type) or not Defs.BUILDINGS[type].get("wall", false):
		return ERR_INVALID
	var d: Dictionary = Defs.BUILDINGS[type]
	if p.age < int(d["age"]):
		return ERR_AGE
	var built: Array[Ent] = []
	var cost_fail := false
	var reach_ok := false
	var reach_fail := false
	for t: Vector2i in tiles:
		if built.size() >= Defs.WALL_MAX_LINE or not can_place(type, t, pidx):
			continue
		if not Defs.can_afford(p.res, d["cost"]):
			cost_fail = true
			break
		if not reach_ok and not is_solid_tile(t):
			if not can_reach_building(tile_of(vs[0].pos), type, t):
				reach_fail = true
				continue
			reach_ok = true
		Defs.pay(p.res, d["cost"])
		var old := _own_wall_at(t.y * W + t.x, pidx) if type == "puerta" else null
		if old != null:
			_remove_silently(old)
		var b := _spawn_building(type, pidx, t, false)
		_nudge_units_from(b)
		built.append(b)
	if built.is_empty():
		if cost_fail:
			return ERR_COST
		return ERR_UNREACHABLE if reach_fail else ERR_PLACE
	_ev({"t": "placed", "pos": built[0].pos, "owner": pidx})
	for i in vs.size():
		var k := mini(built.size() - 1, int(float(i) / float(vs.size()) * float(built.size())))
		_assign_build(vs[i], built[k])
	return built.size()

func _remove_silently(w: Ent) -> void:
	## Retira un edificio sin contarlo como pérdida ni generar eventos (sustitución por puerta).
	w.alive = false
	dead.append(w)
	var idx := w.tile.y * W + w.tile.x
	occ[idx] = 0
	wall_tile[idx] = 0
	gate_tile[idx] = 0
	wall_count -= 1
	astar2.set_point_weight_scale(w.tile, 1.0)
	set_solid(w.tile, false)

func can_reach_building(from: Vector2i, type: String, tile: Vector2i) -> bool:
	## Comprueba (antes de colocar) que un aldeano en `from` podrá llegar junto a la huella.
	var size: int = Defs.BUILDINGS[type]["size"]
	var center := tile + Vector2i(size / 2, size / 2)
	if comp[from.y * W + from.x] < 0 or comp[from.y * W + from.x] != comp[center.y * W + center.x]:
		return false
	if from == center:
		return true
	return astar.get_id_path(from, center, false).size() > 0

func _assign_build(e: Ent, b: Ent) -> void:
	_clear_orders(e)
	e.target_id = b.id
	e.state = S_BUILD_GO
	_request_path(e, b.tile + Vector2i(b.size / 2, b.size / 2))

func cmd_help_build(pidx: int, ids: Array, bid: int) -> void:
	var b := get_ent(bid)
	if b == null or b.owner != pidx or not b.is_building or b.progress >= 1.0:
		return
	for e in _own_units(pidx, ids):
		if e.type == "aldeano":
			_assign_build(e, b)

func can_place_farm(tile: Vector2i) -> bool:
	if not in_bounds(tile):
		return false
	var idx := tile.y * W + tile.x
	return solid[idx] == 0 and rtype[idx] == 0 and occ[idx] == 0 and terrain[idx] != Defs.T_WATER

## ¿Se puede plantar un retoño aquí? Hierba libre, sin nadie encima y sin edificios pegados (así un árbol al crecer
## nunca tapa la puerta de un edificio ni encierra a los aldeanos).
func can_plant(tile: Vector2i) -> bool:
	if not in_bounds(tile):
		return false
	var idx := tile.y * W + tile.x
	if solid[idx] != 0 or rtype[idx] != 0 or occ[idx] != 0 or terrain[idx] != Defs.T_GRASS:
		return false
	for dd: Vector2i in DIR8:
		var q := tile + dd
		if in_bounds(q) and occ[q.y * W + q.x] != 0:
			return false
	return true

func sapling_count(pidx: int) -> int:
	var n := 0
	for i: int in saplings:
		if rowner[i] == pidx:
			n += 1
	return n

## Minas del jugador: depósitos creados que aún tienen oro más obras de mina sin terminar.
func mine_count(pidx: int) -> int:
	var n := 0
	for i: int in mines:
		if rowner[i] == pidx:
			n += 1
	for b in buildings:
		if b.alive and b.owner == pidx and b.progress < 1.0 and bool(b.def.get("mine", false)):
			n += 1
	return n

func _plant(pidx: int, tile: Vector2i) -> int:
	var p: Player = players[pidx]
	if not Defs.can_afford(p.res, Defs.PLANT_COST):
		return ERR_COST
	if sapling_count(pidx) >= Defs.PLANT_MAX:
		return ERR_LIMIT
	if not can_plant(tile):
		return ERR_PLACE
	if not query(tile_center(tile), 0.6 * Defs.TILE).is_empty():
		return ERR_PLACE
	Defs.pay(p.res, Defs.PLANT_COST)
	var idx := tile.y * W + tile.x
	rtype[idx] = Defs.R_SAPLING
	ramt[idx] = Defs.PLANT_GROW
	rowner[idx] = pidx
	chunk_cnt[Defs.R_SAPLING][((idx / W) / 8) * cw + (idx % W) / 8] += 1
	saplings.append(idx)
	_ev({"t": "planted", "pos": tile_center(tile), "owner": pidx, "tile": tile})
	return OK

func can_place(type: String, tile: Vector2i, pidx: int = -1) -> bool:
	if type == "granja":
		return can_place_farm(tile)
	if type == "arbol":
		return can_plant(tile)
	var size: int = Defs.BUILDINGS[type]["size"]
	for dy in size:
		for dx in size:
			var t := tile + Vector2i(dx, dy)
			if not in_bounds(t):
				return false
			var idx := t.y * W + t.x
			if solid[idx] == 1 or rtype[idx] != 0 or occ[idx] != 0 or terrain[idx] == Defs.T_WATER:
				if type == "puerta" and pidx >= 0 and _own_wall_at(idx, pidx) != null:
					continue
				return false
	if bool(Defs.BUILDINGS[type].get("dock", false)):
		return bool(dock_info(tile, size)["ok"])
	return true

func _own_wall_at(idx: int, pidx: int) -> Ent:
	## Muralla terminada propia en esa casilla (una puerta puede sustituirla).
	if wall_tile[idx] == 0 or gate_tile[idx] == 1:
		return null
	var w: Ent = ents.get(occ[idx])
	if w != null and w.alive and w.type == "muralla" and w.owner == pidx and w.progress >= 1.0:
		return w
	return null

func _nudge_units_from(b: Ent) -> void:
	var r := b.rect()
	for u in units:
		if u.alive and r.has_point(u.pos):
			var t := nearest_free_tile(tile_of(u.pos), 8)
			u.pos = tile_center(t)
			u.ppos = u.pos
			if u.goal.x >= 0 and u.state != S_IDLE:
				_request_path(u, u.goal)

func cmd_train(pidx: int, bid: int, utype: String) -> int:
	var b := get_ent(bid)
	var p: Player = players[pidx]
	if b == null or b.owner != pidx or not b.is_building or b.progress < 1.0:
		return ERR_INVALID
	if not Civs.can_train(b.type, p.civ, utype):
		return ERR_INVALID
	var ud: Dictionary = Defs.UNITS[utype]
	if p.age < int(ud["age"]):
		return ERR_AGE
	if b.queue.size() >= 5:
		return ERR_QUEUE
	if bool(ud.get("naval", false)) and b.dock_tile.x < 0:
		return ERR_INVALID
	var cost := unit_cost(pidx, utype)
	if not Defs.can_afford(p.res, cost):
		return ERR_COST
	Defs.pay(p.res, cost)
	b.queue.append(utype)
	return OK

func cmd_cancel_train(pidx: int, bid: int, index: int) -> void:
	var b := get_ent(bid)
	if b == null or b.owner != pidx or index < 0 or index >= b.queue.size():
		return
	var item: String = b.queue[index]
	var is_tech := Defs.is_tech_item(item)
	if is_tech:
		Defs.refund(players[pidx].res, Defs.TECHS[Defs.tech_of_item(item)]["cost"])
	else:
		Defs.refund(players[pidx].res, unit_cost(pidx, item))
	b.queue.remove_at(index)
	if index == 0 and b.producing:
		b.producing = false
		b.prod_tech = false
		if not is_tech:
			players[pidx].reserved -= 1

func cmd_set_rally(pidx: int, bid: int, tile: Vector2i) -> void:
	var b := get_ent(bid)
	if b != null and b.owner == pidx and b.is_building:
		b.rally = tile

## Cuántos tipos distintos de edificio militar tiene terminados el jugador (requisito de la Edad de los Castillos).
func military_kinds_done(pidx: int) -> int:
	var seen := {}
	for b in buildings:
		if b.alive and b.owner == pidx and b.progress >= 1.0 and Defs.MIL_BUILDINGS.has(b.type):
			seen[b.type] = true
	return seen.size()

func cmd_age_up(pidx: int) -> int:
	var p: Player = players[pidx]
	if p.age >= Defs.AGES.size() - 1 or p.aging:
		return ERR_INVALID
	var ad: Dictionary = Defs.AGES[p.age + 1]
	var acost := age_cost(pidx, p.age + 1)
	if not Defs.can_afford(p.res, acost):
		return ERR_COST
	if military_kinds_done(pidx) < int(ad.get("need_mil", 0)):
		return ERR_REQ
	var has_tc := false
	for b in buildings:
		if b.alive and b.owner == pidx and b.type == "centro" and b.progress >= 1.0:
			has_tc = true
			break
	if not has_tc:
		return ERR_INVALID
	Defs.pay(p.res, acost)
	p.aging = true
	p.age_left = age_time(pidx, p.age + 1)
	return OK

func cmd_delete(pidx: int, id: int) -> void:
	var e := get_ent(id)
	if e != null and e.owner == pidx:
		_kill(e, null)

func idle_villagers(pidx: int) -> Array:
	var out: Array = []
	for u in units:
		if u.alive and u.owner == pidx and (u.type == "aldeano" or bool(u.def.get("fisher", false))) and u.state == S_IDLE:
			out.append(u)
	return out

func army(pidx: int) -> Array:
	var out: Array = []
	for u in units:
		if u.alive and u.owner == pidx and u.is_military():
			out.append(u)
	return out

# ------------------------------------------------------------------ bucle principal

var dead: Array[Ent] = []

var profiling: bool = false
var prof: Dictionary = {}
var bfs_calls: int = 0
var bfs_nodes: int = 0

func _p(key: String, t0: int) -> void:
	prof[key] = int(prof.get(key, 0)) + (Time.get_ticks_usec() - t0)

func step() -> void:
	if game_over:
		return
	time += DT
	step_count += 1
	var t0 := 0
	if profiling:
		t0 = Time.get_ticks_usec()
	for u in units:
		u.ppos = u.pos
	if step_count % 2 == 0:
		_rebuild_buckets()
	for b in buildings:
		b.builders = b.bacc
		b.bacc = 0
	if profiling:
		_p("buckets", t0)
		t0 = Time.get_ticks_usec()
	_process_path_queue()
	if profiling:
		_p("paths", t0)
		t0 = Time.get_ticks_usec()
	if profiling:
		for u in units:
			if u.alive:
				var tu := Time.get_ticks_usec()
				var st0 := u.state
				_update_unit(u)
				var k := "u_%s_s%d" % [u.type, st0]
				prof[k] = int(prof.get(k, 0)) + (Time.get_ticks_usec() - tu)
				prof[k + "_n"] = int(prof.get(k + "_n", 0)) + 1
	else:
		for u in units:
			if u.alive:
				_update_unit(u)
	if profiling:
		_p("units", t0)
		t0 = Time.get_ticks_usec()
	for b in buildings:
		if b.alive:
			_update_building(b)
	_fauna_tick()
	_sapling_tick()
	_update_players()
	if not zones.is_empty():
		_zones_tick()
	if step_count % 10 == 0:
		_heal_tick()
	if profiling:
		_p("buildings", t0)
		t0 = Time.get_ticks_usec()
	for a in ais:
		a.update(DT)
	if profiling:
		_p("ai", t0)
		t0 = Time.get_ticks_usec()
	_cleanup()

func _cleanup() -> void:
	if not stowed_list.is_empty():
		for e in stowed_list:
			ents.erase(e.id)
		units.assign(units.filter(func(e: Ent) -> bool: return not e.stowed))
		stowed_list.clear()
	if dead.is_empty():
		return
	for e in dead:
		ents.erase(e.id)
	units.assign(units.filter(func(e: Ent) -> bool: return e.alive))
	buildings.assign(buildings.filter(func(e: Ent) -> bool: return e.alive))
	dead.clear()

## Una vez por segundo cada monje cura a los aliados heridos que tiene cerca (los que menos vida tienen primero).
func _heal_tick() -> void:
	for m in units:
		if not m.alive:
			continue
		var rg := float(m.def.get("regen", 0.0))
		if rg > 0.0 and m.hp < m.max_hp:
			m.hp = minf(m.max_hp, m.hp + rg)
		if float(m.def.get("heal", 0.0)) <= 0.0:
			continue
		var rate: float = float(m.def["heal"])
		if m.owner < civ_mods.size():
			rate *= float(civ_mods[m.owner]["heal"])
		var rpx: float = float(m.def["heal_r"]) * float(Defs.TILE)
		var hurt: Array[Ent] = []
		for o in query(m.pos, rpx):
			if o != m and o.alive and not o.is_building and not o.naval and o.hp < o.max_hp - 0.5 and (o.owner == m.owner or not hostile[m.owner][o.owner]):
				hurt.append(o)
		if hurt.is_empty():
			continue
		hurt.sort_custom(func(a: Ent, b: Ent) -> bool: return a.hp / a.max_hp < b.hp / b.max_hp)
		var n := mini(hurt.size(), int(m.def.get("heal_n", 3)))
		for i in n:
			var o := hurt[i]
			o.hp = minf(o.max_hp, o.hp + rate)
			_ev({"t": "heal", "pos": o.pos, "owner": m.owner})

func _update_players() -> void:
	if step_count % 100 == 0:
		_market_drift()
	if step_count % 10 == 5:
		for p in players:
			if p.bell and p.alive:
				_bell_tick(p.idx)
	for p in players:
		if p.abil_on and time >= p.abil_until:
			_end_buff(p)
		if p.aging:
			p.age_left -= DT
			if p.age_left <= 0.0:
				p.aging = false
				p.age += 1
				var m: float = Defs.AGE_STAT_MULT[p.age]
				var prev: float = Defs.AGE_STAT_MULT[p.age - 1]
				var ratio: float = m / prev
				for u in units:
					if u.alive and u.owner == p.idx:
						u.max_hp *= ratio
						u.hp *= ratio
						for c: Ent in u.cargo:
							c.max_hp *= ratio
							c.hp *= ratio
				for bb in buildings:
					for c2: Ent in bb.cargo:
						if c2.owner == p.idx:
							c2.max_hp *= ratio
							c2.hp *= ratio
				_ev({"t": "age", "owner": p.idx, "age": p.age})

# ------------------------------------------------------------------ guarnición, rebato, posturas y formaciones

func garrison_cap(b: Ent) -> int:
	return int(b.def.get("garrison", 0))

## ¿Se puede refugiar gente en este edificio (propio, terminado y con plazas)?
func can_garrison_in(b: Ent, pidx: int) -> bool:
	return b != null and b.alive and b.is_building and b.owner == pidx and b.progress >= 1.0 and garrison_cap(b) > 0

## Plazas libres de cada edificio con guarnición del jugador ({id: plazas}), descontando a quienes ya van de camino.
func garrison_rooms(pidx: int) -> Dictionary:
	var rooms := {}
	for b in buildings:
		if can_garrison_in(b, pidx):
			rooms[b.id] = garrison_cap(b) - b.cargo.size()
	for u in units:
		if u.alive and u.owner == pidx and u.state == S_GARRISON_GO and rooms.has(u.target_id):
			rooms[u.target_id] = int(rooms[u.target_id]) - 1
	return rooms

func _nearest_garrison(e: Ent, rooms: Dictionary, max_tiles: float) -> Ent:
	var best: Ent = null
	var bd := pow(max_tiles * Defs.TILE, 2.0)
	for b in buildings:
		if rooms.has(b.id) and int(rooms[b.id]) > 0:
			var d := b.center().distance_squared_to(e.pos)
			if d < bd:
				bd = d
				best = b
	return best

func _send_garrison(e: Ent, b: Ent, auto: bool) -> void:
	var was_work := e.state == S_GATHER_GO or e.state == S_GATHER or e.state == S_RETURN
	var wt := e.target_tile if was_work else Vector2i(-1, -1)
	_clear_orders(e)
	e.gar_tile = wt
	e.gar_auto = auto
	e.state = S_GARRISON_GO
	e.target_id = b.id
	e.fails = 0
	e.repath_t = 0.0
	_request_path(e, b.tile + Vector2i(b.size / 2, b.size / 2))

## Las unidades van al edificio y se refugian dentro (no pueden ser atacadas, se curan y las que disparan añaden flechas).
func cmd_garrison(pidx: int, ids: Array, bid: int) -> int:
	var b := get_ent(bid)
	if not can_garrison_in(b, pidx):
		return ERR_NOGAR
	var room: int = int(garrison_rooms(pidx).get(bid, 0))
	if room <= 0:
		return ERR_FULL
	var n := 0
	for e in _own_units(pidx, ids):
		if e.naval or e.stowed or n >= room or bool(e.def.get("siege", false)):
			continue
		_send_garrison(e, b, false)
		n += 1
	return OK if n > 0 else ERR_NOUNITS

func cmd_ungarrison(pidx: int, bid: int) -> int:
	var b := get_ent(bid)
	if not can_garrison_in(b, pidx):
		return ERR_NOGAR
	return OK if _garrison_release(b, 0) > 0 else ERR_NOUNITS

func _u_garrison_go(e: Ent, step_px: float) -> void:
	var b := get_ent(e.target_id)
	if not can_garrison_in(b, e.owner) or b.cargo.size() >= garrison_cap(b):
		var wt := e.gar_tile
		_clear_orders(e)
		e.gar_tile = wt
		_resume_work(e)
		return
	if b.dist_to(e.pos) <= Defs.TILE * 1.4:
		_garrison_enter(e, b)
		return
	var r := _follow(e, step_px)
	if r != 0:
		e.fails += 1
		if e.fails > 4:
			var wt2 := e.gar_tile
			_clear_orders(e)
			e.gar_tile = wt2
			_resume_work(e)
		elif not e.path_pending:
			_request_path(e, b.tile + Vector2i(b.size / 2, b.size / 2))

func _garrison_enter(e: Ent, b: Ent) -> void:
	var wt := e.gar_tile
	var auto := e.gar_auto
	_clear_orders(e)
	e.gar_tile = wt
	e.gar_auto = auto
	if e.carry_amt >= 1.0 and e.carry_kind != "" and bool(b.def.get("drop", false)):
		# el Centro recoge lo que lleva el aldeano
		var p: Player = players[e.owner]
		var n := int(e.carry_amt)
		p.res[e.carry_kind] = int(p.res.get(e.carry_kind, 0)) + n
		p.gathered[e.carry_kind] = int(p.gathered.get(e.carry_kind, 0)) + n
		e.carry_amt = 0.0
	e.stowed = true
	e.in_gar = b.id
	e.pos = b.center()
	e.ppos = e.pos
	b.cargo.append(e)
	stowed_list.append(e)
	_ev({"t": "garrison", "pos": b.center(), "owner": e.owner})

## Saca refugiados de `b` y los deja a pie junto al edificio. mode: 0 todos · 1 sólo aldeanos · 2 sólo los que entraron huyendo.
func _garrison_release(b: Ent, mode: int) -> int:
	var out: Array[Ent] = []
	for c: Ent in b.cargo:
		if mode == 0 or (mode == 1 and c.type == "aldeano") or (mode == 2 and c.gar_auto):
			out.append(c)
	if out.is_empty():
		return 0
	var center := b.tile + Vector2i(b.size / 2, b.size / 2)
	var spots := free_tiles_around(center, out.size() + 6, b.size + 5)
	var n := 0
	for u in out:
		if n >= spots.size():
			break
		b.cargo.erase(u)
		u.stowed = false
		u.in_gar = 0
		u.pos = tile_center(spots[n])
		u.ppos = u.pos
		n += 1
		ents[u.id] = u
		units.append(u)
		_clear_orders(u)
		u.gar_auto = false
		if u.type == "aldeano":
			_resume_work(u)
		else:
			u.gar_tile = Vector2i(-1, -1)
			if b.rally.x >= 0:
				cmd_move(u.owner, [u.id], b.rally)
	if n > 0:
		_ev({"t": "ungarrison", "pos": b.center(), "owner": b.owner, "n": n})
	return n

## Un aldeano que sale del refugio vuelve a su trabajo (al recurso que dejó, o a uno cercano del mismo tipo).
func _resume_work(u: Ent) -> void:
	var t := u.gar_tile
	u.gar_tile = Vector2i(-1, -1)
	if t.x >= 0:
		var idx := t.y * W + t.x
		if _res_usable(idx, _gmask(u), u.owner, u.id):
			u.target_tile = t
			if rtype[idx] == Defs.R_FARM:
				farm_slots[idx] = u.id
			u.state = S_GATHER_GO
			u.fails = 0
			_request_path(u, t)
			return
	if u.carry_kind != "":
		_find_new_resource(u)

## Cada segundo, dentro de un edificio con guarnición: los refugiados se curan, y si no hay enemigos cerca y no suena el
## rebato salen solos los que entraron huyendo.
func _gar_tick(b: Ent) -> void:
	for c: Ent in b.cargo:
		if c.hp < c.max_hp:
			c.hp = minf(c.max_hp, c.hp + c.max_hp * GAR_HEAL)
	if players[b.owner].bell:
		b.gar_t = 0.0
		return
	var danger := false
	var r := (float(b.def.get("range", 6.0)) + 3.0) * Defs.TILE
	for o in query(b.center(), r):
		if o.alive and not o.is_building and hostile[b.owner][o.owner]:
			danger = true
			break
	if danger:
		b.gar_t = 0.0
	else:
		b.gar_t += 1.0
		if b.gar_t >= 5.0:
			_garrison_release(b, 2)

## Rebato: todos los aldeanos corren a refugiarse (los más cercanos a cada edificio, mientras haya plazas).
func cmd_bell(pidx: int, on: bool) -> int:
	var p: Player = players[pidx]
	if p.bell == on:
		return OK
	if on and garrison_rooms(pidx).is_empty():
		return ERR_NOGAR
	p.bell = on
	if on:
		_bell_tick(pidx)
	else:
		for b in buildings:
			if b.alive and b.owner == pidx and not b.cargo.is_empty():
				_garrison_release(b, 1)
		for u in units:
			if u.alive and u.owner == pidx and u.state == S_GARRISON_GO:
				var wt := u.gar_tile
				_clear_orders(u)
				u.gar_tile = wt
				_resume_work(u)
	_ev({"t": "bell", "owner": pidx, "on": on})
	return OK

func _bell_tick(pidx: int) -> void:
	var rooms := garrison_rooms(pidx)
	if rooms.is_empty():
		return
	for u in units:
		if not u.alive or u.owner != pidx or u.type != "aldeano" or u.state == S_GARRISON_GO or u.stowed:
			continue
		var b := _nearest_garrison(u, rooms, BELL_R)
		if b == null:
			continue
		rooms[b.id] = int(rooms[b.id]) - 1
		_send_garrison(u, b, true)

## Un aldeano herido por un soldado enemigo corre al refugio más cercano si lo tiene a menos de FLEE_R casillas.
func _flee(t: Ent) -> void:
	if t.naval or t.stowed or time - t.danger_t < 3.0:
		return
	t.danger_t = time
	var b := _nearest_garrison(t, garrison_rooms(t.owner), FLEE_R)
	if b != null:
		_send_garrison(t, b, true)
		_ev({"t": "flee", "owner": t.owner})

# --- posturas

## Radio al que un soldado parado (o que acaba de terminar con su objetivo) busca enemigos según su postura.
func _scan_radius(e: Ent) -> float:
	match e.stance:
		ST_DEF:
			return minf(_los_px(e), maxf(eff_range(e) + 2.5, 5.0) * Defs.TILE)
		ST_HOLD:
			return eff_range(e) * Defs.TILE + e.radius + 6.0
	return _los_px(e)

## Hasta dónde se aleja persiguiendo a un objetivo que no ha elegido el jugador antes de volver a su sitio.
func _leash_px(e: Ent) -> float:
	if e.stance == ST_DEF:
		return _scan_radius(e) + 2.0 * Defs.TILE
	return _los_px(e) + 6.0 * Defs.TILE

func cmd_stance(pidx: int, ids: Array, st: int) -> int:
	if st < ST_AGGR or st > ST_PASSIVE:
		return ERR_INVALID
	var n := 0
	for e in _own_units(pidx, ids):
		if not e.is_military():
			continue
		e.stance = st
		n += 1
		if st >= ST_HOLD and e.auto_target and (e.state == S_ATTACK_GO or e.state == S_ATTACK):
			_clear_orders(e)         # deja de pelear lo que nadie le mandó
	return OK if n > 0 else ERR_NOUNITS

# --- formaciones

func cmd_formation(pidx: int, f: int) -> int:
	if f < FM_FREE or f > FM_COLUMN:
		return ERR_INVALID
	players[pidx].formation = f
	return OK

func _formation_spot(st: Vector2i, taken: Dictionary, goal: Vector2i) -> Vector2i:
	var gc := comp[goal.y * W + goal.x]
	for r in range(0, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := st + Vector2i(dx, dy)
				if in_bounds(q) and not is_solid_tile(q) and not taken.has(q) and comp[q.y * W + q.x] == gc:
					return q
	return goal

## Marcha en formación: los de cuerpo a cuerpo van delante y arqueros, asedio y monjes detrás, en filas perpendiculares al
## rumbo, y todo el grupo avanza al paso del más lento para llegar junto.
func _move_formation(us: Array, tile: Vector2i, attack_move: bool, fm: int) -> void:
	var center := tile_center(tile)
	var n := us.size()
	var c0 := Vector2.ZERO
	var slow := 99.0
	for e: Ent in us:
		c0 += e.pos
		slow = minf(slow, float(e.def["speed"]) * e.sm)
	c0 /= float(n)
	var dir := center - c0
	var far := dir.length() > 6.0 * Defs.TILE
	dir = dir.normalized() if dir.length() > Defs.TILE else Vector2.DOWN
	var perp := Vector2(-dir.y, dir.x)
	var front: Array = []
	var back: Array = []
	for e: Ent in us:
		if e.is_military() and float(e.def["range"]) <= 1.5 and not bool(e.def.get("siege", false)):
			front.append(e)
		else:
			back.append(e)
	var cols := clampi(int(ceil(sqrt(float(n) * 2.0))), 3, 12) if fm == FM_LINE else 3
	var taken := {}
	var row := 0
	for grp: Array in [front, back]:
		if grp.is_empty():
			continue
		# los que ya van más adelantados ocupan las filas de delante
		grp.sort_custom(func(a: Ent, b: Ent) -> bool: return (a.pos - c0).dot(dir) > (b.pos - c0).dot(dir))
		var rows_n := int(ceil(float(grp.size()) / float(cols)))
		for r in rows_n:
			var chunk: Array = grp.slice(r * cols, mini(grp.size(), (r + 1) * cols))
			chunk.sort_custom(func(a: Ent, b: Ent) -> bool: return (a.pos - c0).dot(perp) < (b.pos - c0).dot(perp))
			for k in chunk.size():
				var lateral := float(k) - (float(chunk.size()) - 1.0) * 0.5
				var pt := Vector2(tile) + perp * lateral - dir * float(row)
				var spot := _formation_spot(Vector2i(roundi(pt.x), roundi(pt.y)), taken, tile)
				taken[spot] = true
				var e: Ent = chunk[k]
				_clear_orders(e)
				e.state = S_MOVE
				e.amove = attack_move
				e.amove_goal = tile
				e.home = center
				e.fspd = slow if far else 0.0
				_request_path(e, spot)
			row += 1

# ------------------------------------------------------------------ caza, mercado y mejoras

const DIR8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]

## Rehace las listas de retoños y de minas creadas desde el mapa (al cargar una partida).
func _init_plants() -> void:
	saplings.clear()
	mines.clear()
	for i in W * H:
		if rtype[i] == Defs.R_SAPLING:
			saplings.append(i)
		elif rtype[i] == Defs.R_GOLD and rowner[i] != 255:
			mines.append(i)

## Cada retoño envejece un paso por segundo de juego (se reparte entre 5 pasos) y al llegar a 0 se vuelve árbol, salvo
## que haya alguien encima: entonces espera 3 s y vuelve a intentarlo.
func _sapling_tick() -> void:
	var n := saplings.size()
	if n == 0:
		return
	var grown: Array = []
	var k := step_count % 5
	while k < n:
		var idx: int = saplings[k]
		k += 5
		ramt[idx] -= 5
		if ramt[idx] <= 0:
			grown.append(idx)
	for idx: int in grown:
		_sapling_grow(idx)

func _sapling_grow(idx: int) -> void:
	var t := Vector2i(idx % W, idx / W)
	for o in query(tile_center(t), 0.7 * Defs.TILE):
		if o.alive and not o.is_building:
			ramt[idx] = 30
			return
	saplings.erase(idx)
	var ci := ((idx / W) / 8) * cw + (idx % W) / 8
	chunk_cnt[Defs.R_SAPLING][ci] -= 1
	chunk_cnt[Defs.R_TREE][ci] += 1
	rtype[idx] = Defs.R_TREE
	ramt[idx] = int(Defs.RES_INFO[Defs.R_TREE]["amount"])
	rowner[idx] = 255
	set_solid(t, true)
	_ev({"t": "grown", "tile": t})

## Registra los animales que trae el mapa (cada uno recuerda su casilla de origen para no alejarse demasiado de ella).
func _init_fauna() -> void:
	fauna.clear()
	fauna_at.clear()
	for i in W * H:
		if Defs.is_animal(rtype[i]):
			_fauna_add(i)

func _fauna_add(i: int) -> void:
	var a := {"i": i, "home": i, "fx": tile_center(Vector2i(i % W, i / W)), "t0": -100.0, "t1": -100.0,
		"nx": rng.randf_range(3.0, 12.0), "face": 1 if rng.randf() < 0.5 else -1}
	fauna.append(a)
	fauna_at[i] = a

func _fauna_remove(i: int) -> void:
	var a: Variant = fauna_at.get(i)
	if a != null:
		fauna.erase(a)
		fauna_at.erase(i)

## Cada animal da un paseo corto de vez en cuando (a una casilla contigua, sin alejarse más de 6 de su origen), salvo
## que haya alguien cerca: así se puede cazar sin que se escape y las manadas no deambulan por todo el mapa.
func _fauna_tick() -> void:
	var n := fauna.size()
	var k := step_count % 5
	while k < n:
		var a: Dictionary = fauna[k]
		k += 5
		if time < float(a["nx"]):
			continue
		a["nx"] = time + rng.randf_range(6.0, 16.0)
		var idx: int = a["i"]
		var t := Vector2i(idx % W, idx / W)
		if not query(tile_center(t), 5.0 * Defs.TILE).is_empty():
			a["nx"] = time + 3.0
			continue
		var hi: int = a["home"]
		for tries in 3:
			var dd: Vector2i = DIR8[rng.randi() % 8]
			var q := t + dd
			if not in_bounds(q):
				continue
			var qi := q.y * W + q.x
			if rtype[qi] != 0 or solid[qi] == 1 or occ[qi] != 0 or terrain[qi] != Defs.T_GRASS:
				continue
			if Vector2(q - Vector2i(hi % W, hi / W)).length() > 6.0:
				continue
			_fauna_move(a, idx, qi, dd)
			break

func _fauna_move(a: Dictionary, from: int, to: int, dd: Vector2i) -> void:
	var rt := rtype[from]
	var ci_from := ((from / W) / 8) * cw + (from % W) / 8
	var ci_to := ((to / W) / 8) * cw + (to % W) / 8
	rtype[to] = rt
	ramt[to] = ramt[from]
	rtype[from] = 0
	ramt[from] = 0
	if ci_from != ci_to:
		chunk_cnt[rt][ci_from] -= 1
		chunk_cnt[rt][ci_to] += 1
	fauna_at.erase(from)
	fauna_at[to] = a
	a["i"] = to
	a["fx"] = tile_center(Vector2i(from % W, from / W))
	a["t0"] = time
	a["t1"] = time + FAUNA_WALK
	if dd.x != 0:
		a["face"] = dd.x

# --- mercado

func has_market(pidx: int) -> bool:
	for b in buildings:
		if b.alive and b.owner == pidx and b.progress >= 1.0 and bool(b.def.get("market", false)):
			return true
	return false

func market_price(pidx: int, kind: String) -> int:
	return int(players[pidx].mkt.get(kind, 100))

## Oro que cuesta comprar MKT_LOT unidades de `kind`.
func market_buy_cost(pidx: int, kind: String) -> int:
	return int(ceil(float(market_price(pidx, kind)) * (1.0 + MKT_TAX)))

## Oro que se recibe al vender MKT_LOT unidades de `kind`.
func market_sell_gain(pidx: int, kind: String) -> int:
	return int(floor(float(market_price(pidx, kind)) * (1.0 - MKT_TAX)))

## Compra (`buy`) o vende MKT_LOT unidades de comida, madera o piedra a cambio de oro. El precio sube con cada compra y
## baja con cada venta (y con el tiempo vuelve poco a poco a 100).
func cmd_trade(pidx: int, kind: String, buy: bool) -> int:
	var p: Player = players[pidx]
	if not p.alive or not p.mkt.has(kind):
		return ERR_INVALID
	if not has_market(pidx):
		return ERR_NOMARKET
	var price := int(p.mkt[kind])
	if buy:
		var cost := market_buy_cost(pidx, kind)
		if int(p.res.get("gold", 0)) < cost:
			return ERR_COST
		p.res["gold"] = int(p.res["gold"]) - cost
		p.res[kind] = int(p.res.get(kind, 0)) + MKT_LOT
		p.mkt[kind] = mini(300, price + MKT_STEP)
	else:
		if int(p.res.get(kind, 0)) < MKT_LOT:
			return ERR_COST
		p.res[kind] = int(p.res[kind]) - MKT_LOT
		p.res["gold"] = int(p.res.get("gold", 0)) + market_sell_gain(pidx, kind)
		p.mkt[kind] = maxi(20, price - MKT_STEP)
	_ev({"t": "trade", "owner": pidx, "buy": buy})
	return OK

## Con el tiempo los precios del mercado vuelven hacia 100 (un punto cada 10 s).
func _market_drift() -> void:
	for p in players:
		for k: String in p.mkt:
			var v := int(p.mkt[k])
			if v < 100:
				p.mkt[k] = v + 1
			elif v > 100:
				p.mkt[k] = v - 1

# --- mejoras

func tech_queued(pidx: int, tid: String) -> bool:
	var item := "tech:" + tid
	for b in buildings:
		if b.alive and b.owner == pidx and b.queue.has(item):
			return true
	return false

## OK si el jugador puede ponerse a investigar `tid` (sin contar coste ni cola); si no, el motivo.
func tech_status(pidx: int, tid: String) -> int:
	var t: Dictionary = Defs.TECHS.get(tid, {})
	if t.is_empty():
		return ERR_INVALID
	var p: Player = players[pidx]
	if p.techs.has(tid) or tech_queued(pidx, tid):
		return ERR_DONE
	if p.age < int(t["age"]):
		return ERR_AGE
	var req := String(t.get("req", ""))
	if req != "" and not p.techs.has(req):
		return ERR_REQ
	return OK

func tech_time(item: String) -> float:
	return float(Defs.TECHS[Defs.tech_of_item(item)]["time"])

func cmd_research(pidx: int, bid: int, tid: String) -> int:
	var b := get_ent(bid)
	if b == null or b.owner != pidx or not b.is_building or b.progress < 1.0:
		return ERR_INVALID
	var t: Dictionary = Defs.TECHS.get(tid, {})
	if t.is_empty() or String(t["b"]) != b.type:
		return ERR_INVALID
	var r := tech_status(pidx, tid)
	if r != OK:
		return r
	if b.queue.size() >= 5:
		return ERR_QUEUE
	var p: Player = players[pidx]
	if not Defs.can_afford(p.res, t["cost"]):
		return ERR_COST
	Defs.pay(p.res, t["cost"])
	b.queue.append("tech:" + tid)
	return OK

func _finish_tech(b: Ent) -> void:
	var item: String = b.queue.pop_front()
	b.producing = false
	b.prod_tech = false
	var tid := Defs.tech_of_item(item)
	var p: Player = players[b.owner]
	p.techs[tid] = true
	var old_hp: Dictionary = (up_mods[b.owner]["hp"] as Dictionary).duplicate()
	_recalc_ups(b.owner)
	var new_hp: Dictionary = up_mods[b.owner]["hp"]
	if new_hp != old_hp:
		# la vida extra también llega a quien ya existe (incluidos los refugiados y los embarcados)
		var every: Array[Ent] = []
		for u in units:
			every.append(u)
			every.append_array(u.cargo)
		for bb in buildings:
			every.append_array(bb.cargo)
		for u in every:
			if u.alive and u.owner == b.owner:
				var ratio := float(new_hp.get(u.type, 1.0)) / float(old_hp.get(u.type, 1.0))
				if absf(ratio - 1.0) > 0.0001:
					u.max_hp *= ratio
					u.hp *= ratio
	_ev({"t": "tech", "pos": b.center(), "owner": b.owner, "id": tid})

# ------------------------------------------------------------------ habilidad de civilización

func _end_buff(p: Player) -> void:
	p.abil_on = false
	p.b_atk = 1.0
	p.b_spd = 1.0
	p.b_def = 1.0
	p.b_rate = 1.0
	p.b_types = {}
	p.b_loot = false
	_ev({"t": "abil_end", "owner": p.idx})

## Daño de las zonas de fuego: cada medio segundo, a todo lo hostil que pisa la zona (los edificios sufren la mitad).
func _zones_tick() -> void:
	var tick := step_count % 5 == 0
	var i := 0
	while i < zones.size():
		var z: Dictionary = zones[i]
		if time >= float(z["until"]):
			zones.remove_at(i)
			continue
		if tick:
			var dmg := float(z["dps"]) * 0.5
			var ow: int = int(z["owner"])
			for o in query(z["p"], float(z["r"])):
				if o.alive and o.owner != ow and hostile[ow][o.owner] and not o.naval:
					_damage(o, dmg * (0.5 if o.is_building else 1.0), null, true)
		i += 1

func _town_center(pidx: int) -> Ent:
	for b in buildings:
		if b.alive and b.owner == pidx and b.type == "centro" and b.progress >= 1.0:
			return b
	return null

## Estado de la habilidad para la interfaz: {"has", "age_ok", "ready", "cd_left", "active", "act_left", "cd_total"}.
func ability_state(pidx: int) -> Dictionary:
	var p: Player = players[pidx]
	var ab := Civs.ability_of(p.civ)
	if ab.is_empty():
		return {"has": false}
	var left := maxf(0.0, p.abil_ready - time)
	return {"has": true, "age_ok": p.age >= int(ab.get("age", 1)), "ready": left <= 0.0, "cd_left": left,
		"cd_total": float(ab["cd"]), "active": p.abil_on, "act_left": maxf(0.0, p.abil_until - time), "kind": String(ab["kind"])}

## Dispara la habilidad de la civilización. `tile` sólo hace falta si apunta (fuego).
func cmd_ability(pidx: int, tile: Vector2i = Vector2i(-1, -1)) -> int:
	var p: Player = players[pidx]
	if not p.alive or not Civs.valid(p.civ):
		return ERR_INVALID
	var ab: Dictionary = Civs.ability_of(p.civ)
	if p.age < int(ab.get("age", 1)):
		return ERR_AGE
	if time < p.abil_ready:
		return ERR_COOLDOWN
	var kind: String = ab["kind"]
	var tc := _town_center(pidx)
	var at: Vector2 = tc.center() if tc != null else tile_center(p.start_tile)
	match kind:
		"buff", "reveal":
			p.b_atk = float(ab.get("atk", 1.0))
			p.b_spd = float(ab.get("spd", 1.0))
			p.b_def = float(ab.get("def", 1.0))
			p.b_rate = float(ab.get("rate", 1.0))
			p.b_types = Civs.buff_types(ab)
			p.b_loot = bool(ab.get("loot", false))
			p.b_loot_gold = int(ab.get("loot_gold", 0))
			p.b_loot_food = int(ab.get("loot_food", 0))
			p.abil_on = true
			p.abil_until = time + float(ab["dur"])
			if kind == "reveal":
				p.reveal_until = time + float(ab["dur"])
		"lump":
			var vills := 0
			for u in units:
				if u.alive and u.owner == pidx and u.type == "aldeano":
					vills += 1
			var n := clampi(vills * int(ab["per_vill"]), int(ab["min"]), int(ab["max"]))
			for k: String in ab["kinds"]:
				p.res[k] = int(p.res.get(k, 0)) + n
			_ev({"t": "abil_text", "pos": at, "owner": pidx, "n": n})
		"fire":
			if tile.x < 0 or not in_bounds(tile):
				return ERR_NOTARGET
			zones.append({"p": tile_center(tile), "r": float(ab["radius"]) * Defs.TILE, "dps": float(ab["dps"]), "until": time + float(ab["dur"]), "owner": pidx})
			at = tile_center(tile)
		"spawn":
			var room := p.pop_cap - p.pop - p.reserved
			var n2 := mini(int(ab["n"]), room)
			if n2 <= 0:
				return ERR_POP
			var base := tile_of(at)
			for ft in free_tiles_around(base + Vector2i(0, 2), n2, 8):
				_spawn_unit(String(ab["unit"]), pidx, ft)
	p.abil_ready = time + float(ab["cd"])
	p.abil_uses += 1
	_ev({"t": "abil", "owner": pidx, "civ": p.civ, "kind": kind, "pos": at})
	return OK

# ------------------------------------------------------------------ unidades

func _update_unit(e: Ent) -> void:
	e.cd = maxf(0.0, e.cd - DT)
	e.repath_t = maxf(0.0, e.repath_t - DT)
	var step_px: float = float(e.def["speed"]) * Defs.TILE * DT * e.sm
	var pl: Player = players[e.owner]
	if pl.abil_on and pl.b_spd != 1.0 and pl.b_types.has(e.type):
		step_px *= pl.b_spd
	if e.fspd > 0.0 and e.state == S_MOVE:
		step_px = minf(step_px, e.fspd * Defs.TILE * DT)      # marcha en formación: al paso del más lento
	match e.state:
		S_IDLE:
			_u_idle(e)
		S_MOVE:
			_u_move(e, step_px)
		S_GATHER_GO:
			_u_gather_go(e, step_px)
		S_GATHER:
			_u_gather(e)
		S_RETURN:
			_u_return(e, step_px)
		S_BUILD_GO:
			_u_build_go(e, step_px)
		S_BUILD:
			_u_build(e)
		S_ATTACK_GO:
			_u_attack_go(e, step_px)
		S_ATTACK:
			_u_attack(e)
		S_BOARD_GO:
			_u_board_go(e, step_px)
		S_GARRISON_GO:
			_u_garrison_go(e, step_px)

func _los_px(e: Ent) -> float:
	return (float(e.def["los"]) + float(e.lb)) * Defs.TILE

func _engage(e: Ent, t: Ent, auto: bool) -> void:
	if e.state == S_IDLE:
		e.home = e.pos
	e.target_id = t.id
	e.auto_target = auto
	e.fspd = 0.0
	e.state = S_ATTACK_GO
	e.repath_t = 0.0
	e.path = []
	e.path_pending = false
	e.fails = 0

func _u_idle(e: Ent) -> void:
	if e.explore:
		_explore_next(e)
		return
	if float(e.def.get("heal", 0.0)) > 0.0:
		e.scan_t -= DT
		if e.scan_t <= 0.0:
			e.scan_t = 1.0
			_healer_seek(e)
		return
	if not e.is_military() or e.stance == ST_PASSIVE:
		return
	e.scan_t -= DT
	if e.scan_t <= 0.0:
		e.scan_t = 0.5
		var t := scan_enemy(e, _scan_radius(e))
		if t != null and e.stance == ST_HOLD and not _in_range(e, t):
			t = null                    # mantener posición: sólo dispara a lo que tiene a tiro
		if t != null:
			_engage(e, t, true)

## Un monje ocioso se acerca al aliado herido más próximo que vea (si no está ya a tiro de su curación).
func _healer_seek(e: Ent) -> void:
	var rpx: float = float(e.def["heal_r"]) * float(Defs.TILE)
	var best: Ent = null
	var bd := 1e18
	for o in query(e.pos, _los_px(e)):
		if o != e and o.alive and not o.is_building and not o.naval and o.hp < o.max_hp - 2.0 and (o.owner == e.owner or not hostile[e.owner][o.owner]):
			var d := e.pos.distance_squared_to(o.pos)
			if d < bd:
				bd = d
				best = o
	if best == null or sqrt(bd) <= rpx * 0.7:
		return
	e.state = S_MOVE
	e.amove = false
	_request_path(e, tile_of(best.pos))

func _u_move(e: Ent, step_px: float) -> void:
	if e.explore:
		e.xp_t -= DT
		if e.xp_t <= 0.0:
			e.xp_t = 1.5
			if e.xp_cell >= 0 and explore_known[e.xp_cell] >= EX_DONE:
				_explore_next(e)       # su destino ya se ha visto (otra unidad, o desde lejos): siguiente
				return
	if e.amove and e.is_military():
		e.scan_t -= DT
		if e.scan_t <= 0.0:
			e.scan_t = 0.5
			var t := scan_enemy(e, _los_px(e))
			if t != null:
				_engage(e, t, true)
				return
	var r := _follow(e, step_px)
	if r != 0:
		e.state = S_IDLE
		e.amove = false
		e.path = []
		e.home = e.pos
		if e.unload_at.x >= 0:
			_unload(e)
			e.unload_at = Vector2i(-1, -1)
		if e.explore and r == 2 and e.xp_cell >= 0:
			e.xp_bad.append(e.xp_cell)       # no hay camino hasta allí: no se vuelve a intentar un rato
			if e.xp_bad.size() > 16:
				e.xp_bad.pop_front()

# --- transporte marítimo

func _cargo_cap(ship: Ent) -> int:
	return int(ship.def.get("cargo", 0))

func _landing_tile(sh: Ent, from: Vector2i) -> Vector2i:
	## Casilla de tierra libre a ≤2 casillas del barco, a la que `from` pueda llegar andando; la más cercana al barco.
	var st := tile_of(sh.pos)
	var fc: int = comp[from.y * W + from.x]
	if fc < 0:
		return Vector2i(-1, -1)
	var cands: Array = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t := st + Vector2i(dx, dy)
			if in_bounds(t) and not is_solid_tile(t) and comp[t.y * W + t.x] == fc:
				cands.append(t)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return tile_center(a).distance_squared_to(sh.pos) < tile_center(b).distance_squared_to(sh.pos))
	for t: Vector2i in cands:
		if t == from or not astar.get_id_path(from, t, false).is_empty():
			return t
	return Vector2i(-1, -1)

func cmd_board(pidx: int, ids: Array, ship_id: int) -> int:
	## Unidades de tierra caminan hasta la orilla junto a un transporte propio y suben.
	var sh := get_ent(ship_id)
	if sh == null or sh.owner != pidx or not sh.naval or _cargo_cap(sh) <= 0:
		return ERR_INVALID
	var room := _cargo_cap(sh) - sh.cargo.size()
	if room <= 0:
		return ERR_FULL
	var n := 0
	var no_shore := false
	for e in _own_units(pidx, ids):
		if e.naval or n >= room:
			continue
		var lt := _landing_tile(sh, tile_of(e.pos))
		if lt.x < 0:
			no_shore = true
			continue
		_clear_orders(e)
		e.state = S_BOARD_GO
		e.target_id = ship_id
		e.fails = 0
		e.repath_t = 0.0
		_request_path(e, lt)
		n += 1
	if n > 0:
		return OK
	return ERR_NOSHORE if no_shore else ERR_NOUNITS

func _u_board_go(e: Ent, step_px: float) -> void:
	var sh := get_ent(e.target_id)
	if sh == null or not sh.naval or sh.cargo.size() >= _cargo_cap(sh):
		_clear_orders(e)
		return
	if sh.dist_to(e.pos) <= Defs.TILE * 3.1:
		_board(e, sh)
		return
	# el barco se mueve: se rehace la ruta de vez en cuando
	if not e.path_pending and e.repath_t <= 0.0:
		e.repath_t = 0.8
		var lt := _landing_tile(sh, tile_of(e.pos))
		if lt.x < 0:
			_clear_orders(e)
			return
		if lt != e.goal:
			_request_path(e, lt)
			return
	var r := _follow(e, step_px)
	if r != 0:
		e.fails += 1
		if e.fails > 4:
			_clear_orders(e)
		elif not e.path_pending:
			var lt2 := _landing_tile(sh, tile_of(e.pos))
			if lt2.x < 0:
				_clear_orders(e)
			else:
				_request_path(e, lt2)

func _board(e: Ent, sh: Ent) -> void:
	_clear_orders(e)
	e.stowed = true
	e.pos = sh.pos
	e.ppos = sh.pos
	sh.cargo.append(e)
	stowed_list.append(e)
	_ev({"t": "boarded", "pos": sh.pos, "owner": e.owner})

func cmd_unload(pidx: int, ids: Array, tile: Vector2i) -> int:
	## Los transportes con pasajeros navegan hasta la orilla más cercana a `tile` y los desembarcan.
	## Con tile fuera del mapa (−1,−1) desembarcan donde están, si hay tierra a menos de 4 casillas.
	var n := 0
	var any_cargo := false
	for e in _own_units(pidx, ids):
		if not e.naval or e.cargo.is_empty():
			continue
		any_cargo = true
		if tile.x < 0:
			if _unload(e) > 0:
				n += 1
			continue
		var gt := nearest_water_tile(tile, water_comp_at(tile_of(e.pos)), 6)
		if gt.x < 0:
			continue
		_clear_orders(e)
		e.state = S_MOVE
		e.unload_at = tile
		e.amove_goal = gt
		_request_path(e, gt)
		n += 1
	if not any_cargo:
		return ERR_NOUNITS
	return OK if n > 0 else ERR_NOSHORE

func _unload(sh: Ent) -> int:
	if sh.cargo.is_empty():
		return 0
	var here := tile_of(sh.pos)
	var center := sh.unload_at if sh.unload_at.x >= 0 else here
	var spots: Array = []
	for t: Vector2i in free_tiles_around(center, sh.cargo.size() + 8, 5):
		if Vector2(t - here).length() <= 4.5:
			spots.append(t)
	var n := 0
	for t: Vector2i in spots:
		if sh.cargo.is_empty():
			break
		var u: Ent = sh.cargo.pop_front()
		u.stowed = false
		u.pos = tile_center(t)
		u.ppos = u.pos
		_clear_orders(u)
		ents[u.id] = u
		units.append(u)
		n += 1
	if n > 0:
		_ev({"t": "unloaded", "pos": sh.pos, "owner": sh.owner, "n": n})
	return n

func _in_range(e: Ent, t: Ent, slack: float = 1.0) -> bool:
	return t.dist_to(e.pos) - e.radius <= eff_range(e) * Defs.TILE * slack

func _target_lost(e: Ent) -> void:
	e.target_id = 0
	e.path = []
	e.path_pending = false
	if e.resume_id != 0:
		var rt := get_ent(e.resume_id)
		e.resume_id = 0
		if rt != null and hostile[e.owner][rt.owner]:
			_engage(e, rt, false)
			return
	if e.amove and e.amove_goal.x >= 0:
		e.state = S_MOVE
		_request_path(e, e.amove_goal)
		return
	if e.is_military() and e.stance != ST_PASSIVE:
		var t := scan_enemy(e, _scan_radius(e))
		if t != null and e.stance == ST_HOLD and not _in_range(e, t):
			t = null
		if t != null:
			_engage(e, t, e.auto_target)
			return
	e.state = S_IDLE
	e.auto_target = false
	e.scan_t = 0.3

func _give_up_target(e: Ent) -> void:
	e.ignore_id = e.target_id
	e.ignore_until = time + 20.0
	_target_lost(e)

func _u_attack_go(e: Ent, step_px: float) -> void:
	var t := get_ent(e.target_id)
	if t == null or not hostile[e.owner][t.owner]:
		_target_lost(e)
		return
	if e.fails > 4:
		_give_up_target(e)
		return
	if _in_range(e, t):
		e.state = S_ATTACK
		e.path = []
		e.path_pending = false
		return
	if e.auto_target and not e.amove and e.stance == ST_HOLD:
		_target_lost(e)                 # mantener posición: no persigue a nadie
		return
	if e.auto_target and not e.amove:
		if e.pos.distance_to(e.home) > _leash_px(e):
			e.target_id = 0
			e.auto_target = false
			e.state = S_MOVE
			_request_path(e, tile_of(e.home))
			return
	var tg := _target_goal(t, e)
	if not e.path_pending:
		if e.path.is_empty() or (not t.is_building and e.repath_t <= 0.0 and Vector2(tg - e.goal).length_squared() > 2.0):
			e.repath_t = 0.6
			_request_path(e, tg)
			return
	var r := _follow(e, step_px)
	if r != 0:
		e.fails += 1
		if e.fails > 4:
			_give_up_target(e)
		elif not e.path_pending:
			_request_path(e, tg)

func _u_attack(e: Ent) -> void:
	var t := get_ent(e.target_id)
	if t == null or not hostile[e.owner][t.owner]:
		_target_lost(e)
		return
	if not _in_range(e, t, 1.3):
		e.state = S_ATTACK_GO
		e.repath_t = 0.0
		return
	if e.cd <= 0.0:
		var cdv := float(e.def["cd"])
		var pl: Player = players[e.owner]
		if pl.abil_on and pl.b_rate != 1.0 and pl.b_types.has(e.type):
			cdv /= pl.b_rate
		e.cd = cdv
		_hit(e, t)
	if e.is_military() and t.is_building:
		e.scan_t -= DT
		if e.scan_t <= 0.0:
			e.scan_t = 1.0
			var o := scan_enemy(e, _los_px(e) * 0.8)
			if o != null and not o.is_building:
				_engage(e, o, e.auto_target)

func _hit(a: Ent, t: Ent) -> void:
	var p: Player = players[a.owner]
	var dmg: float = float(a.def["atk"]) * float(Defs.AGE_STAT_MULT[p.age]) * a.am * _up_atk(a)
	if p.abil_on and p.b_atk != 1.0 and p.b_types.has(a.type):
		dmg *= p.b_atk
	if t.is_building:
		dmg *= float(a.def.get("vs_building", 0.3))
	else:
		dmg *= Defs.bonus(a.type, t.type)
	if bool(a.def.get("cannon", false)):
		_ev({"t": "cannon", "from": a.pos, "to": t.center(), "owner": a.owner})
	elif bool(a.def.get("rock", false)):
		_ev({"t": "rock", "from": a.pos, "to": t.center(), "owner": a.owner})
	elif float(a.def["range"]) > 1.5:
		_ev({"t": "arrow", "from": a.pos, "to": t.center(), "owner": a.owner})
	else:
		_ev({"t": "hit", "pos": t.center(), "owner": a.owner})
	_damage(t, dmg, a)
	var splash := float(a.def.get("splash", 0.0))
	if splash > 0.0:
		# la piedra también golpea (a menos fuerza) a los enemigos que están junto al objetivo
		var c := t.center()
		var base_atk: float = float(a.def["atk"]) * float(Defs.AGE_STAT_MULT[p.age]) * a.am * _up_atk(a)
		for o in query(c, splash * float(Defs.TILE)):
			if o != t and o.alive and not o.is_building and o.owner != a.owner and hostile[a.owner][o.owner]:
				_damage(o, base_atk * 0.55 * Defs.bonus(a.type, o.type), a)

func _damage(t: Ent, dmg: float, attacker: Ent, raw: bool = false) -> void:
	var tp: Player = players[t.owner]
	if not t.is_building:
		if not raw:
			var rres: float = float(t.def.get("rres", 1.0))
			if rres < 1.0 and (attacker == null or float(attacker.def["range"]) > 1.5):
				dmg *= rres            # los arietes casi no sienten flechas ni torres
		if tp.abil_on and tp.b_def != 1.0 and tp.b_types.has(t.type):
			dmg *= tp.b_def
		if not raw and t.owner < up_mods.size():
			dmg *= float((up_mods[t.owner]["arm"] as Dictionary).get(t.type, 1.0))
	t.hp -= dmg
	t.last_hit = time
	if tp.is_human and time - tp.last_alarm > 8.0:
		tp.last_alarm = time
		_ev({"t": "alarm", "pos": t.center(), "owner": t.owner})
	if t.hp <= 0.0:
		_kill(t, attacker)
		return
	if attacker != null and (not t.is_building) and t.explore:
		# El explorador no se pone a pelear: huye y evita esa zona un rato
		if time - t.danger_t > 3.0:
			t.danger_pos = t.pos
			_explore_next(t)
		t.danger_t = time
		return
	if attacker != null and not attacker.is_building and t.type == "aldeano" and not t.is_building and t.state != S_GARRISON_GO:
		_flee(t)
	if attacker != null and (not t.is_building) and t.state == S_IDLE and t.is_military() and t.stance != ST_PASSIVE \
			and (t.stance != ST_HOLD or _in_range(t, attacker)):
		_engage(t, attacker, true)

# --- recolección

func _adjacent(a: Vector2i, b: Vector2i) -> bool:
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) <= 1

func _find_new_resource(e: Ent) -> void:
	var kind := e.carry_kind
	if kind == "":
		_clear_orders(e)
		return
	if e.target_tile.x >= 0:
		var oi := e.target_tile.y * W + e.target_tile.x
		if farm_slots.get(oi, 0) == e.id:
			farm_slots.erase(oi)
	var t := Vector2i(-1, -1)
	if e.naval:
		t = find_fish(tile_of(e.pos), 15)
		if t.x < 0 and e.target_tile.x >= 0:
			t = find_fish(e.target_tile, 15)
	else:
		t = find_resource(tile_of(e.pos), res_mask_for(kind), e.owner, e.id, 15)
		if t.x < 0 and e.target_tile.x >= 0:
			t = find_resource(e.target_tile, res_mask_for(kind), e.owner, e.id, 15)
	if t.x >= 0:
		e.target_tile = t
		var idx := t.y * W + t.x
		if rtype[idx] == Defs.R_FARM:
			farm_slots[idx] = e.id
		e.state = S_GATHER_GO
		e.fails = 0
		_request_path(e, t)
	elif e.carry_amt >= 1.0:
		_start_return(e)
	else:
		_clear_orders(e)

func _deplete(idx: int) -> void:
	var rt := rtype[idx]
	chunk_cnt[rt][((idx / W) / 8) * cw + (idx % W) / 8] -= 1
	rtype[idx] = 0
	rowner[idx] = 255
	ramt[idx] = 0
	farm_slots.erase(idx)
	if Defs.is_animal(rt):
		_fauna_remove(idx)
	if rt == Defs.R_GOLD and not mines.is_empty():
		mines.erase(idx)
	if rt == Defs.R_FISH:
		wsol[idx] = 0
		astar_w.set_point_solid(Vector2i(idx % W, idx / W), false)
	elif Defs.solid_res(rt):
		var t := Vector2i(idx % W, idx / W)
		if terrain[idx] != Defs.T_WATER and terrain[idx] != Defs.T_ROCK and occ[idx] == 0:
			set_solid(t, false)
	_ev({"t": "depleted", "tile": Vector2i(idx % W, idx / W), "rt": rt})

func _cnt(k: String) -> void:
	if profiling:
		prof[k] = int(prof.get(k, 0)) + 1

func _u_gather_go(e: Ent, step_px: float) -> void:
	var idx := e.target_tile.y * W + e.target_tile.x
	var mask := _gmask(e)
	if rtype[idx] == 0 or ramt[idx] <= 0 or ((1 << rtype[idx]) & mask) == 0:
		_cnt("gg_invalid")
		_find_new_resource(e)
		return
	if _adjacent(tile_of(e.pos), e.target_tile):
		e.state = S_GATHER
		e.path = []
		e.path_pending = false
		e.gather_acc = 0.0
		return
	var r := _follow(e, step_px)
	if r != 0:
		_cnt("gg_pathfail_%d" % r)
		e.fails += 1
		if e.fails > 3:
			_cnt("gg_findnew")
			bad_res[idx] = time + 40.0
			if bad_res.size() > 400:
				for k in bad_res.keys():
					if float(bad_res[k]) <= time:
						bad_res.erase(k)
			_find_new_resource(e)
		elif not e.path_pending:
			_request_path(e, e.target_tile)

func _u_gather(e: Ent) -> void:
	var idx := e.target_tile.y * W + e.target_tile.x
	var rt := rtype[idx]
	if rt == 0 or ramt[idx] <= 0 or ((1 << rt) & _gmask(e)) == 0:
		_find_new_resource(e)
		return
	if not _adjacent(tile_of(e.pos), e.target_tile):
		e.state = S_GATHER_GO
		_request_path(e, e.target_tile)
		return
	var p: Player = players[e.owner]
	var gm := p.gather_mult
	if e.owner < civ_mods.size():
		gm *= (civ_mods[e.owner]["gather"] as PackedFloat32Array)[rt]
	if e.owner < up_mods.size():
		gm *= (up_mods[e.owner]["gather"] as PackedFloat32Array)[rt]
	e.gather_acc += float(Defs.RES_INFO[rt]["rate"]) * gm * DT
	if e.gather_acc >= 1.0:
		var n := mini(int(e.gather_acc), ramt[idx])
		e.gather_acc -= float(n)
		e.carry_amt += float(n)
		ramt[idx] -= n
		if ramt[idx] <= 0:
			_deplete(idx)
	var cap := float(e.def.get("carry", CARRY_CAP))
	if e.type == "aldeano" and e.owner < up_mods.size():
		cap += float(up_mods[e.owner]["carry"])
	if e.carry_amt >= cap:
		_start_return(e)

func _start_return(e: Ent) -> void:
	var d := nearest_dropoff(e)
	if d == null:
		e.state = S_IDLE
		return
	e.state = S_RETURN
	e.target_id = d.id
	e.fails = 0
	_request_path(e, _return_goal(e, d))

func _u_return(e: Ent, step_px: float) -> void:
	var d := get_ent(e.target_id)
	if d == null or d.progress < 1.0:
		_start_return(e)
		return
	if d.dist_to(e.pos) <= Defs.TILE * 0.95:
		var p: Player = players[e.owner]
		var n := int(e.carry_amt)
		p.res[e.carry_kind] = int(p.res.get(e.carry_kind, 0)) + n
		p.gathered[e.carry_kind] = int(p.gathered.get(e.carry_kind, 0)) + n
		if n > 0:
			_ev({"t": "deposit", "pos": d.center(), "owner": e.owner, "kind": e.carry_kind, "n": n})
		e.carry_amt = 0.0
		e.target_id = 0
		if e.target_tile.x >= 0:
			var idx := e.target_tile.y * W + e.target_tile.x
			if _res_usable(idx, _gmask(e), e.owner, e.id):
				e.state = S_GATHER_GO
				e.fails = 0
				_request_path(e, e.target_tile)
				return
		_find_new_resource(e)
		return
	var r := _follow(e, step_px)
	if r != 0:
		e.fails += 1
		if e.fails > 4:
			e.state = S_IDLE
		elif not e.path_pending:
			_request_path(e, _return_goal(e, d))

# --- construcción

func _u_build_go(e: Ent, step_px: float) -> void:
	var b := get_ent(e.target_id)
	if b == null or b.progress >= 1.0:
		_builder_done(e, b)
		return
	if b.dist_to(e.pos) <= Defs.TILE * 0.95:
		e.state = S_BUILD
		e.path = []
		e.path_pending = false
		return
	var r := _follow(e, step_px)
	if r != 0 and b.dist_to(e.pos) <= Defs.TILE * 1.4:
		# La ruta termina en una casilla en diagonal al edificio: desde ahí ya se puede construir
		# (_u_build admite hasta 1,4 casillas), así que no se queda dando vueltas.
		e.state = S_BUILD
		e.path = []
		e.path_pending = false
		return
	if r != 0:
		e.fails += 1
		if e.fails > 4:
			if bool(b.def.get("wall", false)):
				_builder_done(e, b)
			else:
				_clear_orders(e)
		elif not e.path_pending:
			_request_path(e, b.tile + Vector2i(b.size / 2, b.size / 2))

func _u_build(e: Ent) -> void:
	var b := get_ent(e.target_id)
	if b == null or b.progress >= 1.0:
		_builder_done(e, b)
		return
	if b.dist_to(e.pos) > Defs.TILE * 1.4:
		e.state = S_BUILD_GO
		_request_path(e, b.tile + Vector2i(b.size / 2, b.size / 2))
		return
	b.bacc += 1
	var n := maxi(1, b.builders)
	var rate := DT / float(b.def["time"]) / pow(float(n), 0.3)
	b.progress = minf(1.0, b.progress + rate)
	b.hp = minf(b.max_hp, b.hp + rate * 0.9 * b.max_hp)
	if b.progress >= 1.0:
		b.hp = maxf(b.hp, b.max_hp * 0.5)
		_on_building_complete(b, true)

func _builder_done(e: Ent, b: Ent) -> void:
	var near := e.pos
	_clear_orders(e)
	if b != null and bool(b.def.get("wall", false)):
		# seguir con el siguiente tramo de muralla sin terminar que haya cerca
		var cands: Array = []
		for o in buildings:
			if o.alive and o.owner == e.owner and o.progress < 1.0 and o.def.get("wall", false):
				var d := o.pos.distance_squared_to(near)
				if d < pow(12.0 * Defs.TILE, 2.0):
					cands.append([d, o])
		cands.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		var start := tile_of(near)
		for c: Array in cands:
			var o: Ent = c[1]
			if _site_reachable(start, o):
				_assign_build(e, o)
				return
			# La propia muralla ha dejado esta pieza encerrada: se cancela y se devuelve el coste.
			_cancel_site(o)
		return
	if b != null and bool(b.def.get("drop", false)) and not bool(b.def.get("dock", false)):
		var t := find_resource(tile_of(near), res_mask_for("wood"), e.owner, e.id, 12)
		if t.x < 0:
			t = find_resource(tile_of(near), res_mask_for("gold"), e.owner, e.id, 12)
		if t.x >= 0:
			_assign_gather(e, t, kind_of_tile(t))

func _site_reachable(start: Vector2i, o: Ent) -> bool:
	## ¿puede un aldeano en `start` llegar junto a la obra `o` (ya colocada y sólida)?
	if start == o.tile:
		return true
	return not _path_into(start, o.tile).is_empty()

func _cancel_site(o: Ent) -> void:
	## Cancela una pieza de muralla sin empezar que nadie más está construyendo y devuelve su coste.
	if o.progress > 0.0:
		return
	for u in units:
		if u.alive and u.owner == o.owner and u.target_id == o.id and (u.state == S_BUILD_GO or u.state == S_BUILD):
			return
	var p: Player = players[o.owner]
	var cost: Dictionary = o.def["cost"]
	for k in cost:
		p.res[k] = int(p.res.get(k, 0)) + int(cost[k])
	_remove_silently(o)
	_ev({"t": "wall_gap", "owner": o.owner, "pos": o.pos})

# ------------------------------------------------------------------ edificios

func _recount_pop_cap(p: Player) -> void:
	var cap := 0
	for b in buildings:
		if b.alive and b.owner == p.idx and b.progress >= 1.0:
			cap += _bld_pop(b)
	p.pop_cap = mini(Defs.MAX_POP, cap)

func _update_building(b: Ent) -> void:
	if b.progress < 1.0:
		return
	var p: Player = players[b.owner]
	if b.queue.size() > 0:
		if not b.producing:
			if Defs.is_tech_item(b.queue[0]):
				b.blocked_pop = false
				b.producing = true
				b.prod_tech = true
				b.train_total = tech_time(b.queue[0])
				b.train_left = b.train_total
			elif p.pop + p.reserved >= p.pop_cap:
				b.blocked_pop = true
			else:
				b.blocked_pop = false
				b.producing = true
				p.reserved += 1
				b.train_total = unit_time(b.owner, b.queue[0])
				b.train_left = b.train_total
		else:
			b.train_left -= DT
			if b.train_left <= 0.0:
				if b.prod_tech:
					_finish_tech(b)
				else:
					_spawn_trained(b)
	else:
		b.blocked_pop = false
	if not b.cargo.is_empty() and (step_count + b.id) % 10 == 0:
		_gar_tick(b)
	if b.def.has("atk"):
		b.cd = maxf(0.0, b.cd - DT)
		if b.cd <= 0.0:
			var rng_px := float(b.def["range"]) * Defs.TILE
			var best: Ent = null
			var bd := 1e9
			for o in query(b.center(), rng_px):
				if o.is_building or not hostile[b.owner][o.owner]:
					continue
				var d: float = o.pos.distance_to(b.center())
				if d < bd:
					bd = d
					best = o
			if best == null:
				b.cd = 0.4
			else:
				var shooters := 0
				for c: Ent in b.cargo:
					if float(c.def["range"]) > 1.5 and float(c.def["atk"]) > 0.0 and c.is_military():
						shooters += 1
				b.cd = float(b.def["cd"]) / (1.0 + GAR_ARROW * float(mini(shooters, GAR_ARROW_MAX)))
				_ev({"t": "arrow", "from": b.center(), "to": best.pos, "owner": b.owner})
				_damage(best, float(b.def["atk"]) * float(Defs.AGE_STAT_MULT[p.age]), null)

func _spawn_tile_near(b: Ent) -> Vector2i:
	var target := Vector2(b.tile.x + b.size * 0.5, b.tile.y + b.size + 1.0)
	if b.rally.x >= 0:
		target = Vector2(b.rally)
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for dy in range(-1, b.size + 1):
		for dx in range(-1, b.size + 1):
			if dx >= 0 and dx < b.size and dy >= 0 and dy < b.size:
				continue
			var t := b.tile + Vector2i(dx, dy)
			if in_bounds(t) and not is_solid_tile(t):
				var d := Vector2(t).distance_squared_to(target)
				if d < bd:
					bd = d
					best = t
	if best.x < 0:
		best = nearest_free_tile(b.tile + Vector2i(b.size / 2, b.size + 1), 6)
	return best

func _spawn_water_near(b: Ent) -> Vector2i:
	var wc := water_comp_at(b.dock_tile)
	var spots := free_water_around(b.dock_tile, 6, 3, wc)
	if spots.is_empty():
		return b.dock_tile
	return spots[rng.randi() % spots.size()]

func _spawn_trained(b: Ent) -> void:
	var utype: String = b.queue.pop_front()
	b.producing = false
	var p: Player = players[b.owner]
	p.reserved -= 1
	var naval := bool(Defs.UNITS[utype].get("naval", false))
	var u := _spawn_unit(utype, b.owner, _spawn_water_near(b) if naval else _spawn_tile_near(b))
	_ev({"t": "trained", "pos": u.pos, "owner": b.owner, "type": utype})
	if b.rally.x >= 0:
		var idx := b.rally.y * W + b.rally.x
		if bool(u.def.get("fisher", false)):
			if rtype[idx] == Defs.R_FISH:
				_assign_gather(u, b.rally, "food")
			elif is_free_water(b.rally, water_comp_at(tile_of(u.pos))):
				cmd_move(b.owner, [u.id], b.rally)
		elif naval:
			if is_free_water(b.rally, water_comp_at(tile_of(u.pos))):
				cmd_move(b.owner, [u.id], b.rally)
		elif utype == "aldeano" and rtype[idx] != 0 and rtype[idx] != Defs.R_FISH and rtype[idx] != Defs.R_SAPLING and (rtype[idx] != Defs.R_FARM or rowner[idx] == b.owner):
			_assign_gather(u, b.rally, kind_of_tile(b.rally))
		else:
			cmd_move(b.owner, [u.id], b.rally)
	elif utype == "explorador" and p.is_human:
		cmd_explore(b.owner, [u.id], true)      # sin punto de reunión: el explorador nuevo sale a explorar solo

# ------------------------------------------------------------------ muerte y victoria

func _kill(e: Ent, killer: Ent) -> void:
	if not e.alive:
		return
	e.alive = false
	var p: Player = players[e.owner]
	p.losses += 1
	if killer != null:
		var kp: Player = players[killer.owner]
		kp.kills += 1
		if kp.b_loot and kp.abil_on and not e.is_building and kp.b_types.has(killer.type):
			kp.res["gold"] = int(kp.res["gold"]) + kp.b_loot_gold
			kp.res["food"] = int(kp.res["food"]) + kp.b_loot_food
			_ev({"t": "loot", "pos": e.pos, "owner": killer.owner, "gold": kp.b_loot_gold})
	_ev({"t": "death", "pos": e.center(), "owner": e.owner, "building": e.is_building, "type": e.type})
	dead.append(e)
	if e.is_building:
		for dy in e.size:
			for dx in e.size:
				var t := e.tile + Vector2i(dx, dy)
				occ[t.y * W + t.x] = 0
				if wall_tile[t.y * W + t.x] == 1:
					wall_tile[t.y * W + t.x] = 0
					gate_tile[t.y * W + t.x] = 0
					wall_count -= 1
					astar2.set_point_weight_scale(t, 1.0)
				if rtype[t.y * W + t.x] == 0 and terrain[t.y * W + t.x] != Defs.T_WATER and terrain[t.y * W + t.x] != Defs.T_ROCK:
					set_solid(t, false)
		if e.producing and not e.prod_tech:
			p.reserved -= 1
		if not e.cargo.is_empty():
			if p.alive:
				_garrison_release(e, 0)          # el edificio cae: los refugiados salen a pie
			else:
				for c: Ent in e.cargo:
					c.alive = false
					p.pop -= 1
					p.losses += 1
				e.cargo.clear()
		_recount_pop_cap(p)
		if e.type == "centro":
			_check_player_alive(p)
	else:
		p.pop -= 1
		_clear_orders(e)
		for c: Ent in e.cargo:
			c.alive = false
			p.pop -= 1
			p.losses += 1
		e.cargo.clear()

func _check_player_alive(p: Player) -> void:
	if not p.alive:
		return
	for b in buildings:
		if b.alive and b.owner == p.idx and b.type == "centro":
			return
	_eliminate(p)

func _eliminate(p: Player) -> void:
	p.alive = false
	_ev({"t": "eliminated", "owner": p.idx})
	for e: Ent in ents.values():
		if e.alive and e.owner == p.idx:
			_kill(e, null)
	_check_victory()

func _check_victory() -> void:
	if game_over:
		return
	var teams := {}
	for p in players:
		if p.alive:
			teams[p.team] = true
	var human_alive: bool = human_index < 0 or players[human_index].alive
	if teams.size() <= 1 or not human_alive:
		game_over = true
		winner_team = int(teams.keys()[0]) if teams.size() == 1 else -1
		var human_won: bool = human_index >= 0 and human_alive and teams.size() <= 1
		_ev({"t": "gameover", "winner": winner_team, "human_won": human_won})

func summary() -> Dictionary:
	var out := {"time": snappedf(time, 0.1), "players": []}
	for p in players:
		var vill := 0
		var mil := 0
		var bld := {}
		for u in units:
			if u.alive and u.owner == p.idx:
				if u.type == "aldeano":
					vill += 1
				else:
					mil += 1
		for b in buildings:
			if b.alive and b.owner == p.idx:
				bld[b.type] = int(bld.get(b.type, 0)) + (1 if b.progress >= 1.0 else 0)
		(out["players"] as Array).append({
			"i": p.idx, "civ": p.civ, "alive": p.alive, "age": p.age, "pop": p.pop, "cap": p.pop_cap,
			"vill": vill, "mil": mil, "res": p.res.duplicate(), "b": bld, "kills": p.kills,
		})
	return out
