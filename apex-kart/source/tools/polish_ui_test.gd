extends SceneTree
var main
func _initialize(): call_deferred("run")
func shot(name: String):
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../qa/"+name+".png")
func button(node: Node, label: String) -> Button:
	if node is Button and node.text == label and not node.is_queued_for_deletion(): return node
	for child in node.get_children():
		if child.is_queued_for_deletion(): continue
		var found := button(child,label)
		if found: return found
	return null
func run():
	var g = root.get_node("Game")
	g.new_career("João Silva",0,6)
	g.career["team"] = 0
	g.career["appearance"] = {"livery":1,"suit":3,"gloves":2}
	g.career["helmet_visor"] = 1
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._show_garage()
	await shot("polish-garage")
	var before: Dictionary = g.career.duplicate(true)
	button(main,"KART").pressed.emit()
	button(main,"CANCELAR").pressed.emit()
	assert(g.career == before)
	await process_frame
	main._show_garage()
	await process_frame
	button(main,"MACACÃO").pressed.emit()
	button(main,"LUVAS").pressed.emit()
	button(main,"APLICAR").pressed.emit()
	assert(g.career["appearance"]["suit"] == 4)
	assert(g.career["appearance"]["gloves"] == 3)
	assert(g.career["team"] == before["team"])
	g.save_career()
	g.career = {}
	assert(g.load_career())
	assert(g.career["appearance"]["suit"] == 4)
	g.career["appearance"] = before["appearance"]
	await process_frame
	var cls := [{"name":"João Silva","team":0,"player":true,"status":"ok"},{"name":"Rafael Moura","team":1,"player":false,"status":"ok"},{"name":"Marina Valente","team":2,"player":false,"status":"ok"}]
	main._show_trophy_award({"track":0,"place":1,"first":true,"count":1},func():pass,cls)
	await create_timer(3.3).timeout
	await shot("polish-podium")
	print("POLISH UI PASS: garage preview, cancel/apply, persistence, team unchanged, animated podium")
	quit()
