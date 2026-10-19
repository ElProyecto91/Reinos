class_name WorldLayer
extends Node2D
## Capa de dibujo del mundo: 0 = terreno, 1 = efectos y barras (sobre los sprites), 2 = niebla, 3 = sombras de nubes, 4 = marcas del suelo.

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
			Renderer.draw_overlay(game, self)
			prof_us += Time.get_ticks_usec() - t0
			prof_n += 1
		2:
			Renderer.draw_fog(game, self)
		3:
			Renderer.draw_terrain(game, self)   # un rectángulo: el color lo pone el shader de nubes
		4:
			Renderer.draw_decals(game, self)
