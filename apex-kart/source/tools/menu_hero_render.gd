extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = root.get_node("Game")
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("111e2f")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = .75
	env.environment = e
	scene.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	light.light_energy = 1.4
	scene.add_child(light)
	var car = load("res://scripts/car.gd").new()
	car.team = game.teams[5]
	car.is_player = true
	scene.add_child(car)
	car.build_model()
	car.set_helmet_design(6)
	car.set_process(false)
	car.held = false
	car.dirt = 0
	car.damage = 0
	car.wear = 0
	# A track reference enables the normal visual-wear update without touching physics.
	car.track = Node3D.new()
	car._update_race_wear(0)
	car.celebration_strength = 0
	car._update_rig(.016)
	var cam := Camera3D.new()
	cam.fov = 24
	cam.position = Vector3(2.4,1.45,-3.2)
	scene.add_child(cam)
	cam.look_at(Vector3(0,.5,0))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://ui/menu_kart.png")
	car.track.free()
	quit()
