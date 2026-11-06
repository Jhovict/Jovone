extends SceneTree
var race
var wet_shot := false
var replay_shot := false
var finished_count := 0
func _initialize(): call_deferred("run")
func run():
	var game = root.get_node("Game")
	game.settings["quality"] = 1
	game.settings["camera"] = 1
	game.settings["weather_change"] = true
	game.settings["finish_replay"] = true
	game.settings["radio"] = true
	race = load("res://scripts/race.gd").new()
	root.add_child(race)
	var field: Array = []
	for i in 5: field.append(game.drivers[i])
	race.setup({"mode":"race","track":0,"weather":"dry","laps":2,"field":field,"player_grid":3,"player_team":5,"player_name":"Piloto teste","player_code":"JOG","player_num":21,"difficulty":1,"pit_rule":0})
	race.autopilot = true
	race.finished.connect(func(res):
		finished_count+=1
		assert(res["classification"].size()==6)
		assert(finished_count==1)
		assert(wet_shot and replay_shot)
		print("SEVEN LIVE PASS: wet race, radio, 6 finishers, replay emits result once")
		call_deferred("finish"))
	Engine.time_scale = 4
	while is_instance_valid(race) and finished_count==0:
		await process_frame
		if not is_instance_valid(race) or finished_count>0: break
		if race.weather_flow.wetness>.5 and not wet_shot:
			wet_shot = true
			race.radio.say("wet","",true)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../qa/seven-weather.png")
		if race.state=="replay" and not replay_shot:
			replay_shot = true
			await create_timer(.8).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../qa/seven-replay.png")
func finish():
	race.queue_free()
	await process_frame
	quit()
