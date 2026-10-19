extends Node
## Captura del mundo: args seed=N size=128 at=start|x,y zoom=1.0 out=/tmp/w.png fog=0|1 players=2 wait=0.6
var game: Game
var seed_v := 3
var size := 128
var at := "start"
var zoom_v := 1.0
var out := "/tmp/world.png"
var fog_on := false
var nplayers := 2
var wait_s := 0.6
var prof := 1
var _started := false
var steps := 0.0
var t_force := -1.0
var rain_force := -1.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("size="): size = int(a.substr(5))
		elif a.begins_with("at="): at = a.substr(3)
		elif a.begins_with("zoom="): zoom_v = float(a.substr(5))
		elif a.begins_with("out="): out = a.substr(4)
		elif a.begins_with("fog="): fog_on = a.substr(4) == "1"
		elif a.begins_with("players="): nplayers = int(a.substr(8))
		elif a.begins_with("wait="): wait_s = float(a.substr(5))
		elif a.begins_with("perfil="): prof = int(a.substr(7))
		elif a.begins_with("sim="): steps = float(a.substr(4))
		elif a.begins_with("t="): t_force = float(a.substr(2))
		elif a.begins_with("rain="): rain_force = float(a.substr(5))
	Settings.ensure_loaded()
	Settings.profile = prof
	Settings.auto_pause = false
	Settings.apply_display(get_window())
	var pl: Array = [{"human": true, "team": 0, "diff": 1, "name": "Tú"}]
	for i in nplayers - 1:
		pl.append({"human": false, "team": 0 if i == 0 else i + 1, "diff": 1, "name": "IA%d" % i})
	game = Game.new()
	add_child(game)
	game.start({"size": size, "seed": seed_v, "events": true, "players": pl})

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func _run() -> void:
	await get_tree().create_timer(0.3).timeout
	var sim := game.sim
	if steps > 0.0:
		for i in int(steps / Sim.DT):
			sim.step()
		sim.events.clear()
	if t_force >= 0.0:
		sim.time = t_force
	game._atmosphere()
	if rain_force >= 0.0:
		game.rain = rain_force
		game.overcast = rain_force
		game._rain_rect.visible = rain_force > 0.03
		(game._rain_rect.material as ShaderMaterial).set_shader_parameter("amount", rain_force)
		game._sky_mat.set_shader_parameter("cover", rain_force)
	game.zoom = zoom_v
	if at == "start":
		game.focus_on(sim.tile_center(sim.players[game.human].start_tile))
	elif at == "center":
		game.focus_on(Vector2(sim.W, sim.H) * Defs.TILE * 0.5)
	elif at == "minimap":
		game.focus_on(Vector2(sim.W, sim.H) * Defs.TILE * 0.5)
	else:
		var p := at.split(",")
		game.focus_on(sim.tile_center(Vector2i(int(p[0]), int(p[1]))))
	if not fog_on:
		game.l_fog.visible = false
		game.fog.state.fill(2)
		game.view.refresh_explored()
	game.paused = true
	game.hud.visible = false
	game.hud.set_process(false)
	await get_tree().create_timer(wait_s).timeout
	for k in 3:
		game.l_ents.queue_redraw()
		await get_tree().process_frame
	if at == "minimap":
		var mm = game.hud.minimap
		if not mm._built:
			mm._build()
		mm.img_tex.get_image().save_png(out)
		print("MINIMAP ", out)
		get_tree().quit()
		return
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out, " mats ", game.l_terrain.material != null)
	get_tree().quit()
