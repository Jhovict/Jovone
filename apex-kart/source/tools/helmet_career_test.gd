extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var g = root.get_node("Game")
	g.new_career("Teste Capacete", 0, 6)
	g.career["team"] = 0
	g.career["helmet_visor"] = 1
	g.career["helmet_finish"] = 2
	g.save_career()
	g.career = {}
	assert(g.load_career())
	assert(g.career["helmet"] == 6 and g.career["helmet_visor"] == 1 and g.career["helmet_finish"] == 2)
	g.career.erase("helmet_visor")
	g.career.erase("helmet_finish")
	g.save_career()
	assert(g.load_career())
	assert(g.career["helmet_visor"] == 0 and g.career["helmet_finish"] == 0)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._show_helmet_customization()
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../qa/helmet-ui.png")
	var before: Dictionary = g.career.duplicate(true)
	var paint_button = find_button(main, "PINTURA")
	assert(paint_button != null)
	paint_button.pressed.emit()
	find_button(main, "CANCELAR").pressed.emit()
	assert(g.career == before)
	await process_frame
	main._show_helmet_customization()
	await process_frame
	find_button(main, "PINTURA").pressed.emit()
	find_button(main, "APLICAR").pressed.emit()
	assert(g.career["helmet"] == 7)
	assert(g.career["name"] == before["name"] and g.career["trophies"] == before["trophies"])
	print("HELMET CAREER PASS: persistence and legacy migration")
	quit()

func find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found := find_button(child, label)
		if found: return found
	return null

