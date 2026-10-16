class_name AiPlayer
extends RefCounted
## IA por guion (local, sin red ni modelos): economía con ratios, orden de
## construcción, subida de edad, producción militar y oleadas con temporizador.

var sim: Sim
var pi: int
var diff: int
var acc: float = 0.0
var interval: float = 1.0
var attack_at: float = 600.0          # no antes de este instante de partida (s)
var need_army: int = 22               # soldados mínimos para lanzar la oleada
var wave_gap: float = 240.0           # pausa entre una oleada y la siguiente
var wave: int = 0
var wave_active: bool = false
var wave_start: float = 0.0
var wave_ids: Array = []              # ids de los soldados de la oleada en curso (el resto es la reserva que defiende)
var wave_n0: int = 0
var target_pi: int = -1
var last_defend: float = -100.0
var last_reinf: float = -100.0
var raid_ids: Array = []              # jinetes que hostigan a los aldeanos del enemigo
var raid_at: float = 900.0
var raid_start: float = 0.0
var navy_at: float = 700.0
var navy_start: float = 0.0
var navy_out: bool = false
var exp_cd: float = 0.0               # espera entre intentos de ampliar con otro centro urbano
var mix: Dictionary = {}              # tipo enemigo -> cuántos se han visto cerca (elegir contrarios)
var mix_t: float = -100.0
var store_cd: float = 0.0
var port_cd: float = 0.0              # espera entre búsquedas de sitio de puerto
var port_spot_cache := Vector2i(-2, -2)
var reserve: Dictionary = {}          # recursos que el entrenamiento no debe gastar (próximo edificio de la 3ª edad)
var assign_fail: Dictionary = {}      # recurso -> instante hasta el que no se repite una búsqueda fallida (partidas largas)
var rng := RandomNumberGenerator.new()
const LIMITED := ["ariete", "catapulta", "trabuquete", "monje"]   # tipos que la IA no acumula sin límite

func _init(s: Sim, idx: int, d: int) -> void:
	sim = s
	pi = idx
	diff = clampi(d, 0, 2)
	interval = [1.4, 1.0, 0.7][diff]
	rng.seed = s.rng.seed + idx * 131
	# Ritmo de la IA (medido con tools/rush_probe.gd contra un jugador que no hace nada): antes (build-21) el primer
	# enemigo llegaba a ~13,5 min en Fácil, ~11 en Normal y ~9-10 en Difícil con 30-45 soldados rivales; un jugador que
	# aprende no llega a eso. Ahora la primera oleada llega a ~26 / ~17 / ~11 min y, mientras no ataca, la IA no acumula
	# más soldados de los necesarios (ver `_army_cap`), así que la primera oleada tiene el tamaño previsto y no uno enorme.
	attack_at = [1500.0, 1000.0, 660.0][diff] + rng.randf_range(0.0, 50.0)
	need_army = [10, 18, 26][diff]
	wave_gap = [420.0, 300.0, 200.0][diff]
	raid_at = [1e9, 1260.0, 840.0][diff] + rng.randf_range(0.0, 60.0)
	navy_at = [1e9, 1000.0, 660.0][diff] + rng.randf_range(0.0, 40.0)
	acc = rng.randf() * interval

## Soldados que la IA llega a juntar mientras espera para atacar (sin límite en Difícil).
func _army_cap() -> int:
	return [need_army + 6, need_army + 14, 100000][diff]

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
	var boats: Array = []
	var navy: Array = []
	for u in sim.units:
		if u.alive and u.owner == pi:
			if u.type == "aldeano":
				vills.append(u)
			elif u.naval:
				if bool(u.def.get("fisher", false)):
					boats.append(u)
				elif u.is_military():
					navy.append(u)
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
	port_cd = maxf(0.0, port_cd - interval)
	exp_cd = maxf(0.0, exp_cd - interval)
	var t0 := 0
	if sim.profiling:
		t0 = Time.get_ticks_usec()
	if sim.time - mix_t > 6.0:
		_scan_mix(base, army)
	t0 = _pt("ai_mix", t0)
	_economy(p, vills, base, done, inprog)
	t0 = _pt("ai_economy", t0)
	_fishing(p, boats)
	t0 = _pt("ai_fishing", t0)
	_build(p, vills, base, done, inprog)
	_plan_reserve(p, vills, done, inprog)
	t0 = _pt("ai_build", t0)
	_expand(p, vills, base, done, inprog)
	t0 = _pt("ai_expand", t0)
	_train(p, vills, done, boats, navy, army)
	t0 = _pt("ai_train", t0)
	_age(p, vills, done)
	_military(p, army, base)
	_ability(p, vills, army, base)
	t0 = _pt("ai_military", t0)
	_naval(p, navy)
	_pt("ai_naval", t0)

## Mide cuánto tarda cada parte del pensamiento de la IA (sólo con sim.profiling).
func _pt(key: String, t0: int) -> int:
	if not sim.profiling:
		return 0
	var now := Time.get_ticks_usec()
	sim.prof[key] = int(sim.prof.get(key, 0)) + (now - t0)
	return now

# ------------------------------------------------------------------ economía

func _vill_target(p: Player) -> int:
	var t: int = [24, 34, 46][diff]
	if p.age >= 1:
		t += 10
	return t

func _wants_age(p: Player, vills: Array, done: Dictionary) -> bool:
	if p.age == 0:
		return int(done.get("cuartel", 0)) >= 1 and vills.size() >= [24, 20, 16][diff]
	if p.age == 1 and diff >= 1 and p.age < Defs.AGES.size() - 1:
		# Edad de los Castillos: con una economía ya grande y al menos 2 tipos de edificio militar
		return vills.size() >= [0, 36, 30][diff] and p.pop >= [0, 90, 75][diff] and sim.military_kinds_done(pi) >= int(Defs.AGES[2].get("need_mil", 0))
	return false

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
	# Comida lejana: los aldeanos que siguen bayas a decenas de casillas del centro (la
	# recolección automática salta de arbusto en arbusto) pasan a granjas junto a la base.
	if int(p.res.wood) >= int(Defs.FARM_COST["wood"]):
		for v in vills:
			if v.carry_kind != "food" or v.carry_amt >= 3.0 or v.target_tile.x < 0:
				continue
			if v.state != Sim.S_GATHER and v.state != Sim.S_GATHER_GO:
				continue
			if sim.rtype[v.target_tile.y * sim.W + v.target_tile.x] != Defs.R_BERRY:
				continue
			if Vector2(v.target_tile - base).length() > 20.0:
				var ft := _farm_spot(base)
				if ft.x >= 0:
					sim.cmd_build(pi, [v.id], "granja", ft)
				break

func _assign(p: Player, v: Ent, kind: String, base: Vector2i) -> bool:
	if sim.time < float(assign_fail.get(kind, -1.0)):
		return false
	var mask := sim.res_mask_for(kind)
	var from := sim.tile_of(v.pos)
	var t := sim.find_resource(from, mask, pi, v.id, 18)
	if t.x < 0 and from.distance_to(base) > 14.0:
		t = sim.find_resource(base, mask, pi, v.id, 18)
	# Comida: si lo más cercano está lejos de la base (bayas a decenas de casillas, caminata
	# larga y expuesta), es mejor una granja junto al centro urbano.
	var far_food := kind == "food" and t.x >= 0 and Vector2(t - base).length() > 20.0
	if t.x >= 0 and not far_food:
		sim.cmd_gather(pi, [v.id], t)
		return true
	if kind == "food" and int(p.res.wood) >= int(Defs.FARM_COST["wood"]):
		var ft := _farm_spot(base)
		if ft.x >= 0 and sim.cmd_build(pi, [v.id], "granja", ft) == Sim.OK:
			return true
	if t.x >= 0:
		sim.cmd_gather(pi, [v.id], t)
		return true
	assign_fail[kind] = sim.time + (5.0 if kind == "food" else 12.0)
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
		if sim.can_place(type, t) and _spaced(type, t):
			return t
	return Vector2i(-1, -1)

## Deja una casilla libre alrededor de cada edificio: así las casas no forman una muralla (ni siquiera
## tocándose por las esquinas) que deje a los aldeanos encerrados en un rincón de su propia base.
func _spaced(type: String, t: Vector2i) -> bool:
	var size: int = Defs.BUILDINGS[type]["size"]
	for dy in range(-1, size + 1):
		for dx in range(-1, size + 1):
			var q := t + Vector2i(dx, dy)
			if sim.in_bounds(q) and sim.occ[q.y * sim.W + q.x] != 0:
				return false
	return true

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
			# Corona llena (granjas, bosque, costa): se amplía el anillo antes de rendirse.
			t = _spot(type, base, rmax, rmax + 8)
		if t.x < 0:
			return false
		var ids := _builder_for(p, t, vills, nb)
		if ids.is_empty():
			return false
		if sim.cmd_build(pi, ids, type, t) > 0:
			return true
	return false

## Busca en la costa próxima un sitio de puerto desde el que se llegue a peces y lo construye.
func _try_port(p: Player, base: Vector2i, vills: Array) -> void:
	port_cd = 45.0
	var best := Vector2i(-1, -1)
	var bd := 1e9
	var from := sim.nearest_free_tile(base + Vector2i(0, 3), 6)
	for r in range(4, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := base + Vector2i(dx, dy)
				if not sim.in_bounds(t) or not sim.can_place("puerto", t) or not _spaced("puerto", t):
					continue
				var d := Vector2(dx, dy).length()
				if d >= bd:
					continue
				var di := sim.dock_info(t, 3)
				if sim.find_fish(di["spawn"], 18).x < 0:
					continue
				if not sim.can_reach_building(from, "puerto", t):
					continue
				bd = d
				best = t
		if best.x >= 0:
			break
	if best.x < 0:
		port_cd = 120.0
		return
	var ids := _builder_for(p, best, vills, 2)
	if not ids.is_empty():
		sim.cmd_build(pi, ids, "puerto", best)

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
	var grow := (1 if p.pop >= 90 else 0) + (1 if p.pop >= 150 else 0)     # más producción cuando la economía da para ello
	var barracks_target: int = [2, 3, 4][diff] + grow
	var min_vills: int = [12, 10, 9][diff]
	if n >= min_vills:
		if int(done.get("cuartel", 0)) + int(inprog.get("cuartel", 0)) < (1 if p.age == 0 else barracks_target):
			_try_build(p, "cuartel", base, vills, 6, 13, 2)
		if p.age >= 1 and diff >= 1 and n >= min_vills + 6:
			if int(done.get("taller", 0)) + int(inprog.get("taller", 0)) < 1 + (1 if (diff == 2 and p.pop >= 120) else 0) and int(p.res.wood) >= 320:
				_try_build(p, "taller", base, vills, 7, 14, 2)
		# Puerto: sólo si hay costa con peces cerca (la comida del mar libera aldeanos de las granjas)
		if n >= min_vills + 3 and port_cd <= 0.0 and int(done.get("puerto", 0)) + int(inprog.get("puerto", 0)) < 1 and int(p.res.wood) >= 220:
			_try_port(p, base, vills)
		if p.age >= 1:
			var ranges: int = [1, 2, 2][diff] + grow
			if int(done.get("arqueria", 0)) + int(inprog.get("arqueria", 0)) < ranges:
				_try_build(p, "arqueria", base, vills, 6, 14, 2)
			if int(done.get("establo", 0)) + int(inprog.get("establo", 0)) < ranges:
				_try_build(p, "establo", base, vills, 6, 14, 2)
			# Edad de los Castillos: monasterio (monjes) y castillo (trabuquetes y defensa fuerte)
			var nb := _next_castle_building(p, done, inprog)
			if nb == "monasterio":
				_try_build(p, "monasterio", base, vills, 7, 15, 2)
			elif nb == "castillo":
				_try_build(p, "castillo", base, vills, 9, 16, 3)
			# Excedentes de madera y oro: torres de defensa alrededor de la base
			if n >= min_vills + 4 and int(p.res.wood) >= 450 and int(p.res.gold) >= 250 and int(inprog.get("torre", 0)) == 0:
				if int(done.get("torre", 0)) < [2, 4, 6][diff]:
					_try_build(p, "torre", base, vills, 8, 14, 2)

# ------------------------------------------------------------------ ampliación

## Número de casillas con árboles, oro o bayas en un cuadrado de lado 2r+1 (para elegir dónde ampliar).
func _res_score(t: Vector2i, r: int) -> int:
	var n := 0
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := t + Vector2i(dx, dy)
			if sim.in_bounds(q):
				var rt := sim.rtype[q.y * sim.W + q.x]
				if rt == Defs.R_TREE or rt == Defs.R_GOLD or rt == Defs.R_BERRY:
					n += 1
	return n

## Otro centro urbano junto a recursos nuevos cuando la base ya es grande (y reconstruir el centro si lo pierde):
## más aldeanos entrenando, más población y recursos que no se agotan en partidas largas.
func _expand(p: Player, vills: Array, base: Vector2i, done: Dictionary, inprog: Dictionary) -> void:
	if exp_cd > 0.0 or vills.is_empty():
		return
	var tcs := int(done.get("centro", 0)) + int(inprog.get("centro", 0))
	if int(inprog.get("centro", 0)) > 0:
		return
	var cost: Dictionary = Defs.BUILDINGS["centro"]["cost"]
	if tcs == 0:
		# Sin centro urbano: se reconstruye en cuanto se pueda pagar
		if Defs.can_afford(p.res, cost):
			exp_cd = 20.0
			_try_build(p, "centro", base, vills, 3, 12, 3)
		return
	if diff == 0 or p.age < 1 or tcs >= [1, 2, 3][diff] or vills.size() < 28 or p.pop < 70:
		return
	if int(p.res.wood) < int(cost["wood"]) + 150 or int(p.res.gold) < int(cost["gold"]) + 50:
		return
	exp_cd = 60.0
	var from := sim.nearest_free_tile(base + Vector2i(0, 3), 6)
	var best := Vector2i(-1, -1)
	var bs := 0
	for i in 40:
		var ang := rng.randf() * TAU
		var r := rng.randf_range(17.0, 32.0)
		var t := base + Vector2i(int(round(cos(ang) * r)), int(round(sin(ang) * r)))
		if not sim.in_bounds(t) or not sim.can_place("centro", t) or not _spaced("centro", t):
			continue
		var sc := _res_score(t, 8)
		if sc > bs:
			bs = sc
			best = t
	if best.x < 0 or bs < 14 or not sim.can_reach_building(from, "centro", best):
		exp_cd = 120.0
		return
	var ids := _builder_for(p, best, vills, 3)
	if not ids.is_empty():
		sim.cmd_build(pi, ids, "centro", best)

# ------------------------------------------------------------------ elegir contrarios

## Mira qué soldados enemigos hay cerca de mis edificios y de mi ejército (sólo lo que está a su alcance).
func _scan_mix(base: Vector2i, army: Array) -> void:
	mix_t = sim.time
	var tally := {}
	var seen := {}
	var anchors: Array[Vector2] = []
	var cnt := 0
	for b in sim.buildings:
		if b.alive and b.owner == pi and (b.type == "centro" or cnt < 3):
			anchors.append(b.center())
			cnt += 1
	if not army.is_empty():
		anchors.append(army[0].pos)
		anchors.append(army[army.size() - 1].pos)
	for a in anchors:
		for o in sim.query(a, 18.0 * Defs.TILE):
			if o.alive and not o.is_building and not o.naval and o.is_military() and sim.is_hostile(pi, o.owner) and not seen.has(o.id):
				seen[o.id] = true
				tally[o.type] = int(tally.get(o.type, 0)) + 1
	var merged := {}
	for k in mix:
		merged[k] = float(mix[k]) * 0.6          # la memoria se desvanece
	for k in tally:
		merged[k] = float(merged.get(k, 0.0)) + float(tally[k])
	mix = merged

static func _bonus(a: String, b: String) -> float:
	return Defs.bonus(a, b)

## >1 si este tipo de soldado rinde bien contra lo que se ha visto del enemigo, <1 si rinde mal.
func _counter_score(ut: String) -> float:
	if diff == 0 or mix.is_empty():
		return 1.0
	var tot := 0.0
	var sc := 0.0
	for et: String in mix:
		var c := float(mix[et])
		if c < 0.5:
			continue
		sc += c * _bonus(ut, et) / maxf(0.6, _bonus(et, ut))
		tot += c
	if tot < 3.0:
		return 1.0
	return pow(clampf(sc / tot, 0.5, 2.5), 1.3 if diff == 2 else 0.7)

# ------------------------------------------------------------------ entrenamiento y edad

func _age(p: Player, vills: Array, done: Dictionary) -> void:
	if _wants_age(p, vills, done) and not p.aging:
		sim.cmd_age_up(pi)

## true mientras la IA debe guardar comida y oro para subir de edad.
func _saving_for_age(p: Player, vills: Array, done: Dictionary) -> bool:
	return _wants_age(p, vills, done) and not p.aging

## Próximo edificio de la Edad de los Castillos que le falta a la IA ("" si ya tiene los que quiere).
func _next_castle_building(p: Player, done: Dictionary, inprog: Dictionary) -> String:
	if p.age < 2 or diff < 1:
		return ""
	var want_m := 2 if (diff == 2 and p.pop >= 150) else 1
	if int(done.get("monasterio", 0)) + int(inprog.get("monasterio", 0)) < want_m:
		return "monasterio"
	var want_c := 2 if (diff == 2 and p.pop >= 170) else 1
	if int(done.get("castillo", 0)) + int(inprog.get("castillo", 0)) < want_c:
		return "castillo"
	return ""

## Guarda el coste del próximo edificio de la 3ª edad: sin esto el entrenamiento de unidades gastaba la madera y el oro
## en cuanto entraban y la IA no llegaba nunca a reunir lo necesario (medido: 0 monasterios y 0 castillos en 20 min).
func _plan_reserve(p: Player, vills: Array, done: Dictionary, inprog: Dictionary) -> void:
	reserve = {}
	if vills.size() < [12, 10, 9][diff] + 6:
		return
	var nb := _next_castle_building(p, done, inprog)
	if nb != "":
		reserve = (Defs.BUILDINGS[nb]["cost"] as Dictionary).duplicate()

## ¿puede gastar `cost` sin retrasar el ascenso de edad ni el próximo edificio planeado?
func _can_spend(p: Player, cost: Dictionary, saving: bool) -> bool:
	for k in reserve:
		if int(cost.get(k, 0)) > 0 and int(p.res.get(k, 0)) - int(cost.get(k, 0)) < int(reserve[k]):
			return false
	if not saving:
		return true
	var ac: Dictionary = sim.age_cost(pi, mini(p.age + 1, Defs.AGES.size() - 1))
	for k in ac:
		if int(p.res.get(k, 0)) - int(cost.get(k, 0)) < int(ac[k]) and int(cost.get(k, 0)) > 0:
			return false
	return true

## Elige qué soldado entrenar en un edificio (mezcla de contrarios, sólo lo que se puede pagar y permite la edad).
## `cnt` = cuántos hay (en pie o en cola) de los tipos que se limitan: ariete, catapulta, trabuquete, monje.
func _pick_unit(b: Ent, p: Player, cnt: Dictionary) -> String:
	var opts: Array = []        # [tipo, peso]
	var a := p.age
	match b.type:
		"cuartel":
			if a == 0:
				opts = [["piquero", 1.0]]
			elif a == 1:
				opts = [["piquero", 0.55], ["espadachin", 0.45]]
			else:
				opts = [["piquero", 0.15], ["espadachin", 0.35], ["alabardero", 0.50]]
		"arqueria":
			if a <= 1:
				opts = [["arquero", 0.6], ["ballestero", 0.4]]
			else:
				opts = [["arquero", 0.30], ["ballestero", 0.20], ["hostigador", 0.25], ["arquero_caballo", 0.25]]
		"establo":
			opts = [["jinete", 0.5], ["caballero", 0.5]]
		"taller":
			opts = [["ariete", 1.0 if int(cnt.get("ariete", 0)) < [1, 2, 4][diff] else 0.0]]
			if a >= 2:
				opts.append(["catapulta", 1.2 if int(cnt.get("catapulta", 0)) < [0, 2, 4][diff] else 0.0])
		"monasterio":
			opts = [["monje", 1.0 if int(cnt.get("monje", 0)) < [1, 3, 5][diff] else 0.0]]
		"castillo":
			opts = [["trabuquete", 1.0 if int(cnt.get("trabuquete", 0)) < [0, 1, 3][diff] else 0.0]]
			var uq := Civs.unique_of(p.civ)
			if uq != "":
				opts.append([uq, 3.0])          # la unidad única de su civilización es lo que más entrena el castillo
		_:
			var tr: Array = b.def["train"]
			opts = [[tr[0], 1.0]]
	var total := 0.0
	var ok: Array = []
	for o in opts:
		var ud: Dictionary = Defs.UNITS[o[0]]
		if float(o[1]) > 0.0 and p.age >= int(ud["age"]) and Defs.can_afford(p.res, sim.unit_cost(pi, o[0])):
			var w := float(o[1]) * _counter_score(o[0])
			ok.append([o[0], w])
			total += w
	if ok.is_empty():
		return ""
	var r := rng.randf() * total
	for o in ok:
		r -= float(o[1])
		if r <= 0.0:
			return o[0]
	return ok[0][0]

func _train(p: Player, vills: Array, done: Dictionary, boats: Array, navy: Array, army: Array) -> void:
	var n := vills.size()
	var saving := _saving_for_age(p, vills, done)
	var queued_v := 0
	var queued_boats := 0
	var queued_ships := 0
	var cnt := {}
	for u in army:
		if LIMITED.has(u.type):
			cnt[u.type] = int(cnt.get(u.type, 0)) + 1
	for b in sim.buildings:
		if not (b.alive and b.owner == pi and b.progress >= 1.0):
			continue
		for q in b.queue:
			if b.type == "centro" and q == "aldeano":
				queued_v += 1
			elif q == "barco_pesca":
				queued_boats += 1
			elif q == "galera" or q == "galeon":
				queued_ships += 1
			elif LIMITED.has(q):
				cnt[q] = int(cnt.get(q, 0)) + 1
	for b in sim.buildings:
		if not (b.alive and b.owner == pi and b.progress >= 1.0):
			continue
		var tr: Array = b.def["train"]
		if tr.is_empty():
			continue
		if b.type == "centro":
			if n + queued_v < _vill_target(p) and b.queue.size() < 2 and _can_spend(p, sim.unit_cost(pi, "aldeano"), saving):
				if sim.cmd_train(pi, b.id, "aldeano") > 0:
					queued_v += 1
		elif b.type == "puerto":
			if n < [12, 10, 9][diff] or b.queue.size() >= 2 or p.pop + p.reserved + b.queue.size() >= p.pop_cap:
				continue
			var want_boats: int = [2, 3, 4][diff] + (1 if p.age >= 1 else 0)
			if boats.size() + queued_boats < want_boats and sim.find_fish(b.dock_tile, 18).x >= 0 and _can_spend(p, sim.unit_cost(pi, "barco_pesca"), saving):
				if sim.cmd_train(pi, b.id, "barco_pesca") > 0:
					queued_boats += 1
			elif p.age >= 1 and navy.size() + queued_ships < [1, 2, 3][diff] and not saving:
				var ship := "galeon" if (diff == 2 and navy.size() >= 2 and Defs.can_afford(p.res, sim.unit_cost(pi, "galeon"))) else "galera"
				if Defs.can_afford(p.res, sim.unit_cost(pi, ship)) and sim.cmd_train(pi, b.id, ship) > 0:
					queued_ships += 1
		else:
			if n < [12, 10, 9][diff]:
				continue
			if not wave_active and army.size() >= _army_cap():
				continue
			if b.queue.size() < 2 and p.pop + p.reserved + b.queue.size() < p.pop_cap:
				var ut := _pick_unit(b, p, cnt)
				if ut != "" and _can_spend(p, sim.unit_cost(pi, ut), saving):
					if sim.cmd_train(pi, b.id, ut) > 0 and LIMITED.has(ut):
						cnt[ut] = int(cnt.get(ut, 0)) + 1

## Los barcos de pesca ociosos buscan peces solos.
func _fishing(p: Player, boats: Array) -> void:
	for bt in boats:
		if bt.state != Sim.S_IDLE:
			continue
		var t := sim.find_fish(sim.tile_of(bt.pos), 18)
		if t.x >= 0:
			sim.cmd_gather(pi, [bt.id], t)

# ------------------------------------------------------------------ militar

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
			elif b.type == "muralla" or b.type == "puerta":
				d *= 3.0          # primero lo que importa, no los tramos de muralla
			if d < bd:
				bd = d
				best = b.tile + Vector2i(b.size / 2, b.size / 2)
	return best

## Enemigos (de a pie o a caballo) cerca de mis edificios: cuántos y dónde.
func _threat() -> Dictionary:
	var checked := 0
	var seen := {}
	var pos := Vector2(-1, -1)
	for b in sim.buildings:
		if not (b.alive and b.owner == pi):
			continue
		if b.type != "centro" and checked >= 3:
			continue
		checked += 1
		for o in sim.query(b.center(), 12.0 * Defs.TILE):
			if (not o.is_building) and (not o.naval) and sim.is_hostile(pi, o.owner) and not seen.has(o.id):
				seen[o.id] = true
				if pos.x < 0.0:
					pos = o.pos
	return {"pos": pos, "n": seen.size()}

func _rally_tile(base: Vector2i, enemy_tile: Vector2i) -> Vector2i:
	var dir := Vector2.ZERO
	if enemy_tile.x >= 0:
		dir = (Vector2(enemy_tile) - Vector2(base)).normalized()
	return sim.nearest_free_tile(base + Vector2i(int(dir.x * 10.0), int(dir.y * 10.0)), 6)

func _military(p: Player, army: Array, base: Vector2i) -> void:
	# Los de la oleada que siguen vivos
	if not wave_ids.is_empty():
		var alive: Array = []
		for id in wave_ids:
			var e: Ent = sim.ents.get(id)
			if e != null and e.alive and not e.is_building:
				alive.append(id)
		wave_ids = alive
	if army.is_empty():
		wave_active = false
		wave_ids = []
		raid_ids = []
		return
	var tp := _pick_target()
	var in_wave := {}
	for id in wave_ids:
		in_wave[id] = true
	var reserve: Array = []              # los que se quedan en casa y defienden
	for u in army:
		if not in_wave.has(u.id):
			reserve.append(u)
	# --- Defensa: la reserva sale al encuentro; si la amenaza es mayor, también los de la oleada que aún están cerca
	var thr := _threat()
	if int(thr["n"]) > 0:
		if sim.time - last_defend > 3.0:
			last_defend = sim.time
			var ids: Array = []
			for u in reserve:
				ids.append(u.id)
			if int(thr["n"]) > reserve.size():
				for u in army:
					if in_wave.has(u.id) and (sim.time - wave_start < 40.0 or Vector2(sim.tile_of(u.pos)).distance_to(Vector2(base)) < 28.0):
						ids.append(u.id)
			if not ids.is_empty():
				sim.cmd_move(pi, ids, sim.tile_of(thr["pos"]), true)
		return
	if tp < 0:
		return
	var enemy_tile := _enemy_building_tile(base, tp)
	_raid(p, reserve, tp, base)
	# --- Oleada en curso
	if wave_active:
		var weak := wave_ids.size() < maxi(4, int(float(wave_n0) * 0.35))
		if weak or sim.time - wave_start > 480.0 or enemy_tile.x < 0:
			# Retirada: los supervivientes vuelven a casa y la siguiente oleada será mayor
			if not wave_ids.is_empty():
				sim.cmd_move(pi, wave_ids, _rally_tile(base, enemy_tile), false)
			wave_active = false
			wave_ids = []
			attack_at = sim.time + wave_gap
			need_army = mini(need_army + [4, 6, 8][diff], 90)
			return
		# Segunda línea: la reserva sobrante refuerza a los que están luchando
		if sim.time - last_reinf > 25.0 and reserve.size() >= 10:
			last_reinf = sim.time
			var keep := reserve.size() / 3
			var ids2: Array = []
			var k := 0
			for u in reserve:
				k += 1
				if k > keep and u.state == Sim.S_IDLE:
					ids2.append(u.id)
					wave_ids.append(u.id)
			if not ids2.is_empty():
				sim.cmd_move(pi, ids2, enemy_tile, true)
		# Los ociosos continúan hacia el siguiente edificio enemigo
		if sim.time - wave_start > 25.0:
			var idle_ids: Array = []
			for u in army:
				if in_wave.has(u.id) and u.state == Sim.S_IDLE:
					idle_ids.append(u.id)
			if not idle_ids.is_empty():
				sim.cmd_move(pi, idle_ids, enemy_tile, true)
		return
	# --- Lanzar una oleada: todos menos una cuarta parte, que se queda defendiendo
	var full := p.pop >= p.pop_cap - 2 and p.pop_cap >= 100          # no se puede crecer más: hay que pelear
	if sim.time >= attack_at and enemy_tile.x >= 0 and (army.size() >= need_army or (full and army.size() >= 12)):
		var attackers: Array = []
		var sorted_a := army.duplicate()
		sorted_a.sort_custom(func(a: Ent, b: Ent) -> bool: return a.id < b.id)
		var j := 0
		for u in sorted_a:
			j += 1
			if j % 4 != 0 or army.size() < 16:
				attackers.append(u.id)
		wave_ids = attackers
		wave_n0 = attackers.size()
		sim.cmd_move(pi, attackers, enemy_tile, true)
		wave_active = true
		wave_start = sim.time
		last_reinf = sim.time
		wave += 1
		return
	# --- Concentración en el punto de reunión
	var rally := _rally_tile(base, enemy_tile)
	var gather_ids: Array = []
	for u in reserve:
		if u.state == Sim.S_IDLE and Vector2(sim.tile_of(u.pos)).distance_to(Vector2(rally)) > 8.0:
			gather_ids.append(u.id)
	if not gather_ids.is_empty():
		sim.cmd_move(pi, gather_ids, rally, false)

## Habilidad de civilización: la IA (normal y difícil) la usa cuando sirve — bonos con el ejército peleando, recursos y
## refuerzos en cuanto estén listos, fuego sobre el grupo enemigo más denso que tenga cerca de su gente.
func _ability(p: Player, vills: Array, army: Array, base: Vector2i) -> void:
	if diff == 0 or p.civ == "" or p.age < 1 or sim.time < p.abil_ready:
		return
	var ab: Dictionary = Civs.ability_of(p.civ)
	match String(ab["kind"]):
		"buff", "reveal":
			var fighting := 0
			for u in army:
				if u.state == Sim.S_ATTACK or u.state == Sim.S_ATTACK_GO:
					fighting += 1
			if fighting >= maxi(6, army.size() / 3):
				sim.cmd_ability(pi)
		"lump":
			if vills.size() >= 14:
				sim.cmd_ability(pi)
		"spawn":
			if p.pop + 5 <= p.pop_cap - p.reserved and army.size() >= 6:
				sim.cmd_ability(pi)
		"fire":
			var tile := _fire_target(army, base)
			if tile.x >= 0:
				sim.cmd_ability(pi, tile)

## Casilla donde más enemigos están a la vez junto a mi ejército o mi base (>= 5 soldados), o (-1,-1).
func _fire_target(army: Array, base: Vector2i) -> Vector2i:
	var anchors: Array[Vector2] = [sim.tile_center(base)]
	for i in mini(army.size(), 6):
		anchors.append((army[i] as Ent).pos)
	var best := Vector2i(-1, -1)
	var best_n := 4
	var seen := {}
	for a in anchors:
		for o in sim.query(a, 14.0 * Defs.TILE):
			if not o.alive or o.is_building or o.naval or not o.is_military() or not sim.is_hostile(pi, o.owner) or seen.has(o.id):
				continue
			seen[o.id] = true
			var n := 0
			for q in sim.query(o.pos, 2.4 * Defs.TILE):
				if not q.is_building and q.alive and sim.is_hostile(pi, q.owner):
					n += 1
			if n > best_n:
				best_n = n
				best = sim.tile_of(o.pos)
	return best

## Hostigamiento: unos cuantos jinetes de la reserva caen sobre los aldeanos del enemigo y vuelven.
func _raid(p: Player, reserve: Array, tp: int, base: Vector2i) -> void:
	if not raid_ids.is_empty():
		var alive: Array = []
		for id in raid_ids:
			var e: Ent = sim.ents.get(id)
			if e != null and e.alive:
				alive.append(id)
		raid_ids = alive
		if raid_ids.size() < 2 or sim.time - raid_start > 90.0:
			if not raid_ids.is_empty():
				sim.cmd_move(pi, raid_ids, _rally_tile(base, Vector2i(-1, -1)), false)
			raid_ids = []
			raid_at = sim.time + [1e9, 300.0, 220.0][diff]
		return
	if sim.time < raid_at or p.age < 1 or wave_active:
		return
	var riders: Array = []
	for u in reserve:
		if (u.type == "jinete" or u.type == "caballero") and u.state == Sim.S_IDLE:
			riders.append(u.id)
	if riders.size() < 5:
		return
	var from := Vector2(base) * float(Defs.TILE)
	var victim: Ent = null
	var bd := 1e12
	for u in sim.units:
		if u.alive and u.owner == tp and u.type == "aldeano":
			var d := u.pos.distance_squared_to(from)
			if d < bd:
				bd = d
				victim = u
	if victim == null:
		return
	riders = riders.slice(0, 8)
	raid_ids = riders
	raid_start = sim.time
	sim.cmd_move(pi, riders, sim.tile_of(victim.pos), true)

## Armada: unas galeras salen a cazar los barcos (o el puerto) del enemigo y regresan.
func _naval(p: Player, navy: Array) -> void:
	if navy.size() < 2:
		navy_out = false
		return
	var ids: Array = []
	for u in navy:
		ids.append(u.id)
	if navy_out:
		if sim.time - navy_start > 100.0:
			navy_out = false
			navy_at = sim.time + [1e9, 240.0, 170.0][diff]
			var home := Vector2i(-1, -1)
			for b in sim.buildings:
				if b.alive and b.owner == pi and b.type == "puerto" and b.progress >= 1.0:
					home = b.dock_tile
					break
			if home.x >= 0:
				sim.cmd_move(pi, ids, home, false)
		return
	if sim.time < navy_at or p.age < 1:
		return
	var tp := _pick_target()
	if tp < 0:
		return
	var tile := Vector2i(-1, -1)
	var bd := 1e12
	var from := Vector2(navy[0].pos)
	for u in sim.units:
		if u.alive and u.naval and u.owner == tp:
			var d := u.pos.distance_squared_to(from)
			if d < bd:
				bd = d
				tile = sim.tile_of(u.pos)
	if tile.x < 0:
		for b in sim.buildings:
			if b.alive and b.owner == tp and b.type == "puerto" and b.progress >= 1.0:
				tile = b.dock_tile
				break
	if tile.x < 0:
		navy_at = sim.time + 90.0
		return
	navy_out = true
	navy_start = sim.time
	sim.cmd_move(pi, ids, tile, true)
