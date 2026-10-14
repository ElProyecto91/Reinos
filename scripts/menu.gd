class_name MenuScreen
extends CanvasLayer
## Menú principal: rivales, tamaño de mapa, dificultad, equipos y semilla.

signal play_pressed(cfg: Dictionary)
signal quit_pressed

var rivals := 2
var map_size := 192
var diff := 1
var allied := true
var seed_val := 1

var root: Control
var _rows: Array = []
var _play: UiButton
var _help_btn: UiButton
var _quit: UiButton
var _seed_btn: UiButton
var _help: Control
var _seg: Dictionary = {}
var _t := 0.0

func _ready() -> void:
	layer = 5
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	seed_val = rng.randi_range(1000, 99999)
	root = MenuBg.new()
	(root as MenuBg).menu = self
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_segment("rivals", Lang.t("menu_rivals"), [["1", 1], ["2", 2], ["3", 3]], func() -> int: return rivals, func(v: int) -> void: rivals = v)
	_add_segment("size", Lang.t("menu_size"), [[Lang.t("size_128"), 128], [Lang.t("size_192"), 192], [Lang.t("size_256"), 256]], func() -> int: return map_size, func(v: int) -> void: map_size = v)
	_add_segment("diff", Lang.t("menu_diff"), [[Lang.t("diff_0"), 0], [Lang.t("diff_1"), 1], [Lang.t("diff_2"), 2]], func() -> int: return diff, func(v: int) -> void: diff = v)
	_add_segment("teams", Lang.t("menu_teams"), [[Lang.t("teams_allied"), 1], [Lang.t("teams_ffa"), 0]], func() -> int: return 1 if allied else 0, func(v: int) -> void: allied = v == 1)
	_add_segment("perf", Lang.t("menu_perf"), [[Lang.t("perf_ahorro"), 0], [Lang.t("perf_equilibrado"), 1], [Lang.t("perf_alta"), 2]], func() -> int: return Settings.profile, func(v: int) -> void: Settings.set_profile(v, get_window()))
	_seed_btn = UiButton.new()
	_seed_btn.font_size = 22
	_seed_btn.action = func() -> void:
		seed_val = randi_range(1000, 99999)
		_refresh()
	root.add_child(_seed_btn)
	_play = UiButton.new()
	_play.text = Lang.t("menu_play")
	_play.font_size = 36
	_play.accent = Color(0.5, 0.95, 0.5)
	_play.action = _on_play
	root.add_child(_play)
	_help_btn = UiButton.new()
	_help_btn.text = Lang.t("menu_help")
	_help_btn.font_size = 24
	_help_btn.action = func() -> void: _help.visible = true
	root.add_child(_help_btn)
	_quit = UiButton.new()
	_quit.text = Lang.t("menu_quit")
	_quit.font_size = 24
	_quit.action = func() -> void: quit_pressed.emit()
	root.add_child(_quit)
	_help = Hud.HelpPanel.new()
	_help.visible = false
	root.add_child(_help)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_refresh()

func _add_segment(key: String, label: String, opts: Array, getter: Callable, setter: Callable) -> void:
	var btns: Array[UiButton] = []
	for o in opts:
		var b := UiButton.new()
		b.text = o[0]
		b.font_size = 24
		var val: int = o[1]
		b.action = func() -> void:
			setter.call(val)
			_refresh()
		root.add_child(b)
		btns.append(b)
	_seg[key] = {"label": label, "btns": btns, "opts": opts, "get": getter}
	_rows.append(key)

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var w := 760.0
	var x := (vs.x - w) * 0.5
	var y := 158.0
	var rh := 50.0      # alto de botón
	var pitch := 60.0   # separación entre filas
	for key in _rows:
		var d: Dictionary = _seg[key]
		var btns: Array = d["btns"]
		var bw := (w * 0.62) / btns.size()
		for i in btns.size():
			var b: UiButton = btns[i]
			b.size = Vector2(bw - 6, rh)
			b.position = Vector2(x + w * 0.38 + i * bw, y)
		d["y"] = y - 4.0
		y += pitch
	_seed_btn.size = Vector2(w * 0.62 - 6, rh)
	_seed_btn.position = Vector2(x + w * 0.38, y)
	_seg["seed_y"] = y - 4.0
	_play.size = Vector2(w, 74)
	_play.position = Vector2(x, y + 62)
	_help_btn.size = Vector2(w * 0.5 - 6, 54)
	_help_btn.position = Vector2(x, y + 148)
	_quit.size = Vector2(w * 0.5 - 6, 54)
	_quit.position = Vector2(x + w * 0.5 + 6, y + 148)
	_help.position = Vector2.ZERO
	_help.size = vs
	root.queue_redraw()

func _refresh() -> void:
	for key in _rows:
		var d: Dictionary = _seg[key]
		var cur: int = d["get"].call()
		var opts: Array = d["opts"]
		for i in opts.size():
			(d["btns"][i] as UiButton).toggled = int(opts[i][1]) == cur
			(d["btns"][i] as UiButton).queue_redraw()
	_seed_btn.text = "%s  %d   ⟳" % [Lang.t("menu_seed"), seed_val]
	_seed_btn.queue_redraw()
	root.queue_redraw()

func _on_play() -> void:
	var plist: Array = [{"human": true, "team": 0, "diff": 1, "name": Lang.t("player_name")}]
	for i in rivals:
		plist.append({"human": false, "team": 1 if allied else i + 1, "diff": diff, "name": Defs.PLAYER_COLOR_NAMES[i + 1]})
	play_pressed.emit({"size": map_size, "seed": seed_val, "players": plist, "events": true})

class MenuBg extends Control:
	var menu: MenuScreen
	var _islands: Array = []
	func _ready() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 12
		for i in 9:
			_islands.append([r.randf(), r.randf_range(0.55, 0.95), r.randf_range(0.04, 0.12)])
	func _draw() -> void:
		var top := Color(0.07, 0.17, 0.30)
		var bot := Color(0.14, 0.42, 0.55)
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
		draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		for isl in _islands:
			var c := Vector2(isl[0] * size.x, isl[1] * size.y)
			var rr: float = float(isl[2]) * size.x
			draw_set_transform(c, 0.0, Vector2(1.0, 0.35))
			draw_circle(Vector2.ZERO, rr * 1.15, Color(0.85, 0.8, 0.55, 0.35))
			draw_circle(Vector2.ZERO, rr, Color(0.3, 0.55, 0.28, 0.55))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var font := get_theme_default_font()
		draw_string(font, Vector2(3, 103), Lang.t("title"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 86, Color(0, 0, 0, 0.5))
		draw_string(font, Vector2(0, 100), Lang.t("title"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 86, Color(1, 0.9, 0.5))
		draw_string(font, Vector2(0, 140), Lang.t("subtitle"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.85, 0.92, 1.0))
		draw_string(font, Vector2(14, size.y - 12), Settings.build_label(), HORIZONTAL_ALIGNMENT_LEFT, size.x, 18, Color(1, 1, 1, 0.55))
		if menu != null:
			var w := 760.0
			var x := (size.x - w) * 0.5
			for key in menu._rows:
				var d: Dictionary = menu._seg[key]
				draw_string(font, Vector2(x, float(d["y"]) + 38), d["label"], HORIZONTAL_ALIGNMENT_LEFT, w * 0.38, 26, Color(0.95, 0.92, 0.82))
			if menu._seg.has("seed_y"):
				draw_string(font, Vector2(x, float(menu._seg["seed_y"]) + 36), "", HORIZONTAL_ALIGNMENT_LEFT, w * 0.38, 24, Color(0.9, 0.9, 0.8))
