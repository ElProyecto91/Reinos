class_name Renderer
extends RefCounted
## Funciones de dibujo del mundo (terreno, entidades, efectos, niebla).

const T := Defs.TILE

static func draw_terrain(g: Game, c: CanvasItem) -> void:
	# el color lo calcula el shader del material de la capa (shaders/terrain.gdshader)
	c.draw_rect(Rect2(0, 0, g.sim.W * T, g.sim.H * T), Color.WHITE, true)

static func draw_fog(g: Game, c: CanvasItem) -> void:
	if g.fog != null:
		c.draw_texture_rect(g.fog.tex, Rect2(0, 0, g.sim.W * T, g.sim.H * T), false)

# ------------------------------------------------------------------ entidades

static var _bs: Array = []              # edificios ordenados por y (se reordena sólo si cambian)
static var _bs_key := Vector3i(-1, -1, -1)
static var _smoke: PackedFloat32Array = PackedFloat32Array()   # x, y, radio, alfa de cada bocanada del fotograma

static func _sorted_buildings(sim: Sim) -> Array:
	var key := Vector3i(sim.get_instance_id() & 0x7fffffff, sim.buildings.size(), sim.next_id)
	if key != _bs_key:
		_bs_key = key
		_bs = sim.buildings.duplicate()
		_bs.sort_custom(func(a: Ent, b: Ent) -> bool: return a.tile.y + a.size < b.tile.y + b.size)
	return _bs

static func draw_entities(g: Game, c: CanvasItem) -> void:
	var sim := g.sim
	var vr := g.view_rect(80.0)
	# Granjas
	for idx in g.farm_tiles:
		var tx: int = idx % sim.W
		var ty: int = idx / sim.W
		var r := Rect2(tx * T, ty * T, T, T)
		if vr.intersects(r) and g.fog.explored_at(Vector2i(tx, ty)):
			_draw_farm(c, r, float(sim.ramt[idx]) / float(Defs.RES_INFO[Defs.R_FARM]["amount"]), sim.rowner[idx] == g.human)
	# Edificios (ordenados por y; la lista ordenada se reutiliza entre fotogramas)
	_smoke.clear()
	for b: Ent in _sorted_buildings(sim):
		if b.alive and vr.intersects(b.rect()) and g.can_see_building(b):
			_draw_building(g, c, b)
	# El humo se dibuja todo junto (una sola llamada de dibujo) por encima de los edificios
	var sm := g.art.puff_tex
	for i in range(0, _smoke.size(), 4):
		var rad := _smoke[i + 2] * 1.0667
		c.draw_texture_rect(sm, Rect2(_smoke[i] - rad, _smoke[i + 1] - rad, rad * 2.0, rad * 2.0), false, Color(0.86, 0.86, 0.88, _smoke[i + 3]))
	_draw_fauna(g, c, vr)
	_draw_units(g, c, vr)
	if not sim.zones.is_empty():
		_draw_zones(g, c)
	# Efectos
	for f in g.fx:
		_draw_fx(c, f)
	# Marcadores de orden
	for m in g.markers:
		var k: float = float(m["a"]) / float(m["life"])
		var col: Color = m["col"]
		col.a = 1.0 - k
		c.draw_set_transform(m["p"], 0.0, Vector2(1.0, 0.6))
		c.draw_arc(Vector2.ZERO, 6.0 + 18.0 * k, 0.0, TAU, 20, col, 2.5)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Edificios seleccionados
	for id in g.sel:
		var e := g.sim.get_ent(id)
		if e != null and e.is_building:
			var r := e.rect().grow(2.0)
			var col := Color(0.2, 1.0, 0.3, 0.95) if e.owner == g.human else Color(1.0, 0.4, 0.3, 0.95)
			_corners(c, r, col)
			if e.owner == g.human and e.rally.x >= 0:
				var rp := sim.tile_center(e.rally)
				c.draw_line(e.center(), rp, Color(1, 1, 1, 0.35), 1.5)
				c.draw_line(rp, rp + Vector2(0, -22), Color(0.2, 0.15, 0.1), 2.0)
				c.draw_colored_polygon(PackedVector2Array([rp + Vector2(0, -22), rp + Vector2(14, -17), rp + Vector2(0, -12)]), Defs.PLAYER_COLORS[g.human])
	# Fantasma de construcción
	if g.placing_type != "" and g.place_tile.x >= 0:
		_draw_ghost(g, c)
	# Caja de selección
	if g.box_active:
		var a := g.screen_to_world(g.box_start)
		var b := g.screen_to_world(g.box_end)
		var rr := Rect2(a, b - a).abs()
		c.draw_rect(rr, Color(0.3, 1.0, 0.4, 0.15), true)
		c.draw_rect(rr, Color(0.3, 1.0, 0.4, 0.9), false, 2.0)

## Animales de caza: se dibujan con las celdas del atlas de recursos y pasean con una interpolación propia (no son entidades).
## Sólo se ven mientras la casilla está a la vista (como las unidades enemigas).
static func _draw_fauna(g: Game, c: CanvasItem, vr: Rect2) -> void:
	var sim := g.sim
	if sim.fauna.is_empty():
		return
	var tex := g.art.res_atlas
	var tnow := sim.time - Sim.DT + g.interp * Sim.DT
	for a: Dictionary in sim.fauna:
		var i: int = a["i"]
		var t := Vector2i(i % sim.W, i / sim.W)
		var dest := sim.tile_center(t)
		var p := dest
		var moving := false
		var t1: float = a["t1"]
		if tnow < t1:
			var t0: float = a["t0"]
			var k := clampf((tnow - t0) / maxf(t1 - t0, 0.01), 0.0, 1.0)
			p = (a["fx"] as Vector2).lerp(dest, k)
			moving = k < 1.0
		if not vr.has_point(p) or not g.fog.visible_at(t):
			continue
		var boar := sim.rtype[i] == Defs.R_BOAR
		var cell := (Art.RES_BOAR0 if boar else Art.RES_DEER0) + (int(tnow * 4.0) % 2 if moving else 0)
		var face: int = a["face"]
		var w := 64.0 * float(face)
		c.draw_texture_rect_region(tex, Rect2(p.x - w * 0.5, p.y - 38.0, w, 64.0), Rect2(cell * Art.RES_CELL, 0, Art.RES_CELL, Art.RES_CELL))

## Zonas de fuego (fuego griego): disco rojizo con llamas que parpadean; se apagan en el último segundo.
static func _draw_zones(g: Game, c: CanvasItem) -> void:
	var tt := g.anim_t
	for z: Dictionary in g.sim.zones:
		var p: Vector2 = z["p"]
		if int(z["owner"]) != g.human and not g.fog.visible_at(g.sim.tile_of(p)):
			continue
		var r: float = z["r"]
		var fade := clampf((float(z["until"]) - g.sim.time) / 1.2, 0.0, 1.0)
		c.draw_set_transform(p, 0.0, Vector2(1.0, 0.7))
		c.draw_circle(Vector2.ZERO, r, Color(0.85, 0.25, 0.05, 0.20 * fade))
		c.draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.55, 0.12, 0.75 * fade), 2.5)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 18:
			var ang := float(i) * 2.39996
			var rad := r * sqrt((float(i) + 0.5) / 18.0) * 0.92
			var b := p + Vector2(cos(ang) * rad, sin(ang) * rad * 0.7)
			var h := (13.0 + 9.0 * sin(tt * 9.0 + float(i) * 1.7)) * fade
			var sw := 3.5 * sin(tt * 7.0 + float(i))
			c.draw_colored_polygon(PackedVector2Array([b + Vector2(-5.5, 0), b + Vector2(5.5, 0), b + Vector2(sw, -h)]), Color(1.0, 0.42, 0.08, 0.85 * fade))
			c.draw_colored_polygon(PackedVector2Array([b + Vector2(-3.0, 0), b + Vector2(3.0, 0), b + Vector2(sw * 0.6, -h * 0.62)]), Color(1.0, 0.85, 0.30, 0.9 * fade))

static func _corners(c: CanvasItem, r: Rect2, col: Color) -> void:
	var l := 14.0
	var p := r.position
	var e := r.end
	for pair in [[p, Vector2(1, 0), Vector2(0, 1)], [Vector2(e.x, p.y), Vector2(-1, 0), Vector2(0, 1)], [Vector2(p.x, e.y), Vector2(1, 0), Vector2(0, -1)], [e, Vector2(-1, 0), Vector2(0, -1)]]:
		c.draw_line(pair[0], pair[0] + pair[1] * l, col, 3.0)
		c.draw_line(pair[0], pair[0] + pair[2] * l, col, 3.0)

static func _draw_farm(c: CanvasItem, r: Rect2, frac: float, mine: bool) -> void:
	c.draw_rect(r.grow(-1), Color(0.42, 0.28, 0.14), true)
	var crop := Color(0.45, 0.62, 0.2).lerp(Color(0.85, 0.72, 0.2), clampf(1.0 - frac, 0.0, 1.0) * 0.4)
	if frac < 0.25:
		crop = Color(0.55, 0.42, 0.2)
	for i in 4:
		var y := r.position.y + 5.0 + i * 7.0
		c.draw_line(Vector2(r.position.x + 4, y), Vector2(r.end.x - 4, y), crop, 3.5)
	c.draw_rect(r.grow(-1), Color(0.2, 0.12, 0.05), false, 1.5)

static func _unit_target_pos(g: Game, u: Ent) -> Vector2:
	if u.state == Sim.S_GATHER and u.target_tile.x >= 0:
		return g.sim.tile_center(u.target_tile)
	if u.state == Sim.S_ATTACK or u.state == Sim.S_BUILD:
		var t := g.sim.get_ent(u.target_id)
		if t != null:
			return t.center() if t.is_building else t.pos
	return Vector2.INF

const WS_FOOT := 0.62          # píxeles de mundo por píxel lógico de la hoja (gente, caballos, ariete)
const WS_SHIP := 0.58
const SHADOWS := {"jinete": Vector2(46, 13), "explorador": Vector2(44, 13), "caballero": Vector2(50, 14), "ariete": Vector2(60, 14), "arquero_caballo": Vector2(46, 13), "conquistador": Vector2(48, 13), "catafracta": Vector2(52, 14), "mameluco": Vector2(46, 13), "mangudai": Vector2(46, 13), "catapulta": Vector2(54, 14), "trabuquete": Vector2(60, 15)}
const SHIP_HALF := {"barco_pesca": 19.0, "barco_transporte": 24.0, "galera": 31.0, "galeon": 31.0}
const RANGED := ["arquero", "ballestero", "hostigador", "arquero_caballo", "conquistador", "hachero", "arquero_largo", "mangudai"]

static func ws_of(u: Ent) -> float:
	return WS_SHIP if u.naval else WS_FOOT

## Altura aproximada (px de mundo) por encima de los pies/flotación, para colocar barras de vida e iconos.
static func unit_top(u: Ent) -> float:
	return float(ArtUnits.CELLS[u.type][3]) * ws_of(u) * 0.86

static func _trade_of(g: Game, u: Ent) -> int:
	if u.target_tile.x >= 0:
		match g.sim.rtype[u.target_tile.y * g.sim.W + u.target_tile.x]:
			Defs.R_TREE:
				return ArtUnits.TRADE_CHOP
			Defs.R_GOLD, Defs.R_STONE:
				return ArtUnits.TRADE_MINE
			Defs.R_BERRY, Defs.R_FARM, Defs.R_DEER, Defs.R_BOAR:
				return ArtUnits.TRADE_FARM
	match u.carry_kind:
		"gold", "stone":
			return ArtUnits.TRADE_MINE
		"food":
			return ArtUnits.TRADE_FARM
	return ArtUnits.TRADE_CHOP

## Datos de dibujo de cada tipo de unidad. Se calculan una vez (las hojas se cargan la primera vez que hacen falta)
## para no repetir búsquedas en diccionarios ni recortes de hoja por cada unidad y fotograma.
class TInfo extends RefCounted:
	var sheet: Texture2D
	var ws := 1.0
	var naval := false
	var w := 0.0               # tamaño del rectángulo de destino (px de mundo)
	var h := 0.0
	var ax := 0.0              # ancla (pies o flotación) respecto a la esquina del rectángulo
	var ay := 0.0
	var nf := 1                # fotogramas por capa
	var rects: Array[Rect2] = []   # región de la hoja: capa * nf + fotograma
	var shadow := Vector2(22, 9)
	var top := 0.0
	var half := 0.0            # barcos: semilongitud
	var speed_k := 0.0         # ritmo de la animación de caminar
	var vill := false
	var fisher := false
	var military := false
	var ranged := false
	var carry_max := 10.0

static var _ti: Dictionary = {}
static var _ti_art: Art = null
static var _groups: Dictionary = {}    # tipo -> índices (Array: los vectores empaquetados se copian al sacarlos del diccionario)
const DRAW_ORDER := ["barco_pesca", "barco_transporte", "galera", "galeon", "aldeano", "piquero", "espadachin", "arquero", "ballestero",
		"jinete", "explorador", "caballero", "arquero_caballo", "alabardero", "hostigador", "monje", "ariete", "catapulta", "trabuquete",
		"hachero", "arquero_largo", "teutonico", "berserker", "conquistador", "catafracta", "mameluco", "mangudai"]
static var _types: Array = []          # DRAW_ORDER y, detrás, cualquier tipo nuevo de Defs.UNITS que no esté en la lista

static func _draw_types() -> Array:
	if _types.is_empty():
		_types = DRAW_ORDER.duplicate()
		for t in Defs.UNITS:
			if not _types.has(t):
				_types.append(t)
	return _types

static func _tinfo(g: Game, type: String) -> TInfo:
	if _ti_art != g.art:
		_ti.clear()
		_ti_art = g.art
	var ti: TInfo = _ti.get(type)
	if ti != null:
		return ti
	ti = TInfo.new()
	var def: Dictionary = Defs.UNITS[type]
	var cell: Array = ArtUnits.CELLS[type]
	var cp := ArtUnits.cell_px(type)
	var k: float = cell[4]
	ti.naval = bool(def.get("naval", false))
	ti.ws = WS_SHIP if ti.naval else WS_FOOT
	ti.sheet = g.art.sheet(type)
	ti.w = float(cp.x) / k * ti.ws
	ti.h = float(cp.y) / k * ti.ws
	ti.ax = float(cell[2]) * ti.ws
	ti.ay = float(cell[3]) * ti.ws
	ti.nf = int(cell[5])
	for layer in 3:
		for fr in ti.nf:
			ti.rects.append(Rect2(ArtUnits.frame_rect(type, fr, layer)))
	ti.shadow = SHADOWS.get(type, Vector2(22, 9))
	ti.top = float(cell[3]) * ti.ws * 0.86
	ti.half = float(SHIP_HALF.get(type, 0.0))
	ti.speed_k = float(def["speed"]) * 3.4
	ti.vill = type == "aldeano"
	ti.fisher = bool(def.get("fisher", false))
	ti.military = bool(def.get("military", false))
	ti.ranged = type in RANGED
	ti.carry_max = 10.0 if ti.vill else float(def.get("carry", 10.0))
	_ti[type] = ti
	return ti

## Fotograma de la hoja según lo que hace la unidad.
static func _unit_frame(g: Game, u: Ent, ti: TInfo, moving: bool) -> int:
	var t := g.anim_t + float(u.id) * 0.37
	if ti.naval:
		if moving:
			return int(t * 5.0) % 4
		if u.state == Sim.S_GATHER and ti.fisher:
			return 4 + int(t * 1.6) % 2
		if u.state == Sim.S_ATTACK and ti.military:
			return 4 + int(t * 2.2) % 2
		return int(t * 1.4) % 4
	if moving:
		return ArtUnits.F_WALK + int(t * ti.speed_k) % 4
	match u.state:
		Sim.S_GATHER:
			if ti.vill:
				return ArtUnits.F_ACT + 2 * _trade_of(g, u) + int(t * 2.6) % 2
		Sim.S_BUILD:
			if ti.vill:
				return ArtUnits.F_ACT + 2 * ArtUnits.TRADE_BUILD + int(t * 2.6) % 2
		Sim.S_ATTACK:
			if ti.vill:
				return ArtUnits.F_ACT + 2 * ArtUnits.TRADE_CHOP + int(t * 3.0) % 2
			var ph := fposmod(t * 1.7, 1.0)
			if ti.ranged:
				return 5 if ph < 0.25 else (7 if ph < 0.7 else 6)
			return 5 if ph < 0.6 else 6
	return ArtUnits.F_IDLE

## Todas las unidades visibles. Para gastar poco (menos llamadas de dibujo y menos GDScript por fotograma):
## una pasada calcula lo que hace falta de cada una; después se dibuja por capas y agrupando por tipo (todas las
## unidades de un tipo comparten hoja, así que el motor las manda a la GPU de golpe) en vez de unidad por unidad.
## Orden de pintado: anillos de selección, sombras, estela de barcos, figuras (por tipo), cargas y barras de vida.
static func _draw_units(g: Game, c: CanvasItem, vr: Rect2) -> void:
	var sim := g.sim
	var art := g.art
	var interp := g.interp
	var sel: Dictionary = g.sel_set
	var ul: Array[Ent] = []
	var tis: Array[TInfo] = []
	var pp := PackedVector2Array()
	var pf := PackedInt32Array()
	var pl := PackedFloat32Array()
	var pm := PackedByteArray()
	for k in _groups:
		(_groups[k] as Array).clear()
	for u in sim.units:
		if not u.alive or not vr.has_point(u.pos) or not g.can_see_unit(u):
			continue
		var type := u.type
		var ti := _tinfo(g, type)
		var p: Vector2 = u.ppos.lerp(u.pos, interp)
		# orientación: hacia donde anda o hacia lo que trabaja/ataca
		var moving := u.ppos.distance_to(u.pos) > 0.12
		if moving:
			if absf(u.pos.x - u.ppos.x) > 0.04:
				u.face = 1 if u.pos.x > u.ppos.x else -1
		elif u.state >= Sim.S_GATHER_GO:
			var tp := _unit_target_pos(g, u)
			if tp != Vector2.INF and absf(tp.x - p.x) > 3.0:
				u.face = 1 if tp.x > p.x else -1
		var fr := mini(_unit_frame(g, u, ti, moving), ti.nf - 1)
		var lunge := 0.0
		if u.state == Sim.S_ATTACK and not moving and not ti.naval and fr == 6:
			lunge = 3.0 * float(u.face)
		var idx := ul.size()
		ul.append(u)
		tis.append(ti)
		pp.append(p)
		pf.append(fr)
		pl.append(lunge)
		pm.append(1 if moving else 0)
		var grp: Array = _groups.get(type, [])
		if grp.is_empty() and not _groups.has(type):
			_groups[type] = grp
		grp.append(idx)
	if ul.is_empty():
		return
	# 1) anillos de selección (bajo todo): una textura por tamaño, así que se agrupan por tipo
	if not sel.is_empty():
		for type in _draw_types():
			var grp: Array = _groups.get(type, [])
			for i in grp:
				var u := ul[i]
				if sel.has(u.id):
					var ti := tis[i]
					var rr: float = u.radius + 5.0
					var ky := 0.55
					if ti.naval:
						rr = ti.half + 3.0
						ky = 0.30
					var rt := art.ring_tex(rr, ky)
					var tw := float(rt.get_width()) * 0.5
					var th := float(rt.get_height()) * 0.5
					c.draw_texture_rect(rt, Rect2(pp[i].x - tw * 0.5, pp[i].y + 3.0 - th * 0.5, tw, th), false)
	# 2) sombras (una sola textura) y espuma/estela de los barcos
	var sh := art.shadow_tex
	for i in ul.size():
		var ti := tis[i]
		if ti.naval:
			continue
		var p := pp[i]
		c.draw_texture_rect(sh, Rect2(p.x - ti.shadow.x * 0.5 + pl[i] * 0.5 + 1.5, p.y - ti.shadow.y * 0.1, ti.shadow.x, ti.shadow.y), false)
	for i in ul.size():
		if tis[i].naval:
			_draw_ship_water(c, ul[i], tis[i], pp[i], pm[i] == 1)
	# 3) figuras: 3 capas por unidad (fondo, equipo teñido, frente); todas las de un tipo seguidas
	var tm := art.team_mod
	for type in _draw_types():
		var grp: Array = _groups.get(type, [])
		if grp.is_empty():
			continue
		var ti: TInfo = _ti[type]
		var sheet := ti.sheet
		var rects := ti.rects
		var nf := ti.nf
		var w := ti.w
		var h := ti.h
		var ax := ti.ax
		var ay := ti.ay
		for i in grp:
			var u := ul[i]
			var p := pp[i]
			var fr := pf[i]
			var x := p.x + pl[i]
			var dst: Rect2
			if u.face >= 0:
				dst = Rect2(x - ax, p.y - ay, w, h)
			else:
				dst = Rect2(x + ax - w, p.y - ay, -w, h)      # ancho negativo = espejo horizontal
			c.draw_texture_rect_region(sheet, dst, rects[fr])
			c.draw_texture_rect_region(sheet, dst, rects[nf + fr], tm[u.owner % 4])
			c.draw_texture_rect_region(sheet, dst, rects[2 * nf + fr])
	# 4) iconos de carga (un único atlas) y barras de vida
	var catlas := art.carry_atlas
	var cs := float(art.carry_cell)
	for i in ul.size():
		var u := ul[i]
		var ti := tis[i]
		if u.carry_amt >= 1.0 and (ti.vill or ti.fisher):
			var p := pp[i]
			var co := Vector2(12, -ti.top * 0.8) if ti.vill else Vector2(0, -ti.top - 7.0)
			var fill := clampf(u.carry_amt / ti.carry_max, 0.0, 1.0)
			var hs := Art.CARRY_HALF * (0.8 + 0.4 * fill)
			var o := p + co
			var ci := 0 if u.carry_kind == "gold" else (1 if u.carry_kind == "food" else 2)
			c.draw_texture_rect_region(catlas, Rect2(o.x - hs, o.y - hs, hs * 2.0, hs * 2.0), Rect2(float(ci) * cs, 0.0, cs, cs))
	for i in ul.size():
		var u := ul[i]
		if u.hp < u.max_hp or sel.has(u.id):
			var ti := tis[i]
			var p := pp[i]
			var w := 24.0 if not ti.naval else 34.0
			var f := clampf(u.hp / u.max_hp, 0.0, 1.0)
			c.draw_rect(Rect2(p.x - w * 0.5 - 1, p.y - ti.top - 7, w + 2, 5), Color(0, 0, 0, 0.75), true)
			c.draw_rect(Rect2(p.x - w * 0.5, p.y - ti.top - 6, w * f, 3), Color(0.9 - 0.7 * f, 0.25 + 0.65 * f, 0.15), true)

## Espuma en la línea de flotación y estela cuando navega.
static func _draw_ship_water(c: CanvasItem, u: Ent, ti: TInfo, p: Vector2, moving: bool) -> void:
	var half := ti.half
	var fc := float(u.face)
	c.draw_set_transform(p + Vector2(0.0, 1.5), 0.0, Vector2(1.0, 0.26))
	c.draw_arc(Vector2.ZERO, half, 0.0, TAU, 26, Color(0.10, 0.25, 0.42, 0.28), 5.0)
	c.draw_arc(Vector2.ZERO, half - 1.0, 0.0, TAU, 26, Color(1.0, 1.0, 1.0, 0.48), 1.8)
	if moving:
		for i in 3:
			c.draw_set_transform(p + Vector2(-fc * (half + 5.0 + i * 9.0), 2.0), 0.0, Vector2(1.0, 0.28))
			c.draw_arc(Vector2.ZERO, 5.0 + i * 3.0, 0.0, TAU, 14, Color(1.0, 1.0, 1.0, 0.38 - i * 0.11), 1.6)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

const DIRS8 := [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]

static func _wall_link(g: Game, b: Ent, d: Vector2i) -> bool:
	var t := b.tile + d
	if not g.sim.in_bounds(t):
		return false
	var o: Ent = g.sim.get_ent(g.sim.occ[t.y * g.sim.W + t.x])
	if o == null or not o.def.get("wall", false):
		return false
	if d.x != 0 and d.y != 0:
		# diagonal: sólo se une si las dos casillas contiguas no son muralla (evita barras dobles)
		return o.owner == b.owner
	return o.owner == b.owner

static func _draw_wall(g: Game, c: CanvasItem, b: Ent) -> void:
	var m := b.rect().get_center()
	var team: Color = Defs.PLAYER_COLORS[b.owner % 4]
	var done := b.progress >= 1.0
	var a := 1.0 if done else 0.42 + 0.4 * b.progress
	var stone := Color(0.70, 0.68, 0.63, a)
	var stone_d := Color(0.45, 0.43, 0.40, a)
	var outline := Color(0.14, 0.12, 0.10, a)
	var is_gate: bool = b.def.get("gate", false)
	var links: Array[Vector2i] = []
	for d in DIRS8:
		if _wall_link(g, b, d):
			links.append(d)
	var horiz := true
	if is_gate:
		var hz := false
		var vt := false
		for d in links:
			if d.y == 0:
				hz = true
			if d.x == 0:
				vt = true
		horiz = hz or not vt
	var rot := 0.0 if (not is_gate or horiz) else PI * 0.5
	c.draw_set_transform(m, 0.0, Vector2.ONE)
	for d in links:
		if is_gate and ((horiz and d.y != 0) or ((not horiz) and d.x != 0)):
			continue
		var tip := Vector2(d) * 16.0
		c.draw_line(Vector2(0, 5), tip + Vector2(0, 5), outline, 13.0)
		c.draw_line(Vector2(0, 4), tip + Vector2(0, 4), stone_d, 10.0)
		c.draw_line(Vector2(0, -2), tip + Vector2(0, -2), outline, 13.0)
		c.draw_line(Vector2(0, -2), tip + Vector2(0, -2), stone, 10.0)
		c.draw_line(Vector2(0, -5), tip + Vector2(0, -5), Color(0.86, 0.84, 0.78, a), 2.5)
	if not is_gate:
		c.draw_rect(Rect2(-9, -9, 18, 20), outline, true)
		c.draw_rect(Rect2(-8, -8, 16, 18), stone_d, true)
		c.draw_rect(Rect2(-8, -8, 16, 11), stone, true)
		for i in 3:
			c.draw_rect(Rect2(-8 + i * 6, -12, 4, 5), stone, true)
			c.draw_rect(Rect2(-8 + i * 6, -12, 4, 5), outline, false, 1.0)
		c.draw_rect(Rect2(-2, -6, 4, 4), Color(team.r, team.g, team.b, a), true)
	else:
		c.draw_set_transform(m, rot, Vector2.ONE)
		# jambas de piedra a los lados y puerta de madera entre ellas
		for sx in [-1.0, 1.0]:
			c.draw_rect(Rect2(sx * 11.0 - 5.0, -12, 10, 24), outline, true)
			c.draw_rect(Rect2(sx * 11.0 - 4.0, -11, 8, 22), stone_d, true)
			c.draw_rect(Rect2(sx * 11.0 - 4.0, -11, 8, 13), stone, true)
			c.draw_rect(Rect2(sx * 11.0 - 4.0, -15, 8, 5), stone, true)
			c.draw_rect(Rect2(sx * 11.0 - 4.0, -15, 8, 5), outline, false, 1.0)
		var wood := Color(0.45, 0.28, 0.12, a)
		c.draw_rect(Rect2(-7, -9, 14, 21), outline, true)
		c.draw_rect(Rect2(-6, -8, 12, 19), wood, true)
		for i in range(1, 4):
			c.draw_line(Vector2(-6 + i * 3.0, -8), Vector2(-6 + i * 3.0, 11), Color(0.28, 0.16, 0.06, a), 1.0)
		c.draw_line(Vector2(-6, -2), Vector2(6, -2), Color(0.25, 0.25, 0.28, a), 2.0)
		c.draw_line(Vector2(-6, 6), Vector2(6, 6), Color(0.25, 0.25, 0.28, a), 2.0)
		c.draw_rect(Rect2(-2, -17, 4, 4), Color(team.r, team.g, team.b, a), true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if (b.hp < b.max_hp * 0.995 and done) or g.sel_set.has(b.id):
		var f := clampf(b.hp / b.max_hp, 0.0, 1.0)
		var r := b.rect()
		c.draw_rect(Rect2(r.position.x + 2, r.position.y - 9, 28, 5), Color(0, 0, 0, 0.75), true)
		c.draw_rect(Rect2(r.position.x + 3, r.position.y - 8, 26 * f, 3), Color(0.9 - 0.7 * f, 0.25 + 0.65 * f, 0.15), true)

const SMOKE := {"casa": Vector2(0.34, 0.09), "centro": Vector2(0.755, 0.27), "cuartel": Vector2(0.67, 0.20)}
# ventanas (x, y, ancho, alto) en píxeles del sprite lógico, para el brillo nocturno
const WINDOWS := {
	"casa": [[14, 41, 6, 6], [40, 41, 6, 6]],
	"centro": [[18, 68, 8, 8], [66, 68, 8, 8]],
	"cuartel": [[16, 70, 8, 8], [60, 70, 8, 8]],
	"puerto": [[16, 64, 6, 6], [64, 64, 6, 6]],
}

static func _draw_smoke(g: Game, b: Ent, r: Rect2) -> void:
	var f: Vector2 = SMOKE[b.type]
	var base := r.position + Vector2(r.size.x * f.x, r.size.y * f.y)
	for k in 3:
		var ph := fposmod(g.anim_t * 0.30 + float(k) / 3.0 + float(b.id) * 0.137, 1.0)
		var p := base + Vector2(ph * 10.0 + sin(ph * 6.0 + float(b.id)) * 2.0, -ph * 32.0)
		var a := 0.42 * (1.0 - ph) * minf(1.0, ph * 6.0)
		_smoke.append(p.x)
		_smoke.append(p.y)
		_smoke.append(2.2 + ph * 6.5)
		_smoke.append(a)

static func _draw_night_lights(g: Game, c: CanvasItem, b: Ent, r: Rect2) -> void:
	var sc := r.size.x / (96.0 if b.size == 3 else 64.0)
	for w: Array in WINDOWS[b.type]:
		var wr := Rect2(r.position + Vector2(float(w[0]), float(w[1])) * sc, Vector2(float(w[2]), float(w[3])) * sc)
		var gr := wr.size.x * 1.6
		c.draw_texture_rect(g.art.puff_tex, Rect2(wr.get_center() - Vector2(gr, gr), Vector2(gr, gr) * 2.0), false, Color(1.0, 0.78, 0.38, 0.10 * g.night))
		c.draw_rect(wr, Color(1.0, 0.84, 0.45, 0.88 * g.night), true)
		c.draw_rect(Rect2(wr.position.x + wr.size.x * 0.5 - 0.5, wr.position.y, 1.0, wr.size.y), Color(0.35, 0.22, 0.08, 0.7 * g.night), true)
		c.draw_rect(Rect2(wr.position.x, wr.position.y + wr.size.y * 0.5 - 0.5, wr.size.x, 1.0), Color(0.35, 0.22, 0.08, 0.7 * g.night), true)

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
	c.draw_colored_polygon(PackedVector2Array([p0 - side * (hw + 1.5), p1 - side * (hw + 1.5), p1 + side * (hw + 1.5), p0 + side * (hw + 1.5)]), dark)
	c.draw_colored_polygon(PackedVector2Array([p0 - side * hw, p1 - side * hw, p1 + side * hw, p0 + side * hw]), wood)
	var n := 8
	for i in range(1, n):
		var q := p0.lerp(p1, float(i) / float(n))
		c.draw_line(q - side * hw, q + side * hw, Color(dark.r, dark.g, dark.b, 0.7 * a), 1.0)
	c.draw_line(p0 - side * hw, p1 - side * hw, Color(0.80, 0.62, 0.36, a), 1.5)
	for sgn in [-1.0, 1.0]:
		for t in [0.35, 1.0]:
			var pp: Vector2 = p0.lerp(p1, float(t)) + side * hw * float(sgn)
			c.draw_circle(pp, 2.4, dark)
			c.draw_circle(pp - Vector2(0.5, 0.5), 1.5, Color(0.52, 0.36, 0.20, a))

static func _draw_building(g: Game, c: CanvasItem, b: Ent) -> void:
	if b.def.get("wall", false):
		_draw_wall(g, c, b)
		return
	if b.def.get("dock", false):
		_draw_pier(c, b)
	var tex: Texture2D = g.art.building_tex[b.type][b.owner % 4]
	var r := b.rect()
	if b.progress >= 1.0:
		c.draw_texture_rect(tex, r, false)
	else:
		c.draw_texture_rect(tex, r, false, Color(0.55, 0.65, 0.8, 0.35))
		var px: float = tex.get_height()
		var cut := px * (1.0 - b.progress)
		var dst := Rect2(r.position.x, r.position.y + r.size.y * (1.0 - b.progress), r.size.x, r.size.y * b.progress)
		var src := Rect2(0, cut, tex.get_width(), px - cut)
		c.draw_texture_rect_region(tex, dst, src)
		# andamio
		var col := Color(0.55, 0.4, 0.2, 0.9)
		c.draw_line(r.position + Vector2(4, r.size.y - 2), r.position + Vector2(4, 6), col, 2.0)
		c.draw_line(r.position + Vector2(r.size.x - 4, r.size.y - 2), r.position + Vector2(r.size.x - 4, 6), col, 2.0)
		for i in range(1, 4):
			var yy := r.position.y + r.size.y * i / 4.0
			c.draw_line(Vector2(r.position.x + 4, yy), Vector2(r.end.x - 4, yy), col, 1.5)
	if b.progress >= 1.0:
		if SMOKE.has(b.type):
			_draw_smoke(g, b, r)
		if g.night > 0.12 and WINDOWS.has(b.type):
			_draw_night_lights(g, c, b, r)
	var show_bar := b.hp < b.max_hp or g.sel_set.has(b.id) or b.progress < 1.0
	if show_bar:
		var w := r.size.x * 0.8
		var f := clampf(b.hp / b.max_hp, 0.0, 1.0)
		var y := r.position.y - 8.0
		c.draw_rect(Rect2(r.position.x + (r.size.x - w) * 0.5 - 1, y - 1, w + 2, 7), Color(0, 0, 0, 0.75), true)
		c.draw_rect(Rect2(r.position.x + (r.size.x - w) * 0.5, y, w * f, 5), Color(0.9 - 0.7 * f, 0.25 + 0.65 * f, 0.15), true)
		if b.progress < 1.0:
			c.draw_rect(Rect2(r.position.x + (r.size.x - w) * 0.5, y + 7, w * b.progress, 3), Color(0.4, 0.7, 1.0), true)

static func _draw_ghost(g: Game, c: CanvasItem) -> void:
	var type := g.placing_type
	if type == "muralla":
		var tiles: Array = g.wall_tiles if not g.wall_tiles.is_empty() else [g.place_tile]
		for t: Vector2i in tiles:
			var okw := g.sim.can_place(type, t, g.human)
			var r := Rect2(Vector2(t) * T, Vector2(T, T))
			var colw := Color(0.55, 0.9, 0.5, 0.55) if okw else Color(1.0, 0.2, 0.2, 0.5)
			c.draw_rect(r.grow(-3), colw, true)
			c.draw_rect(r.grow(-3), Color(colw.r, colw.g, colw.b, 0.95), false, 2.0)
		return
	var ok := g.sim.can_place(type, g.place_tile, g.human)
	var col := Color(0.2, 1.0, 0.3, 0.35) if ok else Color(1.0, 0.2, 0.2, 0.4)
	if Defs.is_plot(type):
		var r := Rect2(Vector2(g.place_tile) * T, Vector2(T, T))
		if type == "arbol":
			# retoño en transparencia sobre la casilla (el dibujo del atlas es de 64 px centrado en ella)
			var cell := float(Art.RES_CELL)
			c.draw_texture_rect_region(g.art.res_atlas, Rect2(r.position + Vector2(T, T) * 0.5 - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), Rect2(float(Art.RES_SAPLING) * cell, 0.0, cell, cell), Color(1, 1, 1, 0.8))
		c.draw_rect(r, col, true)
		c.draw_rect(r, Color(col.r, col.g, col.b, 0.95), false, 2.0)
		return
	var size: int = Defs.BUILDINGS[type]["size"]
	var r := Rect2(Vector2(g.place_tile) * T, Vector2(size, size) * T)
	c.draw_texture_rect(g.art.building_tex[type][g.human % 4], r, false, Color(1, 1, 1, 0.55))
	c.draw_rect(r, col, true)
	c.draw_rect(r, Color(col.r, col.g, col.b, 0.95), false, 2.5)

static func _draw_fx(c: CanvasItem, f: Dictionary) -> void:
	var k: float = float(f["a"]) / float(f["life"])
	match f["t"]:
		"arrow":
			var from: Vector2 = f["p"]
			var to: Vector2 = f["q"]
			var pos := from.lerp(to, minf(1.0, k * 1.3))
			var dir := (to - from).normalized()
			c.draw_line(pos - dir * 12.0, pos, Color(0.95, 0.9, 0.7, 0.95), 2.0)
			c.draw_line(pos, pos - dir * 3.0 + dir.orthogonal() * 3.0, Color(0.95, 0.9, 0.7, 0.95), 1.5)
		"hit":
			var p: Vector2 = f["p"]
			var rr: float = 4.0 + 8.0 * k
			c.draw_circle(p, rr, Color(1.0, 0.85, 0.3, 0.8 * (1.0 - k)))
			c.draw_arc(p, rr + 3.0, 0.0, TAU, 12, Color(1, 1, 1, 0.8 * (1.0 - k)), 1.5)
		"puff":
			var p: Vector2 = f["p"]
			var rad: float = float(f["r"]) * (0.5 + k)
			c.draw_circle(p, rad, Color(0.55, 0.5, 0.45, 0.55 * (1.0 - k)))
			c.draw_circle(p + Vector2(-rad * 0.5, -rad * 0.3), rad * 0.7, Color(0.7, 0.66, 0.6, 0.4 * (1.0 - k)))
			c.draw_circle(p + Vector2(rad * 0.5, -rad * 0.2), rad * 0.6, Color(0.7, 0.66, 0.6, 0.4 * (1.0 - k)))
		"cannon":
			var p: Vector2 = f["p"]
			var q: Vector2 = f["q"]
			# fogonazo y humo en la boca; la bala cruza el aire rápido
			c.draw_circle(p, 9.0 * (1.0 - k) + 2.0, Color(1.0, 0.82, 0.30, 0.9 * (1.0 - k)))
			c.draw_circle(p + Vector2(7.0 * k, -6.0 * k), 6.0 + 12.0 * k, Color(0.78, 0.78, 0.80, 0.55 * (1.0 - k)))
			c.draw_circle(p + Vector2(14.0 * k, -12.0 * k), 5.0 + 9.0 * k, Color(0.70, 0.70, 0.72, 0.4 * (1.0 - k)))
			var bp := p.lerp(q, minf(1.0, k * 1.9))
			if k < 0.53:
				c.draw_circle(bp, 3.0, Color(0.08, 0.07, 0.07, 0.95))
				c.draw_line(bp, bp - (q - p).normalized() * 14.0, Color(0.9, 0.9, 0.9, 0.5), 2.0)
		"rock":
			var p: Vector2 = f["p"]
			var q: Vector2 = f["q"]
			# la piedra sube en arco y cae; al caer levanta una nube de polvo
			var kk := minf(1.0, k * 1.25)
			var bp := p.lerp(q, kk) + Vector2(0, -sin(kk * PI) * 46.0)
			if kk < 1.0:
				c.draw_circle(bp, 3.6, Color(0.30, 0.28, 0.26, 0.95))
				c.draw_circle(bp + Vector2(-1.0, -1.0), 1.6, Color(0.55, 0.52, 0.48, 0.9))
			else:
				var j := (k - 0.8) / 0.2
				c.draw_circle(q, 6.0 + 14.0 * j, Color(0.62, 0.56, 0.48, 0.55 * (1.0 - j)))
				c.draw_arc(q, 8.0 + 16.0 * j, 0.0, TAU, 16, Color(1, 1, 1, 0.5 * (1.0 - j)), 1.5)
		"heal":
			var p: Vector2 = f["p"]
			var q := p + Vector2(0, -16.0 * k)
			var a := 1.0 - k
			c.draw_rect(Rect2(q + Vector2(-1.4, -4.5), Vector2(2.8, 9.0)), Color(0.3, 1.0, 0.45, a))
			c.draw_rect(Rect2(q + Vector2(-4.5, -1.4), Vector2(9.0, 2.8)), Color(0.3, 1.0, 0.45, a))
		"flash":
			var p: Vector2 = f["p"]
			c.draw_arc(p, 10.0 + 22.0 * k, 0.0, TAU, 24, Color(1, 1, 1, 0.8 * (1.0 - k)), 3.0)
		"text":
			var tp: Vector2 = f["p"]
			var tcol: Color = f["col"]
			var fnt := ThemeDB.fallback_font
			var fa := 1.0 - maxf(0.0, (k - 0.6) / 0.4)
			var q := tp + Vector2(0, -34.0 * k)
			c.draw_string(fnt, q + Vector2(-17, 2), str(f["s"]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 22, Color(0, 0, 0, 0.8 * fa))
			c.draw_string(fnt, q + Vector2(-18, 0), str(f["s"]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 22, Color(tcol.r, tcol.g, tcol.b, fa))
		"ping":
			var p: Vector2 = f["p"]
			c.draw_arc(p, 10.0 + 70.0 * k, 0.0, TAU, 32, Color(1, 0.2, 0.2, 0.9 * (1.0 - k)), 4.0)
