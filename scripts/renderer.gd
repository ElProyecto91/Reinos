class_name Renderer
extends RefCounted
## Funciones de dibujo del mundo isométrico fuera de los sprites (que gestiona IsoView):
##  · terreno y niebla: en coordenadas lógicas, la capa lleva la transformación Iso.XF (se proyectan solas)
##  · marcas del suelo («decals»): se dibujan en el plano isométrico proyectando a mano (trazos de grosor uniforme)
##  · capa superior: humo, luces nocturnas, barras de vida, iconos de carga y efectos

const T := Defs.TILE
const S := IsoArt.SPRITE_SCALE

static func draw_terrain(g: Game, c: CanvasItem) -> void:
	# el color lo calcula el shader del material de la capa (shaders/terrain.gdshader)
	c.draw_rect(Rect2(0, 0, g.sim.W * T, g.sim.H * T), Color.WHITE, true)

static func draw_fog(g: Game, c: CanvasItem) -> void:
	if g.fog != null:
		c.draw_texture_rect(g.fog.tex, Rect2(0, 0, g.sim.W * T, g.sim.H * T), false)

# ------------------------------------------------------------------ ayudas de proyección

static func _quad(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([Iso.proj(r.position), Iso.proj(Vector2(r.end.x, r.position.y)), Iso.proj(r.end), Iso.proj(Vector2(r.position.x, r.end.y))])

static func _quad_closed(r: Rect2) -> PackedVector2Array:
	var q := _quad(r)
	q.append(q[0])
	return q

## Elipse de suelo (círculo lógico de radio r) con centro en el punto lógico p
static func _ring(c: CanvasItem, p: Vector2, r: float, col: Color, w: float) -> void:
	c.draw_set_transform(Iso.proj(p), 0.0, Vector2(1.0, 0.5))
	c.draw_arc(Vector2.ZERO, r * 1.4142, 0.0, TAU, 32, col, w)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _disc(c: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	c.draw_set_transform(Iso.proj(p), 0.0, Vector2(1.0, 0.5))
	c.draw_circle(Vector2.ZERO, r * 1.4142, col)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func _corners(c: CanvasItem, r: Rect2, col: Color) -> void:
	## Esquinas de la huella de un edificio (rombo en el suelo)
	var q := _quad(r)
	for i in 4:
		var a := q[i]
		var b := q[(i + 1) % 4]
		var d := q[(i + 3) % 4]
		c.draw_line(a, a + (b - a) * 0.28, col, 3.0)
		c.draw_line(a, a + (d - a) * 0.28, col, 3.0)

# ------------------------------------------------------------------ marcas del suelo

static func draw_decals(g: Game, c: CanvasItem) -> void:
	var sim := g.sim
	var vr := g.view_rect(80.0)
	# Peces (rizos en el agua)
	if g.view != null:
		for idx in g.view.fish:
			var tx: int = idx % sim.W
			var ty: int = idx / sim.W
			var p := Vector2(tx, ty) * T + Vector2(T, T) * 0.5
			if vr.has_point(p) and g.fog.explored_at(Vector2i(tx, ty)):
				_draw_fish(g, c, p, idx)
	# Granjas
	for idx in g.farm_tiles:
		var tx: int = idx % sim.W
		var ty: int = idx / sim.W
		var r := Rect2(tx * T, ty * T, T, T)
		if vr.intersects(r) and g.fog.explored_at(Vector2i(tx, ty)):
			_draw_farm(c, r, float(sim.ramt[idx]) / float(Defs.RES_INFO[Defs.R_FARM]["amount"]), sim.rowner[idx] == g.human)
	# Muelles
	for b: Ent in sim.buildings:
		if b.alive and b.def.get("dock", false) and vr.intersects(b.rect()) and g.can_see_building(b):
			_draw_pier(c, b)
	if not sim.zones.is_empty():
		_draw_zones_ground(g, c)
	# Anillos de selección
	for id in g.sel:
		var e := sim.get_ent(id)
		if e == null:
			continue
		var col := Color(0.2, 1.0, 0.3, 0.95) if e.owner == g.human else Color(1.0, 0.4, 0.3, 0.95)
		if e.is_building:
			_corners(c, e.rect().grow(2.0), col)
			if e.owner == g.human and e.rally.x >= 0:
				var rp := sim.tile_center(e.rally)
				c.draw_line(Iso.proj(e.center()), Iso.proj(rp), Color(1, 1, 1, 0.35), 1.5)
		else:
			var p: Vector2 = e.ppos.lerp(e.pos, g.interp)
			var rr := e.radius + 5.0
			if e.naval:
				rr = e.radius + 9.0
			_ring(c, p, rr, col, 2.2)
	# Marcadores de orden
	for m in g.markers:
		var k: float = float(m["a"]) / float(m["life"])
		var col: Color = m["col"]
		col.a = 1.0 - k
		_ring(c, m["p"], 4.0 + 13.0 * k, col, 2.5)
	# Fantasma de construcción: la huella (el sprite lo pone IsoView)
	if g.placing_type != "" and g.place_tile.x >= 0:
		_draw_ghost_ground(g, c)

static func _draw_fish(g: Game, c: CanvasItem, p: Vector2, idx: int) -> void:
	var ph := float(idx % 7) * 0.9
	var t := g.anim_t * 1.3 + ph
	var ip := Iso.proj(p)
	var k := fposmod(t, 3.0) / 3.0
	c.draw_set_transform(ip, 0.0, Vector2(1.0, 0.5))
	c.draw_arc(Vector2.ZERO, 6.0 + 12.0 * k, 0.0, TAU, 20, Color(1, 1, 1, 0.34 * (1.0 - k)), 1.4)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var side := 1.0 if idx % 2 == 0 else -1.0
	var q := ip + Vector2(sin(t * 0.9) * 7.0 * side, cos(t * 0.7) * 2.0)
	c.draw_colored_polygon(PackedVector2Array([q + Vector2(5, 0), q + Vector2(0, -2.2), q + Vector2(-4, 0), q + Vector2(0, 2.2)]), Color(0.86, 0.92, 0.98, 0.9))
	c.draw_colored_polygon(PackedVector2Array([q + Vector2(-3.5, 0), q + Vector2(-7.5, -2.5), q + Vector2(-7.5, 2.5)]), Color(0.72, 0.82, 0.92, 0.9))

static func _draw_farm(c: CanvasItem, r: Rect2, frac: float, mine: bool) -> void:
	var inner := r.grow(-1.5)
	c.draw_colored_polygon(_quad(inner), Color(0.42, 0.28, 0.14))
	var crop := Color(0.45, 0.62, 0.2).lerp(Color(0.85, 0.72, 0.2), clampf(1.0 - frac, 0.0, 1.0) * 0.4)
	if frac < 0.25:
		crop = Color(0.55, 0.42, 0.2)
	for i in 4:
		var y := r.position.y + 5.0 + i * 7.0
		c.draw_line(Iso.proj(Vector2(r.position.x + 4, y)), Iso.proj(Vector2(r.end.x - 4, y)), crop, 3.0)
	c.draw_polyline(_quad_closed(inner), Color(0.2, 0.12, 0.05), 1.5)

## Zonas de fuego (suelo): disco rojizo
static func _draw_zones_ground(g: Game, c: CanvasItem) -> void:
	for z: Dictionary in g.sim.zones:
		var p: Vector2 = z["p"]
		if int(z["owner"]) != g.human and not g.fog.visible_at(g.sim.tile_of(p)):
			continue
		var r: float = z["r"]
		var fade := clampf((float(z["until"]) - g.sim.time) / 1.2, 0.0, 1.0)
		_disc(c, p, r, Color(0.85, 0.25, 0.05, 0.20 * fade))
		_ring(c, p, r, Color(1.0, 0.55, 0.12, 0.75 * fade), 2.5)

static func _draw_ghost_ground(g: Game, c: CanvasItem) -> void:
	var type := g.placing_type
	if type == "muralla" or type == "puerta":
		var tiles: Array = g.wall_tiles if not g.wall_tiles.is_empty() else [g.place_tile]
		for t: Vector2i in tiles:
			var okw := g.sim.can_place(type, t, g.human)
			var r := Rect2(Vector2(t) * T, Vector2(T, T)).grow(-2)
			var colw := Color(0.55, 0.9, 0.5, 0.55) if okw else Color(1.0, 0.2, 0.2, 0.5)
			c.draw_colored_polygon(_quad(r), colw)
			c.draw_polyline(_quad_closed(r), Color(colw.r, colw.g, colw.b, 0.95), 2.0)
		return
	var ok := g.sim.can_place(type, g.place_tile, g.human)
	var col := Color(0.2, 1.0, 0.3, 0.35) if ok else Color(1.0, 0.2, 0.2, 0.4)
	var size := 1 if Defs.is_plot(type) else int(Defs.BUILDINGS[type]["size"])
	var r := Rect2(Vector2(g.place_tile) * T, Vector2(size, size) * T)
	c.draw_colored_polygon(_quad(r), col)
	c.draw_polyline(_quad_closed(r), Color(col.r, col.g, col.b, 0.95), 2.5)

## Muelle de madera del puerto: sale de la fachada del lado del mar, junto a la casilla donde atracan los barcos.
static func _draw_pier(c: CanvasItem, b: Ent) -> void:
	var dirs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	var dir: Vector2 = dirs[b.orient]
	var side := Vector2(-dir.y, dir.x)
	var k := 0
	if b.dock_tile.x >= 0:
		k = (b.dock_tile.x - b.tile.x) if (b.orient == 0 or b.orient == 2) else (b.dock_tile.y - b.tile.y)
	var pk := 0 if k >= 1 else b.size - 1
	var base := b.rect().get_center() + dir * (float(b.size) * T * 0.5) + side * ((float(pk) + 0.5 - float(b.size) * 0.5) * T)
	var a := 1.0 if b.progress >= 1.0 else 0.5
	var p0 := base - dir * 6.0
	var p1 := base + dir * (T * 1.55)
	var hw := 9.0
	var wood := Color(0.60, 0.43, 0.24, a)
	var dark := Color(0.30, 0.19, 0.09, a)
	c.draw_colored_polygon(PackedVector2Array([Iso.proj(p0 - side * (hw + 1.5)), Iso.proj(p1 - side * (hw + 1.5)), Iso.proj(p1 + side * (hw + 1.5)), Iso.proj(p0 + side * (hw + 1.5))]), dark)
	c.draw_colored_polygon(PackedVector2Array([Iso.proj(p0 - side * hw), Iso.proj(p1 - side * hw), Iso.proj(p1 + side * hw), Iso.proj(p0 + side * hw)]), wood)
	var n := 8
	for i in range(1, n):
		var q := p0.lerp(p1, float(i) / float(n))
		c.draw_line(Iso.proj(q - side * hw), Iso.proj(q + side * hw), Color(dark.r, dark.g, dark.b, 0.7 * a), 1.0)
	c.draw_line(Iso.proj(p0 - side * hw), Iso.proj(p1 - side * hw), Color(0.80, 0.62, 0.36, a), 1.5)
	for sgn in [-1.0, 1.0]:
		for t in [0.35, 1.0]:
			var pp: Vector2 = Iso.proj(p0.lerp(p1, float(t)) + side * hw * float(sgn))
			c.draw_circle(pp, 2.4, dark)
			c.draw_circle(pp - Vector2(0.5, 0.5), 1.5, Color(0.52, 0.36, 0.20, a))

# ------------------------------------------------------------------ capa superior

static var _smoke: PackedFloat32Array = PackedFloat32Array()   # x, y, radio, alfa de cada bocanada del fotograma

## Chimeneas (px de pantalla respecto al centro de la huella) y ventanas (x, y, ancho, alto) para el brillo nocturno
const SMOKE := {"casa": Vector2(18, -78), "centro": Vector2(30, -128), "cuartel": Vector2(24, -100), "herreria": Vector2(-20, -92)}
const WINDOWS := {
	"casa": [[-14, -34, 7, 8], [10, -28, 7, 8]],
	"centro": [[-30, -50, 8, 10], [26, -44, 8, 10]],
	"cuartel": [[-30, -46, 8, 9], [26, -40, 8, 9]],
	"puerto": [[-24, -40, 7, 8], [20, -34, 7, 8]],
}

static func draw_overlay(g: Game, c: CanvasItem) -> void:
	var sim := g.sim
	var view := g.view
	var vi := g.view_iso(100.0)
	_smoke.clear()
	# Edificios: humo, luces de noche y barras
	for b: Ent in sim.buildings:
		if not b.alive or not g.can_see_building(b):
			continue
		var ctr := Iso.proj(b.center())
		if not vi.has_point(ctr):
			continue
		_overlay_building(g, c, b, ctr, view)
	# Humo (una sola tanda de dibujo)
	var sm := g.art.puff_tex
	for i in range(0, _smoke.size(), 4):
		var rad := _smoke[i + 2] * 1.0667
		c.draw_texture_rect(sm, Rect2(_smoke[i] - rad, _smoke[i + 1] - rad, rad * 2.0, rad * 2.0), false, Color(0.86, 0.86, 0.88, _smoke[i + 3]))
	# Unidades: iconos de carga y barras de vida
	_overlay_units(g, c, vi)
	_draw_zone_flames(g, c)
	# Banderas de punto de reunión de edificios seleccionados
	for id in g.sel:
		var e := sim.get_ent(id)
		if e != null and e.is_building and e.owner == g.human and e.rally.x >= 0:
			var rp := Iso.proj(sim.tile_center(e.rally))
			c.draw_line(rp, rp + Vector2(0, -22), Color(0.2, 0.15, 0.1), 2.0)
			c.draw_colored_polygon(PackedVector2Array([rp + Vector2(0, -22), rp + Vector2(14, -17), rp + Vector2(0, -12)]), Defs.PLAYER_COLORS[g.human])
	# Efectos
	for f in g.fx:
		_draw_fx(c, f)
	# Caja de selección (los dos extremos están en pantalla; el rectángulo se dibuja en el plano isométrico)
	if g.box_active:
		var a := g.screen_to_iso(g.box_start)
		var b := g.screen_to_iso(g.box_end)
		var rr := Rect2(a, b - a).abs()
		c.draw_rect(rr, Color(0.3, 1.0, 0.4, 0.15), true)
		c.draw_rect(rr, Color(0.3, 1.0, 0.4, 0.9), false, 2.0 / g.zoom)

static func _bar(c: CanvasItem, cx: float, y: float, w: float, f: float, h: float = 3.0) -> void:
	c.draw_rect(Rect2(cx - w * 0.5 - 1, y - 1, w + 2, h + 2), Color(0, 0, 0, 0.75), true)
	c.draw_rect(Rect2(cx - w * 0.5, y, w * f, h), Color(0.9 - 0.7 * f, 0.25 + 0.65 * f, 0.15), true)

static func _overlay_building(g: Game, c: CanvasItem, b: Ent, ctr: Vector2, view: IsoView) -> void:
	var done := b.progress >= 1.0
	if b.def.get("wall", false):
		if (b.hp < b.max_hp * 0.995 and done) or g.sel_set.has(b.id):
			_bar(c, ctr.x, ctr.y - 40.0, 28.0, clampf(b.hp / b.max_hp, 0.0, 1.0))
		return
	if done:
		if SMOKE.has(b.type):
			var base: Vector2 = ctr + (SMOKE[b.type] as Vector2)
			for k in 3:
				var ph := fposmod(g.anim_t * 0.30 + float(k) / 3.0 + float(b.id) * 0.137, 1.0)
				var p := base + Vector2(ph * 10.0 + sin(ph * 6.0 + float(b.id)) * 2.0, -ph * 32.0)
				_smoke.append(p.x)
				_smoke.append(p.y)
				_smoke.append(2.2 + ph * 6.5)
				_smoke.append(0.42 * (1.0 - ph) * minf(1.0, ph * 6.0))
		if g.night > 0.12 and WINDOWS.has(b.type):
			for w: Array in WINDOWS[b.type]:
				var wr := Rect2(ctr + Vector2(float(w[0]), float(w[1])), Vector2(float(w[2]), float(w[3])))
				var gr := wr.size.x * 1.6
				c.draw_texture_rect(g.art.puff_tex, Rect2(wr.get_center() - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(1.0, 0.78, 0.38, 0.10 * g.night))
				c.draw_rect(wr, Color(1.0, 0.84, 0.45, 0.88 * g.night), true)
	var show_bar := b.hp < b.max_hp or g.sel_set.has(b.id) or not done
	if show_bar:
		var dims := view.building_dims(b.type)
		var w := clampf(dims.size.x * 0.5, 36.0, 90.0)
		var y := ctr.y + dims.position.y - 6.0
		_bar(c, ctr.x, y, w, clampf(b.hp / b.max_hp, 0.0, 1.0), 5.0)
		if not done:
			c.draw_rect(Rect2(ctr.x - w * 0.5, y + 8, w * b.progress, 3), Color(0.4, 0.7, 1.0), true)

static func _overlay_units(g: Game, c: CanvasItem, vi: Rect2) -> void:
	var sim := g.sim
	var view := g.view
	var art := g.art
	var catlas := art.carry_atlas
	var cs := float(art.carry_cell)
	var sel: Dictionary = g.sel_set
	for u in sim.units:
		if not u.alive:
			continue
		var carry := u.carry_amt >= 1.0
		var hurt := u.hp < u.max_hp or sel.has(u.id)
		if not carry and not hurt:
			continue
		var p: Vector2 = u.ppos.lerp(u.pos, g.interp)
		var ip := Iso.proj(p)
		if not vi.has_point(ip) or not g.can_see_unit(u):
			continue
		var ti := view.tinfo(u.type)
		var top := ti.top if ti.has_any else 36.0
		if carry and (ti.vill or ti.fisher):
			var co := Vector2(10, -top * 0.78) if ti.vill else Vector2(0, -top - 8.0)
			var fill := clampf(u.carry_amt / ti.carry_max, 0.0, 1.0)
			var hs := Art.CARRY_HALF * 0.7 * (0.8 + 0.4 * fill)
			var o := ip + co
			var ci := 0 if u.carry_kind == "gold" else (1 if u.carry_kind == "food" else 2)
			c.draw_texture_rect_region(catlas, Rect2(o.x - hs, o.y - hs, hs * 2.0, hs * 2.0), Rect2(float(ci) * cs, 0.0, cs, cs))
		if hurt:
			var w := 26.0 if not ti.naval else 36.0
			_bar(c, ip.x, ip.y - top - 7.0, w, clampf(u.hp / u.max_hp, 0.0, 1.0))

## Llamas de las zonas de fuego (encima de los sprites)
static func _draw_zone_flames(g: Game, c: CanvasItem) -> void:
	if g.sim.zones.is_empty():
		return
	var tt := g.anim_t
	for z: Dictionary in g.sim.zones:
		var p: Vector2 = z["p"]
		if int(z["owner"]) != g.human and not g.fog.visible_at(g.sim.tile_of(p)):
			continue
		var r: float = z["r"]
		var fade := clampf((float(z["until"]) - g.sim.time) / 1.2, 0.0, 1.0)
		for i in 18:
			var ang := float(i) * 2.39996
			var rad := r * sqrt((float(i) + 0.5) / 18.0) * 0.92
			var b := Iso.proj(p + Vector2(cos(ang), sin(ang)) * rad)
			var h := (13.0 + 9.0 * sin(tt * 9.0 + float(i) * 1.7)) * fade
			var sw := 3.5 * sin(tt * 7.0 + float(i))
			c.draw_colored_polygon(PackedVector2Array([b + Vector2(-5.5, 0), b + Vector2(5.5, 0), b + Vector2(sw, -h)]), Color(1.0, 0.42, 0.08, 0.85 * fade))
			c.draw_colored_polygon(PackedVector2Array([b + Vector2(-3.0, 0), b + Vector2(3.0, 0), b + Vector2(sw * 0.6, -h * 0.62)]), Color(1.0, 0.85, 0.30, 0.9 * fade))

# ------------------------------------------------------------------ efectos (posiciones lógicas -> plano isométrico)

const UP_BODY := Vector2(0, -20)      # de los pies al pecho de una unidad

static func _draw_fx(c: CanvasItem, f: Dictionary) -> void:
	var k: float = float(f["a"]) / float(f["life"])
	match f["t"]:
		"arrow":
			var from: Vector2 = Iso.proj(f["p"]) + UP_BODY
			var to: Vector2 = Iso.proj(f["q"]) + UP_BODY * 0.8
			var pos := from.lerp(to, minf(1.0, k * 1.3))
			var dir := (to - from).normalized()
			c.draw_line(pos - dir * 12.0, pos, Color(0.95, 0.9, 0.7, 0.95), 2.0)
			c.draw_line(pos, pos - dir * 3.0 + dir.orthogonal() * 3.0, Color(0.95, 0.9, 0.7, 0.95), 1.5)
		"hit":
			var p: Vector2 = Iso.proj(f["p"]) + UP_BODY
			var rr: float = 4.0 + 8.0 * k
			c.draw_circle(p, rr, Color(1.0, 0.85, 0.3, 0.8 * (1.0 - k)))
			c.draw_arc(p, rr + 3.0, 0.0, TAU, 12, Color(1, 1, 1, 0.8 * (1.0 - k)), 1.5)
		"puff":
			var p: Vector2 = Iso.proj(f["p"]) + Vector2(0, -8)
			var rad: float = float(f["r"]) * (0.5 + k)
			c.draw_circle(p, rad, Color(0.55, 0.5, 0.45, 0.55 * (1.0 - k)))
			c.draw_circle(p + Vector2(-rad * 0.5, -rad * 0.3), rad * 0.7, Color(0.7, 0.66, 0.6, 0.4 * (1.0 - k)))
			c.draw_circle(p + Vector2(rad * 0.5, -rad * 0.2), rad * 0.6, Color(0.7, 0.66, 0.6, 0.4 * (1.0 - k)))
		"cannon":
			var q: Vector2 = Iso.proj(f["q"])
			var dir_l: Vector2 = (f["q"] as Vector2) - (f["p"] as Vector2)
			var p: Vector2 = Iso.proj(f["p"]) + Vector2(0, -16)
			# fogonazo y humo en la boca; la bala cruza el aire rápido
			c.draw_circle(p, 9.0 * (1.0 - k) + 2.0, Color(1.0, 0.82, 0.30, 0.9 * (1.0 - k)))
			c.draw_circle(p + Vector2(7.0 * k, -6.0 * k), 6.0 + 12.0 * k, Color(0.78, 0.78, 0.80, 0.55 * (1.0 - k)))
			c.draw_circle(p + Vector2(14.0 * k, -12.0 * k), 5.0 + 9.0 * k, Color(0.70, 0.70, 0.72, 0.4 * (1.0 - k)))
			var bp := p.lerp(q + UP_BODY * 0.6, minf(1.0, k * 1.9))
			if k < 0.53:
				c.draw_circle(bp, 3.0, Color(0.08, 0.07, 0.07, 0.95))
				c.draw_line(bp, bp - (q - p).normalized() * 14.0, Color(0.9, 0.9, 0.9, 0.5), 2.0)
		"rock":
			var p: Vector2 = Iso.proj(f["p"]) + Vector2(0, -22)
			var q: Vector2 = Iso.proj(f["q"])
			# la piedra sube en arco y cae; al caer levanta una nube de polvo
			var kk := minf(1.0, k * 1.25)
			var bp := p.lerp(q, kk) + Vector2(0, -sin(kk * PI) * 60.0)
			if kk < 1.0:
				c.draw_circle(bp, 3.6, Color(0.30, 0.28, 0.26, 0.95))
				c.draw_circle(bp + Vector2(-1.0, -1.0), 1.6, Color(0.55, 0.52, 0.48, 0.9))
			else:
				var j := (k - 0.8) / 0.2
				c.draw_circle(q, 6.0 + 14.0 * j, Color(0.62, 0.56, 0.48, 0.55 * (1.0 - j)))
				c.draw_set_transform(q, 0.0, Vector2(1.0, 0.5))
				c.draw_arc(Vector2.ZERO, 8.0 + 16.0 * j, 0.0, TAU, 16, Color(1, 1, 1, 0.5 * (1.0 - j)), 1.5)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"heal":
			var p: Vector2 = Iso.proj(f["p"]) + Vector2(0, -8)
			var q := p + Vector2(0, -16.0 * k)
			var a := 1.0 - k
			c.draw_rect(Rect2(q + Vector2(-1.4, -4.5), Vector2(2.8, 9.0)), Color(0.3, 1.0, 0.45, a))
			c.draw_rect(Rect2(q + Vector2(-4.5, -1.4), Vector2(9.0, 2.8)), Color(0.3, 1.0, 0.45, a))
		"flash":
			var p: Vector2 = Iso.proj(f["p"])
			c.draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
			c.draw_arc(Vector2.ZERO, 10.0 + 22.0 * k, 0.0, TAU, 24, Color(1, 1, 1, 0.8 * (1.0 - k)), 3.0)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"text":
			var tp: Vector2 = Iso.proj(f["p"])
			var tcol: Color = f["col"]
			var fnt := ThemeDB.fallback_font
			var fa := 1.0 - maxf(0.0, (k - 0.6) / 0.4)
			var q := tp + Vector2(0, -34.0 * k)
			c.draw_string(fnt, q + Vector2(-17, 2), str(f["s"]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 22, Color(0, 0, 0, 0.8 * fa))
			c.draw_string(fnt, q + Vector2(-18, 0), str(f["s"]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 22, Color(tcol.r, tcol.g, tcol.b, fa))
		"ping":
			var p: Vector2 = Iso.proj(f["p"])
			c.draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
			c.draw_arc(Vector2.ZERO, 10.0 + 70.0 * k, 0.0, TAU, 32, Color(1, 0.2, 0.2, 0.9 * (1.0 - k)), 4.0)
			c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
