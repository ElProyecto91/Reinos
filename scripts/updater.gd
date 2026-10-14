class_name Updater
extends Node
## Aviso de versión nueva. Es la ÚNICA conexión a Internet del juego y es opcional.
##
## Qué hace: pide a GitHub (HTTPS, sin enviar ningún dato tuyo) cuál es la última release
## ("build-N") y la compara con la build instalada. Si hay una más nueva avisa en el menú; al tocar
## el aviso abre en el navegador una dirección FIJA en el código (nunca una que venga de la
## respuesta). La instalación la hace Android y solo acepta APKs firmados con la misma clave que el
## instalado, de modo que un APK manipulado no puede sustituir al juego aunque llegue a descargarse.
## No descarga ni instala nada por su cuenta (Android no lo permite sin tu confirmación).

signal update_found(build: int)

const PAGE_URL := "https://github.com/ElProyecto91/reinos/releases/latest"
const DEFAULT_API := "https://api.github.com/repos/ElProyecto91/reinos/releases/latest"
const CHECK_EVERY := 6 * 3600   # segundos entre comprobaciones
const MAX_BODY := 262144        # se ignora cualquier respuesta mayor de 256 KB
const TIMEOUT := 8.0

var api_url := DEFAULT_API      # solo las pruebas lo cambian
var _req: HTTPRequest

## Número de build instalada (lo escribe el flujo de GitHub); 0 en compilaciones locales.
static func current_build() -> int:
	var path := "res://data/build.json"
	if not FileAccess.file_exists(path):
		return 0
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary and (d as Dictionary).has("build"):
		var s := String((d as Dictionary)["build"]).strip_edges()
		var rx := RegEx.create_from_string("^([0-9]{1,6})")
		var m := rx.search(s)
		if m != null:
			return int(m.get_string(1))
	return 0

## Extrae el número de build de la respuesta de la API; -1 si no es válida o no es estable.
static func parse_release(body: String) -> int:
	if body.length() > MAX_BODY:
		return -1
	var j := JSON.new()
	if j.parse(body) != OK or not (j.data is Dictionary):
		return -1
	var dict := j.data as Dictionary
	if bool(dict.get("draft", false)) or bool(dict.get("prerelease", false)):
		return -1
	var tag: Variant = dict.get("tag_name", null)
	if not (tag is String):
		return -1
	var rx := RegEx.create_from_string("^build-([0-9]{1,6})\\z")
	var m := rx.search(tag as String)
	if m == null:
		return -1
	return int(m.get_string(1))

static func is_newer(remote: int, local: int) -> bool:
	return remote > 0 and local > 0 and remote > local

func check() -> void:
	Settings.ensure_loaded()
	if not Settings.check_updates:
		return
	var cur := current_build()
	if cur <= 0:
		return   # compilación local: no hay con qué comparar
	if is_newer(Settings.known_build, cur):
		update_found.emit(Settings.known_build)
	var now := int(Time.get_unix_time_from_system())
	if now - Settings.last_update_check < CHECK_EVERY and now >= Settings.last_update_check:
		return
	_req = HTTPRequest.new()
	_req.timeout = TIMEOUT
	_req.body_size_limit = MAX_BODY
	_req.max_redirects = 2
	add_child(_req)
	_req.request_completed.connect(_on_done)
	var headers := PackedStringArray(["Accept: application/vnd.github+json", "User-Agent: Reinos-update-check"])
	if _req.request(api_url, headers) != OK:
		_req.queue_free()

func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if is_instance_valid(_req):
		_req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return   # sin red, repositorio privado, límite de GitHub...: en silencio
	var remote := parse_release(body.get_string_from_utf8())
	Settings.last_update_check = int(Time.get_unix_time_from_system())
	if remote > 0:
		Settings.known_build = remote
	Settings.save()
	if is_newer(remote, current_build()):
		update_found.emit(remote)

func open_download() -> void:
	OS.shell_open(PAGE_URL)
