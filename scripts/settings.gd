class_name Settings
extends RefCounted
## Ajustes de rendimiento y batería. Se guardan en user://ajustes.cfg.
##
## Qué gasta batería en un juego 2D como este (de más a menos):
##   1. Pantalla encendida (no se puede reducir desde el juego).
##   2. Fotogramas por segundo y número de píxeles que dibuja la GPU.
##   3. CPU: simulación, dibujo de unidades y refresco de la interfaz.
##   4. Audio y bucles de espera cuando no pasa nada (pausa, menús).
## Cada perfil actúa sobre 2, 3 y 4. Los valores no se han medido en un móvil real.

const PATH := "user://ajustes.cfg"
const BASE_SIZE := Vector2i(1280, 720)
const IDLE_FPS := 15          # menús, pausa y fin de partida: el motor casi no hace nada
const CALM_AFTER := 6.0       # segundos sin tocar la pantalla para pasar a los fps «tranquilos» del perfil

# fps: tope de fotogramas tocando la pantalla · fps_calm: tope tras CALM_AFTER s sin tocarla (mirando la partida);
# al tocar vuelve a fps · lowres: dibujar a ~720p y escalar · hud: segundos entre refrescos
# del panel · fog: segundos entre actualizaciones de niebla · idle: segundos sin tocar hasta
# pausar solo (0 = nunca)
const PROFILES := [
	{"id": "ahorro", "fps": 20, "fps_calm": 15, "lowres": true, "hud": 0.30, "fog": 0.6, "idle": 90.0},
	{"id": "equilibrado", "fps": 30, "fps_calm": 20, "lowres": true, "hud": 0.20, "fog": 0.4, "idle": 180.0},
	{"id": "alta", "fps": 60, "fps_calm": 30, "lowres": false, "hud": 0.12, "fog": 0.3, "idle": 300.0},
]

static var profile := 1
static var auto_pause := true
static var check_updates := true      # aviso de versión nueva (única conexión a Internet del juego)
static var last_update_check := 0     # segundos Unix de la última comprobación
static var known_build := 0           # última build publicada que se conoce
static var civ := "random"             # civilización elegida en el menú ("random" = al azar)
static var _loaded := false

static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		profile = clampi(int(cf.get_value("rendimiento", "perfil", 1)), 0, PROFILES.size() - 1)
		auto_pause = bool(cf.get_value("rendimiento", "pausa_auto", true))
		check_updates = bool(cf.get_value("actualizaciones", "avisar", true))
		last_update_check = int(cf.get_value("actualizaciones", "ultima", 0))
		known_build = int(cf.get_value("actualizaciones", "conocida", 0))
		var cv := String(cf.get_value("partida", "civilizacion", "random"))
		civ = cv if (cv == "random" or Civs.valid(cv)) else "random"

static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("rendimiento", "perfil", profile)
	cf.set_value("rendimiento", "pausa_auto", auto_pause)
	cf.set_value("actualizaciones", "avisar", check_updates)
	cf.set_value("actualizaciones", "ultima", last_update_check)
	cf.set_value("actualizaciones", "conocida", known_build)
	cf.set_value("partida", "civilizacion", civ)
	cf.save(PATH)

static func cur() -> Dictionary:
	ensure_loaded()
	return PROFILES[profile]

static func v(key: String) -> Variant:
	return cur()[key]

static func set_profile(i: int, win: Window = null) -> void:
	ensure_loaded()
	profile = clampi(i, 0, PROFILES.size() - 1)
	save()
	apply_display(win)

static func cycle_profile(win: Window = null) -> void:
	ensure_loaded()
	set_profile((profile + 1) % PROFILES.size(), win)

static func profile_name(i: int = -1) -> String:
	ensure_loaded()
	return Lang.t("perf_" + String(PROFILES[profile if i < 0 else i]["id"]))

## Identificador de la compilación (lo escribe el flujo de GitHub en data/build.json).
static func build_label() -> String:
	var path := "res://data/build.json"
	if FileAccess.file_exists(path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary and (d as Dictionary).has("build"):
			return "build %s" % str((d as Dictionary)["build"])
	return "build local"

## Resolución interna: en perfiles de ahorro se dibuja a ~720p y se escala a la pantalla
## (la GPU pinta 2-4 veces menos píxeles). Las posiciones táctiles no cambian.
static func apply_display(win: Window = null) -> void:
	ensure_loaded()
	if win == null:
		var ml := Engine.get_main_loop()
		if ml is SceneTree:
			win = (ml as SceneTree).root
	if win == null:
		return
	win.content_scale_size = BASE_SIZE
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT if bool(v("lowres")) else Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

## Mientras se juega: fps normales o «tranquilos» (sin tocar la pantalla; las unidades siguen interpoladas, solo
## se dibujan menos fotogramas por segundo). Al tocar vuelve el tope normal del perfil.
static func set_calm(calm: bool) -> void:
	ensure_loaded()
	Engine.max_fps = int(v("fps_calm")) if calm else int(v("fps"))

## Modo de ejecución del motor. playing = partida en marcha y sin pausa.
static func set_playing(playing: bool) -> void:
	ensure_loaded()
	OS.low_processor_usage_mode = true
	OS.low_processor_usage_mode_sleep_usec = 6900
	Engine.max_fps = int(v("fps")) if playing else IDLE_FPS
	# Mientras se juega la pantalla no debe apagarse; en pausa y menús sí puede.
	DisplayServer.screen_set_keep_on(playing)
