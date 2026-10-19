extends Node
## Ciudad de pruebas isométrica: construye uno de cada edificio y planta una fila de cada unidad cerca del inicio, y captura.
## Uso: xvfb-run -a godot --path . res://tools/iso_town.tscn --rendering-driver opengl3 --resolution 1280x720 -- out=/tmp/t.png mode=blds|units|enemy|walls|all seed=3 zoom=1.0
##   mode=blds   edificios; mode=units unidades en fila (propias); mode=enemy las mismas con otro equipo; mode=walls murallas y puerta
##   civ=<id>    civilización del jugador (por defecto castellanos); civ2=<id> la del rival (por defecto francos)
##   secs=N      deja correr N segundos de juego antes de capturar (velocidad x3); sel=1 selecciona las primeras unidades; hud=1 deja el HUD
var game: Game
var out := "/tmp/town.png"
var mode := "blds"
var seed_v := 3
var zoom_v := 1.0
var secs := 0.0
var sel := false
var hud_on := false
var at_off := Vector2i(0, 0)
var _started := false
var tod_v := -1.0
var civ_v := "castellanos"
var civ2_v := "francos"

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		elif a.begins_with("mode="): mode = a.substr(5)
		elif a.begins_with("seed="): seed_v = int(a.substr(5))
		elif a.begins_with("zoom="): zoom_v = float(a.substr(5))
		elif a.begins_with("secs="): secs = float(a.substr(5))
		elif a.begins_with("sel="): sel = a.substr(4) == "1"
		elif a.begins_with("hud="): hud_on = a.substr(4) == "1"
		elif a.begins_with("civ="): civ_v = a.substr(4)
		elif a.begins_with("civ2="): civ2_v = a.substr(5)
		elif a.begins_with("tod="): tod_v = float(a.substr(4))   # hora del día 0..1 (0,85 = noche; 0,5 = mediodía)
	Settings.ensure_loaded()
	Settings.profile = 1
	Settings.auto_pause = false
	Settings.apply_display(get_window())
	var cfg := {"size": 128, "seed": seed_v, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú", "civ": civ_v},
		{"human": false, "team": 1, "diff": 0, "name": "Rojo", "civ": civ2_v}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)
	game.paused = true

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		_run()

func _spot(sim: Sim, type: String, base: Vector2i, rmin: int = 3) -> Vector2i:
	for r in range(rmin, 40):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := base + Vector2i(dx, dy)
				if sim.can_place(type, t, 0):
					return t
	return Vector2i(-1, -1)

func _avg(l: Array[Vector2i], dflt: Vector2i) -> Vector2i:
	if l.is_empty():
		return dflt
	var a := Vector2.ZERO
	for t in l:
		a += Vector2(t)
	return Vector2i(a / float(l.size()))

func _run() -> void:
	await get_tree().create_timer(0.3).timeout
	var sim := game.sim
	var st: Vector2i = sim.players[0].start_tile
	sim.players[0].age = 2
	# toda la vista descubierta
	game.l_fog.visible = false
	game.fog.state.fill(2)
	game.view.refresh_explored()
	var placed: Array[Vector2i] = []
	var focus := st
	if mode == "blds" or mode == "all":
		var types := ["casa", "almacen", "cuartel", "arqueria", "establo", "taller", "monasterio", "herreria", "mercado", "torre", "castillo", "puerto"]
		var col := 0
		var base := st + Vector2i(-14, 6)
		for t in types:
			var tile := _spot(sim, t, base + Vector2i((col % 4) * 6, (col / 4) * 6), 0)
			col += 1
			if tile.x >= 0:
				sim._spawn_building(t, 0 if col % 2 == 0 else 1, tile, true)
				placed.append(tile)
		focus = _avg(placed, base)
	if mode == "units" or mode == "enemy" or mode == "all":
		var base := st + Vector2i(-10, 10)
		var owner := 1 if mode == "enemy" else 0
		var i := 0
		for t in Defs.UNITS:
			var naval: bool = bool(Defs.UNITS[t].get("naval", false))
			if naval:
				continue
			var tile := _spot(sim, "casa", base + Vector2i((i % 9) * 2, (i / 9) * 3), 0)
			if tile.x >= 0:
				sim._spawn_unit(t, owner, tile)
				placed.append(tile)
			i += 1
		focus = _avg(placed, base)
	if mode == "walls" or mode == "all":
		var base := st + Vector2i(6, -16)
		var tiles: Array[Vector2i] = []
		for x in 10:
			tiles.append(base + Vector2i(x, 0))
			tiles.append(base + Vector2i(x, 8))
		for y in range(1, 8):
			tiles.append(base + Vector2i(0, y))
			tiles.append(base + Vector2i(9, y))
		for t in tiles:
			if sim.can_place("muralla", t, 0):
				sim._spawn_building("muralla", 0, t, true)
		if sim.can_place("puerta", base + Vector2i(5, 8), 0) or true:
			var tile := base + Vector2i(5, 8)
			var old: Ent = sim.get_ent(sim.occ[tile.y * sim.W + tile.x])
			if old != null:
				sim.cmd_delete(0, old.id)
		focus = base + Vector2i(5, 4)
	game.focus_on(sim.tile_center(focus))
	game.zoom = zoom_v
	game.speed = 3.0
	if not hud_on:
		game.hud.visible = false
		game.hud.set_process(false)
	if sel:
		var us := game.sim.units.filter(func(u: Ent) -> bool: return u.owner == 0)
		game.select_ents(us.slice(0, 6))
	if secs > 0.0:
		game.paused = false
		await get_tree().create_timer(secs / 3.0).timeout
		game.paused = true
	else:
		for k in 4:
			game.view.update(0.016)
			await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	if tod_v >= 0.0:
		sim.time = fposmod(tod_v - 0.30, 1.0) * Game.DAY_LEN
		game._atmosphere()
	for k in 3:
		game.l_ents.queue_redraw()
		game.l_decals.queue_redraw()
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)
	get_tree().quit()
