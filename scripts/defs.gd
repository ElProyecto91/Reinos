class_name Defs
extends RefCounted
## Datos estáticos del juego: unidades, edificios, recursos y edades.
## Todo se dibuja por código, así que no hay arte externo (coste 0 y APK pequeño).

const TILE := 32
const MAX_POP := 200

const KINDS := ["food", "wood", "gold"]

# Terreno
const T_WATER := 0
const T_SAND := 1
const T_GRASS := 2
const T_ROCK := 3      # montaña: sólida, no se puede construir ni cruzar

# Recursos de casilla
const R_NONE := 0
const R_TREE := 1
const R_GOLD := 2
const R_BERRY := 3
const R_FARM := 4
const R_FISH := 5

const RES_INFO := {
	1: {"kind": "wood", "amount": 100, "rate": 0.8},
	2: {"kind": "gold", "amount": 600, "rate": 0.7},
	3: {"kind": "food", "amount": 200, "rate": 1.0},
	4: {"kind": "food", "amount": 250, "rate": 0.55},
	5: {"kind": "food", "amount": 400, "rate": 1.2},
}

const START_RES := {"food": 300, "wood": 300, "gold": 120}

const PLAYER_COLORS := [
	Color("2f6fdc"), # azul
	Color("d6392f"), # rojo
	Color("e0b400"), # amarillo
	Color("8e44ad"), # morado
]
const PLAYER_COLOR_NAMES := ["Azul", "Rojo", "Amarillo", "Morado"]

# Edades
const AGES := [
	{"name": "age_0"},
	{"name": "age_1", "cost": {"food": 400, "gold": 200}, "time": 40.0},
	# Edad de los Castillos: exige tener al menos 2 tipos distintos de edificio militar terminados
	{"name": "age_2", "cost": {"food": 700, "gold": 450}, "time": 55.0, "need_mil": 2},
]
const AGE_STAT_MULT := [1.0, 1.15, 1.30]
const MIL_BUILDINGS := ["cuartel", "arqueria", "establo", "taller"]

# Unidades. speed y range en casillas/s y casillas.
const UNITS := {
	"aldeano": {
		"hp": 25, "speed": 2.3, "atk": 3.0, "range": 0.9, "cd": 1.5, "los": 6,
		"cost": {"food": 50}, "time": 14.0, "building": "centro", "age": 0,
		"military": false, "radius": 7.0, "vs_building": 0.2,
	},
	"piquero": {
		"hp": 55, "speed": 2.2, "atk": 4.5, "range": 0.9, "cd": 1.2, "los": 6,
		"cost": {"food": 50, "wood": 25}, "time": 20.0, "building": "cuartel", "age": 0,
		"military": true, "radius": 8.0, "vs_building": 0.8,
	},
	"arquero": {
		"hp": 32, "speed": 2.2, "atk": 4.0, "range": 5.0, "cd": 1.5, "los": 8,
		"cost": {"wood": 30, "gold": 45}, "time": 23.0, "building": "arqueria", "age": 1,
		"military": true, "radius": 7.0, "vs_building": 0.3,
	},
	"jinete": {
		"hp": 110, "speed": 3.8, "atk": 8.0, "range": 1.0, "cd": 1.4, "los": 8,
		"cost": {"food": 60, "gold": 75}, "time": 28.0, "building": "establo", "age": 1,
		"military": true, "radius": 10.0, "vs_building": 0.5, "scout": true,
	},
	# --- soldados nuevos ---
	"espadachin": {
		"hp": 72, "speed": 2.2, "atk": 7.0, "range": 0.9, "cd": 1.2, "los": 6,
		"cost": {"food": 55, "gold": 25}, "time": 24.0, "building": "cuartel", "age": 1,
		"military": true, "radius": 8.0, "vs_building": 0.7,
	},
	"ballestero": {
		"hp": 38, "speed": 2.1, "atk": 9.0, "range": 5.5, "cd": 2.2, "los": 8,
		"cost": {"wood": 40, "gold": 55}, "time": 27.0, "building": "arqueria", "age": 1,
		"military": true, "radius": 7.0, "vs_building": 0.3,
	},
	"explorador": {
		"hp": 65, "speed": 4.8, "atk": 3.5, "range": 1.0, "cd": 1.2, "los": 12,
		"cost": {"food": 70}, "time": 16.0, "building": "establo", "age": 1,
		"military": true, "radius": 9.0, "vs_building": 0.2, "scout": true,
	},
	"caballero": {
		"hp": 200, "speed": 3.3, "atk": 11.0, "range": 1.0, "cd": 1.5, "los": 8,
		"cost": {"food": 85, "gold": 100}, "time": 34.0, "building": "establo", "age": 1,
		"military": true, "radius": 10.5, "vs_building": 0.6,
	},
	"ariete": {
		"hp": 190, "speed": 1.5, "atk": 20.0, "range": 0.9, "cd": 2.0, "los": 5,
		"cost": {"wood": 150, "gold": 50}, "time": 36.0, "building": "taller", "age": 1,
		"military": true, "radius": 11.0, "vs_building": 3.5, "siege": true, "rres": 0.25,
	},
	# --- Edad de los Castillos ---
	"alabardero": {
		"hp": 72, "speed": 2.2, "atk": 6.5, "range": 0.9, "cd": 1.2, "los": 6,
		"cost": {"food": 55, "wood": 45}, "time": 26.0, "building": "cuartel", "age": 2,
		"military": true, "radius": 8.0, "vs_building": 0.8,
	},
	"hostigador": {
		"hp": 36, "speed": 2.3, "atk": 5.5, "range": 4.5, "cd": 1.4, "los": 8,
		"cost": {"food": 30, "wood": 40}, "time": 22.0, "building": "arqueria", "age": 2,
		"military": true, "radius": 7.0, "vs_building": 0.25,
	},
	"arquero_caballo": {
		"hp": 75, "speed": 3.5, "atk": 6.0, "range": 4.5, "cd": 1.5, "los": 9,
		"cost": {"wood": 55, "gold": 65}, "time": 30.0, "building": "arqueria", "age": 2,
		"military": true, "radius": 10.0, "vs_building": 0.2,
	},
	# Artillería: la catapulta lanza piedras que dañan en área (a unidades y edificios); el trabuquete sólo derriba edificios, desde lejos
	"catapulta": {
		"hp": 120, "speed": 1.3, "atk": 26.0, "range": 8.0, "cd": 4.2, "los": 7,
		"cost": {"wood": 160, "gold": 100}, "time": 42.0, "building": "taller", "age": 2,
		"military": true, "radius": 12.0, "vs_building": 2.0, "rock": true, "splash": 1.5, "rres": 0.5,
	},
	"trabuquete": {
		"hp": 150, "speed": 1.0, "atk": 46.0, "range": 11.0, "cd": 6.0, "los": 10,
		"cost": {"wood": 220, "gold": 180}, "time": 55.0, "building": "castillo", "age": 2,
		"military": true, "radius": 13.0, "vs_building": 3.2, "siege": true, "rock": true, "rres": 0.4,
	},
	# El monje no ataca: cura sin parar a los aliados heridos que tiene cerca (hasta `heal_n` a la vez)
	"monje": {
		"hp": 32, "speed": 2.0, "atk": 0.0, "range": 0.0, "cd": 9.0, "los": 7,
		"cost": {"gold": 90}, "time": 28.0, "building": "monasterio", "age": 2,
		"military": false, "radius": 7.0, "vs_building": 0.0, "heal": 2.6, "heal_r": 3.6, "heal_n": 3,
	},
	# --- barcos (sólo navegan por agua; se entrenan en el Puerto) ---
	"barco_pesca": {
		"hp": 55, "speed": 2.8, "atk": 0.0, "range": 0.0, "cd": 9.0, "los": 8,
		"cost": {"wood": 60}, "time": 16.0, "building": "puerto", "age": 0,
		"military": false, "radius": 11.0, "vs_building": 0.0, "naval": true, "fisher": true, "carry": 15.0, "scout": true,
	},
	"barco_transporte": {
		"hp": 120, "speed": 2.5, "atk": 0.0, "range": 0.0, "cd": 9.0, "los": 8,
		"cost": {"wood": 110}, "time": 24.0, "building": "puerto", "age": 0,
		"military": false, "radius": 13.0, "vs_building": 0.0, "naval": true, "cargo": 8, "scout": true,
	},
	"galera": {
		"hp": 140, "speed": 3.0, "atk": 7.0, "range": 6.0, "cd": 1.6, "los": 10,
		"cost": {"wood": 80, "gold": 45}, "time": 28.0, "building": "puerto", "age": 1,
		"military": true, "radius": 12.0, "vs_building": 0.5, "naval": true, "scout": true,
	},
	"galeon": {
		"hp": 320, "speed": 2.3, "atk": 17.0, "range": 7.0, "cd": 2.6, "los": 10,
		"cost": {"wood": 130, "gold": 110}, "time": 42.0, "building": "puerto", "age": 1,
		"military": true, "radius": 15.0, "vs_building": 1.1, "naval": true, "cannon": true, "scout": true,
	},
}

# Multiplicadores de daño (atacante -> objetivo).
# Lanza > caballería > arqueros > infantería ligera; el espadachín cuesta más pero vence a la lanza y al ariete;
# la caballería (rápida) también alcanza y destroza arietes, como en la tabla de contras de Age of Empires II.
const BONUS := {
	"piquero": {"jinete": 3.0, "caballero": 3.2, "explorador": 2.0, "arquero_caballo": 2.0},
	"alabardero": {"jinete": 3.5, "caballero": 3.8, "explorador": 2.4, "arquero_caballo": 2.8},
	"espadachin": {"piquero": 1.6, "alabardero": 1.4, "arquero": 1.2, "ballestero": 1.2, "hostigador": 1.3, "ariete": 2.5, "catapulta": 2.2, "trabuquete": 2.2, "monje": 1.4},
	"arquero": {"piquero": 1.6, "alabardero": 1.5, "espadachin": 1.3, "aldeano": 1.3},
	"ballestero": {"jinete": 1.8, "caballero": 1.7, "espadachin": 1.2, "aldeano": 1.2},
	"hostigador": {"arquero": 2.2, "ballestero": 1.8, "arquero_caballo": 2.0, "monje": 1.3},
	"arquero_caballo": {"piquero": 1.6, "espadachin": 1.4, "alabardero": 1.2, "aldeano": 1.3, "monje": 1.5, "catapulta": 1.4},
	"jinete": {"arquero": 2.2, "ballestero": 2.0, "hostigador": 1.5, "arquero_caballo": 1.6, "aldeano": 1.3, "monje": 1.8, "ariete": 1.6, "catapulta": 1.8, "trabuquete": 1.8},
	"explorador": {"aldeano": 1.4, "arquero": 1.4, "ariete": 1.4, "catapulta": 1.4},
	"caballero": {"arquero": 2.2, "ballestero": 2.0, "hostigador": 1.6, "arquero_caballo": 1.6, "aldeano": 1.3, "espadachin": 1.2, "monje": 1.8, "ariete": 1.8, "catapulta": 2.0, "trabuquete": 2.0},
	"galera": {"barco_pesca": 1.6, "barco_transporte": 1.6},
	"galeon": {"galera": 1.5, "barco_pesca": 1.6, "barco_transporte": 1.6},
}

# Edificios. size en casillas, time = segundos de construcción con un aldeano.
const BUILDINGS := {
	"centro": {
		"size": 3, "hp": 1500, "cost": {"wood": 300, "gold": 150}, "time": 90.0,
		"pop": 10, "drop": true, "train": ["aldeano"], "los": 10, "age": 0,
		"atk": 6.0, "range": 7.0, "cd": 2.0,
	},
	"casa": {
		"size": 2, "hp": 350, "cost": {"wood": 30}, "time": 16.0,
		"pop": 5, "drop": false, "train": [], "los": 4, "age": 0,
	},
	"almacen": {
		"size": 2, "hp": 600, "cost": {"wood": 100}, "time": 22.0,
		"pop": 0, "drop": true, "train": [], "los": 5, "age": 0,
	},
	"cuartel": {
		"size": 3, "hp": 900, "cost": {"wood": 150}, "time": 40.0,
		"pop": 0, "drop": false, "train": ["piquero", "espadachin", "alabardero"], "los": 5, "age": 0,
	},
	"arqueria": {
		"size": 3, "hp": 900, "cost": {"wood": 175}, "time": 42.0,
		"pop": 0, "drop": false, "train": ["arquero", "ballestero", "hostigador", "arquero_caballo"], "los": 5, "age": 1,
	},
	"establo": {
		"size": 3, "hp": 900, "cost": {"wood": 175}, "time": 42.0,
		"pop": 0, "drop": false, "train": ["explorador", "jinete", "caballero"], "los": 5, "age": 1,
	},
	"taller": {
		"size": 3, "hp": 900, "cost": {"wood": 200}, "time": 45.0,
		"pop": 0, "drop": false, "train": ["ariete", "catapulta"], "los": 5, "age": 1,
	},
	# El Puerto se construye en la orilla (junto a mar abierto): entrena barcos y recibe el pescado.
	"puerto": {
		"size": 3, "hp": 1000, "cost": {"wood": 150}, "time": 40.0,
		"pop": 0, "drop": true, "drop_kinds": ["food"], "dock": true,
		"train": ["barco_pesca", "barco_transporte", "galera", "galeon"], "los": 8, "age": 0,
	},
	"torre": {
		"size": 2, "hp": 700, "cost": {"wood": 100, "gold": 50}, "time": 36.0,
		"pop": 0, "drop": false, "train": [], "los": 9, "age": 1,
		"atk": 8.0, "range": 8.0, "cd": 1.6,
	},
	# Edad de los Castillos
	"monasterio": {
		"size": 3, "hp": 1100, "cost": {"wood": 175, "gold": 100}, "time": 50.0,
		"pop": 0, "drop": false, "train": ["monje"], "los": 6, "age": 2,
	},
	"castillo": {
		"size": 4, "hp": 3200, "cost": {"wood": 300, "gold": 300}, "time": 120.0,
		"pop": 0, "drop": false, "train": ["trabuquete"], "los": 12, "age": 2,
		"atk": 15.0, "range": 10.0, "cd": 1.1,
	},
	# Murallas y puertas: 1x1, se trazan en línea. La puerta deja pasar a los aliados y no al enemigo.
	"muralla": {
		"size": 1, "hp": 550, "cost": {"wood": 8}, "time": 6.0,
		"pop": 0, "drop": false, "train": [], "los": 2, "age": 1, "wall": true,
	},
	"puerta": {
		"size": 1, "hp": 800, "cost": {"wood": 50}, "time": 14.0,
		"pop": 0, "drop": false, "train": [], "los": 3, "age": 1, "wall": true, "gate": true,
	},
}

# Granja: recurso de 1 casilla que se coloca al instante (no es edificio).
const FARM_COST := {"wood": 60}

# Orden de los botones de construcción
const BUILD_MENU := ["casa", "granja", "almacen", "puerto", "centro"]
const MILITARY_MENU := ["cuartel", "arqueria", "establo", "taller", "monasterio"]
const DEFENSE_MENU := ["muralla", "puerta", "torre", "castillo"]
const WALL_MAX_LINE := 40
const MIN_SEA := 40        # una masa de agua menor que esto no sirve de puerto (charcas)

static func can_afford(res: Dictionary, cost: Dictionary) -> bool:
	for k in cost:
		if int(res.get(k, 0)) < int(cost[k]):
			return false
	return true

static func pay(res: Dictionary, cost: Dictionary) -> void:
	for k in cost:
		res[k] = int(res.get(k, 0)) - int(cost[k])

static func refund(res: Dictionary, cost: Dictionary) -> void:
	for k in cost:
		res[k] = int(res.get(k, 0)) + int(cost[k])
