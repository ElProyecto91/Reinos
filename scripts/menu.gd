class_name MenuScreen
extends CanvasLayer
## Menú principal: rivales, tamaño de mapa, dificultad, equipos y semilla.

signal play_pressed(cfg: Dictionary)
signal quit_pressed
signal continue_pressed

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
var _upd: Updater
var _upd_btn: UiButton
var _help: Control
var _civ_btn: UiButton
var _civ_panel: Control
var _seg: Dictionary = {}
var _t := 0.0
var _continue: UiButton
var _has_save := false
var _new_confirm := -10.0
var notice := ""

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
	_add_civ_row()
	_add_segment("size", Lang.t("menu_size"), [[Lang.t("size_128"), 128], [Lang.t("size_192"), 192], [Lang.t("size_256"), 256]], func() -> int: return map_size, func(v: int) -> void: map_size = v)
	_add_segment("diff", Lang.t("menu_diff"), [[Lang.t("diff_0"), 0], [Lang.t("diff_1"), 1], [Lang.t("diff_2"), 2]], func() -> int: return diff, func(v: int) -> void: diff = v)
	_add_segment("teams", Lang.t("menu_teams"), [[Lang.t("teams_allied"), 1], [Lang.t("teams_ffa"), 0]], func() -> int: return 1 if allied else 0, func(v: int) -> void: allied = v == 1)
	_add_segment("perf", Lang.t("menu_perf"), [[Lang.t("perf_ahorro"), 0], [Lang.t("perf_equilibrado"), 1], [Lang.t("perf_alta"), 2]], func() -> int: return Settings.profile, func(v: int) -> void: Settings.set_profile(v, get_window()))
	_add_segment("upd", Lang.t("menu_updates"), [[Lang.t("opt_yes"), 1], [Lang.t("opt_no"), 0]], func() -> int: return 1 if Settings.check_updates else 0, func(v: int) -> void:
		Settings.check_updates = v == 1
		Settings.save())
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
	_continue = UiButton.new()
	_continue.font_size = 32
	_continue.accent = Color(1.0, 0.85, 0.45)
	_continue.action = func() -> void: continue_pressed.emit()
	root.add_child(_continue)
	var meta := SaveGame.meta()
	_has_save = not meta.is_empty()
	_continue.visible = _has_save
	if _has_save:
		_play.text = Lang.t("menu_new")
		_continue.text = Lang.t("menu_continue")
		var secs := int(float(meta.get("time", 0.0)))
		_continue.sub = Lang.t("save_info", ["%d:%02d" % [secs / 60, secs % 60], int(meta.get("size", 0)), int(meta.get("rivals", 0)), Lang.t("rival_one" if int(meta.get("rivals", 0)) == 1 else "rival_many")])
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
	_upd_btn = UiButton.new()
	_upd_btn.font_size = 19
	_upd_btn.sub_size = 16
	_upd_btn.visible = false
	_upd_btn.action = func() -> void: _upd.activate()
	root.add_child(_upd_btn)
	_help = Hud.HelpPanel.new()
	_help.visible = false
	root.add_child(_help)
	_civ_panel = CivPanel.new()
	(_civ_panel as CivPanel).menu = self
	_civ_panel.visible = false
	root.add_child(_civ_panel)
	_upd = Updater.new()
	add_child(_upd)
	_upd.state_changed.connect(_refresh_upd)
	_upd.check()
	_refresh_upd()
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

## Fila «Civilización»: un botón ancho con la elegida; al tocarlo se abre el selector con las ocho.
func _add_civ_row() -> void:
	_civ_btn = UiButton.new()
	_civ_btn.font_size = 24
	_civ_btn.accent = Color(1.0, 0.85, 0.45)
	_civ_btn.action = func() -> void:
		(_civ_panel as CivPanel).open()
	root.add_child(_civ_btn)
	_seg["civ"] = {"label": Lang.t("menu_civ"), "btns": [_civ_btn], "opts": [["", 0]], "get": func() -> int: return 0}
	_rows.append("civ")

func choose_civ(id: String) -> void:
	Settings.civ = id
	Settings.save()
	_refresh()

func _civ_name() -> String:
	return Lang.t("civ_random") if Settings.civ == "random" else Lang.t("civ_" + Settings.civ)

func _layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var w := 760.0
	var x := (vs.x - w) * 0.5
	var y := 154.0
	var rh := 44.0      # alto de botón
	var pitch := 50.0   # separación entre filas
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
	if _has_save:
		_continue.size = Vector2(w * 0.5 - 6, 70)
		_continue.position = Vector2(x, y + 54)
		_play.size = Vector2(w * 0.5 - 6, 70)
		_play.position = Vector2(x + w * 0.5 + 6, y + 54)
	else:
		_play.size = Vector2(w, 70)
		_play.position = Vector2(x, y + 54)
	_help_btn.size = Vector2(w * 0.5 - 6, 50)
	_help_btn.position = Vector2(x, y + 132)
	_quit.size = Vector2(w * 0.5 - 6, 50)
	_quit.position = Vector2(x + w * 0.5 + 6, y + 132)
	_civ_panel.position = Vector2.ZERO
	_civ_panel.size = vs
	_upd_btn.size = Vector2(330, 62)
	_upd_btn.position = Vector2(vs.x - 342, 8)
	_help.position = Vector2.ZERO
	_help.size = vs
	root.queue_redraw()

## El botón de arriba a la derecha sigue al actualizador: «Buscar actualizaciones» (siempre, salvo en compilaciones locales sin build),
## el aviso de versión nueva, permiso, barra de descarga, instalación... y el resultado de cada comprobación.
func _refresh_upd() -> void:
	var st := _upd.state
	_upd_btn.visible = st != Updater.IDLE or Updater.current_build() > 0
	_upd_btn.text = _upd.label()
	var sub := _upd.sub_text()
	_upd_btn.sub = sub if sub.length() <= 44 else sub.left(43) + "…"
	_upd_btn.progress = _upd.progress if st == Updater.DOWNLOADING else -1.0
	var gold := Color(0.82, 0.64, 0.25)
	if st == Updater.DONE or st == Updater.UPTODATE:
		_upd_btn.accent = Color(0.5, 0.95, 0.5)
	elif st == Updater.CHECK_FAIL:
		_upd_btn.accent = Color(0.95, 0.5, 0.4)
	else:
		_upd_btn.accent = gold
	_upd_btn.toggled = st != Updater.IDLE and st != Updater.CHECKING   # en reposo y buscando, discreto; el color (borde y fondo) es de los avisos y resultados
	_upd_btn.queue_redraw()

func _refresh() -> void:
	_civ_btn.text = "%s  ▸" % _civ_name()
	_civ_btn.queue_redraw()
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

func _process(_d: float) -> void:
	if _has_save and _new_confirm > 0.0 and Time.get_ticks_msec() / 1000.0 - _new_confirm > 4.0:
		_new_confirm = -10.0
		_play.text = Lang.t("menu_new")
		_play.queue_redraw()

func _on_play() -> void:
	if _has_save:
		# empezar de nuevo sustituye la partida guardada: pide confirmación (dos toques)
		var now := Time.get_ticks_msec() / 1000.0
		if now - _new_confirm > 4.0:
			_new_confirm = now
			_play.text = Lang.t("menu_new_confirm")
			_play.queue_redraw()
			return
	var plist: Array = [{"human": true, "team": 0, "diff": 1, "name": Lang.t("player_name"), "civ": Settings.civ}]
	for i in rivals:
		plist.append({"human": false, "team": 1 if allied else i + 1, "diff": diff, "name": Defs.PLAYER_COLOR_NAMES[i + 1], "civ": "random"})
	play_pressed.emit({"size": map_size, "seed": seed_val, "players": plist, "events": true})

class MenuBg extends Control:
	var menu: MenuScreen
	var _logo: Texture2D
	var _bg: Texture2D
	func _ready() -> void:
		if ResourceLoader.exists("res://art/logo/logotipo_menu.png"):
			_logo = load("res://art/logo/logotipo_menu.png")
		# Un reino al atardecer pintado por tools/menu_bg/make_bg.py (2,4:1). Sin ella, un degradado liso.
		if ResourceLoader.exists("res://art/menu/fondo.png"):
			_bg = load("res://art/menu/fondo.png")
	func _draw() -> void:
		if _bg != null:
			# «cover»: llena la pantalla sin deformar y recorta lo que sobre (a los lados en pantallas más cuadradas)
			var sc := maxf(size.x / float(_bg.get_width()), size.y / float(_bg.get_height()))
			var dw := float(_bg.get_width()) * sc
			var dh := float(_bg.get_height()) * sc
			draw_texture_rect(_bg, Rect2((size.x - dw) * 0.5, (size.y - dh) * 0.5, dw, dh), false)
		else:
			var top := Color(0.05, 0.07, 0.20)
			var bot := Color(0.55, 0.30, 0.35)
			var pts := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
			draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		if menu != null and menu._seg.has("seed_y"):
			# cristal oscuro tras los ajustes: se lee igual sobre el resplandor del sol que sobre el cielo
			var pw := 760.0 + 44.0
			var py := 146.0
			draw_style_box(UiButton.box(Color(0.02, 0.035, 0.085, 0.60), Color(0.55, 0.43, 0.22, 0.55), 16, 2),
				Rect2((size.x - pw) * 0.5, py, pw, float(menu._seg["seed_y"]) + 198.0 - py))
		var font := get_theme_default_font()
		if _logo != null:
			# logotipo (emblema + REINOS + lema), dibujado a 2x: 620 x 140 lógicos, centrado, sobre las filas de ajustes (y = 154)
			var lw := 620.0
			var lh := lw * float(_logo.get_height()) / float(_logo.get_width())
			draw_texture_rect(_logo, Rect2((size.x - lw) * 0.5, 8.0, lw, lh), false)
		else:
			draw_string(font, Vector2(3, 103), Lang.t("title"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 86, Color(0, 0, 0, 0.5))
			draw_string(font, Vector2(0, 100), Lang.t("title"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 86, Color(1, 0.9, 0.5))
			draw_string(font, Vector2(0, 140), Lang.t("subtitle"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.85, 0.92, 1.0))
		draw_string(font, Vector2(14, size.y - 12), Settings.build_label(), HORIZONTAL_ALIGNMENT_LEFT, size.x, 18, Color(1, 1, 1, 0.55))
		if menu != null and menu.notice != "":
			draw_string(font, Vector2(0, size.y - 14), menu.notice, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(1, 0.62, 0.52))
		if menu != null:
			var w := 760.0
			var x := (size.x - w) * 0.5
			for key in menu._rows:
				var d: Dictionary = menu._seg[key]
				draw_string(font, Vector2(x, float(d["y"]) + 38), d["label"], HORIZONTAL_ALIGNMENT_LEFT, w * 0.38, 26, Color(0.95, 0.92, 0.82))
			if menu._seg.has("seed_y"):
				draw_string(font, Vector2(x, float(menu._seg["seed_y"]) + 36), "", HORIZONTAL_ALIGNMENT_LEFT, w * 0.38, 24, Color(0.9, 0.9, 0.8))

## Colores con los que se rotula cada civilización.
const CIV_COL := {
	"castellanos": Color(0.96, 0.78, 0.28), "francos": Color(0.52, 0.68, 1.0), "ingleses": Color(0.95, 0.45, 0.42),
	"teutones": Color(0.88, 0.88, 0.94), "vikingos": Color(0.62, 0.84, 0.98), "bizantinos": Color(0.78, 0.55, 0.92),
	"sarracenos": Color(0.45, 0.88, 0.62), "mongoles": Color(0.96, 0.64, 0.32),
}

## Selector de civilización: ocho fichas con bonificaciones, unidad única y habilidad, y «Aleatoria».
const CARD_H := 262.0
const CARD_Y0 := 52.0

class CivPanel extends Control:
	var menu: MenuScreen
	var cards: Array[CivCard] = []
	var rnd: UiButton
	var close: UiButton

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		for id: String in Civs.IDS:
			var c := CivCard.new()
			c.civ = id
			c.on_pick = func() -> void: _pick(id)
			add_child(c)
			cards.append(c)
		rnd = UiButton.new()
		rnd.text = Lang.t("civ_random")
		rnd.font_size = 24
		rnd.action = func() -> void: _pick("random")
		add_child(rnd)
		close = UiButton.new()
		close.text = Lang.t("civ_close")
		close.font_size = 24
		close.action = func() -> void: visible = false
		add_child(close)
		resized.connect(_layout)
		_layout()

	func open() -> void:
		visible = true
		_layout()
		for c in cards:
			c.selected = c.civ == Settings.civ
			c.queue_redraw()
		rnd.toggled = Settings.civ == "random"
		rnd.queue_redraw()

	func _pick(id: String) -> void:
		menu.choose_civ(id)
		visible = false

	func _layout() -> void:
		var margin := 24.0
		var gap := 12.0
		var cw := minf(330.0, (size.x - margin * 2.0 - gap * 3.0) / 4.0)
		var ch := CARD_H
		var total := cw * 4.0 + gap * 3.0
		var x0 := (size.x - total) * 0.5
		var y0 := CARD_Y0
		for i in cards.size():
			var c := cards[i]
			c.size = Vector2(cw, ch)
			c.position = Vector2(x0 + (i % 4) * (cw + gap), y0 + (i / 4) * (ch + gap))
		var by := y0 + 2.0 * ch + gap + 10.0
		rnd.size = Vector2(total * 0.5 - 6.0, 48.0)
		rnd.position = Vector2(x0, by)
		close.size = Vector2(total * 0.5 - 6.0, 48.0)
		close.position = Vector2(x0 + total * 0.5 + 6.0, by)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.06, 0.10, 0.94), true)
		var font := get_theme_default_font()
		draw_string(font, Vector2(0, 38), Lang.t("civ_pick_title"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Color(1, 0.9, 0.5))
		var by := CARD_Y0 + 2.0 * CARD_H + 12.0 + 10.0 + 48.0
		draw_multiline_string(font, Vector2(0, by + 22.0), Lang.t("civ_pick_note"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 2, Color(0.8, 0.72, 0.72))

class CivCard extends Control:
	var civ := ""
	var selected := false
	var on_pick: Callable
	var _down := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := ev as InputEventMouseButton
			if mb.pressed:
				_down = true
				queue_redraw()
			else:
				var inside := Rect2(Vector2.ZERO, size).grow(6.0).has_point(mb.position)
				var fire := _down and inside
				_down = false
				queue_redraw()
				if fire and on_pick.is_valid():
					on_pick.call()
			accept_event()

	func _draw() -> void:
		var col: Color = MenuScreen.CIV_COL.get(civ, Color.WHITE)
		var bg := Color(0.30, 0.24, 0.15, 0.96) if _down else (Color(0.20, 0.16, 0.09, 0.96) if selected else Color(0.12, 0.10, 0.08, 0.95))
		var border := Color(1.0, 0.85, 0.45, 1.0) if selected else Color(0.55, 0.43, 0.22, 0.95)
		draw_style_box(UiButton.box(bg, border, 10, 3 if selected else 2), Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(10, 40, size.x - 20, 3), Color(col.r, col.g, col.b, 0.8), true)
		var font := get_theme_default_font()
		var w := size.x - 24.0
		draw_string(font, Vector2(12, 33), Lang.t("civ_" + civ), HORIZONTAL_ALIGNMENT_LEFT, w, 26, col)
		var fg := Color(0.92, 0.88, 0.78)
		var fs := 14
		var y := 62.0
		# cada párrafo ocupa lo que mide (los textos tienen largos distintos): sin solaparse ni salirse de la tarjeta
		var blocks := [
			[Lang.t("civ_%s_pas" % civ), fg],
			["%s: %s" % [Lang.t("civ_unique_label"), Lang.t("civ_%s_uni" % civ)], Color(0.75, 0.9, 1.0)],
			["%s: %s. %s" % [Lang.t("civ_ability_label"), Lang.t("abil_" + civ), Lang.t("abil_%s_desc" % civ)], Color(1.0, 0.86, 0.55)]]
		for blk in blocks:
			var txt: String = blk[0]
			var h := font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
			draw_multiline_string(font, Vector2(12, y), txt, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, blk[1])
			y += h + 5.0
