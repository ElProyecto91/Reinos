extends SceneTree
# Compara el rasterizador nuevo (por tramos) con el de referencia: diferencia y tiempo.
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 400
	var shapes: Array = []
	for i in n:
		var kind := rng.randi() % 4
		var col := Color(rng.randf(), rng.randf(), rng.randf(), 1.0 if rng.randf() < 0.85 else rng.randf_range(0.2, 0.9))
		match kind:
			0: shapes.append([0, rng.randf_range(10, 118), rng.randf_range(10, 118), rng.randf_range(1.0, 22.0), rng.randf_range(1.0, 22.0), col])
			1: shapes.append([1, rng.randf_range(0, 128), rng.randf_range(0, 128), rng.randf_range(0, 128), rng.randf_range(0, 128), rng.randf_range(0.6, 12.0), col])
			2: shapes.append([2, rng.randf_range(0, 128), rng.randf_range(0, 128), rng.randf_range(0, 128), rng.randf_range(0, 128), rng.randf_range(0, 128), rng.randf_range(0, 128), col])
			3: shapes.append([1, rng.randf_range(0, 128), rng.randf_range(0, 128), rng.randf_range(0, 128), rng.randf_range(0, 128), rng.randf_range(0.6, 3.0), col])
	var a := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var b := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var worst := 0.0
	var sum_diff := 0.0
	var cnt := 0
	var t_old := 0
	var t_new := 0
	for sh in shapes:
		a.fill(Color(0.3, 0.5, 0.2, 1.0))
		b.fill(Color(0.3, 0.5, 0.2, 1.0))
		var t0 := Time.get_ticks_usec()
		match sh[0]:
			0: PainterRef.ellipse(a, sh[1], sh[2], sh[3], sh[4], sh[5])
			1: PainterRef.line(a, sh[1], sh[2], sh[3], sh[4], sh[5], sh[6])
			2: PainterRef.tri(a, sh[1], sh[2], sh[3], sh[4], sh[5], sh[6], sh[7])
		var t1 := Time.get_ticks_usec()
		match sh[0]:
			0: Painter.ellipse(b, sh[1], sh[2], sh[3], sh[4], sh[5])
			1: Painter.line(b, sh[1], sh[2], sh[3], sh[4], sh[5], sh[6])
			2: Painter.tri(b, sh[1], sh[2], sh[3], sh[4], sh[5], sh[6], sh[7])
		var t2 := Time.get_ticks_usec()
		t_old += t1 - t0
		t_new += t2 - t1
		var da := a.get_data()
		var db := b.get_data()
		var bad := 0
		var shape_worst := 0
		for k in da.size():
			var d := absi(int(da[k]) - int(db[k]))
			if d > shape_worst:
				shape_worst = d
			if d > 24:
				bad += 1
		sum_diff += float(bad)
		if shape_worst > worst:
			worst = shape_worst
		cnt += 1
		if bad > 6:
			print("shape kind ", sh[0], " big diff bytes=", bad, " worst=", shape_worst, " ", sh)
	print("worst byte diff ", worst, " avg bad bytes/shape ", sum_diff / float(cnt))
	print("time old us ", t_old, " new us ", t_new, " speedup x", float(t_old) / float(maxi(1, t_new)))
	quit()
