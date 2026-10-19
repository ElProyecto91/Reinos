extends SceneTree
## Comprueba los módulos de arquitectura de las civilizaciones: que cada tipo de edificio se construye con geometría, que la planta cabe
## en su huella (avisa si algo sobresale más de la cuenta) y que las murallas existen (poste, 8 brazos, 2 puertas).
## Uso: godot --headless --path . --script res://tools/iso/civ_check.gd [-- civ=a,b | file=res://tools/iso/civ/_plantilla.gd]
## Sale con código 1 si algo falla. No renderiza: tarda segundos.

const FOOT := {"casa": 2, "almacen": 2, "torre": 2, "centro": 3, "cuartel": 3, "arqueria": 3, "establo": 3, "taller": 3, "puerto": 3,
	"monasterio": 3, "herreria": 3, "mercado": 3, "castillo": 4}
const MARGIN := 0.60        # lo que puede sobresalir de la huella (patios, aleros, banderas) antes de avisar
var fails := 0
var warns := 0

func _initialize() -> void:
	var want := PackedStringArray()
	var file := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("civ="):
			want = a.substr(4).split(",")
		elif a.begins_with("file="):
			file = a.substr(5)
	var mods := {}
	if file != "":
		mods[file.get_file().get_basename()] = (load(file) as GDScript).new()
	else:
		for id in IsoCivs.available():
			if want.is_empty() or want.has(id):
				mods[id] = IsoCivs.module(id)
	for id in mods:
		var mod: Object = mods[id]
		var n_ok := 0
		for t in IsoCivs.TYPES:
			var type: String = t
			if not mod.has_method(type):
				_fail(id, type, "falta la función " + type)
				continue
			var root: Node3D = mod.build(type, IsoModels.TEAM_BASE)
			if root == null:
				_fail(id, type, "build devolvió null")
				continue
			var bb := _bounds(root, Transform3D.IDENTITY)
			if bb.size == Vector3.ZERO:
				_fail(id, type, "sin geometría")
			else:
				var half := float(FOOT[type]) * 0.5 + MARGIN
				if type != "puerto" and (bb.position.x < -half or bb.end.x > half or bb.position.z < -half or bb.end.z > half):
					warns += 1
					print("AVISO ", id, "/", type, ": sobresale de la huella (x ", snappedf(bb.position.x, 0.01), "…", snappedf(bb.end.x, 0.01),
						", z ", snappedf(bb.position.z, 0.01), "…", snappedf(bb.end.z, 0.01), ", máx ±", half, ")")
				if bb.end.y > 5.5:
					warns += 1
					print("AVISO ", id, "/", type, ": muy alto (", snappedf(bb.end.y, 0.01), ")")
				n_ok += 1
			root.queue_free()
		for what in ["wall_post", "wall_arm", "gate"]:
			if not mod.has_method(what):
				_fail(id, what, "falta la función")
		if mod.has_method("wall_post"):
			var p: Node3D = mod.wall_post()
			if _bounds(p, Transform3D.IDENTITY).size == Vector3.ZERO:
				_fail(id, "wall_post", "sin geometría")
			p.queue_free()
			for d in 8:
				var arm: Node3D = mod.wall_arm(d)
				if _bounds(arm, Transform3D.IDENTITY).size == Vector3.ZERO:
					_fail(id, "wall_arm", "brazo %d sin geometría" % d)
				arm.queue_free()
			for ax in [true, false]:
				var g: Node3D = mod.gate(ax)
				if _bounds(g, Transform3D.IDENTITY).size == Vector3.ZERO:
					_fail(id, "gate", "puerta sin geometría")
				g.queue_free()
		print("civ_check ", id, ": ", n_ok, "/", IsoCivs.TYPES.size(), " edificios correctos")
	print("civ_check: ", fails, " fallos, ", warns, " avisos")
	quit(1 if fails > 0 else 0)

func _fail(id: String, what: String, why: String) -> void:
	fails += 1
	print("FALLO ", id, "/", what, ": ", why)

## Caja que envuelve toda la geometría de un árbol de nodos (en el sistema de la raíz).
func _bounds(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var t := xf * (n as MeshInstance3D).transform
		box = t * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c in n.get_children():
		if c is Node3D:
			var cb := _bounds(c, xf * (n as Node3D).transform if n is Node3D else xf)
			if cb.size != Vector3.ZERO:
				box = cb if first else box.merge(cb)
				first = false
	return box
