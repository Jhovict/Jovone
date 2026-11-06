extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var g = root.get_node("Game")
	g.settings["volume"] = 0.8
	var sound = load("res://scripts/engine_audio.gd").new()
	root.add_child(sound)
	sound._amb.stream = null
	sound._skid.stream = null
	sound._rain.stream = null
	sound._gen_player.volume_db = -80
	var rec := AudioEffectRecord.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Motor"),rec)
	rec.set_recording_active(true)
	for i in 240:
		var t := i / 20.0
		var rev := fmod(t,4.0)
		sound.rpm = lerpf(3500,14500,rev/4.0)
		sound.thr = 1.0 if t < 8.0 else 0.0
		if i == 80 or i == 160: sound.shift()
		await create_timer(.05).timeout
	rec.set_recording_active(false)
	var recording := rec.get_recording()
	assert(recording != null and recording.get_length() > 10.0)
	recording.save_to_wav("res://../qa/polish-engine.wav")
	print("AUDIO RECORD PASS seconds=",recording.get_length())
	sound.queue_free()
	await process_frame
	quit()
