class_name Hud
extends CanvasLayer
## Interfaz táctil: barra de recursos, minimapa, panel de selección, órdenes, avisos y menús.

const TOP_H := 56.0
const MM := 170.0
const CELL := Vector2(86, 76)
const GAP := 5.0
const COLS := 5

var game: Game
var vs := Vector2(1280, 720)

var root: Control
var topbar: TopBar
var minimap: Minimap
var info: InfoPanel
var place_bar: Control
var place_label: Label
var place_ok: UiButton
var place_cancel: UiButton
var toasts: Toasts
var grid: Array[UiButton] = []
var quick: Array[UiButton] = []
var speed_btn: UiButton
var menu_btn: UiButton
var pause_ui: Control
var help_ui: Control
var end_ui: EndPanel
var load_ui: LoadPanel

var grid_mode := "main"
var _t := 0.0
var _sig := ""
var _del_confirm := -10.0
var _exit_confirm := -10.0
var _speed_btns: Array[UiButton] = []
var _pause_btns: Dictionary = {}
var _pause_title: Label
var _used: Array[bool] = []

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	topbar = TopBar.new()
	topbar.hud = self
	topbar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(topbar)

	minimap = Minimap.new()
	minimap.hud = self
	root.add_child(minimap)

	info = InfoPanel.new()
	info.hud = self
	root.add_child(info)
	info.build_queue_buttons()

	for i in COLS * 2:
		var b := UiButton.new()
		b.visible = false
		root.add_child(b)
		grid.append(b)
		_used.append(false)

	var qdefs := [["idle", "idle", _q_idle], ["army", "army", _q_army], ["base", "base", _q_base], ["select", "select", _q_select]]
	for q in qdefs:
		var b := UiButton.new()
		b.icon_kind = q[1]
		b.action = q[2]
		root.add_child(b)
		quick.append(b)

	speed_btn = UiButton.new()
	speed_btn.font_size = 22
	speed_btn.action = _cycle_speed
	root.add_child(speed_btn)
	menu_btn = UiButton.new()
	menu_btn.icon_kind = "menu"
	menu_btn.action = show_pause
	root.add_child(menu_btn)

	_build_place_bar()
	toasts = Toasts.new()
	toasts.hud = self
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)

	_build_pause()
	_build_help()
	end_ui = EndPanel.new()
	end_ui.hud = self
	end_ui.visible = false
	root.add_child(end_ui)
	load_ui = LoadPanel.new()
	load_ui.hud = self
	root.add_child(load_ui)

	get_viewport().size_changed.connect(layout)
	game.sel_changed.connect(_on_sel_changed)
	layout()

# ------------------------------------------------------------------ composición

func layout() -> void:
	vs = get_viewport().get_visible_rect().size
	topbar.position = Vector2.ZERO
	topbar.size = Vector2(vs.x, TOP_H)
	menu_btn.position = Vector2(vs.x - 64, 2)
	menu_btn.size = Vector2(56, 52)
	speed_btn.position = Vector2(vs.x - 64 - 70, 2)
	speed_btn.size = Vector2(62, 52)
	minimap.position = Vector2(8, vs.y - MM - 8)
	minimap.size = Vector2(MM, MM)
	var gx := vs.x - (CELL.x * COLS + GAP * (COLS - 1)) - 8.0
	var gy := vs.y - (CELL.y * 2 + GAP) - 8.0
	for i in grid.size():
		var c := i % COLS
		var r := i / COLS
		grid[i].position = Vector2(gx + c * (CELL.x + GAP), gy + r * (CELL.y + GAP))
		grid[i].size = CELL
	var ir := Rect2(MM + 16.0, gy, gx - 8.0 - (MM + 16.0), CELL.y * 2 + GAP)
	info.position = ir.position
	info.size = ir.size
	place_bar.position = ir.position
	place_bar.size = ir.size
	_layout_place_bar()
	for i in quick.size():
		quick[i].position = Vector2(vs.x - 80, TOP_H + 12 + i * 80)
		quick[i].size = Vector2(72, 72)
	toasts.position = Vector2.ZERO
	toasts.size = vs
	for c in [pause_ui, help_ui, end_ui, load_ui]:
		if c != null:
			c.position = Vector2.ZERO
			c.size = vs
	_layout_pause()
	info.layout_queue()

func _build_place_bar() -> void:
	place_bar = PanelBox.new()
	place_bar.visible = false
	root.add_child(place_bar)
	place_label = Label.new()
	place_label.add_theme_font_size_override("font_size", 22)
	place_label.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82))
	place_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	place_bar.add_child(place_label)
	place_ok = UiButton.new()
	place_ok.icon_kind = "ok"
	place_ok.accent = Color(0.4, 0.9, 0.45)
	place_ok.action = func() -> void: game.ui_confirm_place()
	place_bar.add_child(place_ok)
	place_cancel = UiButton.new()
	place_cancel.icon_kind = "cancel"
	place_cancel.action = func() -> void: game.ui_cancel_place()
	place_bar.add_child(place_cancel)

func _layout_place_bar() -> void:
	var s := place_bar.size
	place_label.position = Vector2(12, 8)
	place_label.size = Vector2(s.x - 24, s.y - 90)
	place_ok.size = Vector2(s.x * 0.5 - 18, 66)
	place_ok.position = Vector2(12, s.y - 78)
	place_cancel.size = Vector2(s.x * 0.5 - 18, 66)
	place_cancel.position = Vector2(s.x * 0.5 + 6, s.y - 78)

func _build_pause() -> void:
	pause_ui = Control.new()
	pause_ui.visible = false
	pause_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(pause_ui)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_ui.add_child(dim)
	var mk := func(key: String, text: String, act: Callable) -> UiButton:
		var b := UiButton.new()
		b.text = text
		b.font_size = 26
		b.action = act
		pause_ui.add_child(b)
		_pause_btns[key] = b
		return b
	_pause_title = Label.new()
	_pause_title.add_theme_font_size_override("font_size", 22)
	_pause_title.add_theme_color_override("font_color", Color(0.97, 0.93, 0.82))
	_pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_ui.add_child(_pause_title)
	mk.call("resume", Lang.t("pause_resume"), hide_pause)
	mk.call("sound", "", _toggle_sound)
	mk.call("auto", "", _toggle_auto)
	mk.call("perf", "", _cycle_perf)
	mk.call("help", Lang.t("pause_help"), func() -> void: help_ui.visible = true)
	mk.call("exit", Lang.t("pause_exit"), _exit_pressed)
	for i in 3:
		var sp := float(i + 1)
		var b := UiButton.new()
		b.text = "x%d" % (i + 1)
		b.font_size = 26
		b.action = func() -> void: _set_speed(sp)
		pause_ui.add_child(b)
		_speed_btns.append(b)

func _layout_pause() -> void:
	if _pause_btns.is_empty():
		return
	var w := 400.0
	var x := (vs.x - w) * 0.5
	var y := vs.y * 0.5 - 250.0
	var h := 58.0
	var pitch := 68.0
	_pause_title.position = Vector2(x - 40, y)
	_pause_title.size = Vector2(w + 80, 30)
	var top := y + 40.0
	var place := func(k: String, row: int, col: int, cols: int) -> void:
		var b: UiButton = _pause_btns[k]
		var bw := (w - (cols - 1) * 10.0) / cols
		b.size = Vector2(bw, h)
		b.position = Vector2(x + col * (bw + 10.0), top + row * pitch)
		b.font_size = 26 if cols == 1 else 21
	place.call("resume", 0, 0, 1)
	place.call("sound", 2, 0, 2)
	place.call("auto", 2, 1, 2)
	place.call("perf", 3, 0, 1)
	place.call("help", 4, 0, 1)
	place.call("exit", 5, 0, 1)
	for i in 3:
		_speed_btns[i].size = Vector2((w - 20) / 3.0, h)
		_speed_btns[i].position = Vector2(x + i * ((w - 20) / 3.0 + 10), top + pitch)

func _build_help() -> void:
	help_ui = HelpPanel.new()
	(help_ui as HelpPanel).hud = self
	help_ui.visible = false
	root.add_child(help_ui)

# ------------------------------------------------------------------ interfaz hacia el juego

func blocking() -> bool:
	return load_ui.visible or pause_ui.visible or end_ui.visible or help_ui.visible

func is_over_ui(pos: Vector2) -> bool:
	if blocking():
		return true
	if topbar.get_global_rect().has_point(pos) or minimap.get_global_rect().has_point(pos):
		return true
	if info.visible and info.get_global_rect().has_point(pos):
		return true
	if place_bar.visible and place_bar.get_global_rect().has_point(pos):
		return true
	for b in grid:
		if b.visible and b.get_global_rect().grow(3).has_point(pos):
			return true
	for b in quick:
		if b.get_global_rect().grow(3).has_point(pos):
			return true
	return false

func set_loading(msg: String) -> void:
	load_ui.msg = msg
	load_ui.visible = true
	load_ui.queue_redraw()

func finish_loading() -> void:
	load_ui.visible = false
	refresh_now()

func toast(text: String, col: Color = Color.WHITE) -> void:
	toasts.add(text, col)

func show_pause(auto: bool = false) -> void:
	if game.load_state != 3 or end_ui.visible:
		return
	game.ui_pause(true)
	pause_ui.visible = true
	_exit_confirm = -10.0
	_pause_title.text = Lang.t("pause_title_auto") if auto else Lang.t("pause_title")
	if game.last_save_ok:
		_pause_title.text += Lang.t("pause_saved")
	_refresh_pause()

func hide_pause() -> void:
	pause_ui.visible = false
	help_ui.visible = false
	game.ui_pause(false)

func back_pressed() -> void:
	if end_ui.visible:
		return
	if help_ui.visible:
		help_ui.visible = false
	elif pause_ui.visible:
		hide_pause()
	elif game.placing_type != "":
		game.ui_cancel_place()
	elif game.rally_mode or game.amove_mode or game.select_mode:
		game.rally_mode = false
		game.amove_mode = false
		game.select_mode = false
		refresh_now()
	elif not game.sel.is_empty():
		game.clear_selection()
	else:
		show_pause()

func show_end() -> void:
	end_ui.setup()
	end_ui.visible = true

func _refresh_pause() -> void:
	(_pause_btns["sound"] as UiButton).text = Lang.t("pause_sound_off") if game.audio.muted else Lang.t("pause_sound_on")
	(_pause_btns["auto"] as UiButton).text = Lang.t("pause_auto_on") if Settings.auto_pause else Lang.t("pause_auto_off")
	(_pause_btns["perf"] as UiButton).text = Lang.t("pause_perf", [Settings.profile_name()])
	(_pause_btns["exit"] as UiButton).text = Lang.t("pause_exit_confirm") if Time.get_ticks_msec() / 1000.0 - _exit_confirm < 3.0 else Lang.t("pause_exit")
	for i in 3:
		_speed_btns[i].toggled = is_equal_approx(game.speed, float(i + 1))
	for k in _pause_btns:
		(_pause_btns[k] as UiButton).queue_redraw()
	for b in _speed_btns:
		b.queue_redraw()

func _toggle_sound() -> void:
	game.audio.set_muted(not game.audio.muted)
	_refresh_pause()

func _toggle_auto() -> void:
	Settings.auto_pause = not Settings.auto_pause
	Settings.save()
	_refresh_pause()

func _cycle_perf() -> void:
	Settings.cycle_profile(get_window())
	game.reset_run_mode()   # reaplica fps y modo de ejecución en el siguiente fotograma
	_refresh_pause()

func _set_speed(s: float) -> void:
	game.ui_set_speed(s)
	_refresh_pause()

func _cycle_speed() -> void:
	var n := int(game.speed) % 3 + 1
	game.ui_set_speed(float(n))
	game.sfx("click")
	refresh_now()

func _exit_pressed() -> void:
	game.ui_exit()    # guarda la partida y vuelve al menú (ya no se pierde nada, no hace falta confirmar)

func _q_idle() -> void:
	game.ui_select_idle()

func _q_army() -> void:
	game.ui_select_army()

func _q_base() -> void:
	game.ui_goto_base()
	game.sfx("click")

func _q_select() -> void:
	game.ui_toggle_select_mode()

func _on_sel_changed() -> void:
	grid_mode = "main"
	refresh_now()

# ------------------------------------------------------------------ actualización

func _process(delta: float) -> void:
	if game == null or game.load_state != 3:
		if load_ui.visible:
			load_ui.queue_redraw()
		return
	if pause_ui.visible or end_ui.visible:
		return
	_t -= delta
	if _t <= 0.0:
		_t = float(Settings.v("hud"))
		refresh_now()
	if toasts.has_content():
		toasts.queue_redraw()

func refresh_now() -> void:
	if game.load_state != 3:
		return
	var g := game
	var p: Player = g.sim.players[g.human]
	topbar.queue_redraw()
	speed_btn.set_content("x%d" % int(g.speed))
	var idle := g.sim.idle_villagers(g.human).size()
	quick[0].badge = str(idle) if idle > 0 else ""
	quick[0].queue_redraw()
	quick[3].toggled = g.select_mode
	quick[3].queue_redraw()
	var army := g.sim.army(g.human).size()
	quick[1].badge = str(army) if army > 0 else ""
	quick[1].queue_redraw()
	var has_sel := not g.sel.is_empty()
	var placing := g.placing_type != ""
	info.visible = has_sel and not placing
	place_bar.visible = placing
	if placing:
		_update_place_bar()
	else:
		info.queue_redraw()
		info.update_queue()
	_update_grid(p)
	minimap.queue_redraw()
	if pause_ui.visible:
		_refresh_pause()

func _update_place_bar() -> void:
	var g := game
	var t := g.placing_type
	var ok := g._ghost_ok()
	var cost: Dictionary = Defs.FARM_COST if t == "granja" else Defs.BUILDINGS[t]["cost"]
	var nm := Lang.t("b_" + t)
	if t == "granja":
		place_label.text = Lang.t("place_farm_hint", [nm])
		place_ok.text = Lang.t("place_done")
		place_ok.icon_kind = "ok"
		place_ok.set_meta("farm", true)
	elif t == "puerto":
		place_label.text = Lang.t("place_dock_hint", [nm, _cost_str(cost)])
		place_ok.text = Lang.t("place_build")
		place_ok.icon_kind = "ok"
	elif t == "muralla":
		var n := maxi(1, g.place_tiles().size())
		var tot := {}
		for k in cost:
			tot[k] = int(cost[k]) * n
		place_label.text = Lang.t("place_wall_hint", [n, _cost_str(tot)])
		place_ok.text = Lang.t("place_build")
		place_ok.icon_kind = "ok"
	else:
		place_label.text = Lang.t("place_hint", [nm, _cost_str(cost)])
		place_ok.text = Lang.t("place_build")
		place_ok.icon_kind = "ok"
	place_ok.cost = {}
	place_ok.enabled = ok or t == "granja"
	place_ok.action = (func() -> void: game.ui_cancel_place()) if t == "granja" else (func() -> void: game.ui_confirm_place())
	place_cancel.text = Lang.t("place_done") if t == "muralla" else Lang.t("place_cancel")
	place_ok.queue_redraw()
	place_cancel.queue_redraw()

func _cost_str(cost: Dictionary) -> String:
	var parts: Array[String] = []
	var names := {"food": Lang.t("res_food"), "wood": Lang.t("res_wood"), "gold": Lang.t("res_gold")}
	for k in ["food", "wood", "gold"]:
		if cost.has(k) and int(cost[k]) > 0:
			parts.append("%d %s" % [int(cost[k]), names[k]])
	return ", ".join(parts)

func _lack(res: Dictionary, cost: Dictionary) -> Dictionary:
	var out := {}
	for k in cost:
		if int(res.get(k, 0)) < int(cost[k]):
			out[k] = true
	return out

func _slot(i: int, text: String, ic: Texture2D, kind: String, cost: Dictionary, res: Dictionary, on: bool, act: Callable, toggled: bool = false, progress: float = -1.0, sub: String = "") -> void:
	var b := grid[i]
	_used[i] = true
	b.text = text
	b.sub = sub
	b.icon = ic
	b.icon_kind = kind
	b.cost = cost
	b.lack = _lack(res, cost)
	b.enabled = on and b.lack.is_empty()
	b.toggled = toggled
	b.progress = progress
	b.action = act
	b.font_size = 20
	b.queue_redraw()

func _update_grid(p: Player) -> void:
	# Importante: no ocultar y volver a mostrar un botón en cada refresco; si ocurre entre
	# pulsar y soltar, Godot pierde el evento de soltar y el toque no se registra.
	_used.fill(false)
	_fill_grid(p)
	for i in grid.size():
		if grid[i].visible != _used[i]:
			grid[i].visible = _used[i]

## Nombre corto para los botones (las celdas son estrechas); si no hay, el nombre completo.
func _short_name(ut: String) -> String:
	var k := "us_" + ut
	var s := Lang.t(k)
	return s if s != k else Lang.t("u_" + ut)

func _fill_grid(p: Player) -> int:
	var g := game
	if g.placing_type != "":
		return 0
	var n := 0
	var res := p.res
	var b := g.sel_building()
	var units := g.sel_own_units()
	if b != null and b.owner == g.human:
		if b.progress >= 1.0:
			for ut: String in b.def["train"]:
				var ud: Dictionary = Defs.UNITS[ut]
				var okage := p.age >= int(ud["age"])
				_slot(n, _short_name(ut), g.art.unit_icon(ut, g.human % 4), "", ud["cost"], res, okage, (func() -> void: g.ui_train(ut)), false, -1.0, "" if okage else Lang.t("needs_feudal"))
				n += 1
			if b.type == "centro":
				if p.aging:
					_slot(n, Lang.t("aging"), null, "age", {}, res, true, (func() -> void: pass), true, 1.0 - p.age_left / float(Defs.AGES[p.age + 1]["time"]), "%ds" % int(ceil(p.age_left)))
					n += 1
				elif p.age < Defs.AGES.size() - 1:
					_slot(n, Lang.t("age_up"), null, "age", Defs.AGES[p.age + 1]["cost"], res, true, (func() -> void: g.ui_age_up()))
					n += 1
			_slot(n, Lang.t("rally"), null, "flag", {}, res, true, (func() -> void: g.ui_toggle_rally()), g.rally_mode)
			n += 1
		_slot(n, Lang.t("delete") if Time.get_ticks_msec() / 1000.0 - _del_confirm > 3.0 else Lang.t("confirm"), null, "trash", {}, res, true, _delete_pressed)
		return n + 1
	if not units.is_empty():
		var has_v := false
		var has_m := false
		var has_cargo := false
		var has_scout := false
		var all_exploring := true
		for u in units:
			if u.type == "aldeano":
				has_v = true
			elif u.def.get("military", false):
				has_m = true
			if u.naval and not u.cargo.is_empty():
				has_cargo = true
			elif bool(u.def.get("scout", false)):
				has_scout = true
				if not u.explore:
					all_exploring = false
		if has_v and (grid_mode == "build" or grid_mode == "military" or grid_mode == "defense"):
			var idx := 0
			var list: Array = Defs.BUILD_MENU
			if grid_mode == "military":
				list = Defs.MILITARY_MENU
			elif grid_mode == "defense":
				list = Defs.DEFENSE_MENU
			for t: String in list:
				var cost: Dictionary = Defs.FARM_COST if t == "granja" else Defs.BUILDINGS[t]["cost"]
				var okage := t == "granja" or p.age >= int(Defs.BUILDINGS[t]["age"])
				var tex: Texture2D = null
				var kind := ""
				if t == "granja":
					kind = "farm"
				else:
					tex = g.art.building_tex[t][g.human % 4]
				_slot(idx, Lang.t("b_" + t), tex, kind, cost, res, okage, (func() -> void: g.ui_begin_place(t)), false, -1.0, "" if okage else Lang.t("needs_feudal"))
				idx += 1
			if grid_mode == "build":
				_slot(idx, Lang.t("military"), g.art.building_tex["cuartel"][g.human % 4], "", {}, res, true, (func() -> void:
					grid_mode = "military"
					g.sfx("click")
					refresh_now()))
				idx += 1
				_slot(idx, Lang.t("defenses"), g.art.building_tex["muralla"][g.human % 4], "", {}, res, p.age >= 1, (func() -> void:
					grid_mode = "defense"
					g.sfx("click")
					refresh_now()), false, -1.0, "" if p.age >= 1 else Lang.t("needs_feudal"))
			var back_to := "main" if grid_mode == "build" else "build"
			_slot(COLS * 2 - 1, Lang.t("back"), null, "back", {}, res, true, (func() -> void:
				grid_mode = back_to
				refresh_now()))
			return COLS * 2
		if has_v:
			_slot(n, Lang.t("build"), null, "hammer", {}, res, true, (func() -> void:
				grid_mode = "build"
				g.sfx("click")
				refresh_now()))
			n += 1
		if has_cargo:
			_slot(n, Lang.t("unload"), null, "anchor", {}, res, true, (func() -> void: g.ui_unload()))
			n += 1
		if has_scout:
			_slot(n, Lang.t("explore"), null, "explore", {}, res, true, (func() -> void: g.ui_explore()), all_exploring)
			n += 1
		if has_m:
			_slot(n, Lang.t("attack_move"), null, "sword", {}, res, true, (func() -> void: g.ui_toggle_amove()), g.amove_mode)
			n += 1
		_slot(n, Lang.t("stop"), null, "stop", {}, res, true, (func() -> void: g.ui_stop()))
		return n + 1
	return 0

func _delete_pressed() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _del_confirm < 3.0:
		_del_confirm = -10.0
		game.ui_delete()
	else:
		_del_confirm = now
	refresh_now()

# ------------------------------------------------------------------ componentes

class PanelBox extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		draw_style_box(UiButton.box(Color(0.10, 0.085, 0.07, 0.92), Color(0.55, 0.43, 0.22, 0.95), 10, 2), Rect2(Vector2.ZERO, size))

class TopBar extends Control:
	var hud: Hud
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.085, 0.07, 0.9), true)
		draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Color(0.55, 0.43, 0.22, 0.95), 2.0)
		var g := hud.game
		if g == null or g.load_state != 3:
			return
		var p: Player = g.sim.players[g.human]
		var font := get_theme_default_font()
		var x := 10.0
		for k in ["food", "wood", "gold"]:
			UiButton.draw_symbol(self, k, Rect2(x, 10, 36, 36))
			var v := int(p.res[k])
			draw_string(font, Vector2(x + 42, 38), str(v), HORIZONTAL_ALIGNMENT_LEFT, 90, 26, Color(0.98, 0.94, 0.82))
			x += 128.0
		UiButton.draw_symbol(self, "pop", Rect2(x, 10, 36, 36))
		var full := p.pop >= p.pop_cap
		draw_string(font, Vector2(x + 40, 38), "%d/%d" % [p.pop, p.pop_cap], HORIZONTAL_ALIGNMENT_LEFT, 110, 26, Color(1, 0.5, 0.45) if full else Color(0.98, 0.94, 0.82))
		x += 140.0
		var age_txt := Lang.t("age_%d" % p.age)
		if p.aging:
			age_txt = "%s ▸ %ds" % [age_txt, int(ceil(p.age_left))]
		draw_string(font, Vector2(x, 36), age_txt, HORIZONTAL_ALIGNMENT_LEFT, 260, 22, Color(1, 0.9, 0.55))
		var secs := int(g.sim.time)
		var tt := "%d:%02d" % [secs / 60, secs % 60]
		draw_string(font, Vector2(size.x - 64 - 70 - 100, 36), tt, HORIZONTAL_ALIGNMENT_RIGHT, 92, 24, Color(0.85, 0.8, 0.7))

class Toasts extends Control:
	var hud: Hud
	var list: Array = []
	func add(text: String, col: Color) -> void:
		for it in list:
			if it["text"] == text:
				it["t"] = 0.0
				return
		list.append({"text": text, "col": col, "t": 0.0})
		while list.size() > 4:
			list.remove_at(0)
		queue_redraw()
	func has_content() -> bool:
		return not list.is_empty() or hud.game.rally_mode or hud.game.amove_mode or hud.game.select_mode
	func _process(delta: float) -> void:
		var i := 0
		while i < list.size():
			list[i]["t"] = float(list[i]["t"]) + delta
			if float(list[i]["t"]) > 4.2:
				list.remove_at(i)
			else:
				i += 1
	func _draw() -> void:
		var font := get_theme_default_font()
		var y := Hud.TOP_H + 14.0
		var g := hud.game
		var banner := ""
		if g.rally_mode:
			banner = Lang.t("banner_rally")
		elif g.amove_mode:
			banner = Lang.t("banner_amove")
		elif g.select_mode:
			banner = Lang.t("banner_select")
		if banner != "":
			_pill(font, banner, y, Color(0.2, 0.35, 0.55, 0.92), Color.WHITE)
			y += 46.0
		for it in list:
			var a := clampf((4.2 - float(it["t"])) / 0.8, 0.0, 1.0)
			var c: Color = it["col"]
			_pill(font, it["text"], y, Color(0.1, 0.085, 0.07, 0.88 * a), Color(c.r, c.g, c.b, a))
			y += 46.0
	func _pill(font: Font, text: String, y: float, bg: Color, fg: Color) -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 40.0
		var r := Rect2((size.x - w) * 0.5, y, w, 38)
		draw_style_box(UiButton.box(bg, Color(0.55, 0.43, 0.22, bg.a), 19, 1), r)
		draw_string(font, Vector2(r.position.x, y + 27), text, HORIZONTAL_ALIGNMENT_CENTER, w, 22, fg)

class Minimap extends Control:
	var hud: Hud
	var img_tex: ImageTexture
	var _built := false
	var _dragging := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _build() -> void:
		var sim := hud.game.sim
		var img := Image.create(sim.W, sim.H, false, Image.FORMAT_RGB8)
		for y in sim.H:
			for x in sim.W:
				var i := y * sim.W + x
				var c: Color
				match sim.terrain[i]:
					Defs.T_WATER:
						c = Color(0.16, 0.38, 0.62) if sim.dl[i] > 2 else Color(0.28, 0.58, 0.78)
					Defs.T_SAND:
						c = Color(0.85, 0.79, 0.55)
					Defs.T_ROCK:
						c = Color(0.52, 0.50, 0.48)
					_:
						c = Color(0.36, 0.6, 0.3)
				# clima: nieve en el frío extremo y desierto en el calor (como en el mapa)
				if sim.terrain[i] != Defs.T_WATER and sim.heat.size() > i:
					var hv := float(sim.heat[i]) / 255.0
					var snow := 1.0 - smoothstep(0.20, 0.34, hv)
					var desert := smoothstep(0.66, 0.78, hv)
					if sim.terrain[i] == Defs.T_ROCK:
						c = c.lerp(Color(0.92, 0.95, 0.99), maxf(snow * 0.6, 0.0))
					else:
						c = c.lerp(Color(0.80, 0.68, 0.42), desert).lerp(Color(0.88, 0.92, 0.97), snow)
				match sim.rtype[i]:
					Defs.R_TREE:
						c = Color(0.12, 0.38, 0.16)
					Defs.R_GOLD:
						c = Color(1.0, 0.85, 0.15)
					Defs.R_BERRY:
						c = Color(0.85, 0.2, 0.3)
				img.set_pixel(x, y, c)
		img_tex = ImageTexture.create_from_image(img)
		_built = true

	func _to_world(p: Vector2) -> Vector2:
		var sim := hud.game.sim
		return (p / size) * Vector2(sim.W, sim.H) * Defs.TILE

	func _gui_input(ev: InputEvent) -> void:
		if hud.game.load_state != 3:
			return
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_dragging = (ev as InputEventMouseButton).pressed
			if _dragging:
				hud.game.focus_on(_to_world((ev as InputEventMouseButton).position))
			accept_event()
		elif ev is InputEventMouseMotion and _dragging:
			hud.game.focus_on(_to_world((ev as InputEventMouseMotion).position))
			accept_event()

	func _draw() -> void:
		var g := hud.game
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05, 0.95), true)
		if g == null or g.load_state != 3:
			return
		if not _built:
			_build()
		var sim := g.sim
		var r := Rect2(Vector2.ZERO, size)
		draw_texture_rect(img_tex, r, false)
		draw_texture_rect(g.fog.tex, r, false)
		var k := size / (Vector2(sim.W, sim.H) * Defs.TILE)
		for b in sim.buildings:
			if b.alive and g.can_see_building(b):
				var c: Color = Defs.PLAYER_COLORS[b.owner % 4]
				var s := 3.0 + b.size
				draw_rect(Rect2(b.center() * k - Vector2(s, s) * 0.5, Vector2(s, s)), c, true)
				draw_rect(Rect2(b.center() * k - Vector2(s, s) * 0.5, Vector2(s, s)), Color(0, 0, 0, 0.7), false, 1.0)
		for u in sim.units:
			if u.alive and g.can_see_unit(u):
				var c2: Color = Defs.PLAYER_COLORS[u.owner % 4]
				draw_rect(Rect2(u.pos * k - Vector2(1.5, 1.5), Vector2(3, 3)), c2, true)
		var vr := g.view_rect(0.0)
		draw_rect(Rect2(vr.position * k, vr.size * k), Color(1, 1, 1, 0.9), false, 1.5)
		if g.sim.time - g.alarm_time < 6.0 and g.alarm_pos.x >= 0:
			var ph := fmod(Time.get_ticks_msec() / 400.0, 1.0)
			draw_arc(g.alarm_pos * k, 4.0 + 12.0 * ph, 0.0, TAU, 20, Color(1, 0.2, 0.2, 1.0 - ph), 2.5)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.43, 0.22), false, 3.0)

class InfoPanel extends Control:
	var hud: Hud
	var qbtns: Array[UiButton] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func build_queue_buttons() -> void:
		for i in 5:
			var b := UiButton.new()
			b.visible = false
			b.size = Vector2(56, 56)
			var idx := i
			b.action = func() -> void: hud.game.ui_cancel_queue(idx)
			add_child(b)
			qbtns.append(b)

	func layout_queue() -> void:
		for i in qbtns.size():
			qbtns[i].position = Vector2(12 + i * 62, size.y - 62)

	func update_queue() -> void:
		var g := hud.game
		var b := g.sel_building()
		var show := b != null and b.owner == g.human and b.progress >= 1.0
		for i in qbtns.size():
			var q := qbtns[i]
			if show and i < b.queue.size():
				q.visible = true
				q.icon = g.art.unit_icon(b.queue[i], g.human % 4)
				q.progress = (1.0 - b.train_left / maxf(b.train_total, 0.01)) if (i == 0 and b.producing) else -1.0
				q.toggled = i == 0 and b.blocked_pop
				q.queue_redraw()
			else:
				q.visible = false

	func _state_text(u: Ent) -> String:
		match u.state:
			Sim.S_MOVE: return Lang.t("st_move")
			Sim.S_GATHER_GO, Sim.S_GATHER:
				if u.def.get("fisher", false):
					return Lang.t("st_fish")
				return Lang.t("st_gather_" + (u.carry_kind if u.carry_kind != "" else "wood"))
			Sim.S_RETURN: return Lang.t("st_return")
			Sim.S_BUILD_GO, Sim.S_BUILD: return Lang.t("st_build")
			Sim.S_ATTACK_GO, Sim.S_ATTACK: return Lang.t("st_attack")
			Sim.S_BOARD_GO: return Lang.t("st_board")
		return Lang.t("st_idle")

	func _hp_bar(font: Font, x: float, y: float, w: float, e: Ent) -> void:
		var f := clampf(e.hp / e.max_hp, 0.0, 1.0)
		draw_rect(Rect2(x, y, w, 14), Color(0, 0, 0, 0.7), true)
		draw_rect(Rect2(x + 1, y + 1, (w - 2) * f, 12), Color(0.9 - 0.7 * f, 0.25 + 0.65 * f, 0.15), true)
		draw_string(font, Vector2(x, y + 12), "%d / %d" % [int(ceil(e.hp)), int(e.max_hp)], HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color.WHITE)

	func _draw() -> void:
		draw_style_box(UiButton.box(Color(0.10, 0.085, 0.07, 0.92), Color(0.55, 0.43, 0.22, 0.95), 10, 2), Rect2(Vector2.ZERO, size))
		var g := hud.game
		if g == null or g.load_state != 3:
			return
		var list := g.sel_ents()
		if list.is_empty():
			return
		var font := get_theme_default_font()
		if list.size() == 1:
			var e: Ent = list[0]
			var tex: Texture2D = g.art.building_tex[e.type][e.owner % 4] if e.is_building else g.art.unit_icon(e.type, e.owner)
			draw_texture_rect(tex, Rect2(12, 10, 64, 64), false)
			var name_txt := Lang.t(("b_" if e.is_building else "u_") + e.type)
			var oc: Color = Defs.PLAYER_COLORS[e.owner % 4]
			draw_string(font, Vector2(88, 36), name_txt, HORIZONTAL_ALIGNMENT_LEFT, size.x - 100, 28, Color(0.98, 0.94, 0.82))
			var owner_name: String = g.sim.players[e.owner].name
			draw_circle(Vector2(96, 56), 6, oc)
			draw_string(font, Vector2(108, 62), owner_name, HORIZONTAL_ALIGNMENT_LEFT, 150, 18, oc.lightened(0.3))
			_hp_bar(font, 270, 44, minf(size.x - 290, 220), e)
			if e.is_building:
				if e.progress < 1.0:
					draw_string(font, Vector2(88, 94), Lang.t("under_construction", [int(e.progress * 100.0)]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 100, 20, Color(0.7, 0.85, 1.0))
					if e.builders > 0:
						draw_string(font, Vector2(88, 118), Lang.t("builders", [e.builders]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 100, 18, Color(0.85, 0.8, 0.7))
				elif e.owner == g.human:
					if e.queue.size() > 0:
						var line := Lang.t("queue_label")
						if e.blocked_pop:
							line = Lang.t("queue_blocked")
						draw_string(font, Vector2(12, size.y - 68), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 18, Color(1, 0.6, 0.5) if e.blocked_pop else Color(0.85, 0.8, 0.7))
					elif e.def.get("pop", 0) > 0:
						draw_string(font, Vector2(88, 100), Lang.t("gives_pop", [int(e.def["pop"])]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 100, 19, Color(0.85, 0.8, 0.7))
					if e.queue.is_empty() and (e.def["train"] as Array).size() > 0:
						draw_string(font, Vector2(12, size.y - 20), Lang.t("tip_train"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 17, Color(0.7, 0.66, 0.55))
			else:
				draw_string(font, Vector2(88, 96), _state_text(e), HORIZONTAL_ALIGNMENT_LEFT, size.x - 100, 21, Color(0.9, 0.85, 0.7))
				if e.carry_amt >= 1.0 and (e.type == "aldeano" or e.def.get("fisher", false)):
					UiButton.draw_symbol(self, e.carry_kind, Rect2(88, 106, 26, 26))
					draw_string(font, Vector2(120, 126), "%d" % int(e.carry_amt), HORIZONTAL_ALIGNMENT_LEFT, 80, 22, Color(0.95, 0.9, 0.8))
				if int(e.def.get("cargo", 0)) > 0 and e.owner == g.human:
					draw_string(font, Vector2(88, 122), Lang.t("passengers", [e.cargo.size(), int(e.def["cargo"])]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 100, 20, Color(0.7, 0.9, 1.0))
				var ud: Dictionary = e.def
				var stat := Lang.t("unit_stats", [int(ud["atk"] * Defs.AGE_STAT_MULT[g.sim.players[e.owner].age]), (ud["range"] as float), (ud["speed"] as float)])
				if float(ud["atk"]) <= 0.0:
					stat = Lang.t("unit_stats_peace", [(ud["speed"] as float)])
				draw_string(font, Vector2(12, size.y - 14), stat, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 18, Color(0.75, 0.7, 0.58))
		else:
			var counts: Dictionary = {}
			for e: Ent in list:
				counts[e.type] = int(counts.get(e.type, 0)) + 1
			draw_string(font, Vector2(14, 34), Lang.t("n_selected", [list.size()]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 26, Color(0.98, 0.94, 0.82))
			var x := 14.0
			var y := 48.0
			for t in counts:
				var ow: int = (list[0] as Ent).owner
				draw_texture_rect(g.art.unit_icon(t, ow), Rect2(x, y, 52, 52), false)
				draw_string(font, Vector2(x + 54, y + 34), "×%d" % counts[t], HORIZONTAL_ALIGNMENT_LEFT, 70, 26, Color(0.98, 0.94, 0.82))
				x += 150.0
				if x + 140.0 > size.x:
					x = 14.0
					y += 56.0
			draw_string(font, Vector2(14, size.y - 12), Lang.t("tip_multi"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 17, Color(0.7, 0.66, 0.55))

class HelpPanel extends Control:
	## Ayuda con desplazamiento vertical (arrastrar con el dedo o rueda del ratón).
	var hud: Hud
	var close_btn: UiButton
	var body: HelpBody
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		body = HelpBody.new()
		add_child(body)
		close_btn = UiButton.new()
		close_btn.text = Lang.t("close")
		close_btn.font_size = 26
		close_btn.action = func() -> void: visible = false
		add_child(close_btn)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED and visible and body != null:
			body.scroll = 0.0
			body.queue_redraw()
	func panel_rect() -> Rect2:
		return Rect2(Vector2(size.x * 0.5 - 540, 14), Vector2(1080, size.y - 28))
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85), true)
		var font := get_theme_default_font()
		var r := panel_rect()
		draw_style_box(UiButton.box(Color(0.10, 0.085, 0.07, 0.97), Color(0.55, 0.43, 0.22), 14, 3), r)
		draw_string(font, Vector2(r.position.x, r.position.y + 42), Lang.t("help_title"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 32, Color(1, 0.9, 0.55))
		close_btn.size = Vector2(220, 50)
		close_btn.position = Vector2(size.x * 0.5 - 110, r.end.y - 60)
		body.position = Vector2(r.position.x + 12, r.position.y + 58)
		body.size = Vector2(r.size.x - 24, r.size.y - 58 - 70)

class HelpBody extends Control:
	var scroll := 0.0
	var _total := 0.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
	func _gui_input(ev: InputEvent) -> void:
		var max_s := maxf(0.0, _total - size.y)
		if ev is InputEventMouseMotion and ((ev as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			scroll = clampf(scroll - (ev as InputEventMouseMotion).relative.y, 0.0, max_s)
			queue_redraw()
			accept_event()
		elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			var mb := ev as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll = clampf(scroll - 60.0, 0.0, max_s)
				queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll = clampf(scroll + 60.0, 0.0, max_s)
				queue_redraw()
	func _draw() -> void:
		var font := get_theme_default_font()
		var y := -scroll
		var fs := 19
		var bw := size.x - 190.0
		for pair in Lang.a("help_lines"):
			var head := str(pair[0])
			var body_text := str(pair[1])
			var sz := font.get_multiline_string_size(body_text, HORIZONTAL_ALIGNMENT_LEFT, bw, fs)
			draw_string(font, Vector2(12, y + fs), head, HORIZONTAL_ALIGNMENT_LEFT, 150, fs, Color(1, 0.88, 0.5))
			draw_multiline_string(font, Vector2(168, y + fs), body_text, HORIZONTAL_ALIGNMENT_LEFT, bw, fs, -1, Color(0.93, 0.9, 0.8))
			y += maxf(sz.y, float(fs) * 1.3) + 10.0
		_total = y + scroll
		# indicador de que hay más contenido
		if _total > size.y + 1.0:
			var frac := size.y / _total
			var bar_h := maxf(36.0, size.y * frac)
			var bar_y := (size.y - bar_h) * (scroll / maxf(_total - size.y, 1.0))
			draw_rect(Rect2(size.x - 6, bar_y, 4, bar_h), Color(0.8, 0.65, 0.35, 0.7), true)

class EndPanel extends Control:
	var hud: Hud
	var won := false
	var btn: UiButton
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		btn = UiButton.new()
		btn.text = Lang.t("back_to_menu")
		btn.font_size = 26
		add_child(btn)
	func setup() -> void:
		var g := hud.game
		won = g.sim.human_index >= 0 and g.sim.players[g.human].alive and g.sim.winner_team == g.sim.players[g.human].team
		btn.action = func() -> void: g.ui_exit()
		g.sfx("victory" if won else "defeat")
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7), true)
		var g := hud.game
		if g == null or g.load_state != 3:
			return
		var font := get_theme_default_font()
		var r := Rect2(Vector2(size.x * 0.5 - 300, size.y * 0.5 - 230), Vector2(600, 460))
		draw_style_box(UiButton.box(Color(0.10, 0.085, 0.07, 0.97), Color(0.55, 0.43, 0.22), 14, 3), r)
		var title := Lang.t("victory") if won else Lang.t("defeat")
		draw_string(font, Vector2(r.position.x, r.position.y + 78), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 56, Color(1, 0.9, 0.4) if won else Color(1, 0.5, 0.45))
		var p: Player = g.sim.players[g.human]
		var secs := int(g.sim.time)
		var lines := [
			Lang.t("end_time", ["%d:%02d" % [secs / 60, secs % 60]]),
			Lang.t("end_kills", [p.kills]),
			Lang.t("end_losses", [p.losses]),
			Lang.t("end_gathered", [int(p.gathered["food"]), int(p.gathered["wood"]), int(p.gathered["gold"])]),
		]
		var y := r.position.y + 150.0
		for l in lines:
			draw_string(font, Vector2(r.position.x, y), l, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26, Color(0.93, 0.9, 0.8))
			y += 48.0
		btn.size = Vector2(300, 66)
		btn.position = Vector2(size.x * 0.5 - 150, r.end.y - 90)

class LoadPanel extends Control:
	var hud: Hud
	var msg := ""
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.12, 0.2, 1.0), true)
		var font := get_theme_default_font()
		var c := size * 0.5
		draw_string(font, Vector2(0, c.y - 40), Lang.t("title"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 64, Color(1, 0.9, 0.55))
		draw_string(font, Vector2(0, c.y + 30), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(0.85, 0.9, 1.0))
		var ph := Time.get_ticks_msec() / 1000.0 * 4.0
		for i in 8:
			var a := fmod(ph - i * 0.5, 8.0)
			draw_circle(c + Vector2(0, 100) + Vector2(1, 0).rotated(i * TAU / 8.0) * 26.0, 5.0, Color(1, 1, 1, clampf(1.0 - a / 8.0, 0.1, 1.0)))
