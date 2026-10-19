class_name IsoCivs
extends RefCounted
## Registro de la arquitectura por civilización. Cada civilización de `Civs.IDS` tiene su módulo en tools/iso/civ/<id>.gd con
## los métodos `build(tipo, color_equipo) -> Node3D` (uno por tipo de edificio de TYPES), `wall_post()`, `wall_arm(d)` y
## `gate(along_x)`. Para añadir una civilización: copiar tools/iso/civ/_plantilla.gd, rellenarlo con su estética y hornear
## (ver «Cómo añadir una civilización» en el README); el catálogo, el atlas y el juego recogen su paquete de sprites solos.
## Los sprites se llaman `<civ>__<tipo>` (puerto: `<civ>__puerto_<lado>`; murallas: `<civ>__muralla_poste`, `<civ>__muralla_a0..7`,
## `<civ>__puerta_x`, `<civ>__puerta_z`).

## Tipos de edificio con arquitectura propia (la mina, que sólo se ve en obra, es común a todas).
const TYPES := ["casa", "centro", "almacen", "cuartel", "arqueria", "establo", "taller", "puerto", "torre", "monasterio", "castillo", "herreria", "mercado"]
const DIR := "res://tools/iso/civ/"

static var _mods: Dictionary = {}

## Civilizaciones de `Civs.IDS` que ya tienen módulo de arquitectura.
static func available() -> Array:
	var out: Array = []
	for id in Civs.IDS:
		if ResourceLoader.exists(DIR + String(id) + ".gd"):
			out.append(id)
	return out

static func module(id: String) -> Object:
	if not _mods.has(id):
		var path := DIR + id + ".gd"
		if not ResourceLoader.exists(path):
			push_error("IsoCivs: falta el módulo de la civilización " + path)
			return null
		_mods[id] = (load(path) as GDScript).new()
	return _mods[id]

## Nombre del sprite de un edificio de una civilización.
static func sprite(civ: String, type: String) -> String:
	return "%s__%s" % [civ, type]

## Trabajos de horneado de una civilización, agrupados por lienzo: {"edificios": [...], "castillo": [...], "muralla": [...]}.
## Cada trabajo es [nombre, constructor, giro, sombra, máscara de equipo] (como en IsoCatalog).
static func jobs(civ: String) -> Dictionary:
	var mod := module(civ)
	var T := IsoModels.TEAM_BASE
	var main: Array = []
	var castle: Array = []
	for t in TYPES:
		var tt: String = t
		if tt == "castillo":
			castle.append([sprite(civ, tt), func() -> Node3D: return mod.build(tt, T), 0.0, true, true])
		elif tt == "puerto":
			for o in 4:
				var oo := o
				# lado del agua: 0 norte (−z), 1 este (+x), 2 sur (+z), 3 oeste (−x); el modelo mira a +z
				var yaw := [180.0, 90.0, 0.0, 270.0][o] as float
				main.append(["%s__puerto_%d" % [civ, oo], func() -> Node3D: return mod.build("puerto", T), yaw, true, true])
		else:
			main.append([sprite(civ, tt), func() -> Node3D: return mod.build(tt, T), 0.0, true, true])
	var walls: Array = [[sprite(civ, "muralla_poste"), func() -> Node3D: return mod.wall_post(), 0.0, true, true]]
	for d in 8:
		var dd := d
		walls.append([sprite(civ, "muralla_a%d" % dd), func() -> Node3D: return mod.wall_arm(dd), 0.0, true, false])
	walls.append([sprite(civ, "puerta_x"), func() -> Node3D: return mod.gate(true), 0.0, true, true])
	walls.append([sprite(civ, "puerta_z"), func() -> Node3D: return mod.gate(false), 0.0, true, true])
	return {"edificios": main, "castillo": castle, "muralla": walls}
