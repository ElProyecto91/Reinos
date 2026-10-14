extends SceneTree
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	var a := Art.new()
	a.build()
	print("ART build ms: ", Time.get_ticks_msec() - t0)
	quit()
