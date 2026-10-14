extends Node
## Combate y fin de partida desde la interfaz.

var game: Game
var fails := 0
var exited := false
var _started := false

func _ready() -> void:
	var cfg := {"size": 128, "seed": 7, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo"}]}
	game = Game.new()
	add_child(game)
	game.exit_requested.connect(func() -> void: exited = true)
	game.start(cfg)

func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1

func touch(idx: int, pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = idx
	t.position = pos
	t.pressed = pressed
	Input.parse_input_event(t)

func tap(sp: Vector2) -> void:
	touch(0, sp, true)
	await get_tree().process_frame
	touch(0, sp, false)
	await get_tree().process_frame
	await get_tree().process_frame

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("/tmp/ui3_%s.png" % name)

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func _run() -> void:
	await frames(5)
	var sim := game.sim
	var h := game.human
	var enemy := 1
	var etc: Ent = null
	for b in sim.buildings:
		if b.owner == enemy:
			etc = b
	var near := sim.tile_of(etc.center()) + Vector2i(-6, 0)
	var spawned: Array = []
	for i in 14:
		var t := sim.nearest_free_tile(near + Vector2i(i % 4, i / 4), 6)
		var u := sim._spawn_unit("piquero", h, t)
		spawned.append(u)
	sim.players[h].age = 1
	sim.players[enemy].res = {"food": 0, "wood": 0, "gold": 0}
	for i in 6:
		var t2 := sim.nearest_free_tile(near + Vector2i(i % 3, 5 + i / 3), 6)
		spawned.append(sim._spawn_unit("arquero", h, t2))
	game.focus_on(etc.center() + Vector2(-100, 0))
	game.zoom = 0.8
	await frames(15)
	# seleccionar el ejército con el botón rápido
	var army_btn: UiButton = game.hud.quick[1]
	await tap(army_btn.get_global_rect().get_center())
	await frames(3)
	check("army selected via quick button", game.sel.size() == 20)
	# camara de vuelta al enemigo
	game.focus_on(etc.center() + Vector2(-100, 0))
	await frames(5)
	check("enemy tc visible", game.can_see_building(etc))
	# tocar el centro enemigo
	await tap(game.world_to_screen(etc.center()))
	await frames(4)
	var attacking := 0
	for u in spawned:
		if u.alive and (u.state == Sim.S_ATTACK_GO or u.state == Sim.S_ATTACK):
			attacking += 1
	check("tap enemy orders attack", attacking >= 10)
	game.speed = 3.0
	await get_tree().create_timer(5.0).timeout
	shot("fight")
	print("enemy tc hp ", etc.hp, " kills ", sim.players[h].kills)
	game.speed = 6.0
	var waited := 0.0
	while not sim.game_over and waited < 90.0:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
		if int(waited) % 10 == 0:
			print("enemy tc hp ", int(etc.hp), " alive=", etc.alive)
	check("victory reached", sim.game_over and sim.winner_team == 0)
	await get_tree().create_timer(3.0).timeout
	check("end panel visible", game.hud.end_ui.visible)
	shot("end")
	var b2: UiButton = game.hud.end_ui.btn
	await tap(b2.get_global_rect().get_center())
	await frames(3)
	check("exit requested", exited)
	print("RESULT fails=", fails)
	get_tree().quit()
