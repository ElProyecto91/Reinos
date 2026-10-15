class_name Painter
extends RefCounted
## Rasterizador 2D mínimo sobre Image (formas con bordes suavizados).
## Sirve para generar los sprites por código: no hay archivos de arte (coste 0).

static func _over(img: Image, x: int, y: int, c: Color, cov: float) -> void:
	var sa := c.a * cov
	if sa <= 0.003:
		return
	if sa >= 0.997:
		img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
		return
	var d := img.get_pixel(x, y)
	var oa := sa + d.a * (1.0 - sa)
	img.set_pixel(x, y, Color(
		(c.r * sa + d.r * d.a * (1.0 - sa)) / oa,
		(c.g * sa + d.g * d.a * (1.0 - sa)) / oa,
		(c.b * sa + d.b * d.a * (1.0 - sa)) / oa,
		oa))

static func disc(img: Image, cx: float, cy: float, r: float, col: Color) -> void:
	ellipse(img, cx, cy, r, r, col)

static func ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := maxi(0, int(floor(cx - rx - 1.0)))
	var x1 := mini(w - 1, int(ceil(cx + rx + 1.0)))
	var y0 := maxi(0, int(floor(cy - ry - 1.0)))
	var y1 := mini(h - 1, int(ceil(cy + ry + 1.0)))
	var rm := minf(rx, ry)
	var solid_col := col.a >= 0.997 and rm >= 1.5
	var dout := 1.0 + 0.5 / rm
	var dout2 := dout * dout
	var din := 1.0 - 0.5 / rm
	var din2 := din * din
	var fill := Color(col.r, col.g, col.b, 1.0)
	for y in range(y0, y1 + 1):
		var dy := (y + 0.5 - cy) / ry
		var dy2 := dy * dy
		if dy2 >= dout2:
			continue
		var xo := rx * sqrt(dout2 - dy2)
		var xa := maxi(x0, int(ceil(cx - xo - 0.5)))
		var xb := mini(x1, int(floor(cx + xo - 0.5)))
		if xa > xb:
			continue
		var ia := xb + 1
		var ib := xb
		if solid_col and dy2 < din2:
			var xi := rx * sqrt(din2 - dy2)
			ia = maxi(xa, int(ceil(cx - xi - 0.5)))
			ib = mini(xb, int(floor(cx + xi - 0.5)))
			if ia <= ib:
				img.fill_rect(Rect2i(ia, y, ib - ia + 1, 1), fill)
			else:
				ia = xb + 1
				ib = xb
		# píxeles del borde (y todos los de la fila si no hay interior): cobertura exacta
		var x := xa
		while x <= xb:
			if x == ia:
				x = ib + 1
				continue
			var dx := (x + 0.5 - cx) / rx
			var edge := (1.0 - sqrt(dx * dx + dy2)) * rm
			if edge >= 0.5:
				_over(img, x, y, col, 1.0)
			elif edge > -0.5:
				_over(img, x, y, col, edge + 0.5)
			x += 1

static func ring(img: Image, cx: float, cy: float, r: float, width: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := maxi(0, int(floor(cx - r - width - 1.0)))
	var x1 := mini(w - 1, int(ceil(cx + r + width + 1.0)))
	var y0 := maxi(0, int(floor(cy - r - width - 1.0)))
	var y1 := mini(h - 1, int(ceil(cy + r + width + 1.0)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := absf(sqrt((x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cy) * (y + 0.5 - cy)) - r)
			var cov := clampf(width * 0.5 + 0.5 - d, 0.0, 1.0)
			if cov > 0.0:
				_over(img, x, y, col, cov)

static func rect(img: Image, x: float, y: float, w: float, h: float, col: Color) -> void:
	var xi := int(round(x))
	var yi := int(round(y))
	var wi := maxi(1, int(round(w)))
	var hi := maxi(1, int(round(h)))
	var r := Rect2i(xi, yi, wi, hi).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x <= 0 or r.size.y <= 0:
		return
	if col.a >= 0.999:
		img.fill_rect(r, col)
	else:
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				_over(img, xx, yy, col, 1.0)

## Intervalo horizontal (en coordenadas de centro de píxel) que una cápsula de radio R ocupa en la fila yc.
static func _stadium_row(ax: float, ay: float, bx: float, by: float, r: float, yc: float) -> Vector2:
	var lo := INF
	var hi := -INF
	var dya := yc - ay
	if absf(dya) <= r:
		var s := sqrt(r * r - dya * dya)
		lo = minf(lo, ax - s)
		hi = maxf(hi, ax + s)
	var dyb := yc - by
	if absf(dyb) <= r:
		var s2 := sqrt(r * r - dyb * dyb)
		lo = minf(lo, bx - s2)
		hi = maxf(hi, bx + s2)
	var vx := bx - ax
	var vy := by - ay
	var l2 := vx * vx + vy * vy
	if l2 > 1e-9:
		var ln := sqrt(l2)
		var ulo := -INF
		var uhi := INF
		var ok := true
		# |vx*dy - vy*u| <= r*ln
		if absf(vy) > 1e-9:
			var u1 := (vx * dya - r * ln) / vy
			var u2 := (vx * dya + r * ln) / vy
			ulo = maxf(ulo, minf(u1, u2))
			uhi = minf(uhi, maxf(u1, u2))
		elif absf(vx * dya) > r * ln:
			ok = false
		# 0 <= vx*u + vy*dy <= l2
		if ok:
			if absf(vx) > 1e-9:
				var w1 := (-vy * dya) / vx
				var w2 := (l2 - vy * dya) / vx
				ulo = maxf(ulo, minf(w1, w2))
				uhi = minf(uhi, maxf(w1, w2))
			else:
				var pr := vy * dya
				if pr < 0.0 or pr > l2:
					ok = false
		if ok and ulo <= uhi:
			lo = minf(lo, ax + ulo)
			hi = maxf(hi, ax + uhi)
	return Vector2(lo, hi)

static func line(img: Image, x0: float, y0: float, x1: float, y1: float, width: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var hw := width * 0.5
	var r_out := hw + 0.5
	var r_in := hw - 0.5
	var by0 := maxi(0, int(floor(minf(y0, y1) - r_out - 1.0)))
	var by1 := mini(h - 1, int(ceil(maxf(y0, y1) + r_out + 1.0)))
	var vx := x1 - x0
	var vy := y1 - y0
	var len2 := vx * vx + vy * vy
	var solid_col := col.a >= 0.997 and r_in > 0.0
	var fill := Color(col.r, col.g, col.b, 1.0)
	for y in range(by0, by1 + 1):
		var yc := y + 0.5
		var so := _stadium_row(x0, y0, x1, y1, r_out, yc)
		if so.x > so.y:
			continue
		var xa := maxi(0, int(ceil(so.x - 0.5)) - 1)
		var xb := mini(w - 1, int(floor(so.y - 0.5)) + 1)
		if xa > xb:
			continue
		var ia := xb + 1
		var ib := xb
		if solid_col:
			var si := _stadium_row(x0, y0, x1, y1, r_in, yc)
			if si.x <= si.y:
				ia = maxi(xa, int(ceil(si.x - 0.5)))
				ib = mini(xb, int(floor(si.y - 0.5)))
				if ia <= ib:
					img.fill_rect(Rect2i(ia, y, ib - ia + 1, 1), fill)
				else:
					ia = xb + 1
					ib = xb
		var x := xa
		while x <= xb:
			if x == ia:
				x = ib + 1
				continue
			var px := x + 0.5 - x0
			var py := yc - y0
			var t := 0.0
			if len2 > 0.0:
				t = clampf((px * vx + py * vy) / len2, 0.0, 1.0)
			var dx := px - vx * t
			var dy := py - vy * t
			var d := sqrt(dx * dx + dy * dy)
			var cov := clampf(hw + 0.5 - d, 0.0, 1.0)
			if cov > 0.0:
				_over(img, x, y, col, cov)
			x += 1

## Intervalo horizontal de un triángulo en la ordenada Y (x > y del Vector2 = vacío).
static func _tri_row(ax: float, ay: float, bx: float, by: float, cx: float, cy: float, yy: float) -> Vector2:
	var lo := INF
	var hi := -INF
	var pts := [ax, ay, bx, by, cx, cy]
	for e in 3:
		var px: float = pts[e * 2]
		var py: float = pts[e * 2 + 1]
		var qx: float = pts[((e + 1) % 3) * 2]
		var qy: float = pts[((e + 1) % 3) * 2 + 1]
		if (py <= yy and qy >= yy) or (qy <= yy and py >= yy):
			if absf(qy - py) < 1e-9:
				lo = minf(lo, minf(px, qx))
				hi = maxf(hi, maxf(px, qx))
			else:
				var xx := px + (qx - px) * (yy - py) / (qy - py)
				lo = minf(lo, xx)
				hi = maxf(hi, xx)
	return Vector2(lo, hi)

static func tri(img: Image, ax: float, ay: float, bx: float, by: float, cx: float, cy: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var den := (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
	if absf(den) < 0.0001:
		return
	var ty0 := minf(ay, minf(by, cy))
	var ty1 := maxf(ay, maxf(by, cy))
	var y0 := maxi(0, int(floor(ty0)))
	var y1 := mini(h - 1, int(ceil(ty1)))
	var solid_col := col.a >= 0.997
	var fill := Color(col.r, col.g, col.b, 1.0)
	for y in range(y0, y1 + 1):
		var s_t := _tri_row(ax, ay, bx, by, cx, cy, clampf(float(y), ty0, ty1))
		var s_b := _tri_row(ax, ay, bx, by, cx, cy, clampf(float(y + 1), ty0, ty1))
		var s_c := _tri_row(ax, ay, bx, by, cx, cy, clampf(y + 0.5, ty0, ty1))
		var lo := minf(s_t.x, minf(s_b.x, s_c.x))
		var hi := maxf(s_t.y, maxf(s_b.y, s_c.y))
		if lo > hi:
			continue
		var xa := maxi(0, int(floor(lo)))
		var xb := mini(w - 1, int(ceil(hi)))
		var ia := xb + 1
		var ib := xb
		if solid_col and float(y) >= ty0 and float(y + 1) <= ty1 and s_t.x <= s_t.y and s_b.x <= s_b.y:
			ia = maxi(xa, int(ceil(maxf(s_t.x, s_b.x))))
			ib = mini(xb, int(floor(minf(s_t.y, s_b.y))) - 1)
			if ia <= ib:
				img.fill_rect(Rect2i(ia, y, ib - ia + 1, 1), fill)
			else:
				ia = xb + 1
				ib = xb
		var x := xa
		while x <= xb:
			if x == ia:
				x = ib + 1
				continue
			var hits := 0
			for sy in 2:
				for sx in 2:
					var px := x + 0.25 + 0.5 * sx
					var py := y + 0.25 + 0.5 * sy
					var l1 := ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / den
					var l2 := ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / den
					var l3 := 1.0 - l1 - l2
					if l1 >= 0.0 and l2 >= 0.0 and l3 >= 0.0:
						hits += 1
			if hits > 0:
				_over(img, x, y, col, float(hits) / 4.0)
			x += 1

static func quad(img: Image, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, col: Color) -> void:
	tri(img, p0.x, p0.y, p1.x, p1.y, p2.x, p2.y, col)
	tri(img, p0.x, p0.y, p2.x, p2.y, p3.x, p3.y, col)

static func arc(img: Image, cx: float, cy: float, r: float, a0: float, a1: float, width: float, col: Color) -> void:
	var steps := maxi(6, int(absf(a1 - a0) * r / 3.0))
	var prev := Vector2(cx + cos(a0) * r, cy + sin(a0) * r)
	for i in range(1, steps + 1):
		var a := a0 + (a1 - a0) * float(i) / float(steps)
		var p := Vector2(cx + cos(a) * r, cy + sin(a) * r)
		line(img, prev.x, prev.y, p.x, p.y, width, col)
		prev = p

static func shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), c.a)
