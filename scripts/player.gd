class_name Player
extends RefCounted

var idx: int = 0
var name: String = ""
var team: int = 0
var is_human: bool = false
var color: Color = Color.WHITE
var res: Dictionary = {}
var age: int = 0
var aging: bool = false
var age_left: float = 0.0
var pop: int = 0
var pop_cap: int = 0
var reserved: int = 0
var alive: bool = true
var start_tile: Vector2i = Vector2i.ZERO
var difficulty: int = 1
var gather_mult: float = 1.0
var last_alarm: float = -100.0
var kills: int = 0
var losses: int = 0
var gathered: Dictionary = {"food": 0, "wood": 0, "gold": 0, "stone": 0}

# --- mejoras, mercado, rebato y formación ---
var techs: Dictionary = {}             # mejoras investigadas (id -> true); ver Defs.TECHS
var mkt: Dictionary = {"food": 100, "wood": 100, "stone": 100}   # precio de 100 unidades en oro (sube al comprar y baja al vender)
var bell: bool = false                 # rebato: los aldeanos se refugian en los edificios con guarnición
var formation: int = 0                 # formación al mover grupos: 0 libre, 1 línea, 2 caja

# --- civilización y habilidad (ver civs.gd) ---
var civ: String = ""                   # "" = sin civilización (partidas antiguas y pruebas)
var abil_ready: float = 0.0            # instante de la partida en que vuelve a estar disponible
var abil_until: float = 0.0            # instante en que acaba el efecto en curso
var abil_on: bool = false              # hay bonos temporales activos
var abil_uses: int = 0
var b_atk: float = 1.0                 # bonos temporales: daño, velocidad, daño recibido, cadencia
var b_spd: float = 1.0
var b_def: float = 1.0
var b_rate: float = 1.0
var b_types: Dictionary = {}           # tipos de unidad a los que afectan (tipo -> true)
var b_loot: bool = false
var b_loot_gold: int = 0
var b_loot_food: int = 0
var reveal_until: float = 0.0          # el humano ve a todos los enemigos hasta este instante
