class_name IsoView
extends Node2D
## Entidades del mundo como sprites isométricos (recursos, edificios, unidades, fauna), ordenados por profundidad (y del pie).
## Este nodo es el contenedor ordenado por y; las sombras son hijos con z_index fijo (por debajo de todo sprite), de modo que
## se mueven con su dueño sin trabajo de script. Lo que va pegado al suelo (granjas, anillos) y los efectos se dibujan en
## las capas de `WorldLayer` (ver Renderer).
##
## Dirección de las unidades: 8 direcciones lógicas d = ángulo/45° (0 = +x lógico, 1 = +x+y …). Sólo se hornean 5
## (1..5); las otras tres son espejos horizontales (ver MIRROR).

const T := Defs.TILE
const S := IsoArt.SPRITE_SCALE
const Z_SHADOW := -10

# fotogramas de unidad (índices en la tabla de nombres)
const F_IDLE := 0
const F_WALK := 1              # 1..4
const F_ACT := 5               # acciones (aldeano: 5 + 2·oficio + fase; soldados: 5 preparar, 6 golpe, 7 apuntar)
const NF := 13
const TRADE_CHOP := 0
const TRADE_MINE := 1
const TRADE_FARM := 2
const TRADE_BUILD := 3

## dirección horneada que se usa (y si va espejada) para cada una de las 8
const MIRROR := [[2, true], [1, false], [2, false], [3, false], [4, false], [5, false], [4, true], [3, true]]

const RANGED := ["arquero", "ballestero", "hostigador", "arquero_caballo", "conquistador", "hachero", "arquero_largo", "mangudai"]
const SHADOWS := {"jinete": Vector2(46, 17), "explorador": Vector2(44, 17), "caballero": Vector2(50, 18), "ariete": Vector2(60, 18),
		"arquero_caballo": Vector2(46, 17), "conquistador": Vector2(48, 17), "catafracta": Vector2(52, 18), "mameluco": Vector2(46, 17),
		"mangudai": Vector2(46, 17), "catapulta": Vector2(54, 18), "trabuquete": Vector2(60, 19)}
## Altura del cuerpo (px de pantalla a zoom 1) cuando el sprite lleva algo mucho más alto (pica, lanza, mástil): barras de vida, iconos y toque
const TOPS := {"piquero": 48.0, "alabardero": 48.0, "monje": 48.0, "teutonico": 54.0, "hostigador": 50.0, "jinete": 64.0, "explorador": 60.0,
		"caballero": 68.0, "arquero_caballo": 62.0, "conquistador": 66.0, "mameluco": 64.0, "mangudai": 56.0, "catafracta": 70.0,
		"ariete": 58.0, "catapulta": 50.0, "trabuquete": 62.0, "barco_pesca": 40.0, "barco_transporte": 50.0, "galera": 44.0, "galeon": 58.0}
const SHIP_HALF := {"barco_pesca": 19.0, "barco_transporte": 24.0, "galera": 31.0, "galeon": 31.0}

## sprites de recursos que pueden faltar mientras no estén hechos: nombre -> sustituto
const FALLBACK := {"nieve_0": "pino_0", "nieve_1": "pino_1", "pino_2": "pino_1", "otono_0": "roble_2", "otono_1": "roble_3",
		"palma_0": "roble_5", "seco_0": "roble_6", "bayas_0": "roca_0", "retono_0": "pino_0", "mina_0": "oro_0"}

var game: Game
var sim: Sim
var art: Art
var ia: IsoArt

var _res: Dictionary = {}          # casilla -> Sprite2D (árbol, mina, bayas…)
var _mnt: Dictionary = {}          # casilla de montaña -> Sprite2D (picos de roca; el suelo de roca lo pinta el shader del terreno)
var fish: Dictionary = {}          # casillas con peces (se dibujan como rizos en las marcas del suelo)
var _bld: Dictionary = {}          # id de edificio -> BNode
var _uns: Dictionary = {}          # id de unidad -> UNode
var _fau: Dictionary = {}          # uid de animal -> UNode
var _fau_uid := 1
var _stamp := 0
var _ti: Dictionary = {}           # tipo de unidad -> TInfo
var _bdim: Dictionary = {}         # tipo de edificio -> Rect2 (sprite relativo al centro de la huella, plano iso)
var _ghost: Sprite2D
var _ghost_name := ""
var _wall_t := 0.0

class BNode extends RefCounted:
	var sp: Sprite2D
	var sh: Sprite2D
	var rev: Sprite2D                 # parte ya construida (revelado de abajo arriba)
	var arms: Array = []              # muralla: Sprite2D de los brazos (índice de dirección)
	var kind := 0                     # 0 normal, 1 muralla, 2 puerta
	var name := ""
	var prog := -1.0
	var stamp := 0
	var owner := -1
	var vis := true

class UNode extends RefCounted:
	var sp: Sprite2D
	var sh: Sprite2D
	var key := -1                     # (dirección, fotograma, equipo) ya puesto
	var stamp := 0
	var vis := false

class TInfo extends RefCounted:
	var names: Array = []             # [dirección horneada 0..7][fotograma] -> nombre de sprite ("" si falta)
	var naval := false
	var vill := false
	var fisher := false
	var military := false
	var ranged := false
	var siege := false
	var speed_k := 0.0
	var carry_max := 10.0
	var top := 40.0                   # altura del sprite en px de pantalla (zoom 1): barras de vida e iconos
	var half_w := 12.0
	var shadow := Vector2(24, 9)
	var half := 0.0
	var has_any := false

func build() -> void:
	sim = game.sim
	art = game.art
	ia = art.iso
	y_sort_enabled = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ghost = Sprite2D.new()
	_ghost.centered = false
	_ghost.visible = false
	_ghost.z_index = 20
	_ghost.z_as_relative = false
	add_child(_ghost)
	var W := sim.W
	for idx in W * sim.H:
		var rt := sim.rtype[idx]
		if rt == 0:
			continue
		if rt == Defs.R_FARM:
			game.farm_tiles[idx] = true
			continue
		if rt == Defs.R_FISH:
			fish[idx] = true
			continue
		_res_set(idx)
	_build_mountains()

# ------------------------------------------------------------------ recursos

## Picos de roca sobre las casillas de montaña (el suelo de roca va debajo, lo pinta el shader del terreno).
## Los picos grandes van en una retícula de 2×2 casillas con desplazamiento; los bordes sueltos llevan lomas bajas.
func _build_mountains() -> void:
	if not ia.has("montana_0"):
		return
	var W := sim.W
	var H := sim.H
	for y in H:
		for x in W:
			var idx := y * W + x
			if sim.terrain[idx] != Defs.T_ROCK:
				continue
			var h := _hash(x, y)
			var edge := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= W or ny >= H or sim.terrain[ny * W + nx] != Defs.T_ROCK:
						edge = true
			var heat := float(sim.heat[idx]) / 255.0
			var nm := ""
			var sc := 1.0
			if (x + (y >> 1)) % 2 == 0 and y % 2 == 0 and not (edge and (h >> 5) % 4 == 0):
				nm = ("montana_n%d" % ((h >> 9) % 2)) if heat < 0.40 else ("montana_%d" % ((h >> 9) % 4))
				sc = (1.15 if edge else 1.45) + 0.30 * float((h >> 14) % 100) / 100.0
			elif edge and (h >> 5) % 3 == 0:
				nm = "montana_l%d" % ((h >> 9) % 3)
				sc = 1.0 + 0.25 * float((h >> 14) % 100) / 100.0
			if nm == "" or not ia.has(nm):
				continue
			var jit := Vector2(float((h >> 3) % 13) - 6.0, float((h >> 17) % 13) - 6.0)
			var sp := ia.make_sprite(nm, Iso.proj(sim.tile_center(Vector2i(x, y)) + jit), sc, ((h >> 20) & 1) == 1)
			add_child(sp)
			_add_shadow(sp, nm + "_sh")
			sp.visible = game.fog != null and game.fog.explored_at(Vector2i(x, y))
			_mnt[idx] = sp

func _hash(x: int, y: int) -> int:
	return ((x * 73856093) ^ (y * 19349663)) & 0x7fffffff

## Nombre del sprite de un recurso según el tipo y el clima de la casilla.
func res_name(rt: int, x: int, y: int) -> String:
	var h := _hash(x, y)
	match rt:
		Defs.R_TREE:
			var heat := float(sim.heat[y * sim.W + x]) / 255.0
			var k := (h >> 4) % 100
			var j := (h >> 11) % 100
			if heat < 0.28:
				return ("nieve_0" if j < 55 else "nieve_1") if k < 72 else "pino_1"
			elif heat < 0.42:
				if k < 52:
					return "pino_0" if j < 34 else ("pino_1" if j < 67 else "pino_2")
				return "roble_%d" % (j % 4)
			elif heat < 0.66:
				if k < 62:
					return "roble_%d" % (j % 4)
				if k < 85:
					return "pino_0" if j < 34 else ("pino_1" if j < 67 else "pino_2")
				return ("otono_0" if j < 34 else ("otono_1" if j < 67 else "otono_2")) if k < 92 else "pino_1"
			return ("palma_0" if j < 50 else "palma_1") if k < 52 else (("seco_0" if j < 50 else "seco_1") if k < 88 else "roble_1")
		Defs.R_GOLD:
			return "oro_0"
		Defs.R_STONE:
			return "roca_0"
		Defs.R_BERRY:
			return "bayas_0"
		Defs.R_SAPLING:
			return "retono_0"
	return ""

func _resolve(name: String) -> String:
	if name == "" or ia.has(name):
		return name
	var f: String = FALLBACK.get(name, "")
	return f if f != "" and ia.has(f) else ""

func _res_set(idx: int) -> void:
	var old: Sprite2D = _res.get(idx)
	if old != null:
		old.queue_free()
		_res.erase(idx)
	var rt := sim.rtype[idx]
	if rt == 0 or rt == Defs.R_FARM or rt == Defs.R_FISH or Defs.is_animal(rt):
		return
	var x := idx % sim.W
	var y := idx / sim.W
	var nm := _resolve(res_name(rt, x, y))
	if nm == "":
		return
	var h := _hash(x, y)
	var jit := Vector2(float((h >> 3) % 13) - 6.0, float((h >> 9) % 13) - 6.0) if rt == Defs.R_TREE else Vector2.ZERO
	var sc := 1.0
	if rt == Defs.R_TREE:
		sc = 0.92 + 0.16 * float((h >> 14) % 100) / 100.0
	var p := Iso.proj(sim.tile_center(Vector2i(x, y)) + jit)
	var sp := ia.make_sprite(nm, p, sc, ((h >> 20) & 1) == 1 and rt == Defs.R_TREE)
	add_child(sp)
	_add_shadow(sp, nm + "_sh")
	sp.visible = game.fog != null and game.fog.explored_at(Vector2i(x, y))
	sp.set_meta("n", nm)
	_res[idx] = sp

## Nombre del sprite de recurso dibujado en una casilla ("" si no hay): para pruebas y depuración.
func res_name_at(t: Vector2i) -> String:
	var sp: Sprite2D = _res.get(t.y * sim.W + t.x)
	return String(sp.get_meta("n", "")) if sp != null else ""

## Hijo sombra (sprite horneado `<nombre>_sh`, mismo ancla): z fijo por debajo de los sprites
func _add_shadow(parent: Sprite2D, shname: String) -> Sprite2D:
	if not ia.has(shname):
		return null
	var sh := Sprite2D.new()
	sh.centered = false
	sh.z_index = Z_SHADOW
	sh.z_as_relative = false
	sh.texture = ia.tex(shname)
	sh.offset = -ia.anchors[shname]
	parent.add_child(sh)
	return sh

func res_changed(t: Vector2i) -> void:
	var idx := t.y * sim.W + t.x
	if sim.rtype[idx] != Defs.R_FISH:
		fish.erase(idx)
	_res_set(idx)

## El juego avisa de las casillas recién exploradas: los recursos de casillas sin explorar no se dibujan.
func on_fog() -> void:
	for idx in game.fog.take_new():
		var sp: Sprite2D = _res.get(idx)
		if sp != null:
			sp.visible = true
		var mp: Sprite2D = _mnt.get(idx)
		if mp != null:
			mp.visible = true

func refresh_explored() -> void:
	game.fog.take_new()
	for idx in _res:
		(_res[idx] as Sprite2D).visible = game.fog.explored_at(Vector2i(idx % sim.W, idx / sim.W))
	for idx in _mnt:
		(_mnt[idx] as Sprite2D).visible = game.fog.explored_at(Vector2i(idx % sim.W, idx / sim.W))

# ------------------------------------------------------------------ información de dibujo de las unidades

func tinfo(type: String) -> TInfo:
	var ti: TInfo = _ti.get(type)
	if ti != null:
		return ti
	ti = TInfo.new()
	var def: Dictionary = Defs.UNITS[type]
	ti.naval = bool(def.get("naval", false))
	ti.vill = type == "aldeano"
	ti.fisher = bool(def.get("fisher", false))
	ti.military = bool(def.get("military", false))
	ti.ranged = type in RANGED
	ti.siege = bool(def.get("siege", false))
	ti.speed_k = float(def["speed"]) * 2.2
	ti.carry_max = 10.0 if ti.vill else float(def.get("carry", 10.0))
	ti.shadow = SHADOWS.get(type, Vector2(24, 9))
	ti.half = float(SHIP_HALF.get(type, 0.0))
	_fill_names(ti, type)
	# altura y anchura a partir del reposo de cara a la cámara
	var idle: String = ti.names[1][F_IDLE]
	if idle != "":
		var r: Rect2 = ia.rects[idle][1]
		ti.top = minf(r.size.y * S, float(TOPS.get(type, 1000.0)))
		ti.half_w = r.size.x * S * 0.5
		ti.has_any = true
	_ti[type] = ti
	return ti

func _fill_names(ti: TInfo, type: String) -> void:
	for d in 8:
		var row: Array = []
		for f in NF:
			var nm := _frame_name(type, d, f)
			row.append(nm if ia.has(nm) else "")
		ti.names.append(row)

static func _frame_name(type: String, d: int, f: int) -> String:
	if f == F_IDLE:
		return "%s_%d_idle" % [type, d]
	if f < F_ACT:
		return "%s_%d_w%d" % [type, d, f - F_WALK]
	if type == "aldeano":
		return "%s_%d_t%d%d" % [type, d, (f - F_ACT) / 2, (f - F_ACT) % 2]
	return "%s_%d_a%d" % [type, d, f - F_ACT]

static func dir_of(dx: float, dy: float) -> int:
	return posmod(roundi(atan2(dy, dx) / (PI * 0.25)), 8)

## Altura (px de pantalla) de la unidad, para barras de vida e iconos
func unit_top(u: Ent) -> float:
	return tinfo(u.type).top

# ------------------------------------------------------------------ actualización por fotograma

func update(delta: float) -> void:
	_stamp += 1
	_update_units()
	_update_buildings(delta)
	_update_fauna()
	_update_ghost()
	if _stamp % 30 == 0:
		_sweep()

func _unit_target_pos(u: Ent) -> Vector2:
	if u.state == Sim.S_GATHER and u.target_tile.x >= 0:
		return sim.tile_center(u.target_tile)
	if u.state == Sim.S_ATTACK or u.state == Sim.S_BUILD:
		var t := sim.get_ent(u.target_id)
		if t != null:
			return t.center() if t.is_building else t.pos
	return Vector2.INF

func _trade_of(u: Ent) -> int:
	if u.target_tile.x >= 0:
		match sim.rtype[u.target_tile.y * sim.W + u.target_tile.x]:
			Defs.R_TREE:
				return TRADE_CHOP
			Defs.R_GOLD, Defs.R_STONE:
				return TRADE_MINE
			Defs.R_BERRY, Defs.R_FARM, Defs.R_DEER, Defs.R_BOAR:
				return TRADE_FARM
	match u.carry_kind:
		"gold", "stone":
			return TRADE_MINE
		"food":
			return TRADE_FARM
	return TRADE_CHOP

func _unit_frame(u: Ent, ti: TInfo, moving: bool) -> int:
	var t := game.anim_t + float(u.id) * 0.37
	if ti.naval:
		return F_IDLE
	if moving:
		return F_WALK + int(t * ti.speed_k) % 4
	match u.state:
		Sim.S_GATHER:
			if ti.vill:
				return F_ACT + 2 * _trade_of(u) + int(t * 2.6) % 2
		Sim.S_BUILD:
			if ti.vill:
				return F_ACT + 2 * TRADE_BUILD + int(t * 2.6) % 2
		Sim.S_ATTACK:
			if ti.vill:
				return F_ACT + 2 * TRADE_CHOP + int(t * 3.0) % 2
			var ph := fposmod(t * 1.7, 1.0)
			if ti.ranged:
				return F_ACT if ph < 0.25 else (F_ACT + 2 if ph < 0.7 else F_ACT + 1)
			return F_ACT if ph < 0.6 else F_ACT + 1
	return F_IDLE

func _new_unit_node(ti: TInfo) -> UNode:
	var n := UNode.new()
	var sp := Sprite2D.new()
	sp.centered = false
	sp.visible = false
	add_child(sp)
	n.sp = sp
	var sh := Sprite2D.new()
	sh.texture = art.shadow_tex
	sh.z_index = Z_SHADOW
	sh.z_as_relative = false
	sh.scale = Vector2(ti.shadow.x / 32.0, ti.shadow.y / 32.0) / S
	sh.position = Vector2(0, -2.0) / S
	sp.add_child(sh)
	n.sh = sh
	if ti.naval:
		sh.visible = false
	return n

func _set_frame(n: UNode, ti: TInfo, d: int, f: int, owner: int) -> void:
	var m: Array = MIRROR[d]
	var row: Array = ti.names[m[0]]
	var nm: String = row[f]
	if nm == "":
		nm = row[F_IDLE if f < F_WALK or f >= F_ACT else F_WALK]
		if nm == "":
			nm = row[F_IDLE]
	if nm == "":
		return
	var key := (d * 16 + f) * 64 + owner
	if key == n.key:
		return
	n.key = key
	ia.set_frame(n.sp, nm, 1.0, bool(m[1]))
	n.sp.modulate = art.team_mod[owner % 4]

func _update_units() -> void:
	var interp := game.interp
	var vi := game.view_iso(90.0)
	var st := _stamp
	for u in sim.units:
		if not u.alive:
			continue
		var n: UNode = _uns.get(u.id)
		var p: Vector2 = u.ppos.lerp(u.pos, interp)
		var ip := Iso.proj(p)
		if not game.can_see_unit(u) or not vi.has_point(ip):
			if n != null:
				n.stamp = st
				if n.vis:
					n.sp.visible = false
					n.vis = false
			continue
		var ti := tinfo(u.type)
		if not ti.has_any:
			continue
		if n == null:
			n = _new_unit_node(ti)
			_uns[u.id] = n
		n.stamp = st
		# orientación: hacia donde anda o hacia lo que trabaja/ataca
		var moving := u.ppos.distance_to(u.pos) > 0.12
		if moving:
			var dd := u.pos - u.ppos
			var nd := dir_of(dd.x, dd.y)
			if nd != u.d8:
				var diff := absf(wrapf(atan2(dd.y, dd.x) - float(u.d8) * PI * 0.25, -PI, PI))
				if diff > PI * 0.25 + 0.12:
					u.d8 = nd
		elif u.state >= Sim.S_GATHER_GO:
			var tp := _unit_target_pos(u)
			if tp != Vector2.INF and tp.distance_to(p) > 3.0:
				u.d8 = dir_of(tp.x - p.x, tp.y - p.y)
		_set_frame(n, ti, u.d8, _unit_frame(u, ti, moving), u.owner)
		var pos := ip
		if ti.naval:
			pos.y += sin((game.anim_t + float(u.id)) * 1.8) * 0.8
		n.sp.position = pos
		if not n.vis:
			n.sp.visible = true
			n.vis = true

func _sweep() -> void:
	var st := _stamp - 1
	for k in _uns.keys():
		var n: UNode = _uns[k]
		if n.stamp < st:
			n.sp.queue_free()
			_uns.erase(k)
	for k in _bld.keys():
		var b: BNode = _bld[k]
		if b.stamp < st:
			b.sp.queue_free()
			_bld.erase(k)
	for k in _fau.keys():
		var n2: UNode = _fau[k]
		if n2.stamp < st:
			n2.sp.queue_free()
			_fau.erase(k)

# ------------------------------------------------------------------ edificios

## Sprite principal de un tipo de edificio (con el sustituto provisional si aún no hay arte)
func building_sprite(type: String, orient: int = 2) -> String:
	var nm := type
	if type == "puerto":
		nm = "puerto_%d" % orient
	if ia.has(nm):
		return nm
	var sz: int = int(Defs.BUILDINGS[type]["size"])
	for alt in (["casa", "centro"] if sz <= 2 else ["centro", "castillo"]):
		if ia.has(alt):
			return alt
	return ""

## Rectángulo del sprite del edificio respecto al centro de su huella (plano isométrico): para tocar y para barras
func building_dims(type: String) -> Rect2:
	var r: Rect2 = _bdim.get(type, Rect2())
	if r.size == Vector2.ZERO:
		var nm := building_sprite(type)
		if nm == "":
			return Rect2(-32, -64, 64, 64)
		var rr: Rect2 = ia.rects[nm][1]
		var an: Vector2 = ia.anchors[nm]
		r = Rect2(-an * S, rr.size * S)
		_bdim[type] = r
	return r

func _wall_link(b: Ent, d: Vector2i) -> bool:
	var t := b.tile + d
	if not sim.in_bounds(t):
		return false
	var o: Ent = sim.get_ent(sim.occ[t.y * sim.W + t.x])
	if o == null or not o.def.get("wall", false):
		return false
	return o.owner == b.owner

func _new_building_node(b: Ent) -> BNode:
	var n := BNode.new()
	var c := Iso.proj(b.center())
	if b.def.get("wall", false):
		n.kind = 2 if b.def.get("gate", false) else 1
		n.name = "muralla_poste" if n.kind == 1 else "puerta_x"
		n.arms.resize(8)
	else:
		n.name = building_sprite(b.type, b.orient)
	if n.name == "" or not ia.has(n.name):
		return null
	var sp := ia.make_sprite(n.name, c)
	add_child(sp)
	n.sp = sp
	n.sh = _add_shadow(sp, n.name + "_sh")
	return n

func _update_buildings(delta: float) -> void:
	var st := _stamp
	_wall_t -= delta
	var relink := false
	if _wall_t <= 0.0:
		_wall_t = 0.5
		relink = true
	for b in sim.buildings:
		if not b.alive:
			continue
		var n: BNode = _bld.get(b.id)
		var vis := game.can_see_building(b)
		if n == null:
			if not vis:
				continue
			n = _new_building_node(b)
			if n == null:
				continue
			_bld[b.id] = n
			relink = true
		n.stamp = st
		if vis != n.vis:
			n.vis = vis
			n.sp.visible = vis
		if not vis:
			continue
		if n.owner != b.owner:
			n.owner = b.owner
			n.sp.modulate = art.team_mod[b.owner % 4]
			n.prog = -1.0
		var done := b.progress >= 1.0
		if n.kind != 0:
			_update_wall(b, n, done, relink)
			continue
		if done:
			if n.prog != 1.0:
				n.prog = 1.0
				n.sp.modulate = art.team_mod[b.owner % 4]
				if n.rev != null:
					n.rev.queue_free()
					n.rev = null
		else:
			_update_scaffold(b, n)

## Obra en marcha: el sprite entero se ve tenue y la parte construida (de abajo arriba) opaca
func _update_scaffold(b: Ent, n: BNode) -> void:
	var prog := snappedf(b.progress, 0.01)
	if prog == n.prog:
		return
	n.prog = prog
	var tm: Color = art.team_mod[b.owner % 4]
	n.sp.modulate = Color(tm.r * 0.6, tm.g * 0.7, tm.b * 0.9, 0.35)
	if n.rev == null:
		n.rev = Sprite2D.new()
		n.rev.centered = false
		n.rev.region_enabled = true
		n.rev.material = ia.mat_of(n.name)
		n.rev.texture = ia.tex(n.name)
		n.sp.add_child(n.rev)
	var r: Rect2 = ia.rects[n.name][1]
	var an: Vector2 = ia.anchors[n.name]
	var cut := r.size.y * (1.0 - prog)
	n.rev.region_rect = Rect2(0.0, cut, r.size.x, r.size.y - cut)
	n.rev.offset = -an + Vector2(0.0, cut)
	n.rev.modulate = tm

func _update_wall(b: Ent, n: BNode, done: bool, relink: bool) -> void:
	var a := 1.0 if done else 0.42 + 0.4 * b.progress
	if absf(n.prog - a) > 0.01:
		n.prog = a
		var tm: Color = art.team_mod[b.owner % 4]
		n.sp.modulate = Color(tm.r, tm.g, tm.b, a)
		for arm: Variant in n.arms:
			if arm != null:
				(arm as Sprite2D).modulate = Color(1, 1, 1, a)
	if not relink:
		return
	var is_gate := n.kind == 2
	var links: Array[bool] = []
	for d in 8:
		links.append(_wall_link(b, Iso.DIRS8[d]))
	var horiz := true
	if is_gate:
		var hz := links[2] or links[6]
		var vt := links[0] or links[4]
		horiz = hz or not vt
		var nm := "puerta_x" if horiz else "puerta_z"
		if nm != n.name and ia.has(nm):
			n.name = nm
			ia.set_frame(n.sp, nm)
			if n.sh != null:
				n.sh.queue_free()
			n.sh = _add_shadow(n.sp, nm + "_sh")
	for d in 8:
		var want := links[d]
		if want and is_gate:
			var v: Vector2i = Iso.DIRS8[d]
			if (horiz and v.y != 0) or ((not horiz) and v.x != 0):
				want = false
		var arm: Sprite2D = n.arms[d]
		if want and arm == null:
			var an := "muralla_a%d" % d
			if ia.has(an):
				arm = Sprite2D.new()
				arm.centered = false
				ia.set_frame(arm, an)
				arm.scale = Vector2.ONE            # hijo del poste: hereda su escala
				arm.modulate = Color(1, 1, 1, maxf(n.prog, 0.3))
				n.sp.add_child(arm)
				_add_shadow(arm, an + "_sh")
				n.arms[d] = arm
		elif (not want) and arm != null:
			arm.queue_free()
			n.arms[d] = null

# ------------------------------------------------------------------ fauna

func _update_fauna() -> void:
	if sim.fauna.is_empty():
		return
	var tnow := sim.time - Sim.DT + game.interp * Sim.DT
	var vi := game.view_iso(90.0)
	var st := _stamp
	for a: Dictionary in sim.fauna:
		var i: int = a["i"]
		var t := Vector2i(i % sim.W, i / sim.W)
		var dest := sim.tile_center(t)
		var p := dest
		var moving := false
		var from := dest
		var t1: float = a["t1"]
		if tnow < t1:
			var t0: float = a["t0"]
			var k := clampf((tnow - t0) / maxf(t1 - t0, 0.01), 0.0, 1.0)
			from = a["fx"]
			p = from.lerp(dest, k)
			moving = k < 1.0
		var uid: int = a.get("uid", 0)
		if uid == 0:
			uid = _fau_uid
			_fau_uid += 1
			a["uid"] = uid
		var n: UNode = _fau.get(uid)
		var ip := Iso.proj(p)
		if not game.fog.visible_at(t) or not vi.has_point(ip):
			if n != null:
				n.stamp = st
				if n.vis:
					n.sp.visible = false
					n.vis = false
			continue
		var type := "jabali" if sim.rtype[i] == Defs.R_BOAR else "ciervo"
		var ti := tinfo_animal(type)
		if not ti.has_any:
			continue
		if n == null:
			n = _new_unit_node(ti)
			_fau[uid] = n
		n.stamp = st
		if moving:
			var dd := dest - from
			a["d8"] = dir_of(dd.x, dd.y)
		var f := (F_WALK + int(tnow * 4.0) % 4) if moving else F_IDLE
		_set_frame(n, ti, int(a.get("d8", 1)), f, 0)
		n.sp.modulate = Color.WHITE
		n.sp.position = ip
		if not n.vis:
			n.sp.visible = true
			n.vis = true

func tinfo_animal(type: String) -> TInfo:
	var ti: TInfo = _ti.get(type)
	if ti != null:
		return ti
	ti = TInfo.new()
	ti.shadow = Vector2(26, 10)
	_fill_names(ti, type)
	ti.has_any = ti.names[1][F_IDLE] != ""
	_ti[type] = ti
	return ti

# ------------------------------------------------------------------ fantasma de construcción

func _update_ghost() -> void:
	var g := game
	var type := g.placing_type
	if type == "" or Defs.is_plot(type) or type == "muralla" or g.place_tile.x < 0:
		_ghost.visible = false
		return
	var nm := building_sprite(type, 2)
	if nm == "":
		_ghost.visible = false
		return
	var size: int = int(Defs.BUILDINGS[type]["size"])
	var c := Iso.proj((Vector2(g.place_tile) + Vector2(size, size) * 0.5) * T)
	if nm != _ghost_name:
		_ghost_name = nm
		ia.set_frame(_ghost, nm)
	_ghost.position = c
	var ok := sim.can_place(type, g.place_tile, g.human)
	_ghost.modulate = Color(0.7, 1.0, 0.7, 0.62) if ok else Color(1.0, 0.45, 0.45, 0.62)
	_ghost.visible = true

# ------------------------------------------------------------------ toques

## Unidad bajo un punto del plano isométrico (o null). Se acierta sobre el cuerpo del sprite.
func pick_unit(ip: Vector2) -> Ent:
	var best: Ent = null
	var bd := 1e9
	var gp := Iso.unproj(ip + Vector2(0, 14.0))
	for u in sim.query(gp, 70.0):
		if u.is_building or not game.can_see_unit(u):
			continue
		var ti := tinfo(u.type)
		var up := Iso.proj(u.pos)
		var top := ti.top if ti.has_any else 36.0
		var hw := ti.half_w + 6.0
		if ti.naval:
			hw = ti.half + 8.0
		var hh := top * 0.5 + 6.0
		var dx := absf(ip.x - up.x)
		var dy := absf(ip.y - (up.y - top * 0.5))
		if dx > hw or dy > hh:
			continue
		var d := Vector2(dx / hw, dy / hh).length()
		if d < bd:
			bd = d
			best = u
	return best

## Edificio bajo un punto del plano isométrico: su huella o su sprite
func pick_building(ip: Vector2) -> Ent:
	var best: Ent = null
	var bk := -1e9
	var gp := Iso.unproj(ip)
	for b in sim.buildings:
		if not b.alive or not game.can_see_building(b):
			continue
		var hit := b.rect().grow(4.0).has_point(gp)
		if not hit and not b.def.get("wall", false):
			# píxeles del sprite (con un margen de unas celdas para el dedo); los edificios de delante tapan a los de detrás
			var nm := building_sprite(b.type, b.orient)
			if nm != "":
				var c := Iso.proj(b.center())
				hit = ia.hit_test(nm, (ip - c) / S + ia.anchors[nm], 2)
		if hit:
			var key := b.center().x + b.center().y
			if key > bk:
				bk = key
				best = b
	return best
