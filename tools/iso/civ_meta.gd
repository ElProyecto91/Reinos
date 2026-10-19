extends SceneTree
## Genera los datos que el juego necesita de cada civilización además de sus sprites: art/iso/civ_<id>_meta.json
## con los puntos de humo de cada edificio (marcadores «smoke» puestos con IsoArch.smoke_src en los modelos), ya convertidos a
## píxeles de pantalla respecto al centro de la huella: ((x − z)·32, (x + z)·16 − y·39,2), como en la proyección del juego.
## Uso: godot --headless --path . --script res://tools/iso/civ_meta.gd [-- civ=castellanos,francos]
## Es rápido (no renderiza): hay que lanzarlo cada vez que se cambien chimeneas o aberturas de humo de una civilización.

const MAX_PER_BUILDING := 2

func _initialize() -> void:
	var want := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("civ="):
			want = a.substr(4).split(",")
	var ids: Array = IsoCivs.available()
	for id in ids:
		var civ: String = id
		if not want.is_empty() and not want.has(civ):
			continue
		var mod := IsoCivs.module(civ)
		var smoke := {}
		for t in IsoCivs.TYPES:
			var type: String = t
			if type == "puerto":
				continue
			var root: Node3D = mod.build(type, IsoModels.TEAM_BASE)
			var pts: Array = []
			_collect(root, Transform3D.IDENTITY, pts)
			root.queue_free()
			if pts.is_empty():
				continue
			var out: Array = []
			for p: Vector3 in pts:
				if out.size() >= MAX_PER_BUILDING:
					break
				out.append([snappedf((p.x - p.z) * 32.0, 0.1), snappedf((p.x + p.z) * 16.0 - p.y * 39.2, 0.1)])
			smoke[type] = out
		var path := "res://art/iso/civ_%s_meta.json" % civ
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"smoke": smoke}))
		f.close()
		print("meta ", civ, ": humo en ", smoke.keys())
	quit()

## Recorre el árbol acumulando transformaciones y recoge la posición (respecto a la raíz) de los nodos llamados «smoke».
func _collect(n: Node, xf: Transform3D, out: Array) -> void:
	for c in n.get_children():
		if c is Node3D:
			var t := xf * (c as Node3D).transform
			if String(c.name).begins_with("smoke"):
				out.append(t.origin)
			_collect(c, t, out)
