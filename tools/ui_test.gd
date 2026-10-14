extends Node
## Prueba de interfaz: arranca una partida, simula toques reales y guarda capturas.
## Uso: xvfb-run -a godot --path . res://tools/ui_test.tscn -- out=/tmp/ui seed=7

var game: Game
var out := "/tmp/ui"
var step_i := 0
var wait := 0.0
var seq: Array = []

func _ready() -> void:
	var seed_v := 7
	var size_v := 128
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("seed="):
			seed_v = int(a.substr(5))
		elif a.begins_with("size="):
			size_v = int(a.substr(5))
	var cfg := {"size": size_v, "seed": seed_v, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)

func shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s_%s.png" % [out, name])
	print("shot ", name, " ", img.get_size())

func tap(sp: Vector2) -> void:
	var d := InputEventScreenTouch.new()
	d.index = 0
	d.position = sp
	d.pressed = true
	Input.parse_input_event(d)
	await get_tree().process_frame
	var u := InputEventScreenTouch.new()
	u.index = 0
	u.position = sp
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().process_frame

func drag(a: Vector2, b: Vector2, idx: int = 0) -> void:
	var d := InputEventScreenTouch.new()
	d.index = idx
	d.position = a
	d.pressed = true
	Input.parse_input_event(d)
	await get_tree().process_frame
	for i in 6:
		var m := InputEventScreenDrag.new()
		m.index = idx
		m.position = a.lerp(b, (i + 1) / 6.0)
		m.relative = (b - a) / 6.0
		Input.parse_input_event(m)
		await get_tree().process_frame
	var u := InputEventScreenTouch.new()
	u.index = idx
	u.position = b
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().process_frame

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _process(_d: float) -> void:
	if step_i == 0 and game.load_state == 3:
		step_i = 1
		_run()

func world_to_screen(p: Vector2) -> Vector2:
	return game.world_to_screen(p)

func _run() -> void:
	await frames(10)
	shot("1_start")
	var sim := game.sim
	var h := game.human
	# seleccionar un aldeano con un toque
	var vill: Ent = null
	for u in sim.units:
		if u.owner == h:
			vill = u
			break
	print("villager at ", vill.pos, " screen ", world_to_screen(vill.pos))
	await tap(world_to_screen(vill.pos) + Vector2(0, -14))
	await frames(5)
	print("sel after tap: ", game.sel.size())
	shot("2_selected")
	# caja con arrastre largo desde el modo selección
	game.select_mode = true
	var c := world_to_screen(sim.tile_center(sim.players[h].start_tile))
	await drag(c + Vector2(-220, -200), c + Vector2(240, 200))
	await frames(5)
	print("sel after box: ", game.sel.size())
	shot("3_box")
	# menú de construcción
	game.hud.grid_mode = "build"
	game.hud.refresh_now()
	await frames(5)
	shot("4_buildmenu")
	game.ui_begin_place("casa")
	await frames(3)
	await tap(c + Vector2(200, -90))
	await frames(3)
	shot("5_placing")
	game.ui_confirm_place()
	await frames(5)
	print("buildings: ", sim.buildings.size(), " wood ", sim.players[h].res["wood"])
	# avanzar rápido
	game.speed = 3.0
	await get_tree().create_timer(6.0).timeout
	shot("6_later")
	# seleccionar centro urbano
	for b in sim.buildings:
		if b.owner == h and b.type == "centro":
			game.select_ents([b])
	game.hud.refresh_now()
	await frames(5)
	game.ui_train("aldeano")
	await frames(5)
	shot("7_tc")
	# zoom out
	game.zoom = 0.4
	await frames(5)
	shot("8_zoomout")
	# pausa
	game.hud.show_pause()
	await frames(4)
	shot("9_pause")
	game.hud.hide_pause()
	game.hud.help_ui.visible = true
	await frames(3)
	shot("10_help")
	get_tree().quit()
