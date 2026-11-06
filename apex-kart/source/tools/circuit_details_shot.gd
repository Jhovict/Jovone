extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = root.get_node("Game")
	var scene := Node3D.new()
	root.add_child(scene)
	var track = load("res://scripts/track.gd").new()
	scene.add_child(track)
	track.build(g.tracks[0],"dry")
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = .7
	env.environment = e
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,35,0)
	sun.light_energy = 1.3
	scene.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 48
	scene.add_child(cam)
	var stand = track.get_node("Grandstand_0")
	cam.position = stand.position + stand.basis * Vector3(22,17,32)
	cam.look_at(stand.position+Vector3(0,2,0))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../qa/polish-track.png")
	print("SCENERY SHOT PASS")
	quit()
