extends Node
## TouchScroll — rolagem por arrasto (estilo celular) para TODOS os ScrollContainer do jogo.
##
## Bota o dedo em cima de qualquer opção de uma lista, arrasta pra cima/baixo
## e a lista acompanha o dedo; soltando rápido ela continua deslizando (inércia).
## Um toque curto sem arrastar continua funcionando como clique normal no botão.
##
## Instalação: Projeto > Configurações do Projeto > Globais (Autoload)
##   Caminho: res://scripts/touch_scroll.gd   Nome: TouchScroll
## Não precisa mexer em nenhum menu: o script acha os ScrollContainer sozinho.
##
## Ajustes para este projeto (em relação ao patch original):
## - arrasto que começa na barra de rolagem, num slider, num campo de texto ou numa prévia 3D
##   (kart da garagem, que gira arrastando) fica com esse controle;
## - os ScrollContainer são guardados numa lista atualizada por node_added, em vez de procurar na
##   árvore inteira a cada toque (na corrida a árvore tem milhares de nós e os botões de toque
##   da pilotagem gerariam uma busca a cada toque).

## Distância (px) que o dedo precisa andar pra virar arrasto em vez de toque.
const DRAG_THRESHOLD := 14.0
## Quanto maior, mais rápido a inércia para depois de soltar o dedo.
const FRICTION := 4.0
const MIN_FLING_SPEED := 40.0
const MAX_FLING_SPEED := 6000.0
## Se o dedo ficou parado mais que isso antes de soltar, não tem inércia.
const FLING_MAX_IDLE_MS := 80

var _scroll: ScrollContainer = null
var _pressing := false
var _dragging := false
var _swallow_until_release := false
var _start_pos := Vector2.ZERO
var _start_scroll := Vector2.ZERO
var _can_h := false
var _can_v := false
var _velocity := Vector2.ZERO
var _last_motion_ms := 0

var _fling: ScrollContainer = null
var _fling_pos := Vector2.ZERO
var _fling_last_us := 0

var _injecting := false
var _scrolls: Array[ScrollContainer] = []


func _ready() -> void:
	# Continua funcionando em menus de pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "ScrollContainer", true, false):
		_on_node_added(node)


func _on_node_added(node: Node) -> void:
	if node is ScrollContainer and not _scrolls.has(node):
		_scrolls.append(node)
		node.tree_exiting.connect(func(): _scrolls.erase(node), CONNECT_ONE_SHOT)


func _input(event: InputEvent) -> void:
	if _injecting:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release()
		return

	if event is InputEventMouseMotion and _pressing:
		_on_motion(event)


func _on_press(pos: Vector2) -> void:
	var sc := _find_scroll_at(pos)
	if sc != null and _blocked_at(sc, pos):
		sc = null

	# Toque numa lista que ainda está deslizando: só para a lista (igual celular),
	# sem clicar no botão que estiver embaixo do dedo.
	if _fling != null and is_instance_valid(_fling) and sc == _fling:
		_swallow_until_release = true
		get_viewport().set_input_as_handled()
	_fling = null
	_velocity = Vector2.ZERO

	_scroll = sc
	_pressing = sc != null
	_dragging = false
	if sc == null:
		return

	_start_pos = pos
	_start_scroll = Vector2(sc.scroll_horizontal, sc.scroll_vertical)
	_can_h = _max_scroll(sc).x > 0.0 and sc.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	_can_v = _max_scroll(sc).y > 0.0 and sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	_last_motion_ms = Time.get_ticks_msec()


func _on_motion(event: InputEventMouseMotion) -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		_reset()
		return

	var delta: Vector2 = event.position - _start_pos
	if not _can_h:
		delta.x = 0.0
	if not _can_v:
		delta.y = 0.0

	if not _dragging:
		if delta.length() < DRAG_THRESHOLD:
			if _swallow_until_release:
				get_viewport().set_input_as_handled()
			return
		_dragging = true
		_cancel_gui_press()

	_set_scroll(_scroll, _start_scroll - delta)

	var v: Vector2 = -event.velocity
	if not _can_h:
		v.x = 0.0
	if not _can_v:
		v.y = 0.0
	_velocity = v.limit_length(MAX_FLING_SPEED)
	_last_motion_ms = Time.get_ticks_msec()

	# O botão embaixo do dedo não fica sabendo do arrasto.
	get_viewport().set_input_as_handled()


func _on_release() -> void:
	if _dragging or _swallow_until_release:
		get_viewport().set_input_as_handled()

	if _dragging and _scroll != null and is_instance_valid(_scroll):
		var idle := Time.get_ticks_msec() - _last_motion_ms
		if idle <= FLING_MAX_IDLE_MS and _velocity.length() > MIN_FLING_SPEED:
			_fling = _scroll
			_fling_pos = Vector2(_scroll.scroll_horizontal, _scroll.scroll_vertical)
			_fling_last_us = Time.get_ticks_usec()

	_reset()


func _reset() -> void:
	_scroll = null
	_pressing = false
	_dragging = false
	_swallow_until_release = false


func _process(_delta: float) -> void:
	if _fling == null:
		return
	if not is_instance_valid(_fling) or not _fling.is_visible_in_tree():
		_fling = null
		return

	# Tempo real (não depende de Engine.time_scale nem de pausa).
	var now := Time.get_ticks_usec()
	var dt := minf((now - _fling_last_us) / 1000000.0, 0.05)
	_fling_last_us = now

	_fling_pos += _velocity * dt
	var limit := _max_scroll(_fling)
	var clamped := _fling_pos.clamp(Vector2.ZERO, limit)
	if clamped.x != _fling_pos.x:
		_velocity.x = 0.0
	if clamped.y != _fling_pos.y:
		_velocity.y = 0.0
	_fling_pos = clamped
	_set_scroll(_fling, _fling_pos)

	_velocity *= exp(-FRICTION * dt)
	if _velocity.length() < MIN_FLING_SPEED:
		_fling = null


## Avisa a interface que o toque "saiu" do botão, pra ele não disparar
## quando o dedo for solto depois de arrastar a lista.
func _cancel_gui_press() -> void:
	var far := Vector2(-100000, -100000)
	_injecting = true

	var motion := InputEventMouseMotion.new()
	motion.position = far
	motion.global_position = far
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion, true)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = far
	release.global_position = far
	get_viewport().push_input(release, true)

	_injecting = false


func _set_scroll(sc: ScrollContainer, value: Vector2) -> void:
	var v := value.clamp(Vector2.ZERO, _max_scroll(sc))
	if _can_h or sc == _fling:
		sc.scroll_horizontal = int(round(v.x))
	if _can_v or sc == _fling:
		sc.scroll_vertical = int(round(v.y))


func _max_scroll(sc: ScrollContainer) -> Vector2:
	var h := sc.get_h_scroll_bar()
	var v := sc.get_v_scroll_bar()
	return Vector2(
		maxf(0.0, h.max_value - h.page),
		maxf(0.0, v.max_value - v.page)
	)


## Acha o ScrollContainer (o mais interno, se tiver um dentro do outro)
## que está embaixo do dedo e que realmente tem conteúdo pra rolar.
func _find_scroll_at(pos: Vector2) -> ScrollContainer:
	var best: ScrollContainer = null
	var best_depth := -1
	var vp := get_viewport()
	for sc in _scrolls:
		if not is_instance_valid(sc) or not sc.is_visible_in_tree() or sc.get_viewport() != vp:
			continue
		var m := _max_scroll(sc)
		if m.x <= 0.0 and m.y <= 0.0:
			continue
		if not _hit(sc, pos):
			continue
		var depth := sc.get_path().get_name_count()
		if depth > best_depth:
			best_depth = depth
			best = sc
	return best


## true se o toque começou num controle que usa o arrasto para si: barra de rolagem, slider,
## campo de texto ou prévia 3D (o kart da garagem gira arrastando).
func _blocked_at(sc: ScrollContainer, pos: Vector2) -> bool:
	for bar in [sc.get_v_scroll_bar(), sc.get_h_scroll_bar()]:
		if bar.is_visible_in_tree() and _hit(bar, pos):
			return true
	var stack: Array[Node] = [sc]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			var ctl := c as Control
			if ctl == null or not ctl.is_visible_in_tree() or not _hit(ctl, pos):
				continue
			if ctl is Range or ctl is LineEdit or ctl is TextEdit or ctl is SubViewportContainer:
				return true
			stack.push_back(ctl)
	return false


func _hit(ctl: Control, pos: Vector2) -> bool:
	var local: Vector2 = ctl.get_global_transform_with_canvas().affine_inverse() * pos
	return Rect2(Vector2.ZERO, ctl.size).has_point(local)
