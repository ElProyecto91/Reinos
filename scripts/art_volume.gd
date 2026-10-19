class_name ArtVolume
extends RefCounted
## Sombreado con volumen para los sprites de recursos (árboles, rocas, pepitas de oro).
## Cada sprite se arma con primitivas (esferas, conos, cilindros) que se rasterizan en un búfer de profundidad
## (z-buffer) guardando la normal de la superficie visible. Después cada píxel se ilumina por su normal con la luz
## del noroeste, la misma que usa el relieve del terreno (shaders/terrain.gdshader), así que las sombras de árboles
## y montañas caen hacia el mismo lado. Todo se pinta una vez al arrancar: no cuesta nada al dibujar.
##
## Tipos de material (mat): 1 follaje/agujas, 2 tronco, 3 nieve, 4 oro, 5 roca.

const LIGHT := Vector3(-0.52, -0.66, 0.54)
const NO_Z := -1.0e9

var w: int
var h: int
var zb := PackedFloat32Array()
var nx := PackedFloat32Array()
var ny := PackedFloat32Array()
var nz := PackedFloat32Array()
var cov := PackedFloat32Array()
var tone := PackedFloat32Array()
var kind := PackedByteArray()

func _init(width: int, height: int) -> void:
	w = width
	h = height
	var n: int = w * h
	zb.resize(n)
	zb.fill(NO_Z)
	nx.resize(n)
	ny.resize(n)
	nz.resize(n)
	cov.resize(n)
	tone.resize(n)
	tone.fill(1.0)
	kind.resize(n)

## Escribe un píxel de una primitiva: la cobertura crece siempre; la normal sólo cambia si queda por delante.
func _put(i: int, c: float, zz: float, vx: float, vy: float, vz: float, br: float, mat: int) -> void:
	var old: float = cov[i]
	if c > old:
		cov[i] = c
	if zz > zb[i] and (c >= 0.5 or old < 0.5):
		zb[i] = zz
		nx[i] = vx
		ny[i] = vy
		nz[i] = vz
		tone[i] = br
		kind[i] = mat

## Esfera (o elipsoide aplastado en vertical si sy < 1) con el centro en (cx, cy) y profundidad cz.
func sphere(cx: float, cy: float, cz: float, r: float, br: float, mat: int, sy: float = 1.0) -> void:
	var x0: int = maxi(0, int(floor(cx - r - 1.0)))
	var x1: int = mini(w - 1, int(ceil(cx + r + 1.0)))
	var y0: int = maxi(0, int(floor(cy - r * sy - 1.0)))
	var y1: int = mini(h - 1, int(ceil(cy + r * sy + 1.0)))
	var inv: float = 1.0 / maxf(r, 0.001)
	for y in range(y0, y1 + 1):
		var dy: float = (float(y) + 0.5 - cy) / sy
		for x in range(x0, x1 + 1):
			var dx: float = float(x) + 0.5 - cx
			var d: float = sqrt(dx * dx + dy * dy)
			var c: float = clampf(r - d + 0.5, 0.0, 1.0)
			if c <= 0.0:
				continue
			var dz: float = sqrt(maxf(0.0, r * r - d * d))
			_put(y * w + x, c, cz + dz, dx * inv, dy / sy * inv, dz * inv, br, mat)

## Cilindro vertical (tronco) que se ensancha de hw0 arriba a hw1 abajo.
func cylinder(cx: float, y0: float, y1: float, hw0: float, hw1: float, cz: float, br: float, mat: int) -> void:
	for y in range(maxi(0, int(floor(y0))), mini(h - 1, int(ceil(y1))) + 1):
		var py: float = float(y) + 0.5
		var t: float = clampf((py - y0) / maxf(y1 - y0, 0.001), 0.0, 1.0)
		var hw: float = lerpf(hw0, hw1, t)
		var cv: float = clampf(minf(py - y0 + 0.5, y1 - py + 0.5), 0.0, 1.0)
		for x in range(maxi(0, int(floor(cx - hw - 1.0))), mini(w - 1, int(ceil(cx + hw + 1.0))) + 1):
			var dx: float = float(x) + 0.5 - cx
			var c: float = clampf(hw - absf(dx) + 0.5, 0.0, 1.0) * cv
			if c <= 0.0:
				continue
			var th: float = asin(clampf(dx / maxf(hw, 0.5), -1.0, 1.0))
			_put(y * w + x, c, cz + cos(th) * hw, sin(th), 0.0, cos(th), br, mat)

## Piso de un pino: cono con el ápice arriba y la base elíptica (el borde delantero cae más abajo).
## snow_frac > 0 cubre de nieve esa fracción alta del piso, con borde ondulado.
func cone(cx: float, ytop: float, ybot: float, hw: float, cz: float, br: float, mat: int, snow_frac: float = 0.0, phase: float = 0.0) -> void:
	var ry: float = hw * 0.30
	var ys: float = ybot - ry
	for y in range(maxi(0, int(floor(ytop))), mini(h - 1, int(ceil(ybot))) + 1):
		var py: float = float(y) + 0.5
		var v: float = clampf((py - ytop) / maxf(ys - ytop, 0.001), 0.0, 1.0)
		var half: float = hw * v
		var under: float = smoothstep(0.80, 1.05, (py - ytop) / maxf(ybot - ytop, 0.001))
		for x in range(maxi(0, int(floor(cx - hw - 1.0))), mini(w - 1, int(ceil(cx + hw + 1.0))) + 1):
			var dx: float = float(x) + 0.5 - cx
			var c: float = clampf(half - absf(dx) + 0.5, 0.0, 1.0)
			if py > ys:
				var uu: float = clampf(dx / maxf(hw, 0.5), -1.0, 1.0)
				var edge: float = ys + ry * sqrt(maxf(0.0, 1.0 - uu * uu))
				c = minf(c, clampf(edge - py + 0.5, 0.0, 1.0))
			if c <= 0.0:
				continue
			var th: float = asin(clampf(dx / maxf(half, 0.6), -1.0, 1.0))
			var m: int = mat
			if snow_frac > 0.0:
				# la parte alta de cada piso la tapa el de arriba: la nieve se ve sobre todo en la punta y en el labio visible de abajo
				var lip: float = 0.60 + 0.30 * (0.55 + 0.45 * sin(dx * 1.7 + phase))
				if v < snow_frac * (1.0 + 0.32 * sin(dx * 0.95 + phase)) or (v > 0.58 and v < lip + 0.08):
					m = 3
			_put(y * w + x, c, cz + cos(th) * hw * 0.40, sin(th) * 0.80, -0.50, cos(th) * 0.80, br * (1.0 - 0.36 * under), m)

## Mechones: esferitas medio hundidas en la superficie ya pintada (hojas, agujas, grava). Dan textura al contorno y a la luz.
func clumps(count: int, rng: RandomNumberGenerator, rmin: float, rmax: float, jitter: float, mat: int) -> void:
	for k in count:
		var px: int = rng.randi_range(0, w - 1)
		var py: int = rng.randi_range(0, h - 1)
		var i: int = py * w + px
		if cov[i] < 0.95 or kind[i] != mat:
			continue
		var rr: float = rng.randf_range(rmin, rmax)
		sphere(float(px) + 0.5, float(py) + 0.5, zb[i] - rr * 0.55, rr, 1.0 + rng.randf_range(-jitter, jitter), mat)

## Facetas: reparte los píxeles de un material entre `count` celdas (Voronoi) y da a cada celda una sola normal
## (la de su centro, algo girada al azar): la roca queda tallada en planos con aristas vivas y grietas en los bordes.
func facets(count: int, rng: RandomNumberGenerator, mat: int, tilt: float, crack: float) -> void:
	var sx := PackedFloat32Array()
	var sy := PackedFloat32Array()
	var fx := PackedFloat32Array()
	var fy := PackedFloat32Array()
	var fz := PackedFloat32Array()
	var fb := PackedFloat32Array()
	var tries: int = 0
	while sx.size() < count and tries < count * 60:
		tries += 1
		var px: int = rng.randi_range(0, w - 1)
		var py: int = rng.randi_range(0, h - 1)
		var i: int = py * w + px
		if cov[i] < 0.95 or kind[i] != mat:
			continue
		var n := Vector3(nx[i], ny[i], nz[i]).normalized()
		n = (n + Vector3(rng.randf_range(-tilt, tilt), rng.randf_range(-tilt, tilt), rng.randf_range(-tilt * 0.5, tilt * 0.5))).normalized()
		sx.append(float(px) + 0.5)
		sy.append(float(py) + 0.5)
		fx.append(n.x)
		fy.append(n.y)
		fz.append(n.z)
		fb.append(1.0 + rng.randf_range(-0.13, 0.13))
	var m: int = sx.size()
	if m < 2:
		return
	for y in h:
		for x in w:
			var i: int = y * w + x
			if cov[i] < 0.5 or kind[i] != mat:
				continue
			var best: float = 1.0e9
			var second: float = 1.0e9
			var bi: int = 0
			for k in m:
				var dx: float = float(x) + 0.5 - sx[k]
				var dy: float = float(y) + 0.5 - sy[k]
				var d: float = dx * dx + dy * dy
				if d < best:
					second = best
					best = d
					bi = k
				elif d < second:
					second = d
			nx[i] = fx[bi]
			ny[i] = fy[bi]
			nz[i] = fz[bi]
			tone[i] = fb[bi] * (1.0 - crack * (1.0 - smoothstep(0.0, 2.0, sqrt(second) - sqrt(best))))

## Grano fino: cada píxel varía un poco de brillo.
func grain(rng: RandomNumberGenerator, amount: float) -> void:
	for i in w * h:
		if cov[i] > 0.0:
			tone[i] *= 1.0 + rng.randf_range(-amount, amount)

## Paleta de tres tonos (sombra azulada, medio, luz amarillenta) a partir de un color base.
static func pal(base: Color, dark: float = 0.38, bright: float = 1.30) -> Array:
	var sh := Color(base.r * dark * 0.95, base.g * dark * 1.10, base.b * dark * 1.15 + 0.03, 1.0)
	var li := Color(minf(1.0, base.r * bright + 0.05), minf(1.0, base.g * bright + 0.05), minf(1.0, base.b * bright * 0.92), 1.0)
	return [sh, base, li]

## Oclusión de las hendiduras: un píxel más hundido que la media de sus vecinos (entre lóbulos, bajo cada piso de pino)
## recibe menos luz. Los vecinos vacíos no cuentan: el borde de la silueta no se oscurece por esto.
func _creases() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(w * h)
	var offs: Array[Vector2i] = [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(2, 2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(-2, -2)]
	for y in h:
		for x in w:
			var i: int = y * w + x
			if cov[i] < 0.5:
				continue
			var sum: float = 0.0
			var cnt: int = 0
			for o in offs:
				var qx: int = x + o.x
				var qy: int = y + o.y
				if qx < 0 or qy < 0 or qx >= w or qy >= h:
					continue
				var j: int = qy * w + qx
				if cov[j] >= 0.5:
					sum += zb[j]
					cnt += 1
			if cnt > 0:
				out[i] = clampf((sum / float(cnt) - zb[i]) * 0.055, 0.0, 0.42)
	return out

## Ilumina el búfer y devuelve la imagen. pals[mat] = [sombra, medio, luz]; gloss[mat] = brillo especular.
## Las filas por debajo de ao_y0 se oscurecen hasta `ao` en ao_y1 (oclusión de la propia copa). El contorno es un halo fino.
func render(pals: Array, gloss: Dictionary, ao_y0: float, ao_y1: float, ao: float, rim: Color, rim_a: float) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var L: Vector3 = LIGHT.normalized()
	var Hv: Vector3 = (L + Vector3(0, 0, 1)).normalized()
	var crease: PackedFloat32Array = _creases()
	for y in h:
		var occ: float = 1.0 - ao * smoothstep(ao_y0, ao_y1, float(y))
		for x in w:
			var i: int = y * w + x
			var cv: float = cov[i]
			if cv <= 0.0:
				continue
			var n := Vector3(nx[i], ny[i], nz[i]).normalized()
			var t: float = clampf((n.dot(L) * 0.62 + 0.46 - n.y * 0.10) * tone[i] * occ * (1.0 - crease[i]), 0.0, 1.0)
			var p: Array = pals[kind[i]]
			var col: Color
			if t < 0.5:
				col = (p[0] as Color).lerp(p[1] as Color, t * 2.0)
			else:
				col = (p[1] as Color).lerp(p[2] as Color, (t - 0.5) * 2.0)
			var gl: float = float(gloss.get(int(kind[i]), 0.0))
			if gl > 0.0:
				var sp: float = pow(maxf(0.0, n.dot(Hv)), 22.0) * gl
				col = Color(col.r + sp, col.g + sp * 0.95, col.b + sp * 0.70, 1.0)
			var edge: float = 0.80 + 0.20 * smoothstep(0.0, 0.45, n.z)     # el borde de la silueta mira de lado: algo más oscuro
			img.set_pixel(x, y, Color(clampf(col.r * edge, 0.0, 1.0), clampf(col.g * edge, 0.0, 1.0), clampf(col.b * edge, 0.0, 1.0), cv))
	# halo oscuro alrededor de la silueta (1 px), más fino y suave que un contorno negro
	var halo: Array[Vector3i] = []
	for y in h:
		for x in w:
			var i: int = y * w + x
			if cov[i] >= 0.5:
				continue
			var m: float = 0.0
			if x > 0: m = maxf(m, cov[i - 1])
			if x < w - 1: m = maxf(m, cov[i + 1])
			if y > 0: m = maxf(m, cov[i - w])
			if y < h - 1: m = maxf(m, cov[i + w])
			if m >= 0.5:
				halo.append(Vector3i(x, y, int(round(m * 100.0))))
	for q in halo:
		var a: float = maxf(cov[q.y * w + q.x], rim_a * float(q.z) / 100.0)
		img.set_pixel(q.x, q.y, Color(rim.r, rim.g, rim.b, a))
	return img
