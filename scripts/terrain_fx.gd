class_name TerrainFx
extends RefCounted
## Prepara los datos del terreno para el shader (res://shaders/terrain.gdshader):
## textura de datos de 1 píxel por casilla y dos texturas de ruido sin costura.

static func make_material(sim: Sim) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	m.set_shader_parameter("data", build_data(sim))
	m.set_shader_parameter("nz1", _noise_tex(sim.seed_used + 11, 0.020, 4))
	m.set_shader_parameter("nz2", _noise_tex(sim.seed_used + 23, 0.050, 3))
	m.set_shader_parameter("map_size", Vector2(sim.W, sim.H))
	m.set_shader_parameter("tile_px", float(Defs.TILE))
	return m

## RGBA8: r = distancia con signo a la costa, g = temperatura, b = bosque, a = roca.
static func build_data(sim: Sim) -> ImageTexture:
	var W := sim.W
	var H := sim.H
	var n := W * H
	var trees := PackedFloat32Array()
	trees.resize(n)
	for i in n:
		if sim.rtype[i] == Defs.R_TREE:
			trees[i] = 1.0
	var forest := _blur(trees, W, H, 2)
	var hf := PackedFloat32Array()
	hf.resize(n)
	for i in n:
		hf[i] = float(sim.heat[i])
	var heat_s := _blur(hf, W, H, 1)
	var bytes := PackedByteArray()
	bytes.resize(n * 4)
	for i in n:
		var t: int = sim.terrain[i]
		var s := -float(mini(sim.dl[i], 8)) if t == Defs.T_WATER else float(mini(sim.dw[i], 8))
		bytes[i * 4] = int(clampf(s / 16.0 + 0.5, 0.0, 1.0) * 255.0)
		bytes[i * 4 + 1] = int(clampf(heat_s[i], 0.0, 255.0))
		bytes[i * 4 + 2] = int(clampf(forest[i] * 1.7, 0.0, 1.0) * 255.0)
		bytes[i * 4 + 3] = 255 if t == Defs.T_ROCK else 0
	var img := Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, bytes)
	return ImageTexture.create_from_image(img)

static func _noise_tex(seed_v: int, freq: float, octaves: int) -> ImageTexture:
	var chans: Array[PackedByteArray] = []
	for ch in 3:
		var nz := FastNoiseLite.new()
		nz.seed = seed_v + ch * 101
		nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		nz.fractal_type = FastNoiseLite.FRACTAL_FBM
		nz.fractal_octaves = octaves
		nz.frequency = freq
		chans.append(nz.get_seamless_image(256, 256, false, false, 0.1, true).get_data())
	var bytes := PackedByteArray()
	bytes.resize(256 * 256 * 3)
	for i in 256 * 256:
		bytes[i * 3] = chans[0][i]
		bytes[i * 3 + 1] = chans[1][i]
		bytes[i * 3 + 2] = chans[2][i]
	var img := Image.create_from_data(256, 256, false, Image.FORMAT_RGB8, bytes)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _blur(a: PackedFloat32Array, W: int, H: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(a.size())
	var out := PackedFloat32Array()
	out.resize(a.size())
	var k := 1.0 / float(2 * r + 1)
	for y in H:
		var sum := 0.0
		for x in range(-r, r + 1):
			sum += a[y * W + clampi(x, 0, W - 1)]
		for x in W:
			tmp[y * W + x] = sum * k
			sum += a[y * W + clampi(x + r + 1, 0, W - 1)] - a[y * W + clampi(x - r, 0, W - 1)]
	for x in W:
		var sum := 0.0
		for y in range(-r, r + 1):
			sum += tmp[clampi(y, 0, H - 1) * W + x]
		for y in H:
			out[y * W + x] = sum * k
			sum += tmp[clampi(y + r + 1, 0, H - 1) * W + x] - tmp[clampi(y - r, 0, H - 1) * W + x]
	return out
