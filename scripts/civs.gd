class_name Civs
extends RefCounted
## Civilizaciones: cada jugador elige una al empezar (la IA, al azar). Cada una tiene
##   · bonificaciones pasivas (multiplicadores por tipo o por clase de unidad, recolección, edificios, edades),
##   · una unidad única que se entrena en el Castillo (Edad de los Castillos),
##   · una habilidad activa con enfriamiento (desde la Edad Feudal) que el jugador dispara con un botón.
## Todo es dato: Sim lee los multiplicadores una sola vez al crear la partida (`build_mods`) y los guarda en cada
## unidad al nacer, así que el coste por fotograma es casi nulo. Los textos están en data/es.json
## (civ_<id>, civ_<id>_desc, abil_<id>, abil_<id>_desc).

const IDS := ["castellanos", "francos", "ingleses", "teutones", "vikingos", "bizantinos", "sarracenos", "mongoles"]

## Clase de cada unidad (los selectores de los multiplicadores pueden ser un tipo, una clase, "mil" o "all").
## vill = aldeano · inf = infantería · arc = arqueros a pie · cav = caballería · marc = arqueros/tiradores a caballo
## siege = asedio · monk = monje · ship = barcos
const CLS := {
	"aldeano": "vill",
	"piquero": "inf", "espadachin": "inf", "alabardero": "inf",
	"arquero": "arc", "ballestero": "arc", "hostigador": "arc",
	"jinete": "cav", "explorador": "cav", "caballero": "cav",
	"arquero_caballo": "marc",
	"ariete": "siege", "catapulta": "siege", "trabuquete": "siege",
	"monje": "monk",
	"barco_pesca": "ship", "barco_transporte": "ship", "galera": "ship", "galeon": "ship",
	# únicas
	"conquistador": "marc", "hachero": "inf", "arquero_largo": "arc", "teutonico": "inf",
	"berserker": "inf", "catafracta": "cav", "mameluco": "cav", "mangudai": "marc",
}

## Habilidades. kind: buff (bonos temporales a ciertas clases) · lump (recursos de golpe) · fire (zona de fuego, hay
## que apuntar) · reveal (ves a todos los enemigos un rato, y bono de velocidad) · spawn (tropas nuevas en el Centro).
## buff: atk (daño ×), spd (velocidad ×), def (daño recibido ×), rate (cadencia ×), cls (clases a las que afecta; vacío = todo
## el ejército de tierra), loot (cada baja enemiga da botín).
const DATA := {
	"castellanos": {
		"unique": "conquistador",
		"hp": {"cav": 1.20},
		"gather": {"gold": 1.15},
		"ability": {"kind": "buff", "dur": 18.0, "cd": 120.0, "atk": 1.30, "spd": 1.20},
	},
	"francos": {
		"unique": "hachero",
		"atk": {"inf": 1.08},
		"gather": {"food": 1.10},
		"ability": {"kind": "lump", "cd": 180.0, "per_vill": 3, "kinds": ["food", "wood"], "min": 90, "max": 270},
	},
	"ingleses": {
		"unique": "arquero_largo",
		"rng": {"arc": 1.12, "marc": 1.12},
		"atk": {"arc": 1.10, "marc": 1.10},
		"gather": {"wood": 1.15},
		"ability": {"kind": "buff", "dur": 15.0, "cd": 100.0, "rate": 1.6, "cls": ["arc", "marc"]},
	},
	"teutones": {
		"unique": "teutonico",
		"hp": {"inf": 1.12},
		"atk": {"inf": 1.06},
		"gather": {"food": 1.08},
		"bld_hp": 1.25,
		"pop_house": 1,
		"ability": {"kind": "buff", "dur": 12.0, "cd": 110.0, "def": 0.65},
	},
	"vikingos": {
		"unique": "berserker",
		"atk": {"inf": 1.10},
		"hp": {"ship": 1.20, "inf": 1.08},
		"cost": {"ship": 0.85},
		"gather": {"fish": 1.25, "food": 1.06},
		"ability": {"kind": "buff", "dur": 20.0, "cd": 120.0, "atk": 1.20, "loot": true, "loot_gold": 12, "loot_food": 8},
	},
	"bizantinos": {
		"unique": "catafracta",
		"hp": {"monk": 1.30},
		"heal": 1.40,
		"bld_hp": 1.10,
		"age_cost": 0.95,
		"age_time": 0.92,
		"ability": {"kind": "fire", "cd": 90.0, "dur": 7.0, "radius": 2.8, "dps": 12.0},
	},
	"sarracenos": {
		"unique": "mameluco",
		"hp": {"cav": 1.08},
		"cost": {"marc": 0.85, "cav": 0.90},
		"gather": {"food": 1.10, "gold": 1.10},
		"ability": {"kind": "reveal", "dur": 20.0, "cd": 120.0, "spd": 1.20},
	},
	"mongoles": {
		"unique": "mangudai",
		"spd": {"cav": 1.10, "marc": 1.10},
		"los": {"cav": 2, "marc": 2},
		"time": {"cav": 0.85, "marc": 0.85},
		"ability": {"kind": "spawn", "cd": 180.0, "unit": "mangudai", "n": 4},
	},
}

static func valid(id: String) -> bool:
	return DATA.has(id)

static func cls_of(type: String) -> String:
	return String(CLS.get(type, ""))

static func unique_of(id: String) -> String:
	return String(DATA[id]["unique"]) if DATA.has(id) else ""

static func ability_of(id: String) -> Dictionary:
	return DATA[id]["ability"] if DATA.has(id) else {}

## ¿La regla `sel` (tipo, clase, "mil" o "all") alcanza a esta unidad?
static func sel_matches(sel: String, type: String) -> bool:
	if sel == type or sel == "all":
		return true
	var d: Dictionary = Defs.UNITS[type]
	if sel == "mil":
		return bool(d.get("military", false)) and not bool(d.get("naval", false))
	return sel == cls_of(type)

## Producto de los multiplicadores de `rules` ({selector: factor}) que alcanzan a `type`.
static func _mult(rules: Dictionary, type: String) -> float:
	var m := 1.0
	for sel: String in rules:
		if sel_matches(sel, type):
			m *= float(rules[sel])
	return m

## Tablas de multiplicadores por tipo de unidad para una civilización (sólo entradas distintas de 1).
## Devuelve {"hp": {tipo: ×}, "atk": …, "spd": …, "rng": …, "los": {tipo: casillas}, "cost": …, "time": …,
##           "gather": PackedFloat32Array indexada por tipo de recurso (R_*), "bld_hp": ×, "pop_house": +n,
##           "age_cost": ×, "age_time": ×, "heal": ×}
static func build_mods(id: String) -> Dictionary:
	var out := {"hp": {}, "atk": {}, "spd": {}, "rng": {}, "los": {}, "cost": {}, "time": {},
		"gather": PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]),
		"bld_hp": 1.0, "pop_house": 0, "age_cost": 1.0, "age_time": 1.0, "heal": 1.0}
	if not DATA.has(id):
		return out
	var c: Dictionary = DATA[id]
	for stat in ["hp", "atk", "spd", "rng", "cost", "time"]:
		var rules: Dictionary = c.get(stat, {})
		if rules.is_empty():
			continue
		for t: String in Defs.UNITS:
			var m := _mult(rules, t)
			if absf(m - 1.0) > 0.0001:
				(out[stat] as Dictionary)[t] = m
	var los_rules: Dictionary = c.get("los", {})
	for t: String in Defs.UNITS:
		var add := 0
		for sel: String in los_rules:
			if sel_matches(sel, t):
				add += int(los_rules[sel])
		if add != 0:
			(out["los"] as Dictionary)[t] = add
	var gm: Dictionary = c.get("gather", {})
	var g: PackedFloat32Array = out["gather"]
	for rt in [Defs.R_TREE, Defs.R_GOLD, Defs.R_BERRY, Defs.R_FARM, Defs.R_FISH, Defs.R_STONE, Defs.R_DEER, Defs.R_BOAR]:
		var kind: String = String(Defs.RES_INFO[rt]["kind"])
		var m := float(gm.get(kind, 1.0))
		if rt == Defs.R_FISH:
			m *= float(gm.get("fish", 1.0))
		g[rt] = m
	out["gather"] = g
	out["bld_hp"] = float(c.get("bld_hp", 1.0))
	out["pop_house"] = int(c.get("pop_house", 0))
	out["age_cost"] = float(c.get("age_cost", 1.0))
	out["age_time"] = float(c.get("age_time", 1.0))
	out["heal"] = float(c.get("heal", 1.0))
	return out

## Lista de unidades que entrena un edificio para una civilización (el Castillo añade su unidad única).
static func train_list(btype: String, civ: String) -> Array:
	var base: Array = Defs.BUILDINGS[btype]["train"]
	if btype == "castillo" and DATA.has(civ):
		var l := base.duplicate()
		l.append(String(DATA[civ]["unique"]))
		return l
	return base

## ¿Puede esta civilización entrenar `utype` en `btype`? (las únicas sólo son de su civilización)
static func can_train(btype: String, civ: String, utype: String) -> bool:
	return train_list(btype, civ).has(utype)

## Clases de la habilidad como diccionario tipo → true (vacío = todo el ejército de tierra).
static func buff_types(ab: Dictionary) -> Dictionary:
	var out := {}
	var cls: Array = ab.get("cls", [])
	for t: String in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[t]
		if bool(d.get("naval", false)) or t == "aldeano":
			continue
		if cls.is_empty():
			if bool(d.get("military", false)):
				out[t] = true
		elif cls.has(cls_of(t)):
			out[t] = true
	return out
