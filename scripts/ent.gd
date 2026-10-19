class_name Ent
extends RefCounted
## Entidad de juego: unidad o edificio (los recursos viven en arrays de casilla).

var id: int = 0
var is_building: bool = false
var type: String = ""
var owner: int = 0
var def: Dictionary = {}
var pos: Vector2 = Vector2.ZERO
var ppos: Vector2 = Vector2.ZERO      # posición previa (interpolación de dibujo)
var tile: Vector2i = Vector2i.ZERO    # edificios: esquina superior izquierda
var size: int = 1
var hp: float = 1.0
var max_hp: float = 1.0
var alive: bool = true
var radius: float = 8.0
var last_hit: float = -100.0
var qmark: int = 0
var off: Vector2 = Vector2.ZERO       # desvío de formación
var face: int = 1                      # hacia dónde mira (+1 derecha, -1 izquierda); sólo dibujo
var d8: int = 1                        # dirección de dibujo (0..7 = ángulo lógico / 45°); sólo dibujo
var naval: bool = false                # barco: sólo se mueve por agua
var stowed: bool = false               # a bordo de un barco (fuera de la partida hasta desembarcar)
var cargo: Array = []                  # barco de transporte: unidades (Ent) a bordo
var unload_at: Vector2i = Vector2i(-1, -1)   # barco: casilla de tierra donde desembarcar al llegar

# --- unidad ---
var state: int = 0
var path: Array = []
var path_i: int = 0
var path_pending: bool = false
var goal: Vector2i = Vector2i(-1, -1)
var target_id: int = 0
var target_tile: Vector2i = Vector2i(-1, -1)
var carry_kind: String = ""
var carry_amt: float = 0.0
var gather_acc: float = 0.0
var cd: float = 0.0
var scan_t: float = 0.0
var repath_t: float = 0.0
var amove: bool = false
var amove_goal: Vector2i = Vector2i(-1, -1)
var auto_target: bool = false
var home: Vector2 = Vector2.ZERO
var fails: int = 0
var ignore_id: int = 0
var fail_goal: Vector2i = Vector2i(-2, -2)
var fail_time: float = -100.0
var ignore_until: float = 0.0
var resume_id: int = 0                # objetivo al que volver tras romper una muralla
var explore: bool = false             # exploración automática: va sola a lo que aún no se ha visto
var xp_cell: int = -1                 # celda (de 4×4 casillas) hacia la que explora ahora
var xp_t: float = 0.0                 # temporizador para comprobar si ya se vio su destino
var xp_bad: Array = []                # celdas a las que no pudo llegar (se saltan un rato)
var danger_pos: Vector2 = Vector2(-1, -1)   # dónde la hirieron: evita esa zona un tiempo
var danger_t: float = -1000.0
var am: float = 1.0                   # multiplicadores de civilización fijados al nacer: daño, velocidad, alcance
var sm: float = 1.0
var rm: float = 1.0
var lb: int = 0                        # casillas extra de vista
var stance: int = 0                    # postura de combate (Sim.ST_*): 0 agresiva, 1 defensiva, 2 mantener posición, 3 pasiva
var fspd: float = 0.0                  # formación: velocidad máxima mientras marcha con el grupo (casillas/s; 0 = sin tope)
var gar_tile: Vector2i = Vector2i(-1, -1)   # aldeano refugiado: recurso en el que trabajaba (para volver a él)
var in_gar: int = 0                    # id del edificio donde está refugiado (0 = a la intemperie)
var gar_auto: bool = false               # se refugió huyendo (o por el rebato): sale solo cuando pasa el peligro

# --- edificio ---
var progress: float = 1.0             # 0..1; 1 = completo
var queue: Array = []
var train_left: float = 0.0
var train_total: float = 0.0
var producing: bool = false
var blocked_pop: bool = false
var rally: Vector2i = Vector2i(-1, -1)
var builders: int = 0
var bacc: int = 0
var orient: int = 2                   # puerto: lado del agua (0 norte, 1 este, 2 sur, 3 oeste)
var dock_tile: Vector2i = Vector2i(-1, -1)   # puerto: casilla de agua donde aparecen los barcos
var prod_tech: bool = false           # lo que se produce ahora es una mejora (no reserva población)
var gar_t: float = 0.0                # guarnición: segundos seguidos sin enemigos cerca

func center() -> Vector2:
	if is_building:
		return (Vector2(tile) + Vector2(size, size) * 0.5) * Defs.TILE
	return pos

func rect() -> Rect2:
	return Rect2(Vector2(tile) * Defs.TILE, Vector2(size, size) * Defs.TILE)

func dist_to(p: Vector2) -> float:
	## Distancia de un punto al borde de la entidad (0 si está dentro).
	if is_building:
		var r := rect()
		var cx := clampf(p.x, r.position.x, r.end.x)
		var cy := clampf(p.y, r.position.y, r.end.y)
		return p.distance_to(Vector2(cx, cy))
	return maxf(0.0, p.distance_to(pos) - radius)

func is_military() -> bool:
	return (not is_building) and bool(def.get("military", false))
