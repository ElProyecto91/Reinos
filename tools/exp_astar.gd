extends SceneTree
func _init():
	var a := AStarGrid2D.new()
	a.region = Rect2i(0,0,192,192)
	a.cell_size = Vector2(1,1)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	var t0 := Time.get_ticks_usec()
	a.update()
	print("update us: ", Time.get_ticks_usec()-t0)
	# wall with gap
	for y in range(0,192):
		if y != 100: a.set_point_solid(Vector2i(96,y), true)
	t0 = Time.get_ticks_usec()
	var p = a.get_id_path(Vector2i(5,5), Vector2i(185,185))
	print("long path len ", p.size(), " us ", Time.get_ticks_usec()-t0)
	# solid target
	a.set_point_solid(Vector2i(50,50), true)
	var p2 = a.get_id_path(Vector2i(40,40), Vector2i(50,50))
	print("solid target no partial: ", p2.size())
	var p3 = a.get_id_path(Vector2i(40,40), Vector2i(50,50), true)
	print("solid target partial: ", p3.size(), " last ", (p3[p3.size()-1] if p3.size()>0 else null))
	# solid start
	var p4 = a.get_id_path(Vector2i(50,50), Vector2i(60,60))
	print("solid start: ", p4.size())
	var p5 = a.get_id_path(Vector2i(50,50), Vector2i(60,60), true)
	print("solid start partial: ", p5.size())
	# unreachable target (enclosed)
	for x in range(150,155):
		for y in range(150,155):
			if x==150 or x==154 or y==150 or y==154: a.set_point_solid(Vector2i(x,y), true)
	var p6 = a.get_id_path(Vector2i(10,10), Vector2i(152,152))
	print("unreachable no partial: ", p6.size())
	var p7 = a.get_id_path(Vector2i(10,10), Vector2i(152,152), true)
	print("unreachable partial: ", p7.size(), " last ", (p7[p7.size()-1] if p7.size()>0 else null))
	# many short paths timing
	t0 = Time.get_ticks_usec()
	for i in 200:
		a.get_id_path(Vector2i(10+i%50,10), Vector2i(60+i%30,40))
	print("200 short paths us: ", Time.get_ticks_usec()-t0)
	quit()
