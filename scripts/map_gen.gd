class_name MapGen
extends RefCounted
## Generador de mapas con continentes, islas y océano.
## Garantiza que todas las bases iniciales estén en la misma masa de tierra
## (comprobado con flood fill); si no, reintenta con otra semilla.

# Parámetros de forma del mundo (ajustables para pruebas)
static var freq_k := 3.4
static var bias_base := 0.45
static var fall_k := 1.8
static var fall_pow := 3.5
static var rad_k := 0.25

static func generate(size: int, seed_value: int, n_players: int) -> Dictionary:
	var last: Dictionary = {}
	for attempt in 60:
		var sd := seed_value + attempt * 7919
		last = _try(size, sd, n_players, attempt)
		if last.get("ok", false):
			last["seed_used"] = sd
			last["attempts"] = attempt + 1
			return last
	push_error("MapGen: no se pudo generar un mapa válido")
	last["seed_used"] = seed_value
	last["attempts"] = 60
	return last

static func _try(size: int, sd: int, n: int, attempt: int) -> Dictionary:
	var total := size * size
	var noise := FastNoiseLite.new()
	noise.seed = sd
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = freq_k / float(size)
	# A partir de cierto número de intentos, forzamos un continente más grande
	var bias := bias_base + 0.01 * attempt
	var half := size * 0.5
	var land := PackedByteArray()
	land.resize(total)
	var land_count := 0
	for y in size:
		for x in size:
			var nx := absf((x + 0.5) / half - 1.0)
			var ny := absf((y + 0.5) / half - 1.0)
			var e := maxf(nx, ny)
			var rad := sqrt(nx * nx + ny * ny) / 1.4142
			var v := noise.get_noise_2d(x, y) + bias - fall_k * pow(e, fall_pow) - rad_k * rad
			if v > 0.0:
				land[y * size + x] = 1
				land_count += 1
	# Islas extra: manchas de tierra en mar abierto, lejos de la costa y de los bordes
	var irng := RandomNumberGenerator.new()
	irng.seed = sd + 55
	var dl0 := _bfs_dist(land, size, 0, false)
	var extra := maxi(4, size / 30)
	var placed_isl := 0
	var isl_tries := 0
	var isl_centers: Array[Vector2i] = []
	while placed_isl < extra and isl_tries < extra * 40:
		isl_tries += 1
		var ix := irng.randi_range(12, size - 13)
		var iy := irng.randi_range(12, size - 13)
		if dl0[iy * size + ix] < 9:
			continue
		var close := false
		for c in isl_centers:
			if Vector2(c).distance_to(Vector2(ix, iy)) < 22.0:
				close = true
				break
		if close:
			continue
		isl_centers.append(Vector2i(ix, iy))
		var rr := irng.randf_range(3.5, 7.5)
		var inoise := FastNoiseLite.new()
		inoise.seed = sd + 900 + placed_isl
		inoise.frequency = 0.22
		for dy in range(-10, 11):
			for dx in range(-10, 11):
				var px := ix + dx
				var py := iy + dy
				if px < 2 or py < 2 or px >= size - 2 or py >= size - 2:
					continue
				var d := sqrt(float(dx * dx + dy * dy)) + inoise.get_noise_2d(px, py) * 3.0
				if d < rr and land[py * size + px] == 0:
					land[py * size + px] = 1
					land_count += 1
		placed_isl += 1
	# Componentes conexas (4 vecinos)
	var comp := PackedInt32Array()
	comp.resize(total)
	comp.fill(-1)
	var comp_sizes: Array[int] = []
	var stack := PackedInt32Array()
	for i in total:
		if land[i] == 1 and comp[i] == -1:
			var cid := comp_sizes.size()
			var cnt := 0
			stack.clear()
			stack.append(i)
			comp[i] = cid
			while stack.size() > 0:
				var cur: int = stack[stack.size() - 1]
				stack.resize(stack.size() - 1)
				cnt += 1
				var cx := cur % size
				var cy := cur / size
				if cx > 0 and land[cur - 1] == 1 and comp[cur - 1] == -1:
					comp[cur - 1] = cid
					stack.append(cur - 1)
				if cx < size - 1 and land[cur + 1] == 1 and comp[cur + 1] == -1:
					comp[cur + 1] = cid
					stack.append(cur + 1)
				if cy > 0 and land[cur - size] == 1 and comp[cur - size] == -1:
					comp[cur - size] = cid
					stack.append(cur - size)
				if cy < size - 1 and land[cur + size] == 1 and comp[cur + size] == -1:
					comp[cur + size] = cid
					stack.append(cur + size)
			comp_sizes.append(cnt)
	if comp_sizes.is_empty():
		return {"ok": false}
	var main_comp := 0
	for c in comp_sizes.size():
		if comp_sizes[c] > comp_sizes[main_comp]:
			main_comp = c
	var main_size: int = comp_sizes[main_comp]
	if main_size < int(total * 0.16):
		return {"ok": false}
	# Distancia a la costa (desde tierra) y al litoral (desde agua)
	var dw := _bfs_dist(land, size, 1, true)   # distancia a agua, medida en tierra
	var dl := _bfs_dist(land, size, 0, false)  # distancia a tierra, medida en agua
	# Candidatos para bases: interior de la masa principal
	var min_dw := 8
	var cands: Array[Vector2i] = []
	while cands.is_empty() and min_dw >= 5:
		for y in range(0, size, 3):
			for x in range(0, size, 3):
				var idx := y * size + x
				if comp[idx] == main_comp and dw[idx] >= min_dw:
					cands.append(Vector2i(x, y))
		if cands.is_empty():
			min_dw -= 1
	if cands.size() < n:
		return {"ok": false}
	var starts := _pick_starts(cands, n)
	var min_sep := size * 0.22
	for i in n:
		for j in range(i + 1, n):
			if Vector2(starts[i]).distance_to(Vector2(starts[j])) < min_sep:
				return {"ok": false}
	# Terreno
	var terrain := PackedByteArray()
	terrain.resize(total)
	for i in total:
		if land[i] == 0:
			terrain[i] = Defs.T_WATER
		elif dw[i] <= 1:
			terrain[i] = Defs.T_SAND
		else:
			terrain[i] = Defs.T_GRASS
	var rtype := PackedByteArray()
	rtype.resize(total)
	var ramt := PackedInt32Array()
	ramt.resize(total)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	# Zona reservada alrededor de cada base
	var reserved := PackedByteArray()
	reserved.resize(total)
	for s in starts:
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				var px: int = s.x + dx
				var py: int = s.y + dy
				if px >= 0 and py >= 0 and px < size and py < size:
					reserved[py * size + px] = 1
	# Recursos iniciales de cada base
	for s in starts:
		var ang := rng.randf() * TAU
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		_place_cluster(rtype, ramt, terrain, reserved, size, Vector2(s) + dir * 8.5, 6, Defs.R_BERRY, rng, 2.2)
		_place_cluster(rtype, ramt, terrain, reserved, size, Vector2(s) + perp * 9.5, 4, Defs.R_GOLD, rng, 1.8)
		_place_cluster(rtype, ramt, terrain, reserved, size, Vector2(s) - dir * 10.0, 32, Defs.R_TREE, rng, 3.4)
		_place_cluster(rtype, ramt, terrain, reserved, size, Vector2(s) - perp * 11.0, 18, Defs.R_TREE, rng, 2.8)
	# Bosques globales
	var fnoise := FastNoiseLite.new()
	fnoise.seed = sd + 101
	fnoise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fnoise.fractal_type = FastNoiseLite.FRACTAL_FBM
	fnoise.fractal_octaves = 3
	fnoise.frequency = 7.0 / float(size)
	for y in size:
		for x in size:
			var i := y * size + x
			if terrain[i] != Defs.T_GRASS or rtype[i] != 0:
				continue
			var near_start := false
			for s in starts:
				if absi(s.x - x) < 12 and absi(s.y - y) < 12:
					near_start = true
					break
			if near_start:
				continue
			var f := fnoise.get_noise_2d(x, y)
			if (f > 0.13 and rng.randf() < 0.82) or rng.randf() < 0.008:
				rtype[i] = Defs.R_TREE
				ramt[i] = Defs.RES_INFO[Defs.R_TREE]["amount"]
	# Oro y bayas neutrales repartidos por todas las tierras
	var gold_clusters := maxi(4, size / 14)
	var berry_clusters := maxi(3, size / 24)
	_scatter(rtype, ramt, terrain, dw, reserved, size, gold_clusters, Defs.R_GOLD, 4, rng, starts)
	_scatter(rtype, ramt, terrain, dw, reserved, size, berry_clusters, Defs.R_BERRY, 5, rng, starts)
	# Islas: cada isla relevante recibe oro y, si es grande, bayas
	var islands: Array = []
	for c in comp_sizes.size():
		if c == main_comp:
			continue
		var area: int = comp_sizes[c]
		if area < 20:
			continue
		var best := -1
		var best_d := -1
		var sumx := 0
		var sumy := 0
		for i in total:
			if comp[i] == c:
				sumx += i % size
				sumy += i / size
				if dw[i] > best_d:
					best_d = dw[i]
					best = i
		islands.append({"id": c, "area": area, "center": Vector2i(sumx / area, sumy / area)})
		if best >= 0:
			var bc := Vector2(best % size, best / size)
			_place_cluster(rtype, ramt, terrain, reserved, size, bc, 4 if area < 60 else 6, Defs.R_GOLD, rng, 1.6)
			if area >= 40:
				_place_cluster(rtype, ramt, terrain, reserved, size, bc + Vector2(2, 2), 5, Defs.R_BERRY, rng, 2.0)
	# Pasillos: los bosques densos no pueden aislar unas bases de otras
	_carve_corridors(rtype, ramt, terrain, size, starts)
	# Peces en aguas poco profundas
	var fish_clusters := maxi(6, size / 9)
	var tries := 0
	var placed := 0
	while placed < fish_clusters and tries < fish_clusters * 40:
		tries += 1
		var fx := rng.randi_range(2, size - 3)
		var fy := rng.randi_range(2, size - 3)
		var fi := fy * size + fx
		if terrain[fi] == Defs.T_WATER and dl[fi] >= 2 and dl[fi] <= 6 and rtype[fi] == 0:
			_place_cluster(rtype, ramt, terrain, reserved, size, Vector2(fx, fy), rng.randi_range(4, 7), Defs.R_FISH, rng, 2.0)
			placed += 1
	return {
		"ok": true, "size": size, "terrain": terrain, "rtype": rtype, "ramt": ramt,
		"starts": starts, "comp": comp, "main_comp": main_comp, "main_size": main_size,
		"land_count": land_count, "islands": islands, "dw": dw, "dl": dl,
	}

static func _pick_starts(cands: Array[Vector2i], n: int) -> Array[Vector2i]:
	var cx := 0.0
	var cy := 0.0
	for c in cands:
		cx += c.x
		cy += c.y
	var centroid := Vector2(cx / cands.size(), cy / cands.size())
	var first := cands[0]
	var fd := -1.0
	for c in cands:
		var d := Vector2(c).distance_to(centroid)
		if d > fd:
			fd = d
			first = c
	var chosen: Array[Vector2i] = [first]
	while chosen.size() < n:
		var best := cands[0]
		var bd := -1.0
		for c in cands:
			var md := 1e9
			for s in chosen:
				md = minf(md, Vector2(c).distance_to(Vector2(s)))
			if md > bd:
				bd = md
				best = c
		chosen.append(best)
	return chosen

static func _bfs_dist(land: PackedByteArray, size: int, from_val: int, measure_on_land: bool) -> PackedInt32Array:
	# Distancia (4 vecinos) desde las casillas con valor from_val hacia las de valor distinto.
	var total := size * size
	var dist := PackedInt32Array()
	dist.resize(total)
	dist.fill(-1)
	var q := PackedInt32Array()
	# Para dw: fuentes = agua (land==0), se mide en tierra. Para dl: fuentes = tierra, se mide en agua.
	var source_val := 0 if measure_on_land else 1
	for i in total:
		if land[i] == source_val:
			dist[i] = 0
			q.append(i)
	var head := 0
	while head < q.size():
		var cur: int = q[head]
		head += 1
		var cx := cur % size
		var cy := cur / size
		var d: int = dist[cur] + 1
		if cx > 0 and dist[cur - 1] == -1:
			dist[cur - 1] = d
			q.append(cur - 1)
		if cx < size - 1 and dist[cur + 1] == -1:
			dist[cur + 1] = d
			q.append(cur + 1)
		if cy > 0 and dist[cur - size] == -1:
			dist[cur - size] = d
			q.append(cur - size)
		if cy < size - 1 and dist[cur + size] == -1:
			dist[cur + size] = d
			q.append(cur + size)
	# Los bordes sin fuente quedan en -1: tratarlos como lejanos
	for i in total:
		if dist[i] == -1:
			dist[i] = 99
	return dist

static func _tile_ok_for(kind: int, terrain: PackedByteArray, rtype: PackedByteArray, reserved: PackedByteArray, i: int) -> bool:
	if rtype[i] != 0:
		return false
	if kind == Defs.R_FISH:
		return terrain[i] == Defs.T_WATER
	if reserved[i] == 1 and kind != Defs.R_BERRY and kind != Defs.R_GOLD and kind != Defs.R_TREE:
		return false
	return terrain[i] == Defs.T_GRASS

static func _place_cluster(rtype: PackedByteArray, ramt: PackedInt32Array, terrain: PackedByteArray, reserved: PackedByteArray, size: int, center: Vector2, count: int, kind: int, rng: RandomNumberGenerator, spread: float) -> int:
	var placed := 0
	var tries := 0
	var amount: int = Defs.RES_INFO[kind]["amount"]
	while placed < count and tries < count * 30:
		tries += 1
		var off := Vector2(rng.randfn(0.0, spread), rng.randfn(0.0, spread))
		var p := center + off
		var x := int(round(p.x))
		var y := int(round(p.y))
		if x < 1 or y < 1 or x >= size - 1 or y >= size - 1:
			continue
		var i := y * size + x
		# Evita pisar la huella de la base (TC 3x3 y alrededores inmediatos)
		if not _tile_ok_for(kind, terrain, rtype, reserved, i):
			continue
		rtype[i] = kind
		ramt[i] = amount
		placed += 1
	return placed

static func _scatter(rtype: PackedByteArray, ramt: PackedInt32Array, terrain: PackedByteArray, dw: PackedInt32Array, reserved: PackedByteArray, size: int, clusters: int, kind: int, count: int, rng: RandomNumberGenerator, starts: Array[Vector2i]) -> void:
	var placed := 0
	var tries := 0
	while placed < clusters and tries < clusters * 60:
		tries += 1
		var x := rng.randi_range(3, size - 4)
		var y := rng.randi_range(3, size - 4)
		var i := y * size + x
		if terrain[i] != Defs.T_GRASS or dw[i] < 2 or rtype[i] != 0 or reserved[i] == 1:
			continue
		var far := true
		for s in starts:
			if Vector2(s).distance_to(Vector2(x, y)) < 16.0:
				far = false
				break
		if not far:
			continue
		_place_cluster(rtype, ramt, terrain, reserved, size, Vector2(x, y), count, kind, rng, 1.7)
		placed += 1

static func _carve_corridors(rtype: PackedByteArray, ramt: PackedInt32Array, terrain: PackedByteArray, size: int, starts: Array[Vector2i]) -> void:
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, size, size)
	g.cell_size = Vector2(1, 1)
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	g.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	g.update()
	for i in size * size:
		var rt := rtype[i]
		var pt := Vector2i(i % size, i / size)
		if terrain[i] == Defs.T_WATER:
			g.set_point_solid(pt, true)
		elif rt == Defs.R_TREE:
			g.set_point_weight_scale(pt, 12.0)
		elif rt == Defs.R_GOLD or rt == Defs.R_BERRY:
			g.set_point_weight_scale(pt, 30.0)
	for i in starts.size():
		for j in range(i + 1, starts.size()):
			var path := g.get_id_path(starts[i], starts[j], false)
			for pt in path:
				# Despeja un pasillo de 3 casillas de ancho
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var q: Vector2i = pt + Vector2i(dx, dy)
						if q.x < 0 or q.y < 0 or q.x >= size or q.y >= size:
							continue
						var qi := q.y * size + q.x
						if rtype[qi] == Defs.R_TREE:
							rtype[qi] = 0
							ramt[qi] = 0
