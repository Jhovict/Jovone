extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var game = root.get_node("Game")
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("24344b")
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
	car.dirt = .7
	car.damage = .5
	car.wear = .65
	# A track reference enables the normal visual-wear update without touching physics.
	car.track = Node3D.new()
	car._update_race_wear(0)
	car.celebration_strength = 1.0
	car._update_rig(.016)
	var cam := Camera3D.new()
	cam.fov = 35
	cam.position = Vector3(2.4,1.45,-3.2)
	scene.add_child(cam)
	cam.look_at(Vector3(0,.5,0))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../qa/seven-wear-victory.png")
	assert(car.driver_rig.hands[0].global_position.y>car.driver_rig.hands[1].global_position.y)
	var ghost = load("res://scripts/lap_ghost.gd").new()
	scene.add_child(ghost)
	ghost.setup(car,0,"dry")
	ghost.best = [[0,-2,0,0,0,0,0],[1,-2,0,0,0,.2,1]]
	ghost.best_time = 1
	assert(ghost.display(.5,true)!="")
	assert(ghost.ghost.visible)
	cam.position = Vector3(3.0,2.4,-6)
	cam.look_at(Vector3(-.8,.5,0))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../qa/seven-ghost.png")
	car.track.free()
	print("SEVEN VISUAL PASS: wear shader, tyre pickup, raised victory hand")
	quit()
