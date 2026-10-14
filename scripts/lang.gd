class_name Lang
extends RefCounted
## Textos en español cargados desde res://data/es.json.
## Para traducir el juego solo hay que añadir otro JSON y cambiar FILE.

const FILE := "res://data/es.json"
static var _d: Dictionary = {}
static var _loaded := false

static func _load() -> void:
	_loaded = true
	var f := FileAccess.open(FILE, FileAccess.READ)
	if f == null:
		push_warning("No se pudo abrir " + FILE)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_d = parsed

static func t(key: String, args: Array = []) -> String:
	if not _loaded:
		_load()
	var s: String = _d.get(key, key)
	if args.size() > 0:
		return s % args
	return s

static func a(key: String) -> Array:
	if not _loaded:
		_load()
	var v = _d.get(key, [])
	return v if v is Array else []
