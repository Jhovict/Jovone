extends SubViewportContainer
const Car := preload("res://scripts/car.gd")
const Appearance := preload("res://scripts/appearance.gd")
var car
var camera: Camera3D
var stage: Node3D
var yaw := 0.65
var zoom := 3.8
var dragging := false
var view_mode := 0
func setup(team: Dictionary) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_4X
	add_child(sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c5d5ed")
	e.ambient_light_energy = 0.7
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	env.environment = e
	sv.add_child(env)
	for angles in [Vector3(-45, -30, 0), Vector3(-20, 145, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = angles
		light.light_energy = 1.15
		sv.add_child(light)
	stage = Node3D.new()
	sv.add_child(stage)
	var platform := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 1.45
	disk.bottom_radius = 1.5
	disk.height = 0.07
	disk.radial_segments = 64
	platform.mesh = disk
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("26354a")
	mat.metallic = 0.55
	mat.roughness = 0.32
	platform.material_override = mat
	platform.position.y = -0.05
	stage.add_child(platform)
	car = Car.new()
	car.team = team.duplicate()
	stage.add_child(car)
	car.build_model()
	camera = Camera3D.new()
	camera.fov = 35
	camera.near = 0.03
	sv.add_child(camera)
	_update_camera()
func update_look(data: Dictionary) -> void:
	Appearance.apply(car, data.get("appearance", {}))
	car.set_helmet_design(int(data.get("helmet", 0)), int(data.get("helmet_visor", 0)), int(data.get("helmet_finish", 0)))
func view_part(index: int) -> void:
	view_mode = index
	zoom = [3.8, 1.0, 1.65][index]
	_update_camera()
func turn(amount: float) -> void:
	yaw += amount
	_update_camera()
func dolly(amount: float) -> void:
	zoom = clampf(zoom + amount, 0.7, 5.0)
	_update_camera()
func _update_camera() -> void:
	var target := Vector3(0, 0.45, 0)
	if view_mode == 1 and car.helmet: target = car.helmet.global_position
	elif view_mode == 2: target = Vector3(0, 0.55, -0.2)
	camera.position = target + Vector3(sin(yaw), 0.42, -cos(yaw)).normalized() * zoom
	camera.look_at(target)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: dolly(-0.2)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: dolly(0.2)
	elif event is InputEventMouseMotion and dragging: turn(-event.relative.x * 0.008)
	elif event is InputEventScreenDrag: turn(-event.relative.x * 0.008)
	elif event is InputEventMagnifyGesture: dolly((1.0 - event.factor) * zoom)
