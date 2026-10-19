extends RefCounted
## PLANTILLA para una civilización nueva. Copiar a tools/iso/civ/<id>.gd (el <id> es el de `Civs.IDS`), cambiar la paleta y la forma
## de cada edificio, y hornear con `tools/iso/civ_build.sh <id>`. Ver «Cómo añadir una civilización» en el README.
##
## Contrato (lo que IsoCivs y el juego esperan; no cambiar los nombres):
##   build(tipo, equipo)  -> Node3D   (ya está: llama a la función con el nombre del tipo)
##   casa, centro, almacen, cuartel, arqueria, establo, taller, puerto, torre, monasterio, castillo, herreria, mercado(equipo) -> Node3D
##   wall_post(), wall_arm(d: int 0..7), gate(along_x: bool) -> Node3D       (murallas y puerta de la civilización)
## Reglas del horneado (iso_bake.gd):
##   · la cámara ve las caras +z (abajo a la izquierda) y +x (abajo a la derecha); el sol viene de arriba a la izquierda;
##   · la huella de un edificio de N casillas mide N unidades (centrada en el origen): casa/almacén/torre 2, el resto 3, castillo 4;
##   · el color del jugador es CUALQUIER material liso con r = g = b (M.fmat(team) o M.TEAM_BASE): nunca uses grises neutros en otro sitio;
##   · el modelo mira a +z (la puerta va en la cara +z); el puerto se gira solo para las 4 orientaciones;
##   · para que una chimenea o abertura eche humo en el juego: A.chimney(...) lo hace sola, o A.smoke_src(root, posición) a mano;
##   · tools/iso/civ_check.gd comprueba que todos los edificios se construyen y caben en su huella.

const A = preload("res://tools/iso/iso_arch.gd")
const M = preload("res://tools/iso/iso_models.gd")
const B = preload("res://tools/iso/iso_build.gd")

func build(type: String, team: Color) -> Node3D:
	return call(type, team) as Node3D

## Paleta de la civilización: 3-6 materiales con carácter (pared, tejado, madera, detalle). `seed_v` varía la textura entre edificios.
## Tipos de textura de A.mat: stone, plaster, wood, roof, brick, barrel, thatch, turf, felt, planks, marble, tiles.
func pal(seed_v: int) -> Dictionary:
	var S := A.plain()
	S["wall"] = A.mat("plaster", seed_v + 1, Color(0.80, 0.72, 0.58), 1.0)
	S["wall_d"] = A.mat("stone", seed_v + 2, Color(0.48, 0.44, 0.38), 1.2)
	S["roof"] = A.mat("roof", seed_v + 3, Color(0.62, 0.30, 0.20), 1.5)
	S["roof_d"] = A.mat("roof", seed_v + 4, Color(0.44, 0.21, 0.14), 1.5)
	# nombres que esperan los patios comunes del kit (corral, muelle, fragua, tiro con arco, desfile)
	S["wood"] = A.mat("wood", seed_v + 5, Color(0.36, 0.24, 0.14), 1.4)
	S["wood_l"] = A.mat("wood", seed_v + 6, Color(0.58, 0.42, 0.24), 1.5)
	S["plaster"] = S["wall"]
	S["stone"] = S["wall_d"]
	S["stone_d"] = S["wall_d"]
	# fortificación (castillo, torre, murallas): muro, sombra, luz, ribete, madera, tipo de textura
	S["F"] = A.fort(seed_v + 20, Color(0.70, 0.66, 0.58), Color(0.48, 0.45, 0.40), Color(0.82, 0.78, 0.70), Color(0.62, 0.30, 0.20), Color(0.36, 0.24, 0.14), "stone")
	return S

func _tm(team: Color) -> StandardMaterial3D:
	return M.fmat(team, 0.85, 0.2)

## Edificio de una planta con tejado a dos aguas: base (w × d), muros de altura wh, puerta en +z y bandera del jugador.
func _hall(S: Dictionary, team: Color, w: float, d: float, wh: float, rise: float, chimney: bool = false) -> Node3D:
	var root := Node3D.new()
	M.box(root, Vector3(w + 0.10, 0.12, d + 0.10), Vector3(0, 0.06, 0), S.wall_d)
	M.box(root, Vector3(w, wh, d), Vector3(0, 0.12 + wh * 0.5, 0), S.wall)
	B.roof_x(root, w + 0.22, d + 0.20, rise, 0.12 + wh, S.roof)
	A.arch_hole(root, Vector3(0.0, 0.12, d * 0.5 + 0.005), 0.36, 0.52, false, S.wood, S.wall_d, "round")
	if chimney:
		A.chimney(root, Vector3(-w * 0.28, 0.12 + wh, -d * 0.2), 0.20, 0.55, S.wall, S.wall_d)
	M._flag(root, Vector3(-w * 0.5 + 0.12, 0.0, d * 0.5 + 0.12), team, 0.95)
	return root

func casa(team: Color) -> Node3D:
	return _hall(pal(11), team, 1.40, 1.30, 0.70, 0.45, true)

func almacen(team: Color) -> Node3D:
	return _hall(pal(101), team, 1.50, 1.40, 0.62, 0.40)

func centro(team: Color) -> Node3D:
	var S := pal(201)
	var root := _hall(S, team, 2.30, 1.90, 1.10, 0.80, true)
	A.tower_sq(root, Vector3(-1.0, 0, -0.9), 0.7, 1.9, S.F)
	return root

func cuartel(team: Color) -> Node3D:
	var S := pal(301)
	var root := _hall(S, team, 2.30, 1.70, 0.90, 0.60)
	A.shield(root, Vector3(0.7, 0.55, 0.88), 0.16, false, S.wood, _tm(team))
	A.drill_yard(root, S)
	return root

func arqueria(team: Color) -> Node3D:
	var S := pal(401)
	var root := _hall(S, team, 2.10, 1.40, 0.75, 0.50)
	A.archery_field(root, S, _tm(team))
	return root

func establo(team: Color) -> Node3D:
	var S := pal(501)
	var root := _hall(S, team, 2.30, 1.50, 0.75, 0.55)
	A.corral(root, S)
	return root

func taller(team: Color) -> Node3D:
	var S := pal(601)
	var root := _hall(S, team, 2.30, 1.60, 0.80, 0.55, true)
	A.siege_yard(root, S)
	return root

func puerto(team: Color) -> Node3D:
	var S := pal(701)
	var root := _hall(S, team, 1.50, 1.20, 0.65, 0.40)
	root.position = Vector3(0.0, 0.0, -0.8)
	var outer := Node3D.new()
	outer.add_child(root)
	A.pier(outer, S)
	return outer

func torre(team: Color) -> Node3D:
	var S := pal(801)
	var root := Node3D.new()
	var top := A.tower_sq(root, Vector3.ZERO, 1.05, 2.40, S.F)
	M._flag(root, Vector3(0, top, 0), team, 1.0)
	return root

func monasterio(team: Color) -> Node3D:
	var S := pal(901)
	var root := _hall(S, team, 2.20, 1.60, 1.00, 0.70)
	A.tower_sq(root, Vector3(1.0, 0, -0.7), 0.8, 2.2, S.F)
	return root

func castillo(team: Color) -> Node3D:
	var S := pal(110)
	var F: Dictionary = S.F
	var root := Node3D.new()
	A.wall_block(root, F, 3.0, 1.30, 0.50, Vector3(0, 0, -1.55))
	A.wall_block(root, F, 0.50, 1.30, 3.0, Vector3(-1.55, 0, 0))
	A.wall_block(root, F, 0.50, 1.30, 3.0, Vector3(1.55, 0, 0))
	A.wall_block(root, F, 1.05, 1.30, 0.50, Vector3(-0.975, 0, 1.55))
	A.wall_block(root, F, 1.05, 1.30, 0.50, Vector3(0.975, 0, 1.55))
	M.box(root, Vector3(0.90, 0.92, 0.30), Vector3(0, 0.46, 1.50), F.slit)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			A.tower_sq(root, Vector3(sx * 1.55, 0, sz * 1.55), 1.05, 2.35, F)
	var top := A.tower_sq(root, Vector3(0, 0, -0.45), 1.50, 2.80, F)
	M._flag(root, Vector3(0, top, -0.45), team, 1.0)
	return root

func herreria(team: Color) -> Node3D:
	var S := pal(1001)
	var root := _hall(S, team, 2.20, 1.60, 0.80, 0.50, true)
	A.forge_yard(root, S)
	return root

func mercado(team: Color) -> Node3D:
	var S := pal(1101)
	var root := Node3D.new()
	M.box(root, Vector3(2.40, 0.10, 2.00), Vector3(0, 0.05, 0), S.wall_d)
	for k in 3:
		var x := -0.8 + k * 0.8
		M.box(root, Vector3(0.70, 0.05, 0.60), Vector3(x, 0.90, 0.2), _tm(team) if k == 1 else S.roof)
		M.box(root, Vector3(0.05, 0.80, 0.05), Vector3(x - 0.3, 0.50, 0.45), S.wood)
		M.box(root, Vector3(0.05, 0.80, 0.05), Vector3(x + 0.3, 0.50, 0.45), S.wood)
		M.box(root, Vector3(0.50, 0.30, 0.30), Vector3(x, 0.25, 0.2), S.wood_l)
	return root

# ------------------------------------------------------------------ murallas

func wall_post() -> Node3D:
	return A.wall_post(pal(250).F)

func wall_arm(d: int) -> Node3D:
	return A.wall_arm(d, pal(250).F)

func gate(along_x: bool) -> Node3D:
	var S := pal(260)
	return A.wall_gate(along_x, S.F, S.wood, "round")
