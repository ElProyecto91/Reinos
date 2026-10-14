extends Node
## Prueba de rendimiento: partida con 3 IAs + una IA que juega por el humano, sin esperar al reloj.
## Uso: xvfb-run -a godot --path . res://tools/perf_test.tscn -- size=192 minutes=14 seed=3

var game: Game
var minutes := 14.0
var size_v := 192
var seed_v := 3
var _started := false
var _fog_us := 0
var _fog_n := 0
var _step_us := 0
var _step_n := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("minutes="): minutes = float(a.substr(8))
		elif a.begins_with("size="): size_v = int(a.substr(5))
		elif a.begins_with("seed="): seed_v = int(a.substr(5))
	var cfg := {"size": size_v, "seed": seed_v, "events": true, "players": [
		{"human": true, "team": 0, "diff": 1, "name": "Tú"},
		{"human": false, "team": 1, "diff": 1, "name": "Rojo"},
		{"human": false, "team": 1, "diff": 1, "name": "Amarillo"},
		{"human": false, "team": 1, "diff": 1, "name": "Morado"}]}
	game = Game.new()
	add_child(game)
	game.start(cfg)

func _process(_d: float) -> void:
	if game.load_state == 3 and not _started:
		_started = true
		game.sim.ais.append(AiPlayer.new(game.sim, game.human, 1))
		game.sim.players[game.human].gather_mult = 1.0
		_run()

func _run() -> void:
	var sim := game.sim
	var next_report := 60.0
	var wall0 := Time.get_ticks_msec()
	game.speed = 6.0
	var frames_n := 0
	LayerStats.reset()
	while sim.time < minutes * 60.0 and not sim.game_over:
		await get_tree().process_frame
		frames_n += 1
		if sim.time >= next_report:
			var units := 0
			var blds := 0
			for u in sim.units: if u.alive: units += 1
			for b in sim.buildings: if b.alive: blds += 1
			var t0 := Time.get_ticks_usec()
			game.fog.update(sim, game.human)
			var fog_ms := (Time.get_ticks_usec() - t0) / 1000.0
			var draw_ms := WorldLayer.prof_us / 1000.0 / maxf(WorldLayer.prof_n, 1)
			print("t=%4ds units=%3d blds=%3d fps=%.1f proc_ms=%.1f physics=%.1f fog_ms=%.1f draw_ms=%.2f" % [int(sim.time), units, blds, Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, fog_ms, draw_ms])
			WorldLayer.prof_us = 0
			WorldLayer.prof_n = 0
			next_report += 60.0
	var summ := sim.summary()
	print("END t=", int(sim.time), " over=", sim.game_over, " wall=", (Time.get_ticks_msec() - wall0) / 1000.0, "s")
	for pl in summ["players"]:
		print(pl)
	game.cam_pos = sim.tile_center(sim.players[game.human].start_tile)
	game.zoom = 0.6
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/perf_end.png")
	get_tree().quit()

class LayerStats:
	static func reset() -> void:
		WorldLayer.prof_us = 0
		WorldLayer.prof_n = 0
