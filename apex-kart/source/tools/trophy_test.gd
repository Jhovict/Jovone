extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var game = get_root().get_node("Game")
	game.new_career("Piloto Teste", 0, 0)
	game.career["team"] = 5
	game.career["role"] = "first"
	check(game.trophy_track_count() == 0, "New career must start empty")
	check(game.award_track_trophy(0, 0).is_empty(), "DNF cannot win trophy")
	check(game.award_track_trophy(0, 4).is_empty(), "Fourth cannot win trophy")
	check(game.award_track_trophy(-1, 1).is_empty(), "Invalid circuit")
	var visited := {}
	for season in range(1, 5):
		game.career["season"] = season
		for round_idx in 4:
			visited[game.round_track(round_idx)] = true
	check(visited.size() == 16, "Calendar must visit every circuit")
	game.career["season_results"] = [{"round": 1, "track": 7}]
	check(game.round_track(0) == 7, "Legacy completed stage was changed")
	game.career["season_results"] = []
	game.career["season"] = 1
	for i in 16:
		game.career["round"] = i
		check(not game.award_track_trophy(i, 1).is_empty(), "Gold not awarded")
		check(game.award_track_trophy(i, 1).is_empty(), "Duplicate event must be ignored")
		game.career["season"] = 2
		check(not game.award_track_trophy(i, 2).is_empty(), "Silver not awarded")
		game.career["season"] = 3
		game.award_track_trophy(i, 3)
		game.career["season"] = 1
		check(game.trophy_for(i)["medals"] == [1, 1, 1], "Podium variants not counted")
		check(int(game.trophy_for(i)["best_place"]) == 1, "Bronze replaced gold")
		var model = load("res://scripts/trophy_model.gd").build(game.tracks[i], i, 1)
		check(model.get_child_count() >= 10, "Incomplete trophy")
		model.free()
	check(game.trophy_track_count() == 16, "Collection progress wrong")
	check(game.save_career(), "Save failed")
	game.career = {}
	check(game.load_career(), "Load failed")
	check(game.trophy_track_count() == 16, "Trophies lost on load")
	var saved_medals: Array = game.trophy_for(15)["medals"]
	check(saved_medals.size() == 3 and int(saved_medals[0]) == 1 and int(saved_medals[1]) == 1 and int(saved_medals[2]) == 1, "Medal counts lost")
	game.career.erase("trophies")
	game.career.erase("trophy_events")
	game.save_career()
	check(game.load_career(), "Legacy save rejected")
	check(game.trophy_track_count() == 0, "Legacy migration incorrect")
	check(game.career["name"] == "Piloto Teste", "Migration changed driver")
	# Render screens using disposable sample data, never the user's save.
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		var out: String = args[0]
		DirAccess.make_dir_recursive_absolute(out)
		game.career["round"] = 0
		game.award_track_trophy(0, 1)
		var main = load("res://scenes/main.tscn").instantiate()
		get_root().add_child(main)
		await process_frame
		main._show_trophies(0, 1)
		for n in 8: await process_frame
		get_root().get_texture().get_image().save_png(out.path_join("sala-trofeus.png"))
		main._show_trophies(15, 3)
		for n in 5: await process_frame
		get_root().get_texture().get_image().save_png(out.path_join("trofeu-bloqueado.png"))
		main._show_trophy_award({"track": 3, "place": 2, "first": true, "count": 1}, func(): pass)
		for n in 5: await process_frame
		get_root().get_texture().get_image().save_png(out.path_join("trofeu-podio.png"))
		for i in 16:
			game.award_track_trophy(i, 1)
			main._show_trophies(i, 1)
			for n in 3: await process_frame
			var box = main.screen_extras[0]
			box.get_child(0).get_texture().get_image().save_png(out.path_join("trofeu_%02d.png" % i))
		main.queue_free()
		await process_frame
	print("TROPHY_TEST ", "PASS" if failures == 0 else "FAIL", " checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
