extends Node
## Capturas del botón de actualización del menú en cada estado. Uso: ... res://tools/update_shot.tscn -- out=/tmp/upd [real=1 (además, toca el botón contra la API real de GitHub)]
## Escribe un res://data/build.json de mentira (build 35) mientras dura y lo borra al terminar.
func _ready() -> void:
	var out := "/tmp/upd"
	var real := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		if a == "real=1":
			real = true
	var bj_path := "res://data/build.json"
	var had_bj := FileAccess.file_exists(bj_path)
	if not had_bj:
		var bj := FileAccess.open(bj_path, FileAccess.WRITE)
		bj.store_string('{"build": "35 · captura"}\n')
		bj.close()
	Settings.ensure_loaded()
	var keep_check := Settings.check_updates
	Settings.check_updates = false   # la comprobación automática de abrir el menú no interviene: se fuerzan los estados a mano
	Settings.set_profile(1, get_window())
	var m := MenuScreen.new()
	add_child(m)
	await get_tree().create_timer(0.6).timeout
	var u: Updater = m._upd
	u.target_build = 36
	u.target_size = 51838221
	var cases := [
		["0_reposo", Updater.IDLE, -1.0, ""],
		["0b_buscando", Updater.CHECKING, -1.0, ""],
		["0c_al_dia", Updater.UPTODATE, -1.0, ""],
		["0d_fallo", Updater.CHECK_FAIL, -1.0, Lang.t("update_check_net")],
		["1_aviso", Updater.AVAILABLE, -1.0, ""],
		["2_permiso", Updater.PERMISSION, -1.0, ""],
		["3_descarga", Updater.DOWNLOADING, 0.42, ""],
		["4_comprobando", Updater.VERIFYING, 1.0, ""],
		["5_confirmar", Updater.CONFIRMING, -1.0, ""],
		["6_reintento", Updater.RETRY, -1.0, Lang.t("update_err_net")],
		["7_navegador", Updater.FALLBACK, -1.0, Lang.t("update_err_hash")],
	]
	for c in cases:
		u.progress = float(c[2])
		u.detail = String(c[3])
		u._set_state(int(c[1]))
		u.set_process(false)   # sin descarga real: solo se pinta el estado
		await get_tree().create_timer(0.25).timeout
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, c[0]])
	if real:
		# de verdad: el botón en reposo, un toque y la respuesta de api.github.com (build instalada «35»)
		u.target_build = 0
		u.detail = ""
		u._set_state(Updater.IDLE)
		u.activate()
		var t_end := Time.get_ticks_msec() + 15000
		while Time.get_ticks_msec() < t_end and u.state == Updater.CHECKING:
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		print("REAL estado=", u.state, " build=", u.target_build, " detalle=", u.detail)
		get_viewport().get_texture().get_image().save_png("%s_9_real.png" % out)
	Settings.check_updates = keep_check
	Settings.save()
	if not had_bj:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bj_path))
	print("SHOTS ", cases.size())
	get_tree().quit()
