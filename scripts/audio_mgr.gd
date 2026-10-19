class_name AudioMgr
extends Node
## Efectos y ambiente sonoro. Todo está sintetizado (tools/gen_audio.py), sin música.

const SFX := ["click", "order", "place", "built", "hit", "arrow", "death", "crash", "trained", "alarm", "age", "victory", "defeat", "error", "deposit", "cannon", "splash"]
const AMB := ["wind", "sea", "forest", "rain"]
const COOLDOWN := {"hit": 70, "arrow": 90, "death": 80, "click": 40, "order": 60, "crash": 150, "built": 350, "deposit": 250, "cannon": 110, "splash": 200}

var game: Game
var muted := false
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _amb: Dictionary = {}
var _amb_vol: Dictionary = {"wind": 0.0, "sea": 0.0, "forest": 0.0, "rain": 0.0}
var _amb_target: Dictionary = {"wind": 0.3, "sea": 0.0, "forest": 0.0, "rain": 0.0}
var _amb_t := 0.0
var _last: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var active := false
var quiet := false   # pausa o fin de partida: el ambiente se detiene para no gastar batería

func _ready() -> void:
	_rng.randomize()
	for n in SFX:
		var path := "res://audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)

func start() -> void:
	for n in AMB:
		var path := "res://audio/%s.wav" % n
		if not ResourceLoader.exists(path):
			continue
		var s: AudioStreamWAV = (load(path) as AudioStreamWAV).duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.volume_db = -60.0
		add_child(p)
		p.play()
		_amb[n] = p
	active = true

func set_quiet(v: bool) -> void:
	quiet = v
	for n in _amb:
		(_amb[n] as AudioStreamPlayer).stream_paused = v or muted

func set_muted(v: bool) -> void:
	muted = v
	AudioServer.set_bus_mute(0, v)
	# Silenciado = ni siquiera se mezcla el ambiente.
	for n in _amb:
		(_amb[n] as AudioStreamPlayer).stream_paused = v or quiet

func play(name: String, pos: Vector2 = Vector2(-1e9, -1e9)) -> void:
	if muted or not _streams.has(name):
		return
	var now := Time.get_ticks_msec()
	if COOLDOWN.has(name) and now - int(_last.get(name, -1000)) < int(COOLDOWN[name]):
		return
	var gain := 1.0
	if pos.x > -1e8 and game != null and game.load_state == 3:
		var d := Iso.proj(pos).distance_to(game.cam_pos) * game.zoom
		var reach := game._vs.x * 0.75
		gain = clampf(1.15 - d / reach, 0.0, 1.0)
		if gain < 0.06:
			return
	_last[name] = now
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = linear_to_db(gain * 0.9)
			p.pitch_scale = _rng.randf_range(0.93, 1.07) if name in ["hit", "arrow", "death", "click"] else 1.0
			p.play()
			return

func _process(delta: float) -> void:
	if not active or quiet or muted or game == null or game.load_state != 3:
		return
	_amb_t -= delta
	if _amb_t <= 0.0:
		_amb_t = 0.4
		_sample_surroundings()
	for n in _amb:
		var cur: float = _amb_vol[n]
		cur = lerpf(cur, float(_amb_target[n]), clampf(delta * 1.5, 0.0, 1.0))
		_amb_vol[n] = cur
		var p: AudioStreamPlayer = _amb[n]
		p.volume_db = linear_to_db(maxf(cur, 0.0001)) - 4.0
		# Un ambiente inaudible no se mezcla.
		var inaudible: bool = cur < 0.01 and float(_amb_target[n]) < 0.01
		if p.stream_paused != inaudible:
			p.stream_paused = inaudible

func _sample_surroundings() -> void:
	var sim := game.sim
	var c := sim.tile_of(Iso.unproj(game.cam_pos))
	var water := 0
	var trees := 0
	var total := 0
	for dy in range(-12, 13, 3):
		for dx in range(-12, 13, 3):
			var t := c + Vector2i(dx, dy)
			if not sim.in_bounds(t):
				continue
			total += 1
			var i := t.y * sim.W + t.x
			if sim.terrain[i] == Defs.T_WATER:
				water += 1
			elif sim.rtype[i] == Defs.R_TREE:
				trees += 1
	var wf := float(water) / maxf(total, 1)
	var tf := float(trees) / maxf(total, 1)
	var far := clampf((game.zoom - 0.35) / 0.8, 0.3, 1.0)
	_amb_target["sea"] = clampf(wf * 1.8, 0.0, 1.0) * 0.7 * far
	_amb_target["forest"] = clampf(tf * 4.0, 0.0, 1.0) * 0.6 * far
	_amb_target["wind"] = (0.28 + 0.2 * (1.0 - wf) + 0.15 * game.rain) * far
	_amb_target["rain"] = clampf(game.rain, 0.0, 1.0) * 0.55
