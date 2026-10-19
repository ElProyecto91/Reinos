extends Node
## Pre-renderiza modelos 3D (IsoModels) a PNG con fondo transparente, en la proyección isométrica de AoE:
## cámara ortográfica a 45° de giro y 30° de elevación (la casilla sale como un rombo 2:1), luz arriba a la izquierda.
## Escala de horneado: SCALE px por unidad de mundo (4 veces la final; tools/iso/iso_post.py baja a la mitad y recorta).
## Uso: xvfb-run -a godot --path . res://tools/iso/iso_bake.tscn --rendering-driver opengl3 --resolution 800x600 -- out=/tmp/iso_raw only=casa,centro
const SCALE := 181.0            # px por unidad de mundo en el horneado (rombo de casilla = 256 px de ancho)
const VP_W := 896
const VP_H := 1024
const ORIGIN := Vector2(448, 720)   # píxel donde cae el origen (centro de la huella, a nivel del suelo)
var vp: SubViewport
var holder: Node3D
var out_dir := "/tmp/iso_raw"
var only := PackedStringArray()

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out_dir = a.substr(4)
		elif a.begins_with("only="): only = a.substr(5).split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_log("ready")
	_setup()
	_log("setup ok")
	await _run()
	get_tree().quit()

func _setup() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(VP_W, VP_H)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.68, 0.84)
	env.ambient_light_energy = 0.62
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(VP_H) / SCALE
	cam.near = 0.1
	cam.far = 80.0
	vp.add_child(cam)
	var el := deg_to_rad(30.0)
	var look := Vector3(cos(el) * 0.70710678, sin(el), cos(el) * 0.70710678)
	cam.position = look * 30.0
	cam.look_at(Vector3.ZERO, Vector3.UP)
	# el origen cae en ORIGIN en vez de en el centro del encuadre
	cam.v_offset = (ORIGIN.y - float(VP_H) * 0.5) / SCALE
	cam.h_offset = (ORIGIN.x - float(VP_W) * 0.5) / SCALE
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 14.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	vp.add_child(sun)
	sun.look_at_from_position(Vector3(-3.0, 7.0, 4.0), Vector3.ZERO, Vector3.UP)
	holder = Node3D.new()
	vp.add_child(holder)

func _log(t: String) -> void:
	var f := FileAccess.open("/tmp/iso_log.txt", FileAccess.READ_WRITE if FileAccess.file_exists("/tmp/iso_log.txt") else FileAccess.WRITE)
	f.seek_end()
	f.store_line("%d %s" % [Time.get_ticks_msec(), t])

func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout

func _shot(model: Node3D, yaw: float, name: String) -> void:
	_log("shot " + name + " start")
	holder.add_child(model)
	model.rotation_degrees.y = yaw
	await _frames()
	_log("frames ok")
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	model.queue_free()
	await get_tree().process_frame

func _want(n: String) -> bool:
	return only.is_empty() or only.has(n)

func _run() -> void:
	var blue := Color(0.20, 0.42, 0.88)
	var red := Color(0.80, 0.18, 0.16)
	if _want("casa"):
		await _shot(IsoModels.casa(blue), 0.0, "casa_blue")
		await _shot(IsoModels.casa(red), 0.0, "casa_red")
	if _want("centro"):
		await _shot(IsoModels.centro(blue), 0.0, "centro_blue")
	if _want("torre"):
		await _shot(IsoModels.torre(blue), 0.0, "torre_blue")
	if _want("roble"):
		for v in 4:
			await _shot(IsoModels.roble(v), 0.0, "roble_%d" % v)
	if _want("pino"):
		for v in 2:
			await _shot(IsoModels.pino(v), 0.0, "pino_%d" % v)
	if _want("roca"):
		await _shot(IsoModels.roca(0, false), 0.0, "roca_0")
		await _shot(IsoModels.roca(1, true), 0.0, "oro_0")
	for kind in ["aldeano", "espadachin"]:
		if not _want(kind):
			continue
		for d in 8:
			await _shot(IsoModels.persona(kind, blue, -1.0), float(d) * 45.0, "%s_blue_%d_idle" % [kind, d])
			for f in 4:
				await _shot(IsoModels.persona(kind, blue, float(f) * 0.25), float(d) * 45.0, "%s_blue_%d_w%d" % [kind, d, f])
		await _shot(IsoModels.persona(kind, red, -1.0), 0.0, "%s_red_0_idle" % kind)
	print("INFO horneado en ", out_dir)
