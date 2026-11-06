extends SceneTree
var checks := 0
var failure := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failure = true
		push_error(message)

func run() -> void:
	var game = get_root().get_node("Game")
	var car_script = load("res://scripts/car.gd")
	for quality in [1, 2]:
		game.settings["quality"] = quality
		for key in ["volt", "scarlet", "papaya", "nova", "aureon", "polar", "verde", "magenta"]:
			var car = car_script.new()
			car.team = {"livery": key}
			get_root().add_child(car)
			car.build_model()
			check(car.driver_rig.skeleton.get_bone_count() == 7, "Missing driver bones")
			var arr: Array = car.driver_rig.torso.mesh.surface_get_arrays(0)
			check(arr[Mesh.ARRAY_TEX_UV].size() == arr[Mesh.ARRAY_VERTEX].size(), "Lost suit UVs")
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var valid := true
			var weight_error := 0.0
			for i in range(0, weights.size(), 4):
				weight_error = maxf(weight_error, absf(weights[i] + weights[i+1] + weights[i+2] + weights[i+3] - 1.0))
				if weight_error > 0.0001:
					valid = false
			check(valid, "Non-normalized skin weights error=" + str(weight_error))
			if key == "volt": print("WEIGHT_QUANTIZATION_ERROR ", weight_error)
			for turn in [-1.0, -0.5, 0.0, 0.5, 1.0]:
				car.steer = turn
				car.vx = 20.0
				car.r = turn * 0.7
				car.ax = -8.0
				car._update_rig()
				check(car.driver_rig.wrist_error < 0.001, "Unreachable wrist at lock " + str(turn))
				check(car.driver_rig.hands[0].transform.is_finite(), "Non-finite IK")
				if turn > 0:
					check(car._front_angle(-0.25) > car._front_angle(0.25), "Ackermann reversed")
				elif turn < 0:
					check(absf(car._front_angle(0.25)) > absf(car._front_angle(-0.25)), "Ackermann reversed")
			car.set_helmet_color(Color(0.1, 0.5, 0.9))
			check(car.helmet.material_override.albedo_color.is_equal_approx(Color(0.1, 0.5, 0.9)), "Career helmet tint lost")
			car.free()
	print("VISUAL_TEST ", "FAIL" if failure else "PASS", " checks=", checks)
	quit(1 if failure else 0)
