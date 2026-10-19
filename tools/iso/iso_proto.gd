extends Node2D
## Prototipo isométrico: el mapa real de la simulación (terreno con el shader isométrico, árboles, minas) y edificios, máquinas y
## unidades dibujados con sprites pre-renderizados en 3D (tools/iso/iso_bake.gd + iso_post.py), con sombras horneadas.
## Sólo para juzgar el aspecto; no forma parte del juego.
## Escenas: scene=base (casas, torre y soldados junto al centro urbano) | scene=ref (asedio a una fortaleza, como la imagen de referencia).
## Uso: xvfb-run -a godot --path . res://tools/iso/iso_proto.tscn --rendering-driver opengl3 --resolution 1280x720 -- shot=/tmp/iso_proto.png scene=ref zoom=1.5 seed=4 cx=3 cy=0
const TW2 := 32.0
const TH2 := 16.0
const UNIT_SC := 0.52        # las unidades de Age of Empires miden ~1/4 de la casilla: bastante menos que mis muñecos
var sim: Sim
var sprites_dir := "/tmp/iso_sprites"
var anchors: Dictionary = {}
var tex_cache: Dictionary = {}
var shot_path := "/tmp/iso_proto.png"
var zoom_v := 1.35
var seed_v := 4
var scene_v := "ref"
var lego_style := false
var off := Vector2(3, 0)     # desplazamiento del centro de la vista respecto del sitio elegido
var site := Vector2i(64, 64)
var shadow_tex: Texture2D
var puff_tex: Texture2D
var world: Node2D
var shadows: Node2D
var objs: Node2D
var air: Node2D
var blockers: Array = []     # [centro Vector2, radio] zonas donde no se plantan árboles
var road_img: Image
var comp_rect := Rect2()     # zona de la composición (en casillas absolutas): no se dibujan los árboles del mapa dentro

func iso(t: Vector2) -> Vector2:
	return Vector2((t.x - t.y) * TW2, (t.x + t.y) * TH2)

func P(u: float, v: float) -> Vector2:
	return Vector2(float(site.x) + u, float(site.y) + v)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="): shot_path = a.substr(5)
		elif a.begins_with("zoom="): zoom_v = float(a.substr(5))
		elif a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("cx="): off.x = float(a.substr(3))
		elif a.begins_with("cy="): off.y = float(a.substr(3))
		elif a.begins_with("scene="): scene_v = a.substr(6)
		elif a.begins_with("sprites="): sprites_dir = a.substr(8)
		elif a.begins_with("style="): lego_style = a.substr(6) == "lego"
	if lego_style and sprites_dir == "/tmp/iso_sprites":
		sprites_dir = "/tmp/iso_sprites_lego"
	anchors = JSON.parse_string(FileAccess.get_file_as_string(sprites_dir + "/anchors.json"))
	sim = Sim.new()
	sim.setup({"size": 128, "seed": seed_v, "events": false, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú", "civ": "castellanos"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo"}]})
	sim.ais.clear()
	_make_textures()
	if scene_v == "ref":
		site = _find_site()
		print("INFO sitio ", site)
		comp_rect = Rect2(P(-13, -11), Vector2(27, 24))
	else:
		site = sim.players[0].start_tile
	_build_scene()
	if scene_v == "ref":
		_compose_ref()
	else:
		_populate_base()
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

func _make_textures() -> void:
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 64:
			var d := Vector2((x + 0.5 - 32.0) / 32.0, (y + 0.5 - 16.0) / 16.0).length()
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.03, 0.05, 0.09, pow(a, 0.9) * 0.55))
	img.generate_mipmaps()
	shadow_tex = ImageTexture.create_from_image(img)
	var pi := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 5
	nz.frequency = 0.06
	for y in 96:
		for x in 96:
			var d := Vector2(x - 47.5, y - 47.5).length() / 48.0
			var n := 0.75 + 0.5 * nz.get_noise_2d(x, y)
			var a := clampf(1.0 - d * n * 1.05, 0.0, 1.0)
			pi.set_pixel(x, y, Color(0.80, 0.79, 0.77, pow(a, 1.4) * 0.62))
	pi.generate_mipmaps()
	puff_tex = ImageTexture.create_from_image(pi)

# ------------------------------------------------------------------ sitio de la escena de referencia

## Busca un claro de hierba grande (casi sin agua, roca, desierto ni nieve) y, a ser posible, con costa cerca.
func _find_site() -> Vector2i:
	var best := Vector2i(64, 64)
	var bs := -100000
	for cy in range(26, sim.H - 26, 2):
		for cx in range(26, sim.W - 26, 2):
			var bad := 0
			for dv in range(-11, 13, 2):
				for du in range(-13, 15, 2):
					var i: int = (cy + dv) * sim.W + cx + du
					var h: int = sim.heat[i]
					if sim.terrain[i] == Defs.T_WATER or sim.terrain[i] == Defs.T_ROCK or sim.rtype[i] == Defs.R_GOLD or sim.rtype[i] == Defs.R_STONE:
						bad += 3
					elif h < 105 or h > 150:
						bad += 1
			var score := -bad * 6
			for dv in range(-20, 21, 2):
				for du in range(-24, 25, 2):
					if absi(du) <= 13 and absi(dv) <= 11:
						continue
					var q := Vector2i(cx + du, cy + dv)
					if sim.in_bounds(q) and sim.terrain[q.y * sim.W + q.x] == Defs.T_WATER:
						score += 1
			if score > bs:
				bs = score
				best = Vector2i(cx, cy)
	print("INFO puntuación de sitio ", bs)
	return best

# ------------------------------------------------------------------ dibujo

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

## Sombra horneada del modelo (name_sh): cae siempre hacia la derecha de la pantalla, aunque el sprite vaya reflejado.
func _shadow_of(name: String, ground: Vector2, sc: float = 1.0) -> void:
	if anchors.has(name + "_sh"):
		_spr(shadows, name + "_sh", ground, sc).modulate.a = 0.80

func _ellipse(ground: Vector2, rx: float, ry: float, shift: Vector2 = Vector2(0.14, 0.04)) -> void:
	var sp := Sprite2D.new()
	sp.texture = shadow_tex
	sp.position = iso(ground + shift)
	sp.scale = Vector2(rx / 32.0, ry / 16.0)
	shadows.add_child(sp)

func _prop(name: String, g: Vector2, sc: float = 1.0, flip: bool = false) -> void:
	if not anchors.has(name):
		return
	_shadow_of(name, g, sc)
	_spr(objs, name, g, sc, flip)

func _unit(kind: String, team: String, g: Vector2, face: Vector2, walking: bool, k: int) -> void:
	var ang := atan2(face.x, face.y)                  # yaw 0 = hacia +y de casilla
	var dir := posmod(int(round(ang / (PI * 0.25))), 8)
	var nm := "%s_%s_%d_%s" % [kind, team, dir, ("w%d" % (k % 4)) if walking else "idle"]
	if not anchors.has(nm):
		nm = "%s_blue_%d_%s" % [kind, dir, ("w%d" % (k % 4)) if walking else "idle"]
	if not anchors.has(nm):
		return
	_ellipse(g, 11.0 * UNIT_SC * 1.5, 5.0 * UNIT_SC * 1.5)
	_spr(objs, nm, g, UNIT_SC)

func _build_scene() -> void:
	world = Node2D.new()
	add_child(world)
	world.scale = Vector2(zoom_v, zoom_v)
	var centre := P(off.x, off.y)
	world.position = Vector2(640, 360) - iso(centre) * zoom_v
	var mat := TerrainFx.make_material(sim)
	mat.shader = load("res://tools/iso/terrain_iso.gdshader")
	mat.set_shader_parameter("tile_px", float(Defs.TILE))
	mat.set_shader_parameter("tm", 0.0)
	mat.set_shader_parameter("lego", 1.0 if lego_style else 0.0)
	road_img = Image.create(sim.W, sim.H, false, Image.FORMAT_R8)
	if scene_v == "ref":
		_paint_roads()
	mat.set_shader_parameter("road", ImageTexture.create_from_image(road_img))
	mat.set_shader_parameter("use_road", 1.0 if scene_v == "ref" else 0.0)
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
	air = Node2D.new()
	world.add_child(air)
	# árboles, oro y piedra del mapa real
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
		if comp_rect.has_point(g):
			continue
		var hsh := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
		var jit := Vector2(float((hsh >> 3) % 100) / 100.0 - 0.5, float((hsh >> 9) % 100) / 100.0 - 0.5) * 0.45
		var heat := float(sim.heat[i]) / 255.0
		if rt == Defs.R_TREE:
			_prop(_tree_name(hsh, heat), g + jit, 0.92 + float((hsh >> 13) % 20) / 100.0, (hsh >> 17) % 2 == 0)
			n_tree += 1
		elif rt == Defs.R_GOLD:
			_prop("oro_0", g)
		elif rt == Defs.R_STONE:
			_prop("roca_0", g)
	print("INFO árboles del mapa ", n_tree)

## Camino: pinta una línea gruesa (en casillas locales) en la máscara del camino y reserva el sitio para los árboles.
func _road_line(a: Vector2, b: Vector2, half_w: float) -> void:
	var L := a.distance_to(b)
	var n := maxi(1, int(L * 2.0))
	for i in n + 1:
		var c := P(0, 0) + a.lerp(b, float(i) / float(n))
		blockers.append([c, half_w + 0.3])
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var q := Vector2i(int(floor(c.x)) + dx, int(floor(c.y)) + dy)
				if not sim.in_bounds(q):
					continue
				if Vector2(q.x + 0.5, q.y + 0.5).distance_to(c) <= half_w:
					road_img.set_pixel(q.x, q.y, Color(1, 0, 0, 1))

func _paint_roads() -> void:
	_road_line(Vector2(10.2, 3.4), Vector2(10.2, 9.6), 0.95)       # de la puerta del castillo hacia el sur
	_road_line(Vector2(10.2, 9.6), Vector2(-3.0, 9.6), 0.95)      # hacia el poblado
	_road_line(Vector2(10.2, 4.6), Vector2(14.0, 4.6), 0.80)
	_road_line(Vector2(1.5, 1.0), Vector2(1.5, 9.6), 0.8)        # paso junto a la muralla
	_road_line(Vector2(10.2, 5.8), Vector2(10.2, 5.8), 2.1)        # plaza ante la puerta

func _tree_name(hsh: int, heat: float) -> String:
	if heat < 0.42 or (hsh >> 15) % 100 < 22:
		return "pino_%d" % ((hsh >> 5) % 2)
	var v := (hsh >> 5) % 10
	return "roble_%d" % (4 + v % 3 if v >= 7 else v % 4)    # 30 % de otoño

# ------------------------------------------------------------------ escena base (junto al centro urbano)

func _populate_base() -> void:
	var s: Vector2i = site
	for spec in [["casa", Vector2i(-8, 4)], ["casa", Vector2i(-8, 8)], ["casa", Vector2i(8, -6)], ["torre", Vector2i(6, 7)], ["casa", Vector2i(10, 4)]]:
		var t := _free(s + (spec[1] as Vector2i), spec[0] as String)
		if t.x >= 0:
			var sz: int = Defs.BUILDINGS[spec[0] as String]["size"]
			_prop("%s_blue" % (spec[0] as String), Vector2(t.x + sz * 0.5, t.y + sz * 0.5))
	for i in 8:
		var ft := sim.nearest_free_tile(s + Vector2i(i - 3, 8), 6)
		_unit("espadachin", "blue", Vector2(ft.x + 0.5, ft.y + 0.5), Vector2(0.4, 1.0), true, i)

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

# ------------------------------------------------------------------ escena de referencia: asedio a una fortaleza

func _near_blocker(g: Vector2, extra: float = 0.0) -> bool:
	for b in blockers:
		if g.distance_to(b[0] as Vector2) < float(b[1]) + extra:
			return true
	return false

## Tramo de muralla entre dos bordes (coordenadas locales). Los tramos con centro dentro de `gap` se omiten (brecha).
func _wall_raw(a: Vector2, b: Vector2, gap: Rect2 = Rect2()) -> void:
	var d := b - a
	var L := d.length()
	var dir := d / L
	var along_x := absf(dir.x) > absf(dir.y)
	var n := maxi(1, int(ceil(L - 0.001)))
	var step := L / float(n)
	for k in n:
		var c := a + dir * (step * (float(k) + 0.5))
		if gap.size != Vector2.ZERO and gap.has_point(c):
			continue
		blockers.append([P(c.x, c.y), 0.95])
		_prop("muralla_x" if along_x else "muralla_z", P(c.x, c.y))

## Muralla entre los centros de dos torres: deja 0.75 libres en cada extremo.
func _wall(a: Vector2, b: Vector2, gap: Rect2 = Rect2()) -> void:
	var dir := (b - a).normalized()
	_wall_raw(a + dir * 0.75, b - dir * 0.75, gap)

func _tower(name: String, u: float, v: float) -> void:
	blockers.append([P(u, v), 1.5])
	_prop(name, P(u, v))

func _compose_ref() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# castillo y murallas: dos lienzos en ángulo con torres y atalayas
	blockers.append([P(10.2, 1), 3.0])
	_prop("castillo_blue", P(10.2, 1))
	_tower("torrec_blue", 6.0, 1.0)
	_tower("atalaya_blue", 0.0, 1.0)
	_tower("torrec_blue", -6.0, 1.0)
	_tower("torrec_blue", 0.0, 7.0)
	_tower("atalaya_blue", 0.0, 12.0)
	_wall(Vector2(6.0, 1.0), Vector2(0.0, 1.0))
	_wall_raw(Vector2(6.75, 1.0), Vector2(8.5, 1.0))              # empalma con la cortina oeste del castillo
	_wall(Vector2(0.0, 1.0), Vector2(-6.0, 1.0), Rect2(-3.6, 0.2, 1.8, 1.6))     # brecha entre la atalaya y la torre de la izquierda
	_wall(Vector2(0.0, 1.0), Vector2(0.0, 7.0))
	_wall(Vector2(0.0, 7.0), Vector2(0.0, 12.0))
	# casas del poblado a la izquierda
	for h in [Vector2(-3.4, 7.4), Vector2(-2.6, 10.6)]:
		blockers.append([P(h.x, h.y), 1.8])
		_prop("casa_blue", P(h.x, h.y))
	# máquinas de asedio (giradas hacia la muralla)
	for s in [["trabuquete_blue", Vector2(-2.0, -7.0)], ["trabuquete_blue", Vector2(-8.0, -3.0)], ["catapulta_blue", Vector2(-5.0, -5.2)], ["catapulta_blue", Vector2(3.5, -4.8)]]:
		blockers.append([P((s[1] as Vector2).x, (s[1] as Vector2).y), 1.4])
		_prop(s[0] as String, P((s[1] as Vector2).x, (s[1] as Vector2).y), 1.0, true)
	# árboles: cuatro bosquetes y algunos sueltos (30 % de otoño)
	var clumps := [[Vector2(3.5, 5.5), 3.2, 20], [Vector2(8.0, 12.0), 2.6, 9], [Vector2(-6.5, 3.5), 2.6, 9], [Vector2(4.0, -2.5), 2.6, 9], [Vector2(-4.0, 13.0), 2.4, 7]]
	var n_t := 0
	for c in clumps:
		for k in int(c[2]):
			for tries in 12:
				var ang := rng.randf() * TAU
				var rr := sqrt(rng.randf()) * float(c[1])
				var g := P((c[0] as Vector2).x + cos(ang) * rr, (c[0] as Vector2).y + sin(ang) * rr * 0.85)
				if _near_blocker(g, 0.35) or sim.terrain[int(g.y) * sim.W + int(g.x)] == Defs.T_WATER:
					continue
				var hsh := rng.randi() & 0x7fffffff
				_prop(_tree_name(hsh, 0.6), g, 0.9 + rng.randf() * 0.35, hsh % 2 == 0)
				blockers.append([g, 0.55])
				n_t += 1
				break
	print("INFO árboles de la composición ", n_t)
	# unidades en grupos: atacantes rojos hacia la muralla, defensores azules tras ella y ante el castillo, aldeanos en el poblado
	var k := 0
	for cl in [[Vector2(-5.5, -2.2), 15, 2.6, "red", Vector2(0.15, 1.0), 0.9], [Vector2(-0.5, -3.2), 15, 2.4, "red", Vector2(0.0, 1.0), 0.9],
			[Vector2(-9.5, -0.5), 12, 2.2, "red", Vector2(0.3, 1.0), 0.8], [Vector2(3.8, -1.8), 14, 2.2, "red", Vector2(-0.2, 1.0), 0.9],
			[Vector2(-1.5, 3.4), 10, 2.0, "blue", Vector2(0.0, -1.0), 0.4], [Vector2(3.4, 3.2), 8, 1.6, "blue", Vector2(0.0, -1.0), 0.4],
			[Vector2(10.2, 6.4), 17, 2.0, "blue", Vector2(0.0, 1.0), 0.5], [Vector2(13.0, 3.8), 8, 1.4, "blue", Vector2(-1.0, 0.5), 0.4]]:
		var cc: Vector2 = cl[0]
		for i in int(cl[1]):
			var g := P(cc.x + rng.randf_range(-1.0, 1.0) * float(cl[2]), cc.y + rng.randf_range(-1.0, 1.0) * float(cl[2]) * 0.8)
			if _near_blocker(g, 0.3):
				continue
			var face: Vector2 = (cl[4] as Vector2) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.3, 0.3))
			_unit("espadachin" if i % 7 != 3 else "aldeano", cl[3] as String, g, face, rng.randf() < float(cl[5]), k)
			blockers.append([g, 0.42])
			k += 1
	for i in 7:
		var g := P(-4.5 + rng.randf() * 2.5, 8.2 + rng.randf() * 3.0)
		if _near_blocker(g, 0.3):
			continue
		_unit("aldeano", "blue", g, Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)), rng.randf() < 0.5, k)
		blockers.append([g, 0.42])
		k += 1
	# humo de la brecha
	for i in 8:
		var sp := Sprite2D.new()
		sp.texture = puff_tex
		sp.position = iso(P(-2.8 + rng.randf() * 1.2, 1.0 + rng.randf() * 0.8)) + Vector2(rng.randf_range(-6, 6), -14.0 - float(i) * 6.0)
		var sc := 0.55 + float(i) * 0.09
		sp.scale = Vector2(sc, sc * 0.9)
		air.add_child(sp)
