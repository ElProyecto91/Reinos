extends Node
## Pre-renderiza modelos 3D (IsoModels) a PNG con fondo transparente, en la proyección isométrica de AoE:
## cámara ortográfica a 45° de giro y 30° de elevación (la casilla sale como un rombo 2:1), luz arriba a la izquierda.
## Escala de horneado: SCALE px por unidad de mundo (4 veces la final; tools/iso/iso_post.py baja a la mitad y recorta).
## Uso: xvfb-run -a godot --path . res://tools/iso/iso_bake.tscn --rendering-driver opengl3 --resolution 800x600 -- out=/tmp/iso_raw only=casa,centro
const SCALE := 181.0            # px por unidad de mundo en el horneado (rombo de casilla = 256 px de ancho)
var VP_W := 1152     # ancho de sobra a la derecha: las sombras caen hacia ese lado
var VP_H := 1024
var ORIGIN := Vector2(448, 720)   # píxel donde cae el origen (centro de la huella, a nivel del suelo)
var vp: SubViewport
var cam: Camera3D
var holder: Node3D
var sun: DirectionalLight3D
var sun_sh: DirectionalLight3D     # luz sólo para el pase de sombras (viene de arriba a la izquierda de la pantalla)
var ground: MeshInstance3D
var origins: Dictionary = {}
var out_dir := "/tmp/iso_raw"
var only := PackedStringArray()
var teams := PackedStringArray(["blue", "red"])

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out_dir = a.substr(4)
		elif a.begins_with("only="): only = a.substr(5).split(",")
		elif a.begins_with("teams="): teams = a.substr(6).split(",")
		elif a.begins_with("style="): IsoModels.lego = a.substr(6) == "lego"
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
	cam = Camera3D.new()
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
	cam.h_offset = (float(VP_W) * 0.5 - ORIGIN.x) / SCALE   # al revés que v_offset: un desplazamiento positivo mueve la imagen a la izquierda
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 14.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	vp.add_child(sun)
	sun.look_at_from_position(Vector3(-3.0, 7.0, 4.0), Vector3.ZERO, Vector3.UP)
	# pase de sombras: otra luz (desde arriba a la izquierda de la pantalla = -x) y un suelo que sólo recibe
	sun_sh = DirectionalLight3D.new()
	sun_sh.light_energy = 1.35
	sun_sh.shadow_enabled = true
	sun_sh.directional_shadow_max_distance = 20.0
	sun_sh.shadow_bias = 0.03
	sun_sh.shadow_normal_bias = 0.6
	sun_sh.visible = false
	vp.add_child(sun_sh)
	sun_sh.look_at_from_position(Vector3(-5.0, 6.5, -0.6), Vector3.ZERO, Vector3.UP)
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color.WHITE
	gm.roughness = 1.0
	gm.metallic_specular = 0.0
	ground.material_override = gm
	ground.visible = false
	vp.add_child(ground)
	holder = Node3D.new()
	vp.add_child(holder)

## Cambia el tamaño del lienzo y el punto donde cae el origen (modelos grandes, como el castillo).
func _configure(w: int, h: int, ox: float, oy: float) -> void:
	VP_W = w
	VP_H = h
	ORIGIN = Vector2(ox, oy)
	vp.size = Vector2i(VP_W, VP_H)
	cam.size = float(VP_H) / SCALE
	cam.v_offset = (ORIGIN.y - float(VP_H) * 0.5) / SCALE
	cam.h_offset = (float(VP_W) * 0.5 - ORIGIN.x) / SCALE   # al revés que v_offset: un desplazamiento positivo mueve la imagen a la izquierda

func _log(t: String) -> void:
	var f := FileAccess.open("/tmp/iso_log.txt", FileAccess.READ_WRITE if FileAccess.file_exists("/tmp/iso_log.txt") else FileAccess.WRITE)
	f.seek_end()
	f.store_line("%d %s" % [Time.get_ticks_msec(), t])

func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout

func _shadows_only(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for c in n.get_children():
		_shadows_only(c)

func _shot(model: Node3D, yaw: float, name: String, shadow: bool = false) -> void:
	_log("shot " + name + " start")
	holder.add_child(model)
	model.rotation_degrees.y = yaw
	await _frames()
	var img := vp.get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	origins[name] = [ORIGIN.x, ORIGIN.y]
	if shadow:
		# segundo pase: sólo se dibujan las sombras sobre un suelo blanco (iso_post.py las convierte en alfa)
		sun.visible = false
		sun_sh.visible = true
		ground.visible = true
		_shadows_only(model)
		await _frames()
		vp.get_texture().get_image().save_png("%s/%s_sh.png" % [out_dir, name])
		origins[name + "_sh"] = [ORIGIN.x, ORIGIN.y]
		sun.visible = true
		sun_sh.visible = false
		ground.visible = false
	model.queue_free()
	await get_tree().process_frame

func _want(n: String) -> bool:
	return only.is_empty() or only.has(n)

func _run() -> void:
	var blue := Color(0.20, 0.42, 0.88)
	var red := Color(0.80, 0.18, 0.16)
	if _want("casa"):
		await _shot(IsoModels.casa(blue), 0.0, "casa_blue", true)
		await _shot(IsoModels.casa(red), 0.0, "casa_red")
	if _want("centro"):
		await _shot(IsoModels.centro(blue), 0.0, "centro_blue", true)
	if _want("torre"):
		await _shot(IsoModels.torre(blue), 0.0, "torre_blue", true)
	if _want("torrec"):
		await _shot(IsoModels.torre_cuadrada(blue), 0.0, "torrec_blue", true)
		await _shot(IsoModels.torre_cuadrada(red), 0.0, "torrec_red")
	if _want("atalaya"):
		await _shot(IsoModels.atalaya(blue), 0.0, "atalaya_blue", true)
	if _want("muralla"):
		await _shot(IsoModels.muralla(false), 0.0, "muralla_x", true)
		await _shot(IsoModels.muralla(true), 0.0, "muralla_z", true)
	if _want("castillo"):
		_configure(1900, 1500, 640, 880)
		await _shot(IsoModels.castillo(blue), 0.0, "castillo_blue", true)
		_configure(1152, 1024, 448, 720)
	if _want("asedio"):
		await _shot(IsoModels.trabuquete(blue), 0.0, "trabuquete_blue", true)
		await _shot(IsoModels.catapulta(blue), 0.0, "catapulta_blue", true)
	if _want("roble"):
		for v in 7:
			await _shot(IsoModels.roble(v), 0.0, "roble_%d" % v, true)
	if _want("pino"):
		for v in 2:
			await _shot(IsoModels.pino(v), 0.0, "pino_%d" % v, true)
	if _want("roca"):
		await _shot(IsoModels.roca(0, false), 0.0, "roca_0", true)
		await _shot(IsoModels.roca(1, true), 0.0, "oro_0", true)
	for kind in ["aldeano", "espadachin"]:
		if not _want(kind):
			continue
		for team in teams:
			var col: Color = blue if team == "blue" else red
			for d in 8:
				await _shot(IsoModels.persona(kind, col, -1.0), float(d) * 45.0, "%s_%s_%d_idle" % [kind, team, d])
				for f in 4:
					await _shot(IsoModels.persona(kind, col, float(f) * 0.25), float(d) * 45.0, "%s_%s_%d_w%d" % [kind, team, d, f])
	# orígenes por sprite (iso_post.py los lee)
	var op := out_dir + "/origins.json"
	var f := FileAccess.open(op, FileAccess.WRITE)
	f.store_string(JSON.stringify(origins))
	f.close()
	print("INFO horneado en ", out_dir)
