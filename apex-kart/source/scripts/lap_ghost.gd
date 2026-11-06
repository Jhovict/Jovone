extends Node3D
var best: Array = []
var current: Array = []
var best_time := INF
var path := ""
var clock := 0.0
var cursor := 0
var ghost
var owner_car
func setup(car, track_idx: int, weather: String) -> void:
	owner_car = car
	path = "user://ghost_v1_%d_%s_%s.json" % [track_idx,weather,car.team.get("livery","default")]
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if valid_data(data):
			best = data["samples"]
			best_time = float(data["time"])
	ghost = load("res://scripts/car.gd").new()
	ghost.team = car.team.duplicate()
	add_child(ghost)
	ghost.build_model(Color(0,0,0,0),true)
	ghost.set_process(false)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(.12,.80,1,.22)
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	paint(ghost,mat)
	ghost.hide()
static func valid_data(data) -> bool:
	if not data is Dictionary or not data.get("samples") is Array: return false
	if not is_finite(float(data.get("time",0))) or float(data.get("time",0))<=0: return false
	var samples: Array = data["samples"]
	if samples.size()<2 or samples.size()>7202: return false
	var previous := -1.0
	for sample in samples:
		if not sample is Array or sample.size()!=7: return false
		for value in sample:
			if not (value is float or value is int) or not is_finite(float(value)): return false
		if float(sample[0])<=previous: return false
		previous = float(sample[0])
	return true
func paint(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children(): paint(child,mat)
func sample(elapsed: float) -> Array:
	return [elapsed,owner_car.pos.x,owner_car.pos.y,owner_car.pos.z,owner_car.h,owner_car.steer,owner_car.s]
func begin_lap() -> void:
	current = [sample(0)]
	clock = 0
	cursor = 0
func record(dt: float, elapsed: float) -> void:
	clock += dt
	if current.is_empty() or elapsed<=0: return
	if clock >= .10 and current.size()<7200:
		clock = 0
		current.append(sample(elapsed))
func complete(lap_time: float, valid: bool) -> bool:
	if not valid or current.size()<10 or lap_time>=best_time: return false
	if float(current[-1][0]) < lap_time: current.append(sample(lap_time))
	var data := {"time":lap_time,"samples":current}
	if not valid_data(data): return false
	best = current.duplicate(true)
	best_time = lap_time
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		DirAccess.rename_absolute(path+".tmp",path)
	return true
func display(elapsed: float, enabled: bool) -> String:
	ghost.visible = enabled and best.size()>1 and elapsed>=0 and elapsed<=best_time
	if not ghost.visible: return ""
	while cursor<best.size()-2 and float(best[cursor+1][0])<elapsed: cursor+=1
	var a: Array = best[cursor]
	var b: Array = best[cursor+1]
	var f := clampf((elapsed-float(a[0]))/maxf(.001,float(b[0])-float(a[0])),0,1)
	ghost.position = Vector3(a[1],a[2],a[3]).lerp(Vector3(b[1],b[2],b[3]),f)
	ghost.rotation.y = lerp_angle(a[4],b[4],f)
	ghost.steer = lerpf(a[5],b[5],f)
	ghost._update_rig()
	ghost.visible = ghost.position.distance_to(owner_car.pos)>1.8
	return "FANTASMA  " + Game.fmt_time(best_time)
