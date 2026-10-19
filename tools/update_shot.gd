extends Node
## Capturas del botón de actualización del menú en cada estado. Uso: ... res://tools/update_shot.tscn -- out=/tmp/upd
func _ready() -> void:
	var out := "/tmp/upd"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	Settings.ensure_loaded()
	Settings.set_profile(1, get_window())
	var m := MenuScreen.new()
	add_child(m)
	await get_tree().create_timer(0.6).timeout
	var u: Updater = m._upd
	u.target_build = 31
	u.target_size = 39000000
	var cases := [
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
	print("SHOTS ", cases.size())
	get_tree().quit()
