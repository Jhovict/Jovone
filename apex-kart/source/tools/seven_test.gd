extends SceneTree
class FakeCar extends Node3D:
	var body := Node3D.new()
	var steer := 0.0
	var vx := 10.0
	var celebration_strength := 0.0
	var helmet = null
	var replaying := false
func _initialize(): call_deferred("run")
func run():
	var replay = load("res://scripts/finish_replay.gd").new()
	var c := FakeCar.new()
	root.add_child(c)
	c.add_child(c.body)
	for i in 1800:
		c.position.x = i*.1
		replay.capture(1.0/60.0,[c])
	assert(replay.frames.size()<=240 and replay.frames.size()>150)
	assert(replay.begin())
	assert(replay.duration-replay.playback<=12.1)
	var start: float = replay.playback
	replay.tick(.2,[c])
	assert(c.replaying and c.global_transform.is_finite())
	assert(absf(replay.playback-start-.15)<.001)
	var weather = load("res://scripts/dynamic_weather.gd").new()
	weather.duration = 120
	var high := 0.0
	for i in 2400:
		var before: float = weather.wetness
		weather.advance(.1)
		assert(absf(weather.wetness-before)<=.00451)
		high = maxf(high,weather.wetness)
	assert(high>.7 and weather.wetness<.1)
	var Ghost = load("res://scripts/lap_ghost.gd")
	assert(not Ghost.valid_data({"time":1,"samples":[[0,0,0,0,0,0,0],[0,0,0,0,0,0,0]]}))
	assert(Ghost.valid_data({"time":1,"samples":[[0,0,0,0,0,0,0],[1,0,0,0,0,0,0]]}))
	var car = load("res://scripts/car.gd").new()
	car.team = root.get_node("Game").teams[0]
	root.add_child(car)
	car.build_model(Color(0,0,0,0),true)
	for i in 61:
		car.celebration_strength = i/60.0
		car._update_rig(.016)
		assert(car.driver_rig.hands[0].transform.is_finite())
		assert(car.driver_rig.wrist_error<.005)
	var ghost = Ghost.new()
	root.add_child(ghost)
	ghost.setup(car,0,"dry")
	ghost.path = "user://seven_ghost_test.json"
	ghost.best_time = INF
	ghost.begin_lap()
	for i in 30:
		car.pos.x = i
		ghost.record(.1,(i+1)*.1)
	assert(not ghost.complete(3.1,false))
	assert(ghost.complete(3.1,true))
	assert(not ghost.complete(4,true))
	assert(Ghost.valid_data(JSON.parse_string(FileAccess.get_file_as_string(ghost.path))))
	print("SEVEN CORE PASS: bounded replay, slow motion, wet/dry transitions, ghost validation/persistence, victory arm IK")
	ghost.free()
	car.free()
	c.free()
	quit()
