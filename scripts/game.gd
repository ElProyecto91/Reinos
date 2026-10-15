class_name Game
extends Node2D
## Pantalla de juego: bucle de simulación, cámara, entrada táctil, selección y órdenes.

signal exit_requested
signal load_failed
signal sel_changed

const T := Defs.TILE
const ZOOM_MAX := 2.2
const MOVE_THRESHOLD := 16.0
const LONG_PRESS := 0.45
const AUTOSAVE_SEC := 90.0   # guardado periódico (tiempo real, sólo con la partida en marcha)

var cfg: Dictionary = {}
var sim: Sim
var art: Art
var fog: Fog
var hud: Hud
var audio: AudioMgr
var human: int = 0
var terrain_mat: ShaderMaterial
var farm_tiles: Dictionary = {}
var res_layer: TileMapLayer
var l_terrain: WorldLayer
var l_ents: WorldLayer
var l_fog: WorldLayer

# estado de carga: 0 nada, 1 generando (hilo), 2 preparando, 3 listo, -1 error
var load_state: int = 0
var _thread: Thread
var _gen_ok := false
var _gen_tries := 0
var loading_save := false     # true = se está cargando la partida guardada en vez de generar un mundo
var loaded: Dictionary = {}   # datos leídos del archivo (se liberan al terminar la carga)
var last_save_ok := false
var _autosave_t := AUTOSAVE_SEC

# bucle
var _acc := 0.0
var interp := 0.0
var _last_xf := Transform2D(Vector2(0, 0), Vector2(0, 0), Vector2(-1, -1))   # última transformación de cámara escrita
var _tm := 0.0              # reloj de animación de los shaders (agua, nubes, lluvia); se para en pausa
var _calm := false           # sin tocar la pantalla desde hace CALM_AFTER s: fps «tranquilos» del perfil
var speed := 1.0
var paused := false
var _fog_t := 0.0
var _ui_t := 0.0
var _end_timer := -1.0
var _end_shown := false
var _run_mode := -1          # -1 sin definir, 0 reposo (pausa/fin), 1 en marcha (batería, ver Settings)
var _last_input_ms := 0
var _cam_sig := Vector3.ZERO
var _dirty := 2
var anim_t := 0.0             # reloj de animación (se detiene en pausa)
var night := 0.0              # 0 día .. 1 noche cerrada (ver atmósfera)
var rain := 0.0               # 0 despejado .. 1 lluvia
var overcast := 0.0
var l_sky: WorldLayer
var canvas_mod: CanvasModulate
var _sky_mat: ShaderMaterial
var _rain_rect: ColorRect
var _rain_layer: CanvasLayer
var _wx: FastNoiseLite
var _atmo_t := 0.0

# cámara
var cam_pos := Vector2.ZERO
var zoom := 1.0
var _vs := Vector2(1280, 720)

# selección y modos
var sel: Array[int] = []
var sel_set: Dictionary = {}
var placing_type := ""
var place_tile := Vector2i(-1, -1)
var wall_tiles: Array[Vector2i] = []   # tramo de muralla que se está trazando
var wall_anchor := Vector2i(-1, -1)
var wall_state := 0                     # 0 nada, 1 primer punto fijado, 2 tramo trazado
var rally_mode := false
var amove_mode := false
var select_mode := false
var box_active := false
var box_start := Vector2.ZERO
var box_end := Vector2.ZERO

# efectos
var fx: Array = []
var markers: Array = []
var alarm_pos := Vector2(-1, -1)
var alarm_time := -100.0
var _alarm_toast := -100.0

# entrada táctil
var _touches: Dictionary = {}
var _pinch_d := 0.0
var _pinch_mid := Vector2.ZERO
var _gesture_multi := false
var _last_tap_t := -10.0
var _last_tap_pos := Vector2.ZERO
var _idle_cycle := 0

# ------------------------------------------------------------------ carga

func start(c: Dictionary) -> void:
	cfg = c
	_last_input_ms = Time.get_ticks_msec()
	hud = Hud.new()
	hud.game = self
	add_child(hud)
	audio = AudioMgr.new()
	audio.game = self
	add_child(audio)
	_begin_generation()

## Carga la partida guardada (la lectura y la reconstrucción van en el hilo de carga).
func start_load() -> void:
	loading_save = true
	start({})

func _begin_generation() -> void:
	sim = Sim.new()
	load_state = 1
	hud.set_loading(Lang.t("loading_save") if loading_save else Lang.t("loading_world"))
	_thread = Thread.new()
	_thread.start(_gen_thread)

func _gen_thread() -> void:
	if loading_save:
		loaded = SaveGame.read_data()
		var s: Sim = SaveGame.restore(loaded) if not loaded.is_empty() else null
		_gen_ok = s != null
		if s != null:
			sim = s
			cfg = (loaded["cfg"] as Dictionary).duplicate(true)
		return
	_gen_ok = sim.setup(cfg)

func _poll_thread() -> void:
	if _thread == null or _thread.is_alive():
		return
	_thread.wait_to_finish()
	_thread = null
	if _gen_ok:
		_prepare()
	elif loading_save:
		push_warning("No se pudo cargar la partida: " + SaveGame.last_error)
		load_failed.emit()
	else:
		_gen_tries += 1
		if _gen_tries < 6:
			cfg["seed"] = int(cfg["seed"]) + 101
			_begin_generation()
		else:
			load_state = -1
			hud.set_loading(Lang.t("loading_failed"))

func _prepare() -> void:
	load_state = 2
	hud.set_loading(Lang.t("loading_art"))
	await get_tree().process_frame
	art = Art.new()
	art.build()
	await get_tree().process_frame
	hud.set_loading(Lang.t("loading_terrain"))
	await get_tree().process_frame
	terrain_mat = TerrainFx.make_material(sim)
	await get_tree().process_frame
	human = sim.human_index
	l_terrain = _make_layer(0)
	l_terrain.material = terrain_mat
	_build_tilemap()
	l_ents = _make_layer(1)
	l_ents.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	res_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_build_atmosphere()
	l_fog = _make_layer(2)
	fog = Fog.new(sim.W, sim.H)
	farm_tiles.clear()
	var st: Vector2i = sim.players[human].start_tile
	cam_pos = sim.tile_center(st)
	zoom = 1.0
	if loading_save:
		var gd: Dictionary = loaded.get("game", {})
		if gd.get("cam") is Vector2:
			cam_pos = gd["cam"]
		zoom = clampf(float(gd.get("zoom", 1.0)), 0.25, ZOOM_MAX)
		speed = clampf(float(gd.get("speed", 1.0)), 1.0, 3.0)
		anim_t = float(gd.get("anim_t", 0.0))
		SaveGame.restore_fog(gd, fog)
		loaded = {}
	fog.update(sim, human)
	l_terrain.queue_redraw()
	l_fog.queue_redraw()
	audio.start()
	load_state = 3
	hud.finish_loading()
	_apply_camera()
	if loading_save:
		hud.toast(Lang.t("toast_loaded"), Color(1, 1, 1))
		hud.show_pause()    # la partida cargada empieza en pausa: tiempo para orientarse
	else:
		hud.toast(Lang.t("toast_start"), Color(1, 1, 1))

func _build_atmosphere() -> void:
	l_sky = _make_layer(3)
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://shaders/clouds.gdshader")
	_sky_mat.set_shader_parameter("nz1", terrain_mat.get_shader_parameter("nz1"))
	_sky_mat.set_shader_parameter("tile_px", float(T))
	l_sky.material = _sky_mat
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)
	_rain_layer = CanvasLayer.new()
	_rain_layer.layer = 5            # por encima del mundo y por debajo de la interfaz (10)
	add_child(_rain_layer)
	_rain_rect = ColorRect.new()
	_rain_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/rain.gdshader")
	_rain_rect.material = rm
	_rain_rect.visible = false
	_rain_layer.add_child(_rain_rect)
	_wx = FastNoiseLite.new()
	_wx.seed = sim.seed_used + 5
	_wx.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_wx.frequency = 1.0
	_atmosphere()

const DAY_LEN := 540.0     # segundos de partida por día completo
const TOD_KEYS := [0.0, 0.20, 0.27, 0.35, 0.50, 0.65, 0.73, 0.80, 0.88, 1.0]
const TOD_COLS := [Color(0.50, 0.56, 0.80), Color(0.52, 0.58, 0.82), Color(0.96, 0.76, 0.64), Color(1.0, 0.97, 0.90), Color(1, 1, 1),
		Color(1.0, 0.98, 0.92), Color(1.0, 0.72, 0.55), Color(0.70, 0.66, 0.86), Color(0.50, 0.56, 0.80), Color(0.50, 0.56, 0.80)]
const TOD_NIGHT := [1.0, 0.95, 0.35, 0.0, 0.0, 0.0, 0.25, 0.75, 1.0, 1.0]

## Ciclo día/noche (tinte global), cielo cubierto, sombras de nubes y lluvia. 4 veces por segundo.
func _atmosphere() -> void:
	var tod := fposmod(0.30 + sim.time / DAY_LEN, 1.0)
	var k := 0
	while k < TOD_KEYS.size() - 2 and tod > float(TOD_KEYS[k + 1]):
		k += 1
	var f := clampf((tod - float(TOD_KEYS[k])) / (float(TOD_KEYS[k + 1]) - float(TOD_KEYS[k])), 0.0, 1.0)
	var col: Color = (TOD_COLS[k] as Color).lerp(TOD_COLS[k + 1], f)
	night = lerpf(float(TOD_NIGHT[k]), float(TOD_NIGHT[k + 1]), f)
	# clima: ruido lento; los primeros minutos siempre despejados
	var v := _wx.get_noise_1d(sim.time / 140.0)
	var warm := smoothstep(60.0, 200.0, sim.time)
	rain = smoothstep(0.28, 0.50, v) * warm
	overcast = maxf(smoothstep(0.0, 0.35, v), rain) * warm
	col = col.lerp(Color(0.72, 0.76, 0.84), overcast * 0.40)
	var dim := 1.0 - 0.12 * rain
	canvas_mod.color = Color(col.r * dim, col.g * dim, col.b * dim, 1.0)
	_sky_mat.set_shader_parameter("cover", overcast)
	terrain_mat.set_shader_parameter("full", 0.0 if Settings.profile == 0 else 1.0)
	_rain_rect.visible = rain > 0.03
	if _rain_rect.visible:
		(_rain_rect.material as ShaderMaterial).set_shader_parameter("amount", rain)

func _make_layer(mode: int) -> WorldLayer:
	var l := WorldLayer.new()
	l.game = self
	l.mode = mode
	add_child(l)
	return l

func _build_tilemap() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = art.res_atlas
	src.texture_region_size = Vector2i(Art.RES_CELL, Art.RES_CELL)
	for i in Art.ATLAS_N:
		src.create_tile(Vector2i(i, 0))
	ts.add_source(src, 0)
	res_layer = TileMapLayer.new()
	res_layer.tile_set = ts
	add_child(res_layer)
	var W := sim.W
	for idx in W * sim.H:
		var rt := sim.rtype[idx]
		if rt == 0:
			continue
		var x := idx % W
		var y := idx / W
		var ai := _atlas_index(rt, x, y)
		if ai >= 0:
			res_layer.set_cell(Vector2i(x, y), 0, Vector2i(ai, 0))
		elif rt == Defs.R_FARM:
			farm_tiles[idx] = true

func _atlas_index(rt: int, x: int, y: int) -> int:
	var h := ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff
	match rt:
		Defs.R_TREE:
			# especie según el clima de la casilla
			var heat := float(sim.heat[y * sim.W + x]) / 255.0
			var k := (h >> 4) % 100
			if heat < 0.28:
				return Art.TREE_SNOW if k < 72 else Art.TREE_PINE_B
			elif heat < 0.42:
				return Art.TREE_PINE if k < 34 else (Art.TREE_PINE_B if k < 58 else (Art.TREE_OAK_A if k < 82 else Art.TREE_OAK_B))
			elif heat < 0.66:
				return Art.TREE_OAK_A if k < 40 else (Art.TREE_OAK_B if k < 72 else (Art.TREE_PINE if k < 85 else (Art.TREE_PINE_B if k < 95 else Art.TREE_AUTUMN)))
			return Art.TREE_PALM if k < 52 else (Art.TREE_DRY if k < 88 else Art.TREE_OAK_B)
		Defs.R_GOLD:
			return Art.RES_GOLD
		Defs.R_BERRY:
			return Art.RES_BERRY
		Defs.R_FISH:
			return Art.RES_FISH0 + (h % 2)
	return -1

func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	SaveGame.wait_idle()
	if is_inside_tree():
		get_viewport().canvas_transform = Transform2D.IDENTITY

# ------------------------------------------------------------------ bucle

func _process(delta: float) -> void:
	_update_run_mode()
	if load_state == 1:
		_poll_thread()
		return
	if load_state != 3:
		return
	_vs = get_viewport().get_visible_rect().size
	_keys(delta)
	_long_press_check()
	if not paused:
		anim_t += delta
		_atmo_t -= delta
		if _atmo_t <= 0.0:
			_atmo_t = 0.25
			_atmosphere()
		_step_sim(delta)
		_check_idle()
		var calm := (Time.get_ticks_msec() - _last_input_ms) > int(Settings.CALM_AFTER * 1000.0)
		if calm != _calm:
			_calm = calm
			Settings.set_calm(calm)
		_autosave_t -= delta
		if _autosave_t <= 0.0:
			_autosave_t = AUTOSAVE_SEC
			SaveGame.save(self, false)
	_update_fx(delta)
	var still := paused or (sim.game_over and _end_shown)
	if not still:
		_fog_t -= delta
		if _fog_t <= 0.0:
			_fog_t = float(Settings.v("fog"))
			fog.update(sim, human)
			l_fog.queue_redraw()
	_ui_t -= delta
	if _ui_t <= 0.0:
		_ui_t = 0.2
		_prune_selection()
	if not still:
		_tick_shader_time(delta)
	_apply_camera()
	# Batería: en pausa o con la partida terminada solo se redibuja si algo ha cambiado.
	var sig := Vector3(cam_pos.x, cam_pos.y, zoom)
	var moved := sig != _cam_sig
	_cam_sig = sig
	if (not still) or moved or _dirty > 0 or not fx.is_empty() or not markers.is_empty():
		l_ents.queue_redraw()
	_dirty = maxi(_dirty - 1, 0)
	if _end_timer >= 0.0:
		_end_timer -= delta
		if _end_timer < 0.0 and not _end_shown:
			_end_shown = true
			hud.show_end()

## Los shaders del mundo no usan TIME sino este reloj propio: con TIME el motor redibuja la pantalla entera en cada
## fotograma aunque no cambie nada (también en pausa y con la partida terminada), y eso gasta batería a cambio de nada.
func _tick_shader_time(delta: float) -> void:
	_tm += delta
	terrain_mat.set_shader_parameter("tm", _tm)
	_sky_mat.set_shader_parameter("tm", _tm)
	if _rain_rect.visible:
		(_rain_rect.material as ShaderMaterial).set_shader_parameter("tm", _tm)

## Ajusta el motor según el estado: en marcha = fps del perfil y pantalla encendida;
## en reposo (pausa, fin de partida) = pocos fps, pantalla libre para apagarse y ambiente en silencio.
func _update_run_mode() -> void:
	var want := 1
	if load_state == 3 and (paused or sim.game_over):
		want = 0
	if want == _run_mode:
		return
	_run_mode = want
	Settings.set_playing(want == 1)
	if audio != null:
		audio.set_quiet(want == 0)
	if want == 1:
		_last_input_ms = Time.get_ticks_msec()
		_calm = false
		_dirty = 2

func reset_run_mode() -> void:
	_run_mode = -1

func _check_idle() -> void:
	var lim := float(Settings.v("idle"))
	if not Settings.auto_pause or lim <= 0.0 or sim.game_over or hud.blocking():
		return
	if (Time.get_ticks_msec() - _last_input_ms) / 1000.0 > lim:
		hud.show_pause(true)

func _step_sim(delta: float) -> void:
	if sim.game_over:
		interp = 1.0
		_consume_events()
		return
	_acc += minf(delta, 0.2) * speed
	var t0 := Time.get_ticks_usec()
	var n := 0
	while _acc >= Sim.DT:
		sim.step()
		_acc -= Sim.DT
		n += 1
		if Time.get_ticks_usec() - t0 > 14000:
			break
	if _acc > 0.5:
		_acc = 0.0
	interp = clampf(_acc / Sim.DT, 0.0, 1.0)
	_consume_events()

func _keys(delta: float) -> void:
	var d := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1
	if d != Vector2.ZERO:
		cam_pos += d.normalized() * 900.0 * delta / zoom

func _notification(what: int) -> void:
	if load_state != 3:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if not paused and not sim.game_over:
			hud.show_pause()     # pausa y guarda
		else:
			save_now()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		hud.back_pressed()

# ------------------------------------------------------------------ cámara

func zoom_min() -> float:
	return maxf(0.25, _vs.x / (sim.W * T * 1.05))

func _apply_camera() -> void:
	zoom = clampf(zoom, zoom_min(), ZOOM_MAX)
	var maxp := Vector2(sim.W, sim.H) * T
	var half := _vs * 0.5 / zoom
	for ax in 2:
		var lo := half[ax]
		var hi := maxp[ax] - half[ax]
		if lo > hi:
			cam_pos[ax] = maxp[ax] * 0.5
		else:
			cam_pos[ax] = clampf(cam_pos[ax], lo, hi)
	# Sólo se escribe si cambia: cada escritura al servidor de dibujo cuenta como «hay cambios» y, con el modo de
	# bajo consumo del motor, obliga a dibujar el fotograma entero aunque no se mueva nada (pausa, fin de partida).
	var xf := Transform2D(Vector2(zoom, 0), Vector2(0, zoom), _vs * 0.5 - cam_pos * zoom)
	if xf != _last_xf:
		_last_xf = xf
		get_viewport().canvas_transform = xf

func screen_to_world(p: Vector2) -> Vector2:
	return (p - _vs * 0.5) / zoom + cam_pos

func world_to_screen(p: Vector2) -> Vector2:
	return (p - cam_pos) * zoom + _vs * 0.5

func view_rect(margin: float = 0.0) -> Rect2:
	var half := _vs * 0.5 / zoom
	return Rect2(cam_pos - half, half * 2.0).grow(margin)

func focus_on(wp: Vector2) -> void:
	cam_pos = wp

func zoom_at(screen_pos: Vector2, factor: float) -> void:
	var before := screen_to_world(screen_pos)
	zoom = clampf(zoom * factor, zoom_min(), ZOOM_MAX)
	var after := screen_to_world(screen_pos)
	cam_pos += before - after

# ------------------------------------------------------------------ visibilidad

func can_see_unit(u: Ent) -> bool:
	return u.owner == human or fog.visible_at(sim.tile_of(u.pos))

func can_see_building(b: Ent) -> bool:
	if b.owner == human:
		return true
	return fog.explored_at(b.tile + Vector2i(b.size / 2, b.size / 2))

# ------------------------------------------------------------------ eventos de la simulación

func _seen(p: Vector2) -> bool:
	return fog.visible_at(sim.tile_of(p))

func _fx(d: Dictionary) -> void:
	if fx.size() < 260:
		d["a"] = 0.0
		fx.append(d)

func _consume_events() -> void:
	if sim.events.is_empty():
		return
	for ev: Dictionary in sim.events:
		match ev["t"]:
			"arrow":
				if _seen(ev["from"]) or _seen(ev["to"]):
					_fx({"t": "arrow", "p": ev["from"], "q": ev["to"], "life": 0.28})
					sfx("arrow", ev["from"])
			"hit":
				if _seen(ev["pos"]):
					_fx({"t": "hit", "p": ev["pos"], "life": 0.3})
					sfx("hit", ev["pos"])
			"death":
				var p: Vector2 = ev["pos"]
				if _seen(p) or ev["owner"] == human:
					var big: bool = ev["building"]
					for i in (5 if big else 1):
						var off := Vector2(randf_range(-20, 20), randf_range(-14, 14)) if big else Vector2.ZERO
						_fx({"t": "puff", "p": p + off, "r": 26.0 if big else 12.0, "life": 0.9 if big else 0.6})
					sfx("crash" if big else "death", p)
			"built":
				if ev["owner"] == human:
					sfx("built", ev["pos"])
					if ev["type"] != "muralla":
						var fem: bool = str(ev["type"]) in ["casa", "arqueria", "torre", "granja", "puerta", "muralla"]
						hud.toast(Lang.t("toast_built_f" if fem else "toast_built", [Lang.t("b_" + str(ev["type"]))]), Color(0.7, 1, 0.7))
			"deposit":
				if ev["owner"] == human:
					var dp: Vector2 = ev["pos"]
					var dk: String = ev["kind"]
					var dcol := Color(0.95, 0.72, 0.42) if dk == "wood" else (Color(1.0, 0.86, 0.25) if dk == "gold" else Color(1.0, 0.45, 0.4))
					_fx({"t": "text", "p": dp + Vector2(randf_range(-10, 10), -26), "s": "+%d" % int(ev["n"]), "col": dcol, "life": 1.2})
					sfx("deposit", dp)
			"cannon":
				if _seen(ev["from"]) or _seen(ev["to"]):
					var cf: Vector2 = ev["from"]
					var ct: Vector2 = ev["to"]
					_fx({"t": "cannon", "p": cf + (ct - cf).normalized() * 12.0 + Vector2(0, -10), "q": ct, "life": 0.55})
					sfx("cannon", cf)
			"boarded":
				if ev["owner"] == human:
					sfx("splash", ev["pos"])
			"unloaded":
				if ev["owner"] == human:
					sfx("splash", ev["pos"])
					hud.toast(Lang.t("toast_unloaded", [int(ev["n"])]), Color(0.7, 1, 0.7))
			"explore_done":
				if ev["owner"] == human:
					hud.toast(Lang.t("toast_explore_done"), Color(0.7, 0.9, 1.0))
			"wall_gap":
				if ev["owner"] == human:
					hud.toast(Lang.t("toast_wall_gap"), Color(1, 0.8, 0.45))
			"placed":
				if ev.has("farm"):
					var t: Vector2i = ev["farm"]
					farm_tiles[t.y * sim.W + t.x] = true
				if ev["owner"] == human:
					sfx("place", ev["pos"])
			"trained":
				if ev["owner"] == human:
					sfx("trained", ev["pos"])
					_fx({"t": "flash", "p": ev["pos"], "life": 0.5})
			"alarm":
				if ev["owner"] == human:
					alarm_pos = ev["pos"]
					alarm_time = sim.time
					if sim.time - _alarm_toast > 12.0:
						_alarm_toast = sim.time
						hud.toast(Lang.t("toast_alarm"), Color(1, 0.55, 0.45))
						sfx("alarm")
			"age":
				var who: Player = sim.players[ev["owner"]]
				if who.is_human:
					hud.toast(Lang.t("toast_age_you", [Lang.t("age_%d" % int(ev["age"]))]), Color(1, 0.9, 0.5))
					sfx("age")
				else:
					hud.toast(Lang.t("toast_age_other", [who.name, Lang.t("age_%d" % int(ev["age"]))]), Color(1, 0.9, 0.7))
			"depleted":
				var t: Vector2i = ev["tile"]
				var rt: int = ev["rt"]
				if rt == Defs.R_FARM:
					farm_tiles.erase(t.y * sim.W + t.x)
				else:
					res_layer.erase_cell(t)
					if rt == Defs.R_TREE and _seen(sim.tile_center(t)):
						_fx({"t": "puff", "p": sim.tile_center(t), "r": 10.0, "life": 0.5})
			"eliminated":
				var who2: Player = sim.players[ev["owner"]]
				if not who2.is_human:
					hud.toast(Lang.t("toast_eliminated", [who2.name]), Color(1, 0.8, 0.5))
			"gameover":
				_end_timer = 2.0
				paused = false
				SaveGame.delete()
	sim.events.clear()

func _update_fx(delta: float) -> void:
	var i := 0
	while i < fx.size():
		var f: Dictionary = fx[i]
		f["a"] = float(f["a"]) + delta
		if float(f["a"]) >= float(f["life"]):
			fx.remove_at(i)
		else:
			i += 1
	i = 0
	while i < markers.size():
		var m: Dictionary = markers[i]
		m["a"] = float(m["a"]) + delta
		if float(m["a"]) >= float(m["life"]):
			markers.remove_at(i)
		else:
			i += 1

func add_marker(p: Vector2, col: Color) -> void:
	markers.append({"p": p, "col": col, "a": 0.0, "life": 0.7})

func sfx(name: String, pos: Vector2 = Vector2(-1e9, -1e9)) -> void:
	if audio != null:
		audio.play(name, pos)

# ------------------------------------------------------------------ selección

func clear_selection() -> void:
	sel.clear()
	sel_set.clear()
	rally_mode = false
	amove_mode = false
	sel_changed.emit()

func select_ents(list: Array) -> void:
	sel.clear()
	sel_set.clear()
	for e: Ent in list:
		sel.append(e.id)
		sel_set[e.id] = true
	rally_mode = false
	amove_mode = false
	sel_changed.emit()

func sel_ents() -> Array[Ent]:
	var out: Array[Ent] = []
	for id in sel:
		var e := sim.get_ent(id)
		if e != null:
			out.append(e)
	return out

func sel_own_units() -> Array[Ent]:
	var out: Array[Ent] = []
	for id in sel:
		var e := sim.get_ent(id)
		if e != null and not e.is_building and e.owner == human:
			out.append(e)
	return out

func _ids_of(list: Array[Ent], only_type: String = "", military: bool = false) -> Array:
	var ids: Array = []
	for e in list:
		if only_type != "" and e.type != only_type:
			continue
		if military and not e.is_military():
			continue
		ids.append(e.id)
	return ids

func sel_building() -> Ent:
	if sel.size() == 1:
		var e := sim.get_ent(sel[0])
		if e != null and e.is_building:
			return e
	return null

func _prune_selection() -> void:
	var changed := false
	var i := 0
	while i < sel.size():
		if sim.get_ent(sel[i]) == null:
			sel_set.erase(sel[i])
			sel.remove_at(i)
			changed = true
		else:
			i += 1
	if changed:
		if sel.is_empty():
			rally_mode = false
			amove_mode = false
		sel_changed.emit()

func pick_at(wp: Vector2) -> Ent:
	var best: Ent = null
	var bd := 1e9
	var probe := wp + Vector2(0, 10.0)
	for u in sim.query(wp, 50.0):
		if u.is_building or not can_see_unit(u):
			continue
		if u.naval:
			# un barco es largo: se acierta sobre el casco o los mástiles, no sólo junto al centro
			var top := Renderer.unit_top(u)
			var dxn := absf(wp.x - u.pos.x)
			var dyn := absf(wp.y - (u.pos.y - top * 0.4))
			if dxn < float(Renderer.SHIP_HALF[u.type]) + 6.0 and dyn < top * 0.5 + 8.0:
				var dn := Vector2(dxn * 0.6, dyn).length()
				if dn < bd:
					bd = dn
					best = u
			continue
		var d := probe.distance_to(u.pos)
		if d < u.radius + 14.0 and d < bd:
			bd = d
			best = u
	if best != null:
		return best
	for b in sim.buildings:
		if b.alive and b.rect().grow(4.0).has_point(wp) and can_see_building(b):
			return b
	return null

func select_in_box(a: Vector2, b: Vector2) -> void:
	var r := Rect2(a, b - a).abs()
	var list: Array = []
	for u in sim.units:
		if u.alive and u.owner == human and r.has_point(u.pos):
			list.append(u)
	if list.is_empty():
		clear_selection()
		return
	if list.size() > 80:
		list.resize(80)
	select_ents(list)
	sfx("click")

func select_same_type_on_screen(e: Ent) -> void:
	var vr := view_rect(0.0)
	var list: Array = []
	for u in sim.units:
		if u.alive and u.owner == human and u.type == e.type and vr.has_point(u.pos):
			list.append(u)
	if list.is_empty():
		list.append(e)
	select_ents(list)

# ------------------------------------------------------------------ entrada

func _input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseMotion) or (ev as InputEventMouseMotion).button_mask != 0:
		_last_input_ms = Time.get_ticks_msec()
		_dirty = 2
	if load_state != 3 or paused or hud == null or hud.blocking():
		return
	if ev is InputEventScreenTouch:
		_on_touch(ev)
	elif ev is InputEventScreenDrag:
		_on_drag(ev)
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and not hud.is_over_ui(mb.position):
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_at(mb.position, 1.12)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_at(mb.position, 1.0 / 1.12)
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				_right_click(mb.position)
	elif ev is InputEventKey:
		var k := ev as InputEventKey
		if k.pressed and not k.echo:
			match k.keycode:
				KEY_ESCAPE:
					hud.back_pressed()
				KEY_SPACE:
					ui_goto_base()
				KEY_DELETE:
					ui_delete()

func _live_touches() -> Array:
	var out: Array = []
	for k in _touches:
		if not _touches[k]["ui"]:
			out.append(k)
	return out

func _on_touch(ev: InputEventScreenTouch) -> void:
	var idx := ev.index
	if ev.pressed:
		if hud.is_over_ui(ev.position):
			_touches[idx] = {"ui": true}
			return
		_touches[idx] = {"ui": false, "start": ev.position, "pos": ev.position, "t": Time.get_ticks_msec() / 1000.0, "moved": false}
		var live := _live_touches()
		if live.size() >= 2:
			_gesture_multi = true
			box_active = false
			_pinch_reset(live)
		else:
			_gesture_multi = false
	else:
		var t: Dictionary = _touches.get(idx, {})
		_touches.erase(idx)
		if t.is_empty() or t["ui"]:
			return
		if _gesture_multi:
			if _live_touches().is_empty():
				_gesture_multi = false
			return
		if box_active:
			box_active = false
			var a := screen_to_world(box_start)
			var b := screen_to_world(box_end)
			if (b - a).length() * zoom > 14.0:
				select_in_box(a, b)
				select_mode = false
				hud.refresh_now()
				return
		if not t["moved"]:
			_tap(ev.position)

func _pinch_reset(live: Array) -> void:
	var a: Vector2 = _touches[live[0]]["pos"]
	var b: Vector2 = _touches[live[1]]["pos"]
	_pinch_d = maxf(a.distance_to(b), 1.0)
	_pinch_mid = (a + b) * 0.5

func _on_drag(ev: InputEventScreenDrag) -> void:
	var idx := ev.index
	if not _touches.has(idx):
		return
	var t: Dictionary = _touches[idx]
	if t["ui"]:
		return
	t["pos"] = ev.position
	var live := _live_touches()
	if live.size() >= 2:
		var a: Vector2 = _touches[live[0]]["pos"]
		var b: Vector2 = _touches[live[1]]["pos"]
		var d := maxf(a.distance_to(b), 1.0)
		var mid := (a + b) * 0.5
		cam_pos -= (mid - _pinch_mid) / zoom
		zoom_at(mid, d / _pinch_d)
		_pinch_d = d
		_pinch_mid = mid
		return
	if not t["moved"] and ev.position.distance_to(t["start"]) > MOVE_THRESHOLD:
		t["moved"] = true
		if select_mode and placing_type == "":
			box_active = true
			box_start = t["start"]
	if not t["moved"]:
		return
	if box_active:
		box_end = ev.position
	elif placing_type == "muralla":
		var a := _ghost_from_world(screen_to_world(Vector2(t["start"]) + Vector2(0, -56)))
		var b := _ghost_from_world(screen_to_world(ev.position + Vector2(0, -56)))
		wall_anchor = a
		place_tile = b
		wall_tiles = _line_tiles(a, b)
		wall_state = 2 if wall_tiles.size() > 1 else 1
	elif placing_type != "":
		place_tile = _ghost_from_world(screen_to_world(ev.position + Vector2(0, -56)))
	else:
		cam_pos -= ev.relative / zoom

func _long_press_check() -> void:
	if box_active or placing_type != "" or _gesture_multi:
		return
	var live := _live_touches()
	if live.size() != 1:
		return
	var t: Dictionary = _touches[live[0]]
	if t["moved"]:
		return
	if Time.get_ticks_msec() / 1000.0 - float(t["t"]) > LONG_PRESS:
		box_active = true
		box_start = t["start"]
		box_end = t["pos"]
		t["moved"] = true
		Input.vibrate_handheld(25)

func _right_click(sp: Vector2) -> void:
	var wp := screen_to_world(sp)
	_order_at(wp, true)

# ------------------------------------------------------------------ toques

func _tap(sp: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var dbl := now - _last_tap_t < 0.35 and sp.distance_to(_last_tap_pos) < 40.0
	_last_tap_t = now
	_last_tap_pos = sp
	var wp := screen_to_world(sp)
	if placing_type != "":
		place_tile = _ghost_from_world(wp)
		if placing_type == "granja":
			ui_confirm_place()
		elif placing_type == "muralla":
			# primer toque: inicio; segundo toque: final del tramo; tercero: empieza otro
			if wall_state == 1:
				wall_tiles = _line_tiles(wall_anchor, place_tile)
				wall_state = 2
			else:
				wall_anchor = place_tile
				wall_tiles = [place_tile]
				wall_state = 1
		return
	if rally_mode:
		var b := sel_building()
		if b != null:
			# si se toca junto a un árbol, mina o granja, el punto de reunión se pega al recurso
			# (los aldeanos nuevos irán a recolectarlo solos)
			var rtile := _res_at(wp)
			if rtile.x < 0 and b.def.get("dock", false):
				rtile = _fish_at(wp)
			var rl := rtile if rtile.x >= 0 else sim.tile_of(wp)
			sim.cmd_set_rally(human, b.id, rl)
			add_marker(sim.tile_center(rl), Color(0.5, 1, 0.5) if rtile.x >= 0 else Color(1, 1, 1))
			if rtile.x >= 0:
				hud.toast(Lang.t("toast_rally_res", [_res_name(rtile)]), Color(0.7, 1, 0.7))
			sfx("order")
		rally_mode = false
		sel_changed.emit()
		return
	if amove_mode:
		var us := sel_own_units()
		if not us.is_empty():
			sim.cmd_move(human, _ids_of(us), sim.tile_of(wp), true)
			add_marker(sim.tile_center(sim.tile_of(wp)), Color(1, 0.35, 0.3))
			sfx("order")
		amove_mode = false
		sel_changed.emit()
		return
	var hit := pick_at(wp)
	if hit != null and hit.owner == human:
		var mine := sel_own_units()
		if _try_board(hit, mine):
			return
		if hit.is_building and hit.progress < 1.0 and _count_type(mine, "aldeano") > 0:
			sim.cmd_help_build(human, _ids_of(mine, "aldeano"), hit.id)
			add_marker(hit.center(), Color(0.4, 1, 0.5))
			sfx("order")
			return
		if dbl and not hit.is_building:
			select_same_type_on_screen(hit)
		else:
			select_ents([hit])
		sfx("click")
		return
	_order_at(wp, false, hit)

func _count_type(list: Array[Ent], t: String) -> int:
	var n := 0
	for e in list:
		if e.type == t:
			n += 1
	return n

func _any_naval(list: Array[Ent]) -> bool:
	for e in list:
		if e.naval:
			return true
	return false

func _fisher_ids(list: Array[Ent]) -> Array:
	var out: Array = []
	for e in list:
		if e.def.get("fisher", false):
			out.append(e.id)
	return out

func _cargo_ship_ids(list: Array[Ent]) -> Array:
	var out: Array = []
	for e in list:
		if e.naval and not e.cargo.is_empty():
			out.append(e.id)
	return out

## Si `hit` es un transporte propio y hay soldados/aldeanos de tierra seleccionados, ordena embarcar.
func _try_board(hit: Ent, mine: Array[Ent]) -> bool:
	if hit.is_building or not hit.naval or int(hit.def.get("cargo", 0)) <= 0:
		return false
	var land: Array = []
	for e in mine:
		if not e.naval:
			land.append(e.id)
	if land.is_empty():
		return false
	var r := sim.cmd_board(human, land, hit.id)
	if r != Sim.OK:
		_err(r)
		return true
	add_marker(hit.pos, Color(0.4, 0.8, 1.0))
	hud.toast(Lang.t("toast_board_go", [land.size()]), Color(0.7, 0.9, 1.0))
	sfx("order")
	return true

## Casilla con peces cerca del punto tocado (sólo la usan los barcos de pesca).
func _fish_at(wp: Vector2) -> Vector2i:
	var t := sim.tile_of(wp)
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := t + Vector2i(dx, dy)
			if not sim.in_bounds(q) or not fog.explored_at(q):
				continue
			if sim.rtype[q.y * sim.W + q.x] != Defs.R_FISH:
				continue
			var d := wp.distance_to(sim.tile_center(q))
			if d < 34.0 and d < bd:
				bd = d
				best = q
	return best

func _order_at(wp: Vector2, right_click: bool, hit: Ent = null) -> void:
	## Orden contextual con la selección actual sobre un punto del mundo.
	if hit == null:
		hit = pick_at(wp)
	var mine := sel_own_units()
	if hit != null and sim.is_hostile(human, hit.owner):
		var attackers: Array = _ids_of(mine, "", true)
		if attackers.is_empty() and not hit.is_building:
			attackers = _ids_of(mine)
		if not attackers.is_empty():
			if sim.cmd_attack(human, attackers, hit.id) == 0:
				_err(Sim.ERR_CANT)
				return
			add_marker(hit.center(), Color(1, 0.3, 0.25))
			sfx("order")
			return
		select_ents([hit])
		return
	if hit != null:
		if _try_board(hit, mine):
			return
		select_ents([hit])
		return
	var tile := sim.tile_of(wp)
	if not mine.is_empty():
		var fishers := _fisher_ids(mine)
		if not fishers.is_empty():
			var ft := _fish_at(wp)
			if ft.x >= 0:
				sim.cmd_gather(human, fishers, ft)
				add_marker(sim.tile_center(ft), Color(0.5, 1, 0.5))
				hud.toast(Lang.t("toast_gather", [_res_name(ft)]), Color(0.7, 1, 0.7))
				sfx("order")
				return
		if sim.terrain[tile.y * sim.W + tile.x] != Defs.T_WATER:
			var carriers := _cargo_ship_ids(mine)
			if not carriers.is_empty():
				var ur := sim.cmd_unload(human, carriers, tile)
				if ur != Sim.OK:
					_err(ur)
					return
				add_marker(sim.tile_center(tile), Color(0.4, 0.8, 1.0))
				hud.toast(Lang.t("toast_unload_go"), Color(0.7, 0.9, 1.0))
				sfx("order")
				var rest: Array[Ent] = []
				for e in mine:
					if not carriers.has(e.id):
						rest.append(e)
				if not rest.is_empty():
					sim.cmd_move(human, _ids_of(rest), tile, false)
				return
		var rt := _res_at(wp)
		if rt.x >= 0 and _count_type(mine, "aldeano") > 0:
			sim.cmd_gather(human, _ids_of(mine, "aldeano"), rt)
			add_marker(sim.tile_center(rt), Color(0.5, 1, 0.5))
			hud.toast(Lang.t("toast_gather", [_res_name(rt)]), Color(0.7, 1, 0.7))
			sfx("order")
			return
		if not fog.explored_at(tile) and sim.terrain[tile.y * sim.W + tile.x] == Defs.T_WATER and not _any_naval(mine):
			return
		sim.cmd_move(human, _ids_of(mine), tile, false)
		add_marker(sim.tile_center(tile), Color(1, 1, 1))
		sfx("order")
	elif not right_click and not sel.is_empty():
		clear_selection()

func _res_name(t: Vector2i) -> String:
	var rt: int = sim.rtype[t.y * sim.W + t.x]
	if rt == 0:
		return ""
	return Lang.t("res_" + String(Defs.RES_INFO[rt]["kind"]))

func _res_at(wp: Vector2) -> Vector2i:
	var t := sim.tile_of(wp)
	var best := Vector2i(-1, -1)
	var bd := 1e9
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var q := t + Vector2i(dx, dy)
			if not sim.in_bounds(q) or not fog.explored_at(q):
				continue
			var idx := q.y * sim.W + q.x
			var rt := sim.rtype[idx]
			if rt == 0 or rt == Defs.R_FISH:
				continue
			if rt == Defs.R_FARM and sim.rowner[idx] != human:
				continue
			var d := wp.distance_to(sim.tile_center(q))
			if d < 30.0 and d < bd:
				bd = d
				best = q
	return best

# ------------------------------------------------------------------ construcción

func _ghost_from_world(wp: Vector2) -> Vector2i:
	var s := 1.0
	if placing_type != "granja":
		s = float(Defs.BUILDINGS[placing_type]["size"])
	return Vector2i(roundi(wp.x / T - s * 0.5), roundi(wp.y / T - s * 0.5))

func err_text(code: int) -> String:
	match code:
		Sim.ERR_PLACE: return Lang.t("err_place")
		Sim.ERR_COST: return Lang.t("err_cost")
		Sim.ERR_AGE: return Lang.t("err_age")
		Sim.ERR_QUEUE: return Lang.t("err_queue")
		Sim.ERR_NOUNITS: return Lang.t("err_nounits")
		Sim.ERR_UNREACHABLE: return Lang.t("err_unreachable")
		Sim.ERR_NOSHORE: return Lang.t("err_noshore")
		Sim.ERR_CANT: return Lang.t("err_cant")
		Sim.ERR_FULL: return Lang.t("err_full")
	return Lang.t("err_invalid")

func _err(code: int) -> void:
	hud.toast(err_text(code), Color(1, 0.6, 0.5))
	sfx("error")

func ui_begin_place(type: String) -> void:
	var vill := _count_type(sel_own_units(), "aldeano")
	if vill == 0:
		_err(Sim.ERR_NOUNITS)
		return
	var p: Player = sim.players[human]
	if type != "granja":
		var d: Dictionary = Defs.BUILDINGS[type]
		if p.age < int(d["age"]):
			_err(Sim.ERR_AGE)
			return
		if not Defs.can_afford(p.res, d["cost"]):
			_err(Sim.ERR_COST)
			return
	elif not Defs.can_afford(p.res, Defs.FARM_COST):
		_err(Sim.ERR_COST)
		return
	placing_type = type
	rally_mode = false
	amove_mode = false
	select_mode = false
	wall_tiles = []
	wall_anchor = Vector2i(-1, -1)
	wall_state = 0
	place_tile = _ghost_from_world(cam_pos + Vector2(0, -40))
	sfx("click")
	sel_changed.emit()

func place_tiles() -> Array[Vector2i]:
	## Casillas que se construirán al confirmar (muralla: el tramo trazado; resto: la casilla del fantasma).
	if placing_type == "muralla" and not wall_tiles.is_empty():
		return wall_tiles
	var one: Array[Vector2i] = [place_tile]
	return one

func _line_tiles(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	## Línea recta en 8 direcciones (horizontal, vertical o diagonal) de a hacia b.
	var out: Array[Vector2i] = []
	var dx := b.x - a.x
	var dy := b.y - a.y
	var adx := absi(dx)
	var ady := absi(dy)
	var step := Vector2i.ZERO
	var n := 0
	if adx >= ady * 2:
		step = Vector2i(signi(dx), 0)
		n = adx
	elif ady >= adx * 2:
		step = Vector2i(0, signi(dy))
		n = ady
	else:
		step = Vector2i(signi(dx), signi(dy))
		n = maxi(adx, ady)
	n = mini(n, Defs.WALL_MAX_LINE - 1)
	for i in range(n + 1):
		out.append(a + step * i)
	return out

func ui_confirm_place() -> void:
	if placing_type == "":
		return
	var us := sel_own_units()
	var r := 0
	if placing_type == "muralla" or placing_type == "puerta":
		r = sim.cmd_build_wall(human, _ids_of(us, "aldeano"), placing_type, place_tiles())
	else:
		r = sim.cmd_build(human, _ids_of(us, "aldeano"), placing_type, place_tile)
	if r > 0:
		if placing_type == "muralla":
			wall_tiles = []
			wall_state = 0
			var p0: Player = sim.players[human]
			if not Defs.can_afford(p0.res, Defs.BUILDINGS["muralla"]["cost"]):
				placing_type = ""
			hud.refresh_now()
			sel_changed.emit()
			return
		if placing_type == "granja":
			var p: Player = sim.players[human]
			if not Defs.can_afford(p.res, Defs.FARM_COST):
				placing_type = ""
		else:
			placing_type = ""
		hud.refresh_now()
		sel_changed.emit()
	else:
		_err(r)

func ui_cancel_place() -> void:
	placing_type = ""
	wall_tiles = []
	wall_state = 0
	sfx("click")
	sel_changed.emit()

# ------------------------------------------------------------------ órdenes desde la interfaz

func ui_train(utype: String) -> void:
	var b := sel_building()
	if b == null or b.owner != human:
		return
	var r := sim.cmd_train(human, b.id, utype)
	if r == Sim.OK:
		sfx("click")
	else:
		_err(r)

func ui_cancel_queue(i: int) -> void:
	var b := sel_building()
	if b != null and b.owner == human:
		sim.cmd_cancel_train(human, b.id, i)
		sfx("click")

func ui_age_up() -> void:
	var r := sim.cmd_age_up(human)
	if r == Sim.OK:
		sfx("click")
		hud.toast(Lang.t("toast_aging"), Color(1, 0.9, 0.5))
	else:
		_err(r)

func ui_unload() -> void:
	var cs := _cargo_ship_ids(sel_own_units())
	if cs.is_empty():
		_err(Sim.ERR_NOUNITS)
		return
	var r := sim.cmd_unload(human, cs, Vector2i(-1, -1))
	if r != Sim.OK:
		_err(r)
		return
	sfx("order")

## Botón «Explorar»: activa la exploración automática de los exploradores/barcos seleccionados (si ya la tenían todos, la quita).
func ui_explore() -> void:
	var ids: Array = []
	var all_on := true
	for u in sel_own_units():
		if bool(u.def.get("scout", false)):
			ids.append(u.id)
			if not u.explore:
				all_on = false
	if ids.is_empty():
		hud.toast(Lang.t("toast_explore_none"), Color(1, 0.8, 0.45))
		return
	sim.cmd_explore(human, ids, not all_on)
	sfx("order")
	if not all_on:
		hud.toast(Lang.t("toast_explore_start"), Color(0.7, 0.9, 1.0))
	hud.refresh_now()

func ui_stop() -> void:
	var us := sel_own_units()
	if us.is_empty():
		return
	for u in us:
		sim.cmd_move(human, [u.id], sim.tile_of(u.pos), false)
	sfx("click")

func ui_delete() -> void:
	for e in sel_ents():
		if e.owner == human:
			sim.cmd_delete(human, e.id)
	sfx("click")
	_prune_selection()

func ui_toggle_rally() -> void:
	if sel_building() == null:
		return
	rally_mode = not rally_mode
	amove_mode = false
	if rally_mode:
		hud.toast(Lang.t("toast_rally"), Color(1, 1, 1))
	sfx("click")
	sel_changed.emit()

func ui_toggle_amove() -> void:
	if sel_own_units().is_empty():
		return
	amove_mode = not amove_mode
	rally_mode = false
	if amove_mode:
		hud.toast(Lang.t("toast_amove"), Color(1, 1, 1))
	sfx("click")
	sel_changed.emit()

func ui_toggle_select_mode() -> void:
	select_mode = not select_mode
	if select_mode:
		hud.toast(Lang.t("toast_select_mode"), Color(1, 1, 1))
	sfx("click")
	sel_changed.emit()

func ui_select_idle() -> void:
	var idle := sim.idle_villagers(human)
	if idle.is_empty():
		hud.toast(Lang.t("toast_no_idle"), Color(1, 1, 1))
		return
	_idle_cycle = (_idle_cycle + 1) % idle.size()
	var u: Ent = idle[_idle_cycle]
	select_ents([u])
	focus_on(u.pos)
	sfx("click")

func ui_select_army() -> void:
	var a := sim.army(human)
	if a.is_empty():
		hud.toast(Lang.t("toast_no_army"), Color(1, 1, 1))
		return
	select_ents(a)
	var c := Vector2.ZERO
	for u: Ent in a:
		c += u.pos
	focus_on(c / a.size())
	sfx("click")

func ui_goto_base() -> void:
	for b in sim.buildings:
		if b.alive and b.owner == human and b.type == "centro":
			focus_on(b.center())
			return
	focus_on(sim.tile_center(sim.players[human].start_tile))

func ui_goto_alarm() -> void:
	if alarm_pos.x >= 0:
		focus_on(alarm_pos)

func ui_set_speed(s: float) -> void:
	speed = s

func ui_pause(v: bool) -> void:
	paused = v
	if v:
		save_now()

## Guarda ya (síncrono). Con la partida terminada no hace nada.
func save_now() -> bool:
	if load_state != 3 or sim.game_over:
		return false
	last_save_ok = SaveGame.save(self, true)
	if not last_save_ok:
		push_warning("No se pudo guardar la partida: " + SaveGame.last_error)
		hud.toast(Lang.t("toast_save_failed"), Color(1, 0.6, 0.5))
	return last_save_ok

func ui_exit() -> void:
	if load_state == 3:
		if sim.game_over:
			SaveGame.delete()      # partida terminada: no hay nada que continuar
		else:
			save_now()
	exit_requested.emit()

func _ghost_ok() -> bool:
	if placing_type == "":
		return false
	for t in place_tiles():
		if sim.can_place(placing_type, t, human):
			return true
	return false
