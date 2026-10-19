extends RefCounted
## Instalador de mentira para tools/updater_test.gd: mismos métodos que el plugin de Android (ReinosInstaller).
var can := true
var result := ""                      # lo que devuelve install(): "", "permiso" o "error:..."
var status_seq: Array = []            # lo que va devolviendo status() (el último se repite)
var installed_path := ""
var calls := 0
var settings_opened := 0
var _n := 0

func canInstall() -> bool:
	return can

func openInstallSettings() -> void:
	settings_opened += 1

func install(path: String) -> String:
	installed_path = path
	calls += 1
	_n = 0
	return result

func status() -> String:
	if status_seq.is_empty():
		return ""
	var i := mini(_n, status_seq.size() - 1)
	_n += 1
	return str(status_seq[i])
