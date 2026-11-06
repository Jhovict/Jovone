extends SubViewportContainer
const Trophy := preload("res://scripts/trophy_model.gd")
var sculpture: Node3D
var time := 0.0

func setup(track: Dictionary, idx: int, place: int) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)
	var environment := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.92, 1)
	e.ambient_light_energy = 0.65
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.25, 0.35, 0.55)
	sky.sky_horizon_color = Color(0.85, 0.85, 0.8)
	sky.ground_bottom_color = Color(0.08, 0.1, 0.15)
	e.sky.sky_material = sky
	environment.environment = e
	viewport.add_child(environment)
	for angles in [Vector3(-35, -40, 0), Vector3(-20, 130, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = angles
		light.light_energy = 1.0
		viewport.add_child(light)
	sculpture = Trophy.build(track, idx, place)
	viewport.add_child(sculpture)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.85
	camera.position = Vector3(0.5, 1.1, 3.5)
	viewport.add_child(camera)
	camera.look_at(Vector3(0, 0.78, 0))

func _process(delta: float) -> void:
	time += delta
	if sculpture:
		sculpture.rotation.y = sin(time * 0.65) * 0.25

