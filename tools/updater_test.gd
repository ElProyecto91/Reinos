extends SceneTree
## Pruebas del aviso de actualización: análisis de la respuesta (incluida basura maliciosa) y
## recorrido completo contra tools/mock_release_server.py (puerto en el argumento port=N).
const FakeInstaller := preload("res://tools/fake_installer.gd")
const DIR := "user://update"
var fails := 0
var port := 18765
var got := -1
var opened: Array = []
var expected := ""   # SHA-256 del «APK» que sirve el servidor de pruebas

func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + name)
	if not ok:
		fails += 1

func _on_found(b: int) -> void:
	got = b

func _run_case(path: String, wait_s: float) -> int:
	got = -1
	Settings.last_update_check = 0
	Settings.known_build = 0
	var u := Updater.new()
	u.api_url = "http://127.0.0.1:%d%s" % [port, path]
	u.update_found.connect(_on_found)
	root.add_child(u)
	u.check()
	var t_end := Time.get_ticks_msec() + int(wait_s * 1000.0)
	while Time.get_ticks_msec() < t_end and got < 0:
		await process_frame
	u.queue_free()
	return got

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("port="):
			port = int(a.substr(5))
	_main()

func _main() -> void:
	await process_frame   # el árbol de escenas debe estar en marcha para HTTPRequest
	# --- análisis puro
	check("tag válido", Updater.parse_release('{"tag_name":"build-12","draft":false,"prerelease":false}') == 12)
	check("prerelease ignorada", Updater.parse_release('{"tag_name":"build-12","prerelease":true}') == -1)
	check("borrador ignorado", Updater.parse_release('{"tag_name":"build-12","draft":true}') == -1)
	check("tag con inyección", Updater.parse_release('{"tag_name":"build-12; rm -rf /"}') == -1)
	check("tag con salto de línea", Updater.parse_release('{"tag_name":"build-12\\n"}') == -1)
	check("tag con prefijo distinto", Updater.parse_release('{"tag_name":"v1.2"}') == -1)
	check("tag vacío", Updater.parse_release('{"tag_name":"build-"}') == -1)
	check("número demasiado largo", Updater.parse_release('{"tag_name":"build-1234567"}') == -1)
	check("tag numérico (no texto)", Updater.parse_release('{"tag_name":12}') == -1)
	check("sin tag", Updater.parse_release('{"name":"x"}') == -1)
	check("no es JSON", Updater.parse_release("<html>hola</html>") == -1)
	check("JSON no es objeto", Updater.parse_release("[1,2,3]") == -1)
	check("vacío", Updater.parse_release("") == -1)
	check("demasiado grande", Updater.parse_release('{"tag_name":"build-5","pad":"%s"}' % "x".repeat(300000)) == -1)
	check("is_newer 5>3", Updater.is_newer(5, 3))
	check("is_newer 3>3 no", not Updater.is_newer(3, 3))
	check("is_newer remota inválida", not Updater.is_newer(-1, 3))
	check("is_newer build local (0)", not Updater.is_newer(9, 0))
	check("dirección de descarga fija y https", Updater.PAGE_URL.begins_with("https://github.com/ElProyecto91/reinos/"))
	check("descargas desde el host fijo", Updater.DEFAULT_DL.begins_with("https://github.com/ElProyecto91/reinos/releases/download"))
	var rel := '{"tag_name":"build-7","assets":[{"name":"reinos.apk.sha256","size":77},{"name":"reinos.apk","size":38864443}]}'
	check("tamaño del APK", Updater.parse_size(rel) == 38864443)
	check("tamaño: sin assets", Updater.parse_size('{"tag_name":"build-7"}') == 0)
	check("tamaño: otro nombre", Updater.parse_size('{"assets":[{"name":"otro.apk","size":38864443}]}') == 0)
	check("tamaño: demasiado pequeño", Updater.parse_size('{"assets":[{"name":"reinos.apk","size":100}]}') == 0)
	check("tamaño: absurdo", Updater.parse_size('{"assets":[{"name":"reinos.apk","size":9999999999}]}') == 0)
	check("tamaño: no es número", Updater.parse_size('{"assets":[{"name":"reinos.apk","size":"mucho"}]}') == 0)
	check("tamaño: no es JSON", Updater.parse_size("<html>") == 0)
	check("texto de tamaño", Updater.size_text(38864443) == "37 MB")
	# --- recorrido completo (build instalada = 3)
	var bj := FileAccess.open("res://data/build.json", FileAccess.WRITE)
	bj.store_string('{"build": "3 · test"}\n')
	bj.close()
	check("build instalada leída", Updater.current_build() == 3)
	Settings.ensure_loaded()
	var keep := [Settings.check_updates, Settings.last_update_check, Settings.known_build]
	Settings.check_updates = true
	check("respuesta buena avisa (99999)", await _run_case("/ok", 4.0) == 99999)
	check("se recuerda la build conocida", Settings.known_build == 99999)
	check("misma build no avisa", await _run_case("/same", 2.5) == -1)
	check("etiqueta maliciosa no avisa", await _run_case("/evil", 2.5) == -1)
	check("HTML no avisa", await _run_case("/html", 2.5) == -1)
	check("404 (repo privado) no avisa", await _run_case("/nada", 2.5) == -1)
	check("respuesta enorme no avisa", await _run_case("/big", 3.5) == -1)
	Settings.check_updates = false
	check("desactivado no consulta", await _run_case("/ok", 1.5) == -1)
	Settings.check_updates = true
	# la comprobación no se repite antes de 6 h
	Settings.last_update_check = int(Time.get_unix_time_from_system())
	Settings.known_build = 0
	var u2 := Updater.new()
	u2.api_url = "http://127.0.0.1:%d/ok" % port
	var hits := [0]
	u2.update_found.connect(func(_b: int) -> void: hits[0] += 1)
	root.add_child(u2)
	u2.check()
	for i in 90:
		await process_frame
	check("no repite antes de 6 h", hits[0] == 0)
	await _download_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://data/build.json"))
	Settings.check_updates = keep[0]
	Settings.last_update_check = keep[1]
	Settings.known_build = keep[2]
	Settings.save()
	print("DONE fails=", fails)
	quit()

# ----------------------------------------------------------------------------------------------------------------
# descarga + verificación + entrega al instalador (con un instalador de mentira y el servidor de pruebas)

func _clean_dir() -> void:
	if DirAccess.dir_exists_absolute(DIR):
		var d := DirAccess.open(DIR)
		for f in d.get_files():
			d.remove(f)

func _mk(base: String, fake: Object, size: int = 0) -> Updater:
	var u := Updater.new()
	u.dl_base = "http://127.0.0.1:%d/%s" % [port, base]
	u.installer = fake
	u.opener = func(url: String) -> void: opened.append(url)
	u.stall_secs = 2.5
	u.install_wait = 2.0
	root.add_child(u)
	u.offer(5, size)
	return u

func _wait_state(u: Updater, states: Array, secs: float) -> bool:
	var t_end := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < t_end and not (u.state in states):
		await process_frame
	return u.state in states

func _download_tests() -> void:
	var blob := PackedByteArray()
	blob.resize(1500000)
	for i in 1500000:
		blob[i] = (i * 7 + 3) % 256
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	hc.update(blob)
	expected = hc.finish().hex_encode()
	_clean_dir()

	# --- todo bien: suma, descarga, hash, entrega y ventana de Android
	var fk := FakeInstaller.new()
	fk.status_seq = ["pendiente", "confirmar"]
	var u := _mk("dl", fk)
	check("avisa con la build", u.state == Updater.AVAILABLE and u.label().contains("5"))
	u.activate()
	check("empieza a descargar", u.state == Updater.DOWNLOADING)
	check("llega a la ventana de Android", await _wait_state(u, [Updater.CONFIRMING], 20.0))
	check("el instalador recibe el APK", fk.installed_path.ends_with("/update/reinos-5.apk") and fk.calls == 1)
	check("el APK guardado es idéntico", FileAccess.get_sha256(DIR + "/reinos-5.apk") == expected)
	check("sin restos .part", not FileAccess.file_exists(DIR + "/reinos-5.apk.part"))
	check("el botón pide confirmar", u.label().contains("Instalar") and u.sub_text() != "")
	u.activate()   # el jugador volvió sin instalar: se le vuelve a abrir
	check("se entrega otra vez sin volver a descargar", fk.calls == 2 and u.state == Updater.INSTALLING)
	check("y vuelve a pedir confirmación", await _wait_state(u, [Updater.CONFIRMING], 5.0))
	u.queue_free()

	# --- GitHub responde con una redirección a otro sitio
	_clean_dir()
	fk = FakeInstaller.new()
	fk.status_seq = ["confirmar"]
	u = _mk("dlredir", fk)
	u.activate()
	check("sigue la redirección", await _wait_state(u, [Updater.CONFIRMING], 20.0))
	check("APK idéntico tras la redirección", FileAccess.get_sha256(DIR + "/reinos-5.apk") == expected)
	u.queue_free()

	# --- descarga lenta: la barra avanza y tocar cancela
	_clean_dir()
	fk = FakeInstaller.new()
	fk.status_seq = ["confirmar"]
	u = _mk("dlslow", fk)
	var seen := []
	u.state_changed.connect(func() -> void:
		if u.state == Updater.DOWNLOADING and u.progress > 0.0 and u.progress < 1.0:
			seen.append(u.progress))
	u.activate()
	var t_end := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < t_end and seen.size() < 2:
		await process_frame
	check("la barra avanza (%d lecturas)" % seen.size(), seen.size() >= 2 and float(seen[-1]) > float(seen[0]))
	check("el botón muestra el porcentaje", u.label().contains("%"))
	u.activate()   # cancelar
	check("tocar durante la descarga cancela", u.state == Updater.AVAILABLE)
	await process_frame
	check("cancelar borra el resto de la descarga", not FileAccess.file_exists(DIR + "/reinos-5.apk.part"))
	check("cancelar no entrega nada", fk.calls == 0)
	u.activate()   # y se puede volver a empezar y terminar
	check("tras cancelar se puede reintentar hasta el final", await _wait_state(u, [Updater.CONFIRMING], 20.0))
	u.queue_free()

	# --- falta el permiso de «instalar apps desconocidas»
	_clean_dir()
	fk = FakeInstaller.new()
	fk.can = false
	fk.status_seq = ["confirmar"]
	u = _mk("dl", fk)
	u.activate()
	check("sin permiso: abre los ajustes y espera", u.state == Updater.PERMISSION and fk.settings_opened == 1)
	check("sin permiso no descarga nada", not FileAccess.file_exists(DIR + "/reinos-5.apk.part") and fk.calls == 0)
	check("explica qué activar", u.sub_text().contains("Permitir"))
	u._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)   # vuelve al juego sin conceder el permiso
	check("sigue esperando si no lo concedió", u.state == Updater.PERMISSION)
	fk.can = true
	u._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)   # vuelve al juego con el permiso concedido
	check("al volver con permiso continúa solo", u.state == Updater.DOWNLOADING)
	check("y llega a la ventana de Android", await _wait_state(u, [Updater.CONFIRMING], 20.0))
	u.queue_free()

	# --- el instalador dice «permiso» aunque canInstall() dijo que sí (carrera con los ajustes)
	_clean_dir()
	fk = FakeInstaller.new()
	fk.result = "permiso"
	u = _mk("dl", fk)
	u.activate()
	check("«permiso» del instalador vuelve a esperar", await _wait_state(u, [Updater.PERMISSION], 20.0))
	u.queue_free()

	# --- suma incorrecta: se descarta, un reintento y después el navegador
	_clean_dir()
	opened.clear()
	fk = FakeInstaller.new()
	u = _mk("dlbad", fk)
	u.activate()
	check("suma distinta: se rechaza", await _wait_state(u, [Updater.RETRY], 20.0))
	check("el motivo se explica", u.sub_text().contains("suma"))
	check("no queda nada del APK malo", not FileAccess.file_exists(DIR + "/reinos-5.apk") and not FileAccess.file_exists(DIR + "/reinos-5.apk.part"))
	check("el APK malo nunca llega al instalador", fk.calls == 0)
	u.activate()
	check("segundo fallo: ofrece el navegador", await _wait_state(u, [Updater.FALLBACK], 20.0))
	u.activate()
	check("en el navegador se abre la página fija", opened == [Updater.PAGE_URL])
	u.queue_free()

	# --- descarga cortada a la mitad, 404, tamaño que no coincide, descarga parada
	for c in [["dlshort", 0, "cortada"], ["dl404", 0, "404"], ["dl", 1500001, "de otro tamaño"], ["dlstall", 0, "parada"]]:
		_clean_dir()
		fk = FakeInstaller.new()
		u = _mk(String(c[0]), fk, int(c[1]))
		u.activate()
		check("descarga %s: falla y se puede reintentar" % c[2], await _wait_state(u, [Updater.RETRY], 20.0))
		check("descarga %s: sin restos" % c[2], not FileAccess.file_exists(DIR + "/reinos-5.apk.part") and not FileAccess.file_exists(DIR + "/reinos-5.apk"))
		check("descarga %s: nada al instalador" % c[2], fk.calls == 0)
		u.queue_free()

	# --- errores del instalador
	_clean_dir()
	fk = FakeInstaller.new()
	fk.result = "error:java.lang.SecurityException: boom"
	u = _mk("dl", fk)
	u.activate()
	check("error al entregar: ofrece el navegador", await _wait_state(u, [Updater.FALLBACK], 20.0))
	check("el motivo del instalador se muestra", u.sub_text().contains("SecurityException") and not u.sub_text().contains("%s"))
	u.queue_free()

	_clean_dir()
	fk = FakeInstaller.new()
	fk.status_seq = ["pendiente", "confirmar", "error:3:INSTALL_FAILED_ABORTED"]
	u = _mk("dl", fk)
	u.activate()
	check("el jugador cancela en Android: se puede reintentar", await _wait_state(u, [Updater.RETRY], 20.0))
	check("cancelar no es un error", u.sub_text().contains("cancelada"))
	fk.status_seq = ["confirmar"]
	var calls_before := fk.calls
	u.activate()
	check("reintentar reutiliza el APK ya verificado", fk.calls == calls_before + 1 and await _wait_state(u, [Updater.CONFIRMING], 5.0))
	u.queue_free()

	_clean_dir()
	fk = FakeInstaller.new()
	fk.status_seq = ["pendiente"]
	u = _mk("dl", fk)
	u.activate()
	check("el instalador no responde: navegador", await _wait_state(u, [Updater.FALLBACK], 25.0))
	u.queue_free()

	_clean_dir()
	fk = FakeInstaller.new()
	fk.status_seq = ["error:5:INSTALL_FAILED_UPDATE_INCOMPATIBLE"]
	u = _mk("dl", fk)
	u.activate()
	check("firma distinta: Android la rechaza y se ofrece el navegador", await _wait_state(u, [Updater.FALLBACK], 20.0))
	u.queue_free()

	# --- sin instalador (escritorio / compilación local): directo al navegador
	opened.clear()
	u = Updater.new()
	u.opener = func(url: String) -> void: opened.append(url)
	root.add_child(u)
	u.offer(5, 0)
	check("sin plugin no hay instalador", not u.has_installer())
	u.activate()
	check("sin plugin: abre el navegador y no descarga", opened == [Updater.PAGE_URL] and u.state == Updater.AVAILABLE)
	u.queue_free()

	# --- no se pisa una descarga en curso con un aviso nuevo
	_clean_dir()
	fk = FakeInstaller.new()
	u = _mk("dlslow", fk)
	u.activate()
	u.offer(6, 0)
	check("un aviso nuevo no interrumpe la descarga", u.state == Updater.DOWNLOADING and u.target_build == 5)
	u.cancel()
	u.queue_free()

	# --- limpieza de descargas viejas
	_clean_dir()
	DirAccess.make_dir_recursive_absolute(DIR)
	for n in ["reinos-2.apk", "reinos-3.apk", "reinos-9.apk", "reinos-9.apk.part", "reinos-x.apk", "otra.txt"]:
		var f := FileAccess.open(DIR + "/" + n, FileAccess.WRITE)
		f.store_string("x")
		f.close()
	Updater.cleanup_old(5)
	var left := Array(DirAccess.get_files_at(DIR))
	left.sort()
	check("limpieza: solo queda la build más nueva", left == ["reinos-9.apk"])
	_clean_dir()
