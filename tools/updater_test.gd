extends SceneTree
## Pruebas del aviso de actualización: análisis de la respuesta (incluida basura maliciosa) y
## recorrido completo contra tools/mock_release_server.py (puerto en el argumento port=N).
var fails := 0
var port := 18765
var got := -1

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://data/build.json"))
	Settings.check_updates = keep[0]
	Settings.last_update_check = keep[1]
	Settings.known_build = keep[2]
	Settings.save()
	print("DONE fails=", fails)
	quit()
