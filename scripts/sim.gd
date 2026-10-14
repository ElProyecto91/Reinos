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

# Códigos de resultado de órdenes (negativos = error)
const OK := 1
const ERR_PLACE := -1
const ERR_COST := -2
const ERR_AGE := -3
const ERR_QUEUE := -4
const ERR_NOUNITS := -5
const ERR_INVALID := -6
const ERR_UNREACHABLE := -7

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
var ais: Array[AiPlayer] = []
var hostile: Array = []
var next_id: int = 1
var time: float = 0.0
var events: Array = []
var record_events: bool = true
var buckets: Array = []
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
var chunk_cnt: Array = []
var cw: int = 0
var wall_tile := PackedByteArray()      # 1 = casilla con muralla o puerta
var gate_tile := PackedByteArray()      # 1 = puerta terminada (no sólida para aliados)
var astar2: AStarGrid2D                 # rejilla de asedio: las murallas se pueden atravesar con coste alto
var wall_count: int = 0

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
	map_info = {"main_size": m["main_size"], "islands": m["islands"], "land_count": m["land_count"]}
	var total := W * H
	rowner.resize(total)
	rowner.fill(255)
	solid.resize(total)
	occ.resize(total)
	bfs_mark.resize(total)
	bfs_dist.resize(total)
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
	for i in total:
		var rt := rtype[i]
		if terrain[i] == Defs.T_WATER or rt == Defs.R_TREE or rt == Defs.R_GOLD or rt == Defs.R_BERRY:
			solid[i] = 1
			astar.set_point_solid(Vector2i(i % W, i / W), true)
			astar2.set_point_solid(Vector2i(i % W, i / W), true)
	cw = (W + 7) / 8
	for k in 6:
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
		players.append(p)
		if p.is_human and human_index < 0:
			human_index = i
	for a in players.size():
		var row: Array = []
		for b in players.size():
			row.append(players[a].team != players[b].team)
		hostile.append(row)
	for p in players:
		var s: Vector2i = p.start_tile
		_spawn_building("centro", p.idx, s - Vector2i(1, 1), true)
		for k in 5:
			var ft := nearest_free_tile(s + Vector2i(k - 2, 3), 6)
			_spawn_unit("aldeano", p.idx, ft)
		if not p.is_human:
			ais.append(AiPlayer.new(self, p.idx, p.difficulty))
	_rebuild_buckets()
	return true


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
	if e != null and e.alive:
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
	e.radius = d["radius"]
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
	e.progress = 1.0 if complete else 0.0
	e.hp = e.max_hp if complete else e.max_hp * 0.1
	e.radius = e.size * Defs.TILE * 0.5
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
	var p: Player = players[b.owner]
	if b.def.get("gate", false):
		# la puerta terminada deja de ser sólida: pasan los aliados; al enemigo lo frena _follow
		gate_tile[b.tile.y * W + b.tile.x] = 1
		astar2.set_point_weight_scale(b.tile, 1.0)
		set_solid(b.tile, false)
	p.pop_cap = mini(Defs.MAX_POP, p.pop_cap + int(b.def.get("pop", 0)))
	if announce:
		_ev({"t": "built", "pos": b.pos, "owner": b.owner, "type": b.type})

# ------------------------------------------------------------------ búsqueda espacial

func _rebuild_buckets() -> void:
	for b in buckets:
		b.clear()
	var bs := float(BUCKET * Defs.TILE)
	for e in units:
		if e.alive:
			var bx := clampi(int(e.pos.x / bs), 0, bw - 1)
			var by := clampi(int(e.pos.y / bs), 0, bh - 1)
			buckets[by * bw + bx].append(e)
	for e in buildings:
		if e.alive:
			var r := e.rect()
			var x0 := clampi(int(r.position.x / bs), 0, bw - 1)
			var x1 := clampi(int((r.end.x - 1.0) / bs), 0, bw - 1)
			var y0 := clampi(int(r.position.y / bs), 0, bh - 1)
			var y1 := clampi(int((r.end.y - 1.0) / bs), 0, bh - 1)
			for by in range(y0, y1 + 1):
				for bx in range(x0, x1 + 1):
					buckets[by * bw + bx].append(e)

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
	var best: Ent = null
	var bs := 1e9
	for o in query(e.pos, r):
		if o.owner == e.owner or not hostile[e.owner][o.owner]:
			continue
		if o.id == e.ignore_id and time < e.ignore_until:
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
		if solid[t.y * W + t.x] == 1 and e.path_i < e.path.size() - 1:
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
		"food":
			return (1 << Defs.R_BERRY) | (1 << Defs.R_FARM)
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
	for rt in [Defs.R_TREE, Defs.R_GOLD, Defs.R_BERRY]:
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

func nearest_dropoff(e: Ent) -> Ent:
	var best: Ent = null
	var bd := 1e12
	for b in buildings:
		if b.alive and b.owner == e.owner and b.progress >= 1.0 and bool(b.def.get("drop", false)):
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

func cmd_attack(pidx: int, ids: Array, target_id: int) -> void:
	var t := get_ent(target_id)
	if t == null or not is_hostile(pidx, t.owner):
		return
	for e in _own_units(pidx, ids):
		_clear_orders(e)
		e.target_id = target_id
		e.state = S_ATTACK_GO
		e.auto_target = false
		e.repath_t = 0.0
		_request_path(e, _target_goal(t))

func _target_goal(t: Ent) -> Vector2i:
	if t.is_building:
		return t.tile + Vector2i(t.size / 2, t.size / 2)
	return tile_of(t.pos)

func cmd_gather(pidx: int, ids: Array, tile: Vector2i) -> void:
	if not in_bounds(tile):
		return
	var idx := tile.y * W + tile.x
	var rt := rtype[idx]
	if rt == 0 or rt == Defs.R_FISH:
		return
	if rt == Defs.R_FARM and rowner[idx] != pidx:
		return
	var kind: String = Defs.RES_INFO[rt]["kind"]
	for e in _own_units(pidx, ids):
		if e.type != "aldeano":
			continue
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
	if not Defs.BUILDINGS.has(type):
		return ERR_INVALID
	var d: Dictionary = Defs.BUILDINGS[type]
	if d.get("wall", false):
		return cmd_build_wall(pidx, ids, type, [tile])
	if p.age < int(d["age"]):
		return ERR_AGE
	if not Defs.can_afford(p.res, d["cost"]):
		return ERR_COST
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

func can_place(type: String, tile: Vector2i, pidx: int = -1) -> bool:
	if type == "granja":
		return can_place_farm(tile)
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
	if not (b.def["train"] as Array).has(utype):
		return ERR_INVALID
	var ud: Dictionary = Defs.UNITS[utype]
	if p.age < int(ud["age"]):
		return ERR_AGE
	if b.queue.size() >= 5:
		return ERR_QUEUE
	if not Defs.can_afford(p.res, ud["cost"]):
		return ERR_COST
	Defs.pay(p.res, ud["cost"])
	b.queue.append(utype)
	return OK

func cmd_cancel_train(pidx: int, bid: int, index: int) -> void:
	var b := get_ent(bid)
	if b == null or b.owner != pidx or index < 0 or index >= b.queue.size():
		return
	var utype: String = b.queue[index]
	Defs.refund(players[pidx].res, Defs.UNITS[utype]["cost"])
	b.queue.remove_at(index)
	if index == 0 and b.producing:
		b.producing = false
		players[pidx].reserved -= 1

func cmd_set_rally(pidx: int, bid: int, tile: Vector2i) -> void:
	var b := get_ent(bid)
	if b != null and b.owner == pidx and b.is_building:
		b.rally = tile

func cmd_age_up(pidx: int) -> int:
	var p: Player = players[pidx]
	if p.age >= Defs.AGES.size() - 1 or p.aging:
		return ERR_INVALID
	var ad: Dictionary = Defs.AGES[p.age + 1]
	if not Defs.can_afford(p.res, ad["cost"]):
		return ERR_COST
	var has_tc := false
	for b in buildings:
		if b.alive and b.owner == pidx and b.type == "centro" and b.progress >= 1.0:
			has_tc = true
			break
	if not has_tc:
		return ERR_INVALID
	Defs.pay(p.res, ad["cost"])
	p.aging = true
	p.age_left = ad["time"]
	return OK

func cmd_delete(pidx: int, id: int) -> void:
	var e := get_ent(id)
	if e != null and e.owner == pidx:
		_kill(e, null)

func idle_villagers(pidx: int) -> Array:
	var out: Array = []
	for u in units:
		if u.alive and u.owner == pidx and u.type == "aldeano" and u.state == S_IDLE:
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
	for u in units:
		if u.alive:
			_update_unit(u)
	if profiling:
		_p("units", t0)
		t0 = Time.get_ticks_usec()
	for b in buildings:
		if b.alive:
			_update_building(b)
	_update_players()
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
	if dead.is_empty():
		return
	for e in dead:
		ents.erase(e.id)
	units.assign(units.filter(func(e: Ent) -> bool: return e.alive))
	buildings.assign(buildings.filter(func(e: Ent) -> bool: return e.alive))
	dead.clear()

func _update_players() -> void:
	for p in players:
		if p.aging:
			p.age_left -= DT
			if p.age_left <= 0.0:
				p.aging = false
				p.age += 1
				var m: float = Defs.AGE_STAT_MULT[p.age]
				var prev: float = Defs.AGE_STAT_MULT[p.age - 1]
				for u in units:
					if u.alive and u.owner == p.idx:
						var ratio: float = m / prev
						u.max_hp *= ratio
						u.hp *= ratio
				_ev({"t": "age", "owner": p.idx, "age": p.age})

# ------------------------------------------------------------------ unidades

func _update_unit(e: Ent) -> void:
	e.cd = maxf(0.0, e.cd - DT)
	e.repath_t = maxf(0.0, e.repath_t - DT)
	var step_px: float = float(e.def["speed"]) * Defs.TILE * DT
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

func _los_px(e: Ent) -> float:
	return float(e.def["los"]) * Defs.TILE

func _engage(e: Ent, t: Ent, auto: bool) -> void:
	if e.state == S_IDLE:
		e.home = e.pos
	e.target_id = t.id
	e.auto_target = auto
	e.state = S_ATTACK_GO
	e.repath_t = 0.0
	e.path = []
	e.path_pending = false
	e.fails = 0

func _u_idle(e: Ent) -> void:
	if not e.is_military():
		return
	e.scan_t -= DT
	if e.scan_t <= 0.0:
		e.scan_t = 0.5
		var t := scan_enemy(e, _los_px(e))
		if t != null:
			_engage(e, t, true)

func _u_move(e: Ent, step_px: float) -> void:
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

func _in_range(e: Ent, t: Ent, slack: float = 1.0) -> bool:
	return t.dist_to(e.pos) - e.radius <= float(e.def["range"]) * Defs.TILE * slack

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
	if e.is_military():
		var t := scan_enemy(e, _los_px(e))
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
	if e.auto_target and not e.amove:
		if e.pos.distance_to(e.home) > _los_px(e) + 6.0 * Defs.TILE:
			e.target_id = 0
			e.auto_target = false
			e.state = S_MOVE
			_request_path(e, tile_of(e.home))
			return
	var tg := _target_goal(t)
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
		e.cd = float(e.def["cd"])
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
	var dmg: float = float(a.def["atk"]) * float(Defs.AGE_STAT_MULT[p.age])
	if t.is_building:
		dmg *= float(a.def.get("vs_building", 0.3))
	else:
		var bon: Dictionary = Defs.BONUS.get(a.type, {})
		dmg *= float(bon.get(t.type, 1.0))
	if float(a.def["range"]) > 1.5:
		_ev({"t": "arrow", "from": a.pos, "to": t.center(), "owner": a.owner})
	else:
		_ev({"t": "hit", "pos": t.center(), "owner": a.owner})
	_damage(t, dmg, a)

func _damage(t: Ent, dmg: float, attacker: Ent) -> void:
	t.hp -= dmg
	t.last_hit = time
	var tp: Player = players[t.owner]
	if tp.is_human and time - tp.last_alarm > 8.0:
		tp.last_alarm = time
		_ev({"t": "alarm", "pos": t.center(), "owner": t.owner})
	if t.hp <= 0.0:
		_kill(t, attacker)
		return
	if attacker != null and (not t.is_building) and t.state == S_IDLE and t.is_military():
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
	var t := find_resource(tile_of(e.pos), res_mask_for(kind), e.owner, e.id, 15)
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
	if rt != Defs.R_FARM:
		var t := Vector2i(idx % W, idx / W)
		if terrain[idx] != Defs.T_WATER and occ[idx] == 0:
			set_solid(t, false)
	_ev({"t": "depleted", "tile": Vector2i(idx % W, idx / W), "rt": rt})

func _cnt(k: String) -> void:
	if profiling:
		prof[k] = int(prof.get(k, 0)) + 1

func _u_gather_go(e: Ent, step_px: float) -> void:
	var idx := e.target_tile.y * W + e.target_tile.x
	var mask := res_mask_for(e.carry_kind)
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
	if rt == 0 or ramt[idx] <= 0 or ((1 << rt) & res_mask_for(e.carry_kind)) == 0:
		_find_new_resource(e)
		return
	if not _adjacent(tile_of(e.pos), e.target_tile):
		e.state = S_GATHER_GO
		_request_path(e, e.target_tile)
		return
	var p: Player = players[e.owner]
	e.gather_acc += float(Defs.RES_INFO[rt]["rate"]) * p.gather_mult * DT
	if e.gather_acc >= 1.0:
		var n := mini(int(e.gather_acc), ramt[idx])
		e.gather_acc -= float(n)
		e.carry_amt += float(n)
		ramt[idx] -= n
		if ramt[idx] <= 0:
			_deplete(idx)
	if e.carry_amt >= CARRY_CAP:
		_start_return(e)

func _start_return(e: Ent) -> void:
	var d := nearest_dropoff(e)
	if d == null:
		e.state = S_IDLE
		return
	e.state = S_RETURN
	e.target_id = d.id
	e.fails = 0
	_request_path(e, d.tile + Vector2i(d.size / 2, d.size / 2))

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
			if _res_usable(idx, res_mask_for(e.carry_kind), e.owner, e.id):
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
			_request_path(e, d.tile + Vector2i(d.size / 2, d.size / 2))

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
	if b != null and bool(b.def.get("drop", false)):
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
			cap += int(b.def.get("pop", 0))
	p.pop_cap = mini(Defs.MAX_POP, cap)

func _update_building(b: Ent) -> void:
	if b.progress < 1.0:
		return
	var p: Player = players[b.owner]
	if b.queue.size() > 0:
		if not b.producing:
			if p.pop + p.reserved >= p.pop_cap:
				b.blocked_pop = true
			else:
				b.blocked_pop = false
				b.producing = true
				p.reserved += 1
				var ud: Dictionary = Defs.UNITS[b.queue[0]]
				b.train_total = float(ud["time"])
				b.train_left = b.train_total
		else:
			b.train_left -= DT
			if b.train_left <= 0.0:
				_spawn_trained(b)
	else:
		b.blocked_pop = false
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
				b.cd = float(b.def["cd"])
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

func _spawn_trained(b: Ent) -> void:
	var utype: String = b.queue.pop_front()
	b.producing = false
	var p: Player = players[b.owner]
	p.reserved -= 1
	var u := _spawn_unit(utype, b.owner, _spawn_tile_near(b))
	_ev({"t": "trained", "pos": u.pos, "owner": b.owner, "type": utype})
	if b.rally.x >= 0:
		var idx := b.rally.y * W + b.rally.x
		if utype == "aldeano" and rtype[idx] != 0 and rtype[idx] != Defs.R_FISH and (rtype[idx] != Defs.R_FARM or rowner[idx] == b.owner):
			_assign_gather(u, b.rally, kind_of_tile(b.rally))
		else:
			cmd_move(b.owner, [u.id], b.rally)

# ------------------------------------------------------------------ muerte y victoria

func _kill(e: Ent, killer: Ent) -> void:
	if not e.alive:
		return
	e.alive = false
	var p: Player = players[e.owner]
	p.losses += 1
	if killer != null:
		players[killer.owner].kills += 1
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
				if rtype[t.y * W + t.x] == 0 and terrain[t.y * W + t.x] != Defs.T_WATER:
					set_solid(t, false)
		if e.producing:
			p.reserved -= 1
		_recount_pop_cap(p)
		if e.type == "centro":
			_check_player_alive(p)
	else:
		p.pop -= 1
		_clear_orders(e)

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
			"i": p.idx, "alive": p.alive, "age": p.age, "pop": p.pop, "cap": p.pop_cap,
			"vill": vill, "mil": mil, "res": p.res.duplicate(), "b": bld, "kills": p.kills,
		})
	return out
