class_name IsoCatalog
extends RefCounted
## Catálogo de lo que se hornea: grupos (los elige `only=` en iso_bake) con su lienzo [ancho, alto, origen x, origen y]
## y la lista de trabajos [nombre, constructor, giro (grados), sombra horneada, máscara de equipo].
## Nombres sin equipo: el color del jugador se aplica en el juego con la máscara (`<nombre>_m`).

const DEFAULT_CFG := [1152, 1024, 448, 720]
const SMALL_CFG := [400, 480, 200, 400]
const SIEGE_CFG := [680, 600, 340, 470]
const SHIP_CFG := [720, 620, 360, 440]
const RIDER_CFG := [920, 780, 460, 620]
const POLE_CFG := [800, 600, 400, 480]
const WALL_CFG := [760, 640, 220, 440]     # sombra a la derecha y abajo (la de la puerta se recortaba con 700×520)
const CASTLE_CFG := [1900, 1500, 640, 880]

static func groups() -> Dictionary:
	var g: Dictionary = {}
	var T := IsoModels.TEAM_BASE
	var tj: Array = []
	for v in 4:
		var vv := v
		tj.append(["roble_%d" % v, func() -> Node3D: return IsoModels.roble(vv), 0.0, true, false])
	g["roble"] = _g(DEFAULT_CFG, tj)
	var pj: Array = []
	for v in 2:
		var vv := v
		pj.append(["pino_%d" % v, func() -> Node3D: return IsoModels.pino(vv), 0.0, true, false])
	pj.append(["pino_2", func() -> Node3D: return IsoNature.pino_alto(), 0.0, true, false])
	g["pino"] = _g(DEFAULT_CFG, pj)
	var oj: Array = []
	for v in 3:
		var vv := v
		oj.append(["otono_%d" % v, func() -> Node3D: return IsoNature.otono(vv), 0.0, true, false])
	g["otono"] = _g(DEFAULT_CFG, oj)
	g["palmera"] = _g(DEFAULT_CFG, [
		["palma_0", func() -> Node3D: return IsoNature.palma(0), 0.0, true, false],
		["palma_1", func() -> Node3D: return IsoNature.palma(1), 0.0, true, false]])
	g["seco"] = _g(DEFAULT_CFG, [
		["seco_0", func() -> Node3D: return IsoNature.seco(0), 0.0, true, false],
		["seco_1", func() -> Node3D: return IsoNature.seco(1), 0.0, true, false]])
	g["nieve"] = _g(DEFAULT_CFG, [
		["nieve_0", func() -> Node3D: return IsoNature.nieve(0), 0.0, true, false],
		["nieve_1", func() -> Node3D: return IsoNature.nieve(1), 0.0, true, false]])
	var mj: Array = []
	for v in 4:
		var vv := v
		mj.append(["montana_%d" % v, func() -> Node3D: return IsoNature.montana(vv, false), 0.0, true, false])
	for v in 2:
		var vv2 := v
		mj.append(["montana_n%d" % v, func() -> Node3D: return IsoNature.montana(vv2 + 4, true), 0.0, true, false])
	for v in 3:
		var vv3 := v
		mj.append(["montana_l%d" % v, func() -> Node3D: return IsoNature.loma(vv3), 0.0, true, false])
	g["montana"] = _g(DEFAULT_CFG, mj)
	g["brote"] = _g(SMALL_CFG, [["retono_0", func() -> Node3D: return IsoNature.retono(), 0.0, true, false]])
	g["baya"] = _g(SMALL_CFG, [["bayas_0", func() -> Node3D: return IsoNature.bayas(), 0.0, true, false]])
	g["roca"] = _g(DEFAULT_CFG, [
		["roca_0", func() -> Node3D: return IsoModels.roca(0, false), 0.0, true, false],
		["oro_0", func() -> Node3D: return IsoModels.roca(1, true), 0.0, true, false]])
	# edificios por civilización (IsoCivs): un grupo por civilización y lienzo; la mina (sólo en obra) es común a todas
	g["mina"] = _g(DEFAULT_CFG, [["mina", func() -> Node3D: return IsoBuild.mina(T), 0.0, true, true]])
	for civ in IsoCivs.available():
		var cj: Dictionary = IsoCivs.jobs(civ)
		g["civ_" + civ] = _g(DEFAULT_CFG, cj["edificios"])
		g["civ_" + civ + "_castillo"] = _g(CASTLE_CFG, cj["castillo"])
		g["civ_" + civ + "_muralla"] = _g(WALL_CFG, cj["muralla"])
	# infantería, aldeano y monje (IsoPeople): 5 direcciones horneadas (d = 1..5; las demás son espejos), yaw = 90° − 45°·d
	for kind in ["aldeano", "piquero", "espadachin", "alabardero", "teutonico", "berserker", "arquero", "arquero_largo", "ballestero", "hostigador", "hachero", "monje"]:
		var kk: String = kind
		var cfgp: Array = POLE_CFG if kk in ["piquero", "alabardero", "teutonico", "hostigador", "hachero", "monje"] else SMALL_CFG
		g[kk] = _g(cfgp, _people_jobs(kk, [1, 2, 3, 4, 5], IsoPeople.frames_of(kk)))
		g["pv_" + kk] = _g(cfgp, _people_jobs(kk, [1, 3], _preview_frames(kk)))
	# máquinas de asedio, barcos y animales (IsoMachines)
	for kind in ["ariete", "catapulta", "trabuquete", "ciervo", "jabali", "barco_pesca", "barco_transporte", "galera", "galeon"]:
		var km: String = kind
		var cfgm: Array = SMALL_CFG if km in ["ciervo", "jabali"] else (SHIP_CFG if km.begins_with("barco") or km in ["galera", "galeon"] else SIEGE_CFG)
		g[km] = _g(cfgm, _machine_jobs(km, [1, 2, 3, 4, 5], IsoMachines.frames_of(km)))
		g["pv_" + km] = _g(cfgm, _machine_jobs(km, [1, 3], _pick(IsoMachines.frames_of(km), ["idle", "w1", "a0", "a1"])))
	# caballería (IsoRiders)
	for kind in ["jinete", "explorador", "caballero", "arquero_caballo", "conquistador", "catafracta", "mameluco", "mangudai"]:
		var kk2: String = kind
		g[kk2] = _g(RIDER_CFG, _people_jobs(kk2, [1, 2, 3, 4, 5], IsoRiders.frames_of(kk2), true))
		g["pv_" + kk2] = _g(RIDER_CFG, _people_jobs(kk2, [1, 3], _preview_frames(kk2, true), true))
	return g

static func yaw_of(d: int) -> float:
	return float(posmod(90 - 45 * d, 360))

static func _people_jobs(kind: String, dirs: Array, frames: Array, mounted: bool = false) -> Array:
	var jobs: Array = []
	for d in dirs:
		for fr in frames:
			var dd: int = d
			var ff: String = fr
			var kk := kind
			if mounted:
				jobs.append(["%s_%d_%s" % [kk, dd, ff], func() -> Node3D: return IsoRiders.mounted(kk, IsoModels.TEAM_BASE, ff), yaw_of(dd), false, true])
			else:
				jobs.append(["%s_%d_%s" % [kk, dd, ff], func() -> Node3D: return IsoPeople.human(kk, IsoModels.TEAM_BASE, ff), yaw_of(dd), false, true])
	return jobs

static func _pick(all: Array, want: Array) -> Array:
	var out: Array = []
	for f in all:
		if f in want:
			out.append(f)
	return out

static func _machine_jobs(kind: String, dirs: Array, frames: Array) -> Array:
	var jobs: Array = []
	for d in dirs:
		for fr in frames:
			var dd: int = d
			var ff: String = fr
			var kk := kind
			jobs.append(["%s_%d_%s" % [kk, dd, ff], func() -> Node3D: return IsoMachines.build(kk, IsoModels.TEAM_BASE, ff), yaw_of(dd), false, true])
	return jobs

static func _preview_frames(kind: String, mounted: bool = false) -> Array:
	var all := IsoRiders.frames_of(kind) if mounted else IsoPeople.frames_of(kind)
	var pick: Array = []
	for f in all:
		if f in ["idle", "w1", "w3", "a0", "a1", "a2", "t00", "t01", "t10", "t11", "t20", "t21", "t30", "t31"]:
			pick.append(f)
	return pick

static func _g(cfg: Array, jobs: Array) -> Dictionary:
	return {"cfg": cfg, "jobs": jobs}
