extends SceneTree
var car
var viewport: SubViewport
var output := ""
var frame := 0

func _initialize() -> void:
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(960, 640)
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(viewport)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("141c29")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.75, 0.8, 0.95)
	world.environment.ambient_light_energy = 0.65
	viewport.add_child(world)
	for angles in [Vector3(-45, -35, 0), Vector3(-30, 145, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = angles
		light.light_energy = 0.9
		viewport.add_child(light)
	car = load("res://scripts/car.gd").new()
	car.team = {"livery": "volt", "c2": Color("d7ed5a")}
	viewport.add_child(car)
	car.build_model()
	car.set_process(false)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.85
	camera.position = Vector3(1.8, 1.35, -2.5)
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 0.4, -0.03))
	for i in 36:
		var phase := TAU * i / 36.0
		car.steer = sin(phase) * 0.85
		car.vx = 12.0
		car.r = sin(phase) * 0.8
		car.ax = cos(phase) * 5.0
		car._update_rig()
		for wheel in car.front_wheels:
			wheel.basis = Basis(Vector3.UP, car._front_angle(wheel.position.x)) * wheel.get_meta("rest")
		await process_frame
		await process_frame
		viewport.get_texture().get_image().save_png(output.path_join("frame_%02d.png" % i))
	print("PREVIEW DONE")
	quit()
