class_name Iso
extends RefCounted
## Proyección isométrica 2:1 (como Age of Empires): el mundo lógico sigue siendo el mismo (píxeles, 32 por casilla) y sólo se proyecta
## a pantalla al dibujar. Una casilla es un rombo de 64×32 px con zoom 1. La matriz es de determinante 1 (conserva el área).
##   proj(p)   = (p.x − p.y, (p.x + p.y) / 2)           mundo lógico → plano isométrico
##   unproj(s) = (s.x / 2 + s.y, s.y − s.x / 2)         plano isométrico → mundo lógico
## `Game.cam_pos` vive en el plano isométrico (así arrastrar con el dedo sigue siendo `cam_pos -= relative / zoom`).

const XF := Transform2D(Vector2(1.0, 0.5), Vector2(-1.0, 0.5), Vector2.ZERO)   # transformación de las capas del suelo (se dibujan en coordenadas lógicas)

## 8 vecinos de una casilla en el orden de los brazos de muralla (N, NE, E, SE, S, SW, W, NW; x e y lógicos)
const DIRS8: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]

static func proj(p: Vector2) -> Vector2:
	return Vector2(p.x - p.y, (p.x + p.y) * 0.5)

static func unproj(s: Vector2) -> Vector2:
	return Vector2(s.x * 0.5 + s.y, s.y - s.x * 0.5)

## Rombo de una casilla (esquinas en el plano isométrico), con su centro en c (plano isométrico).
static func diamond(c: Vector2, half_w: float, half_h: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -half_h), c + Vector2(half_w, 0), c + Vector2(0, half_h), c + Vector2(-half_w, 0)])
