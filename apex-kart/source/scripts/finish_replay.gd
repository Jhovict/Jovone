extends RefCounted
var frames: Array = []
var sample_clock := 0.0
var next_sample := 0.0
var playback := 0.0
var cursor := 0
var duration := 0.0
func capture(dt: float, cars: Array) -> void:
	sample_clock += dt
	if sample_clock < next_sample: return
	next_sample = sample_clock + .05
	var values: Array = []
	for c in cars: values.append([c.global_transform,c.body.transform,c.steer,c.vx,c.celebration_strength])
	frames.append({"time":sample_clock,"cars":values})
	# Absolute sample times retain frame spacing even on a slow device.
	while frames.size()>240 or (frames.size()>2 and float(frames[0]["time"])<sample_clock-12.0): frames.pop_front()
func begin() -> bool:
	if frames.size()<3: return false
	playback = float(frames[0]["time"])
	duration = float(frames[-1]["time"])
	cursor = 0
	return duration-playback>1.0
func tick(dt: float, cars: Array) -> bool:
	playback += dt*.75
	while cursor<frames.size()-2 and float(frames[cursor+1]["time"])<playback: cursor+=1
	var a: Dictionary = frames[cursor]
	var b: Dictionary = frames[cursor+1]
	var f := clampf((playback-float(a["time"]))/maxf(.001,float(b["time"])-float(a["time"])),0,1)
	for i in cars.size():
		var c = cars[i]
		c.global_transform = (a["cars"][i][0] as Transform3D).interpolate_with(b["cars"][i][0],f)
		c.body.transform = (a["cars"][i][1] as Transform3D).interpolate_with(b["cars"][i][1],f)
		c.replaying = true
		c.celebration_strength = lerpf(a["cars"][i][4],b["cars"][i][4],f)
		c.steer = lerpf(a["cars"][i][2],b["cars"][i][2],f)
		c.vx = lerpf(a["cars"][i][3],b["cars"][i][3],f)
		if c.helmet: c.helmet.visible = true
	return playback>=duration
