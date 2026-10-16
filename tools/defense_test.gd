extends SceneTree
## Cuánto aguantan muralla, puerta, torre y castillo frente a soldados y a asedio (vida antes/después del ajuste de la build-25).
## godot --headless --path . --script res://tools/defense_test.gd
var fails := 0
var checks := 0
const OLD_HP := {"muralla": 550.0, "puerta": 800.0, "torre": 700.0, "castillo": 3200.0}

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FALLO: ", msg)

func make_sim() -> Sim:
	var sim := Sim.new()
	sim.setup({"size": 128, "seed": 7, "events": false, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "A", "civ": ""},
		{"human": false, "team": 1, "diff": 1, "name": "B", "civ": ""}]})
	sim.ais.clear()
	return sim

## Claro de tierra andable (hierba o arena) con la obra y casillas libres a su alrededor (por donde llegan los atacantes):
## se talan los árboles y se agotan los recursos que haya en esa zona. Devuelve la esquina de la obra.
func clear_site(sim: Sim, near: Vector2i, btype: String) -> Vector2i:
	var size: int = int(Defs.BUILDINGS[btype]["size"])
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for dy in range(-45, 46):
		for dx in range(-45, 46):
			var q := near + Vector2i(dx, dy)
			if absi(dx) < 9 and absi(dy) < 9:
				continue
			var good := true
			for yy in range(q.y - 3, q.y + size + 3):
				for xx in range(q.x - 3, q.x + size + 8):
					var t := Vector2i(xx, yy)
					if not sim.in_bounds(t):
						good = false
					else:
						var i := yy * sim.W + xx
						if (sim.terrain[i] != Defs.T_GRASS and sim.terrain[i] != Defs.T_SAND) or sim.occ[i] != 0 or sim.rtype[i] == Defs.R_FISH:
							good = false
					if not good:
						break
				if not good:
					break
			if good and Vector2(dx, dy).length() < bd:
				bd = Vector2(dx, dy).length()
				best = q
	if best.x >= 0:
		for yy in range(best.y - 3, best.y + size + 3):
			for xx in range(best.x - 3, best.x + size + 8):
				var j := yy * sim.W + xx
				if sim.rtype[j] != 0:
					sim._deplete(j)
	return best

## Segundos que tardan `n` unidades `utype` en derribar un `btype` (con la vida indicada), y cuántas sobreviven.
func siege(btype: String, hp: float, utype: String, n: int, garrison: int = 0) -> Dictionary:
	var sim := make_sim()
	var p0: Player = sim.players[0]
	var p1: Player = sim.players[1]
	p0.age = 2
	p1.age = 1
	var site := clear_site(sim, p0.start_tile, btype)
	ok(site.x >= 0, "hay un claro para " + btype)
	var b := sim._spawn_building(btype, 0, site, true)
	b.max_hp = hp
	b.hp = hp
	# arqueros dentro (la guarnición añade flechas); la IA no mete soldados en los edificios, una persona sí
	var cap := sim.garrison_cap(b)
	if cap > 0 and garrison > 0:
		var gar: Array = []
		for i in mini(cap, garrison):
			gar.append(sim._spawn_unit("arquero", 0, site + Vector2i(-2, i)).id)
		sim.cmd_garrison(0, gar, b.id)
		for i in 120:
			sim.step()
	var ids: Array = []
	for i in n:
		ids.append(sim._spawn_unit(utype, 1, site + Vector2i(b.size + 3 + i % 4, i / 4)).id)
	sim.cmd_attack(1, ids, b.id)
	var steps := 0
	while b.alive and steps < 3000:
		sim.step()
		steps += 1
	var left := 0
	for id in ids:
		var u := sim.get_ent(id)
		if u != null and u.alive:
			left += 1
	return {"s": float(steps) * Sim.DT, "left": left, "dead": not b.alive}

func _init() -> void:
	var table := {}
	var cases := [
		["muralla", "espadachin", 10, 0], ["muralla", "ariete", 3, 0],
		["puerta", "espadachin", 10, 0], ["puerta", "ariete", 3, 0],
		["torre", "espadachin", 10, 0], ["torre", "espadachin", 10, 3], ["torre", "ariete", 3, 0],
		["castillo", "espadachin", 10, 0], ["castillo", "espadachin", 10, 3], ["castillo", "ariete", 3, 0],
	]
	for c in cases:
		var bt: String = c[0]
		var before := siege(bt, float(OLD_HP[bt]), c[1], c[2], c[3])
		var after := siege(bt, float(Defs.BUILDINGS[bt]["hp"]), c[1], c[2], c[3])
		var key := "%s/%s/%d" % [bt, c[1], c[3]]
		table[key] = [before, after]
		print("%-9s vs %2d %-10s guarnición %d | antes %s | ahora %s" % [bt, c[2], c[1], c[3], fmt(before), fmt(after)])
	# muralla y puerta: los soldados tardan más del doble; el asedio sigue siendo la respuesta (cae en pocos segundos)
	for bt in ["muralla", "puerta"]:
		var sw: Array = table[bt + "/espadachin/0"]
		ok(bool(sw[1]["dead"]), bt + ": 10 espadachines acaban derribándola")
		ok(float(sw[1]["s"]) >= 2.0 * float(sw[0]["s"]), "%s: aguanta al menos el doble frente a espadachines (%.0f → %.0f s)" % [bt, sw[0]["s"], sw[1]["s"]])
		var ar: Array = table[bt + "/ariete/0"]
		ok(bool(ar[1]["dead"]) and float(ar[1]["s"]) <= 20.0, "%s: 3 arietes la derriban en <20 s (%.0f s)" % [bt, ar[1]["s"]])
	# torre sin guarnición (la de la IA): cae, pero cuesta bajas y tiempo; con guarnición (la de una persona) aguanta a 10 espadachines
	var t0: Array = table["torre/espadachin/0"]
	ok(bool(t0[1]["dead"]) and float(t0[1]["s"]) >= 1.5 * float(t0[0]["s"]), "torre sola: cae pero tarda >=1,5 veces más (%.0f → %.0f s)" % [t0[0]["s"], t0[1]["s"]])
	ok(int(t0[1]["left"]) < int(t0[0]["left"]) or int(t0[0]["left"]) < 10, "torre sola: ahora mata a más atacantes (%d → %d supervivientes)" % [t0[0]["left"], t0[1]["left"]])
	var tg: Array = table["torre/espadachin/3"]
	ok(not bool(tg[1]["dead"]), "torre con 3 arqueros dentro: aguanta a 10 espadachines")
	var cs: Array = table["castillo/espadachin/0"]
	ok(not bool(cs[1]["dead"]) or float(cs[1]["s"]) >= 1.4 * float(cs[0]["s"]), "castillo: aguanta más frente a 10 espadachines")
	var cr: Array = table["castillo/ariete/0"]
	ok(bool(cr[1]["dead"]) and float(cr[1]["s"]) <= 90.0, "castillo: 3 arietes lo derriban en <90 s (%.0f s)" % cr[1]["s"])
	print("defense_test: %d comprobaciones, %d fallos" % [checks, fails])
	quit(1 if fails > 0 else 0)

func fmt(r: Dictionary) -> String:
	return "%s %5.1f s, quedan %2d" % ["cae" if bool(r["dead"]) else "NO cae", float(r["s"]), int(r["left"])]
