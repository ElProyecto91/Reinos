extends Node
## Prueba de que el motor renderiza 3D a PNG con fondo transparente (base del pre-renderizado de sprites isométricos).
## Uso: xvfb-run -a godot --path . res://tools/iso_test3d.tscn --rendering-driver opengl3 --resolution 640x360 -- out=/tmp/iso3d.png
func _ready() -> void:
	var out := "/tmp/iso3d.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="): out = a.substr(4)
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.80)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 256.0 / 90.5
	vp.add_child(cam)
	cam.position = Vector3(0, 0, 0) + Vector3(8, 8, 8).normalized() * 0.0
	# yaw 45 grados, elevación 30 grados
	var dir := Vector3(1, 0, 1).normalized()
	var el := deg_to_rad(30.0)
	var look := Vector3(dir.x * cos(el), sin(el), dir.z * cos(el)).normalized()
	cam.position = look * 20.0
	cam.look_at(Vector3.ZERO, Vector3.UP)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 1.2
	vp.add_child(sun)
	sun.look_at_from_position(Vector3(-4, 6, -3), Vector3.ZERO, Vector3.UP)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.4, 0.8, 1.0)
	box.mesh = bm
	box.position = Vector3(0, 0.4, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.70, 0.56)
	box.material_override = mat
	vp.add_child(box)
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(1.6, 0.6, 1.2)
	roof.mesh = pm
	roof.position = Vector3(0, 1.1, 0)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.65, 0.25, 0.18)
	roof.material_override = rm
	vp.add_child(roof)
	for i in 4:
		await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout
	var img := vp.get_texture().get_image()
	print("INFO imagen ", img.get_size(), " formato ", img.get_format())
	var corner := img.get_pixel(2, 2)
	var center := img.get_pixel(128, 150)
	print("INFO esquina alfa=%.2f centro=%s alfa=%.2f" % [corner.a, center, center.a])
	img.save_png(out)
	print("INFO guardado ", out)
	get_tree().quit()
