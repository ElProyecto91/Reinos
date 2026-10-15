extends Node
## Elegir civilización con toques reales en el menú (1280×720 y, con --resolution 2400x1080, el tamaño de un móvil):
## abrir el selector, tocar una ficha, comprobar que se guarda y que «Jugar» arranca la partida con esa civilización.
var fails := 0
var cfg_out: Dictionary = {}

func check(name: String, ok: bool, extra: String = "") -> void:
	print(("PASS " if ok else "FAIL ") + name + (("  " + extra) if extra != "" else ""))
	if not ok:
		fails += 1

func touch(pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = pos
	t.pressed = pressed
	Input.parse_input_event(t)

func to_window(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p

func tap_control(c: Control) -> void:
	var p := to_window(c.get_global_rect().get_center())
	touch(p, true)
	await get_tree().process_frame
	touch(p, false)
	await get_tree().process_frame
	await get_tree().process_frame

func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _ready() -> void:
	Settings.ensure_loaded()
	var prof := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("perfil="):
			prof = int(a.substr(7))
	Settings.profile = prof
	Settings.civ = "random"
	Settings.apply_display(get_window())
	_run()

func _run() -> void:
	var m := MenuScreen.new()
	add_child(m)
	m.play_pressed.connect(func(c: Dictionary) -> void: cfg_out = c)
	await frames(6)
	print("INFO viewport ", get_viewport().get_visible_rect().size, " ventana ", get_window().size)
	var vr := get_viewport().get_visible_rect()
	check("el botón de civilización está dentro de la pantalla", vr.encloses(m._civ_btn.get_global_rect()), str(m._civ_btn.get_global_rect()))
	check("y es visible", m._civ_btn.is_visible_in_tree())
	await tap_control(m._civ_btn)
	check("tocar «Civilización» abre el selector", m._civ_panel.visible)
	var cards: Array = (m._civ_panel as MenuScreen.CivPanel).cards
	var card: Control = cards[7]      # mongoles
	check("la ficha está dentro de la pantalla", vr.encloses(card.get_global_rect()), str(card.get_global_rect()))
	await tap_control(card)
	check("tocar una ficha la elige", Settings.civ == "mongoles", Settings.civ)
	check("y cierra el selector", not m._civ_panel.visible)
	check("el botón muestra la elegida", m._civ_btn.text.begins_with(Lang.t("civ_mongoles")), m._civ_btn.text)
	# «Aleatoria»
	await tap_control(m._civ_btn)
	var rnd: Control = (m._civ_panel as MenuScreen.CivPanel).rnd
	check("el botón Aleatoria está en pantalla", vr.encloses(rnd.get_global_rect()), str(rnd.get_global_rect()))
	await tap_control(rnd)
	check("Aleatoria se guarda", Settings.civ == "random", Settings.civ)
	await tap_control(m._civ_btn)
	await tap_control(cards[3])
	check("elegir los teutones", Settings.civ == "teutones", Settings.civ)
	await tap_control(m._play)
	check("Jugar arranca con la civilización elegida", cfg_out.has("players") and String(cfg_out["players"][0].get("civ", "")) == "teutones", str(cfg_out))
	print("DONE fails=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
