extends Node
## Punto de entrada: alterna entre el menú y la partida.

var menu: MenuScreen
var game: Game

func _ready() -> void:
	Settings.ensure_loaded()
	Settings.apply_display(get_window())
	Settings.set_playing(false)
	var args := OS.get_cmdline_user_args()
	if "--auto" in args:
		var cfg := {"size": 128, "seed": 7, "events": true, "players": [
			{"human": true, "team": 0, "diff": 1, "name": "Tú"},
			{"human": false, "team": 1, "diff": 1, "name": "Rojo"}]}
		for a in args:
			if a.begins_with("seed="):
				cfg["seed"] = int(a.substr(5))
			elif a.begins_with("size="):
				cfg["size"] = int(a.substr(5))
		_start_game(cfg)
		return
	_show_menu()

func _show_menu() -> void:
	Settings.set_playing(false)
	menu = MenuScreen.new()
	menu.play_pressed.connect(_start_game)
	menu.quit_pressed.connect(func() -> void: get_tree().quit())
	add_child(menu)

func _start_game(cfg: Dictionary) -> void:
	if menu != null:
		menu.queue_free()
		menu = null
	game = Game.new()
	game.exit_requested.connect(_back_to_menu)
	add_child(game)
	game.start(cfg)

func _back_to_menu() -> void:
	if game != null:
		game.queue_free()
		game = null
	_show_menu()
