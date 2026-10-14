extends Node
## Captura la ayuda y comprueba que se desplaza arrastrando con el dedo.
func touch(pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = pos
	t.pressed = pressed
	Input.parse_input_event(t)
func _ready() -> void:
	var m := MenuScreen.new()
	add_child(m)
	await get_tree().create_timer(0.5).timeout
	m._help.visible = true
	await get_tree().create_timer(0.5).timeout
	var body: Hud.HelpBody = m._help.body
	var s0 := body.scroll
	touch(Vector2(640, 500), true)
	await get_tree().process_frame
	for i in 10:
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = Vector2(640, 500 - 40 * (i + 1))
		d.relative = Vector2(0, -40)
		Input.parse_input_event(d)
		await get_tree().process_frame
	touch(Vector2(640, 100), false)
	await get_tree().create_timer(0.3).timeout
	print("scroll ", s0, " -> ", body.scroll, " total ", body._total, " size ", body.size)
	print("PASS help scrolls" if body.scroll > 100.0 else "FAIL help scrolls")
	get_viewport().get_texture().get_image().save_png("/tmp/help_shot.png")
	get_tree().quit()
