extends Node
## Desfile de sprites: cada tipo de unidad en sus 8 direcciones (las tres de espejo incluidas), en reposo o en un fotograma
## concreto. Sirve para revisar orientaciones, escala y animaciones sin montar una partida.
## Uso: xvfb-run -a godot --path . res://tools/iso_parade.tscn --rendering-driver opengl3 --resolution 1300x1100 -- out=/tmp/p.png types=aldeano,piquero frame=0 zoom=1.6 team=0
##   frame = índice de fotograma de IsoView (0 reposo, 1..4 marcha, 5.. acción)
var out := "/tmp/parade.png"
var types: PackedStringArray = []
var frame := 0
var zoom_v := 1.6
var team := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
		elif a.begins_with("types="): types = a.substr(6).split(",")
		elif a.begins_with("frame="): frame = int(a.substr(6))
		elif a.begins_with("zoom="): zoom_v = float(a.substr(5))
		elif a.begins_with("team="): team = int(a.substr(5))
	if types.is_empty():
		types = PackedStringArray(Defs.UNITS.keys())
	var art := Art.new()
	art.build()
	var ia := art.iso
	var bg := ColorRect.new()
	bg.color = Color(0.36, 0.50, 0.28)
	bg.size = Vector2(4000, 4000)
	add_child(bg)
	var world := Node2D.new()
	world.scale = Vector2.ONE * zoom_v
	add_child(world)
	var row := 0
	for t in types:
		for d in 8:
			var m: Array = IsoView.MIRROR[d]
			var nm := IsoView._frame_name(t, int(m[0]), frame)
			if not ia.has(nm):
				nm = IsoView._frame_name(t, int(m[0]), 0)
			if not ia.has(nm):
				continue
			var p := Vector2(60 + d * 90, 130 + row * 150)
			var sh := Sprite2D.new()
			sh.texture = art.shadow_tex
			sh.position = p + Vector2(0, -2)
			sh.scale = Vector2(1.2, 0.5)
			world.add_child(sh)
			var sp := ia.make_sprite(nm, p, 1.0, bool(m[1]))
			sp.modulate = art.team_mod[team % 4]
			world.add_child(sp)
			if d == 0:
				var lb := Label.new()
				lb.text = t
				lb.position = Vector2(2, p.y - 120) * zoom_v
				lb.add_theme_font_size_override("font_size", 14)
				add_child(lb)
		row += 1
	await get_tree().create_timer(0.5).timeout
	for i in 3:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(out)
	print("SHOT ", out)
	get_tree().quit()
