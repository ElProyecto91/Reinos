extends SceneTree
func _stats(size:int, sd:int) -> String:
	var m := MapGen.generate(size, sd, 4)
	if not m.get("ok", false): return "FAIL"
	var comp: PackedInt32Array = m["comp"]
	var counts := {}
	for c in comp:
		if c >= 0: counts[c] = counts.get(c, 0) + 1
	var big := 0
	var small := 0
	for c in counts:
		if c == m["main_comp"]: continue
		if counts[c] >= 40: big += 1
		elif counts[c] >= 10: small += 1
	var tot := size*size
	return "land=%d%% main=%d%% isl40+=%d isl10+=%d att=%d" % [int(100.0*m["land_count"]/tot), int(100.0*m["main_size"]/tot), big, small, m["attempts"]]
func _init():
	var combos := [
		[3.0, 0.36, 1.6, 3.0, 0.30],
		[3.4, 0.40, 1.4, 3.0, 0.25],
		[3.4, 0.45, 1.8, 3.5, 0.25],
		[4.0, 0.45, 1.8, 3.5, 0.25],
		[3.6, 0.50, 2.0, 4.0, 0.20],
	]
	for c in combos:
		MapGen.freq_k = c[0]; MapGen.bias_base = c[1]; MapGen.fall_k = c[2]; MapGen.fall_pow = c[3]; MapGen.rad_k = c[4]
		print("params ", c)
		for sd in [1, 2, 3, 42, 777]:
			print("  seed ", sd, " ", _stats(192, sd))
	quit()
