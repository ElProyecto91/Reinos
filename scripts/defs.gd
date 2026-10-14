class_name Defs
extends RefCounted
## Datos estáticos del juego: unidades, edificios, recursos y edades.
## Todo se dibuja por código, así que no hay arte externo (coste 0 y APK pequeño).

const TILE := 32
const MAX_POP := 80

const KINDS := ["food", "wood", "gold"]

# Terreno
const T_WATER := 0
const T_SAND := 1
const T_GRASS := 2

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
]
const AGE_STAT_MULT := [1.0, 1.15]

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
		"military": true, "radius": 10.0, "vs_building": 0.5,
	},
}

# Multiplicadores de daño (atacante -> objetivo): piquero > jinete > arquero > piquero
const BONUS := {
	"piquero": {"jinete": 3.0},
	"jinete": {"arquero": 2.2, "aldeano": 1.3},
	"arquero": {"piquero": 1.6, "aldeano": 1.3},
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
		"pop": 0, "drop": false, "train": ["piquero"], "los": 5, "age": 0,
	},
	"arqueria": {
		"size": 3, "hp": 900, "cost": {"wood": 175}, "time": 42.0,
		"pop": 0, "drop": false, "train": ["arquero"], "los": 5, "age": 1,
	},
	"establo": {
		"size": 3, "hp": 900, "cost": {"wood": 175}, "time": 42.0,
		"pop": 0, "drop": false, "train": ["jinete"], "los": 5, "age": 1,
	},
	"torre": {
		"size": 2, "hp": 700, "cost": {"wood": 100, "gold": 50}, "time": 36.0,
		"pop": 0, "drop": false, "train": [], "los": 9, "age": 1,
		"atk": 8.0, "range": 8.0, "cd": 1.6,
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
const BUILD_MENU := ["casa", "granja", "almacen", "cuartel", "arqueria", "establo", "centro"]
const DEFENSE_MENU := ["muralla", "puerta", "torre"]
const WALL_MAX_LINE := 40

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
