class_name IsoModels
extends RefCounted
## Modelos 3D procedurales para pre-renderizar sprites isométricos (cajas, cilindros, esferas con grumos y
## texturas generadas por código: piedra, yeso, madera, tejas, hojas). 1 unidad de mundo = 1 casilla.
## El origen (0,0,0) es el centro de la huella del objeto, a nivel del suelo; +x y +z son los dos ejes de la rejilla.

# ------------------------------------------------------------------ texturas (128x128, sin costura)

static func _noise_img(seed_v: int, freq: float) -> Image:
	var nz := FastNoiseLite.new()
	nz.seed = seed_v
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz.fractal_octaves = 3
	nz.frequency = freq
	return nz.get_seamless_image(128, 128, false, false, 0.1, false)

static func _mul(c: Color, k: float) -> Color:
	return Color(clampf(c.r * k, 0.0, 1.0), clampf(c.g * k, 0.0, 1.0), clampf(c.b * k, 0.0, 1.0), 1.0)

static func _to_tex(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Sillares: hileras de bloques con juntas oscuras y biselado.
static func tex_stone(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var nzi := _noise_img(seed_v + 7, 0.045)
	var fine := _noise_img(seed_v + 9, 0.20)
	img.fill(_mul(base, 0.40))
	var row_h := 16
	for r in 8:
		var y0 := r * row_h
		var count := rng.randi_range(3, 4)
		var cuts: Array[int] = []
		var off := rng.randi_range(0, 40)
		for k in count:
			cuts.append(off + int(float(k) * float(n) / float(count)) + rng.randi_range(-5, 5))
		for k in count:
			var xa: int = cuts[k]
			var xb: int = cuts[(k + 1) % count] + (n if k == count - 1 else 0)
			var tone := rng.randf_range(0.84, 1.12)
			var warm := rng.randf_range(-0.04, 0.04)
			for yy in range(y0 + 1, y0 + row_h - 1):
				for xx in range(xa + 1, xb - 1):
					var px := posmod(xx, n)
					var py := posmod(yy, n)
					var v := 1.0 + (nzi.get_pixel(px, py).r - 0.5) * 0.30 + (fine.get_pixel(px, py).r - 0.5) * 0.16
					var bev := 1.0
					if yy == y0 + 1 or xx == xa + 1:
						bev = 1.14
					elif yy >= y0 + row_h - 3 or xx >= xb - 3:
						bev = 0.80
					var c := _mul(base, tone * v * bev)
					img.set_pixel(px, py, Color(c.r + warm, c.g, c.b - warm, 1.0))
	return _to_tex(img)

static func tex_plaster(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var a := _noise_img(seed_v, 0.03)
	var b := _noise_img(seed_v + 3, 0.16)
	for y in n:
		for x in n:
			var v := 0.93 + (a.get_pixel(x, y).r - 0.5) * 0.22 + (b.get_pixel(x, y).r - 0.5) * 0.10
			img.set_pixel(x, y, _mul(base, v))
	return _to_tex(img)

## Tablas verticales con veta.
static func tex_wood(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var g := _noise_img(seed_v + 5, 0.07)
	var plank := 16
	for p in n / plank:
		var tone := rng.randf_range(0.82, 1.14)
		for y in n:
			for x in range(p * plank, p * plank + plank):
				var grain := 0.5 + 0.5 * sin(float(x) * 0.9 + g.get_pixel(x % n, y).r * 9.0)
				var v := tone * (0.88 + 0.14 * grain)
				if x == p * plank or x == p * plank + plank - 1:
					v *= 0.55
				img.set_pixel(x, y, _mul(base, v))
	return _to_tex(img)

## Tejas: hileras desfasadas, sombra bajo cada hilera.
static func tex_roof(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var f := _noise_img(seed_v + 11, 0.12)
	var row_h := 16
	var tw := 16
	for r in 8:
		for t in n / tw:
			var tone := rng.randf_range(0.80, 1.16)
			var x0 := t * tw + (tw / 2 if r % 2 == 1 else 0)
			for yy in row_h:
				var y := r * row_h + yy
				var shade := 1.12 - float(yy) / float(row_h) * 0.30
				if yy >= row_h - 3:
					shade *= 0.62
				for xx in tw:
					var px := posmod(x0 + xx, n)
					var v := tone * shade * (0.94 + (f.get_pixel(px, y).r - 0.5) * 0.20)
					if xx == 0:
						v *= 0.62
					img.set_pixel(px, y, _mul(base, v))
	return _to_tex(img)

static func tex_leaf(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var a := _noise_img(seed_v, 0.05)
	var b := _noise_img(seed_v + 4, 0.22)
	for y in n:
		for x in n:
			var v := 0.86 + (a.get_pixel(x, y).r - 0.5) * 0.30 + (b.get_pixel(x, y).r - 0.5) * 0.50
			img.set_pixel(x, y, _mul(base, v))
	return _to_tex(img)

static func tex_bark(seed_v: int, base: Color) -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var a := _noise_img(seed_v, 0.06)
	for y in n:
		for x in n:
			var v := 0.80 + 0.30 * (0.5 + 0.5 * sin(float(x) * 0.55 + a.get_pixel(x, y).r * 6.0))
			img.set_pixel(x, y, _mul(base, v))
	return _to_tex(img)

# ------------------------------------------------------------------ materiales y mallas

## Material con la textura proyectada en triplanar (misma densidad de píxeles en cualquier cara).
static func tmat(tex: Texture2D, per_unit: float, tint: Color = Color.WHITE, rough: float = 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(per_unit, per_unit, per_unit)
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func fmat(col: Color, rough: float = 0.85, spec: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic_specular = spec
	return m

static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi

static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _add(parent, bm, pos, m)

static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, seg: int = 18) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	return _add(parent, cm, pos, m)

static func ball(parent: Node3D, r: float, pos: Vector3, m: Material, sc: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 10
	var mi := _add(parent, sm, pos, m)
	mi.scale = sc
	return mi

## Prisma triangular (techo a dos aguas): base `w` en x, altura `h`, largo `d` en z.
static func prism(parent: Node3D, w: float, h: float, d: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var pm := PrismMesh.new()
	pm.size = Vector3(w, h, d)
	return _add(parent, pm, pos, m)

## Esfera con grumos (copa de árbol, roca): vértices desplazados por ruido y normales suaves soldadas por posición.
static func lump_mesh(r: float, seed_v: int, amp: float, squash: float = 1.0) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 9
	var src := ArrayMesh.new()
	src.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sm.get_mesh_arrays())
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(src, 0)
	var nz := FastNoiseLite.new()
	nz.seed = seed_v
	nz.frequency = 1.1
	var k := 2.2 / maxf(r, 0.01)
	for i in mdt.get_vertex_count():
		var v := mdt.get_vertex(i)
		var d := v.normalized()
		var nv := nz.get_noise_3d(v.x * k, v.y * k, v.z * k) + 0.5 * nz.get_noise_3d(v.x * k * 2.3 + 9.0, v.y * k * 2.3, v.z * k * 2.3)
		var p := v + d * nv * amp * r
		p.y *= squash
		mdt.set_vertex(i, p)
	var acc: Dictionary = {}
	for f in mdt.get_face_count():
		var fn := mdt.get_face_normal(f)
		for c in 3:
			var key := Vector3i((mdt.get_vertex(mdt.get_face_vertex(f, c)) * 1000.0).round())
			acc[key] = (acc[key] as Vector3 if acc.has(key) else Vector3.ZERO) + fn
	for i in mdt.get_vertex_count():
		var key2 := Vector3i((mdt.get_vertex(i) * 1000.0).round())
		mdt.set_vertex_normal(i, (acc[key2] as Vector3).normalized())
	var out := ArrayMesh.new()
	mdt.commit_to_surface(out)
	return out

static func lump(parent: Node3D, r: float, pos: Vector3, m: Material, seed_v: int, amp: float = 0.22, squash: float = 1.0) -> MeshInstance3D:
	return _add(parent, lump_mesh(r, seed_v, amp, squash), pos, m)

# ------------------------------------------------------------------ edificios

static func _flag(parent: Node3D, pos: Vector3, team: Color, h: float = 0.7) -> void:
	var pole := fmat(Color(0.30, 0.20, 0.10))
	cyl(parent, 0.016, 0.016, h, pos + Vector3(0, h * 0.5, 0), pole, 6)
	var cloth := fmat(team, 0.95, 0.1)
	box(parent, Vector3(0.26, 0.16, 0.012), pos + Vector3(0.14, h - 0.10, 0), cloth)
	box(parent, Vector3(0.10, 0.06, 0.014), pos + Vector3(0.20, h - 0.10, 0), fmat(Color(1, 1, 1), 0.9, 0.1))

static func _window(parent: Node3D, pos: Vector3, size: Vector3, wood: Material) -> void:
	box(parent, size, pos, fmat(Color(0.10, 0.14, 0.22), 0.3, 0.8))
	var fr := 0.025
	box(parent, Vector3(size.x + 0.06, fr, size.z + 0.015) if size.z < size.x else Vector3(size.x + 0.015, fr, size.z + 0.06), pos + Vector3(0, size.y * 0.5 + fr * 0.5, 0), wood)

## Casa 2x2: base de piedra, paredes de yeso con vigas, tejado de tejas a dos aguas (cumbrera en x), chimenea, puerta y ventanas.
static func casa(team: Color) -> Node3D:
	var root := Node3D.new()
	var stone := tmat(tex_stone(11, Color(0.64, 0.60, 0.54)), 1.1)
	var plaster := tmat(tex_plaster(12, Color(0.93, 0.87, 0.72)), 1.0)
	var wood := tmat(tex_wood(13, Color(0.34, 0.22, 0.12)), 1.4)
	var roof := tmat(tex_roof(14, Color(0.70, 0.29, 0.18)), 1.5)
	box(root, Vector3(1.62, 0.26, 1.50), Vector3(0, 0.13, 0), stone)
	box(root, Vector3(1.52, 0.56, 1.40), Vector3(0, 0.26 + 0.28, 0), plaster)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(root, Vector3(0.09, 0.58, 0.09), Vector3(sx * 0.77, 0.55, sz * 0.72), wood)
	box(root, Vector3(1.60, 0.07, 0.07), Vector3(0, 0.80, 0.72), wood)
	box(root, Vector3(0.07, 0.07, 1.48), Vector3(0.77, 0.80, 0), wood)
	box(root, Vector3(1.60, 0.07, 0.07), Vector3(0, 0.27, 0.72), wood)
	box(root, Vector3(0.07, 0.07, 1.48), Vector3(0.77, 0.27, 0), wood)
	# tejado: prisma con la cumbrera a lo largo de x (se gira 90 grados)
	var rp := prism(root, 1.78, 0.62, 1.86, Vector3(0, 0.82 + 0.31, 0), roof)
	rp.rotation_degrees.y = 90.0
	box(root, Vector3(1.88, 0.05, 0.05), Vector3(0, 1.44, 0), tmat(tex_roof(15, Color(0.55, 0.22, 0.14)), 1.5))
	# chimenea
	box(root, Vector3(0.20, 0.55, 0.20), Vector3(-0.42, 1.18, -0.18), stone)
	box(root, Vector3(0.26, 0.05, 0.26), Vector3(-0.42, 1.47, -0.18), stone)
	# puerta (cara +z) y ventana (cara +x)
	box(root, Vector3(0.32, 0.46, 0.05), Vector3(0.10, 0.26 + 0.23, 0.72), tmat(tex_wood(16, Color(0.28, 0.17, 0.09)), 2.0))
	box(root, Vector3(0.40, 0.05, 0.10), Vector3(0.10, 0.28, 0.77), stone)
	_window(root, Vector3(-0.45, 0.62, 0.71), Vector3(0.24, 0.22, 0.03), wood)
	_window(root, Vector3(0.76, 0.62, 0.15), Vector3(0.03, 0.22, 0.24), wood)
	_window(root, Vector3(0.76, 0.62, -0.40), Vector3(0.03, 0.22, 0.24), wood)
	_flag(root, Vector3(-0.62, 0.0, 0.92), team, 0.95)
	return root

## Centro urbano 3x3: zócalo de piedra, planta baja de sillería, piso de entramado, tejado grande y campanario.
static func centro(team: Color) -> Node3D:
	var root := Node3D.new()
	var stone := tmat(tex_stone(21, Color(0.66, 0.62, 0.56)), 1.1)
	var stone_d := tmat(tex_stone(22, Color(0.52, 0.49, 0.45)), 1.1)
	var plaster := tmat(tex_plaster(23, Color(0.93, 0.86, 0.70)), 1.0)
	var wood := tmat(tex_wood(24, Color(0.32, 0.21, 0.11)), 1.4)
	var roof := tmat(tex_roof(25, Color(0.66, 0.26, 0.17)), 1.5)
	var roof_d := tmat(tex_roof(26, Color(0.52, 0.21, 0.14)), 1.5)
	box(root, Vector3(2.62, 0.20, 2.50), Vector3(0, 0.10, 0), stone_d)
	box(root, Vector3(2.42, 0.78, 2.28), Vector3(0, 0.20 + 0.39, 0), stone)
	box(root, Vector3(2.46, 0.06, 2.32), Vector3(0, 0.99, 0), stone_d)
	box(root, Vector3(2.20, 0.62, 2.02), Vector3(0, 1.02 + 0.31, 0), plaster)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(root, Vector3(0.11, 0.64, 0.11), Vector3(sx * 1.10, 1.34, sz * 1.0), wood)
	for k in [-0.55, 0.0, 0.55]:
		box(root, Vector3(0.07, 0.64, 0.07), Vector3(k, 1.34, 1.03), wood)
		box(root, Vector3(0.07, 0.64, 0.07), Vector3(1.13, 1.34, k), wood)
	box(root, Vector3(2.26, 0.08, 0.08), Vector3(0, 1.62, 1.03), wood)
	box(root, Vector3(0.08, 0.08, 2.08), Vector3(1.13, 1.62, 0), wood)
	box(root, Vector3(2.26, 0.08, 0.08), Vector3(0, 1.06, 1.03), wood)
	box(root, Vector3(0.08, 0.08, 2.08), Vector3(1.13, 1.06, 0), wood)
	# tejado grande, cumbrera a lo largo de x
	var rp := prism(root, 2.36, 0.88, 2.56, Vector3(0, 1.66 + 0.44, 0), roof)
	rp.rotation_degrees.y = 90.0
	box(root, Vector3(2.64, 0.07, 0.07), Vector3(0, 2.52, 0), roof_d)
	# portón con arco (cara +z) y ventanas
	box(root, Vector3(0.62, 0.62, 0.07), Vector3(0.0, 0.20 + 0.31, 1.16), tmat(tex_wood(27, Color(0.27, 0.17, 0.09)), 1.8))
	var arch := cyl(root, 0.31, 0.31, 0.07, Vector3(0.0, 0.20 + 0.62, 1.16), tmat(tex_wood(28, Color(0.27, 0.17, 0.09)), 1.8), 18)
	arch.rotation_degrees.x = 90.0
	box(root, Vector3(0.84, 0.09, 0.12), Vector3(0.0, 0.24, 1.2), stone_d)
	for wx in [-0.80, 0.80]:
		_window(root, Vector3(wx, 0.62, 1.15), Vector3(0.28, 0.30, 0.03), wood)
		_window(root, Vector3(wx, 1.34, 1.04), Vector3(0.26, 0.26, 0.03), wood)
	for wz in [-0.6, 0.0, 0.6]:
		_window(root, Vector3(1.22, 0.62, wz), Vector3(0.03, 0.28, 0.24), wood)
	# campanario en la esquina trasera derecha
	box(root, Vector3(0.74, 1.7, 0.74), Vector3(0.78, 0.20 + 0.85, -0.78), stone)
	box(root, Vector3(0.84, 0.07, 0.84), Vector3(0.78, 1.93, -0.78), stone_d)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(root, Vector3(0.10, 0.46, 0.10), Vector3(0.78 + sx * 0.26, 2.19, -0.78 + sz * 0.26), stone)
	box(root, Vector3(0.20, 0.20, 0.20), Vector3(0.78, 2.12, -0.78), fmat(Color(0.74, 0.58, 0.20), 0.35, 0.9))
	var pyr := cyl(root, 0.0, 0.58, 0.78, Vector3(0.78, 2.81, -0.78), roof_d, 4)
	pyr.rotation_degrees.y = 45.0
	_window(root, Vector3(1.16, 1.25, -0.78), Vector3(0.03, 0.34, 0.12), wood)
	_window(root, Vector3(0.78, 1.25, -0.39), Vector3(0.12, 0.34, 0.03), wood)
	_flag(root, Vector3(0.78, 3.15, -0.78), team, 0.5)
	_flag(root, Vector3(-1.18, 0.0, 1.30), team, 1.2)
	return root

## Torre 2x2: fuste redondo de sillería, matacán con almenas, saetas y techo cónico.
static func torre(team: Color) -> Node3D:
	var root := Node3D.new()
	var stone := tmat(tex_stone(31, Color(0.62, 0.59, 0.54)), 1.2)
	var stone_d := tmat(tex_stone(32, Color(0.50, 0.47, 0.43)), 1.2)
	var roof := tmat(tex_roof(33, Color(0.40, 0.30, 0.24)), 1.6)
	cyl(root, 0.66, 0.74, 0.26, Vector3(0, 0.13, 0), stone_d, 20)
	cyl(root, 0.54, 0.62, 1.80, Vector3(0, 0.26 + 0.90, 0), stone, 20)
	cyl(root, 0.70, 0.62, 0.20, Vector3(0, 2.16, 0), stone_d, 20)
	cyl(root, 0.70, 0.70, 0.30, Vector3(0, 2.41, 0), stone, 20)
	for k in 10:
		var a := TAU * float(k) / 10.0
		box(root, Vector3(0.16, 0.18, 0.16), Vector3(cos(a) * 0.66, 2.66, sin(a) * 0.66), stone)
	var cone := cyl(root, 0.0, 0.62, 0.92, Vector3(0, 2.57 + 0.46, 0), roof, 20)
	var slit := fmat(Color(0.05, 0.05, 0.07), 0.9, 0.1)
	for h in [0.95, 1.70]:
		for a in [PI * 0.25, PI * 0.75]:
			var piv := Node3D.new()
			piv.rotation.y = -a
			root.add_child(piv)
			var rr := lerpf(0.62, 0.54, (h - 0.26) / 1.8)
			box(piv, Vector3(0.05, 0.26, 0.06), Vector3(rr, h, 0), slit)
	box(root, Vector3(0.28, 0.46, 0.06), Vector3(0, 0.26 + 0.23, 0.66), tmat(tex_wood(34, Color(0.28, 0.17, 0.09)), 2.0))
	_flag(root, Vector3(0, 3.0, 0), team, 0.56)
	return root

# ------------------------------------------------------------------ árboles y rocas

static func roble(variant: int) -> Node3D:
	var root := Node3D.new()
	# 0-3 verdes; 4-6 otoño (naranja, ocre, dorado)
	var bases := [Color(0.24, 0.46, 0.16), Color(0.30, 0.50, 0.17), Color(0.20, 0.42, 0.18), Color(0.34, 0.46, 0.15),
		Color(0.78, 0.42, 0.10), Color(0.66, 0.34, 0.10), Color(0.80, 0.64, 0.16)]
	var base: Color = bases[variant % bases.size()]
	var leaf_d := tmat(tex_leaf(40 + variant, base), 1.6, Color.WHITE, 0.95)
	var leaf_l := tmat(tex_leaf(44 + variant, _mul(base, 1.14)), 1.6, Color.WHITE, 0.95)
	var bark := tmat(tex_bark(50 + variant, Color(0.40, 0.28, 0.16)), 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + variant
	var s := rng.randf_range(0.92, 1.12)
	cyl(root, 0.055, 0.115, 0.70, Vector3(0, 0.35, 0), bark, 10)
	# lóbulos: espiral dorada sobre una cúpula, los de arriba y los del lado de la luz (-x) en el tono claro
	var n := 10
	for k in n:
		var f := (float(k) + 0.5) / float(n)
		var ang := float(k) * 2.39996
		var rr := 0.10 + 0.34 * sqrt(f)
		var r := rng.randf_range(0.20, 0.29) * (1.12 - 0.35 * f)
		var y := 1.12 - 0.34 * f + rng.randf_range(-0.05, 0.05) - rr * 0.30
		var pos := Vector3(cos(ang) * rr, y, sin(ang) * rr) * s
		var light := (y > 0.98) or (pos.x < -0.05)
		lump(root, r * s, pos, leaf_l if light else leaf_d, 900 + variant * 13 + k, 0.34)
		if k < 4:   # ramas que suben del tronco hacia los lóbulos bajos
			var br := Node3D.new()
			root.add_child(br)
			var dir := Vector3(pos.x, pos.y - 0.55, pos.z)
			br.position = Vector3(0, 0.55, 0)
			var bm := cyl(br, 0.022, 0.034, dir.length(), dir * 0.5, bark, 6)
			br.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
			bm.position = Vector3(0, dir.length() * 0.5, 0)
	return root

static func pino(variant: int) -> Node3D:
	var root := Node3D.new()
	var base := Color(0.12, 0.34, 0.22) if variant % 2 == 0 else Color(0.14, 0.38, 0.20)
	var leaf := tmat(tex_leaf(60 + variant, base), 1.8, Color.WHITE, 0.95)
	var bark := tmat(tex_bark(70 + variant, Color(0.34, 0.23, 0.13)), 3.0)
	cyl(root, 0.05, 0.09, 0.50, Vector3(0, 0.25, 0), bark, 10)
	var tiers := 4 + variant % 2
	for i in tiers:
		var t := float(i) / float(tiers)
		var r := lerpf(0.50, 0.17, t)
		var h := 0.62
		var y := 0.34 + t * 1.10
		var c := cyl(root, 0.0, r, h, Vector3(0, y + h * 0.5, 0), leaf, 12)
		c.rotation_degrees.y = float(i) * 31.0
	return root

static func roca(variant: int, gold: bool) -> Node3D:
	var root := Node3D.new()
	var stone := tmat(tex_stone(80 + variant, Color(0.50, 0.50, 0.52) if not gold else Color(0.42, 0.41, 0.43)), 1.8)
	var specs := [Vector4(0, 0.30, 0, 0.46), Vector4(-0.40, 0.20, 0.22, 0.30), Vector4(0.42, 0.22, 0.12, 0.32), Vector4(-0.10, 0.20, -0.40, 0.30), Vector4(0.12, 0.50, -0.10, 0.28)]
	var k := 0
	for l: Vector4 in specs:
		lump(root, l.w, Vector3(l.x, l.y, l.z), stone, 400 + variant * 7 + k, 0.35, 0.80)
		k += 1
	if gold:
		var g := fmat(Color(0.98, 0.78, 0.14), 0.22, 0.9)
		for p: Vector4 in [Vector4(-0.10, 0.55, 0.30, 0.13), Vector4(0.24, 0.62, 0.12, 0.15), Vector4(-0.34, 0.44, 0.12, 0.11), Vector4(0.40, 0.40, 0.34, 0.10), Vector4(0.05, 0.78, -0.10, 0.12)]:
			ball(root, p.w, Vector3(p.x, p.y, p.z), g, Vector3(1, 0.85, 1))
	return root

# ------------------------------------------------------------------ personas

## Persona articulada (mira hacia +z). kind: "aldeano" o "espadachin". phase en [0,1): ciclo de marcha; -1 = parado.
static func persona(kind: String, team: Color, phase: float) -> Node3D:
	var root := Node3D.new()
	var skin := fmat(Color(0.88, 0.69, 0.53), 0.8, 0.3)
	# aldeano: ropa natural con el color del equipo sólo en cinturón y pañuelo; espadachín: sobrevesta del equipo y mangas de malla
	var cloth := fmat(team, 0.9, 0.2) if kind == "espadachin" else fmat(Color(0.70, 0.56, 0.37), 0.95, 0.15)
	var cloth_d := fmat(team.darkened(0.30), 0.9, 0.2) if kind == "espadachin" else fmat(Color(0.50, 0.38, 0.24), 0.95, 0.15)
	var sleeve := fmat(Color(0.40, 0.41, 0.46), 0.5, 0.5) if kind == "espadachin" else cloth
	var team_m := fmat(team, 0.85, 0.2)
	var trousers := fmat(Color(0.30, 0.25, 0.20) if kind == "aldeano" else Color(0.20, 0.20, 0.24), 0.9, 0.2)
	var leather := fmat(Color(0.26, 0.17, 0.10), 0.8, 0.3)
	var steel := fmat(Color(0.50, 0.52, 0.58), 0.42, 0.6)
	var swing := 0.0 if phase < 0.0 else sin(phase * TAU)
	var bob := 0.0 if phase < 0.0 else absf(sin(phase * TAU)) * 0.025
	var body := Node3D.new()
	body.position = Vector3(0, bob, 0)
	body.scale = Vector3(1.12, 1.12, 1.12)
	root.add_child(body)
	# piernas con botas
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.065, 0.46, 0)
		hip.rotation_degrees.x = swing * 32.0 * float(side)
		body.add_child(hip)
		var leg := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.058
		cm.height = 0.46
		leg.mesh = cm
		leg.material_override = trousers
		leg.position = Vector3(0, -0.23, 0)
		hip.add_child(leg)
		var boot := box(hip, Vector3(0.10, 0.08, 0.17), Vector3(0, -0.45, 0.03), leather)
		boot.name = "bota"
	# túnica larga (faldón) y torso
	cyl(body, 0.150, 0.185, 0.20, Vector3(0, 0.40, 0), cloth_d, 16)
	cyl(body, 0.118, 0.150, 0.34, Vector3(0, 0.62, 0), cloth, 16)
	cyl(body, 0.156, 0.156, 0.045, Vector3(0, 0.47, 0), team_m if kind == "aldeano" else leather, 16)
	if kind == "espadachin":
		ball(body, 0.135, Vector3(0, 0.67, 0.02), steel, Vector3(1.0, 0.95, 0.70))
		for side in [-1, 1]:
			ball(body, 0.068, Vector3(side * 0.15, 0.78, 0), steel)
	else:
		cyl(body, 0.105, 0.125, 0.055, Vector3(0, 0.80, 0), team_m, 14)
	# cabeza
	ball(body, 0.088, Vector3(0, 0.88, 0.0), skin)
	if kind == "espadachin":
		ball(body, 0.102, Vector3(0, 0.915, -0.004), steel, Vector3(1, 0.80, 1))
		box(body, Vector3(0.022, 0.07, 0.02), Vector3(0, 0.87, 0.09), steel)
		box(body, Vector3(0.025, 0.07, 0.06), Vector3(0, 1.01, -0.01), fmat(Color(0.75, 0.15, 0.12), 0.8, 0.2))
	else:
		cyl(body, 0.15, 0.15, 0.012, Vector3(0, 0.93, 0), fmat(Color(0.80, 0.68, 0.34), 0.95, 0.1), 16)
		cyl(body, 0.065, 0.085, 0.06, Vector3(0, 0.96, 0), fmat(Color(0.78, 0.66, 0.32), 0.95, 0.1), 14)
	# brazos
	for side in [-1, 1]:
		var sh := Node3D.new()
		sh.position = Vector3(side * 0.165, 0.76, 0)
		sh.rotation_degrees.x = -swing * 30.0 * float(side)
		body.add_child(sh)
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 0.048
		am.height = 0.32
		arm.mesh = am
		arm.material_override = sleeve
		arm.position = Vector3(0, -0.15, 0)
		sh.add_child(arm)
		ball(sh, 0.045, Vector3(0, -0.32, 0), skin)
		if kind == "espadachin" and side == 1:
			box(sh, Vector3(0.035, 0.05, 0.42), Vector3(0, -0.34, 0.21), steel)
			box(sh, Vector3(0.15, 0.03, 0.03), Vector3(0, -0.34, 0.03), leather)
		if kind == "espadachin" and side == -1:
			var shield := cyl(sh, 0.16, 0.16, 0.04, Vector3(-0.07, -0.22, 0.05), fmat(team, 0.7, 0.3), 22)
			shield.rotation_degrees.z = 90.0
			ball(sh, 0.04, Vector3(-0.10, -0.22, 0.05), steel)
		if kind == "aldeano" and side == 1:
			box(sh, Vector3(0.025, 0.28, 0.025), Vector3(0.02, -0.40, 0.08), fmat(Color(0.35, 0.24, 0.12), 0.9, 0.2))
	return root

# ------------------------------------------------------------------ fortificaciones

static func _stone_set(seed_v: int) -> Dictionary:
	return {
		"wall": tmat(tex_stone(seed_v, Color(0.50, 0.50, 0.53)), 1.3),
		"dark": tmat(tex_stone(seed_v + 1, Color(0.36, 0.36, 0.39)), 1.3),
		"light": tmat(tex_stone(seed_v + 2, Color(0.56, 0.55, 0.54)), 1.3),
		"trim": fmat(Color(0.88, 0.52, 0.16), 0.65, 0.35),
		"ivy": tmat(tex_leaf(seed_v + 3, Color(0.22, 0.46, 0.16)), 2.0, Color.WHITE, 0.95),
		"slit": fmat(Color(0.04, 0.04, 0.06), 0.9, 0.1),
		"floor": tmat(tex_stone(seed_v + 4, Color(0.30, 0.30, 0.32)), 1.6),
		"wood": tmat(tex_wood(seed_v + 5, Color(0.36, 0.23, 0.12)), 1.6),
	}

## Almenas en el borde de un rectángulo (hw, hd = medias dimensiones), a altura y.
static func _rim(parent: Node3D, hw: float, hd: float, y: float, m: Material, step: float = 0.30) -> void:
	var nx := maxi(2, 2 * int(round(hw / step)))
	var mx := hw * 2.0 / float(nx) * 0.62
	for i in nx + 1:
		if i % 2 == 0:
			var x := -hw + hw * 2.0 * float(i) / float(nx)
			for sz in [-1, 1]:
				box(parent, Vector3(mx, 0.17, 0.13), Vector3(x, y + 0.085, sz * hd), m)
	var nz := maxi(2, 2 * int(round(hd / step)))
	var mz := hd * 2.0 / float(nz) * 0.62
	for j in range(2, nz - 1, 2):
		var z := -hd + hd * 2.0 * float(j) / float(nz)
		for sx in [-1, 1]:
			box(parent, Vector3(0.13, 0.17, mz), Vector3(sx * hw, y + 0.085, z), m)

## Almenas en círculo.
static func _ring_rim(parent: Node3D, r: float, y: float, n: int, m: Material) -> void:
	for k in n:
		var a := TAU * (float(k) + 0.5) / float(n)
		var mi := box(parent, Vector3(0.14, 0.17, TAU * r / float(n) * 0.58), Vector3(cos(a) * r, y + 0.085, sin(a) * r), m)
		mi.rotation.y = -a

## Mata de hiedra pegada a una pared (cara 0 = +z, 1 = +x).
static func _ivy(parent: Node3D, pos: Vector3, r: float, face: int, S: Dictionary, seed_v: int) -> void:
	var mi := lump(parent, r, pos, S.ivy, seed_v, 0.55)
	mi.scale = Vector3(1.0, 1.35, 0.17) if face == 0 else Vector3(0.17, 1.35, 1.0)

static func _slits(parent: Node3D, c: Vector3, hw: float, ys: Array, S: Dictionary) -> void:
	for y in ys:
		box(parent, Vector3(0.06, 0.28, 0.05), c + Vector3(0, y, hw + 0.005), S.slit)
		box(parent, Vector3(0.05, 0.28, 0.06), c + Vector3(hw + 0.005, y, 0), S.slit)

## Torre cuadrada de sillería: zócalo, fuste, voladizo con matacanes, adarve con almenas.
static func _sq_tower(parent: Node3D, c: Vector3, w: float, h: float, S: Dictionary) -> float:
	var hw := w * 0.5
	box(parent, Vector3(w + 0.12, 0.20, w + 0.12), c + Vector3(0, 0.10, 0), S.dark)
	box(parent, Vector3(w + 0.16, 0.05, w + 0.16), c + Vector3(0, 0.225, 0), S.trim)
	var body_h := h - 0.20 - 0.44
	box(parent, Vector3(w, body_h, w), c + Vector3(0, 0.20 + body_h * 0.5, 0), S.wall)
	var yb := 0.20 + body_h
	box(parent, Vector3(w + 0.10, 0.10, w + 0.10), c + Vector3(0, yb + 0.05, 0), S.dark)
	box(parent, Vector3(w + 0.24, 0.30, w + 0.24), c + Vector3(0, yb + 0.25, 0), S.wall)
	for k in [-0.28, 0.0, 0.28]:   # matacanes
		box(parent, Vector3(0.12, 0.10, 0.07), c + Vector3(k * w * 1.4, yb + 0.05, hw + 0.075), S.light)
		box(parent, Vector3(0.07, 0.10, 0.12), c + Vector3(hw + 0.075, yb + 0.05, k * w * 1.4), S.light)
	var ytop := yb + 0.40
	box(parent, Vector3(w + 0.28, 0.05, w + 0.28), c + Vector3(0, ytop + 0.025, 0), S.trim)
	box(parent, Vector3(w + 0.10, 0.03, w + 0.10), c + Vector3(0, ytop + 0.05, 0), S.floor)
	var crown := Node3D.new()
	crown.position = c
	parent.add_child(crown)
	_rim(crown, (w + 0.24) * 0.5 - 0.065, (w + 0.24) * 0.5 - 0.065, ytop + 0.05, S.light)
	_slits(parent, c, hw, [0.9, 1.5], S)
	_ivy(parent, c + Vector3(-hw * 0.50, 0.75, hw + 0.01), w * 0.24, 0, S, 301)
	_ivy(parent, c + Vector3(hw + 0.01, 0.62, hw * 0.35), w * 0.20, 1, S, 302)
	return ytop + 0.05

## Torre cuadrada 2x2 (la torre del juego): fuste de 1.3 de lado, 2.6 de alto.
static func torre_cuadrada(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := _stone_set(210)
	var top := _sq_tower(root, Vector3.ZERO, 1.25, 2.6, S)
	box(root, Vector3(0.34, 0.50, 0.06), Vector3(0.0, 0.20 + 0.25, 0.66), S.wood)
	_flag(root, Vector3(-0.40, top, -0.40), team, 0.75)
	return root

## Atalaya: fuste cuadrado con tejado piramidal de pizarra.
static func atalaya(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := _stone_set(230)
	var w := 1.10
	var hw := w * 0.5
	box(root, Vector3(w + 0.12, 0.20, w + 0.12), Vector3(0, 0.10, 0), S.dark)
	box(root, Vector3(w + 0.16, 0.05, w + 0.16), Vector3(0, 0.225, 0), S.trim)
	box(root, Vector3(w, 1.95, w), Vector3(0, 0.20 + 0.975, 0), S.wall)
	box(root, Vector3(w + 0.20, 0.12, w + 0.20), Vector3(0, 2.21, 0), S.dark)
	box(root, Vector3(w + 0.20, 0.34, w + 0.20), Vector3(0, 2.44, 0), S.wall)
	box(root, Vector3(w + 0.30, 0.06, w + 0.30), Vector3(0, 2.64, 0), S.trim)
	var roof := tmat(tex_roof(231, Color(0.40, 0.36, 0.34)), 1.5)
	var pyr := cyl(root, 0.0, (w + 0.30) * 0.7071 + 0.02, 1.0, Vector3(0, 2.67 + 0.5, 0), roof, 4)
	pyr.rotation_degrees.y = 45.0
	box(root, Vector3(0.20, 0.20, 0.20), Vector3(0, 3.72, 0), S.trim)
	_slits(root, Vector3.ZERO, hw, [0.9, 1.45], S)
	box(root, Vector3(0.20, 0.26, 0.03), Vector3(0.0, 2.44, hw + 0.115), S.slit)
	box(root, Vector3(0.03, 0.26, 0.20), Vector3(hw + 0.115, 2.44, 0.0), S.slit)
	_ivy(root, Vector3(-0.22, 0.60, hw + 0.02), 0.36, 0, S, 311)
	_ivy(root, Vector3(hw + 0.02, 1.1, 0.12), 0.30, 1, S, 312)
	box(root, Vector3(0.34, 0.50, 0.06), Vector3(0.0, 0.20 + 0.25, hw + 0.03), S.wood)
	_flag(root, Vector3(0, 3.82, 0), team, 0.5)
	return root

## Bloque de muralla (sx, sz = grosor y largo; h = altura): coronación con almenas en los bordes largos.
static func _wall_block(parent: Node3D, S: Dictionary, sx: float, h: float, sz: float, pos: Vector3) -> void:
	box(parent, Vector3(sx + 0.04, 0.14, sz + 0.04), pos + Vector3(0, 0.07, 0), S.dark)
	box(parent, Vector3(sx + 0.06, 0.035, sz + 0.06), pos + Vector3(0, 0.155, 0), S.trim)
	box(parent, Vector3(sx, h - 0.17, sz), pos + Vector3(0, 0.17 + (h - 0.17) * 0.5, 0), S.wall)
	box(parent, Vector3(sx + 0.05, 0.05, sz + 0.05), pos + Vector3(0, h + 0.025, 0), S.light)
	var along_x := sx >= sz
	var L := sx if along_x else sz
	var T := sz if along_x else sx
	var n := maxi(2, 2 * int(round(L / 0.30)))
	for i in n + 1:
		if i % 2 == 0:
			var u := -L * 0.5 + L * float(i) / float(n)
			for side in [-1, 1]:
				var off := float(side) * (T * 0.5 - 0.065)
				var size := Vector3(L / float(n) * 0.62, 0.17, 0.13) if along_x else Vector3(0.13, 0.17, L / float(n) * 0.62)
				var p := Vector3(u, h + 0.05 + 0.085, off) if along_x else Vector3(off, h + 0.05 + 0.085, u)
				box(parent, size, pos + p, S.light)

## Tramo de muralla de una casilla. rot90 = a lo largo de z en vez de x.
static func muralla(rot90: bool) -> Node3D:
	var root := Node3D.new()
	var S := _stone_set(250)
	var body := Node3D.new()
	root.add_child(body)
	_wall_block(body, S, 1.0, 1.05, 0.50, Vector3.ZERO)
	body.rotation_degrees.y = 90.0 if rot90 else 0.0
	return root

## Castillo 4x4: cortina con puerta, cuatro torres, torre del homenaje con torreón redondo.
static func castillo(team: Color) -> Node3D:
	var root := Node3D.new()
	var S := _stone_set(110)
	var yard := tmat(tex_plaster(119, Color(0.60, 0.53, 0.38)), 1.2)
	box(root, Vector3(3.5, 0.06, 3.5), Vector3(0, 0.03, 0), yard)
	var wh := 1.30
	_wall_block(root, S, 3.0, wh, 0.50, Vector3(0, 0, -1.55))
	_wall_block(root, S, 0.50, wh, 3.0, Vector3(-1.55, 0, 0))
	_wall_block(root, S, 0.50, wh, 3.0, Vector3(1.55, 0, 0))
	_wall_block(root, S, 1.05, wh, 0.50, Vector3(-0.975, 0, 1.55))
	_wall_block(root, S, 1.05, wh, 0.50, Vector3(0.975, 0, 1.55))
	# puerta: dintel, hoja de madera y fondo oscuro
	box(root, Vector3(0.90, 0.38, 0.52), Vector3(0, wh - 0.19, 1.55), S.wall)
	box(root, Vector3(0.94, 0.05, 0.56), Vector3(0, wh + 0.025, 1.55), S.light)
	box(root, Vector3(0.90, 0.92, 0.30), Vector3(0, 0.46, 1.50), S.slit)
	for sx in [-1, 1]:
		box(root, Vector3(0.05, 0.86, 0.34), Vector3(sx * 0.46, 0.43, 1.55), S.trim)
		var leaf := box(root, Vector3(0.40, 0.84, 0.05), Vector3(sx * 0.30, 0.43, 1.79), S.wood)
		leaf.rotation_degrees.y = float(sx) * -62.0
	# torres de esquina
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_sq_tower(root, Vector3(sx * 1.55, 0, sz * 1.55), 1.05, 2.35, S)
	# torre del homenaje
	var kc := Vector3(0.0, 0, -0.45)
	box(root, Vector3(1.90, 0.20, 1.60), kc + Vector3(0, 0.10, 0), S.dark)
	box(root, Vector3(1.94, 0.04, 1.64), kc + Vector3(0, 0.22, 0), S.trim)
	box(root, Vector3(1.80, 1.70, 1.50), kc + Vector3(0, 0.20 + 0.85, 0), S.wall)
	box(root, Vector3(1.98, 0.16, 1.68), kc + Vector3(0, 1.98, 0), S.dark)
	box(root, Vector3(2.04, 0.05, 1.74), kc + Vector3(0, 2.08, 0), S.trim)
	box(root, Vector3(1.86, 0.03, 1.56), kc + Vector3(0, 2.10, 0), S.floor)
	_rim(root, 0.93, 0.78, 2.10, S.light)
	cyl(root, 0.50, 0.54, 0.90, kc + Vector3(0.28, 2.10 + 0.45, -0.10), S.wall, 24)
	cyl(root, 0.58, 0.58, 0.16, kc + Vector3(0.28, 3.06, -0.10), S.dark, 24)
	cyl(root, 0.52, 0.52, 0.04, kc + Vector3(0.28, 3.16, -0.10), S.floor, 24)
	var ring := Node3D.new()
	ring.position = kc + Vector3(0.28, 3.16, -0.10)
	root.add_child(ring)
	_ring_rim(ring, 0.52, 0.02, 12, S.light)
	for wx in [-0.55, 0.45]:
		_window(root, kc + Vector3(wx, 1.15, 0.77), Vector3(0.24, 0.34, 0.03), S.trim)
		_window(root, kc + Vector3(wx, 1.65, 0.77), Vector3(0.22, 0.26, 0.03), S.trim)
	for wz in [-0.35, 0.40]:
		_window(root, kc + Vector3(0.92, 1.30, wz), Vector3(0.03, 0.34, 0.24), S.trim)
	_ivy(root, kc + Vector3(-0.70, 0.55, 0.77), 0.45, 0, S, 321)
	_flag(root, kc + Vector3(0.28, 3.20, -0.10), team, 0.9)
	_flag(root, Vector3(-1.2, 1.35, 1.55), team, 0.9)
	return root

# ------------------------------------------------------------------ asedio

## Trabuquete (mira a +x): bastidor, dos caballetes en A, brazo con contrapeso y honda.
static func trabuquete(team: Color) -> Node3D:
	var root := Node3D.new()
	var wood := tmat(tex_wood(260, Color(0.64, 0.48, 0.28)), 1.8)
	var wood_d := tmat(tex_wood(261, Color(0.46, 0.33, 0.18)), 1.8)
	var tm_ := fmat(team, 0.75, 0.3)
	var iron := fmat(Color(0.25, 0.25, 0.28), 0.6, 0.5)
	# bastidor bajo
	for z in [-0.34, 0.34]:
		box(root, Vector3(1.60, 0.12, 0.12), Vector3(0.05, 0.08, z), wood_d)
	for x in [-0.55, 0.0, 0.55]:
		box(root, Vector3(0.12, 0.10, 0.80), Vector3(x, 0.17, 0), wood_d)
	# caballetes en A
	var th := atan2(0.50, 1.05)
	var plen := sqrt(0.50 * 0.50 + 1.05 * 1.05)
	for z in [-0.30, 0.30]:
		for sx in [-1, 1]:
			var post := box(root, Vector3(0.10, plen, 0.10), Vector3(sx * 0.25, 0.12 + 0.525, z), wood)
			post.rotation.z = float(sx) * th
		box(root, Vector3(0.62, 0.07, 0.07), Vector3(0, 0.55, z), wood_d)
	# eje y brazo (el pivote queda a 1.2 de altura)
	var pivot := Vector3(0, 1.18, 0)
	box(root, Vector3(0.07, 0.07, 0.80), pivot, iron)
	var arm := Node3D.new()
	arm.position = pivot
	arm.rotation.z = deg_to_rad(-28.0)   # extremo largo (honda) hacia -x y arriba; contrapeso hacia +x y abajo
	root.add_child(arm)
	box(arm, Vector3(0.10, 1.90, 0.12), Vector3(0, 0.0, 0), wood)
	box(arm, Vector3(0.14, 0.14, 0.16), Vector3(0, 0.95, 0), iron)
	# contrapeso en el extremo corto (abajo del brazo)
	box(arm, Vector3(0.34, 0.36, 0.34), Vector3(0, -1.02, 0), wood_d)
	box(arm, Vector3(0.36, 0.06, 0.36), Vector3(0, -0.82, 0), tm_)
	box(arm, Vector3(0.36, 0.06, 0.36), Vector3(0, -1.22, 0), tm_)
	# honda y piedra
	box(arm, Vector3(0.025, 0.40, 0.025), Vector3(0, 1.15, 0), fmat(Color(0.35, 0.28, 0.2), 0.9, 0.1))
	ball(arm, 0.09, Vector3(0, 1.38, 0), tmat(tex_stone(262, Color(0.55, 0.55, 0.58)), 3.0))
	# banderín de equipo en lo alto del caballete
	box(root, Vector3(0.20, 0.10, 0.02), Vector3(0.0, 1.46, 0.30), tm_)
	return root

## Catapulta de ruedas (mira a +x): bastidor, cuatro ruedas, brazo con cazoleta.
static func catapulta(team: Color) -> Node3D:
	var root := Node3D.new()
	var wood := tmat(tex_wood(270, Color(0.64, 0.48, 0.28)), 1.8)
	var wood_d := tmat(tex_wood(271, Color(0.46, 0.33, 0.18)), 1.8)
	var tm_ := fmat(team, 0.75, 0.3)
	var iron := fmat(Color(0.25, 0.25, 0.28), 0.6, 0.5)
	box(root, Vector3(1.10, 0.12, 0.62), Vector3(0, 0.30, 0), wood_d)
	for sx in [-0.38, 0.38]:
		for sz in [-1, 1]:
			var w := cyl(root, 0.19, 0.19, 0.08, Vector3(sx, 0.19, sz * 0.36), wood, 14)
			w.rotation_degrees.x = 90.0
			var hub := cyl(root, 0.05, 0.05, 0.12, Vector3(sx, 0.19, sz * 0.36), iron, 8)
			hub.rotation_degrees.x = 90.0
	for sz in [-1, 1]:
		box(root, Vector3(0.10, 0.62, 0.10), Vector3(-0.10, 0.62, sz * 0.24), wood)
	box(root, Vector3(0.10, 0.10, 0.62), Vector3(-0.10, 0.92, 0), wood_d)
	var arm := Node3D.new()
	arm.position = Vector3(-0.10, 0.92, 0)
	arm.rotation.z = deg_to_rad(-52.0)
	root.add_child(arm)
	box(arm, Vector3(0.09, 1.10, 0.10), Vector3(0, 0.40, 0), wood)
	box(arm, Vector3(0.22, 0.10, 0.22), Vector3(0, 0.98, 0), wood_d)
	ball(arm, 0.10, Vector3(0, 1.06, 0), tmat(tex_stone(272, Color(0.55, 0.55, 0.58)), 3.0))
	box(root, Vector3(0.36, 0.05, 0.30), Vector3(0.28, 0.375, 0), tm_)
	return root
