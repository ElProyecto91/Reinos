class_name AiPlayer
extends RefCounted
## IA por guion (local, sin red ni modelos): economía con ratios, orden de
## construcción, subida de edad, producción militar y oleadas con temporizador.

var sim: Sim
var pi: int
var diff: int
var acc: float = 0.0
var interval: float = 1.0
var attack_at: float = 480.0
var need_army: int = 12
var wave: int = 0
var wave_active: bool = false
var wave_start: float = 0.0
var target_pi: int = -1
var last_defend: float = -100.0
var store_cd: float = 0.0
var rng := RandomNumberGenerator.new()

func _init(s: Sim, idx: int, d: int) -> void:
	sim = s
	pi = idx
	diff = clampi(d, 0, 2)
	interval = [1.4, 1.0, 0.7][diff]
	rng.seed = s.rng.seed + idx * 131
	attack_at = [640.0, 450.0, 330.0][diff] + rng.randf_range(0.0, 40.0)
	need_army = [10, 12, 12][diff]
	acc = rng.randf() * interval

func update(dt: float) -> void:
	acc += dt
	if acc >= interval:
		acc = 0.0
		_think()

func _think() -> void:
	var p: Player = sim.players[pi]
	if not p.alive:
		return
	var vills: Array = []
	var army: Array = []
	for u in sim.units:
		if u.alive and u.owner == pi:
			if u.type == "aldeano":
				vills.append(u)
			else:
				army.append(u)
	var done := {}
	var inprog := {}
	var tc: Ent = null
	for b in sim.buildings:
		if b.alive and b.owner == pi:
			if b.progress >= 1.0:
				done[b.type] = int(done.get(b.type, 0)) + 1
				if b.type == "centro" and tc == null:
					tc = b
			else:
				inprog[b.type] = int(inprog.get(b.type, 0)) + 1
	var base := p.start_tile
	if tc != null:
		base = tc.tile + Vector2i(1, 1)
	store_cd = maxf(0.0, store_cd - interval)
	_economy(p, vills, base, done, inprog)
	_build(p, vills, base, done, inprog)
	_train(p, vills, done)
	_age(p, vills, done)
	_military(p, army, base)

# ------------------------------------------------------------------ economía

func _vill_target(p: Player) -> int:
	var t: int = [20, 28, 36][diff]
	if p.age >= 1:
		t += 8
	return t

func _wants_age(p: Player, vills: Array, done: Dictionary) -> bool:
	return p.age == 0 and int(done.get("cuartel", 0)) >= 1 and vills.size() >= [24, 20, 16][diff]

func _economy(p: Player, vills: Array, base: Vector2i, done: Dictionary, inprog: Dictionary) -> void:
	var n := vills.size()
	if n == 0:
		return
	var counts := {"food": 0, "wood": 0, "gold": 0}
	var idle: Array = []
	for v in vills:
		if v.state == Sim.S_IDLE:
			idle.append(v)
		elif v.carry_kind != "" and (v.state == Sim.S_GATHER or v.state == Sim.S_GATHER_GO or v.state == Sim.S_RETURN):
			counts[v.carry_kind] = int(counts[v.carry_kind]) + 1
	var wf := 0.45
	var ww := 0.45
	var wg := 0.10
	if n < 9:
		wf = 0.5
		ww = 0.5
		wg = 0.0
	elif _wants_age(p, vills, done):
		wf = 0.35
		ww = 0.35
		wg = 0.30
	elif p.age >= 1:
		wf = 0.30
		ww = 0.35
		wg = 0.35
	var want := {"food": wf, "wood": ww, "gold": wg}
	# Ajuste por existencias: menos gente en lo que sobra, más en lo que falta
	var tot := 0.0
	for k in ["food", "wood", "gold"]:
		var stock := float(p.res.get(k, 0))
		var m := 1.0
		if stock > 1500.0:
			m = 0.15
		elif stock > 800.0:
			m = 0.45
		elif stock < 100.0:
			m = 1.6
		want[k] = float(want[k]) * m
		tot += float(want[k])
	if tot > 0.0:
		for k in ["food", "wood", "gold"]:
			want[k] = float(want[k]) / tot
	for v in idle:
		var best := "wood"
		var bdef := -1e9
		for k in ["food", "wood", "gold"]:
			var deficit: float = float(want[k]) * n - float(counts[k])
			if float(want[k]) <= 0.0:
				continue
			if deficit > bdef:
				bdef = deficit
				best = k
		if _assign(p, v, best, base):
			counts[best] = int(counts[best]) + 1
		else:
			for k in ["wood", "food", "gold"]:
				if k != best and float(want[k]) > 0.0 and _assign(p, v, k, base):
					counts[k] = int(counts[k]) + 1
					break
	# Rebalanceo continuo: mover un recolector del recurso más sobrecargado al más escaso
	var over := ""
	var under := ""
	var over_v := -1e9
	var under_v := 1e9
	for k in ["food", "wood", "gold"]:
		var diff_k: float = float(counts[k]) - float(want[k]) * n
		if diff_k > over_v:
			over_v = diff_k
			over = k
		if diff_k < under_v and float(want[k]) > 0.0:
			under_v = diff_k
			under = k
	if over != "" and under != "" and over != under and over_v > 2.0 and under_v < -1.5:
		for v in vills:
			if v.state == Sim.S_GATHER and v.carry_kind == over and v.carry_amt < 3.0:
				_assign(p, v, under, base)
				break

func _assign(p: Player, v: Ent, kind: String, base: Vector2i) -> bool:
	var mask := sim.res_mask_for(kind)
	var from := sim.tile_of(v.pos)
	var t := sim.find_resource(from, mask, pi, v.id, 18)
	if t.x < 0 and from.distance_to(base) > 14.0:
		t = sim.find_resource(base, mask, pi, v.id, 18)
	if t.x >= 0:
		sim.cmd_gather(pi, [v.id], t)
		return true
	if kind == "food" and int(p.res.wood) >= int(Defs.FARM_COST["wood"]):
		var ft := _farm_spot(base)
		if ft.x >= 0:
			return sim.cmd_build(pi, [v.id], "granja", ft) == Sim.OK
	return false

func _farm_spot(base: Vector2i) -> Vector2i:
	for r in range(3, 10):
		var cand: Array = []
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := base + Vector2i(dx, dy)
				if sim.can_place_farm(t):
					cand.append(t)
		if not cand.is_empty():
			return cand[rng.randi() % cand.size()]
	return Vector2i(-1, -1)

# ------------------------------------------------------------------ construcción

func _spot(type: String, base: Vector2i, rmin: int, rmax: int) -> Vector2i:
	for i in 80:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(float(rmin), float(rmax))
		var t := base + Vector2i(int(round(cos(ang) * r)), int(round(sin(ang) * r)))
		if sim.can_place(type, t):
			return t
	return Vector2i(-1, -1)

func _builder_for(p: Player, tile: Vector2i, vills: Array, n: int = 1) -> Array:
	var sorted_v := vills.duplicate()
	var c := sim.tile_center(tile)
	sorted_v.sort_custom(func(a: Ent, b: Ent) -> bool:
		var pa := 0 if (a.state == Sim.S_IDLE) else 1
		var pb := 0 if (b.state == Sim.S_IDLE) else 1
		if pa != pb:
			return pa < pb
		return a.pos.distance_squared_to(c) < b.pos.distance_squared_to(c))
	var out: Array = []
	for v in sorted_v:
		if v.state == Sim.S_BUILD or v.state == Sim.S_BUILD_GO:
			continue
		out.append(v.id)
		if out.size() >= n:
			break
	return out

func _try_build(p: Player, type: String, base: Vector2i, vills: Array, rmin: int, rmax: int, nb: int = 1) -> bool:
	var d: Dictionary = Defs.BUILDINGS[type]
	if p.age < int(d["age"]) or not Defs.can_afford(p.res, d["cost"]):
		return false
	for attempt in 4:
		var t := _spot(type, base, rmin, rmax)
		if t.x < 0:
			return false
		var ids := _builder_for(p, t, vills, nb)
		if ids.is_empty():
			return false
		if sim.cmd_build(pi, ids, type, t) > 0:
			return true
	return false

func _far_store(p: Player, vills: Array, kind: String) -> bool:
	## Si un recolector de `kind` está lejos de cualquier punto de entrega, construye almacén cerca.
	for v in vills:
		if v.state == Sim.S_GATHER and v.carry_kind == kind:
			var d := sim.nearest_dropoff(v)
			if d == null:
				continue
			if d.dist_to(v.pos) > 9.0 * Defs.TILE:
				var vt := sim.tile_of(v.pos)
				for r in range(1, 6):
					for dy in range(-r, r + 1):
						for dx in range(-r, r + 1):
							if maxi(absi(dx), absi(dy)) != r:
								continue
							var t := vt + Vector2i(dx, dy)
							if sim.can_place("almacen", t):
								var ids: Array = [v.id]
								var res := sim.cmd_build(pi, ids, "almacen", t)
								return res > 0
				return false
	return false

func _build(p: Player, vills: Array, base: Vector2i, done: Dictionary, inprog: Dictionary) -> void:
	var n := vills.size()
	if n == 0:
		return
	# Edificios sin terminar y sin constructores: enviar ayuda
	for b in sim.buildings:
		if b.alive and b.owner == pi and b.progress < 1.0 and b.builders == 0:
			var has_builder := false
			for v in vills:
				if v.target_id == b.id and (v.state == Sim.S_BUILD or v.state == Sim.S_BUILD_GO):
					has_builder = true
					break
			if not has_builder:
				var ids := _builder_for(p, b.tile, vills, 1)
				if not ids.is_empty():
					sim.cmd_help_build(pi, ids, b.id)
				break
	# Casas
	var queued := 0
	for b in sim.buildings:
		if b.alive and b.owner == pi:
			queued += b.queue.size()
	var cap := p.pop_cap
	var houses_building := int(inprog.get("casa", 0))
	var margin := 3 + (2 if diff == 2 else 0) + (3 if p.pop > 40 else 0)
	if cap < Defs.MAX_POP and p.pop + queued + margin >= cap + houses_building * 5:
		if houses_building < (2 if p.pop > 30 else 1):
			_try_build(p, "casa", base, vills, 5, 11, 1)
	# Almacén cerca de recursos lejanos
	if store_cd <= 0.0 and int(inprog.get("almacen", 0)) == 0 and int(done.get("almacen", 0)) < 4:
		if int(p.res.wood) >= 100:
			if _far_store(p, vills, "wood") or _far_store(p, vills, "gold"):
				store_cd = 30.0
	# Cuartel y edificios militares
	var barracks_target: int = [1, 2, 3][diff]
	var min_vills: int = [12, 10, 9][diff]
	if n >= min_vills:
		if int(done.get("cuartel", 0)) + int(inprog.get("cuartel", 0)) < (1 if p.age == 0 else barracks_target):
			_try_build(p, "cuartel", base, vills, 6, 13, 2)
		if p.age >= 1:
			var ranges: int = 1 if diff < 2 else 2
			if int(done.get("arqueria", 0)) + int(inprog.get("arqueria", 0)) < ranges:
				_try_build(p, "arqueria", base, vills, 6, 14, 2)
			if int(done.get("establo", 0)) + int(inprog.get("establo", 0)) < ranges:
				_try_build(p, "establo", base, vills, 6, 14, 2)
			# Excedentes de madera y oro: torres de defensa alrededor de la base
			if n >= min_vills + 4 and int(p.res.wood) >= 450 and int(p.res.gold) >= 250 and int(inprog.get("torre", 0)) == 0:
				if int(done.get("torre", 0)) < [1, 2, 4][diff]:
					_try_build(p, "torre", base, vills, 8, 13, 2)

# ------------------------------------------------------------------ entrenamiento y edad

func _age(p: Player, vills: Array, done: Dictionary) -> void:
	if _wants_age(p, vills, done) and not p.aging:
		sim.cmd_age_up(pi)

## true mientras la IA debe guardar comida y oro para subir de edad.
func _saving_for_age(p: Player, vills: Array, done: Dictionary) -> bool:
	return _wants_age(p, vills, done) and not p.aging

## ¿puede gastar `cost` sin retrasar el ascenso de edad?
func _can_spend(p: Player, cost: Dictionary, saving: bool) -> bool:
	if not saving:
		return true
	var ac: Dictionary = Defs.AGES[1]["cost"]
	for k in ac:
		if int(p.res.get(k, 0)) - int(cost.get(k, 0)) < int(ac[k]) and int(cost.get(k, 0)) > 0:
			return false
	return true

func _train(p: Player, vills: Array, done: Dictionary) -> void:
	var n := vills.size()
	var saving := _saving_for_age(p, vills, done)
	var queued_v := 0
	for b in sim.buildings:
		if not (b.alive and b.owner == pi and b.progress >= 1.0):
			continue
		if b.type == "centro":
			for q in b.queue:
				if q == "aldeano":
					queued_v += 1
	for b in sim.buildings:
		if not (b.alive and b.owner == pi and b.progress >= 1.0):
			continue
		var tr: Array = b.def["train"]
		if tr.is_empty():
			continue
		if b.type == "centro":
			if n + queued_v < _vill_target(p) and b.queue.size() < 2 and _can_spend(p, Defs.UNITS["aldeano"]["cost"], saving):
				if sim.cmd_train(pi, b.id, "aldeano") > 0:
					queued_v += 1
		else:
			if n < [12, 10, 9][diff]:
				continue
			if b.queue.size() < 2 and p.pop + p.reserved + b.queue.size() < p.pop_cap and _can_spend(p, Defs.UNITS[tr[0]]["cost"], saving):
				sim.cmd_train(pi, b.id, tr[0])

# ------------------------------------------------------------------ militar

func _my_army_idle(army: Array) -> Array:
	var out: Array = []
	for u in army:
		if u.state == Sim.S_IDLE or (u.state == Sim.S_MOVE and not u.amove):
			out.append(u.id)
	return out

func _pick_target() -> int:
	if target_pi >= 0 and sim.players[target_pi].alive and sim.is_hostile(pi, target_pi):
		return target_pi
	var me: Player = sim.players[pi]
	var best := -1
	var bd := 1e12
	for q in sim.players:
		if q.idx == pi or not q.alive or not sim.is_hostile(pi, q.idx):
			continue
		var d := Vector2(q.start_tile).distance_to(Vector2(me.start_tile))
		if q.is_human:
			d *= 0.6
		if d < bd:
			bd = d
			best = q.idx
	target_pi = best
	return best

func _enemy_building_tile(from: Vector2i, tpi: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 1e12
	for b in sim.buildings:
		if b.alive and b.owner == tpi:
			var d := Vector2(b.tile).distance_to(Vector2(from))
			if b.type == "centro":
				d *= 0.5
			if d < bd:
				bd = d
				best = b.tile + Vector2i(b.size / 2, b.size / 2)
	return best

func _threat_pos(p: Player) -> Vector2:
	var checked := 0
	for b in sim.buildings:
		if not (b.alive and b.owner == pi):
			continue
		if b.type != "centro" and checked >= 3:
			continue
		checked += 1
		for o in sim.query(b.center(), 12.0 * Defs.TILE):
			if (not o.is_building) and sim.is_hostile(pi, o.owner):
				return o.pos
	return Vector2(-1, -1)

func _military(p: Player, army: Array, base: Vector2i) -> void:
	if army.is_empty():
		wave_active = false
		return
	var tp := _pick_target()
	# Defensa
	var thr := _threat_pos(p)
	if thr.x >= 0.0:
		if sim.time - last_defend > 4.0:
			last_defend = sim.time
			var ids: Array = []
			for u in army:
				ids.append(u.id)
			sim.cmd_move(pi, ids, sim.tile_of(thr), true)
		return
	if tp < 0:
		return
	var enemy_tile := _enemy_building_tile(base, tp)
	# Oleada de ataque
	if (not wave_active) and sim.time >= attack_at and army.size() >= need_army and enemy_tile.x >= 0:
		var ids2: Array = []
		for u in army:
			ids2.append(u.id)
		sim.cmd_move(pi, ids2, enemy_tile, true)
		wave_active = true
		wave_start = sim.time
		wave += 1
		need_army += 3
		attack_at = sim.time + [220.0, 160.0, 120.0][diff]
		return
	if wave_active:
		if army.size() < 3 or sim.time - wave_start > 260.0:
			wave_active = false
		elif enemy_tile.x >= 0 and sim.time - wave_start > 25.0:
			# Los ociosos continúan hacia el siguiente edificio enemigo
			var idle_ids: Array = []
			for u in army:
				if u.state == Sim.S_IDLE:
					idle_ids.append(u.id)
			if not idle_ids.is_empty():
				sim.cmd_move(pi, idle_ids, enemy_tile, true)
		return
	# Concentración en punto de reunión
	var dir := Vector2.ZERO
	if enemy_tile.x >= 0:
		dir = (Vector2(enemy_tile) - Vector2(base)).normalized()
	var rally := sim.nearest_free_tile(base + Vector2i(int(dir.x * 10.0), int(dir.y * 10.0)), 6)
	var gather_ids: Array = []
	for u in army:
		if u.state == Sim.S_IDLE and Vector2(sim.tile_of(u.pos)).distance_to(Vector2(rally)) > 8.0:
			gather_ids.append(u.id)
	if not gather_ids.is_empty():
		sim.cmd_move(pi, gather_ids, rally, false)
