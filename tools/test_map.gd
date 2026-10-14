extends SceneTree
func _init():
	var size := 192
	var seeds := [1, 2, 3, 42, 777]
	for sd in seeds:
		var t0 := Time.get_ticks_msec()
		var m := MapGen.generate(size, sd, 4)
		var dt := Time.get_ticks_msec() - t0
		if not m.get("ok", false):
			print("seed ", sd, " FAIL")
			continue
		var land: float = float(m["land_count"]) / float(size * size)
		print("seed ", sd, " ok in ", dt, " ms, attempts=", m["attempts"], " land=", snappedf(land*100.0, 0.1), "% main=", snappedf(float(m["main_size"])/float(size*size)*100.0,0.1), "% islands=", m["islands"].size(), " starts=", m["starts"])
		if sd == 2:
			var terrain: PackedByteArray = m["terrain"]
			var rtype: PackedByteArray = m["rtype"]
			var starts: Array = m["starts"]
			var lines: Array[String] = []
			for y in range(0, size, 4):
				var line := ""
				for x in range(0, size, 2):
					var ch := "~"
					var i := y * size + x
					if terrain[i] == Defs.T_SAND: ch = ","
					elif terrain[i] == Defs.T_GRASS: ch = "."
					# resumen de recursos en el bloque
					var tr := 0
					var go := false
					var fi := false
					for yy in range(y, min(y+4,size)):
						for xx in range(x, min(x+2,size)):
							var rt := rtype[yy*size+xx]
							if rt == Defs.R_TREE: tr += 1
							elif rt == Defs.R_GOLD: go = true
							elif rt == Defs.R_FISH: fi = true
					if tr >= 4: ch = "T"
					if go: ch = "$"
					if fi: ch = "f"
					for s in starts:
						if absi(s.x - x) < 3 and absi(s.y - y) < 4: ch = "@"
					line += ch
				lines.append(line)
			print("\n".join(lines))
	quit()
