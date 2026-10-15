extends Node
## Edad de los Castillos desde la interfaz: requisito de 2 tipos militares, menús, construir monasterio y castillo, botones de entrenamiento.
var game: Game
var fails := 0
var _started := false

func _ready() -> void:
	var cfg := {"size": 128, "seed": 11, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 0, "name": "Rojo"}]}
	game = Game.new()
	add_child(game)
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
	await get_tree().create_timer(0.25).timeout

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func shot(name: String) -> void:
	get_viewport().get_texture().get_image().save_png("/tmp/ui9_%s.png" % name)

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func slot_with(text: String) -> UiButton:
	for b in game.hud.grid:
		if b.visible and b.text == text:
			return b
	return null

func free_spot(sim: Sim, type: String, around: Vector2i) -> Vector2i:
	for r in range(0, 22):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var q := around + Vector2i(dx, dy)
				if sim.can_place(type, q, game.human):
					return q
	return Vector2i(-1, -1)

func villagers(sim: Sim, h: int) -> Array:
	var vl: Array = []
	for u in sim.units:
		if u.owner == h and u.type == "aldeano":
			vl.append(u)
	return vl

func _run() -> void:
	await frames(5)
	var sim := game.sim
	var h := game.human
	var hud := game.hud
	var p: Player = sim.players[h]
	var s0: Vector2i = p.start_tile
	var tc: Ent = null
	for b in sim.buildings:
		if b.owner == h and b.type == "centro":
			tc = b
	p.res = {"food": 5000, "wood": 5000, "gold": 5000}
	p.age = 1
	p.pop_cap = 200
	# --- 1. sin edificios militares el botón avisa y no sube de edad
	game.select_ents([tc])
	await frames(4)
	var ab := slot_with(Lang.t("age_up"))
	check("botón de avanzar de edad en Feudal", ab != null)
	if ab != null:
		check("el botón enseña lo que falta (0/2)", ab.sub == Lang.t("needs_mil", [0, 2]) and not ab.enabled)
		await tap(ab.get_global_rect().get_center())
		check("tocarlo sin requisitos no sube de edad", not p.aging)
	# --- 2. con cuartel y arquería terminados sí
	sim._spawn_building("cuartel", h, free_spot(sim, "cuartel", s0 + Vector2i(-7, 6)), true)
	await frames(3)
	game.select_ents([tc])
	await frames(4)
	ab = slot_with(Lang.t("age_up"))
	check("con 1 tipo sigue pidiendo 2 (1/2)", ab != null and ab.sub == Lang.t("needs_mil", [1, 2]))
	sim._spawn_building("arqueria", h, free_spot(sim, "arqueria", s0 + Vector2i(7, 6)), true)
	game.select_ents([tc])
	await frames(4)
	ab = slot_with(Lang.t("age_up"))
	check("con 2 tipos el botón queda libre", ab != null and ab.enabled and ab.sub == "")
	if ab != null:
		await tap(ab.get_global_rect().get_center())
	check("empieza a subir de edad", p.aging)
	game.speed = 3.0
	var waited := 0.0
	while p.age < 2 and waited < 40.0:
		await get_tree().create_timer(1.0).timeout
		waited += 1.0
	game.speed = 1.0
	check("llega a la Edad de los Castillos", p.age == 2)
	# --- 3. menús de construcción: monasterio en Militares, castillo en Defensas
	var vl := villagers(sim, h)
	game.select_ents(vl.slice(0, 3))
	await frames(4)
	await tap(hud.grid[0].get_global_rect().get_center())
	var mil := slot_with(Lang.t("military"))
	check("menú Militares", mil != null)
	await tap(mil.get_global_rect().get_center())
	var ms := slot_with(Lang.t("b_monasterio"))
	check("monasterio en Militares y disponible", ms != null and ms.enabled)
	shot("militares")
	await tap(ms.get_global_rect().get_center())
	check("fantasma de monasterio", game.placing_type == "monasterio")
	var mt := free_spot(sim, "monasterio", s0 + Vector2i(-2, -8))
	await tap(game.world_to_screen(sim.tile_center(mt + Vector2i(1, 1))))
	await tap(hud.place_ok.get_global_rect().get_center())
	var mon: Ent = null
	for b in sim.buildings:
		if b.owner == h and b.type == "monasterio":
			mon = b
	check("monasterio en obras", mon != null and mon.progress < 1.0)
	# Defensas → castillo
	game.select_ents(villagers(sim, h).slice(0, 4))
	await frames(4)
	await tap(hud.grid[0].get_global_rect().get_center())
	var dfn := slot_with(Lang.t("defenses"))
	check("menú Defensas", dfn != null)
	await tap(dfn.get_global_rect().get_center())
	var cs := slot_with(Lang.t("b_castillo"))
	check("castillo en Defensas y disponible", cs != null and cs.enabled)
	shot("defensas")
	await tap(cs.get_global_rect().get_center())
	check("fantasma de castillo", game.placing_type == "castillo")
	var ct := free_spot(sim, "castillo", s0 + Vector2i(8, -9))
	check("hay sitio 4x4", ct.x >= 0)
	await tap(game.world_to_screen(Vector2(ct + Vector2i(2, 2)) * float(Defs.TILE)))        # el fantasma 4x4 se centra en el toque
	await tap(hud.place_ok.get_global_rect().get_center())
	var cas: Ent = null
	for b in sim.buildings:
		if b.owner == h and b.type == "castillo":
			cas = b
	check("castillo en obras (4x4)", cas != null and cas.size == 4 and cas.progress < 1.0)
	# --- 4. botones de entrenamiento de las unidades nuevas
	if game.placing_type != "":
		game.ui_cancel_place()
	var made := {}
	for bt in ["taller", "monasterio", "castillo"]:
		var t := free_spot(sim, bt, s0 + Vector2i(-12, -3) if bt != "castillo" else s0 + Vector2i(14, 4))
		made[bt] = sim._spawn_building(bt, h, t, true)
	var cuartel: Ent = null
	var arq: Ent = null
	for b in sim.buildings:
		if b.owner == h and b.progress >= 1.0:
			if b.type == "cuartel":
				cuartel = b
			elif b.type == "arqueria":
				arq = b
	var want := [[cuartel, "alabardero"], [arq, "hostigador"], [arq, "arquero_caballo"], [made["taller"], "catapulta"], [made["monasterio"], "monje"], [made["castillo"], "trabuquete"]]
	for w in want:
		var b: Ent = w[0]
		game.select_ents([b])
		await frames(4)
		var nm: String = Lang.t("us_" + w[1])
		if nm == "us_" + w[1]:
			nm = Lang.t("u_" + w[1])
		var sl := slot_with(nm)
		check("botón %s en %s" % [w[1], b.type], sl != null and sl.enabled)
		if sl != null:
			var q0 := b.queue.size()
			await tap(sl.get_global_rect().get_center())
			check("tocar %s lo encola" % w[1], b.queue.size() == q0 + 1)
		if w[1] == "trabuquete":
			shot("castillo")
	# --- 5. el cuartel ofrece también las unidades anteriores (error antiguo: solo salía el piquero)
	game.select_ents([cuartel])
	await frames(4)
	check("cuartel: piquero, espadachín y alabardero", slot_with(Lang.t("u_piquero")) != null and slot_with(Lang.t("u_espadachin")) != null and slot_with(Lang.t("u_alabardero")) != null)
	game.select_ents([arq])
	await frames(4)
	check("arquería: arquero y ballestero", slot_with(Lang.t("u_arquero")) != null and slot_with(Lang.t("u_ballestero")) != null)
	# --- 6. un monje seleccionado: sin botones de ataque y con su descripción
	var monk := sim._spawn_unit("monje", h, sim.nearest_free_tile(s0 + Vector2i(0, 5), 4))
	game.select_ents([monk])
	await frames(4)
	check("monje: sin atacar-mover", slot_with(Lang.t("attack_move")) == null)
	shot("monje")
	print("DONE fails=", fails)
	get_tree().quit()
