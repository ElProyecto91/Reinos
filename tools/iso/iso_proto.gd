extends Node2D
## Prototipo isométrico: el mapa real de la simulación (terreno con el shader isométrico, árboles, minas, edificios y unidades)
## dibujado con sprites pre-renderizados en 3D (tools/iso/iso_bake.gd + iso_post.py). Sólo para juzgar el aspecto.
## Uso: xvfb-run -a godot --path . res://tools/iso/iso_proto.tscn --rendering-driver opengl3 --resolution 1280x720 -- shot=/tmp/iso_proto.png zoom=1.6 seed=4 cx=6 cy=4 sprites=/tmp/iso_sprites
const TW2 := 32.0
const TH2 := 16.0
var sim: Sim
var sprites_dir := "/tmp/iso_sprites"
var anchors: Dictionary = {}
var tex_cache: Dictionary = {}
var shot_path := "/tmp/iso_proto.png"
var zoom_v := 1.6
var seed_v := 4
var off := Vector2(6, 4)
var shadow_tex: Texture2D
var world: Node2D
var shadows: Node2D
var objs: Node2D

func iso(t: Vector2) -> Vector2:
	return Vector2((t.x - t.y) * TW2, (t.x + t.y) * TH2)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="): shot_path = a.substr(5)
		elif a.begins_with("zoom="): zoom_v = float(a.substr(5))
		elif a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("cx="): off.x = float(a.substr(3))
		elif a.begins_with("cy="): off.y = float(a.substr(3))
		elif a.begins_with("sprites="): sprites_dir = a.substr(8)
	anchors = JSON.parse_string(FileAccess.get_file_as_string(sprites_dir + "/anchors.json"))
	sim = Sim.new()
	sim.setup({"size": 128, "seed": seed_v, "events": false, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú", "civ": "castellanos"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo"}]})
	sim.ais.clear()
	_make_shadow()
	_populate()
	_build_scene()
	for i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(shot_path)
	print("INFO captura ", shot_path)
	get_tree().quit()

func tex(name: String) -> Texture2D:
	if tex_cache.has(name):
		return tex_cache[name]
	var img := Image.load_from_file("%s/%s.png" % [sprites_dir, name])
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	tex_cache[name] = t
	return t

func _make_shadow() -> void:
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 64:
			var d := Vector2((x + 0.5 - 32.0) / 32.0, (y + 0.5 - 16.0) / 16.0).length()
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.03, 0.05, 0.09, pow(a, 0.9) * 0.55))
	img.generate_mipmaps()
	shadow_tex = ImageTexture.create_from_image(img)

## Coloca varias casas, una torre y soldados cerca del centro urbano del jugador.
func _populate() -> void:
	var s: Vector2i = sim.players[0].start_tile
	var placed := 0
	for spec in [["casa", Vector2i(-8, 4)], ["casa", Vector2i(-8, 8)], ["casa", Vector2i(8, -6)], ["torre", Vector2i(6, 7)], ["casa", Vector2i(10, 4)]]:
		var t := _free(s + (spec[1] as Vector2i), spec[0] as String)
		if t.x >= 0:
			sim._spawn_building(spec[0] as String, 0, t, true)
			placed += 1
	print("INFO edificios colocados ", placed)
	for i in 8:
		var ft := sim.nearest_free_tile(s + Vector2i(i - 3, 8), 6)
		sim._spawn_unit("espadachin", 0, ft)

func _free(t: Vector2i, type: String) -> Vector2i:
	for r in range(0, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := t + Vector2i(dx, dy)
				if sim.can_place(type, q, 0):
					return q
	return Vector2i(-1, -1)

func _spr(parent: Node2D, name: String, ground: Vector2, sc: float = 1.0, flip: bool = false) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex(name)
	var an: Array = anchors[name]
	sp.centered = false
	sp.offset = -Vector2(float(an[0]), float(an[1]))
	sp.scale = Vector2(0.5 * sc * (-1.0 if flip else 1.0), 0.5 * sc)
	sp.position = iso(ground)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(sp)
	return sp

func _shadow(ground: Vector2, rx: float, ry: float, shift: Vector2 = Vector2(0.18, 0.18)) -> void:
	var sp := Sprite2D.new()
	sp.texture = shadow_tex
	sp.position = iso(ground + shift)
	sp.scale = Vector2(rx / 32.0, ry / 16.0)
	shadows.add_child(sp)

func _build_scene() -> void:
	world = Node2D.new()
	add_child(world)
	world.scale = Vector2(zoom_v, zoom_v)
	var s: Vector2i = sim.players[0].start_tile
	var centre := Vector2(s.x + off.x, s.y + off.y)
	world.position = Vector2(640, 360) - iso(centre) * zoom_v
	# terreno
	var mat := TerrainFx.make_material(sim)
	mat.shader = load("res://tools/iso/terrain_iso.gdshader")
	mat.set_shader_parameter("tile_px", float(Defs.TILE))
	mat.set_shader_parameter("tm", 0.0)
	var poly := Polygon2D.new()
	var W := float(sim.W)
	var H := float(sim.H)
	poly.polygon = PackedVector2Array([iso(Vector2(0, 0)), iso(Vector2(W, 0)), iso(Vector2(W, H)), iso(Vector2(0, H))])
	poly.material = mat
	world.add_child(poly)
	shadows = Node2D.new()
	world.add_child(shadows)
	objs = Node2D.new()
	objs.y_sort_enabled = true
	world.add_child(objs)
	var win_u := 640.0 / (TW2 * zoom_v) + 5.0
	var win_v := 360.0 / (TH2 * zoom_v) + 8.0
	var in_view := func(t: Vector2) -> bool:
		return absf((t.x - t.y) - (centre.x - centre.y)) <= win_u and absf((t.x + t.y) - (centre.x + centre.y)) <= win_v
	var n_tree := 0
	for i in sim.W * sim.H:
		var rt: int = sim.rtype[i]
		if rt == 0:
			continue
		var x := i % sim.W
		var y := i / sim.W
		var g := Vector2(x + 0.5, y + 0.5)
		if not in_view.call(g):
			continue
		var hsh := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
		var jit := Vector2(float((hsh >> 3) % 100) / 100.0 - 0.5, float((hsh >> 9) % 100) / 100.0 - 0.5) * 0.45
		var heat := float(sim.heat[i]) / 255.0
		if rt == Defs.R_TREE:
			var name := ("pino_%d" % ((hsh >> 5) % 2)) if heat < 0.42 or (hsh >> 15) % 100 < 22 else ("roble_%d" % ((hsh >> 5) % 4))
			var sc := 0.92 + float((hsh >> 13) % 20) / 100.0
			_shadow(g + jit, 20.0 * sc, 8.5 * sc, Vector2(0.45, 0.12))
			_spr(objs, name, g + jit, sc, (hsh >> 17) % 2 == 0)
			n_tree += 1
		elif rt == Defs.R_GOLD:
			_shadow(g, 24.0, 10.0, Vector2(0.3, 0.1))
			_spr(objs, "oro_0", g)
		elif rt == Defs.R_STONE:
			_shadow(g, 24.0, 10.0, Vector2(0.3, 0.1))
			_spr(objs, "roca_0", g)
	print("INFO árboles dibujados ", n_tree)
	for b in sim.buildings:
		if not b.alive:
			continue
		var g := Vector2(b.tile.x + b.size * 0.5, b.tile.y + b.size * 0.5)
		if not in_view.call(g):
			continue
		var nm := "%s_%s" % [b.type, "blue" if b.owner == 0 else "red"]
		if not anchors.has(nm):
			nm = "%s_blue" % b.type
		if not anchors.has(nm):
			continue
		_shadow(g, b.size * 38.0, b.size * 16.0, Vector2(b.size * 0.42, b.size * 0.08))
		_spr(objs, nm, g)
	var k := 0
	for u in sim.units:
		if not u.alive:
			continue
		var g2 := u.pos / float(Defs.TILE)
		if not in_view.call(g2):
			continue
		var kind := "espadachin" if u.type == "espadachin" else "aldeano"
		var team := "blue" if u.owner == 0 else "red"
		var dir := k % 8
		var nm2 := "%s_%s_%d_w%d" % [kind, team, dir, (k * 3) % 4]
		if not anchors.has(nm2):
			nm2 = "%s_blue_%d_w%d" % [kind, dir, (k * 3) % 4]
		_shadow(g2, 11.0, 5.0, Vector2(0.16, 0.04))
		_spr(objs, nm2, g2, 1.0)
		k += 1
