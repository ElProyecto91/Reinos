class_name WorldLayer
extends Node2D
## Capa de dibujo del mundo: 0 = terreno, 1 = entidades y efectos, 2 = niebla.

var game: Node
var mode: int = 0
static var prof_us: int = 0
static var prof_n: int = 0

func _draw() -> void:
	if game == null:
		return
	match mode:
		0:
			Renderer.draw_terrain(game, self)
		1:
			var t0 := Time.get_ticks_usec()
			Renderer.draw_entities(game, self)
			prof_us += Time.get_ticks_usec() - t0
			prof_n += 1
		2:
			Renderer.draw_fog(game, self)
