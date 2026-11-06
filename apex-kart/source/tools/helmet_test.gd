extends SceneTree
const H = preload("res://scripts/helmet_model.gd")
func _initialize():
	call_deferred("run")
func run():
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("161e2b")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.65
	env.environment = e
	scene.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.8
	scene.add_child(light)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.24
	cam.position = Vector3(0.20, 0.065, -0.4)
	scene.add_child(cam)
	cam.look_at(Vector3.ZERO)
	var head := MeshInstance3D.new()
	scene.add_child(head)
	H.apply(head, false, "volt")
	for i in H.FILES.size():
		H.customize(head, i, i % 4, 0)
		assert(head.material_override.albedo_texture != null)
		assert(head.get_node("Visor").mesh != null)
		await process_frame
		await process_frame
		if not DisplayServer.get_name() == "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../qa/helmet-%02d.png" % i)
	for lite in [false, true]:
		var arrays = H.shell(lite).surface_get_arrays(0)
		for v in arrays[Mesh.ARRAY_VERTEX]:
			assert(v.is_finite())
	print("HELMET PASS: 18 textures, separate visor, full/lite finite geometry")
	quit()
