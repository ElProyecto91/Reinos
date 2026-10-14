class_name Fog
extends RefCounted
## Niebla de guerra del jugador humano: 0 = sin explorar, 1 = explorado, 2 = visible.

var W: int
var H: int
var state := PackedByteArray()
var mark := PackedByteArray()
var vis_list := PackedInt32Array()
var img: Image
var tex: ImageTexture
var _offs: Dictionary = {}
const A_UNEXPLORED := 1.0
const A_EXPLORED := 0.5

func _init(w: int, h: int) -> void:
	W = w
	H = h
	state.resize(w * h)
	mark.resize(w * h)
	img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, A_UNEXPLORED))
	tex = ImageTexture.create_from_image(img)

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
	var changed := false
	for idx in vis_list:
		if mark[idx] == 0:
			state[idx] = 1
			img.set_pixel(idx % W, idx / W, Color(0, 0, 0, A_EXPLORED))
			changed = true
	for idx in new_list:
		if state[idx] != 2:
			state[idx] = 2
			img.set_pixel(idx % W, idx / W, Color(0, 0, 0, 0.0))
			changed = true
	vis_list = new_list
	if changed:
		tex.update(img)

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

func visible_at(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H and state[t.y * W + t.x] == 2

func explored_at(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < W and t.y < H and state[t.y * W + t.x] >= 1
