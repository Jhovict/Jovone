extends SceneTree
## Captura as telas de menu (conferência visual):  Godot --path .. -s tools/menu_shots.gd -- <pasta>
var main: Node
var out := ""

func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	var g = get_root().get_node_or_null("Game")
	if g == null:
		g = load("res://scripts/game.gd").new()
		g.name = "Game"
		get_root().add_child(g)
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	_run.call_deferred()

func _shot(n: String) -> void:
	for k in 6:
		await process_frame
	get_root().get_texture().get_image().save_png(out + "/menu_" + n + ".png")

func _run() -> void:
	await _shot("title")
	main._show_main()
	await _shot("main")
	main._show_quick()
	await _shot("quick")
	main._show_options(main._show_main)
	await _shot("options")
	main._show_driver_creation()
	await _shot("creation")
	var g = get_root().get_node("Game")
	var saved: Dictionary = g.career
	g.new_career("Marina Valente", 0, 0)
	g.career["team"] = 5
	g.career["role"] = "test"
	main._show_office()
	await _shot("office")
	main._show_drivers_table()
	await _shot("table")
	g.career = saved
	main._clear()
	main.bg.mode = "loading"
	main.bg.hero = main.HERO_SIDE
	main.bg.tip = main.TIPS[0]
	main.bg.queue_redraw()
	await _shot("loading_screen")
	var cfg: Dictionary = main._base_cfg(0)
	cfg.merge({"mode": "time_trial", "track": 0, "weather": "dry", "timed_laps": 1, "title": "x"})
	main._start_session(cfg, func(_r): pass)
	await _shot("loading")
	quit()
