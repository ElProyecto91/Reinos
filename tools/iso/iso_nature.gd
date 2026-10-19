class_name IsoNature
extends RefCounted
## Vegetación y recursos que faltaban: palmera, árbol seco (acacia), pinos nevados, pino alto, retoño, arbusto de bayas,
## robles de otoño y montañas. Mismas convenciones que IsoModels: 1 unidad = 1 casilla, origen a nivel del suelo.

const M = preload("res://tools/iso/iso_models.gd")

## Roble de otoño (naranja / ocre / dorado): reutiliza el modelo del roble con la paleta de otoño.
static func otono(variant: int) -> Node3D:
	return M.roble(4 + variant % 3)

static func palma(variant: int) -> Node3D:
	var root := Node3D.new()
	var bark := M.tmat(M.tex_bark(120 + variant, Color(0.52, 0.40, 0.24)), 3.0)
	var leaf := M.tmat(M.tex_leaf(124 + variant, Color(0.20, 0.50, 0.16)), 1.6, Color.WHITE, 0.9)
	var leaf_l := M.tmat(M.tex_leaf(128 + variant, Color(0.32, 0.60, 0.20)), 1.6, Color.WHITE, 0.9)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1200 + variant
	# tronco: cadena de tramos que sigue una curva suave (se inclina hacia -x, donde pega la luz)
	var lean := rng.randf_range(0.16, 0.24) * (1.0 if variant == 0 else -0.6)
	var n := 6
	var total_h := 1.35
	var prev := Vector3.ZERO
	for i in n:
		var t1 := float(i + 1) / float(n)
		var nxt := Vector3(-lean * t1 * t1, total_h * t1, 0.05 * sin(t1 * 3.0))
		var d := nxt - prev
		var r0 := lerpf(0.085, 0.048, float(i) / float(n))
		var r1 := lerpf(0.085, 0.048, t1)
		var seg := Node3D.new()
		seg.position = prev
		seg.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
		root.add_child(seg)
		var cm := M.cyl(seg, r1, r0, d.length() * 1.02, Vector3(0, d.length() * 0.5, 0), bark, 8)
		cm.name = "t%d" % i
		prev = nxt
	var top := prev
	# frondas: 10 largas y curvadas hacia abajo (3 tramos cada una), alternando dos verdes
	for k in 10:
		var pivot := Node3D.new()
		pivot.position = top
		pivot.rotation.y = TAU * float(k) / 10.0 + rng.randf_range(-0.10, 0.10)
		root.add_child(pivot)
		var ln := rng.randf_range(0.80, 0.98)
		var ang := rng.randf_range(0.34, 0.50)
		var droop := rng.randf_range(0.34, 0.52)
		var pos := Vector3.ZERO
		for sgi in 3:
			var sl := ln / 3.0
			var fm := M.ball(pivot, sl * 0.62, pos + Vector3(cos(ang) * sl * 0.5, sin(ang) * sl * 0.5, 0.0), leaf_l if (k % 2 == 0) else leaf, Vector3(1.0, 0.17, 0.80 - 0.14 * sgi))
			fm.rotation.z = ang
			pos += Vector3(cos(ang), sin(ang), 0.0) * sl
			ang -= droop
	for k in 4:
		var pivot2 := Node3D.new()
		pivot2.position = top
		pivot2.rotation.y = TAU * float(k) / 4.0 + 0.4
		root.add_child(pivot2)
		var fm2 := M.ball(pivot2, 0.24, Vector3(0.06, 0.24, 0), leaf_l, Vector3(0.9, 0.16, 0.55))
		fm2.rotation.z = 1.15
	# cocos
	var coco := M.fmat(Color(0.34, 0.24, 0.12), 0.8, 0.3)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.3
		M.ball(root, 0.06, top + Vector3(cos(a) * 0.09, -0.08, sin(a) * 0.09), coco)
	return root

## Árbol seco de la sabana (acacia): tronco retorcido y copa plana en sombrilla, hojas pajizas.
static func seco(variant: int) -> Node3D:
	var root := Node3D.new()
	var bark := M.tmat(M.tex_bark(140 + variant, Color(0.40, 0.31, 0.22)), 3.0)
	var leaf := M.tmat(M.tex_leaf(144 + variant, Color(0.60, 0.55, 0.22)), 1.6, Color.WHITE, 0.95)
	var leaf_l := M.tmat(M.tex_leaf(148 + variant, Color(0.72, 0.66, 0.28)), 1.6, Color.WHITE, 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1400 + variant
	M.cyl(root, 0.045, 0.095, 0.62, Vector3(0, 0.31, 0), bark, 8)
	# tres ramas que abren hacia la copa
	var heads: Array[Vector3] = []
	for k in 3:
		var a := TAU * float(k) / 3.0 + rng.randf_range(0.0, 0.8)
		var dir := Vector3(cos(a) * 0.36, 0.42, sin(a) * 0.36)
		var br := Node3D.new()
		br.position = Vector3(0, 0.55, 0)
		root.add_child(br)
		var bm := M.cyl(br, 0.022, 0.04, dir.length(), Vector3.ZERO, bark, 6)
		br.basis = Basis(Quaternion(Vector3.UP, dir.normalized()))
		bm.position = Vector3(0, dir.length() * 0.5, 0)
		heads.append(Vector3(0, 0.55, 0) + dir)
	# copa: discos aplastados
	for h in heads:
		M.lump(root, 0.34, h + Vector3(0, 0.04, 0), leaf_l if h.x < 0.0 else leaf, 1450 + variant, 0.26, 0.38)
	M.lump(root, 0.30, Vector3(0, 1.06, 0), leaf_l, 1460 + variant, 0.26, 0.40)
	return root

## Pino nevado: mismas capas del pino con la parte superior blanca. variant 0 = alto, 1 = achaparrado.
static func nieve(variant: int) -> Node3D:
	var root := Node3D.new()
	var leaf := M.tmat(M.tex_leaf(160 + variant, Color(0.10, 0.30, 0.22)), 1.8, Color.WHITE, 0.95)
	var snow := M.fmat(Color(0.93, 0.96, 1.0), 0.85, 0.3)
	var bark := M.tmat(M.tex_bark(170 + variant, Color(0.30, 0.21, 0.13)), 3.0)
	M.cyl(root, 0.05, 0.09, 0.46, Vector3(0, 0.23, 0), bark, 10)
	var tiers := 5 if variant == 0 else 4
	var h_total := 1.12 if variant == 0 else 0.86
	for i in tiers:
		var t := float(i) / float(tiers)
		var r := lerpf(0.52, 0.17, t) * (1.0 if variant == 0 else 1.08)
		var h := 0.60
		var y := 0.30 + t * h_total
		var c := M.cyl(root, 0.0, r, h, Vector3(0, y + h * 0.5, 0), leaf, 12)
		c.rotation_degrees.y = float(i) * 31.0
		# casquete de nieve (cono más fino y algo menor sobre la capa)
		var s := M.cyl(root, 0.0, r * 0.86, h * 0.60, Vector3(0, y + h * 0.5 + h * 0.19, 0), snow, 12)
		s.rotation_degrees.y = float(i) * 31.0
	M.ball(root, 0.07, Vector3(0, 0.30 + h_total + 0.56, 0), snow)
	return root

## Tercer pino (más alto y estrecho, seis capas)
static func pino_alto() -> Node3D:
	var root := Node3D.new()
	var leaf := M.tmat(M.tex_leaf(180, Color(0.10, 0.30, 0.18)), 1.8, Color.WHITE, 0.95)
	var bark := M.tmat(M.tex_bark(181, Color(0.34, 0.23, 0.13)), 3.0)
	M.cyl(root, 0.045, 0.08, 0.60, Vector3(0, 0.30, 0), bark, 10)
	for i in 6:
		var t := float(i) / 6.0
		var r := lerpf(0.42, 0.12, t)
		var h := 0.56
		var y := 0.38 + t * 1.30
		var c := M.cyl(root, 0.0, r, h, Vector3(0, y + h * 0.5, 0), leaf, 12)
		c.rotation_degrees.y = float(i) * 37.0
	return root

## Retoño: tallo fino con un par de brotes y una copita de hojas.
static func retono() -> Node3D:
	var root := Node3D.new()
	var bark := M.tmat(M.tex_bark(190, Color(0.40, 0.28, 0.16)), 3.0)
	var leaf := M.tmat(M.tex_leaf(191, Color(0.36, 0.60, 0.20)), 1.6, Color.WHITE, 0.95)
	var leaf_l := M.tmat(M.tex_leaf(192, Color(0.48, 0.70, 0.26)), 1.6, Color.WHITE, 0.95)
	M.cyl(root, 0.022, 0.035, 0.46, Vector3(0, 0.23, 0), bark, 6)
	M.lump(root, 0.17, Vector3(0.0, 0.54, 0.0), leaf_l, 1910, 0.30, 0.9)
	M.lump(root, 0.11, Vector3(0.14, 0.40, 0.06), leaf, 1911, 0.30, 0.9)
	M.lump(root, 0.10, Vector3(-0.13, 0.36, -0.06), leaf_l, 1912, 0.30, 0.9)
	M.lump(root, 0.09, Vector3(0.02, 0.28, 0.16), leaf, 1913, 0.30, 0.9)
	return root

## Arbusto de bayas: mata baja con frutos rojos.
static func bayas() -> Node3D:
	var root := Node3D.new()
	var leaf := M.tmat(M.tex_leaf(200, Color(0.20, 0.42, 0.16)), 1.6, Color.WHITE, 0.95)
	var leaf_l := M.tmat(M.tex_leaf(201, Color(0.28, 0.52, 0.20)), 1.6, Color.WHITE, 0.95)
	var berry := M.fmat(Color(0.80, 0.10, 0.16), 0.55, 0.5)
	var berry2 := M.fmat(Color(0.52, 0.10, 0.34), 0.55, 0.5)
	M.lump(root, 0.34, Vector3(0.0, 0.26, 0.0), leaf, 2010, 0.28, 0.80)
	M.lump(root, 0.26, Vector3(-0.26, 0.22, 0.08), leaf_l, 2011, 0.28, 0.80)
	M.lump(root, 0.24, Vector3(0.22, 0.20, 0.14), leaf, 2012, 0.28, 0.80)
	M.lump(root, 0.22, Vector3(0.04, 0.22, -0.26), leaf_l, 2013, 0.28, 0.80)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2020
	for k in 16:
		var a := rng.randf() * TAU
		var rr := rng.randf_range(0.10, 0.42)
		var y := 0.24 + (0.34 - rr * 0.55) * rng.randf_range(0.6, 1.0)
		M.ball(root, 0.035, Vector3(cos(a) * rr, y, sin(a) * rr + 0.04), berry if k % 4 != 0 else berry2)
	return root

## Pico: cono abollado por ruido, con color por vértice (roca más oscura abajo, nieve arriba si snow_y < 1).
static func peak_mesh(r: float, h: float, seed_v: int, amp: float, snow_y: float, blunt: float = 0.05) -> ArrayMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r * blunt
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 8
	cm.cap_top = true
	cm.cap_bottom = false
	var src := ArrayMesh.new()
	src.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, cm.get_mesh_arrays())
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(src, 0)
	var nz := FastNoiseLite.new()
	nz.seed = seed_v
	nz.frequency = 1.0
	var k := 2.6 / maxf(r, 0.01)
	for i in mdt.get_vertex_count():
		var v := mdt.get_vertex(i)
		var t := clampf((v.y + h * 0.5) / h, 0.0, 1.0)
		var n := nz.get_noise_3d(v.x * k, v.y * k * 0.8, v.z * k) + 0.5 * nz.get_noise_3d(v.x * k * 2.4 + 7.0, v.y * k * 2.4, v.z * k * 2.4)
		var push := 1.0 + amp * n * (1.0 - 0.45 * t)
		v.x *= push
		v.z *= push
		v.y += n * amp * 0.10 * h * (1.0 - t)
		mdt.set_vertex(i, v)
		var shade := lerpf(0.72, 1.06, t) + 0.10 * n
		var col := Color(0.50, 0.45, 0.40) * shade
		var sn := smoothstep(snow_y - 0.05, snow_y + 0.07, t + 0.10 * n)
		col = col.lerp(Color(0.93, 0.95, 1.0), sn)
		col.a = 1.0
		mdt.set_vertex_color(i, col)
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

static func _peak(parent: Node3D, r: float, h: float, pos: Vector3, seed_v: int, amp: float, snow_y: float, m: Material, blunt: float = 0.05) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = peak_mesh(r, h, seed_v, amp, snow_y, blunt)
	mi.material_override = m
	mi.position = pos + Vector3(0, h * 0.5, 0)
	parent.add_child(mi)

static func _rock_mat(variant: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = M.tex_leaf(220 + variant, Color(0.92, 0.90, 0.88))
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.4, 1.4, 1.4)
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## Montaña: pico principal ancho de cumbre roma, dos hombros y lomas en la falda. `snow` pone nieve en lo alto.
static func montana(variant: int, snow: bool) -> Node3D:
	var root := Node3D.new()
	var m := _rock_mat(variant)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2100 + variant
	var hh := 1.25 + 0.25 * float(variant % 3)
	var sy := 0.55 if snow else 2.0
	_peak(root, 0.80, hh, Vector3(rng.randf_range(-0.05, 0.05), 0, rng.randf_range(-0.05, 0.05)), 2200 + variant, 0.30, sy, m, 0.16)
	_peak(root, 0.55, hh * 0.62, Vector3(-0.42, 0, 0.22), 2210 + variant, 0.34, sy + 0.12, m, 0.20)
	_peak(root, 0.52, hh * 0.55, Vector3(0.40, 0, 0.26), 2220 + variant, 0.34, sy + 0.16, m, 0.20)
	for k in 4:
		var a := TAU * float(k) / 4.0 + rng.randf_range(0.0, 0.6)
		_peak(root, 0.36, 0.34, Vector3(cos(a) * 0.62, 0, sin(a) * 0.62), 2240 + variant * 7 + k, 0.4, 2.0, m, 0.35)
	return root

## Loma baja de roca (bordes de las cordilleras).
static func loma(variant: int) -> Node3D:
	var root := Node3D.new()
	var m := _rock_mat(variant + 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2400 + variant
	_peak(root, 0.62, 0.62 + 0.12 * float(variant % 2), Vector3(0, 0, 0), 2400 + variant, 0.34, 2.0, m, 0.30)
	_peak(root, 0.40, 0.38, Vector3(-0.38, 0, 0.18), 2410 + variant, 0.4, 2.0, m, 0.34)
	_peak(root, 0.36, 0.34, Vector3(0.36, 0, -0.14), 2420 + variant, 0.4, 2.0, m, 0.34)
	return root
