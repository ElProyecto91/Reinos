extends Node2D
var frames := 0
func _draw():
	draw_rect(Rect2(0,0,1280,720), Color(0.2,0.5,0.3))
	draw_circle(Vector2(640,360), 100, Color.RED)
func _process(_d):
	queue_redraw()
	frames += 1
	if frames == 5:
		var img := get_viewport().get_texture().get_image()
		print("img size ", img.get_size() if img else "null")
		if img: img.save_png("/tmp/shot_test.png")
		get_tree().quit()
