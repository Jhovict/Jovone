extends Control
## Botões de toque para celular/tablet. Cada botão gera as mesmas ações do teclado e do controle
## (InputEventAction), com vários dedos ao mesmo tempo; arrastar o dedo de um botão a outro troca
## de botão (útil na direção). No modo de edição, arrastar move o botão e a seleção pode mudar de tamanho.
## As posições ficam em Game.settings["touch_layout"]: centro em fração da tela e raio em fração da altura.

signal selected(id: String)

const BUTTONS := {
	"steer_left": {"label": "◀", "pos": Vector2(0.075, 0.80), "r": 0.105},
	"steer_right": {"label": "▶", "pos": Vector2(0.215, 0.80), "r": 0.105},
	"accelerate": {"label": "ACEL.", "pos": Vector2(0.915, 0.70), "r": 0.115},
	"brake": {"label": "FREIO", "pos": Vector2(0.785, 0.84), "r": 0.10},
	"gear_up": {"label": "+", "pos": Vector2(0.93, 0.40), "r": 0.065},
	"gear_down": {"label": "−", "pos": Vector2(0.84, 0.48), "r": 0.065},
	"camera": {"label": "CÂM", "pos": Vector2(0.84, 0.30), "r": 0.05},
	"reset_car": {"label": "R", "pos": Vector2(0.335, 0.87), "r": 0.05},
	"pit": {"label": "BOX", "pos": Vector2(0.745, 0.30), "r": 0.05},
	"pause": {"label": "II", "pos": Vector2(0.6, 0.075), "r": 0.045},
}

var editing := false
var selected_id := ""
var _touch := {}      # dedo -> id do botão pressionado (ou arrastado na edição)
var _grab := {}       # dedo -> deslocamento entre o dedo e o centro (edição)
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	get_viewport().size_changed.connect(queue_redraw)


static func layout() -> Dictionary:
	## Posições salvas, completando com o padrão os botões que não foram movidos.
	var saved: Dictionary = Game.settings.get("touch_layout", {})
	var out := {}
	for id in BUTTONS.keys():
		var d: Dictionary = BUTTONS[id]
		var s = saved.get(id)
		if s is Array and s.size() == 3:
			out[id] = [Vector2(float(s[0]), float(s[1])), float(s[2])]
		else:
			out[id] = [d["pos"], float(d["r"])]
	return out


static func should_show() -> bool:
	return Game.touch_buttons()


func _vs() -> Vector2:
	## Tamanho da tela; os toques chegam em coordenadas da janela.
	return get_viewport_rect().size


func _center(id: String, lay: Dictionary) -> Vector2:
	return lay[id][0] * _vs()


func _radius(id: String, lay: Dictionary) -> float:
	return lay[id][1] * _vs().y


func _hit(p: Vector2) -> String:
	var lay := layout()
	var best := ""
	var best_d := INF
	for id in lay.keys():
		var d := p.distance_to(_center(id, lay))
		# área de toque um pouco maior que o desenho
		if d < _radius(id, lay) * 1.15 and d < best_d:
			best = id
			best_d = d
	return best


func _input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			var id := _hit(t.position)
			if id == "":
				return
			_touch[t.index] = id
			if editing:
				selected_id = id
				_grab[t.index] = _center(id, layout()) - t.position
				selected.emit(id)
				queue_redraw()
			else:
				_press(id, true)
			get_viewport().set_input_as_handled()
		elif _touch.has(t.index):
			if not editing:
				_press(_touch[t.index], false)
			_touch.erase(t.index)
			_grab.erase(t.index)
			queue_redraw()
			get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag:
		var dr := e as InputEventScreenDrag
		if not _touch.has(dr.index):
			# dedo que começou fora de um botão e entrou nele (ex.: deslizar na direção)
			if editing:
				return
			var id0 := _hit(dr.position)
			if id0 != "":
				_touch[dr.index] = id0
				_press(id0, true)
				get_viewport().set_input_as_handled()
			return
		if editing:
			var id: String = _touch[dr.index]
			var lay := layout()
			var c: Vector2 = (dr.position + _grab[dr.index]) / _vs()
			c = c.clamp(Vector2(0.02, 0.03), Vector2(0.98, 0.97))
			_store(id, c, lay[id][1])
			queue_redraw()
		else:
			var now := _hit(dr.position)
			var was: String = _touch[dr.index]
			if now != was:
				_press(was, false)
				if now != "":
					_touch[dr.index] = now
					_press(now, true)
				else:
					_touch.erase(dr.index)
				queue_redraw()
		get_viewport().set_input_as_handled()


func _press(id: String, on: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = id
	ev.pressed = on
	ev.strength = 1.0 if on else 0.0
	Input.parse_input_event(ev)
	queue_redraw()


func release_all() -> void:
	if not editing:
		for idx in _touch.keys():
			_press(_touch[idx], false)
	_touch.clear()
	_grab.clear()


func _exit_tree() -> void:
	release_all()


func resize_selected(step: float) -> void:
	if selected_id == "":
		return
	var lay := layout()
	_store(selected_id, lay[selected_id][0], clampf(lay[selected_id][1] + step, 0.035, 0.2))
	queue_redraw()


func reset_layout() -> void:
	Game.settings["touch_layout"] = {}
	queue_redraw()


func _store(id: String, c: Vector2, r: float) -> void:
	var saved: Dictionary = Game.settings.get("touch_layout", {})
	saved[id] = [snappedf(c.x, 0.001), snappedf(c.y, 0.001), snappedf(r, 0.001)]
	Game.settings["touch_layout"] = saved


func _draw() -> void:
	var lay := layout()
	var held := {}
	for idx in _touch.keys():
		held[_touch[idx]] = true
	for id in lay.keys():
		var c := _center(id, lay)
		var r := _radius(id, lay)
		var on: bool = held.has(id)
		var fill := Color(1, 1, 1, 0.32) if on else Color(0.05, 0.07, 0.14, 0.38)
		if editing and id == selected_id:
			fill = Color(0.95, 0.3, 0.2, 0.45)
		draw_circle(c, r, fill)
		draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.75 if on else 0.5), 3.0, true)
		var text: String = BUTTONS[id]["label"]
		var fs := int(clampf(r * (0.75 if text.length() <= 2 else 0.36), 12.0, 64.0))
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(_font, c + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.9))
