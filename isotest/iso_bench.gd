extends Node2D
## PRUEBA DE RENDIMIENTO ISOMÉTRICA (no es el juego). Mapa real de Sim con terreno isométrico, árboles, fortaleza, máquinas y
## cientos de unidades que caminan, con sprites pre-renderizados en 3D. Sirve para medir en el móvil si este enfoque aguanta.
## Gestos: un dedo arrastra, dos dedos acercan/alejan, un toque selecciona la unidad más cercana (y mide el error del toque).
## Botones: unidades, atlas, sombras, terreno (shader o plano) y "Medir 10 s" (recorre el mapa y da FPS medio, 1 % peor y peor fotograma).
## Escritorio: rueda = zoom, botón izquierdo = arrastrar. Prueba automática: -- autotest=3 shot=/tmp/bench.png
const TW2 := 32.0
const TH2 := 16.0
const UNIT_SC := 0.52
const SITE := Vector2i(80, 44)            # claro de hierba junto a la costa en la semilla 4
const SEED := 4
const SHEET_DIR := "res://isotest/sprites/"
const MAX_UNITS := 800
const AREA := Rect2(-12.0, -9.0, 26.0, 21.0)   # zona (casillas locales) por la que pasean las unidades

var sim: Sim
var anchors: Dictionary = {}               # nombre -> [ox, oy]
var regions: Dictionary = {}               # nombre -> [hoja, x, y, w, h]
var sheet_tex: Array = []
var ind_cache: Dictionary = {}
var atlas_cache: Dictionary = {}
var use_atlas := true
var shadows_on := true
var terrain_shader := true
var shadow_tex: Texture2D
var puff_tex: Texture2D

var world: Node2D
var terrain_poly: Polygon2D
var flat_poly: Polygon2D
var shadows: Node2D
var objs: Node2D
var air: Node2D
var sel_ring: Node2D
var all_sprites: Array = []                # Sprite2D con meta "name" (para cambiar atlas / texturas sueltas)
var units: Array = []                      # Dictionary por unidad
var blockers: Array = []
var n_static := 0
var rng := RandomNumberGenerator.new()

var zoom := 1.3
var centre := Vector2.ZERO                 # centro de la vista en píxeles de mundo isométrico
var touches: Dictionary = {}
var tap_info: Dictionary = {}
var ui_touch: Dictionary = {}
var mouse_down := false
var mouse_moved := 0.0
var pinch_prev := 0.0
var selected := -1
var sel_msg := ""

var ui: CanvasLayer
var info: Label
var result_lbl: Label
var panel: PanelContainer
var btn_atlas: Button
var btn_shadow: Button
var btn_terrain: Button
var frame_ms: PackedFloat32Array = PackedFloat32Array()
var info_t := 0.0
var measuring := false
var meas_t := 0.0
var meas_len := 10.0
var meas_ms: PackedFloat32Array = PackedFloat32Array()
var meas_cfg := ""
var ladder: Array = []                     # pasos pendientes de la prueba escalonada (nº de unidades)
var ladder_res: Array = []
var ladder_on := false
var autotest := 0.0
var auto_ladder := false
var tap_test := false
var shot_path := ""
var anim_t := 0.0

func iso(t: Vector2) -> Vector2:
	return Vector2((t.x - t.y) * TW2, (t.x + t.y) * TH2)

func P(u: float, v: float) -> Vector2:
	return Vector2(float(SITE.x) + u, float(SITE.y) + v)

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("autotest="): autotest = float(a.substr(9))
		elif a.begins_with("shot="): shot_path = a.substr(5)
		elif a == "ladder": auto_ladder = true
		elif a == "noatlas": use_atlas = false
		elif a == "taptest": tap_test = true
	Engine.max_fps = 0                                           # sin tope: se quiere medir lo que da el aparato
	OS.low_processor_usage_mode = false                          # el juego usa modo de bajo consumo; aquí se dibuja siempre, como en partida con unidades en movimiento
	Input.emulate_touch_from_mouse = false                       # en escritorio el ratón va por su propio camino (en el móvil los toques son reales)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	rng.seed = 5
	_load_sprites()
	sim = Sim.new()
	sim.setup({"size": 128, "seed": SEED, "events": false, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú", "civ": "castellanos"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo"}]})
	sim.ais.clear()
	_make_textures()
	_build_world()
	_compose()
	_spawn_units(150)
	_build_ui()
	centre = iso(P(3.2, 0.3))
	_apply_camera()
	if tap_test:
		get_tree().create_timer(1.0).timeout.connect(_run_tap_test)
	if auto_ladder:
		autotest = maxf(autotest, 1.0)
		get_tree().create_timer(1.5).timeout.connect(_start_ladder)
	elif autotest > 0.0:
		get_tree().create_timer(1.5).timeout.connect(func() -> void: _start_measure(autotest))

# ------------------------------------------------------------------ sprites

func _load_sprites() -> void:
	var ad: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHEET_DIR + "atlas.json"))
	for nm in ad["sprites"]:
		var r: Array = ad["sprites"][nm]
		regions[nm] = [int(r[0]), float(r[1]), float(r[2]), float(r[3]), float(r[4])]
		anchors[nm] = [float(r[5]), float(r[6])]
	for s in ad["sheets"]:
		var img: Image = (load(SHEET_DIR + (s as String)) as Texture2D).get_image()
		img.generate_mipmaps()
		sheet_tex.append(ImageTexture.create_from_image(img))

func _tex(nm: String) -> Texture2D:
	if use_atlas:
		if not atlas_cache.has(nm):
			var r: Array = regions[nm]
			var at := AtlasTexture.new()
			at.atlas = sheet_tex[int(r[0])]
			at.region = Rect2(float(r[1]), float(r[2]), float(r[3]), float(r[4]))
			atlas_cache[nm] = at
		return atlas_cache[nm]
	if not ind_cache.has(nm):
		var img: Image = (load(SHEET_DIR + "ind/" + nm + ".png") as Texture2D).get_image()
		img.generate_mipmaps()
		ind_cache[nm] = ImageTexture.create_from_image(img)
	return ind_cache[nm]

func _make_sprite(parent: Node2D, nm: String, ground: Vector2, sc: float = 1.0, flip: bool = false) -> Sprite2D:
	var an: Array = anchors[nm]
	var sp := Sprite2D.new()
	sp.texture = _tex(nm)
	sp.centered = false
	sp.offset = -Vector2(float(an[0]), float(an[1]))
	sp.scale = Vector2(0.5 * sc * (-1.0 if flip else 1.0), 0.5 * sc)
	sp.position = iso(ground)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sp.set_meta("name", nm)
	parent.add_child(sp)
	all_sprites.append(sp)
	return sp

func _set_sprite(sp: Sprite2D, nm: String) -> void:
	if sp.get_meta("name") == nm:
		return
	var an: Array = anchors[nm]
	sp.set_meta("name", nm)
	sp.texture = _tex(nm)
	sp.offset = -Vector2(float(an[0]), float(an[1]))

func _make_textures() -> void:
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 64:
			var d := Vector2((x + 0.5 - 32.0) / 32.0, (y + 0.5 - 16.0) / 16.0).length()
			img.set_pixel(x, y, Color(0.03, 0.05, 0.09, pow(clampf(1.0 - d, 0.0, 1.0), 0.9) * 0.55))
	img.generate_mipmaps()
	shadow_tex = ImageTexture.create_from_image(img)
	var pi := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 5
	nz.frequency = 0.06
	for y in 96:
		for x in 96:
			var d := Vector2(x - 47.5, y - 47.5).length() / 48.0
			var a := clampf(1.0 - d * (0.75 + 0.5 * nz.get_noise_2d(x, y)) * 1.05, 0.0, 1.0)
			pi.set_pixel(x, y, Color(0.80, 0.79, 0.77, pow(a, 1.4) * 0.62))
	pi.generate_mipmaps()
	puff_tex = ImageTexture.create_from_image(pi)

# ------------------------------------------------------------------ mundo

func _build_world() -> void:
	world = Node2D.new()
	add_child(world)
	var mat := TerrainFx.make_material(sim)
	mat.shader = load("res://isotest/terrain_iso.gdshader")
	mat.set_shader_parameter("tile_px", float(Defs.TILE))
	mat.set_shader_parameter("tm", 0.0)
	mat.set_shader_parameter("anim", 1.0)
	var img := Image.create(sim.W, sim.H, false, Image.FORMAT_R8)
	mat.set_shader_parameter("road", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("use_road", 0.0)
	var quad := PackedVector2Array([iso(Vector2(0, 0)), iso(Vector2(sim.W, 0)), iso(Vector2(sim.W, sim.H)), iso(Vector2(0, sim.H))])
	terrain_poly = Polygon2D.new()
	terrain_poly.polygon = quad
	terrain_poly.material = mat
	world.add_child(terrain_poly)
	flat_poly = Polygon2D.new()
	flat_poly.polygon = quad
	flat_poly.color = Color(0.30, 0.55, 0.20)
	flat_poly.visible = false
	world.add_child(flat_poly)
	shadows = Node2D.new()
	world.add_child(shadows)
	objs = Node2D.new()
	objs.y_sort_enabled = true
	world.add_child(objs)
	air = Node2D.new()
	world.add_child(air)
	sel_ring = Node2D.new()
	sel_ring.draw.connect(_draw_ring)
	air.add_child(sel_ring)
	# árboles y recursos del mapa real en un radio amplio (no dentro de la zona de la composición)
	var comp := Rect2(P(-13, -11), Vector2(27, 24))
	var n := 0
	for yy in range(maxi(0, SITE.y - 36), mini(sim.H, SITE.y + 36)):
		for xx in range(maxi(0, SITE.x - 40), mini(sim.W, SITE.x + 40)):
			var i := yy * sim.W + xx
			var rt: int = sim.rtype[i]
			if rt == 0:
				continue
			var g := Vector2(xx + 0.5, yy + 0.5)
			if comp.has_point(g):
				continue
			var hsh := ((xx * 73856093) ^ (yy * 19349663)) & 0x7fffffff
			var jit := Vector2(float((hsh >> 3) % 100) / 100.0 - 0.5, float((hsh >> 9) % 100) / 100.0 - 0.5) * 0.45
			if rt == Defs.R_TREE:
				_prop(_tree_name(hsh, float(sim.heat[i]) / 255.0), g + jit, 0.92 + float((hsh >> 13) % 20) / 100.0, (hsh >> 17) % 2 == 0)
				n += 1
			elif rt == Defs.R_GOLD:
				_prop("oro_0", g)
			elif rt == Defs.R_STONE:
				_prop("roca_0", g)

func _tree_name(hsh: int, heat: float) -> String:
	if heat < 0.42 or (hsh >> 15) % 100 < 22:
		return "pino_%d" % ((hsh >> 5) % 2)
	var v := (hsh >> 5) % 10
	return "roble_%d" % (4 + v % 3 if v >= 7 else v % 4)

func _prop(nm: String, g: Vector2, sc: float = 1.0, flip: bool = false) -> void:
	if not anchors.has(nm):
		return
	if anchors.has(nm + "_sh"):
		var sh := _make_sprite(shadows, nm + "_sh", g, sc)
		sh.modulate.a = 0.80
		sh.set_meta("shadow", true)
	_make_sprite(objs, nm, g, sc, flip)
	n_static += 1

func _near_blocker(g: Vector2, extra: float = 0.0) -> bool:
	for b in blockers:
		if g.distance_to(b[0] as Vector2) < float(b[1]) + extra:
			return true
	return false

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

func _wall(a: Vector2, b: Vector2, gap: Rect2 = Rect2()) -> void:
	var dir := (b - a).normalized()
	_wall_raw(a + dir * 0.75, b - dir * 0.75, gap)

func _tower(nm: String, u: float, v: float) -> void:
	blockers.append([P(u, v), 1.5])
	_prop(nm, P(u, v))

func _compose() -> void:
	blockers.append([P(10.2, 1), 3.0])
	_prop("castillo_blue", P(10.2, 1))
	_tower("torrec_blue", 6.0, 1.0)
	_tower("atalaya_blue", 0.0, 1.0)
	_tower("torrec_blue", -6.0, 1.0)
	_tower("torrec_blue", 0.0, 7.0)
	_tower("atalaya_blue", 0.0, 12.0)
	_wall(Vector2(6.0, 1.0), Vector2(0.0, 1.0))
	_wall_raw(Vector2(6.75, 1.0), Vector2(8.5, 1.0))
	_wall(Vector2(0.0, 1.0), Vector2(-6.0, 1.0), Rect2(-3.6, 0.2, 1.8, 1.6))
	_wall(Vector2(0.0, 1.0), Vector2(0.0, 7.0))
	_wall(Vector2(0.0, 7.0), Vector2(0.0, 12.0))
	for h in [Vector2(-3.4, 7.4), Vector2(-2.6, 10.6)]:
		blockers.append([P(h.x, h.y), 1.8])
		_prop("casa_blue", P(h.x, h.y))
	for s in [["trabuquete_blue", Vector2(-2.0, -7.0)], ["trabuquete_blue", Vector2(-8.0, -3.0)], ["catapulta_blue", Vector2(-5.0, -5.2)], ["catapulta_blue", Vector2(3.5, -4.8)]]:
		var sp: Vector2 = s[1]
		blockers.append([P(sp.x, sp.y), 1.4])
		_prop(s[0] as String, P(sp.x, sp.y), 1.0, true)
	var clumps := [[Vector2(3.5, 5.5), 3.2, 20], [Vector2(8.0, 12.0), 2.6, 9], [Vector2(-6.5, 3.5), 2.6, 9], [Vector2(4.0, -2.5), 2.6, 9], [Vector2(-4.0, 13.0), 2.4, 7]]
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
				break
	for i in 8:
		var sp2 := Sprite2D.new()
		sp2.texture = puff_tex
		sp2.position = iso(P(-2.8 + rng.randf() * 1.2, 1.0 + rng.randf() * 0.8)) + Vector2(rng.randf_range(-6, 6), -14.0 - float(i) * 6.0)
		var sc := 0.55 + float(i) * 0.09
		sp2.scale = Vector2(sc, sc * 0.9)
		air.add_child(sp2)

# ------------------------------------------------------------------ unidades

func _unit_name(u: Dictionary, walking: bool) -> String:
	var ang := atan2((u["vel"] as Vector2).x, (u["vel"] as Vector2).y)
	var dir := posmod(int(round(ang / (PI * 0.25))), 8)
	var frame := "w%d" % (int(anim_t * 6.0 + float(u["ph"])) % 4) if walking else "idle"
	return "%s_%s_%d_%s" % [u["kind"], u["team"], dir, frame]

func _spawn_units(n: int) -> void:
	for i in n:
		if units.size() >= MAX_UNITS:
			break
		var team := "red" if rng.randf() < 0.5 else "blue"
		var u := {"kind": "espadachin" if rng.randf() < 0.85 else "aldeano", "team": team, "pos": Vector2.ZERO, "tgt": Vector2.ZERO,
			"vel": Vector2(0, 1), "spd": rng.randf_range(0.9, 1.7), "ph": rng.randi() % 4, "wait": 0.0}
		var p := Vector2(rng.randf_range(AREA.position.x, AREA.end.x), rng.randf_range(AREA.position.y, AREA.end.y))
		u["pos"] = P(p.x, p.y)
		u["tgt"] = u["pos"]
		var nm := _unit_name(u, true)
		u["sp"] = _make_sprite(objs, nm, u["pos"], UNIT_SC)
		var sh := Sprite2D.new()
		sh.texture = shadow_tex
		sh.scale = Vector2(11.0 * UNIT_SC * 1.5 / 32.0, 5.0 * UNIT_SC * 1.5 / 16.0)
		sh.visible = shadows_on
		shadows.add_child(sh)
		u["sh"] = sh
		units.append(u)

func _remove_units(n: int) -> void:
	for i in n:
		if units.is_empty():
			break
		var u: Dictionary = units.pop_back()
		var sp: Sprite2D = u["sp"]
		all_sprites.erase(sp)
		sp.queue_free()
		(u["sh"] as Sprite2D).queue_free()
	selected = mini(selected, units.size() - 1)

func _update_units(dt: float) -> void:
	anim_t += dt
	for u in units:
		var pos: Vector2 = u["pos"]
		var walking := false
		if float(u["wait"]) > 0.0:
			u["wait"] = float(u["wait"]) - dt
		else:
			var d: Vector2 = (u["tgt"] as Vector2) - pos
			if d.length() < 0.15:
				var t := Vector2(rng.randf_range(AREA.position.x, AREA.end.x), rng.randf_range(AREA.position.y, AREA.end.y))
				u["tgt"] = P(t.x, t.y)
				u["wait"] = rng.randf_range(0.0, 1.5) if rng.randf() < 0.3 else 0.0
			else:
				u["vel"] = d.normalized()
				pos += (u["vel"] as Vector2) * float(u["spd"]) * dt
				u["pos"] = pos
				walking = true
		var sp: Sprite2D = u["sp"]
		_set_sprite(sp, _unit_name(u, walking))
		sp.position = iso(pos)
		(u["sh"] as Sprite2D).position = iso(pos + Vector2(0.14, 0.04))

# ------------------------------------------------------------------ cámara, gestos, selección

func _apply_camera() -> void:
	var half := get_viewport_rect().size * 0.5
	var lim_x := iso(Vector2(sim.W, 0)).x - 200.0
	centre.x = clampf(centre.x, -lim_x, lim_x)
	centre.y = clampf(centre.y, 100.0, iso(Vector2(sim.W, sim.H)).y - 100.0)
	world.scale = Vector2(zoom, zoom)
	world.position = half - centre * zoom

func _screen_to_world(p: Vector2) -> Vector2:
	return (p - world.position) / zoom

func _in_ui(p: Vector2) -> bool:
	return panel != null and panel.get_global_rect().grow(8.0).has_point(p)

func _input(ev: InputEvent) -> void:
	if measuring:
		return
	if ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		if t.pressed:
			if _in_ui(t.position):
				ui_touch[t.index] = true
				return
			touches[t.index] = t.position
			tap_info[t.index] = [t.position, Time.get_ticks_msec()]
			pinch_prev = 0.0
		else:
			if ui_touch.has(t.index):
				ui_touch.erase(t.index)
				return
			if tap_info.has(t.index) and touches.size() == 1:
				var ti: Array = tap_info[t.index]
				if (ti[0] as Vector2).distance_to(t.position) < 16.0 and Time.get_ticks_msec() - int(ti[1]) < 350:
					_tap(t.position)
			touches.erase(t.index)
			tap_info.erase(t.index)
			pinch_prev = 0.0
	elif ev is InputEventScreenDrag:
		var d := ev as InputEventScreenDrag
		if ui_touch.has(d.index) or not touches.has(d.index):
			return
		touches[d.index] = d.position
		if touches.size() == 1:
			centre -= d.relative / zoom
			_apply_camera()
		elif touches.size() == 2:
			var keys := touches.keys()
			var a: Vector2 = touches[keys[0]]
			var b: Vector2 = touches[keys[1]]
			var dist := a.distance_to(b)
			if pinch_prev > 0.0 and dist > 1.0:
				_zoom_at((a + b) * 0.5, zoom * dist / pinch_prev)
			pinch_prev = dist
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).device != InputEvent.DEVICE_ID_EMULATION:
		var m := ev as InputEventMouseButton
		if m.button_index == MOUSE_BUTTON_WHEEL_UP and not _in_ui(m.position):
			_zoom_at(m.position, zoom * 1.1)
		elif m.button_index == MOUSE_BUTTON_WHEEL_DOWN and not _in_ui(m.position):
			_zoom_at(m.position, zoom / 1.1)
		elif m.button_index == MOUSE_BUTTON_LEFT:
			if m.pressed and not _in_ui(m.position):
				mouse_down = true
				mouse_moved = 0.0
			elif not m.pressed:
				if mouse_down and mouse_moved < 8.0:
					_tap(m.position)
				mouse_down = false
	elif ev is InputEventMouseMotion and (ev as InputEventMouseMotion).device != InputEvent.DEVICE_ID_EMULATION:
		var mm := ev as InputEventMouseMotion
		if mouse_down:
			mouse_moved += mm.relative.length()
			centre -= mm.relative / zoom
			_apply_camera()

## Prueba automática del toque: pulsa y suelta (como un dedo) a unos píxeles del cuerpo de una unidad.
func _run_tap_test() -> void:
	var body := Vector2.ZERO
	for u2 in units:
		var b: Vector2 = world.position + (iso(u2["pos"]) + Vector2(0.0, -22.0 * UNIT_SC * 2.0)) * zoom
		if b.y > 330.0 and b.y < 650.0 and b.x > 100.0 and b.x < 1100.0:
			body = b
			break
	for off in [Vector2(9, 6), Vector2(-30, 20)]:
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.pressed = true
		down.position = body + off
		_input(down)
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.pressed = false
		up.position = body + off
		_input(up)
		print("INFO taptest ", sel_msg)

func _zoom_at(p: Vector2, z: float) -> void:
	z = clampf(z, 0.6, 2.6)
	var w := _screen_to_world(p)
	zoom = z
	world.scale = Vector2(zoom, zoom)
	world.position = p - w * zoom
	centre = (get_viewport_rect().size * 0.5 - world.position) / zoom
	_apply_camera()

## Toque: elige la unidad cuyo sprite (cuerpo) queda más cerca del dedo y mide a cuántos píxeles de pantalla estaba.
func _tap(p: Vector2) -> void:
	var w := _screen_to_world(p)
	var best := -1
	var bd := 1e9
	for i in units.size():
		var c: Vector2 = iso(units[i]["pos"]) + Vector2(0.0, -22.0 * UNIT_SC * 2.0)
		var d := c.distance_to(w) * zoom
		if d < bd:
			bd = d
			best = i
	if best >= 0 and bd < 70.0:
		selected = best
		var u: Dictionary = units[best]
		sel_msg = "Seleccionado: %s %s nº %d · error del toque %d px" % [u["kind"], "rojo" if u["team"] == "red" else "azul", best, int(bd)]
	else:
		selected = -1
		sel_msg = "Toque sin unidad cerca (más cercana a %d px)" % int(bd)
	sel_ring.queue_redraw()

func _draw_ring() -> void:
	if selected < 0 or selected >= units.size():
		return
	var c: Vector2 = iso(units[selected]["pos"])
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * float(i) / 32.0
		pts.append(c + Vector2(cos(a) * 20.0, sin(a) * 10.0))
	sel_ring.draw_polyline(pts, Color(1.0, 0.95, 0.3), 2.0)

# ------------------------------------------------------------------ interfaz y medición

func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	return b

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	panel = PanelContainer.new()
	panel.position = Vector2(8, 8)
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 18)
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", 4)
	vb.add_child(info)
	var row1 := HBoxContainer.new()
	vb.add_child(row1)
	row1.add_child(_make_button("+100 unidades", func() -> void: _spawn_units(100)))
	row1.add_child(_make_button("−100 unidades", func() -> void: _remove_units(100)))
	btn_atlas = _make_button("", _toggle_atlas)
	row1.add_child(btn_atlas)
	var row2 := HBoxContainer.new()
	vb.add_child(row2)
	btn_shadow = _make_button("", _toggle_shadows)
	row2.add_child(btn_shadow)
	btn_terrain = _make_button("", _toggle_terrain)
	row2.add_child(btn_terrain)
	row2.add_child(_make_button("Medir 10 s", func() -> void: _start_measure(10.0)))
	var row3 := HBoxContainer.new()
	vb.add_child(row3)
	row3.add_child(_make_button("Prueba escalonada", _start_ladder))
	row3.add_child(_make_button("Salir", func() -> void: get_tree().quit()))
	result_lbl = Label.new()
	result_lbl.add_theme_font_size_override("font_size", 20)
	result_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	result_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	result_lbl.add_theme_constant_override("outline_size", 5)
	vb.add_child(result_lbl)
	_refresh_buttons()

func _refresh_buttons() -> void:
	btn_atlas.text = "Atlas: " + ("sí" if use_atlas else "no")
	btn_shadow.text = "Sombras: " + ("sí" if shadows_on else "no")
	btn_terrain.text = "Terreno: " + ("shader" if terrain_shader else "plano")

func _toggle_atlas() -> void:
	use_atlas = not use_atlas
	for sp: Sprite2D in all_sprites:
		sp.texture = _tex(sp.get_meta("name"))
	_refresh_buttons()

func _toggle_shadows() -> void:
	shadows_on = not shadows_on
	shadows.visible = shadows_on
	_refresh_buttons()

func _toggle_terrain() -> void:
	terrain_shader = not terrain_shader
	terrain_poly.visible = terrain_shader
	flat_poly.visible = not terrain_shader
	_refresh_buttons()

func _config_text() -> String:
	return "%d unidades · %d objetos fijos · atlas %s · sombras %s · terreno %s · zoom %.2f" % [units.size(), n_static, "sí" if use_atlas else "no", "sí" if shadows_on else "no", "shader" if terrain_shader else "plano", zoom]

func _start_measure(secs: float) -> void:
	measuring = true
	meas_t = 0.0
	meas_len = secs
	meas_ms = PackedFloat32Array()
	meas_cfg = _config_text()
	result_lbl.text = "Midiendo… no toques la pantalla"

func _start_ladder() -> void:
	ladder = [150, 300, 500, 800]
	ladder_res = []
	ladder_on = true
	_ladder_next()

func _ladder_next() -> void:
	if ladder.is_empty():
		ladder_on = false
		result_lbl.text = "ESCALONADA (FPS media / 1 % peor):\n" + "\n".join(PackedStringArray(ladder_res)) + "\n" + _gpu_text()
		print("INFO ", result_lbl.text.replace("\n", " | "))
		if shot_path != "":
			await get_tree().process_frame
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(shot_path)
		if autotest > 0.0:
			get_tree().quit()
		return
	var target: int = ladder.pop_front()
	if units.size() < target:
		_spawn_units(target - units.size())
	elif units.size() > target:
		_remove_units(units.size() - target)
	_start_measure(5.0)

func _finish_measure() -> void:
	measuring = false
	var s := meas_ms.duplicate()
	s.sort()
	var n := s.size()
	if n == 0:
		result_lbl.text = "Sin datos"
		return
	var avg := 0.0
	for v in s:
		avg += v
	avg /= maxf(1.0, float(n))
	var p99 := s[mini(n - 1, int(float(n) * 0.99))]
	if ladder_on:
		ladder_res.append("%d unidades: %.0f FPS (%.1f ms) · 1 %% peor %.0f FPS · peor %.1f ms" % [units.size(), 1000.0 / maxf(avg, 0.001), avg, 1000.0 / maxf(p99, 0.001), s[n - 1]])
		result_lbl.text = "Escalonada…\n" + "\n".join(PackedStringArray(ladder_res))
		_ladder_next()
		return
	var txt := "RESULTADO: %.0f FPS de media (%.1f ms) · 1 %% peor: %.0f FPS (%.1f ms) · peor fotograma %.1f ms\n%s\n%s" % [
		1000.0 / maxf(avg, 0.001), avg, 1000.0 / maxf(p99, 0.001), p99, s[n - 1], meas_cfg, _gpu_text()]
	result_lbl.text = txt
	print("INFO ", txt.replace("\n", " | "))
	if shot_path != "":
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("INFO captura ", shot_path)
	if autotest > 0.0:
		get_tree().quit()

func _gpu_text() -> String:
	return "GPU: %s · %s · Godot %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor(), Engine.get_version_info()["string"]]

func _process(dt: float) -> void:
	_update_units(dt)
	(terrain_poly.material as ShaderMaterial).set_shader_parameter("tm", anim_t)
	# ventana de las últimas 2 s para el contador en pantalla
	frame_ms.append(dt * 1000.0)
	if frame_ms.size() > 240:
		frame_ms = frame_ms.slice(frame_ms.size() - 240)
	if measuring:
		meas_t += dt
		if meas_t > 0.5:
			meas_ms.append(dt * 1000.0)
		var k := meas_t / meas_len
		var a := iso(P(3.0, 2.0))
		centre = a + Vector2(sin(k * TAU * 1.0) * 520.0, sin(k * TAU * 2.0 + 0.6) * 260.0)
		_apply_camera()
		if meas_t >= meas_len:
			_finish_measure()
	if selected >= 0:
		sel_ring.queue_redraw()
	info_t += dt
	if info_t >= 0.25:
		info_t = 0.0
		var sum := 0.0
		var worst := 0.0
		for v in frame_ms:
			sum += v
			worst = maxf(worst, v)
		var avg := sum / maxf(1.0, float(frame_ms.size()))
		var n_sprites := all_sprites.size() + (units.size() if shadows_on else 0)
		info.text = "%.0f FPS · %.1f ms (peor %.1f ms) · %d sprites\n%s%s" % [1000.0 / maxf(avg, 0.001), avg, worst, n_sprites, sel_msg, "" if sel_msg == "" else "\n"] + _config_text()
