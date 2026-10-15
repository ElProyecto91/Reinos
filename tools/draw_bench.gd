extends Node
## Banco de pruebas del dibujo de entidades: una aldea densa a la vista (unidades de todos los tipos,
## edificios, murallas y granjas). Mide el tiempo de GDScript de Renderer.draw_entities por fotograma y las
## llamadas de dibujo del motor, y puede guardar una captura determinista para comparar antes/después.
## Uso: xvfb-run -a godot --path . res://tools/draw_bench.tscn --rendering-driver opengl3 --resolution 1280x720 -- frames=240 zoom=0.8 shot=/tmp/a.png
## Con shot=… la partida se pausa y la captura es idéntica entre ejecuciones (misma semilla).
var game: Game
var _started := false
var frames_n := 240
var zoom_v := 0.8
var shot_path := ""
var units_per_type := 14
var run_sim := true
var nohud := false
var prof_proc := false
var hide_list: PackedStringArray = []
var noter := false
var steps_before := 0       # pasos de simulación antes de la captura (para que haya unidades en movimiento)
var night_v := 0.0
var select_n := 0
var scene_flags := 0        # 1 = unidades heridas, 2 = aldeanos cargados

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frames="):
			frames_n = int(a.substr(7))
		elif a.begins_with("zoom="):
			zoom_v = float(a.substr(5))
		elif a.begins_with("shot="):
			shot_path = a.substr(5)
		elif a.begins_with("units="):
			units_per_type = int(a.substr(6))
		elif a.begins_with("sim="):
			run_sim = int(a.substr(4)) != 0
		elif a.begins_with("hide="):
			hide_list = a.substr(5).split(",")
		elif a == "proc":
			prof_proc = true
		elif a == "nohud":
			nohud = true
		elif a == "noter":
			noter = true
		elif a.begins_with("steps="):
			steps_before = int(a.substr(6))
		elif a.begins_with("night="):
			night_v = float(a.substr(6))
		elif a.begins_with("select="):
			select_n = int(a.substr(7))
		elif a.begins_with("flags="):
			scene_flags = int(a.substr(6))
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.apply_display(get_window())
	var cfg := {"size": 128, "seed": 4, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 0, "name": "Rojo"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)
	if shot_path != "":
		game.paused = true      # la partida no avanza sola: la captura sólo depende de la semilla

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func _free_near(sim: Sim, t: Vector2i, type: String, h: int) -> Vector2i:
	for r in range(0, 14):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := t + Vector2i(dx, dy)
				if sim.can_place(type, q, h):
					return q
	return Vector2i(-1, -1)

func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	var sim := game.sim
	var h := game.human
	sim.ais.clear()
	var base: Vector2i = sim.players[h].start_tile
	var placed := 0
	var ring := [Vector2i(-9, -7), Vector2i(8, -7), Vector2i(-9, 7), Vector2i(8, 7), Vector2i(0, -11), Vector2i(0, 11), Vector2i(-14, 0), Vector2i(13, 0)]
	var kinds := ["cuartel", "arqueria", "establo", "taller", "almacen", "torre", "torre", "casa", "casa", "casa", "casa", "casa", "casa", "casa", "casa", "casa", "casa", "casa", "casa", "casa"]
	var i := 0
	for k in kinds:
		var c: Vector2i = base + ring[i % ring.size()] + Vector2i((i / ring.size()) * 4, (i / ring.size()) * 3)
		var t := _free_near(sim, c, k, h)
		if t.x >= 0:
			sim._spawn_building(k, h, t, true)
			placed += 1
		i += 1
	var order := ["aldeano", "piquero", "arquero", "jinete", "espadachin", "ballestero", "explorador", "caballero", "ariete"]
	var n := 0
	for ty in order:
		for k in units_per_type:
			var tile := sim.nearest_free_tile(base + Vector2i(-12 + (k * 7 + n) % 24, -8 + (k * 5 + n * 3) % 16), 8)
			var u := sim._spawn_unit(ty, h if k % 5 != 4 else 1, tile)
			if run_sim and k % 3 != 0:
				var dest := sim.nearest_free_tile(base + Vector2i(-14 + (k * 11 + n * 5) % 28, -9 + (k * 3 + n * 7) % 18), 6)
				if u.owner == h:
					sim.cmd_move(h, [u.id], dest)
			n += 1
	sim.players[h].pop_cap = 400
	game.cam_pos = sim.tile_center(base)
	game.zoom = zoom_v
	await get_tree().process_frame
	var vr := game.view_rect(80.0)
	var vis := 0
	for u in sim.units:
		if u.alive and vr.has_point(u.pos) and game.can_see_unit(u):
			vis += 1
	print("INFO edificios %d, unidades %d (a la vista %d), zoom %.2f" % [placed, sim.units.size(), vis, game.zoom])
	if shot_path != "":
		for j in steps_before:
			sim.step()
		var own: Array[Ent] = []
		var k2 := 0
		for u in sim.units:
			if not u.alive:
				continue
			k2 += 1
			if (scene_flags & 1) != 0 and k2 % 4 == 0:
				u.hp = u.max_hp * (0.3 + 0.1 * float(k2 % 6))
			if (scene_flags & 2) != 0 and u.type == "aldeano" and k2 % 2 == 0:
				u.carry_kind = ["gold", "food", "wood"][k2 % 3]
				u.carry_amt = 3.0 + float(k2 % 8)
			if u.owner == h and u.type != "ariete":
				own.append(u)
		if select_n > 0:
			game.select_ents(own.slice(0, select_n))
		game.night = night_v
		game.paused = true
		game.anim_t = 1.234
		game.interp = 0.0
		game._dirty = 3
		for j in 4:
			await get_tree().process_frame
		await get_tree().create_timer(0.4).timeout
		get_viewport().get_texture().get_image().save_png(shot_path)
		print("INFO captura ", shot_path)
		get_tree().quit()
		return
	if nohud:
		game.hud.root.visible = false
	for hname in hide_list:
		match hname:
			"terrain": game.l_terrain.visible = false
			"sky": game.l_sky.visible = false
			"fog": game.l_fog.visible = false
			"res": game.res_layer.visible = false
			"ents": game.l_ents.visible = false
	if noter:
		game.l_terrain.visible = false
		game.l_sky.visible = false
		game.l_fog.visible = false
		game.res_layer.visible = false
	# calentar y medir
	for j in 30:
		await get_tree().process_frame
	if prof_proc:
		# Tiempo de GDScript de Game._process y Hud._process por fotograma (simulación incluida), a 30 fps simulados
		game.set_process(false)
		game.hud.set_process(false)
		var tg := 0
		var th := 0
		var worst := 0
		var nn := 300
		for j in nn:
			await get_tree().process_frame
			var t0 := Time.get_ticks_usec()
			game._process(1.0 / 30.0)
			var t1 := Time.get_ticks_usec()
			game.hud._process(1.0 / 30.0)
			var t2 := Time.get_ticks_usec()
			tg += t1 - t0
			th += t2 - t1
			worst = maxi(worst, t1 - t0)
		var parts := {"step_sim": 0, "fog": 0, "atmo": 0, "idle": 0, "keys": 0, "apply_cam": 0, "fx": 0, "prune": 0}
		var fog_n := 0
		for j in 150:
			await get_tree().process_frame
			var a0 := Time.get_ticks_usec()
			game._step_sim(1.0 / 30.0)
			var a1 := Time.get_ticks_usec()
			parts["step_sim"] += a1 - a0
			if j % 12 == 0:
				game.fog.update(game.sim, game.human)
				fog_n += 1
			var a2 := Time.get_ticks_usec()
			parts["fog"] += a2 - a1
			if j % 8 == 0:
				game._atmosphere()
			var a3 := Time.get_ticks_usec()
			parts["atmo"] += a3 - a2
			game._check_idle()
			game._keys(0.033)
			game._long_press_check()
			var a4 := Time.get_ticks_usec()
			parts["keys"] += a4 - a3
			game._apply_camera()
			game._update_fx(0.033)
			game._prune_selection()
			var a5 := Time.get_ticks_usec()
			parts["apply_cam"] += a5 - a4
		print("PARTS (ms por fotograma, media de 150): step_sim %.3f  fog(1 de cada 12) %.3f  atmósfera(1 de 8) %.3f  teclas/idle %.3f  cámara/fx/selección %.3f" % [parts["step_sim"] / 150000.0, parts["fog"] / 150000.0, parts["atmo"] / 150000.0, parts["keys"] / 150000.0, parts["apply_cam"] / 150000.0])
		print("RESULT game._process %.3f ms/frame (peor %.1f ms), hud._process %.3f ms/frame (sin refresco periódico incluido en media)" % [tg / 1000.0 / nn, worst / 1000.0, th / 1000.0 / nn])
		get_tree().quit()
		return
	WorldLayer.prof_us = 0
	WorldLayer.prof_n = 0
	var calls := 0.0
	var proc := 0.0
	var objs := 0.0
	var t0 := Time.get_ticks_usec()
	for j in frames_n:
		await get_tree().process_frame
		calls += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		objs += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var wall := (Time.get_ticks_usec() - t0) / 1000.0
	var nd := maxf(float(WorldLayer.prof_n), 1.0)
	print("RESULT draw_ms=%.3f redraws=%d/%d frames  calls=%.0f objects=%.0f process_ms=%.2f wall_ms_per_frame=%.1f" % [
		float(WorldLayer.prof_us) / 1000.0 / nd, WorldLayer.prof_n, frames_n, calls / frames_n, objs / frames_n, proc / frames_n, wall / frames_n])
	get_tree().quit()
