extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var race = load("res://scripts/race.gd").new()
	root.add_child(race)
	race.setup({"mode":"race","track":0,"weather":"dry","laps":2,"field":[],"player_grid":1,"player_team":5,"player_name":"Teste","player_code":"JOG","player_num":21,"difficulty":1,"pit_rule":0})
	main.ui.hide()
	race.hud.pause_panel.theme = main.theme_main
	race._set_paused(true)
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../qa/menu-pause.png")
	race._on_pause_action("settings")
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../qa/menu-pause-settings.png")
	assert(race.hud.pause_panel.size.y<=600)
	race._on_pause_action("settings_back")
	race._on_pause_action("resume")
	assert(not race.paused)
	print("PAUSE MENU PASS: settings, back, resume; bounded panel")
	quit()
