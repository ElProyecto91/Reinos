extends SceneTree
## Genera el icono de la app por código (coste 0, como el resto del arte): un castillo de sillares al
## atardecer, con luz cálida a la izquierda, sombras azules, ventanas encendidas y el estandarte del jugador.
## Escribe res://icon.png (512) y los iconos de lanzador de Android en res://art/icon:
##   ic_main_192.png (clásico, esquinas redondeadas), ic_fg_432.png y ic_bg_432.png (adaptativos).
## Uso: godot --headless --path . --script res://tools/gen_icon.gd -- [preview=/ruta/hoja.png]
## Espacio de diseño: 432 x 432 (la capa adaptativa de Android). Sólo el círculo central de 264 se ve
## con seguridad en cualquier máscara, así que el castillo (y 88..352) se compone dentro de él.

const D := 432.0
const SUN := Vector2(118.0, 302.0)         # el sol se pone a la izquierda: luz cálida de ese lado
const HORIZON := 312.0
const CX := 216.0                          # eje del castillo
const BLUE := Color("2f6fdc")
const GOLD := Color(0.98, 0.78, 0.28)
const GOLD_DK := Color(0.62, 0.42, 0.10)
const INK := Color(0.05, 0.04, 0.10)
const STONE := Color(0.76, 0.71, 0.64)
const SLATE := Color(0.34, 0.41, 0.66)
const SUN_COL := Color(1.0, 0.84, 0.62)    # luz directa
const AMB_COL := Color(0.46, 0.52, 0.90)   # luz del cielo (sombras azuladas)
const SKY_STOPS := [
	[0.00, Color("060921")], [0.30, Color("161b57")], [0.52, Color("4b2f88")],
	[0.68, Color("aa4780")], [0.82, Color("f2744e")], [0.93, Color("ffb45a")], [1.00, Color("ffe28c")]]

# ------------------------------------------------------------------ programa principal

func _init() -> void:
	var preview := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("preview="):
			preview = a.substr(8)
	var t0 := Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/icon"))
	# capas adaptativas: 432 px con supersampling 2x
	var bg2 := render_bg(864)
	var fg2 := render_fg(864)
	var bg := _down(bg2, 432)
	var fg := _down(fg2, 432)
	bg.save_png(ProjectSettings.globalize_path("res://art/icon/ic_bg_432.png"))
	fg.save_png(ProjectSettings.globalize_path("res://art/icon/ic_fg_432.png"))
	# iconos "completos" (clásico 192 y principal 512): fondo + castillo, algo más cerca y con esquinas redondeadas
	var main512 := compose_full(512, 1.36, 1296)
	main512.save_png(ProjectSettings.globalize_path("res://icon.png"))
	var main192 := compose_full(192, 1.36, 864)
	main192.save_png(ProjectSettings.globalize_path("res://art/icon/ic_main_192.png"))
	print("iconos generados en %d ms" % (Time.get_ticks_msec() - t0))
	if preview != "":
		_sheet(bg, fg, main512, main192).save_png(preview)
		print("hoja ", preview)
	quit()

## Reducción exacta 2x (caja 2x2) ponderando el color por el alfa: sin halos oscuros en los bordes transparentes.
func _down(img: Image, n: int) -> Image:
	var sw := img.get_width()
	var src := img.get_data()
	var dst := PackedByteArray()
	dst.resize(n * n * 4)
	for y in n:
		for x in n:
			var a := 0.0
			var r := 0.0
			var g := 0.0
			var b := 0.0
			for dy in 2:
				for dx in 2:
					var o := ((2 * y + dy) * sw + 2 * x + dx) * 4
					var pa := float(src[o + 3])
					a += pa
					r += float(src[o]) * pa
					g += float(src[o + 1]) * pa
					b += float(src[o + 2]) * pa
			var o2 := (y * n + x) * 4
			if a > 0.0:
				dst[o2] = int(r / a + 0.5)
				dst[o2 + 1] = int(g / a + 0.5)
				dst[o2 + 2] = int(b / a + 0.5)
				dst[o2 + 3] = int(a * 0.25 + 0.5)
	return Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, dst)

## Fondo + castillo con zoom centrado y esquinas redondeadas (para el icono clásico y el principal).
func compose_full(px: int, zoom: float, n: int) -> Image:
	var comp := render_bg(n)
	comp.blend_rect(render_fg(n), Rect2i(0, 0, n, n), Vector2i.ZERO)
	var win := int(round(float(n) / zoom))
	var k := float(n) / D
	var cx := int(round(CX * k)) - win / 2
	var cy := int(round(222.0 * k)) - win / 2
	var crop := comp.get_region(Rect2i(clampi(cx, 0, n - win), clampi(cy, 0, n - win), win, win))
	crop.resize(px, px, Image.INTERPOLATE_LANCZOS)
	_gloss(crop)
	_round_corners(crop, 0.22 * float(px))
	return crop

func render_bg(n: int) -> Image:
	var k := float(n) / D
	var img := _sky(n)
	var cv := ArtBuildings.Cv.new(img, k)
	_rays(cv)
	_stars(cv)
	_ridge(cv, 292.0, [13.0, 8.0, 3.5], Color(0.40, 0.26, 0.56), Color(0.24, 0.17, 0.44), 11, 0.75)
	_ridge(cv, 320.0, [10.0, 6.0, 3.0], Color(0.19, 0.15, 0.37), Color(0.11, 0.10, 0.26), 23, 0.55)
	_ridge(cv, 352.0, [6.0, 4.0, 2.0], Color(0.08, 0.09, 0.19), Color(0.03, 0.04, 0.09), 37, 0.30)
	_vignette(img)
	return img

func render_fg(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_castle(ArtBuildings.Cv.new(img, float(n) / D))
	return img

# ------------------------------------------------------------------ cielo y paisaje

func _grad(t: float) -> Color:
	for i in range(1, SKY_STOPS.size()):
		var b: Array = SKY_STOPS[i]
		if t <= float(b[0]):
			var a: Array = SKY_STOPS[i - 1]
			return (a[1] as Color).lerp(b[1] as Color, (t - float(a[0])) / (float(b[0]) - float(a[0])))
	return (SKY_STOPS[SKY_STOPS.size() - 1] as Array)[1] as Color

## Degradado del cielo con resplandor del sol, calculado en baja resolución (es suave) y ampliado.
func _sky(n: int) -> Image:
	var m := 216
	var kk := D / float(m)
	var data := PackedByteArray()
	data.resize(m * m * 4)
	for j in m:
		var y := (float(j) + 0.5) * kk
		var base := _grad(clampf(y / HORIZON, 0.0, 1.0))
		for i in m:
			var x := (float(i) + 0.5) * kk
			var dx := x - SUN.x
			var dy := y - SUN.y
			var d2 := dx * dx + dy * dy
			var glow := exp(-d2 / (2.0 * 125.0 * 125.0)) * 0.78 + exp(-d2 / (2.0 * 34.0 * 34.0)) * 0.9
			var c := base.lerp(Color(1.0, 0.82, 0.48), clampf(glow, 0.0, 1.0))
			var o := (j * m + i) * 4
			data[o] = int(c.r * 255.0 + 0.5)
			data[o + 1] = int(c.g * 255.0 + 0.5)
			data[o + 2] = int(c.b * 255.0 + 0.5)
			data[o + 3] = 255
	var small := Image.create_from_data(m, m, false, Image.FORMAT_RGBA8, data)
	small.resize(n, n, Image.INTERPOLATE_CUBIC)
	return small

func _rays(cv: ArtBuildings.Cv) -> void:
	for i in 6:
		var a0 := deg_to_rad(-84.0 + float(i) * 15.5)
		var a1 := a0 + deg_to_rad(6.5)
		var p0 := SUN + Vector2(cos(a0), sin(a0)) * 520.0
		var p1 := SUN + Vector2(cos(a1), sin(a1)) * 520.0
		cv.tri(SUN.x, SUN.y, p0.x, p0.y, p1.x, p1.y, Color(1.0, 0.86, 0.58, 0.040))

func _stars(cv: ArtBuildings.Cv) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		var p := Vector2(rng.randf_range(10.0, 422.0), rng.randf_range(8.0, 196.0))
		if p.distance_to(SUN) < 150.0:
			continue
		var r := rng.randf_range(0.45, 1.05)
		var a := rng.randf_range(0.35, 0.95) * clampf((215.0 - p.y) / 120.0, 0.0, 1.0)
		cv.disc(p.x, p.y, r, Color(1.0, 0.97, 0.90, a))
		if r > 0.9:
			cv.disc(p.x, p.y, r * 2.6, Color(0.85, 0.9, 1.0, 0.10))

func _ridge(cv: ArtBuildings.Cv, base_y: float, amps: Array, c_top: Color, c_bot: Color, seed_v: int, rim: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var p1 := rng.randf_range(0.0, TAU)
	var p2 := rng.randf_range(0.0, TAU)
	var p3 := rng.randf_range(0.0, TAU)
	for xi in 440:
		var x := float(xi) - 4.0
		var y := base_y + float(amps[0]) * sin(x * 0.011 + p1) + float(amps[1]) * sin(x * 0.027 + p2) + float(amps[2]) * sin(x * 0.06 + p3)
		var h := D - y + 2.0
		var ns := 8
		for s in ns:
			cv.rect(x - 0.6, y + h * float(s) / float(ns), 2.4, h / float(ns) + 0.6, c_top.lerp(c_bot, float(s) / float(ns - 1)))
		var dxs := x - SUN.x
		var warm := exp(-dxs * dxs / (2.0 * 150.0 * 150.0)) * rim
		if warm > 0.02:
			cv.rect(x, y, 1.2, 1.5, Color(1.0, 0.70, 0.36, warm))

## Viñeta suave en las esquinas (mapa de alfa en baja resolución, ampliado).
func _vignette(img: Image) -> void:
	var m := 96
	var data := PackedByteArray()
	data.resize(m * m * 4)
	for j in m:
		for i in m:
			var vx := (float(i) + 0.5) / float(m) * 2.0 - 1.0
			var vy := (float(j) + 0.5) / float(m) * 2.0 - 1.0
			var a := clampf((vx * vx + vy * vy - 0.35) * 0.30, 0.0, 0.45)
			var o := (j * m + i) * 4
			data[o] = 3
			data[o + 1] = 4
			data[o + 2] = 14
			data[o + 3] = int(a * 255.0)
	var v := Image.create_from_data(m, m, false, Image.FORMAT_RGBA8, data)
	v.resize(img.get_width(), img.get_height(), Image.INTERPOLATE_CUBIC)
	img.blend_rect(v, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)

## Brillo suave arriba (aspecto de superficie actual) sobre el icono ya recortado.
func _gloss(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var g := Image.create(w, h, false, Image.FORMAT_RGBA8)
	g.fill(Color(0, 0, 0, 0))
	var rows := int(h * 0.5)
	for j in rows:
		var a := 0.10 * pow(1.0 - float(j) / float(rows), 1.6)
		g.fill_rect(Rect2i(0, j, w, 1), Color(1.0, 0.95, 0.9, a))
	img.blend_rect(g, Rect2i(0, 0, w, h), Vector2i.ZERO)

func _round_corners(img: Image, r: float) -> void:
	var w := img.get_width()
	var ri := int(ceil(r)) + 1
	for cxs in [0, w - ri]:
		for cys in [0, w - ri]:
			var ccx: float = r if cxs == 0 else float(w) - r
			var ccy: float = r if cys == 0 else float(w) - r
			for y in range(cys, cys + ri):
				for x in range(cxs, cxs + ri):
					var px := float(x) + 0.5
					var py := float(y) + 0.5
					var inside_corner := (px < r or px > float(w) - r) and (py < r or py > float(w) - r)
					if not inside_corner:
						continue
					var d := Vector2(px, py).distance_to(Vector2(ccx, ccy))
					var cov := clampf(r - d + 0.5, 0.0, 1.0)
					if cov < 1.0:
						var c := img.get_pixel(x, y)
						img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * cov))

# ------------------------------------------------------------------ luz y materiales

## Luz sobre una superficie según su posición u (0..1) en la cara. modo 0 = cara plana iluminada,
## 1 = cilindro (torre redonda), 2 = cara en sombra. Devuelve el multiplicador de color (cálido/azul).
func _light(u: float, mode: int) -> Color:
	var lam: float
	match mode:
		1:
			lam = maxf(0.0, cos((u - 0.5) * PI + 0.6))
		2:
			lam = 0.05 + 0.04 * (1.0 - u)
		_:
			lam = lerpf(0.96, 0.80, u)
	var s := 0.95 * lam
	return Color(SUN_COL.r * s + AMB_COL.r * 0.42, SUN_COL.g * s + AMB_COL.g * 0.42, SUN_COL.b * s + AMB_COL.b * 0.42)

func _tinted(base: Color, lc: Color, tone: float) -> Color:
	return Color(clampf(base.r * lc.r * tone, 0.0, 1.0), clampf(base.g * lc.g * tone, 0.0, 1.0), clampf(base.b * lc.b * tone, 0.0, 1.0))

## Cara de sillares: hileras irregulares, tono distinto por bloque, juntas y luz propia.
## Las tiras con x >= split_x se pintan en sombra (cara lateral de una torre cuadrada).
func _wall(cv: ArtBuildings.Cv, x0: float, y0: float, x1: float, y1: float, base: Color, seed_v: int, mode: int = 0, split_x: float = 1.0e9, ch: float = 6.5, bw: float = 11.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var w := x1 - x0
	var yy := y0
	while yy < y1 - 0.2:
		var rh := minf(ch, y1 - yy)
		var cuts: Array[float] = [x0]
		var xx := x0 + rng.randf_range(0.25, 1.0) * bw
		while xx < x1 - 1.0:
			cuts.append(xx)
			xx += bw * rng.randf_range(0.75, 1.3)
		cuts.append(x1)
		for b in range(cuts.size() - 1):
			var bx0 := cuts[b]
			var bx1 := cuts[b + 1]
			var tone := rng.randf_range(0.86, 1.10)
			var sx := bx0
			while sx < bx1 - 0.01:
				var sw := minf(1.0, bx1 - sx)
				var u := (sx + sw * 0.5 - x0) / w
				var md := 2 if sx >= split_x else mode
				cv.rect(sx, yy, sw + 0.12, rh, _tinted(base, _light(u, md), tone))
				sx += sw
			cv.rect(bx0, yy, 0.55, rh, Color(0.05, 0.04, 0.10, 0.36))                                # junta vertical
			var um := ((bx0 + bx1) * 0.5 - x0) / w
			var lit := clampf(_light(um, 2 if bx0 >= split_x else mode).r - 0.45, 0.0, 0.7)
			cv.rect(bx0 + 0.5, yy + 0.1, bx1 - bx0 - 0.5, 0.75, Color(1.0, 0.92, 0.78, lit * 0.30))   # luz en el canto superior
		cv.rect(x0, yy + rh - 0.65, w, 0.65, Color(0.05, 0.04, 0.10, 0.44))                          # junta horizontal
		yy += rh
	ArtBuildings.vgrad(cv, x0, y0, w, y1 - y0, 0.0, 0.34, Color(0.03, 0.03, 0.12))               # más oscuro hacia el suelo

## Cornisa de ménsulas bajo un parapeto.
func _corbels(cv: ArtBuildings.Cv, x0: float, x1: float, y: float, seed_v: int, mode: int = 0, split_x: float = 1.0e9) -> void:
	_wall(cv, x0, y, x1, y + 6.0, STONE, seed_v, mode, split_x, 3.0, 7.0)
	var xx := x0 + 2.0
	while xx < x1 - 2.0:
		cv.tri(xx, y + 6.0, xx + 3.2, y + 6.0, xx + 1.6, y + 3.6, Color(0.04, 0.03, 0.10, 0.45))
		xx += 5.0
	cv.rect(x0, y + 6.0, x1 - x0, 1.6, Color(0.03, 0.03, 0.10, 0.40))    # sombra bajo la cornisa
	cv.rect(x0, y, x1 - x0, 0.9, Color(1.0, 0.92, 0.78, 0.22))

## Almenas repartidas entre x0 y x1 (la parte a la derecha de split_x queda en sombra).
func _merlons(cv: ArtBuildings.Cv, x0: float, x1: float, y_base: float, h: float, count: int, seed_v: int, mode: int = 0, split_x: float = 1.0e9) -> void:
	var w := x1 - x0
	var mw := w / (float(count) * 1.62 - 0.62)
	var gap := mw * 0.62
	for i in count:
		var mx := x0 + float(i) * (mw + gap)
		_wall(cv, mx, y_base - h, mx + mw, y_base, STONE, seed_v + i, mode, split_x, h * 0.5, mw)

func _window(cv: ArtBuildings.Cv, x: float, y: float, w: float, h: float, halo: bool = true) -> void:
	var r := w * 0.5
	var cx := x + r
	if halo:
		for j in 5:
			cv.ell(cx, y + h * 0.55, w * (2.6 - 0.42 * float(j)), h * (1.05 - 0.14 * float(j)), Color(1.0, 0.62, 0.22, 0.045))
	var fr := Color(0.06, 0.05, 0.10)
	cv.rect(x - 1.5, y + r, w + 3.0, h - r + 1.5, fr)
	cv.disc(cx, y + r, r + 1.5, fr)
	var n := int(ceil(h))
	for i in n:
		var yy := y + float(i)
		var t := float(i) / float(maxi(1, n - 1))
		var col := Color(1.0, 0.90, 0.52).lerp(Color(1.0, 0.50, 0.14), t)
		if yy < y + r:
			var dy := y + r - (yy + 0.5)
			var half := sqrt(maxf(0.0, r * r - dy * dy))
			cv.rect(cx - half, yy, 2.0 * half, 1.1, col)
		else:
			cv.rect(x, yy, w, 1.1, col)
	cv.rect(cx - 0.45, y + r - 1.0, 0.9, h - r + 1.0, Color(0.10, 0.06, 0.06, 0.65))     # parteluz
	cv.rect(x, y + r + h * 0.28, w, 0.8, Color(0.10, 0.06, 0.06, 0.55))
	cv.rect(x - 2.0, y + h, w + 4.0, 1.8, Color(0.62, 0.58, 0.54, 0.9))                  # alféizar

func _slit(cv: ArtBuildings.Cv, cx: float, y: float, h: float) -> void:
	cv.rect(cx - 2.0, y - 1.0, 4.0, h + 2.0, Color(0.04, 0.03, 0.09, 0.55))
	cv.rect(cx - 1.0, y, 2.0, h, Color(0.03, 0.02, 0.07))
	cv.rect(cx - 1.0, y + h * 0.55, 2.0, h * 0.45, Color(0.45, 0.22, 0.10, 0.85))

func _pennant(cv: ArtBuildings.Cv, x: float, y: float, w: float, h: float, phase: float) -> void:
	cv.rect(x - 0.45, y - 1.0, 0.9, h + 9.0, Color(0.20, 0.20, 0.26))
	var i := 0.0
	while i < w:
		var t := i / w
		var dy := sin(t * 5.0 + phase) * 1.2 * t
		var hh := h * (1.0 - 0.78 * t)
		var f := 0.88 + 0.22 * sin(t * 9.0 + phase)
		cv.rect(x + 0.4 + i, y + dy, 0.62, hh, Painter.shade(BLUE, f * 1.12))
		cv.rect(x + 0.4 + i, y + dy, 0.62, 0.8, GOLD)
		i += 0.5
	cv.disc(x, y - 1.2, 1.5, GOLD)

func _torch(cv: ArtBuildings.Cv, x: float, y: float) -> void:
	for j in 5:
		cv.disc(x, y, 18.0 - 3.3 * float(j), Color(1.0, 0.58, 0.18, 0.050))
	cv.rect(x - 0.7, y + 1.5, 1.4, 7.0, Color(0.30, 0.20, 0.12))
	cv.ell(x, y, 2.5, 4.2, Color(1.0, 0.50, 0.12))
	cv.ell(x, y + 0.7, 1.5, 2.8, Color(1.0, 0.82, 0.30))
	cv.ell(x, y + 1.3, 0.7, 1.4, Color(1.0, 0.97, 0.80))

func _shield(cv: ArtBuildings.Cv, cx: float, cy: float, w: float, h: float) -> void:
	var x0 := cx - w * 0.5
	var top := cy - h * 0.5
	var mid := top + h * 0.55
	cv.rect(x0 - 1.0, top - 1.0, w + 2.0, mid - top + 1.0, GOLD_DK)
	cv.tri(x0 - 1.0, mid - 0.2, x0 + w + 1.0, mid - 0.2, cx, cy + h * 0.5 + 1.6, GOLD_DK)
	cv.rect(x0, top, w, mid - top, BLUE)
	cv.tri(x0, mid - 0.1, x0 + w, mid - 0.1, cx, cy + h * 0.5, BLUE)
	cv.rect(x0, top, w * 0.5, mid - top, Color(1, 1, 1, 0.12))
	cv.rect(cx - 0.8, top + 1.0, 1.6, h * 0.74, GOLD)
	cv.rect(x0 + 1.2, top + h * 0.20, w - 2.4, 1.6, GOLD)

func _pine(cv: ArtBuildings.Cv, x: float, y: float, h: float) -> void:
	var c := _tinted(Color(0.14, 0.32, 0.24), _light(clampf((x - 34.0) / 364.0, 0.0, 1.0), 1), 1.0)
	cv.rect(x - 0.8, y - 3.0, 1.6, 4.0, Color(0.16, 0.11, 0.10))
	for i in 3:
		var ty := y - 2.0 - h * 0.28 * float(i)
		var tw := h * (0.36 - 0.07 * float(i))
		cv.tri(x - tw, ty, x + tw, ty, x, ty - h * 0.48, Painter.shade(c, 1.0 - 0.07 * float(i)))
		cv.tri(x - tw, ty, x, ty, x, ty - h * 0.48, Color(1.0, 0.82, 0.55, 0.15))

func _cone(cv: ArtBuildings.Cv, cx: float, apex_y: float, base_y: float, rw: float, base: Color) -> void:
	var h := base_y - apex_y
	var x := cx - rw
	while x < cx + rw:
		var xm := x + 0.25
		var f := absf(xm - cx) / rw
		var top := apex_y + h * f
		var u := (xm - (cx - rw)) / (2.0 * rw)
		var lc := _light(u, 1)
		var row := int(floor((top - apex_y) / 4.0))
		var yy := top
		while yy < base_y - 0.01:
			var seg_end := minf(apex_y + float(row + 1) * 4.0, base_y)
			var tone := 1.0 + (0.07 if (row + int(floor(xm / 3.0))) % 2 == 0 else -0.07)
			cv.rect(x, yy, 0.62, seg_end - yy + 0.1, _tinted(base, lc, tone))
			cv.rect(x, seg_end - 0.75, 0.62, 0.75, Color(0.03, 0.03, 0.12, 0.34))
			yy = seg_end
			row += 1
		x += 0.5
	# arista iluminada en la cara izquierda del cono
	cv.line(cx - 0.4, apex_y + 1.0, cx - rw + 1.2, base_y - 0.5, 0.9, Color(1.0, 0.82, 0.55, 0.34))

# ------------------------------------------------------------------ castillo

func _castle(cv: ArtBuildings.Cv) -> void:
	# loma de hierba al atardecer bajo el castillo: cálida a la izquierda, fría a la derecha
	var x := CX - 182.0
	while x <= CX + 182.0:
		var d := absf(x - CX) / 182.0
		var y := 329.0 + 27.0 * pow(d, 2.2) + 1.6 * sin(x * 0.09) * d
		var u := clampf((x - 34.0) / 364.0, 0.0, 1.0)
		var top := _tinted(Color(0.36, 0.44, 0.27), _light(u, 1), 1.0)
		var h := 436.0 - y
		for s in 6:
			cv.rect(x - 0.6, y + h * float(s) / 6.0, 2.4, h / 6.0 + 0.6, top.lerp(Color(0.04, 0.05, 0.10), minf(1.0, 0.10 + float(s) * 0.22)))
		cv.rect(x - 0.6, y, 2.4, 1.7, top.lerp(Color(1.0, 0.78, 0.48), 0.55 * (1.0 - u)))
		x += 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 16:                                                                    # peñas al pie de las murallas
		var rx := rng.randf_range(112.0, 322.0)
		var rr := rng.randf_range(3.5, 8.0)
		var ry := 337.0 + rng.randf_range(0.0, 7.0)
		var lc := _light(clampf((rx - 34.0) / 364.0, 0.0, 1.0), 1)
		cv.ell(rx, ry, rr, rr * 0.55, _tinted(Color(0.52, 0.48, 0.45), lc, rng.randf_range(0.7, 1.0)))
		cv.ell(rx - rr * 0.25, ry - rr * 0.2, rr * 0.55, rr * 0.28, Color(1.0, 0.85, 0.65, 0.14 * (1.0 - clampf((rx - 34.0) / 364.0, 0.0, 1.0))))
	for px in [66.0, 80.0, 94.0, 342.0, 356.0, 372.0]:                              # pinos en las laderas
		var d2 := absf(float(px) - CX) / 182.0
		_pine(cv, float(px), 329.0 + 27.0 * pow(d2, 2.2) + 2.0, 20.0 + 6.0 * sin(float(px)))

	# torre del homenaje: cara frontal iluminada y cara derecha en sombra
	var kx0 := 186.0
	var kx1 := 246.0
	var ksplit := 232.0
	_wall(cv, kx0, 154.0, kx1, 334.0, STONE, 31, 0, ksplit, 6.5, 11.0)
	cv.rect(ksplit - 0.5, 154.0, 1.0, 180.0, Color(0.03, 0.03, 0.10, 0.40))         # arista
	cv.rect(ksplit - 1.7, 154.0, 1.0, 180.0, Color(1.0, 0.88, 0.7, 0.20))
	cv.rect(kx0, 154.0, 1.2, 180.0, Color(1.0, 0.82, 0.55, 0.30))                    # luz de borde
	_corbels(cv, kx0 - 6.0, kx1 + 6.0, 146.0, 41, 0, ksplit + 6.0)
	_merlons(cv, kx0 - 6.0, kx1 + 6.0, 146.0, 13.0, 5, 50, 0, ksplit + 6.0)
	_window(cv, 195.0, 176.0, 9.0, 24.0)
	_window(cv, 212.0, 176.0, 9.0, 24.0)
	_shield(cv, 208.5, 224.0, 12.0, 15.0)
	_slit(cv, 239.0, 188.0, 16.0)                                                   # saetera en la cara en sombra
	# asta y estandarte del jugador
	cv.rect(CX - 0.9, 92.0, 1.8, 42.0, Color(0.18, 0.18, 0.24))
	_pennant(cv, CX + 0.9, 95.0, 36.0, 22.0, 0.4)

	# muralla frontal con almenas
	var wx0 := 150.0
	var wx1 := 282.0
	_wall(cv, wx0, 268.0, wx1, 334.0, STONE, 61, 0, 1.0e9, 6.5, 12.0)
	_corbels(cv, wx0 - 2.0, wx1 + 2.0, 262.0, 62)
	_merlons(cv, wx0, wx1, 262.0, 11.0, 10, 70)
	# oclusión de la torre izquierda sobre el lienzo
	for i in 10:
		cv.rect(172.0 + float(i) * 1.8, 268.0, 1.9, 66.0, Color(0.02, 0.02, 0.10, 0.20 * (1.0 - float(i) / 10.0)))
	for i in 6:
		cv.rect(260.0 - float(i) * 1.6 - 1.6, 268.0, 1.7, 66.0, Color(0.02, 0.02, 0.10, 0.12 * (1.0 - float(i) / 6.0)))

	# puerta con arco, rastrillo y antorchas
	var gx := CX
	var stone_arc := _tinted(STONE, _light(0.45, 0), 1.08)
	cv.rect(gx - 17.0, 298.0, 34.0, 36.0, stone_arc)
	cv.disc(gx, 298.0, 17.0, stone_arc)
	cv.rect(gx - 16.4, 298.0, 1.0, 36.0, Color(1.0, 0.9, 0.7, 0.25))
	cv.rect(gx - 13.0, 298.0, 26.0, 36.0, Color(0.05, 0.04, 0.07))
	cv.disc(gx, 298.0, 13.0, Color(0.05, 0.04, 0.07))
	for i in 10:                                                                      # luz interior cálida desde el suelo
		cv.rect(gx - 13.0, 334.0 - float(i) * 3.6 - 3.6, 26.0, 3.7, Color(0.95, 0.45, 0.14, 0.20 * (1.0 - float(i) / 10.0)))
	var iron := Color(0.52, 0.55, 0.62)
	for g in 6:
		var bx := gx - 10.0 + float(g) * 4.0
		cv.rect(bx - 0.5, 290.0 + absf(float(g) - 2.5) * 1.4, 1.0, 22.0, iron)
	for gy in [296.0, 303.0, 310.0]:
		cv.rect(gx - 11.0, float(gy), 22.0, 1.0, iron)
		cv.rect(gx - 11.0, float(gy), 22.0, 0.4, Color(0.8, 0.82, 0.9, 0.5))
	_torch(cv, gx - 24.0, 301.0)
	_torch(cv, gx + 24.0, 301.0)

	# torres laterales redondas con tejado cónico
	for side in 2:
		var tcx := 151.0 if side == 0 else 281.0
		var tx0 := tcx - 21.0
		var tx1 := tcx + 21.0
		_wall(cv, tx0, 214.0, tx1, 336.0, STONE, 81 + side * 10, 1, 1.0e9, 6.5, 10.0)
		cv.rect(tx0, 214.0, 1.1, 122.0, Color(1.0, 0.82, 0.55, 0.26))
		_corbels(cv, tx0 - 4.0, tx1 + 4.0, 207.0, 90 + side, 1)
		_cone(cv, tcx, 160.0, 207.5, 27.0, SLATE)
		_pennant(cv, tcx + 0.6, 143.0, 15.0, 9.0, 1.1 + float(side))
		cv.rect(tcx - 0.7, 148.0, 1.4, 14.0, Color(0.20, 0.20, 0.26))
		_window(cv, tcx - 4.0, 232.0, 8.0, 19.0, true)
		_slit(cv, tcx, 270.0, 15.0)
		_slit(cv, tcx, 300.0, 12.0)
	# estandartes verticales a cada lado de la puerta
	for bx in [180.0, 252.0]:
		cv.rect(float(bx) - 5.0, 274.0, 10.0, 1.4, GOLD_DK)
		cv.rect(float(bx) - 4.2, 275.0, 8.4, 24.0, BLUE)
		cv.tri(float(bx) - 4.2, 299.0, float(bx) + 4.2, 299.0, float(bx), 305.0, BLUE)
		cv.rect(float(bx) - 4.2, 275.0, 3.0, 24.0, Color(1, 1, 1, 0.12))
		cv.rect(float(bx) - 0.7, 277.0, 1.4, 16.0, GOLD)

	# camino hasta la puerta, iluminado por las antorchas
	cv.quad(Vector2(gx - 12.0, 334.0), Vector2(gx + 12.0, 334.0), Vector2(gx + 34.0, 354.0), Vector2(gx - 34.0, 354.0), Color(0.42, 0.30, 0.24, 0.92))
	cv.quad(Vector2(gx - 8.0, 334.0), Vector2(gx + 8.0, 334.0), Vector2(gx + 18.0, 354.0), Vector2(gx - 18.0, 354.0), Color(0.95, 0.55, 0.22, 0.28))

# ------------------------------------------------------------------ hoja de comprobación

func _mask(src: Image, shape: String, size: int) -> Image:
	var out := Image.create(size, size, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var s := src.duplicate() as Image
	s.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var r := float(size) * 0.5
	for y in size:
		for x in size:
			var px := float(x) + 0.5 - r
			var py := float(y) + 0.5 - r
			var cov := 1.0
			match shape:
				"circle":
					cov = clampf(r - sqrt(px * px + py * py) + 0.5, 0.0, 1.0)
				"squircle":
					var e := pow(absf(px / r), 4.0) + pow(absf(py / r), 4.0)
					cov = clampf((1.0 - e) * r * 0.25 + 0.5, 0.0, 1.0)
				_:
					var q := Vector2(maxf(absf(px) - (r - 0.22 * float(size)), 0.0), maxf(absf(py) - (r - 0.22 * float(size)), 0.0))
					cov = clampf(0.22 * float(size) - q.length() + 0.5, 0.0, 1.0)
			if cov > 0.0:
				var c := s.get_pixel(x, y)
				out.set_pixel(x, y, Color(c.r, c.g, c.b, cov))
	return out

func _adaptive(bg: Image, fg: Image, shape: String, size: int, guide: bool) -> Image:
	var comp := bg.duplicate() as Image
	comp.blend_rect(fg, Rect2i(0, 0, 432, 432), Vector2i.ZERO)
	var crop := comp.get_region(Rect2i(72, 72, 288, 288))      # la ventana visible es 72/108 de la capa
	if guide:
		var ring := Image.create(288, 288, false, Image.FORMAT_RGBA8)
		ring.fill(Color(0, 0, 0, 0))
		Painter.ring(ring, 144.0, 144.0, 132.0, 1.6, Color(1, 1, 1, 0.9))     # zona segura de 264 px
		crop.blend_rect(ring, Rect2i(0, 0, 288, 288), Vector2i.ZERO)
	return _mask(crop, shape, size)

func _sheet(bg: Image, fg: Image, main512: Image, main192: Image) -> Image:
	var sheet := Image.create(1200, 720, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.09, 0.10, 0.14))
	sheet.fill_rect(Rect2i(560, 0, 640, 330), Color(0.93, 0.93, 0.95))        # lanzador en modo claro
	sheet.blend_rect(main512, Rect2i(0, 0, 512, 512), Vector2i(24, 24))
	for panel in 2:
		var x := 584
		for sz in [144, 96, 64, 48]:
			var ic := main512.duplicate() as Image
			ic.resize(sz, sz, Image.INTERPOLATE_LANCZOS)
			sheet.blend_rect(ic, Rect2i(0, 0, sz, sz), Vector2i(x, 24 + panel * 330))
			x += sz + 30
	var shapes := ["circle", "squircle", "round"]
	for i in 3:
		var a := _adaptive(bg, fg, shapes[i], 108, false)
		sheet.blend_rect(a, Rect2i(0, 0, 108, 108), Vector2i(584 + i * 124, 196))
	sheet.blend_rect(_adaptive(bg, fg, "round", 192, true), Rect2i(0, 0, 192, 192), Vector2i(584, 516))
	sheet.blend_rect(_adaptive(bg, fg, "circle", 192, false), Rect2i(0, 0, 192, 192), Vector2i(800, 516))
	sheet.blend_rect(main192, Rect2i(0, 0, 192, 192), Vector2i(1000, 516))
	return sheet
