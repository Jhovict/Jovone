extends SceneTree
var main
func _initialize(): call_deferred("run")
func shot(name: String):
	for i in 16: await process_frame
	await RenderingServer.frame_post_draw
	check_layout(main.screen)
	root.get_texture().get_image().save_png("res://../qa/menu-"+name+".png")
func check_layout(node: Node):
	if node is Button:
		for child in node.get_children():
			if child is HBoxContainer:
				var previous := -INF
				for label in child.get_children():
					if label is Label:
						assert(label.position.x>=previous-.1,"Selector overlap")
						assert(label.size.y<=node.size.y,"Selector height overflow")
						previous = label.position.x+label.size.x
	for child in node.get_children(): check_layout(child)
func run():
	var g = root.get_node("Game")
	g.new_career("João Silva",0,6)
	g.career["team"] = 0
	g.career["role"] = "second"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await shot("title")
	for method in ["_show_main","_show_quick","_show_driver_creation","_show_office","_show_garage","_show_drivers_table","_show_calendar","_show_trophies"]:
		main.call(method)
		await shot(method)
	main._show_options(main._show_main)
	await shot("options")
	print("MENU SCREENS PASS")
	quit()
