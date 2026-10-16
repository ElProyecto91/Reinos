extends SceneTree
## Prueba de murallas y puertas en la simulación pura.
## godot --headless --path . --script res://tools/wall_test.gd

const R := 6

func make_sim(team_b: int) -> Sim:
	var sim := Sim.new()
	var cfg := {"size": 128, "seed": 7, "events": false, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "A"},
		{"human": false, "team": team_b, "diff": 1, "name": "B"}]}
	sim.setup(cfg)
	sim.ais.clear()
	return sim

func tc_of(sim: Sim, owner: int) -> Ent:
	for bd in sim.buildings:
		if bd.owner == owner and bd.type == "centro":
			return bd
	return null

func outside_tiles(sim: Sim, c: Vector2i) -> Array:
	## casillas fuera del anillo con camino libre hasta dentro (antes de levantar murallas)
	var out: Array = []
	for d in range(R + 4, R + 10):
		for x in range(-d, d + 1):
			for y in range(-d, d + 1):
				if maxi(absi(x), absi(y)) != d:
					continue
				var t := c + Vector2i(x, y)
				if sim.in_bounds(t) and not sim.is_solid_tile(t) and sim.astar.get_id_path(t, c + Vector2i(0, 2), false).size() > 0:
					out.append(t)
	return out

func build_ring(sim: Sim, owner: int, c: Vector2i, gate_at: Vector2i) -> int:
	var n := 0
	for x in range(-R, R + 1):
		for y in range(-R, R + 1):
			var t := c + Vector2i(x, y)
			if maxi(absi(x), absi(y)) != R or not sim.can_place("muralla", t):
				continue
			if t == gate_at:
				sim._spawn_building("puerta", owner, t, true)
			else:
				sim._spawn_building("muralla", owner, t, true)
			n += 1
	return n

func inside(sim: Sim, u: Ent, c: Vector2i) -> bool:
	var t := sim.tile_of(u.pos)
	return absi(t.x - c.x) < R and absi(t.y - c.y) < R

func _initialize() -> void:
	# ---- 1) y 2): propios salen por la puerta; el enemigo rompe la muralla
	var sim := make_sim(1)
	var tcA := tc_of(sim, 0)
	var c := sim.tile_of(tcA.center())
	var outs := outside_tiles(sim, c)
	print("outside candidates ", outs.size())
	# la puerta se pone en la casilla del anillo por donde pasa el camino hacia el primer candidato
	var probe: Vector2i = outs[0]
	var path := sim.astar.get_id_path(c + Vector2i(0, 2), probe, false)
	var gate_at := Vector2i(-1, -1)
	for t in path:
		if maxi(absi(t.x - c.x), absi(t.y - c.y)) == R:
			gate_at = t
			break
	var placed := build_ring(sim, 0, c, gate_at)
	print("ring walls ", sim.wall_count, " of which placed ", placed, " gate at ", gate_at)
	var vill: Array = []
	for u in sim.units:
		if u.owner == 0 and u.type == "aldeano":
			vill.append(u.id)
	sim.cmd_move(0, vill, probe)
	for i in 700:
		sim.step()
	var out_ok := 0
	for id in vill:
		var u := sim.get_ent(id)
		if u != null and not inside(sim, u, c):
			out_ok += 1
	print("TEST own villagers exit via gate: ", out_ok, "/", vill.size(), " -> ", "PASS" if out_ok >= vill.size() - 1 else "FAIL")
	# ejército enemigo desde fuera
	var army: Array = []
	for i in 10:
		var t: Vector2i = outs[(i * 7) % outs.size()]
		army.append(sim._spawn_unit("piquero", 1, t).id)
	sim.players[1].age = 1
	sim.cmd_attack(1, army, tcA.id)
	var walls0 := sim.wall_count
	var breach_t := -1
	var tc_hit_t := -1
	for i in 9000:
		sim.step()
		if breach_t < 0 and sim.wall_count < walls0:
			breach_t = i
		if tc_hit_t < 0 and tcA.hp < tcA.max_hp:
			tc_hit_t = i
		if tc_hit_t >= 0 and i > tc_hit_t + 100:
			break
	print("breach step ", breach_t, " tc damage step ", tc_hit_t, " walls ", walls0, "->", sim.wall_count, " hp=", int(tcA.hp))
	print("TEST enemy breaks wall/gate and reaches TC: ", "PASS" if breach_t >= 0 and tc_hit_t >= 0 else "FAIL")
	# ---- 3) un aldeano enemigo no entra por la puerta
	var sim2 := make_sim(1)
	var c2 := sim2.tile_of(tc_of(sim2, 0).center())
	build_ring(sim2, 0, c2, gate_at)
	var ev := sim2._spawn_unit("aldeano", 1, probe)
	sim2.cmd_move(1, [ev.id], c2 + Vector2i(0, 1))
	for i in 600:
		sim2.step()
	print("TEST enemy villager stays outside: ", "FAIL" if inside(sim2, ev, c2) else "PASS", " tile ", sim2.tile_of(ev.pos))
	# ---- 4) un aldeano aliado sí pasa
	var sim3 := make_sim(0)
	var c3 := sim3.tile_of(tc_of(sim3, 0).center())
	build_ring(sim3, 0, c3, gate_at)
	var al := sim3._spawn_unit("aldeano", 1, probe)
	sim3.cmd_move(1, [al.id], c3 + Vector2i(0, 1))
	for i in 700:
		sim3.step()
	print("TEST allied villager passes gate: ", "PASS" if inside(sim3, al, c3) else "FAIL", " tile ", sim3.tile_of(al.pos))
	# ---- 5) sin puerta, anillo cerrado: el propio aldeano no sale, el enemigo ataca igualmente
	var sim4 := make_sim(1)
	var c4 := sim4.tile_of(tc_of(sim4, 0).center())
	build_ring(sim4, 0, c4, Vector2i(-99, -99))
	var army4: Array = []
	for i in 6:
		army4.append(sim4._spawn_unit("piquero", 1, outs[(i * 5) % outs.size()]).id)
	sim4.cmd_move(1, army4, c4, true)
	var w4 := sim4.wall_count
	for i in 6000:
		sim4.step()
	print("TEST amove into closed ring breaks walls: ", "PASS" if sim4.wall_count < w4 else "FAIL", " ", w4, "->", sim4.wall_count)
	# ---- 6) una pieza que la propia muralla deja encerrada se cancela y se devuelve su coste
	var sim5 := make_sim(1)
	var p5: Player = sim5.players[0]
	p5.res = {"food": 2000, "wood": 2000, "gold": 2000, "stone": 2000}
	p5.age = 1
	var row_a := Vector2i(-1, -1)
	var s5: Vector2i = p5.start_tile
	# la cantera y la caza que trae el mapa caen justo en la zona de prueba: se retiran para dejar el terreno de siempre
	for cy in range(3, 16):
		for cx in range(-16, 10):
			var ci: int = (s5.y + cy) * sim5.W + s5.x + cx
			if sim5.rtype[ci] == Defs.R_STONE or Defs.is_animal(sim5.rtype[ci]):
				sim5._deplete(ci)
	for dy in range(5, 12):
		for dx in range(-10, 4):
			var okr := true
			for i in 8:
				if not sim5.can_place("muralla", s5 + Vector2i(dx + i, dy), 0):
					okr = false
					break
			if okr and row_a.x < 0:
				row_a = s5 + Vector2i(dx, dy)
	# bloquear la casilla de delante de la pieza 1 para encerrarla (como haría un árbol)
	var blocker := row_a + Vector2i(1, -1)
	sim5.set_solid(blocker, true)
	var vs5: Array = []
	for u in sim5.units:
		if u.owner == 0 and u.type == "aldeano":
			vs5.append(u.id)
	vs5 = vs5.slice(0, 3)
	for id in vs5:
		sim5.get_ent(id).pos = sim5.tile_center(row_a + Vector2i(-2, -2))
	var tl5: Array = []
	for i in 8:
		tl5.append(row_a + Vector2i(i, 0))
	var stone5: int = p5.res["stone"]
	var placed5 := sim5.cmd_build_wall(0, vs5, "muralla", tl5)
	for i in 900:
		sim5.step()
	var done5 := 0
	var open5 := 0
	for bd in sim5.buildings:
		if bd.owner == 0 and bd.type == "muralla":
			if bd.progress >= 1.0:
				done5 += 1
			else:
				open5 += 1
	var idle5 := 0
	for id in vs5:
		if sim5.get_ent(id).state == Sim.S_IDLE:
			idle5 += 1
	print("TEST trapped wall piece cancelled: ", "PASS" if placed5 == 8 and open5 == 0 and done5 >= 6 and idle5 == 3 and int(p5.res["stone"]) == stone5 - int(Defs.BUILDINGS["muralla"]["cost"]["stone"]) * done5 else "FAIL", " placed ", placed5, " done ", done5, " open ", open5, " idle ", idle5, " stone ", stone5, "->", p5.res["stone"])
	quit(0)
