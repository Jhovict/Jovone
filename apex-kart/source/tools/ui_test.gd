extends SceneTree
## Teste de entrada: navega os menus só com o controle (A, B, D-pad) e aperta botões de toque na corrida.
##   Godot --path .. -s tools/ui_test.gd -- <pasta para capturas>

var main: Node
var out := ""
var fails := 0
var g: Node


func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	g = get_root().get_node_or_null("Game")
	if g == null:
		g = load("res://scripts/game.gd").new()
		g.name = "Game"
		get_root().add_child(g)
	main = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(main)
	_run.call_deferred()


func _wait(frames := 3) -> void:
	for k in frames:
		await process_frame


func _pad(button: int) -> void:
	for on in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = button
		e.pressed = on
		e.pressure = 1.0 if on else 0.0
		Input.parse_input_event(e)
		await _wait(2)


func _touch(idx: int, pos: Vector2, on: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = on
	Input.parse_input_event(e)
	await _wait(2)


func _check(what: String, ok: bool) -> void:
	print(("OK   " if ok else "FALHA") + "  " + what)
	if not ok:
		fails += 1


func _focused() -> String:
	var f := get_root().gui_get_focus_owner()
	return f.text if f is Button else str(f)


func _sel_value() -> String:
	## Valor mostrado no seletor em foco (rótulo dentro da "pílula" à direita).
	var f := get_root().gui_get_focus_owner()
	if f == null or f.get_child_count() == 0 or not (f.get_child(0) is HBoxContainer):
		return ""
	var v: Node = f.get_child(0).get_child(1)
	# seletor novo: o valor é um Label direto na linha; no antigo ficava dentro de uma "pílula"
	return (v as Label).text if v is Label else (v.get_child(0) as Label).text


func _shot(name: String) -> void:
	if out != "":
		get_root().get_texture().get_image().save_png(out + "/" + name + ".png")


func _run() -> void:
	# o cursor parado sobre um botão "rouba" o foco (passar o mouse foca): tira o mouse do caminho
	get_root().warp_mouse(Vector2(2, 2))
	await _wait(5)
	_check("tela de título", main.screen_id == "title")
	await _pad(JOY_BUTTON_START)
	_check("Start abre o menu principal", main.screen_id == "main")
	_check("foco no primeiro botão: " + _focused(), _focused().to_lower() == "carreira")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_check("D-pad desce o foco: " + _focused(), _focused().to_lower() == "corrida rápida")
	await _pad(JOY_BUTTON_A)
	_check("A entra na corrida rápida", main.screen_id != "main")
	var quick_screen: String = main.screen_id
	var before := _sel_value()
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_check("D-pad → muda seletor: %s → %s" % [before, _sel_value()], before != "" and before != _sel_value())
	await _pad(JOY_BUTTON_B)
	_check("B volta ao menu principal", main.screen_id == "main")
	await _wait(2)
	_check("foco volta para o item escolhido: " + _focused(), _focused().to_lower() == "corrida rápida")
	await _pad(JOY_BUTTON_DPAD_UP)
	await _pad(JOY_BUTTON_DPAD_UP)
	_check("↑ no primeiro item vai para o último: " + _focused(), _focused().to_lower() == "sair do jogo")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	_check("↓ no último volta para o primeiro: " + _focused(), _focused().to_lower() == "carreira")
	# nome do piloto na carreira: digitar direto pelo teclado
	main._show_driver_creation()
	await _wait(4)
	var le = get_root().gui_get_focus_owner()
	_check("foco inicial no campo do nome", le is LineEdit)
	if le is LineEdit:
		_check("campo do nome já em edição", le.is_editing())
		for ch in "Joao Silva":
			for on in [true, false]:
				var k := InputEventKey.new()
				k.keycode = OS.find_keycode_from_string(ch.to_upper()) if ch != " " else KEY_SPACE
				k.unicode = ch.unicode_at(0)
				k.pressed = on
				Input.parse_input_event(k)
				await _wait(1)
		_check("nome digitado: '%s'" % le.text, le.text == "Joao Silva")
	main._show_main()
	await _wait(3)
	# opções → editor de botões de toque (o foco lembra "Corrida rápida": 3 itens abaixo fica Opções)
	for k in 3:
		await _pad(JOY_BUTTON_DPAD_DOWN)
	_check("foco em Opções: " + _focused(), _focused().to_lower() == "opções")
	await _pad(JOY_BUTTON_A)
	_check("A abre opções", main.screen_id == "options")
	g.settings["input_mode"] = 3
	main._show_touch_editor(main._show_main)
	await _wait(4)
	_shot("ui_editor")
	var tc = main.screen.get_child(1)
	var vs: Vector2 = tc._vs()
	var lay: Dictionary = tc.layout()
	var start: Vector2 = lay["accelerate"][0] * vs
	await _touch(0, start, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = start + Vector2(-120, -60)
	Input.parse_input_event(drag)
	await _wait(2)
	await _touch(0, start + Vector2(-120, -60), false)
	var moved: Vector2 = tc.layout()["accelerate"][0] * vs
	_check("arrastar move o botão no editor (%.0f px)" % moved.distance_to(start), moved.distance_to(start) > 100.0)
	tc.reset_layout()
	await _pad(JOY_BUTTON_B)
	_check("B salva e volta para opções", main.screen_id == "options")
	# corrida com botões de toque
	g.settings["auto_gear"] = true
	main._start_quick()
	await _wait(10)
	var race = main.race
	_check("corrida iniciada com botões de toque", race != null and race.touch != null)
	if race == null or race.touch == null:
		print("FALHAS: ", fails)
		quit()
		return
	await create_timer(8.0).timeout
	_shot("ui_race_touch")
	var t2 = race.touch
	var l2: Dictionary = t2.layout()
	var acc: Vector2 = l2["accelerate"][0] * t2._vs()
	var left: Vector2 = l2["steer_left"][0] * t2._vs()
	await _touch(0, acc, true)
	await _touch(1, left, true)
	_check("dedo 1 acelera", Input.is_action_pressed("accelerate"))
	_check("dedo 2 vira à esquerda ao mesmo tempo", Input.is_action_pressed("steer_left"))
	var top := 0.0
	for k in 8:
		await create_timer(0.25).timeout
		top = maxf(top, race.player.vx)
	_check("kart acelerou com o toque (%.1f m/s)" % top, top > 3.0)
	await _touch(1, left, false)
	await _touch(0, acc, false)
	_check("soltar libera as ações", not Input.is_action_pressed("accelerate") and not Input.is_action_pressed("steer_left"))
	var pz: Vector2 = l2["pause"][0] * t2._vs()
	await _touch(2, pz, true)
	await _touch(2, pz, false)
	_check("botão II pausa", race.paused)
	_shot("ui_pause")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_A)
	_check("pausa → Configurações do kart", race.hud.in_settings)
	var before_b := int(g.settings["brake_assist"])
	await _pad(JOY_BUTTON_DPAD_DOWN)
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	_check("D-pad muda a frenagem na corrida (%d → %d)" % [before_b, int(g.settings["brake_assist"])], int(g.settings["brake_assist"]) != before_b)
	await _pad(JOY_BUTTON_DPAD_DOWN)
	var tc_before: bool = race.player.tc
	await _pad(JOY_BUTTON_A)
	_check("controle de tração aplicado ao kart na hora", race.player.tc != tc_before)
	_shot("ui_pause_settings")
	await _pad(JOY_BUTTON_B)
	_check("B volta ao menu de pausa", race.paused and not race.hud.in_settings)
	g.settings["brake_assist"] = before_b
	g.settings["tc"] = tc_before
	g.settings["drive_mode"] = 0
	g.save_settings()
	await _pad(JOY_BUTTON_A)
	_check("A no menu de pausa continua a corrida", not race.paused)
	g.settings["input_mode"] = 0
	g.save_settings()             # o editor de botões salvou o modo "toque"; desfaz
	print("FALHAS: ", fails)
	quit()
