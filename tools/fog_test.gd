extends SceneTree
## Comprueba que Fog.update (optimizada) da exactamente lo mismo que el algoritmo original y mide cuánto tarda cada una.
## Uso: godot --headless --path . --script res://tools/fog_test.gd -- seed=3 size=192 min=10

## Algoritmo original (referencia): sin deduplicar y con dos pasadas sobre las casillas visibles.
class RefFog extends RefCounted:
	var W: int
	var H: int
	var state := PackedByteArray()
	var mark := PackedByteArray()
	var vis_list := PackedInt32Array()
	var img: Image
	var _offs: Dictionary = {}
	func _init(w: int, h: int) -> void:
		W = w
		H = h
		state.resize(w * h)
		mark.resize(w * h)
		img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 1.0))
	func _offsets(r: int) -> PackedInt32Array:
		if _offs.has(r):
			return _offs[r]
		var out := PackedInt32Array()
		var rr := float(r) + 0.5
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if float(dx * dx + dy * dy) <= rr * rr:
					out.append(dx)
					out.append(dy)
		_offs[r] = out
		return out
	func update(sim: Sim, pidx: int) -> void:
		mark.fill(0)
		var new_list := PackedInt32Array()
		for u in sim.units:
			if u.alive and u.owner == pidx:
				_reveal(sim.tile_of(u.pos), int(u.def["los"]), new_list)
		for b in sim.buildings:
			if b.alive and b.owner == pidx:
				var r: int = int(b.def.get("los", 5))
				if b.progress < 1.0:
					r = mini(r, 4)
				_reveal(b.tile + Vector2i(b.size / 2, b.size / 2), r, new_list)
		for idx in vis_list:
			if mark[idx] == 0:
				state[idx] = 1
				img.set_pixel(idx % W, idx / W, Color(0, 0, 0, 0.5))
		for idx in new_list:
			if state[idx] != 2:
				state[idx] = 2
				img.set_pixel(idx % W, idx / W, Color(0, 0, 0, 0.0))
		vis_list = new_list
	func _reveal(c: Vector2i, r: int, out: PackedInt32Array) -> void:
		var o := _offsets(r)
		var i := 0
		while i < o.size():
			var nx := c.x + o[i]
			var ny := c.y + o[i + 1]
			i += 2
			if nx < 0 or ny < 0 or nx >= W or ny >= H:
				continue
			var idx := ny * W + nx
			if mark[idx] == 0:
				mark[idx] = 1
				out.append(idx)

var fails := 0

func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (("  " + extra) if extra != "" else ""))
	if not ok:
		fails += 1

func _init() -> void:
	var seed_v := 3
	var size_v := 192
	var minutes := 10.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("size="): size_v = int(a.substr(5))
		elif a.begins_with("min="): minutes = float(a.substr(4))
	var sim := Sim.new()
	sim.setup({"size": size_v, "seed": seed_v, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo"},
		{"human": false, "team": 1, "diff": 1, "name": "Amarillo"}]})
	sim.ais.append(AiPlayer.new(sim, sim.human_index, 1))      # una IA juega por el humano: hay muchas unidades
	var fog := Fog.new(sim.W, sim.H)
	var ref := RefFog.new(sim.W, sim.H)
	var t_new := 0
	var t_ref := 0
	var n := 0
	var bad := ""
	var steps := int(minutes * 60.0 / Sim.DT)
	for st in steps:
		if sim.game_over:
			break
		sim.step()
		if st % 4 == 0:
			var a0 := Time.get_ticks_usec()
			fog.update(sim, sim.human_index)
			var a1 := Time.get_ticks_usec()
			ref.update(sim, sim.human_index)
			var a2 := Time.get_ticks_usec()
			t_new += a1 - a0
			t_ref += a2 - a1
			n += 1
			if fog.state != ref.state or fog.mark != ref.mark or fog.vis_list != ref.vis_list or fog.img.get_data() != ref.img.get_data():
				bad = "diferencia en t=%.1f" % sim.time
				break
	check("misma niebla que el algoritmo original (%d actualizaciones, %.0f s de partida)" % [n, sim.time], bad == "", bad)
	print("INFO por actualización: original %.2f ms, nueva %.2f ms (%.0f %%)" % [t_ref / 1000.0 / maxf(n, 1), t_new / 1000.0 / maxf(n, 1), 100.0 * t_new / maxf(t_ref, 1)])
	print("DONE fails=", fails)
	quit()
