class_name PainterRef
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
	for y in range(y0, y1 + 1):
		var dy := (y + 0.5 - cy) / ry
		for x in range(x0, x1 + 1):
			var dx := (x + 0.5 - cx) / rx
			var d := sqrt(dx * dx + dy * dy)
			# distancia aproximada al borde en píxeles
			var edge := (1.0 - d) * rm
			if edge >= 0.5:
				_over(img, x, y, col, 1.0)
			elif edge > -0.5:
				_over(img, x, y, col, edge + 0.5)

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

static func line(img: Image, x0: float, y0: float, x1: float, y1: float, width: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var pad := width * 0.5 + 1.5
	var bx0 := maxi(0, int(floor(minf(x0, x1) - pad)))
	var bx1 := mini(w - 1, int(ceil(maxf(x0, x1) + pad)))
	var by0 := maxi(0, int(floor(minf(y0, y1) - pad)))
	var by1 := mini(h - 1, int(ceil(maxf(y0, y1) + pad)))
	var vx := x1 - x0
	var vy := y1 - y0
	var len2 := vx * vx + vy * vy
	for y in range(by0, by1 + 1):
		for x in range(bx0, bx1 + 1):
			var px := x + 0.5 - x0
			var py := y + 0.5 - y0
			var t := 0.0
			if len2 > 0.0:
				t = clampf((px * vx + py * vy) / len2, 0.0, 1.0)
			var dx := px - vx * t
			var dy := py - vy * t
			var d := sqrt(dx * dx + dy * dy)
			var cov := clampf(width * 0.5 + 0.5 - d, 0.0, 1.0)
			if cov > 0.0:
				_over(img, x, y, col, cov)

static func tri(img: Image, ax: float, ay: float, bx: float, by: float, cx: float, cy: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := maxi(0, int(floor(minf(ax, minf(bx, cx)))))
	var x1 := mini(w - 1, int(ceil(maxf(ax, maxf(bx, cx)))))
	var y0 := maxi(0, int(floor(minf(ay, minf(by, cy)))))
	var y1 := mini(h - 1, int(ceil(maxf(ay, maxf(by, cy)))))
	var den := (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
	if absf(den) < 0.0001:
		return
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
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
