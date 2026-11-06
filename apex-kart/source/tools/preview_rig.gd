extends SceneTree
# Renderiza um kart com o volante em três posições para conferir volante, luvas, braços e pneus.
var frame := 0
var cam: Camera3D
var car
var out := ""
var shots := [[-1.0, Vector3(1.4, 1.3, -1.6), "a"], [0.0, Vector3(1.4, 1.3, -1.6), "b"], [1.0, Vector3(1.4, 1.3, -1.6), "c"],
	[1.0, Vector3(0.0, 1.05, 0.6), "d"], [-1.0, Vector3(0.0, 1.05, 0.6), "e"], [0.0, Vector3(2.2, 0.35, 0.3), "f"]]
var k := 0

func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	var root3 := Node3D.new()
	get_root().add_child(root3)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.6, 0.66)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.85)
	e.ambient_light_energy = 0.5
	env.environment = e
	root3.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 60, 0)
	sun.shadow_enabled = true
	root3.add_child(sun)
	car = load("res://scripts/car.gd").new()
	car.team = {"c1": Color(0.1, 0.35, 0.85)}
	root3.add_child(car)
	car.build_model(Color(1, 0.8, 0.1))
	cam = Camera3D.new()
	cam.fov = 45
	root3.add_child(cam)
	call_deferred("_apply")

func _apply() -> void:
	car.steer = shots[k][0]
	car._update_rig()
	cam.position = shots[k][1]
	cam.look_at(Vector3(0, 0.55, -0.2) if shots[k][2] != "f" else Vector3(0, 0.25, 0.3))
	if shots[k][2] == "d" or shots[k][2] == "e":
		car.helmet.visible = false
		cam.look_at(Vector3(0, 0.55, -0.6))
	else:
		car.helmet.visible = true

func _process(_d: float) -> bool:
	frame += 1
	if frame % 10 == 0:
		get_root().get_texture().get_image().save_png(out + "/rig_" + shots[k][2] + ".png")
		k += 1
		if k >= shots.size():
			return true
		_apply()
	return false
