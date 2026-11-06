## Teste da rolagem por arrasto (scripts/touch_scroll.gd): arrastar a lista, toque rápido clica, arrastar
## a partir do botão não clica, inércia e barra de rolagem. Com janela: Godot --path .. -s tools/touch_scroll_test.gd
extends SceneTree
var main: Node
var clicks := 0
var fails := 0
func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	_run.call_deferred()
func _f(n := 3) -> void:
	for i in n: await process_frame
func _btn_ev(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	if pressed: e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	await _f(2)
func _move(pos: Vector2, vel: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	m.velocity = vel
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(m)
	await _f(1)
func _drag(from: Vector2, to: Vector2, steps: int, vel: Vector2, release := true) -> void:
	var m0 := InputEventMouseMotion.new()
	m0.position = from
	m0.global_position = from
	Input.parse_input_event(m0)
	await _f(1)
	await _btn_ev(from, true)
	for i in range(1, steps + 1):
		await _move(from.lerp(to, float(i) / steps), vel)
	if release:
		await _btn_ev(to, false)
func check(name: String, ok: bool, info := "") -> void:
	print(("OK    " if ok else "FALHA ") + name + "  " + info)
	if not ok: fails += 1
func _page() -> void:
	var rows: Array = []
	for k in 16:
		rows.append({"name": "Piloto %d" % k, "team": k % 8, "time": 60.0 + k, "player": k == 12})
	main._show_quali_results(rows, func(): clicks += 1)
	main.screen_id = "teste"
	await _f(12)
func _run() -> void:
	await _f(10)
	await _page()
	var sc: ScrollContainer = main.page_scroll
	sc.scroll_vertical = 0
	await _f(3)
	var r := sc.get_global_rect()
	var mid := r.position + Vector2(r.size.x * 0.4, r.size.y * 0.6)
	# A: arrastar a tabela para cima rola para baixo
	await _drag(mid, mid - Vector2(0, 150), 10, Vector2(0, -300))
	await _f(5)
	check("arrastar a tabela rola", sc.scroll_vertical > 60, "scroll=%d" % sc.scroll_vertical)
	# B: toque rápido no botão clica
	var b: Button = get_root().gui_get_focus_owner() as Button
	sc.scroll_vertical = 100000
	await _f(4)
	var bc := b.get_global_rect().get_center()
	var c0 := clicks
	await _btn_ev(bc, true)
	await _btn_ev(bc, false)
	await _f(4)
	check("toque rápido no botão clica", clicks == c0 + 1, "clicks=%d" % clicks)
	await _page()
	sc = main.page_scroll
	sc.scroll_vertical = 100000
	await _f(4)
	b = get_root().gui_get_focus_owner() as Button
	bc = b.get_global_rect().get_center()
	# C: arrastar começando no botão não clica
	var s0 := sc.scroll_vertical
	c0 = clicks
	await _drag(bc, bc + Vector2(0, 120), 8, Vector2(0, 300))
	await _f(4)
	check("arrastar a partir do botão não clica", clicks == c0, "clicks=%d" % clicks)
	check("arrastar a partir do botão rola", sc.scroll_vertical < s0, "%d -> %d" % [s0, sc.scroll_vertical])
	# D: inércia
	sc.scroll_vertical = 0
	await _f(3)
	await _drag(mid, mid - Vector2(0, 60), 4, Vector2(0, -2500))
	var after_release := sc.scroll_vertical
	await _f(20)
	check("inércia continua depois de soltar", sc.scroll_vertical > after_release + 10, "%d -> %d" % [after_release, sc.scroll_vertical])
	# E: barra de rolagem: arrastar o puxador para baixo desce o conteúdo
	await _f(60)
	sc.scroll_vertical = 0
	await _f(3)
	var bar := sc.get_v_scroll_bar()
	if bar.is_visible_in_tree():
		var g := bar.get_global_rect()
		var p := Vector2(g.get_center().x, g.position.y + 12)
		await _drag(p, p + Vector2(0, 80), 6, Vector2(0, 200))
		await _f(4)
		check("barra de rolagem continua normal", sc.scroll_vertical > 0, "scroll=%d" % sc.scroll_vertical)
	else:
		print("barra de rolagem invisível (ok)")
	print("DRAG_TEST ", "PASS" if fails == 0 else "FAIL %d" % fails)
	quit()
