class_name Updater
extends Node
## Actualización del juego. Es la ÚNICA conexión a Internet de Reinos y es opcional (Menú → Actualizaciones).
##
## 1) Aviso: pide a GitHub (HTTPS, sin enviar ningún dato tuyo) cuál es la última release "build-N" y la
##    compara con la build instalada. Si hay una más nueva avisa en el menú.
## 2) Al tocar el aviso, y solo entonces: descarga el APK dentro del juego (con barra de progreso), comprueba su
##    SHA-256 y se lo entrega al instalador de Android (PackageInstaller, plugin «ReinosInstaller»). Android sigue
##    pidiendo un toque en «Instalar» (no hay forma de saltarse eso fuera de Google Play) y SOLO acepta un APK firmado
##    con la misma clave que el instalado: un APK manipulado no puede sustituir al juego aunque llegara a descargarse.
## 3) Si algo falla (sin permiso, sin red, hash distinto, el instalador no responde...) el botón ofrece reintentar y,
##    después, abrir la descarga en el navegador. En escritorio o en compilaciones sin el plugin, va directo al navegador.
##
## Las direcciones de descarga se construyen SIEMPRE con el host fijo de este archivo y un número de build que ya
## pasó por una expresión regular de solo dígitos: nada de lo que diga la respuesta de la API decide qué se descarga.

signal update_found(build: int)
signal state_changed

enum { IDLE, AVAILABLE, PERMISSION, DOWNLOADING, VERIFYING, INSTALLING, CONFIRMING, RETRY, FALLBACK, DONE }

const PAGE_URL := "https://github.com/ElProyecto91/reinos/releases/latest"
const DEFAULT_API := "https://api.github.com/repos/ElProyecto91/reinos/releases/latest"
const DEFAULT_DL := "https://github.com/ElProyecto91/reinos/releases/download"
const APK_ASSET := "reinos.apk"
const UPDATE_DIR := "user://update"
const CHECK_EVERY := 6 * 3600   # segundos entre comprobaciones
const MAX_BODY := 262144        # se ignora cualquier respuesta mayor de 256 KB
const TIMEOUT := 8.0
const MAX_APK := 200 * 1024 * 1024
const MIN_APK := 1024 * 1024
const POLL_EVERY := 0.5         # cada cuánto se pregunta al instalador cómo va
const UA := ["User-Agent: Reinos-update"]

var api_url := DEFAULT_API      # solo las pruebas lo cambian
var dl_base := DEFAULT_DL       # ídem
var installer: Object = null    # ídem (en el móvil es el singleton «ReinosInstaller»)
var opener: Callable = Callable()   # ídem (por defecto OS.shell_open)
var stall_secs := 30.0          # sin recibir ni un byte durante este tiempo -> se da por cortada
var install_wait := 40.0        # el instalador no contesta en este tiempo -> se da por fallida

var state := IDLE
var progress := -1.0            # 0..1 durante la descarga; -1 si no se conoce el tamaño
var target_build := 0
var target_size := 0            # bytes del APK según la API (0 = desconocido)
var detail := ""                # último problema, en texto para el jugador

var _req: HTTPRequest           # comprobación de versión
var _hreq: HTTPRequest          # suma SHA-256
var _areq: HTTPRequest          # APK
var _part := ""
var _apk_path := ""             # APK ya descargado y verificado
var _hash_want := ""
var _fails := 0
var _last_bytes := -1
var _last_move := 0.0
var _last_pct := -1
var _install_t0 := 0.0
var _poll_t := 0.0

func _ready() -> void:
	set_process(false)
	cleanup_old(current_build())

## Borra lo que quedó de descargas anteriores: restos .part y APKs de builds ya instaladas (o que no son APKs nuestros).
static func cleanup_old(cur: int) -> void:
	if not DirAccess.dir_exists_absolute(UPDATE_DIR):
		return
	var d := DirAccess.open(UPDATE_DIR)
	if d == null:
		return
	var rx := RegEx.create_from_string("^reinos-([0-9]{1,6})\\.apk$")
	for f in d.get_files():
		var m := rx.search(f)
		if m == null or int(m.get_string(1)) <= cur:
			d.remove(f)

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

## Tamaño en bytes del APK según la respuesta de la API (solo para mostrarlo y como comprobación extra); 0 si no consta.
static func parse_size(body: String) -> int:
	if body.length() > MAX_BODY:
		return 0
	var j := JSON.new()
	if j.parse(body) != OK or not (j.data is Dictionary):
		return 0
	var assets: Variant = (j.data as Dictionary).get("assets", null)
	if not (assets is Array):
		return 0
	for a: Variant in (assets as Array):
		if a is Dictionary and String((a as Dictionary).get("name", "")) == APK_ASSET:
			var s: Variant = (a as Dictionary).get("size", 0)
			if (s is int or s is float) and int(s) >= MIN_APK and int(s) <= MAX_APK:
				return int(s)
	return 0

static func is_newer(remote: int, local: int) -> bool:
	return remote > 0 and local > 0 and remote > local

## «38 MB»
static func size_text(bytes: int) -> String:
	return "%d MB" % maxi(1, int(round(float(bytes) / 1048576.0)))

## ¿Hay instalador propio en este dispositivo? (solo en el APK de Android compilado con la plantilla del proyecto)
func has_installer() -> bool:
	return _installer() != null

func _installer() -> Object:
	if installer != null and is_instance_valid(installer):
		return installer
	if Engine.has_singleton("ReinosInstaller"):
		return Engine.get_singleton("ReinosInstaller")
	return null

# ----------------------------------------------------------------------------------------------------------------
# aviso de versión nueva

func check() -> void:
	Settings.ensure_loaded()
	if not Settings.check_updates:
		return
	var cur := current_build()
	if cur <= 0:
		return   # compilación local: no hay con qué comparar
	if is_newer(Settings.known_build, cur):
		offer(Settings.known_build, Settings.known_size)
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
	var text := body.get_string_from_utf8()
	var remote := parse_release(text)
	var size := parse_size(text)
	Settings.last_update_check = int(Time.get_unix_time_from_system())
	if remote > 0:
		Settings.known_build = remote
		Settings.known_size = size
	Settings.save()
	if is_newer(remote, current_build()):
		offer(remote, size)

## Hay una build más nueva: se anuncia (salvo que ya se esté descargando o instalando otra).
func offer(build: int, size: int = 0) -> void:
	if state != IDLE and state != AVAILABLE:
		return
	target_build = build
	target_size = size
	_fails = 0
	_set_state(AVAILABLE)
	update_found.emit(build)

# ----------------------------------------------------------------------------------------------------------------
# lo que hace el botón del menú

## Un toque en el botón del menú, según en qué punto esté.
func activate() -> void:
	match state:
		AVAILABLE, RETRY, PERMISSION:
			start()
		DOWNLOADING:
			cancel()
		CONFIRMING:
			if _apk_path != "":
				_deliver()   # volvió de la ventana de Android sin instalar: se le vuelve a presentar
		FALLBACK:
			open_download()

func start() -> void:
	if target_build <= 0:
		return
	var inst := _installer()
	if inst == null:
		open_download()   # escritorio / compilación sin el plugin: navegador
		return
	if not bool(inst.call("canInstall")):
		inst.call("openInstallSettings")   # «Permitir de esta fuente»; al volver al juego continúa solo
		detail = ""
		_set_state(PERMISSION)
		return
	if _apk_path != "" and FileAccess.file_exists(_apk_path):
		_deliver()   # ya estaba descargado y verificado (p. ej. tras cancelar en la ventana de Android)
		return
	_begin_download()

func cancel() -> void:
	_stop_requests()
	_remove_part()
	_fails = 0
	progress = -1.0
	_set_state(AVAILABLE)

func open_download() -> void:
	if opener.is_valid():
		opener.call(PAGE_URL)
	else:
		OS.shell_open(PAGE_URL)

func _notification(what: int) -> void:
	# volver al juego desde los ajustes de Android con el permiso ya concedido: sigue sin pedir otro toque
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and state == PERMISSION:
		var inst := _installer()
		if inst != null and bool(inst.call("canInstall")):
			start()

# ----------------------------------------------------------------------------------------------------------------
# descarga: primero la suma SHA-256 (archivo diminuto), después el APK

func _url(suffix: String = "") -> String:
	return "%s/build-%d/%s%s" % [dl_base, target_build, APK_ASSET, suffix]

func _begin_download() -> void:
	DirAccess.make_dir_recursive_absolute(UPDATE_DIR)
	_part = "%s/reinos-%d.apk.part" % [UPDATE_DIR, target_build]
	_apk_path = ""
	_hash_want = ""
	progress = -1.0
	_last_pct = -1
	detail = ""
	_set_state(DOWNLOADING)
	_hreq = HTTPRequest.new()
	_hreq.timeout = TIMEOUT * 2.0
	_hreq.body_size_limit = 1024
	_hreq.max_redirects = 8
	add_child(_hreq)
	_hreq.request_completed.connect(_on_hash)
	if _hreq.request(_url(".sha256"), PackedStringArray(UA)) != OK:
		_fail("update_err_net")

func _on_hash(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if state != DOWNLOADING:
		return
	if is_instance_valid(_hreq):
		_hreq.queue_free()
	_hreq = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("update_err_net")
		return
	var m := RegEx.create_from_string("^\\s*([0-9a-fA-F]{64})(\\s|\\z)").search(body.get_string_from_utf8())
	if m == null:
		_fail("update_err_hash", true)
		return
	_hash_want = m.get_string(1).to_lower()
	_areq = HTTPRequest.new()
	_areq.download_file = _part
	_areq.download_chunk_size = 262144
	_areq.timeout = 0.0   # un APK de decenas de MB tarda lo que tarde; la «descarga parada» la vigila _process
	_areq.body_size_limit = MAX_APK
	_areq.max_redirects = 8
	_areq.use_threads = true
	add_child(_areq)
	_areq.request_completed.connect(_on_apk)
	_last_bytes = -1
	_last_move = Time.get_ticks_msec() / 1000.0
	if _areq.request(_url(), PackedStringArray(UA)) != OK:
		_fail("update_err_net")

func _process(_d: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	match state:
		DOWNLOADING:
			if _areq == null:
				return
			var got := _areq.get_downloaded_bytes()
			var total := _areq.get_body_size()
			if total <= 0:
				total = target_size
			if got != _last_bytes:
				_last_bytes = got
				_last_move = now
			elif now - _last_move > stall_secs:
				_fail("update_err_net")
				return
			progress = clampf(float(got) / float(total), 0.0, 1.0) if total > 0 else -1.0
			var pct := int(progress * 100.0) if progress >= 0.0 else -1
			if pct != _last_pct:
				_last_pct = pct
				state_changed.emit()
		INSTALLING, CONFIRMING:
			if now - _poll_t >= POLL_EVERY:
				_poll_t = now
				_poll_install(now)

func _on_apk(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if state != DOWNLOADING:
		return
	if is_instance_valid(_areq):
		_areq.queue_free()
	_areq = null
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("update_err_net")
		return
	progress = 1.0
	_set_state(VERIFYING)
	await get_tree().process_frame   # que el botón muestre «Comprobando» antes de calcular el hash
	await get_tree().process_frame
	if state != VERIFYING:
		return
	var n := 0
	var f := FileAccess.open(_part, FileAccess.READ)
	if f != null:
		n = f.get_length()
		f.close()
	if n < MIN_APK or n > MAX_APK or (target_size > 0 and n != target_size):
		_fail("update_err_size")
		return
	if FileAccess.get_sha256(_part).to_lower() != _hash_want:
		_fail("update_err_hash")
		return
	var final := "%s/reinos-%d.apk" % [UPDATE_DIR, target_build]
	if DirAccess.rename_absolute(_part, final) != OK:
		_fail("update_err_disk", true)
		return
	_apk_path = final
	_part = ""
	_fails = 0
	_deliver()

# ----------------------------------------------------------------------------------------------------------------
# entrega al instalador de Android

func _deliver() -> void:
	var inst := _installer()
	if inst == null:
		_fail("update_err_inst", true)
		return
	_install_t0 = Time.get_ticks_msec() / 1000.0
	_poll_t = _install_t0
	detail = ""
	_set_state(INSTALLING)
	var r := str(inst.call("install", ProjectSettings.globalize_path(_apk_path)))
	if r == "":
		return   # entregado: _process pregunta cómo va
	if r == "permiso":
		_set_state(PERMISSION)
		return
	_install_failed(r)

func _poll_install(now: float) -> void:
	var inst := _installer()
	if inst == null:
		return
	var s := str(inst.call("status"))
	if s == "confirmar":
		if state != CONFIRMING:
			_set_state(CONFIRMING)
	elif s == "ok":
		detail = ""
		_set_state(DONE)
	elif s.begins_with("error"):
		_install_failed(s)
	elif state == INSTALLING and now - _install_t0 > install_wait:
		_fail("update_err_install", true)

## "error:3:..." es que el jugador canceló en la ventana de Android: se puede reintentar con el mismo APK.
func _install_failed(r: String) -> void:
	push_warning("Instalador: " + r)
	if r.begins_with("error:3:"):
		detail = Lang.t("update_cancelled")
		_set_state(RETRY)
	else:
		detail = Lang.t("update_err_inst")
		_apk_path = ""
		_set_state(FALLBACK)

# ----------------------------------------------------------------------------------------------------------------

## Descarga fallida: un reintento antes de ofrecer el navegador (`hard`: sin reintento).
func _fail(key: String, hard: bool = false) -> void:
	_stop_requests()
	_remove_part()
	_fails += 1
	detail = Lang.t(key)
	progress = -1.0
	_set_state(FALLBACK if (hard or _fails >= 2) else RETRY)

func _stop_requests() -> void:
	for r: HTTPRequest in [_hreq, _areq]:
		if r != null and is_instance_valid(r):
			r.cancel_request()
			r.queue_free()
	_hreq = null
	_areq = null

func _remove_part() -> void:
	if _part != "" and FileAccess.file_exists(_part):
		DirAccess.remove_absolute(_part)

func _set_state(s: int) -> void:
	state = s
	set_process(s == DOWNLOADING or s == INSTALLING or s == CONFIRMING)
	state_changed.emit()

# ----------------------------------------------------------------------------------------------------------------
# textos del botón del menú

func label() -> String:
	match state:
		AVAILABLE:
			return Lang.t("update_available") % [target_build, (", " + size_text(target_size)) if target_size > 0 else ""]
		PERMISSION:
			return Lang.t("update_permission")
		DOWNLOADING:
			if progress >= 0.0:
				return Lang.t("update_downloading") % [target_build, int(progress * 100.0)]
			return Lang.t("update_downloading_nop") % target_build
		VERIFYING:
			return Lang.t("update_verifying")
		INSTALLING:
			return Lang.t("update_installing")
		CONFIRMING:
			return Lang.t("update_confirm")
		RETRY:
			return Lang.t("update_retry")
		FALLBACK:
			return Lang.t("update_browser")
		DONE:
			return Lang.t("update_done")
	return ""

func sub_text() -> String:
	match state:
		DOWNLOADING:
			return Lang.t("update_tap_cancel")
		PERMISSION:
			return Lang.t("update_permission_sub")
		CONFIRMING:
			return Lang.t("update_confirm_sub")
		RETRY, FALLBACK:
			return detail
	return ""
