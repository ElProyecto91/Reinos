class_name IsoArch
extends RefCounted
## Kit de arquitectura para los edificios por civilización (cada civilización tiene su módulo en tools/iso/civ/<id>.gd).
## Reúne lo que se repite entre civilizaciones: texturas nuevas (ladrillo, teja curva, paja, césped, fieltro, tablas), mallas
## por revolución (cúpulas, agujas, tiendas), por extrusión (arcos, remates, gabletes escalonados) y por caras (tejados a cuatro
## aguas), y piezas de uso común (torres, garitas, soportales, chimeneas, estandartes). Mismas convenciones que IsoModels:
## 1 unidad = 1 casilla, origen en el centro de la huella a nivel del suelo; la cámara ve las caras +x y +z, así que ahí van
## puertas, ventanas y adornos. Lo que se construye con M.fmat(team) (gris neutro) se tiñe con el color del jugador.

const M = preload("res://tools/iso/iso_models.gd")
const B = preload("res://tools/iso/iso_build.gd")

# ------------------------------------------------------------------ texturas nuevas (128x128, sin costura)

static func _rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r

## Ladrillo: hileras de 8 px, ladrillos de 32 px a tresbolillo, junta clara y tono propio por ladrillo.
static func tex_brick(seed_v: int, base: Color, mortar: Color = Color(0.0, 0.0, 0.0, 0.0)) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := _rng(seed_v)
	var fine := M._noise_img(seed_v + 5, 0.22)
	var mc: Color = mortar if mortar.a > 0.0 else base.lerp(Color(0.80, 0.76, 0.68), 0.55)
	img.fill(mc)
	var bh := 8
	var bw := 32
	for r in n / bh:
		var off := bw / 2 if r % 2 == 1 else 0
		for k in n / bw:
			var tone := rng.randf_range(0.82, 1.14)
			var warm := rng.randf_range(-0.03, 0.03)
			var x0 := k * bw + off
			for yy in range(r * bh + 1, r * bh + bh):
				for xx in range(x0 + 1, x0 + bw - 1):
					var px := posmod(xx, n)
					var v := 1.0 + (fine.get_pixel(px, yy).r - 0.5) * 0.22
					var bev := 1.08 if yy == r * bh + 1 else (0.86 if yy == r * bh + bh - 1 else 1.0)
					var c := M._mul(base, tone * v * bev)
					img.set_pixel(px, yy, Color(c.r + warm, c.g, c.b - warm, 1.0))
	return M._to_tex(img)

## Teja curva (canal y cobija): costillas verticales de 16 px, hiladas de 32 px con sombra bajo cada hilada.
static func tex_barrel(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := _rng(seed_v)
	var f := M._noise_img(seed_v + 11, 0.14)
	var tones: Array = []
	for i in 8 * 4:
		tones.append(rng.randf_range(0.80, 1.14))
	for y in n:
		var row := y / 32
		var yy := y % 32
		for x in n:
			var col := x / 16
			var xx := x % 16
			var rib := 0.60 + 0.52 * sin(PI * (float(xx) + 0.5) / 16.0)
			var shade := 1.10 - float(yy) / 32.0 * 0.28
			if yy >= 29:
				shade *= 0.62
			var v: float = float(tones[row * 8 + col]) * rib * shade * (0.94 + (f.get_pixel(x, y).r - 0.5) * 0.18)
			img.set_pixel(x, y, M._mul(base, v))
	return M._to_tex(img)

## Paja / caña: hebras verticales y ataduras horizontales.
static func tex_thatch(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := _rng(seed_v)
	var f := M._noise_img(seed_v + 3, 0.09)
	var col_t: Array = []
	for x in n:
		col_t.append(rng.randf_range(0.78, 1.18))
	for y in n:
		for x in n:
			var v: float = float(col_t[x]) * (0.92 + (f.get_pixel(x, y).r - 0.5) * 0.30)
			if (y % 32) >= 29:
				v *= 0.66
			img.set_pixel(x, y, M._mul(base, v))
	return M._to_tex(img)

## Césped / tepe: manchas de dos frecuencias.
static func tex_turf(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var a := M._noise_img(seed_v, 0.04)
	var b := M._noise_img(seed_v + 4, 0.30)
	for y in n:
		for x in n:
			var v := 0.84 + (a.get_pixel(x, y).r - 0.5) * 0.42 + (b.get_pixel(x, y).r - 0.5) * 0.46
			var c := M._mul(base, v)
			img.set_pixel(x, y, Color(c.r * (1.0 + (b.get_pixel(x, y).r - 0.5) * 0.25), c.g, c.b * 0.96, 1.0))
	return M._to_tex(img)

## Fieltro de las tiendas: casi liso, fibroso, con costuras cada 64 px.
static func tex_felt(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var a := M._noise_img(seed_v, 0.05)
	var b := M._noise_img(seed_v + 6, 0.45)
	for y in n:
		for x in n:
			var v := 0.97 + (a.get_pixel(x, y).r - 0.5) * 0.12 + (b.get_pixel(x, y).r - 0.5) * 0.10
			if (x % 64) < 2 or (y % 64) < 2:
				v *= 0.82
			img.set_pixel(x, y, M._mul(base, v))
	return M._to_tex(img)

## Tablas horizontales traslapadas (casas de tablones, cascos): 16 px de alto, sombra bajo cada tabla y veta.
static func tex_planks_h(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := _rng(seed_v)
	var g := M._noise_img(seed_v + 5, 0.07)
	for p in n / 16:
		var tone := rng.randf_range(0.84, 1.14)
		var shift := rng.randi_range(0, n - 1)
		for yy in 16:
			var y := p * 16 + yy
			var edge := 1.10 - float(yy) / 15.0 * 0.30
			if yy >= 14:
				edge *= 0.52
			for x in n:
				var grain := 0.5 + 0.5 * sin(float(y) * 1.3 + g.get_pixel((x + shift) % n, y).r * 9.0)
				var v := tone * edge * (0.88 + 0.14 * grain)
				if (x + shift) % 64 == 0:
					v *= 0.55
				img.set_pixel(x, y, M._mul(base, v))
	return M._to_tex(img)

## Azulejos geométricos: celdas de 32 px con rombo de otro color (cenefas sarracenas, bizantinas).
static func tex_tiles(seed_v: int, base: Color, accent: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var f := M._noise_img(seed_v, 0.12)
	for y in n:
		for x in n:
			var u := x % 32
			var w := y % 32
			var d := absi(u - 16) + absi(w - 16)
			var c := base
			if d < 9:
				c = accent
			elif d in [11, 12]:
				c = accent.lerp(base, 0.45)
			if u == 0 or w == 0:
				c = c.darkened(0.30)
			var v := 0.95 + (f.get_pixel(x, y).r - 0.5) * 0.14
			img.set_pixel(x, y, M._mul(c, v))
	return M._to_tex(img)

## Mármol / piedra pulida: casi liso con vetas.
static func tex_marble(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var a := M._noise_img(seed_v, 0.035)
	var b := M._noise_img(seed_v + 8, 0.11)
	for y in n:
		for x in n:
			var v := 0.96 + (a.get_pixel(x, y).r - 0.5) * 0.12 + (b.get_pixel(x, y).r - 0.5) * 0.06
			if absf(a.get_pixel(x, y).r - 0.5) < 0.03:
				v *= 0.90
			if (y % 64) < 2:
				v *= 0.80
			img.set_pixel(x, y, M._mul(base, v))
	return M._to_tex(img)

## Material con textura triplanar. `kind`: stone, plaster, wood, roof (hiladas), brick, barrel (teja curva), thatch, turf, felt,
## planks (tablas horizontales), marble, tiles (azulejos; `col2` = color del dibujo).
static func mat(kind: String, seed_v: int, col: Color, per_unit: float = 1.2, col2: Color = Color.WHITE) -> StandardMaterial3D:
	var tex: ImageTexture
	match kind:
		"stone": tex = M.tex_stone(seed_v, col)
		"plaster": tex = M.tex_plaster(seed_v, col)
		"wood": tex = M.tex_wood(seed_v, col)
		"roof": tex = M.tex_roof(seed_v, col)
		"brick": tex = tex_brick(seed_v, col)
		"barrel": tex = tex_barrel(seed_v, col)
		"thatch": tex = tex_thatch(seed_v, col)
		"turf": tex = tex_turf(seed_v, col)
		"felt": tex = tex_felt(seed_v, col)
		"planks": tex = tex_planks_h(seed_v, col)
		"marble": tex = tex_marble(seed_v, col)
		"tiles": tex = tex_tiles(seed_v, col, col2)
		_: tex = M.tex_plaster(seed_v, col)
	return M.tmat(tex, per_unit)

## Materiales lisos comunes a todas las civilizaciones (nada de grises neutros: serían color de equipo).
static func plain() -> Dictionary:
	return {
		"iron": M.fmat(Color(0.25, 0.25, 0.28), 0.6, 0.5),
		"steel": M.fmat(Color(0.56, 0.58, 0.64), 0.4, 0.7),
		"dark": M.fmat(Color(0.07, 0.06, 0.08), 0.9, 0.1),
		"glass": M.glass_mat(),
		"hay": M.fmat(Color(0.84, 0.72, 0.34), 0.95, 0.1),
		"straw": M.fmat(Color(0.88, 0.78, 0.45), 0.95, 0.1),
		"sack": M.fmat(Color(0.74, 0.64, 0.46), 0.95, 0.1),
		"rope": M.fmat(Color(0.62, 0.52, 0.34), 0.95, 0.1),
		"cloth_w": M.fmat(Color(0.94, 0.92, 0.84), 0.9, 0.1),
		"cloth_r": M.fmat(Color(0.76, 0.18, 0.14), 0.9, 0.1),
		"cloth_b": M.fmat(Color(0.20, 0.34, 0.66), 0.9, 0.1),
		"cloth_g": M.fmat(Color(0.28, 0.55, 0.26), 0.9, 0.1),
		"cloth_y": M.fmat(Color(0.92, 0.74, 0.20), 0.9, 0.1),
		"cloth_p": M.fmat(Color(0.42, 0.16, 0.46), 0.9, 0.1),
		"gold": M.fmat(Color(0.88, 0.70, 0.22), 0.35, 0.9),
		"fire": B._glow(Color(1.0, 0.55, 0.12)),
		"red_fruit": M.fmat(Color(0.82, 0.16, 0.12), 0.8, 0.2),
		"green_fruit": M.fmat(Color(0.30, 0.52, 0.18), 0.8, 0.2),
		"bush": M.fmat(Color(0.20, 0.38, 0.16), 0.95, 0.1),
		"orange_fruit": M.fmat(Color(0.92, 0.56, 0.12), 0.8, 0.2),
		"water": M.fmat(Color(0.25, 0.50, 0.65), 0.2, 0.9),
		"clay": M.fmat(Color(0.66, 0.36, 0.22), 0.9, 0.1),
	}

## Juego de fortificación (lo que usan M._wall_block, M._rim, M._slits): muro, sombra, luz, ribete, saetera, suelo y madera.
static func fort(seed_v: int, wall: Color, dark: Color, light: Color, trim: Color, wood: Color = Color(0.36, 0.23, 0.12), kind: String = "stone") -> Dictionary:
	return {
		"wall": mat(kind, seed_v, wall, 1.3),
		"dark": mat(kind, seed_v + 1, dark, 1.3),
		"light": mat(kind, seed_v + 2, light, 1.3),
		"trim": M.fmat(trim, 0.65, 0.35),
		"slit": M.fmat(Color(0.04, 0.04, 0.06), 0.9, 0.1),
		"floor": mat("stone", seed_v + 4, dark.darkened(0.25), 1.6),
		"wood": mat("wood", seed_v + 5, wood, 1.6),
	}

# ------------------------------------------------------------------ mallas: caras, revolución, extrusión

## Triángulo visible desde donde apuntan las normales dadas (en Godot la cara frontal va en sentido horario).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	var gn := (b - a).cross(c - a)
	if gn.length_squared() < 1e-10:
		return
	if gn.dot(na + nb + nc) > 0.0:
		var t := b
		b = c
		c = t
		var tn := nb
		nb = nc
		nc = tn
	st.set_normal(na)
	st.add_vertex(a)
	st.set_normal(nb)
	st.add_vertex(b)
	st.set_normal(nc)
	st.add_vertex(c)

## Sólido convexo a partir de sus caras (cada cara = lista de Vector3, convexa). `inside` = un punto interior (para orientar).
static func solid(parent: Node3D, faces: Array, inside: Vector3, m: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Array in faces:
		var c := Vector3.ZERO
		for v: Vector3 in f:
			c += v
		c /= float(f.size())
		var n := ((f[1] as Vector3) - (f[0] as Vector3)).cross((f[2] as Vector3) - (f[0] as Vector3))
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		if n.dot(c - inside) < 0.0:
			n = -n
		for i in range(1, f.size() - 1):
			_tri(st, f[0], f[i], f[i + 1], n, n, n)
	return M._add(parent, st.commit(), pos, m)

## Superficie de revolución. `prof` = lista de Vector2(radio, altura) de abajo arriba. smooth = normales suaves; si no, caras planas
## (pirámides y conos de pocos lados). `phase` gira el reparto de lados.
static func lathe(parent: Node3D, prof: Array, seg: int, pos: Vector3, m: Material, smooth: bool = true, phase: float = 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var np := prof.size()
	var seg_n: Array = []
	for i in np - 1:
		var d: Vector2 = (prof[i + 1] as Vector2) - (prof[i] as Vector2)
		seg_n.append(Vector2(d.y, -d.x).normalized())
	for i in np - 1:
		var p0: Vector2 = prof[i]
		var p1: Vector2 = prof[i + 1]
		var n0: Vector2 = seg_n[i]
		var n1: Vector2 = seg_n[i]
		if smooth:
			if i > 0:
				n0 = ((seg_n[i - 1] as Vector2) + (seg_n[i] as Vector2)).normalized()
			if i + 1 < np - 1:
				n1 = ((seg_n[i] as Vector2) + (seg_n[i + 1] as Vector2)).normalized()
		for k in seg:
			var a0 := phase + TAU * float(k) / float(seg)
			var a1 := phase + TAU * float(k + 1) / float(seg)
			var am := (a0 + a1) * 0.5
			var v00 := Vector3(p0.x * cos(a0), p0.y, p0.x * sin(a0))
			var v01 := Vector3(p0.x * cos(a1), p0.y, p0.x * sin(a1))
			var v10 := Vector3(p1.x * cos(a0), p1.y, p1.x * sin(a0))
			var v11 := Vector3(p1.x * cos(a1), p1.y, p1.x * sin(a1))
			var nn00: Vector3
			var nn01: Vector3
			var nn10: Vector3
			var nn11: Vector3
			if smooth:
				nn00 = Vector3(n0.x * cos(a0), n0.y, n0.x * sin(a0))
				nn01 = Vector3(n0.x * cos(a1), n0.y, n0.x * sin(a1))
				nn10 = Vector3(n1.x * cos(a0), n1.y, n1.x * sin(a0))
				nn11 = Vector3(n1.x * cos(a1), n1.y, n1.x * sin(a1))
			else:
				var sn: Vector2 = seg_n[i]
				nn00 = Vector3(sn.x * cos(am), sn.y, sn.x * sin(am))
				nn01 = nn00
				nn10 = nn00
				nn11 = nn00
			_tri(st, v00, v10, v11, nn00, nn10, nn11)
			_tri(st, v00, v11, v01, nn00, nn11, nn01)
	return M._add(parent, st.commit(), pos, m)

## Perfil de cúpula (cuarto de elipse) de radio r y altura h.
static func dome_prof(r: float, h: float, n: int = 8) -> Array:
	var p: Array = []
	for i in n + 1:
		var t := PI * 0.5 * float(i) / float(n)
		p.append(Vector2(r * cos(t), h * sin(t)))
	return p

## Perfil de cúpula bulbosa («cebolla») de radio máximo r y altura h.
static func onion_prof(r: float, h: float) -> Array:
	var pts := [[0.62, 0.0], [0.86, 0.09], [1.0, 0.24], [0.94, 0.38], [0.66, 0.53], [0.34, 0.68], [0.16, 0.82], [0.06, 0.93], [0.0, 1.0]]
	var p: Array = []
	for q in pts:
		p.append(Vector2(r * float(q[0]), h * float(q[1])))
	return p

## Perfil de aguja con vuelo (el tejado se ensancha en el alero): radio r, altura h.
static func flare_prof(r: float, h: float) -> Array:
	var pts := [[1.0, 0.0], [0.86, 0.10], [0.66, 0.30], [0.46, 0.55], [0.26, 0.80], [0.0, 1.0]]
	var p: Array = []
	for q in pts:
		p.append(Vector2(r * float(q[0]), h * float(q[1])))
	return p

## Perfil de tejado de pagoda: cóncavo, con el alero levantado. radio r, altura h.
static func pagoda_prof(r: float, h: float) -> Array:
	var pts := [[1.0, 0.18], [0.80, 0.0], [0.58, 0.02], [0.40, 0.14], [0.24, 0.38], [0.10, 0.70], [0.0, 1.0]]
	var p: Array = []
	for q in pts:
		p.append(Vector2(r * float(q[0]), h * float(q[1])))
	return p

## Prisma recto: contorno 2D (x, y) extruido `depth` a lo largo de z (centrado en z = 0). Admite contornos cóncavos.
## Para verlo en la cara +x del edificio se gira el nodo devuelto 90° en y.
static func extrude(parent: Node3D, pts: PackedVector2Array, depth: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := depth * 0.5
	var idx := Geometry2D.triangulate_polygon(pts)
	if idx.is_empty():
		for i in range(1, pts.size() - 1):
			idx.append(0)
			idx.append(i)
			idx.append(i + 1)
	for t in range(0, idx.size(), 3):
		var a := pts[idx[t]]
		var b := pts[idx[t + 1]]
		var c := pts[idx[t + 2]]
		_tri(st, Vector3(a.x, a.y, hz), Vector3(b.x, b.y, hz), Vector3(c.x, c.y, hz), Vector3.BACK, Vector3.BACK, Vector3.BACK)
		_tri(st, Vector3(a.x, a.y, -hz), Vector3(b.x, b.y, -hz), Vector3(c.x, c.y, -hz), Vector3.FORWARD, Vector3.FORWARD, Vector3.FORWARD)
	var area := 0.0
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		area += p.x * q.y - q.x * p.y
	for i in pts.size():
		var a2 := pts[i]
		var b2 := pts[(i + 1) % pts.size()]
		var e := b2 - a2
		if e.length_squared() < 1e-10:
			continue
		var n2 := Vector2(e.y, -e.x).normalized()
		if area < 0.0:
			n2 = -n2
		var nn := Vector3(n2.x, n2.y, 0.0)
		var va := Vector3(a2.x, a2.y, hz)
		var vb := Vector3(b2.x, b2.y, hz)
		var vc := Vector3(b2.x, b2.y, -hz)
		var vd := Vector3(a2.x, a2.y, -hz)
		_tri(st, va, vb, vc, nn, nn, nn)
		_tri(st, va, vc, vd, nn, nn, nn)
	return M._add(parent, st.commit(), pos, m)

## Contorno de un hueco con arco: kind = "round" (medio punto), "pointed" (apuntado/gótico), "horseshoe" (herradura),
## "flat" (adintelado). Ancho w, altura h hasta el arranque del arco; el origen está en el centro de la base.
static func arch_outline(w: float, h: float, kind: String = "round", n: int = 10) -> PackedVector2Array:
	var p := PackedVector2Array()
	var hw := w * 0.5
	if kind == "flat":
		p.append(Vector2(-hw, 0.0))
		p.append(Vector2(-hw, h))
		p.append(Vector2(hw, h))
		p.append(Vector2(hw, 0.0))
		return p
	if kind == "pointed":
		p.append(Vector2(-hw, 0.0))
		p.append(Vector2(-hw, h))
		for i in range(1, n):   # arco izquierdo: centro (+hw, h), radio w, de 180° a 120°
			var t := deg_to_rad(180.0 - 60.0 * float(i) / float(n))
			p.append(Vector2(hw + w * cos(t), h + w * sin(t)))
		p.append(Vector2(0.0, h + w * 0.866))
		for i in range(1, n):   # arco derecho: centro (−hw, h), de 60° a 0°
			var t2 := deg_to_rad(60.0 - 60.0 * float(i) / float(n))
			p.append(Vector2(-hw + w * cos(t2), h + w * sin(t2)))
		p.append(Vector2(hw, h))
		p.append(Vector2(hw, 0.0))
		return p
	if kind == "horseshoe":
		var r := w * 0.58
		p.append(Vector2(-hw, 0.0))
		for i in n * 2 + 1:
			var t3 := deg_to_rad(210.0 - 240.0 * float(i) / float(n * 2))
			p.append(Vector2(r * cos(t3), h + r * sin(t3)))
		p.append(Vector2(hw, 0.0))
		return p
	p.append(Vector2(-hw, 0.0))
	p.append(Vector2(-hw, h))
	for i in range(1, n):
		var t4 := PI - PI * float(i) / float(n)
		p.append(Vector2(hw * cos(t4), h + hw * sin(t4)))
	p.append(Vector2(hw, h))
	p.append(Vector2(hw, 0.0))
	return p

## Puerta o ventana con arco sobre la cara +z (face_x = false) o +x. Marco (un poco mayor y más atrás) y hueco encima.
## Devuelve la altura total del hueco.
static func arch_hole(parent: Node3D, pos: Vector3, w: float, h: float, face_x: bool, hole_m: Material, frame_m: Material = null, kind: String = "round", frame_w: float = 0.07) -> float:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = 90.0 if face_x else 0.0
	parent.add_child(holder)
	if frame_m != null:
		extrude(holder, arch_outline(w + frame_w * 2.0, h + frame_w, kind), 0.05, Vector3(0, 0, 0.0), frame_m)
	extrude(holder, arch_outline(w, h, kind), 0.07, Vector3(0, 0, 0.01), hole_m)
	var top := h + (w * 0.5 if kind == "round" else (w * 0.866 if kind == "pointed" else w * 0.58))
	return top

# ------------------------------------------------------------------ tejados

## Tejado a cuatro aguas sobre un rectángulo lx × lz (la cumbrera corre a lo largo del lado mayor).
static func hip(parent: Node3D, lx: float, lz: float, rise: float, y: float, m: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var hx := lx * 0.5
	var hz := lz * 0.5
	var a := Vector3(-hx, y, -hz)
	var b := Vector3(hx, y, -hz)
	var c := Vector3(hx, y, hz)
	var d := Vector3(-hx, y, hz)
	var faces: Array
	if lx >= lz:
		var rl := (lx - lz) * 0.5
		var r1 := Vector3(-rl, y + rise, 0.0)
		var r2 := Vector3(rl, y + rise, 0.0)
		faces = [[d, c, r2, r1], [b, a, r1, r2], [a, d, r1], [c, b, r2]]
	else:
		var rz := (lz - lx) * 0.5
		var r3 := Vector3(0.0, y + rise, -rz)
		var r4 := Vector3(0.0, y + rise, rz)
		faces = [[a, d, r4, r3], [c, b, r3, r4], [d, c, r4], [b, a, r3]]
	return solid(parent, faces, Vector3(0.0, y + rise * 0.3, 0.0), m, pos)

## Cono (o cono truncado) de base `r_bot` y punta/radio superior `r_top`, desde y.
static func cone(parent: Node3D, r_bot: float, h: float, y: float, m: Material, pos: Vector3 = Vector3.ZERO, seg: int = 16, r_top: float = 0.0) -> MeshInstance3D:
	return M.cyl(parent, r_top, r_bot, h, pos + Vector3(0, y + h * 0.5, 0), m, seg)

## Pirámide cuadrada de lado w (lados planos), desde y.
static func pyramid(parent: Node3D, w: float, h: float, y: float, m: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return lathe(parent, [Vector2(w * 0.7071, 0.0), Vector2(0.0, h)], 4, pos + Vector3(0, y, 0), m, false, PI * 0.25)

# ------------------------------------------------------------------ torres y almenas

## Almenas apuntadas (sarracenas): prismas triangulares sobre el borde de un rectángulo (hw, hd = medias dimensiones).
static func _rim_pointed(parent: Node3D, hw: float, hd: float, y: float, m: Material, step: float = 0.30) -> void:
	var nx := maxi(2, int(round(hw * 2.0 / step)))
	for i in nx + 1:
		var x := -hw + hw * 2.0 * float(i) / float(nx)
		for sz in [-1, 1]:
			pyramid(parent, 0.16, 0.20, y, m, Vector3(x, 0.0, sz * hd))
	var nz := maxi(2, int(round(hd * 2.0 / step)))
	for j in range(1, nz):
		var z := -hd + hd * 2.0 * float(j) / float(nz)
		for sx in [-1, 1]:
			pyramid(parent, 0.16, 0.20, y, m, Vector3(sx * hw, 0.0, z))

## Torre cuadrada de sillería con zócalo, fuste, voladizo con matacanes y adarve. o: {"cap": "none"|"pyramid"|"cone"|"dome"|"hip",
## "cap_m": Material, "cap_h": float, "pointed": bool (almenas apuntadas), "bartizans": bool o lista de esquinas Vector2(±1, ±1) (garitas),
## "bart_m": Material (tejadillo de las garitas), "door": bool}. Devuelve la altura del adarve.
static func tower_sq(parent: Node3D, c: Vector3, w: float, h: float, F: Dictionary, o: Dictionary = {}) -> float:
	var hw := w * 0.5
	M.box(parent, Vector3(w + 0.12, 0.20, w + 0.12), c + Vector3(0, 0.10, 0), F.dark)
	M.box(parent, Vector3(w + 0.16, 0.05, w + 0.16), c + Vector3(0, 0.225, 0), F.trim)
	var body_h := h - 0.20 - 0.44
	M.box(parent, Vector3(w, body_h, w), c + Vector3(0, 0.20 + body_h * 0.5, 0), F.wall)
	var yb := 0.20 + body_h
	M.box(parent, Vector3(w + 0.10, 0.10, w + 0.10), c + Vector3(0, yb + 0.05, 0), F.dark)
	M.box(parent, Vector3(w + 0.24, 0.30, w + 0.24), c + Vector3(0, yb + 0.25, 0), F.wall)
	for k in [-0.28, 0.0, 0.28]:
		M.box(parent, Vector3(0.12, 0.10, 0.07), c + Vector3(k * w * 1.4, yb + 0.05, hw + 0.075), F.light)
		M.box(parent, Vector3(0.07, 0.10, 0.12), c + Vector3(hw + 0.075, yb + 0.05, k * w * 1.4), F.light)
	var ytop := yb + 0.40
	M.box(parent, Vector3(w + 0.28, 0.05, w + 0.28), c + Vector3(0, ytop + 0.025, 0), F.trim)
	M.box(parent, Vector3(w + 0.10, 0.03, w + 0.10), c + Vector3(0, ytop + 0.05, 0), F.floor)
	var cap: String = o.get("cap", "none")
	var half := (w + 0.24) * 0.5 - 0.065
	if cap == "none":
		var crown := Node3D.new()
		crown.position = c
		parent.add_child(crown)
		if o.get("pointed", false):
			_rim_pointed(crown, half, half, ytop + 0.05, F.light)
		else:
			M._rim(crown, half, half, ytop + 0.05, F.light)
	var cm: Material = o.get("cap_m", F.dark)
	var chh: float = o.get("cap_h", 1.0)
	var rw := w + 0.30
	match cap:
		"pyramid":
			pyramid(parent, rw, chh, ytop + 0.05, cm, c)
		"cone":
			cone(parent, rw * 0.74, chh, ytop + 0.05, cm, c, 20)
		"dome":
			lathe(parent, dome_prof(rw * 0.55, chh), 18, c + Vector3(0, ytop + 0.05, 0), cm)
		"hip":
			hip(parent, rw, rw, chh, ytop + 0.05, cm, c)
	M._slits(parent, c, hw, [0.9, 1.5], F)
	if o.get("door", false):
		M.box(parent, Vector3(0.34, 0.50, 0.06), c + Vector3(0.0, 0.20 + 0.25, hw + 0.03), F.wood)
	var bz: Variant = o.get("bartizans", false)
	if bz is bool and bz:
		bz = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	if bz is Array:
		var bm: Material = o.get("bart_m", F.dark)
		for q: Vector2 in bz:
			bartizan(parent, c + Vector3(q.x * (hw + 0.10), yb + 0.10, q.y * (hw + 0.10)), 0.17, 0.46, F, bm)
	return ytop + 0.05

## Garita redonda sobre repisa (en el vuelo de una esquina): tronco, aro y tejadillo cónico.
static func bartizan(parent: Node3D, pos: Vector3, r: float, h: float, F: Dictionary, cap_m: Material) -> void:
	M.cyl(parent, r * 0.55, r * 1.05, 0.14, pos + Vector3(0, 0.07, 0), F.dark, 10)
	M.cyl(parent, r, r, h, pos + Vector3(0, 0.14 + h * 0.5, 0), F.wall, 12)
	M.cyl(parent, r * 1.12, r * 1.12, 0.05, pos + Vector3(0, 0.14 + h, 0), F.trim, 12)
	cone(parent, r * 1.30, r * 2.0, 0.14 + h + 0.025, cap_m, pos, 12)

## Torre redonda de sillería con zócalo y fuste algo cónico; `cap` = material del tejado cónico (null = adarve con almenas).
## Devuelve la altura del adarve / del arranque del tejado.
static func tower_round(parent: Node3D, c: Vector3, r: float, h: float, F: Dictionary, cap: Material = null, cap_h: float = 1.0, flare: bool = true) -> float:
	M.cyl(parent, r * 1.10, r * 1.18, 0.20, c + Vector3(0, 0.10, 0), F.dark, 22)
	M.cyl(parent, r, r * 1.06, h - 0.20, c + Vector3(0, 0.20 + (h - 0.20) * 0.5, 0), F.wall, 22)
	M.cyl(parent, r * 1.16, r * 1.04, 0.14, c + Vector3(0, h + 0.07, 0), F.dark, 22)
	M.cyl(parent, r * 1.16, r * 1.16, 0.20, c + Vector3(0, h + 0.24, 0), F.wall, 22)
	var yt := h + 0.34
	M.cyl(parent, r * 1.22, r * 1.22, 0.05, c + Vector3(0, yt + 0.025, 0), F.trim, 22)
	if cap == null:
		M.cyl(parent, r * 1.10, r * 1.10, 0.03, c + Vector3(0, yt + 0.065, 0), F.floor, 22)
		var ring := Node3D.new()
		ring.position = c + Vector3(0, yt + 0.05, 0)
		parent.add_child(ring)
		M._ring_rim(ring, r * 1.10, 0.0, maxi(8, int(r * 22.0)), F.light)
	else:
		if flare:
			lathe(parent, flare_prof(r * 1.34, cap_h), 20, c + Vector3(0, yt + 0.05, 0), cap)
		else:
			cone(parent, r * 1.30, cap_h, yt + 0.05, cap, c, 20)
	# saeteras
	for yy in [h * 0.35, h * 0.68]:
		for a in [PI * 0.25, PI * 0.75]:
			var piv := Node3D.new()
			piv.position = c
			piv.rotation.y = -a
			parent.add_child(piv)
			M.box(piv, Vector3(0.05, 0.26, 0.06), Vector3(r * 1.02, yy, 0), F.slit)
	return yt + 0.05

## Bloque de muralla con almenas (cuadradas o apuntadas): sx × sz de planta y altura h.
static func wall_block(parent: Node3D, F: Dictionary, sx: float, h: float, sz: float, pos: Vector3, pointed: bool = false) -> void:
	if not pointed:
		M._wall_block(parent, F, sx, h, sz, pos)
		return
	M.box(parent, Vector3(sx + 0.04, 0.14, sz + 0.04), pos + Vector3(0, 0.07, 0), F.dark)
	M.box(parent, Vector3(sx + 0.06, 0.035, sz + 0.06), pos + Vector3(0, 0.155, 0), F.trim)
	M.box(parent, Vector3(sx, h - 0.17, sz), pos + Vector3(0, 0.17 + (h - 0.17) * 0.5, 0), F.wall)
	M.box(parent, Vector3(sx + 0.05, 0.05, sz + 0.05), pos + Vector3(0, h + 0.025, 0), F.light)
	var along_x := sx >= sz
	var L := sx if along_x else sz
	var T := sz if along_x else sx
	var n := maxi(2, int(round(L / 0.25)))
	for i in n + 1:
		var u := -L * 0.5 + L * float(i) / float(n)
		for side in [-1, 1]:
			var off := float(side) * (T * 0.5 - 0.06)
			var p := Vector3(u, h + 0.05, off) if along_x else Vector3(off, h + 0.05, u)
			pyramid(parent, 0.15, 0.18, 0.0, F.light, pos + p)

# ------------------------------------------------------------------ murallas por enlaces (poste + 8 brazos + 2 puertas)

## Poste de muralla (la casilla entera): pilar con almenas y una placa del color del equipo en las dos caras visibles.
static func wall_post(F: Dictionary, pointed: bool = false) -> Node3D:
	var root := Node3D.new()
	wall_block(root, F, 0.60, 1.18, 0.60, Vector3.ZERO, pointed)
	var tm := M.fmat(M.TEAM_BASE, 0.7, 0.3)
	M.box(root, Vector3(0.20, 0.20, 0.03), Vector3(0.0, 0.78, 0.31), tm)
	M.box(root, Vector3(0.03, 0.20, 0.20), Vector3(0.31, 0.78, 0.0), tm)
	return root

## Brazo de muralla desde el centro de la casilla hacia la dirección d (0..7, como M.DIRS8).
static func wall_arm(d: int, F: Dictionary, pointed: bool = false) -> Node3D:
	var root := Node3D.new()
	var dir: Vector2 = M.DIRS8[d]
	var diag := dir.x != 0.0 and dir.y != 0.0
	var L := 0.7071 if diag else 0.5
	var body := Node3D.new()
	root.add_child(body)
	wall_block(body, F, L + 0.04, 1.05, 0.46, Vector3(L * 0.5, 0, 0), pointed)
	body.rotation.y = atan2(-dir.y, dir.x)
	return root

## Puerta de muralla: dos jambas, dintel con arco y hojas de madera. along_x = la muralla sigue a lo largo de x (se pasa por z).
static func wall_gate(along_x: bool, F: Dictionary, door_m: Material, arch: String = "flat", pointed: bool = false) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	for sx in [-1, 1]:
		wall_block(body, F, 0.34, 1.32, 0.56, Vector3(sx * 0.33, 0, 0), pointed)
	wall_block(body, F, 1.0, 0.30, 0.50, Vector3(0, 0.95, 0), pointed)
	var iron := M.fmat(Color(0.22, 0.22, 0.25), 0.5, 0.6)
	if arch == "flat":
		M.box(body, Vector3(0.32, 0.78, 0.07), Vector3(-0.16, 0.39, 0.0), door_m)
		M.box(body, Vector3(0.32, 0.78, 0.07), Vector3(0.16, 0.39, 0.0), door_m)
		for yy in [0.22, 0.58]:
			M.box(body, Vector3(0.66, 0.045, 0.09), Vector3(0, yy, 0), iron)
	else:
		# hueco con arco en las dos caras (se ve desde +z; el cuerpo se gira para la otra orientación)
		for sz in [-1, 1]:
			extrude(body, arch_outline(0.64, 0.46, arch), 0.06, Vector3(0, 0.0, sz * 0.265), door_m)
		M.box(body, Vector3(0.64, 0.46, 0.46), Vector3(0, 0.23, 0.0), F.slit)
		for yy in [0.20, 0.42]:
			M.box(body, Vector3(0.64, 0.04, 0.5), Vector3(0, yy, 0.0), iron)
	M.box(body, Vector3(0.20, 0.20, 0.03), Vector3(0.0, 1.30, 0.29), M.fmat(M.TEAM_BASE, 0.7, 0.3))
	body.rotation_degrees.y = 0.0 if along_x else 90.0
	return root

# ------------------------------------------------------------------ piezas sueltas

static func chimney(parent: Node3D, pos: Vector3, w: float, h: float, wall: Material, cap: Material) -> void:
	M.box(parent, Vector3(w, h, w), pos + Vector3(0, h * 0.5, 0), wall)
	M.box(parent, Vector3(w * 1.3, 0.05, w * 1.3), pos + Vector3(0, h + 0.025, 0), cap)
	smoke_src(parent, pos + Vector3(0, h + 0.07, 0))

## Marcador (nodo vacío «smoke») del punto por donde sale el humo del edificio: tools/iso/civ_meta.gd lo lee al generar los datos
## de la civilización y el juego dibuja ahí las bocanadas. Ponlo en chimeneas, aberturas de techo o fraguas; no se hornea.
static func smoke_src(parent: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	n.name = "smoke"
	n.position = pos
	parent.add_child(n)

## Arquería adosada a una pared: n arcos de ancho `span` con pilares hasta la altura h (arranque del arco), tímpanos y dintel de
## `m`; el fondo oscuro `back_m` se ve por los huecos. along_x = la fila corre a lo largo de x y mira a +z; si no, corre a lo largo de z
## y mira a +x. `o` = centro de la fila a nivel del suelo y en la cara de los pilares.
static func arcade(parent: Node3D, o: Vector3, along_x: bool, n: int, span: float, h: float, m: Material, back_m: Material, kind: String = "round", round_p: bool = true) -> float:
	var total := span * float(n)
	var holder := Node3D.new()
	holder.position = o
	holder.rotation_degrees.y = 0.0 if along_x else 90.0
	parent.add_child(holder)
	var ol := arch_outline(span - 0.04, h, kind, 8)
	var arch_top := 0.0
	for p in ol:
		arch_top = maxf(arch_top, p.y)
	var ytop := arch_top + 0.07
	M.box(holder, Vector3(total, ytop, 0.04), Vector3(0, ytop * 0.5, -0.10), back_m)
	for i in n:
		var xc := -total * 0.5 + span * (float(i) + 0.5)
		var sp := PackedVector2Array()
		for k in range(1, ol.size() - 1):
			sp.append(ol[k])
		sp.append(Vector2(span * 0.5, ytop))
		sp.append(Vector2(-span * 0.5, ytop))
		extrude(holder, sp, 0.13, Vector3(xc, 0.0, -0.02), m)
	for i in n + 1:
		var x := -total * 0.5 + span * float(i)
		if round_p:
			M.cyl(holder, 0.055, 0.065, h + 0.04, Vector3(x, (h + 0.04) * 0.5, 0.0), m, 10)
			M.cyl(holder, 0.085, 0.085, 0.05, Vector3(x, h + 0.02, 0.0), m, 10)
		else:
			M.box(holder, Vector3(0.12, h + 0.06, 0.13), Vector3(x, (h + 0.06) * 0.5, -0.02), m)
	M.box(holder, Vector3(total + 0.14, 0.07, 0.19), Vector3(0, ytop + 0.035, -0.02), m)
	return ytop + 0.07

## Tinaja de barro (cuerpo, cuello y borde).
static func jar(parent: Node3D, pos: Vector3, m: Material, r: float = 0.11) -> void:
	M.ball(parent, r, pos + Vector3(0, r * 1.05, 0), m, Vector3(1.0, 1.15, 1.0))
	M.cyl(parent, r * 0.50, r * 0.58, r * 0.7, pos + Vector3(0, r * 2.1, 0), m, 12)
	M.cyl(parent, r * 0.62, r * 0.62, 0.025, pos + Vector3(0, r * 2.48, 0), m, 12)

## Toldo inclinado de rayas sobre una puerta de la cara +z: `tm` es el material de las rayas de color (p. ej. de equipo), las otras son telas blancas.
static func awning(parent: Node3D, pos: Vector3, w: float, d: float, tm: Material, S: Dictionary, tilt: float = 16.0) -> void:
	M.box(parent, Vector3(w, 0.03, d), pos, tm).rotation_degrees.x = tilt
	for k in 4:
		M.box(parent, Vector3(w / 8.0, 0.034, d), pos + Vector3(-w * 0.375 + k * w * 0.25, 0.001, 0.0), S.cloth_w).rotation_degrees.x = tilt
	for sx in [-1, 1]:
		M.box(parent, Vector3(0.025, 0.02, d * 0.95), pos + Vector3(sx * (w * 0.5 + 0.005), -0.02, 0.0), S.wood).rotation_degrees.x = tilt

## Ciprés (o árbol estrecho) de altura h.
static func cypress(parent: Node3D, pos: Vector3, h: float, S: Dictionary, col: Color = Color(0.12, 0.30, 0.14)) -> void:
	M.cyl(parent, 0.02, 0.025, 0.14, pos + Vector3(0, 0.07, 0), S.wood, 6)
	lathe(parent, [Vector2(0.0, 0.12), Vector2(0.13, 0.20), Vector2(0.15, h * 0.35), Vector2(0.11, h * 0.70), Vector2(0.04, h * 0.93), Vector2(0.0, h)], 10, pos, M.fmat(col, 0.95, 0.1))

## Entramado de madera sobre una pared: largueros arriba y abajo, montantes cada `step` y tornapuntas en diagonal.
## `c` = centro de la base de la pared (en su superficie); face_x = false: pared que mira a +z, w de ancho a lo largo de x;
## face_x = true: mira a +x y se extiende a lo largo de z.
static func timber(parent: Node3D, c: Vector3, w: float, h: float, face_x: bool, m: Material, step: float = 0.40, braces: bool = true, t: float = 0.06) -> void:
	var holder := Node3D.new()
	holder.position = c
	holder.rotation_degrees.y = 90.0 if face_x else 0.0
	parent.add_child(holder)
	var zf := 0.02
	M.box(holder, Vector3(w, t, 0.05), Vector3(0, t * 0.5, zf), m)
	M.box(holder, Vector3(w, t, 0.05), Vector3(0, h - t * 0.5, zf), m)
	var nb := maxi(1, int(round(w / step)))
	var bw := w / float(nb)
	for i in nb + 1:
		M.box(holder, Vector3(t, h, 0.05), Vector3(-w * 0.5 + bw * float(i), h * 0.5, zf), m)
	if braces:
		for i in nb:
			var x := -w * 0.5 + bw * (float(i) + 0.5)
			var L := sqrt(bw * bw + (h - t * 2.0) * (h - t * 2.0))
			var br := M.box(holder, Vector3(L, t * 0.8, 0.045), Vector3(x, h * 0.5, zf), m)
			var ang := atan2(h - t * 2.0, bw)
			br.rotation.z = ang if i % 2 == 0 else -ang

# ------------------------------------------------------------------ patios y accesorios comunes (mismas coordenadas que los modelos genéricos)

## Campo de tiro de la arquería (a la derecha y delante del edificio de la arquería): valla, dos dianas, carcaj y fardos.
static func archery_field(root: Node3D, S: Dictionary, tm: Material) -> void:
	B.fence(root, Vector3(0.70, 0, 1.40), Vector3(1.40, 0, 1.40), S)
	B.fence(root, Vector3(1.40, 0, 1.40), Vector3(1.40, 0, 0.0), S)
	B.fence(root, Vector3(-1.40, 0, 1.40), Vector3(0.30, 0, 1.40), S)
	for tz in [0.2, 0.85]:
		var tp := Vector3(0.82 if tz == 0.2 else 0.80, 0, tz)
		for lx in [-0.15, 0.15]:
			M.box(root, Vector3(0.04, 0.55, 0.04), tp + Vector3(0.05, 0.27, lx), S.wood).rotation_degrees.z = 8.0 * signf(lx)
		var tgt := Node3D.new()
		tgt.position = tp + Vector3(0.0, 0.50, 0)
		tgt.rotation_degrees.z = 90.0
		root.add_child(tgt)
		M.cyl(tgt, 0.25, 0.25, 0.07, Vector3.ZERO, S.straw, 20)
		M.cyl(tgt, 0.20, 0.20, 0.075, Vector3.ZERO, S.cloth_w, 20)
		M.cyl(tgt, 0.145, 0.145, 0.08, Vector3.ZERO, tm, 20)
		M.cyl(tgt, 0.075, 0.075, 0.085, Vector3.ZERO, S.cloth_w, 20)
		for a in [Vector2(0.03, 0.06), Vector2(-0.10, -0.05), Vector2(0.12, -0.08)]:
			M.box(tgt, Vector3(0.02, 0.36, 0.02), Vector3(a.x, -0.14, a.y), S.wood_l).rotation_degrees.x = 90.0
	B.barrel(root, Vector3(-1.30, 0.0, 0.30), S, 0.10, 0.26)
	for k in 4:
		M.box(root, Vector3(0.015, 0.44, 0.015), Vector3(-1.30 + (k - 1.5) * 0.025, 0.46, 0.30), S.wood_l).rotation_degrees.z = (k - 1.5) * 4.0
	B.hay_bale(root, Vector3(-0.90, 0.0, 1.05), S)
	B.hay_bale(root, Vector3(-0.60, 0.0, 1.05), S)

## Cercado del establo con abrevadero y fardos.
static func corral(root: Node3D, S: Dictionary) -> void:
	B.fence(root, Vector3(0.95, 0, 1.45), Vector3(1.45, 0, 1.45), S)
	B.fence(root, Vector3(1.45, 0, 1.45), Vector3(1.45, 0, 0.35), S)
	B.fence(root, Vector3(-1.40, 0, 1.45), Vector3(0.20, 0, 1.45), S)
	M.box(root, Vector3(0.50, 0.12, 0.16), Vector3(1.22, 0.10, 1.15), S.wood)
	M.box(root, Vector3(0.44, 0.02, 0.10), Vector3(1.22, 0.17, 1.15), S.water)
	B.hay_bale(root, Vector3(1.20, 0.0, 0.62), S, false)
	B.hay_bale(root, Vector3(1.22, 0.30, 0.64), S, false)
	B.hay_bale(root, Vector3(-1.05, 0.0, 1.00), S)
	B.hay_bale(root, Vector3(-0.72, 0.0, 1.05), S)

## Yunque, tajo, cubo de agua, carbón y lingotes delante de una herrería (huella 3x3 con el edificio en c = (-0.2, 0, -0.35)).
static func forge_yard(root: Node3D, S: Dictionary) -> void:
	var ay := Vector3(0.45, 0, 1.05)
	M.box(root, Vector3(0.18, 0.18, 0.18), ay + Vector3(0, 0.09, 0), S.wood_l)
	M.box(root, Vector3(0.30, 0.07, 0.12), ay + Vector3(0, 0.215, 0), S.iron)
	M.box(root, Vector3(0.10, 0.05, 0.10), ay + Vector3(0.18, 0.21, 0), S.iron)
	B.barrel(root, Vector3(-0.30, 0.0, 1.12), S, 0.13, 0.30)
	M.box(root, Vector3(0.24, 0.015, 0.24), Vector3(-0.30, 0.295, 1.12), S.water)
	M.ball(root, 0.14, Vector3(-1.10, 0.10, 1.00), S.dark, Vector3(1.4, 0.7, 1.1))
	M.box(root, Vector3(0.18, 0.05, 0.08), Vector3(-0.88, 0.03, 1.12), S.steel)
	M.box(root, Vector3(0.18, 0.05, 0.08), Vector3(-0.88, 0.08, 1.12), S.steel)

## Muelle de tablones al frente (z+), bolardos, grúa de carga, barriles y cajas, para el puerto (edificio en c = (0, 0, -0.45)).
static func pier(root: Node3D, S: Dictionary) -> void:
	M.box(root, Vector3(2.20, 0.08, 0.70), Vector3(0, 0.04, 1.00), S.wood_l)
	for k in 8:
		M.box(root, Vector3(0.015, 0.09, 0.70), Vector3(-1.05 + k * 0.30, 0.045, 1.00), S.wood)
	for sx in [-1.05, 0.0, 1.05]:
		M.cyl(root, 0.07, 0.07, 0.30, Vector3(sx, 0.15, 1.34), S.wood, 8)
	M.box(root, Vector3(0.10, 1.30, 0.10), Vector3(0.95, 0.65, 0.85), S.wood)
	M.box(root, Vector3(0.90, 0.07, 0.08), Vector3(0.52, 1.28, 0.85), S.wood)
	M.box(root, Vector3(0.50, 0.05, 0.05), Vector3(0.70, 1.04, 0.85), S.wood).rotation_degrees.z = 40.0
	M.box(root, Vector3(0.015, 0.50, 0.015), Vector3(0.12, 1.02, 0.85), S.rope)
	M.box(root, Vector3(0.16, 0.14, 0.16), Vector3(0.12, 0.72, 0.85), S.wood_l)
	B.barrel(root, Vector3(-0.85, 0.08, 0.95), S)
	B.barrel(root, Vector3(-0.60, 0.08, 1.05), S, 0.10, 0.22)
	B.crate(root, Vector3(-0.30, 0.08, 1.08), S, 0.26, 10.0)
	B.crate(root, Vector3(-0.10, 0.08, 1.12), S, 0.22, -12.0)
	M.cyl(root, 0.12, 0.12, 0.08, Vector3(0.40, 0.12, 1.08), S.rope, 14)

## Grúa, troncos y bastidor de ariete delante del taller de asedio (edificio en c = (-0.2, 0, -0.35)).
static func siege_yard(root: Node3D, S: Dictionary) -> void:
	M.box(root, Vector3(0.10, 1.40, 0.10), Vector3(0.95, 0.70, 1.15), S.wood)
	M.box(root, Vector3(0.80, 0.07, 0.07), Vector3(0.62, 1.38, 1.15), S.wood)
	M.box(root, Vector3(0.50, 0.05, 0.05), Vector3(0.78, 1.14, 1.15), S.wood).rotation_degrees.z = 40.0
	M.box(root, Vector3(0.015, 0.56, 0.015), Vector3(0.38, 1.10, 1.15), S.rope)
	M.box(root, Vector3(0.07, 0.07, 0.07), Vector3(0.38, 0.80, 1.15), S.iron)
	for k in 3:
		M.cyl(root, 0.08, 0.08, 0.80, Vector3(-1.20, 0.08 + (k % 2) * 0.12, 0.45 + (k / 2) * 0.16 + (k % 2) * 0.08), S.wood_l, 10).rotation_degrees.x = 90.0
	var fr := Vector3(-0.30, 0, 1.30)
	for sx in [-0.40, 0.40]:
		M.box(root, Vector3(0.06, 0.34, 0.06), fr + Vector3(sx, 0.17, 0.0), S.wood)
	M.box(root, Vector3(0.90, 0.06, 0.07), fr + Vector3(0, 0.34, 0.0), S.wood)
	M.cyl(root, 0.05, 0.05, 0.78, fr + Vector3(0, 0.22, 0.0), S.wood_l, 8).rotation_degrees.z = 90.0
	M.box(root, Vector3(0.10, 0.10, 0.10), fr + Vector3(0.40, 0.22, 0.0), S.iron)

## Patio del cuartel: maniquí de entrenamiento y soporte de lanzas.
static func drill_yard(root: Node3D, S: Dictionary, x: float = 1.10, z: float = 1.40) -> void:
	M.box(root, Vector3(0.05, 0.62, 0.05), Vector3(x, 0.31, z), S.wood)
	M.box(root, Vector3(0.40, 0.05, 0.05), Vector3(x, 0.50, z), S.wood)
	M.ball(root, 0.08, Vector3(x, 0.70, z), S.sack)
	M.box(root, Vector3(0.20, 0.20, 0.10), Vector3(x, 0.38, z), S.sack)
	for k in 4:
		M.box(root, Vector3(0.02, 0.78, 0.02), Vector3(-1.00 + k * 0.08, 0.40, z + 0.02), S.wood_l).rotation_degrees.x = -8.0
		M.box(root, Vector3(0.03, 0.08, 0.03), Vector3(-1.00 + k * 0.08, 0.80, z), S.steel)

## Ventana con parteluces y travesaño (cristal con rejilla de madera/plomo) en la cara +z o +x.
static func mullion(parent: Node3D, pos: Vector3, w: float, h: float, face_x: bool, S: Dictionary, frame: Material = null) -> void:
	var fm: Material = frame if frame != null else S.wood
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = 90.0 if face_x else 0.0
	parent.add_child(holder)
	M.box(holder, Vector3(w, h, 0.03), Vector3.ZERO, M.glass_mat())
	M.box(holder, Vector3(w + 0.05, 0.025, 0.045), Vector3(0, h * 0.5 + 0.012, 0.005), fm)
	M.box(holder, Vector3(w + 0.05, 0.025, 0.045), Vector3(0, -h * 0.5 - 0.012, 0.005), fm)
	M.box(holder, Vector3(0.025, h, 0.045), Vector3(-w * 0.5 - 0.012, 0, 0.005), fm)
	M.box(holder, Vector3(0.025, h, 0.045), Vector3(w * 0.5 + 0.012, 0, 0.005), fm)
	M.box(holder, Vector3(0.02, h, 0.04), Vector3(0, 0, 0.01), fm)
	M.box(holder, Vector3(w, 0.02, 0.04), Vector3(0, 0, 0.01), fm)

## Gablete escalonado (hastial de peldaños, típico del gótico de ladrillo): ancho w, altura h, `steps` peldaños por lado.
## Se dibuja en el plano z = const mirando a +z (o a +x con face_x); la base está en y = pos.y.
static func stepped_gable(parent: Node3D, pos: Vector3, w: float, h: float, steps: int, m: Material, face_x: bool = false, depth: float = 0.20, top_w: float = 0.14) -> void:
	var pts := PackedVector2Array()
	var hw := w * 0.5
	var dx := (hw - top_w * 0.5) / float(steps)
	var dy := h / float(steps + 1)
	pts.append(Vector2(-hw, 0.0))
	pts.append(Vector2(hw, 0.0))
	for i in steps:
		pts.append(Vector2(hw - dx * float(i), dy * float(i + 1)))
		pts.append(Vector2(hw - dx * float(i + 1), dy * float(i + 1)))
	pts.append(Vector2(top_w * 0.5, h))
	pts.append(Vector2(-top_w * 0.5, h))
	for i in range(steps - 1, -1, -1):
		pts.append(Vector2(-hw + dx * float(i + 1), dy * float(i + 1)))
		pts.append(Vector2(-hw + dx * float(i), dy * float(i + 1)))
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = 90.0 if face_x else 0.0
	parent.add_child(holder)
	extrude(holder, pts, depth, Vector3.ZERO, m)

## Escudo heráldico (forma de «almendra»): campo de `field` con cruz de `cross` (null = sin cruz). Mira a +z o a +x.
static func heater(parent: Node3D, pos: Vector3, w: float, face_x: bool, field: Material, cross: Material = null) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = 90.0 if face_x else 0.0
	parent.add_child(holder)
	var h := w * 1.2
	var pts := PackedVector2Array([Vector2(-w * 0.5, h * 0.5), Vector2(w * 0.5, h * 0.5), Vector2(w * 0.5, h * 0.05), Vector2(w * 0.28, -h * 0.28), Vector2(0, -h * 0.5),
		Vector2(-w * 0.28, -h * 0.28), Vector2(-w * 0.5, h * 0.05)])
	extrude(holder, pts, 0.05, Vector3.ZERO, field)
	if cross != null:
		M.box(holder, Vector3(w * 0.16, h * 0.86, 0.02), Vector3(0, 0.0, 0.03), cross)
		M.box(holder, Vector3(w * 0.80, w * 0.16, 0.02), Vector3(0, h * 0.14, 0.03), cross)

## Palmera datilera: tronco curvo de anillos y penacho de hojas.
static func palm(parent: Node3D, pos: Vector3, h: float, S: Dictionary) -> void:
	var trunk := M.fmat(Color(0.48, 0.36, 0.22), 0.9, 0.1)
	var leaf := M.fmat(Color(0.22, 0.46, 0.20), 0.9, 0.1)
	for i in 6:
		var t := float(i) / 5.0
		M.cyl(parent, 0.045 - t * 0.012, 0.05 - t * 0.012, h / 5.0, pos + Vector3(0.05 * t * t, h * (float(i) + 0.5) / 6.0, 0), trunk, 7)
	for k in 8:
		var a := TAU * float(k) / 8.0
		var lf := M.box(parent, Vector3(0.44, 0.015, 0.09), pos + Vector3(0.05 + cos(a) * 0.18, h + 0.03, sin(a) * 0.18), leaf)
		lf.rotation.y = -a
		lf.rotation.z = -0.4 if cos(a) >= 0.0 else 0.4

# ------------------------------------------------------------------ remates

## Cruz (de oro o del material dado) de altura h sobre la cara +z; se gira el nodo si hace falta verla de lado.
static func cross_fin(parent: Node3D, pos: Vector3, h: float, m: Material) -> void:
	var t := h * 0.12
	var pts := PackedVector2Array([Vector2(-t, 0), Vector2(t, 0), Vector2(t, h * 0.62), Vector2(h * 0.34, h * 0.62), Vector2(h * 0.34, h * 0.62 + 2 * t),
		Vector2(t, h * 0.62 + 2 * t), Vector2(t, h), Vector2(-t, h), Vector2(-t, h * 0.62 + 2 * t), Vector2(-h * 0.34, h * 0.62 + 2 * t),
		Vector2(-h * 0.34, h * 0.62), Vector2(-t, h * 0.62)])
	extrude(parent, pts, t * 1.6, pos, m)

## Media luna con la abertura hacia arriba-derecha, radio r.
static func crescent_fin(parent: Node3D, pos: Vector3, r: float, m: Material) -> void:
	var pts := PackedVector2Array()
	var n := 12
	for i in n + 1:
		var a := deg_to_rad(-60.0 + 300.0 * float(i) / float(n))
		pts.append(Vector2(r * cos(a), r * sin(a) + r))
	for i in n + 1:
		var a2 := deg_to_rad(240.0 - 300.0 * float(i) / float(n))
		pts.append(Vector2(r * 0.18 + r * 0.78 * cos(a2), r * 0.10 + r * 0.78 * sin(a2) + r))
	extrude(parent, pts, r * 0.30, pos, m)

## Flor de lis sencilla (tres pétalos y banda).
static func fleur_fin(parent: Node3D, pos: Vector3, h: float, m: Material) -> void:
	M.ball(parent, h * 0.16, pos + Vector3(0, h * 0.62, 0), m, Vector3(0.7, 1.9, 0.7))
	for s in [-1, 1]:
		var p := M.ball(parent, h * 0.13, pos + Vector3(s * h * 0.17, h * 0.46, 0), m, Vector3(0.6, 1.5, 0.6))
		p.rotation_degrees.z = -s * 28.0
	M.box(parent, Vector3(h * 0.46, h * 0.07, h * 0.07), pos + Vector3(0, h * 0.28, 0), m)
	M.box(parent, Vector3(h * 0.07, h * 0.30, h * 0.07), pos + Vector3(0, h * 0.14, 0), m)

## Escudo redondo colgado en una pared (cara +z o +x): disco con cubo central; `team` pinta el campo con el color del jugador.
static func shield(parent: Node3D, pos: Vector3, r: float, face_x: bool, rim: Material, field: Material) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = 90.0 if face_x else 0.0
	parent.add_child(holder)
	var d := M.cyl(holder, r, r, 0.04, Vector3.ZERO, rim, 14)
	d.rotation_degrees.x = 90.0
	var f := M.cyl(holder, r * 0.82, r * 0.82, 0.05, Vector3(0, 0, 0.004), field, 14)
	f.rotation_degrees.x = 90.0
	var b := M.ball(holder, r * 0.26, Vector3(0, 0, 0.03), rim, Vector3(1.0, 1.0, 0.5))
	b.name = "boss"
