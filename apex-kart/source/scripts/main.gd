extends Node
## Fluxo de telas: título, menu principal, configuração de sessões, opções,
## modo carreira (recrutamento, escritório, temporadas) e resultados.

const TrophyPreview := preload("res://scripts/trophy_preview.gd")
const TrophyModel := preload("res://scripts/trophy_model.gd")
const RaceScript := preload("res://scripts/race.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")
const FrameScript := preload("res://scripts/menu_frame.gd")
const FONT_TITLE := preload("res://fonts/ChakraPetch-BoldItalic.ttf")
const FONT_TEXT := preload("res://fonts/ChakraPetch-SemiBoldItalic.ttf")
const FONT_PLAIN := preload("res://fonts/ChakraPetch-SemiBold.ttf")
const HERO_TOP := preload("res://ui/menu_kart.png")
const HERO_SIDE := preload("res://ui/menu_kart.png")
const HERO_FRONT := preload("res://ui/menu_kart.png")
const INK := Color("edf2f8")
const TIPS := [
	"Kart não tem suspensão: passar por cima da zebra alta tira as rodas internas do chão e faz o kart escorregar.",
	"No kart de câmbio, reduzir marchas cedo demais é recusado para proteger o motor. Reduza perto do ponto de frenagem.",
	"As placas de 150, 100 e 50 metros marcam as freadas mais fortes. Use-as como referência nas primeiras voltas.",
	"Na chuva a aderência cai cerca de 30%. Frear com o kart reto evita que as rodas travem.",
	"A brita nas saídas de curva freia o kart e reduz a aderência. Voltar à pista com o volante reto é mais rápido.",
	"Andar logo atrás de outro kart reduz o arrasto. Saia do vácuo no fim da reta para ultrapassar.",
	"Pneus gastos perdem até 12% de aderência. Derrapar e travar rodas acelera o desgaste.",
	"Na carreira, bater a meta do teste de recrutamento abre as portas de uma equipe. Você tem duas tentativas.",
	"Em Opções você escolhe o controle usado e pode reposicionar os botões de toque.",
]

const ACCENT := Color(0.86, 0.1, 0.12)
const NAVY := Color(0.06, 0.09, 0.2)

var ui: CanvasLayer
var bg: Control                  # moldura dos menus (scripts/menu_frame.gd)
var page_hint := ""
var screen_extras: Array = []      # nós fora do contêiner da página (ex.: kart girando), apagados com ela
var screen: Control
var page_scroll: ScrollContainer   # rolagem da página atual (tabelas e textos longos)
var race = null
var back_cb := Callable()
var screen_id := ""
var theme_main: Theme
var title_font: Font
var rebinding := ""
var career_dirty := false
var qr := {"team": 0, "track": 0, "laps": 1, "weather": 0, "opp": 2}
var tt := {"team": 0, "track": 0, "weather": 0}
var weekend_grid: Array = []
var test_args := {}


func _ready() -> void:
	_parse_args()
	_make_theme()
	ui = CanvasLayer.new()
	add_child(ui)
	bg = FrameScript.new()
	ui.add_child(bg)
	bg.controls = _controls_hint()
	if test_args.has("autotest") or test_args.has("shot"):
		call_deferred("_run_test")
		return
	if test_args.has("flowtest"):
		call_deferred("_flow_test")
		return
	_show_title()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var parts: PackedStringArray = a.trim_prefix("--").split("=")
		test_args[parts[0]] = parts[1] if parts.size() > 1 else "1"


func _make_theme() -> void:
	theme_main = Theme.new()
	theme_main.default_font = FONT_PLAIN
	theme_main.default_font_size = 20
	title_font = FONT_TITLE
	for state in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("172334") if state == "normal" else Color("22384d")
		if state == "disabled": box.bg_color = Color("121b28")
		box.border_color = Color("54d7e4") if state == "focus" else Color("304257")
		box.set_border_width_all(2 if state == "focus" else 1)
		box.set_corner_radius_all(8)
		box.content_margin_left = 20
		box.content_margin_right = 20
		box.content_margin_top = 12
		box.content_margin_bottom = 12
		if state == "focus": box.bg_color = Color(0,0,0,0)
		theme_main.set_stylebox(state,"Button",box)
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:
		theme_main.set_color(state,"Button",INK)
	theme_main.set_color("font_disabled_color","Button",Color("768395"))
	theme_main.set_font("font","Button",FONT_PLAIN)
	theme_main.set_font_size("font_size","Button",21)
	theme_main.set_font("font","Label",FONT_PLAIN)
	theme_main.set_color("font_color","Label",INK)
	var field := StyleBoxFlat.new()
	field.bg_color = Color("101a28")
	field.border_color = Color("52677e")
	field.set_border_width_all(1)
	field.set_corner_radius_all(6)
	field.content_margin_left = 16
	field.content_margin_right = 16
	field.content_margin_top = 12
	field.content_margin_bottom = 12
	theme_main.set_stylebox("normal","LineEdit",field)
	var focused: StyleBoxFlat = field.duplicate()
	focused.border_color = Color("54d7e4")
	focused.set_border_width_all(2)
	theme_main.set_stylebox("focus","LineEdit",focused)
	theme_main.set_color("font_color","LineEdit",INK)
	theme_main.set_color("caret_color","LineEdit",INK)
	theme_main.set_font_size("font_size","LineEdit",22)


func _controls_hint() -> String:
	match int(Game.settings.get("input_mode", 0)):
		1:
			return "ENTER  SELEC.     ESC  VOLTAR"
		2:
			return "A  SELEC.     B  VOLTAR"
		3:
			return "TOQUE PARA SELECIONAR"
	return "A / ENTER  SELEC.     B / ESC  VOLTAR"


static var _chevron_tex: ImageTexture
static func _chevron() -> ImageTexture:
	## Seta dupla vermelha (»») que marca o item em foco.
	if _chevron_tex == null:
		var img := Image.create(40, 28, false, Image.FORMAT_RGBA8)
		for y in 28:
			for x in 40:
				var dy := absf(y - 13.5)
				var on := false
				for x0 in [2.0, 19.0]:
					var lx: float = x - x0 - (13.5 - dy) * 0.75
					if lx >= 0.0 and lx < 9.0:
						on = true
				if on:
					img.set_pixel(x, y, Color(0.88, 0.08, 0.1))
		_chevron_tex = ImageTexture.create_from_image(img)
	return _chevron_tex


# ---------------------------------------------------------------- utilidades de tela

func _clear() -> void:
	if screen:
		screen.queue_free()
	screen = null
	for n in screen_extras:
		if is_instance_valid(n):
			n.queue_free()
	screen_extras.clear()
	back_cb = Callable()


func _page(title: String, subtitle := "", wide := false, hero: Texture2D = null) -> VBoxContainer:
	## Página na moldura: título na faixa de cima, dica (subtítulo ou item em foco) na faixa quadriculada.
	_clear()
	bg.visible = true
	bg.controls = _controls_hint()
	page_hint = subtitle
	bg.set_page(title, subtitle, null if wide else (hero if hero else HERO_TOP), wide)
	var vs := get_viewport().get_visible_rect().size
	var top := 126.0
	var hint_y := vs.y - 100.0
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.theme = theme_main
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", int(vs.x * (0.04 if wide else 0.48)))
	margin.add_theme_constant_override("margin_top", int(top))
	margin.add_theme_constant_override("margin_bottom", int(vs.y - hint_y + 12.0))
	ui.add_child(margin)
	screen = margin
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true          # a navegação pelo controle rola a página
	margin.add_child(sc)
	page_scroll = sc
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	return vb


func _menu_item(b: Button, hint: String) -> void:
	b.focus_entered.connect(func():
		bg.set_hint(hint if hint != "" else page_hint)
		Game.sfx("move"))
	b.mouse_entered.connect(func():
		if not b.disabled: b.grab_focus())


func _btn(parent: Control, text: String, cb: Callable, enabled := true, hint := "") -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.custom_minimum_size = Vector2(0, 56)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(func():
		Game.sfx("ok")
		last_focus[screen_id] = b.text      # ao voltar para esta tela, o foco volta para este item
		cb.call())
	parent.add_child(b)
	_menu_item(b, hint)
	return b


func _label(parent: Control, text: String, size := 20, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 0
	parent.add_child(l)
	return l


func _selector(parent: Control, label: String, options: Array, current: int, on_change: Callable, hint := "") -> Button:
	var b := Button.new()
	b.text = label.to_upper()
	b.custom_minimum_size = Vector2(0,72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	b.tooltip_text = label
	# The button retains its accessible name; labels own distinct layout columns.
	for state in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:
		b.add_theme_color_override(state,Color.TRANSPARENT)
	var box := HBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 18
	box.offset_right = -18
	box.offset_top = 10
	box.offset_bottom = -10
	box.add_theme_constant_override("separation",16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var name_label := Label.new()
	name_label.text = label
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_stretch_ratio = 1.0
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size",19)
	name_label.add_theme_color_override("font_color",Color("c1cede"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var val := Label.new()
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val.size_flags_stretch_ratio = 1.15
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_size_override("font_size",19)
	val.add_theme_color_override("font_color",Color("67e0e8"))
	val.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(val)
	var arrow := Label.new()
	arrow.text = "‹   ›"
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_color_override("font_color",Color("67e0e8"))
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(arrow)

	var st := {"i": clampi(current, 0, options.size() - 1)}
	var refresh := func():
		val.text = str(options[st["i"]])
	refresh.call()
	var change := func(step: int):
		st["i"] = (st["i"] + step + options.size()) % options.size()
		refresh.call()
		on_change.call(st["i"])
		Game.sfx("move")
	b.pressed.connect(func(): change.call(1))
	b.gui_input.connect(func(ev: InputEvent):
		# toque/clique na seta da esquerda (ou na metade esquerda do valor) volta uma opção
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and ev.position.x > b.size.x * .48 and ev.position.x < b.size.x * .74:
			change.call(-1)
			b.accept_event()
		elif ev.is_action_pressed("ui_left"):
			change.call(-1)
			b.accept_event()
		elif ev.is_action_pressed("ui_right"):
			change.call(1)
			b.accept_event())
	parent.add_child(b)
	_menu_item(b, hint)
	return b


var last_focus := {}     # tela -> texto do último botão escolhido nela


func _focus_first(vb: Control) -> void:
	## Foco inicial da página: o item escolhido da última vez nesta tela (ou o primeiro). A lista dá a
	## volta: ↑ no primeiro item vai para o último e ↓ no último volta para o primeiro.
	var items: Array = []
	_focusables(vb, items)
	if items.is_empty():
		return
	var first: Control = items[0]
	var last: Control = items[items.size() - 1]
	if items.size() > 1:
		first.focus_neighbor_top = first.get_path_to(last)
		last.focus_neighbor_bottom = last.get_path_to(first)
	var pick: Control = first
	var want: String = last_focus.get(screen_id, "")
	for c in items:
		if c is Button and want != "" and (c as Button).text == want:
			pick = c
			break
	pick.call_deferred("grab_focus")
	if items.size()==1 and pick is Button and pick.text=="VOLTAR":
		_reset_table_scroll.call_deferred(vb)


func _reset_table_scroll(vb: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(vb) and vb.get_parent() is ScrollContainer:
		vb.get_parent().scroll_vertical = 0


func _focusables(node: Node, out: Array) -> void:
	for c in node.get_children():
		if (c is Button and not c.disabled) or c is LineEdit:
			out.append(c)
		elif c is Container:
			_focusables(c, out)


func _table(parent: Control, headers: Array, rows: Array, widths: Array, highlight := -1) -> void:
	var total := 0.0
	for width in widths: total += float(width)
	var factor := (get_viewport().get_visible_rect().size.x-136.0)/maxf(total,1)
	var grid := GridContainer.new()
	grid.columns = headers.size()
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	parent.add_child(grid)
	for k in headers.size():
		grid.add_child(_cell(str(headers[k]), float(widths[k])*factor, Color("30465f"), Color.WHITE))
	for ri in rows.size():
		var row: Array = rows[ri]
		var hl := ri == highlight
		for k in row.size():
			var bgc := (Color("172334") if ri % 2 == 0 else Color("111d2c")) if not hl else Color("234751")
			if k == 0:
				bgc = Color(0.17, 0.2, 0.36) if not hl else ACCENT
			grid.add_child(_cell(str(row[k]), float(widths[k])*factor, bgc, INK))


func _cell(text: String, w: float, bgc: Color, fg: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bgc
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(w, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_PASS     # arrastar no toque/mouse rola a página
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", fg)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.tooltip_text = text
	pc.add_child(l)
	return pc


func _confirm(title: String, text: String, yes_text: String, on_yes: Callable, on_no: Callable) -> void:
	var vb := _page(title, text)
	_btn(vb, yes_text, on_yes)
	_btn(vb, "Cancelar", on_no)
	back_cb = on_no
	_focus_first(vb)


func _unhandled_input(e: InputEvent) -> void:
	if race != null:
		return
	if screen_id == "title":
		if (e is InputEventKey or e is InputEventJoypadButton or e is InputEventMouseButton or e is InputEventScreenTouch) and e.is_pressed():
			get_viewport().set_input_as_handled()
			Game.sfx("ok")
			_show_main()
		return
	if e.is_action_pressed("ui_cancel") and back_cb.is_valid():
		get_viewport().set_input_as_handled()
		Game.sfx("back")
		back_cb.call()


func _process(delta: float) -> void:
	# analógico direito rola tabelas e textos longos (classificação, resultados, regulamento)
	if race != null or not is_instance_valid(page_scroll) or not page_scroll.is_visible_in_tree():
		return
	var ay := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(ay) > 0.2:
		page_scroll.scroll_vertical += int(ay * 900.0 * delta)


func _input(e: InputEvent) -> void:
	if rebinding == "":
		_scroll_input(e)
		return
	if not e.is_pressed() or e.is_echo():
		return
	if e is InputEventKey:
		get_viewport().set_input_as_handled()
		var action := rebinding
		rebinding = ""
		if e.physical_keycode != KEY_ESCAPE or action == "pause":
			Game.set_key(action, e.physical_keycode)
		_show_controls()
	elif e is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
		var action := rebinding
		rebinding = ""
		# B cancela (é o "voltar" dos menus)
		if e.button_index != JOY_BUTTON_B:
			Game.set_pad(action, e.button_index)
		_show_controls()


func _scroll_input(e: InputEvent) -> void:
	## ↑/↓ (teclado, D-pad, analógico) rolam a página quando não há outro botão nessa direção, então dá
	## para ler a tabela inteira com o foco no único botão (VOLTAR).
	if race != null or not is_instance_valid(page_scroll) or not page_scroll.is_visible_in_tree():
		return
	var up := e.is_action_pressed("ui_up", true)
	var down := e.is_action_pressed("ui_down", true)
	if not up and not down:
		return
	var bar := page_scroll.get_v_scroll_bar()
	if bar == null or bar.max_value <= page_scroll.size.y + 1.0:
		return
	var f := get_viewport().gui_get_focus_owner()
	if f != null:
		var nb := f.find_valid_focus_neighbor(SIDE_TOP if up else SIDE_BOTTOM)
		if nb != null and nb != f:
			return
	page_scroll.scroll_vertical += -140 if up else 140
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# botão "voltar" do Android: pausa na corrida, volta uma tela nos menus
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if race != null:
			race.toggle_pause()
		elif screen_id == "title":
			_quit_game()
		elif back_cb.is_valid():
			Game.sfx("back")
			back_cb.call()


# ---------------------------------------------------------------- título e menu principal

func _show_title() -> void:
	## Tela inicial: logotipo, kart em movimento e "pressione start" (desenhados pela moldura).
	_clear()
	screen_id = "title"
	bg.visible = true
	bg.mode = "title"
	bg.hero = HERO_SIDE
	bg.queue_redraw()
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE     # o clique/toque chega ao _unhandled_input
	ui.add_child(c)
	screen = c


func _show_main() -> void:
	screen_id = "main"
	var vb := _page("Menu principal", "Escolha um modo de jogo.")
	_btn(vb, "Carreira", _career_entry, true, "Do teste de recrutamento ao título: crie seu piloto, entre numa equipe e dispute as temporadas.")
	_btn(vb, "Corrida rápida", _show_quick, true, "Uma corrida avulsa: escolha equipe, pista, voltas, clima e adversários.")
	_btn(vb, "Fim de semana de GP", _show_weekend, true, "Classificação e corrida largando da posição conquistada.")
	_btn(vb, "Contrarrelógio", _show_tt, true, "Sozinho na pista atrás do recorde de cada kartódromo.")
	_btn(vb, "Opções", _show_options.bind(_show_main), true, "Assistências, controle usado, botões de toque, câmera, som e qualidade.")
	_btn(vb, "Sair do jogo", _quit_game, true, "Fecha o jogo (no navegador, volta para o launcher).")
	back_cb = _show_title
	_focus_first(vb)


# ---------------------------------------------------------------- opções

func _show_options(back: Callable) -> void:
	screen_id = "options"
	var s := Game.settings
	var vb := _page("Opções", "Assistências afetam somente o seu kart. Cada opção tem efeito real na física ou na interface.", true)
	var on_off := ["Desligado", "Ligado"]
	_label(vb,"PILOTAGEM E ASSISTÊNCIAS",16,Color("67e0e8"))
	_selector(vb, "Modo de pilotagem", Game.DRIVE_MODES, int(s["drive_mode"]), func(i):
		Game.apply_drive_mode(i)
		_show_options(back), "Assistido: tração, ABS, estabilidade, frenagem leve, câmbio automático e linha ideal (o máximo de ajuda). Simulação: tudo desligado.")
	# mexer numa assistência isolada passa o modo para "Personalizado"
	var custom := func(): s["drive_mode"] = 0
	_selector(vb, "Controle de tração", on_off, int(s["tc"]), func(i):
		s["tc"] = i == 1
		custom.call())
	_selector(vb, "ABS", on_off, int(s["abs"]), func(i):
		s["abs"] = i == 1
		custom.call())
	_selector(vb, "Controle de estabilidade", on_off, int(s["stability"]), func(i):
		s["stability"] = i == 1
		custom.call())
	_selector(vb, "Assistência de frenagem", Game.BRAKE_ASSIST_NAMES, int(s["brake_assist"]), func(i):
		s["brake_assist"] = i
		custom.call(), "Leve: o jogo só freia quando você chega rápido demais numa curva.")
	_selector(vb, "Linha ideal virtual", on_off, int(s["racing_line"]), func(i): s["racing_line"] = i == 1)
	_selector(vb, "Câmbio", ["Manual", "Automático"], int(s["auto_gear"]), func(i): s["auto_gear"] = i == 1)
	var sens := [0.6, 0.8, 1.0, 1.2, 1.5]
	_selector(vb, "Sensibilidade da direção", ["60%", "80%", "100%", "120%", "150%"], maxi(0, sens.find(float(s["steer_sens"]))), func(i): s["steer_sens"] = sens[i])
	_label(vb,"CORRIDA E ADVERSÁRIOS",16,Color("67e0e8"))
	_selector(vb, "Danos", on_off, int(s["damage"]), func(i): s["damage"] = i == 1)
	_selector(vb, "Rádio da equipe", ["Desligado", "Ligado"], int(Game.settings.get("radio",true)), func(i): Game.settings["radio"] = i==1)
	_selector(vb, "Clima variável", ["Desligado", "Ligado"], int(Game.settings.get("weather_change",false)), func(i): Game.settings["weather_change"] = i==1, "Mudanças graduais entre seco e chuva nas corridas. Contrarrelógio, neve e tempestade mantêm condições fixas.")
	_selector(vb, "Volta fantasma", ["Desligada", "Ligada"], int(Game.settings.get("ghost",true)), func(i): Game.settings["ghost"] = i==1)
	_selector(vb, "Replay da chegada", ["Desligado", "Ligado"], int(Game.settings.get("finish_replay",true)), func(i): Game.settings["finish_replay"] = i==1)
	_selector(vb, "Dificuldade da IA", Game.DIFFICULTY_NAMES, int(s["difficulty"]), func(i): s["difficulty"] = i)
	_label(vb,"CÂMERA E SENSAÇÃO",16,Color("67e0e8"))
	_selector(vb, "Câmera inicial", Game.CAMERA_NAMES, int(s["camera"]), func(i): s["camera"] = i)
	_selector(vb, "Sensação de velocidade", Game.SPEED_FX_NAMES, int(s.get("speed_fx", 2)), func(i): s["speed_fx"] = i,
		"Campo de visão que abre com a velocidade, câmera que reage à aceleração e às curvas, vibração e riscos de vento na tela.")
	_label(vb,"ESTRATÉGIA E CARREIRA",16,Color("67e0e8"))
	_pit_selectors(vb)
	var laps := [3, 5, 8]
	_selector(vb, "Voltas na carreira", ["3", "5", "8"], maxi(0, laps.find(int(s["career_laps"]))), func(i): s["career_laps"] = laps[i])
	_label(vb,"ÁUDIO, CONTROLES E QUALIDADE",16,Color("67e0e8"))
	var vols := [0.0, 0.25, 0.5, 0.8, 1.0]
	_selector(vb, "Volume", ["Mudo", "25%", "50%", "80%", "100%"], maxi(0, vols.find(float(s["volume"]))), func(i): s["volume"] = vols[i])
	_selector(vb, "Controle usado", Game.INPUT_MODES, int(s["input_mode"]), func(i): s["input_mode"] = i)
	if not (OS.has_feature("web") or OS.has_feature("mobile")):
		_selector(vb, "Qualidade dos modelos", Game.QUALITY_NAMES, int(s["quality"]), func(i): s["quality"] = i)
	_btn(vb, "Posição dos botões de toque", func(): _show_touch_editor(back))
	_btn(vb, "Controles (teclado e controle)", _show_controls)
	var done := func():
		Game.save_settings()
		back.call()
	_btn(vb, "Salvar e voltar", done)
	back_cb = done
	set_meta("options_back", back)
	_focus_first(vb)


func _show_controls() -> void:
	screen_id = "controls"
	var vb := _page("Controles", "Escolha uma ação e pressione a nova tecla ou o novo botão do controle (B cancela). Setas, gatilhos e analógico continuam ativos. Nos menus: A confirma, B volta.")
	for action in Game.ACTIONS.keys():
		var a: String = action
		var b := _btn(vb, "%s:   %s   ·   %s" % [Game.ACTIONS[a], Game.key_name(a), Game.pad_name(a)], func(): pass)
		b.pressed.connect(func():
			rebinding = a
			b.text = "%s:   pressione uma tecla ou botão..." % Game.ACTIONS[a])
	_btn(vb, "Restaurar padrão", func():
		Game.reset_keys()
		_show_controls())
	var back: Callable = get_meta("options_back", Callable(self, "_show_main"))
	_btn(vb, "Voltar", _show_options.bind(back))
	back_cb = _show_options.bind(back)
	_focus_first(vb)


func _show_touch_editor(back: Callable) -> void:
	## Arraste os botões de toque para a posição desejada; toque num botão e ajuste o tamanho.
	_clear()
	screen_id = "touch_editor"
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.theme = theme_main
	ui.add_child(c)
	screen = c
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(shade)
	var tc = TouchScript.new()
	tc.editing = true
	c.add_child(tc)
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -330
	box.offset_right = 330
	box.offset_top = -95
	box.offset_bottom = 95
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(box)
	var hint := Label.new()
	hint.text = "Arraste os botões para mudar a posição.\nToque num botão e use Maior / Menor para o tamanho."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var sel := Label.new()
	sel.text = "Nenhum botão selecionado"
	sel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sel.add_theme_color_override("font_color", Color(1.0, 0.75, 0.3))
	box.add_child(sel)
	tc.selected.connect(func(id): sel.text = "Selecionado: " + Game.ACTIONS[id])
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var done := func():
		Game.save_settings()
		_show_options(back)
	for spec in [["Maior", func(): tc.resize_selected(0.01)], ["Menor", func(): tc.resize_selected(-0.01)],
			["Restaurar padrão", func(): tc.reset_layout()], ["Salvar e voltar", done]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(0, 48)
		var cb: Callable = spec[1]
		b.pressed.connect(func():
			Game.sfx("ok")
			cb.call())
		row.add_child(b)
	back_cb = done
	row.get_child(3).call_deferred("grab_focus")


func _quit_game() -> void:
	# no navegador, volta para o launcher Jovone Games
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = '../';")
	else:
		get_tree().quit()


func _random_name() -> String:
	var first := ["Rafael", "Lucas", "Diego", "Marina", "Bruna", "Caio", "Tiago", "Paula", "Igor", "Renata", "Hugo", "Lara"]
	var last := ["Moura", "Azevedo", "Prado", "Teixeira", "Barros", "Fontes", "Siqueira", "Valente", "Quintela", "Rocha"]
	return "%s %s" % [first[randi() % first.size()], last[randi() % last.size()]]


# ---------------------------------------------------------------- modos rápidos

func _track_names() -> Array:
	var out: Array = []
	for t in Game.tracks:
		out.append(t["name"])
	return out


func _team_names() -> Array:
	var out: Array = []
	for t in Game.teams:
		out.append(t["name"])
	return out


func _show_quick() -> void:
	screen_id = "quick"
	var vb := _page("Corrida rápida", "Escolha equipe, circuito e condições. A ordem do grid é sorteada pelo ritmo dos pilotos.")
	_selector(vb, "Equipe", _team_names(), qr["team"], func(i): qr["team"] = i)
	_selector(vb, "Circuito", _track_names(), qr["track"], func(i): qr["track"] = i)
	_selector(vb, "Voltas", ["3", "5", "8", "12"], qr["laps"], func(i): qr["laps"] = i)
	_selector(vb, "Clima inicial", Game.WEATHER_NAMES, qr["weather"], func(i): qr["weather"] = i, _weather_hint())
	_selector(vb, "Adversários", ["5", "10", "15"], qr["opp"], func(i): qr["opp"] = i)
	_pit_selectors(vb)
	_selector(vb, "Dificuldade", Game.DIFFICULTY_NAMES, int(Game.settings["difficulty"]), func(i): Game.settings["difficulty"] = i)
	_btn(vb, "Iniciar corrida", _start_quick)
	_btn(vb, "Voltar", _show_main)
	back_cb = _show_main
	_focus_first(vb)


func _pit_selectors(vb: Control) -> void:
	## Estratégia de corrida: paradas no box (combustível e pneus) e pneu da largada (no seco).
	var s := Game.settings
	_selector(vb, "Paradas no box", Game.PIT_STOP_NAMES, int(s["pit_stops"]), func(i): s["pit_stops"] = i,
		'"1 parada" ou "2 paradas": o tanque e os pneus duram uma parte da corrida, então é preciso parar no box (F, D-pad ↑ ou BOX chama a parada). "Sem estratégia": combustível não acaba e os pneus quase não gastam.')
	_selector(vb, "Pneu de largada", Game.START_TYRE_NAMES, int(s["start_tyre"]), func(i): s["start_tyre"] = i,
		"Macio: mais aderência, gasta 50% mais rápido. Duro: dura mais. Na chuva todos largam de pneu de chuva.")


func _weather_hint() -> String:
	return "Chuva: aderência cai ~30%. Tempestade: chuva forte, raios e pouca visibilidade (~40%). Neve: pista branca e escorregadia (~50%). Fora do seco todos usam pneu de chuva."


func _ai_field(player_team: int, count: int, exclude: Array) -> Array:
	## Adversários: tira um piloto da equipe do jogador para manter dois karts por equipe.
	var pool: Array = []
	var removed := false
	for d in Game.drivers:
		if exclude.has(d["code"]):
			continue
		if int(d["team"]) == player_team and not removed:
			removed = true
			continue
		pool.append(d)
	pool.shuffle()
	pool = pool.slice(0, mini(count, pool.size()))
	var key := {}
	for d in pool:
		key[d["code"]] = float(d["skill"]) * float(Game.teams[int(d["team"])]["perf"]) + randf() * 0.01
	pool.sort_custom(func(a, b): return key[a["code"]] > key[b["code"]])
	return pool


func _base_cfg(team: int) -> Dictionary:
	return {"player_team": team, "player_name": "Jogador", "player_code": "JOG", "player_num": 21, "helmet": 0,
		"difficulty": int(Game.settings["difficulty"])}


func _start_quick() -> void:
	var laps := [3, 5, 8, 12]
	var opps := [5, 10, 15]
	var field := _ai_field(qr["team"], opps[qr["opp"]], [])
	var cfg := _base_cfg(qr["team"])
	cfg.merge({"mode": "race", "track": qr["track"], "weather": Game.WEATHERS[qr["weather"]],
		"laps": laps[qr["laps"]], "field": field, "player_grid": field.size() / 2,
		"title": "Corrida rápida — " + Game.tracks[qr["track"]]["name"]})
	_start_session(cfg, func(res): _show_race_podium(res, func(): _show_race_results(res, _show_quick, {})))


func _show_tt() -> void:
	screen_id = "tt"
	var vb := _page("Contrarrelógio", "Voltas lançadas sozinho na pista. Cortar a pista invalida a volta.")
	_selector(vb, "Equipe", _team_names(), tt["team"], func(i): tt["team"] = i)
	_selector(vb, "Circuito", _track_names(), tt["track"], func(i): tt["track"] = i)
	_selector(vb, "Clima", Game.WEATHER_NAMES, tt["weather"], func(i): tt["weather"] = i, _weather_hint())
	_btn(vb, "Ir para a pista", _start_tt)
	_btn(vb, "Voltar", _show_main)
	var recs: Array = []
	for k in Game.tracks.size():
		var row: Array = [Game.tracks[k]["name"]]
		for w in Game.WEATHERS:
			row.append(Game.fmt_time(Game.record_for(k, w)))
		recs.append(row)
	_label(vb, "Recordes salvos", 22)
	_table(vb, ["Circuito"] + Game.WEATHER_NAMES, recs, [220, 120, 120, 130, 120])
	back_cb = _show_main
	_focus_first(vb)


func _start_tt() -> void:
	var cfg := _base_cfg(tt["team"])
	cfg.merge({"mode": "time_trial", "track": tt["track"], "weather": Game.WEATHERS[tt["weather"]],
		"timed_laps": 0, "title": "Contrarrelógio — " + Game.tracks[tt["track"]]["name"]})
	_start_session(cfg, _show_tt_results)


func _show_tt_results(res: Dictionary) -> void:
	var best: float = res["best"]
	var is_rec: bool = best < INF and Game.submit_record(res["track"], res["weather"], best, "Jogador")
	var vb := _page("Contrarrelógio — resultado", Game.tracks[res["track"]]["name"])
	_label(vb, "Melhor volta: %s%s" % [Game.fmt_time(best), "   NOVO RECORDE!" if is_rec else ""], 26)
	var rows: Array = []
	var laps: Array = res["laps"]
	for k in laps.size():
		rows.append([str(k + 1), Game.fmt_time(laps[k])])
	if rows.is_empty():
		_label(vb, "Nenhuma volta válida completada.")
	else:
		_table(vb, ["Volta", "Tempo"], rows, [80, 160])
	_btn(vb, "Correr de novo", _start_tt)
	_btn(vb, "Voltar", _show_tt)
	back_cb = _show_tt
	_focus_first(vb)


func _show_weekend() -> void:
	screen_id = "weekend"
	var vb := _page("Fim de semana de GP", "Classificação (sessão única de 3 voltas, formato simplificado deste jogo) e corrida largando na posição conquistada.")
	_selector(vb, "Equipe", _team_names(), qr["team"], func(i): qr["team"] = i)
	_selector(vb, "Circuito", _track_names(), qr["track"], func(i): qr["track"] = i)
	_selector(vb, "Voltas da corrida", ["3", "5", "8", "12"], qr["laps"], func(i): qr["laps"] = i)
	_selector(vb, "Clima inicial", Game.WEATHER_NAMES, qr["weather"], func(i): qr["weather"] = i, _weather_hint())
	_pit_selectors(vb)
	_selector(vb, "Dificuldade", Game.DIFFICULTY_NAMES, int(Game.settings["difficulty"]), func(i): Game.settings["difficulty"] = i)
	_btn(vb, "Ir para a classificação", _start_weekend_quali)
	_btn(vb, "Voltar", _show_main)
	back_cb = _show_main
	_focus_first(vb)


func _start_weekend_quali() -> void:
	var cfg := _base_cfg(qr["team"])
	var weather: String = Game.WEATHERS[qr["weather"]]
	cfg.merge({"mode": "qualifying", "track": qr["track"], "weather": weather, "timed_laps": 3,
		"title": "Classificação — " + Game.tracks[qr["track"]]["name"]})
	_start_session(cfg, func(res):
		var field := _ai_field(qr["team"], 15, [])
		var q := _quali_results(res, field, qr["track"], weather, "Jogador", "JOG", qr["team"])
		_show_quali_results(q, func(): _start_weekend_race(q, weather)))


func _quali_results(res: Dictionary, field: Array, track_idx: int, weather: String, pname: String, pcode: String, pteam: int) -> Array:
	## Tempos da IA estimados pelo perfil do circuito e pelo ritmo de cada piloto (aproximação).
	var est := Game.lap_estimate(track_idx, weather)
	var pace_mult: float = Game.DIFFICULTY_PACE[int(Game.settings["difficulty"])] * float(Game.WEATHER_PACE.get(weather, 1.0))
	var rows: Array = []
	for d in field:
		var perf: float = Game.team_perf(int(d["team"])) if not Game.career.is_empty() else float(Game.teams[int(d["team"])]["perf"])
		var pace: float = float(d["skill"]) * pace_mult * (0.5 + 0.5 * perf)
		rows.append({"code": d["code"], "name": d["name"], "team": int(d["team"]), "time": est / pace * 1.03 * randf_range(0.997, 1.008), "driver": d})
	rows.append({"code": pcode, "name": pname, "team": pteam, "time": res["best"], "player": true})
	rows.sort_custom(func(a, b): return a["time"] < b["time"])
	return rows


func _show_quali_results(rows: Array, next: Callable) -> void:
	var vb := _page("Classificação — resultado", "Grid de largada. Tempos dos adversários estimados por este jogo.", true)
	var table: Array = []
	var hl := -1
	for k in rows.size():
		var r: Dictionary = rows[k]
		if r.get("player", false):
			hl = k
		table.append([str(k + 1), r["name"], Game.teams[r["team"]]["name"], Game.fmt_time(r["time"])])
	_table(vb, ["Pos", "Piloto", "Equipe", "Tempo"], table, [60, 240, 240, 140], hl)
	_btn(vb, "Ir para a corrida", next)
	back_cb = Callable()
	_focus_first(vb)


func _grid_from_quali(rows: Array) -> Array:
	var field: Array = []
	var slot := 0
	for k in rows.size():
		var r: Dictionary = rows[k]
		if r.get("player", false):
			slot = k
		else:
			field.append(r["driver"])
	return [field, slot]


func _start_weekend_race(q: Array, weather: String) -> void:
	var laps := [3, 5, 8, 12]
	var g := _grid_from_quali(q)
	var cfg := _base_cfg(qr["team"])
	cfg.merge({"mode": "race", "track": qr["track"], "weather": weather, "laps": laps[qr["laps"]],
		"field": g[0], "player_grid": g[1], "title": "Corrida — " + Game.tracks[qr["track"]]["name"]})
	_start_session(cfg, func(res): _show_race_podium(res, func(): _show_race_results(res, _show_weekend, {})))


func _show_race_results(res: Dictionary, next: Callable, points: Dictionary) -> void:
	var title := "Resultado da corrida"
	var vb := _page(title, Game.tracks[res["track"]]["name"] + "  ·  " + Game.weather_name(res["weather"]).to_lower(), true)
	var rows: Array = []
	var hl := -1
	var cls: Array = res.get("classification", [])
	var lead_time := 0.0
	if cls.size() > 0:
		lead_time = cls[0]["time"]
	var best_lap := INF
	var best_who := ""
	for r in cls:
		if r["best"] < best_lap:
			best_lap = r["best"]
			best_who = r["name"]
	for k in cls.size():
		var r: Dictionary = cls[k]
		if r["player"]:
			hl = k
		var tstr := ""
		match r["status"]:
			"dnf":
				tstr = "Abandonou"
			"lapped":
				tstr = "+%d volta(s)" % maxi(1, int(res["cfg"]["laps"]) - int(r["laps"]))
			_:
				tstr = Game.fmt_time(r["time"]) if k == 0 else "+%.3f" % (float(r["time"]) - lead_time)
		if r["penalty"] > 0.0:
			tstr += " (pen. %ds)" % int(r["penalty"])
		var pts := ""
		if k < Game.POINTS.size() and r["status"] != "dnf":
			pts = str(Game.POINTS[k])
		rows.append([str(k + 1) if r["status"] != "dnf" else "-", r["name"], Game.teams[r["team"]]["name"], tstr, Game.fmt_time(r["best"]), pts])
	_table(vb, ["Pos", "Piloto", "Equipe", "Tempo", "Melhor volta", "Pts"], rows, [56, 220, 220, 170, 130, 50], hl)
	_label(vb, "Volta mais rápida: %s  %s" % [best_who, Game.fmt_time(best_lap)], 18)
	if not points.is_empty():
		_label(vb, str(points.get("note", "")), 18)
	_btn(vb, "Continuar", next)
	back_cb = Callable()
	_focus_first(vb)


# ---------------------------------------------------------------- sessões

func _start_session(cfg: Dictionary, on_done: Callable) -> void:
	_clear()
	# tela de carregamento com dica enquanto o kartódromo é montado
	bg.visible = true
	bg.mode = "loading"
	bg.hero = HERO_SIDE
	bg.tip = TIPS[randi() % TIPS.size()]
	bg.queue_redraw()
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(c)
	screen = c
	for k in 3:
		await get_tree().process_frame
	_clear()
	screen_id = "session"
	race = RaceScript.new()
	add_child(race)
	race.setup(cfg)
	race.hud.pause_panel.theme = theme_main
	bg.visible = false
	race.finished.connect(func(res): _end_session(res, on_done), CONNECT_DEFERRED)
	race.restart_requested.connect(func(): _restart_session(cfg, on_done), CONNECT_DEFERRED)


func _end_session(res: Dictionary, on_done: Callable) -> void:
	if race:
		race.queue_free()
		race = null
	bg.visible = true
	on_done.call(res)


func _restart_session(cfg: Dictionary, on_done: Callable) -> void:
	if race:
		race.queue_free()
		race = null
	_start_session(cfg, on_done)


# ---------------------------------------------------------------- carreira

func _career_entry() -> void:
	screen_id = "career_entry"
	var vb := _page("Carreira", "Comece como candidato, passe no teste de recrutamento e suba de piloto de testes a primeiro piloto ao longo de até %d temporadas." % Game.MAX_SEASONS)
	if Game.career_exists():
		_btn(vb, "Continuar carreira salva", func():
			if Game.load_career():
				career_dirty = false
				_career_resume()
			else:
				_label(vb, "Não foi possível ler o arquivo de carreira.", 18, Color(1, 0.5, 0.4)))
		_btn(vb, "Nova carreira", func():
			_confirm("Nova carreira", "Já existe uma carreira salva. Ela só será substituída quando você salvar a nova carreira.", "Criar nova carreira", _show_driver_creation, _career_entry))
	else:
		_btn(vb, "Nova carreira", _show_driver_creation)
	_btn(vb, "Voltar", _show_main)
	back_cb = _show_main
	_focus_first(vb)


func _career_resume() -> void:
	if Game.career["role"] == "candidate":
		_show_team_selection()
	else:
		_show_office()


func _show_driver_creation() -> void:
	screen_id = "creation"
	var vb := _page("Detalhes do piloto", "Esses dados ficam com você durante toda a carreira.")
	var data := {"nation": 0, "helmet": 0}
	var preview = _kart_preview(Color.WHITE)
	preview.set_design(0)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	vb.add_child(row)
	var nl := Label.new()
	nl.text = "NOME"
	nl.add_theme_font_override("font", FONT_TITLE)
	nl.add_theme_font_size_override("font_size", 27)
	nl.add_theme_color_override("font_color", INK)
	nl.custom_minimum_size.x = 160
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(nl)
	var le := LineEdit.new()
	le.name = "driver_name"
	le.placeholder_text = "Ex.: Rafael Moura"
	le.max_length = 24
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.custom_minimum_size = Vector2(0, 56)
	le.virtual_keyboard_enabled = true
	le.select_all_on_focus = true   # digitar substitui o nome sorteado
	le.text = _random_name()        # quem joga no controle não precisa digitar
	le.focus_entered.connect(func():
		bg.set_hint("Digite o nome do piloto e confirme com Enter (no celular, toque para abrir o teclado).")
		# no teclado o campo já entra em edição ao receber o foco (antes era preciso clicar ou dar Enter)
		if not OS.has_feature("mobile") and not le.is_editing():
			le.call_deferred("edit"))
	row.add_child(le)
	_btn(vb, "Sortear outro nome", func(): le.text = _random_name(), true, "Troca por outro nome aleatório.")
	_selector(vb, "Nacionalidade", Game.NATIONS, 0, func(i): data["nation"] = i, "País que aparece nas tabelas e notícias.")
	_selector(vb, "Capacete", Game.HELMET_NAMES, 0, func(i):
		data["helmet"] = i
		preview.set_design(i), "Pinturas de países, tribal e grafismos de corrida. Viseira e acabamento podem ser ajustados no escritório.")
	var err := _label(vb, "", 18, Color(1, 0.55, 0.45))
	var go := func():
		var nm := le.text.strip_edges()
		if nm.length() < 3:
			err.text = "Digite um nome com pelo menos 3 letras."
			le.grab_focus()
			return
		Game.new_career(nm, data["nation"], data["helmet"])
		career_dirty = true
		_show_team_selection()
	le.text_submitted.connect(func(_t): go.call())
	_btn(vb, "Criar", go, true, "Cria este perfil de piloto.")
	_btn(vb, "Voltar", _career_entry)
	back_cb = _career_entry
	_focus_first(vb)


class KartPreview extends SubViewportContainer:
	## Kart com o piloto girando devagar, para a tela de criação de piloto.
	var car

	func set_design(i: int, visor: int = 0, finish: int = 0) -> void:
		Game.HelmetModel.customize(car, i, visor, finish)

	func _process(delta: float) -> void:
		if car:
			car.rotation.y += delta * 0.30

	func set_helmet(c: Color) -> void:
		if car:
			car.set_helmet_color(c)


func _kart_preview(helmet: Color) -> Control:
	bg.hero = null
	bg.queue_redraw()
	var vs := get_viewport().get_visible_rect().size
	var box := KartPreview.new()
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(vs.x * 0.5, roundf(vs.y * 0.115) + 30.0)
	box.size = Vector2(vs.x * 0.48, vs.y - roundf(vs.y * 0.1) - 70.0 - box.position.y - 10.0)
	ui.add_child(box)
	screen_extras.append(box)
	var sv := SubViewport.new()
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	box.add_child(sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.88, 0.95)
	e.ambient_light_energy = 0.6
	env.environment = e
	sv.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	sv.add_child(sun)
	var car := MeshInstance3D.new()
	sv.add_child(car)
	Game.HelmetModel.apply(car, false, "scarlet")
	car.rotation.y = 0.35
	box.car = car
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.24
	cam.position = Vector3(0.16, 0.07, -0.4)
	sv.add_child(cam)
	cam.look_at(Vector3.ZERO)
	return box


func _show_team_selection() -> void:
	screen_id = "teams"
	var c := Game.career
	var vb := _page("Testes de recrutamento", "%s, escolha uma das três equipes que estão avaliando novos pilotos." % c["name"])
	var rejected: Array = c["rejected"]
	for t in Game.teams.size():
		var team: Dictionary = Game.teams[t]
		if not team["rookie"]:
			continue
		var tr: Dictionary = Game.tracks[team["test_track"]]
		var cond := "chuva" if team["test_weather"] == "rain" else "seco"
		var refused := rejected.has(t)
		var b := _btn(vb, "%s  —  %s, %s%s" % [team["name"], tr["name"], cond, "  (vaga recusada)" if refused else ""], _show_briefing.bind(t), not refused)
		b.tooltip_text = team["pitch"]
		_label(vb, team["pitch"], 16, Color(0.7, 0.75, 0.9))
	_btn(vb, "Voltar ao menu principal", _career_quit_prompt)
	back_cb = _career_quit_prompt
	_focus_first(vb)


func _recruit_target(team_idx: int) -> float:
	var team: Dictionary = Game.teams[team_idx]
	return snappedf(Game.lap_estimate(team["test_track"], team["test_weather"]) * 1.075, 0.1)


func _show_briefing(team_idx: int) -> void:
	screen_id = "briefing"
	var c := Game.career
	c["team"] = team_idx
	var team: Dictionary = Game.teams[team_idx]
	var tr: Dictionary = Game.tracks[team["test_track"]]
	var target := _recruit_target(team_idx)
	var attempt := int(c["attempts"]) + 1
	var vb := _page("Briefing — " + team["name"], "Teste de recrutamento em contrarrelógio")
	_label(vb, "Circuito: %s (%s)" % [tr["name"], tr["place"]])
	_label(vb, "Condições: %s" % ("pista molhada" if team["test_weather"] == "rain" else "pista seca"))
	_label(vb, "Kart: chassi %s do ano, acerto padrão" % team["name"])
	_label(vb, "Formato: volta de saída e 3 voltas cronometradas. Vale a melhor volta válida.")
	_label(vb, "Meta da equipe: %s  (meta definida por este jogo)" % Game.fmt_time(target), 22, Color(1, 0.85, 0.3))
	_label(vb, "Tentativa %d de 2" % attempt, 18, Color(0.7, 0.75, 0.9))
	_btn(vb, "Ir para a pista", _start_recruit_test.bind(team_idx, target))
	_btn(vb, "Escolher outra equipe", _show_team_selection)
	back_cb = _show_team_selection
	_focus_first(vb)


func _career_cfg(team_idx: int) -> Dictionary:
	var c := Game.career
	return {"player_team": team_idx, "player_name": c["name"], "player_code": c["code"], "player_num": 21,
		"appearance": Game.Appearance.normalized(c.get("appearance", {})), "helmet": int(c["helmet"]), "helmet_visor": int(c.get("helmet_visor", 0)), "helmet_finish": int(c.get("helmet_finish", 0)), "difficulty": int(Game.settings["difficulty"]), "career": true}


func _start_recruit_test(team_idx: int, target: float) -> void:
	var team: Dictionary = Game.teams[team_idx]
	var cfg := _career_cfg(team_idx)
	cfg.merge({"mode": "test", "track": team["test_track"], "weather": team["test_weather"], "timed_laps": 3,
		"target": target, "title": "Teste de recrutamento — " + team["name"]})
	_start_session(cfg, _recruit_result.bind(team_idx, target))


func _recruit_result(res: Dictionary, team_idx: int, target: float) -> void:
	var c := Game.career
	var team: Dictionary = Game.teams[team_idx]
	var best: float = res["best"]
	c["attempts"] = int(c["attempts"]) + 1
	c["recruit"] = {"team": team_idx, "best": best, "target": target}
	career_dirty = true
	var vb := _page("Avaliação — " + team["name"], "Melhor volta %s   ·   meta %s" % [Game.fmt_time(best), Game.fmt_time(target)])
	if best <= target:
		c["role"] = "test"
		c["attempts"] = 0
		Game.add_email(team["name"], "Contrato de piloto de testes", "Parabéns! Sua volta de %s superou a meta. Você é o novo piloto de testes da %s. Faça bons testes de desenvolvimento e a equipe considerará você para um kart titular." % [Game.fmt_time(best), team["name"]])
		Game.add_news("%s é contratado como piloto de testes da %s." % [c["name"], team["name"]])
		_label(vb, "Contratado como piloto de testes!", 30, Color(0.4, 1.0, 0.5))
		_label(vb, "Você entra no escritório da carreira. Lembre-se de salvar o progresso por lá.")
		_btn(vb, "Ir para o escritório", _show_office)
	elif best <= target * 1.02 and int(c["attempts"]) < 2:
		_label(vb, "Quase. Ficou %.3f s acima da meta." % (best - target), 26, Color(1, 0.85, 0.3))
		_label(vb, "A equipe oferece uma nova tentativa.")
		_btn(vb, "Tentar de novo", _show_briefing.bind(team_idx))
		_btn(vb, "Escolher outra equipe", func():
			c["attempts"] = 0
			_show_team_selection())
	else:
		c["attempts"] = 0
		var rejected: Array = c["rejected"]
		if not rejected.has(team_idx):
			rejected.append(team_idx)
		var why := "Nenhuma volta válida foi completada." if best == INF else "Ficou %.3f s acima da meta." % (best - target)
		_label(vb, "A %s não vai contratar você agora." % team["name"], 26, Color(1, 0.5, 0.4))
		_label(vb, why)
		if rejected.size() >= 3:
			rejected.clear()
			_label(vb, "Todas as equipes recusaram. A Federação abriu uma nova rodada de testes para as três equipes.")
		_btn(vb, "Escolher equipe", _show_team_selection)
	back_cb = Callable()
	_focus_first(vb)


func _career_quit_prompt() -> void:
	if career_dirty:
		_confirm("Sair da carreira", "Há progresso não salvo. Sair agora descarta esse progresso.", "Sair sem salvar", _show_main, _career_resume)
	else:
		_show_main()


func _show_office() -> void:
	screen_id = "office"
	var c := Game.career
	var team: Dictionary = Game.teams[int(c["team"])]
	var rnd := int(c["round"])
	var vb := _page("Escritório — " + c["name"], "%s  ·  %s  ·  Temporada %d  ·  Etapa %d de %d" % [team["name"], Game.ROLE_NAMES[c["role"]], int(c["season"]), rnd + 1, Game.ROUNDS_PER_SEASON])
	_label(vb, "Próxima atividade: " + _next_activity_text(), 19, Color(1, 0.85, 0.3))
	_btn(vb, "Avançar tempo", _show_advance)
	var unread := Game.unread_emails()
	_btn(vb, "E-mails" + (" (%d novos)" % unread if unread > 0 else ""), _show_emails)
	_btn(vb, "Notícias", _show_news)
	_btn(vb, "Informações", _show_info)
	_btn(vb, "Sala de troféus (%d/%d)" % [Game.trophy_track_count(), Game.tracks.size()], _show_trophies)
	_btn(vb, "Garagem e personalização", _show_garage)
	_btn(vb, "Salvar carreira", _save_career)
	_btn(vb, "Opções", _show_options.bind(_show_office))
	_btn(vb, "Sair para o menu principal", _career_quit_prompt)
	back_cb = _career_quit_prompt
	_focus_first(vb)


func _next_activity_text() -> String:
	var c := Game.career
	var tr: Dictionary = Game.tracks[Game.round_track(int(c["round"]))]
	if Game.is_race_role():
		return "GP de %s — classificação e corrida (%d voltas)" % [tr["name"], int(Game.settings["career_laps"])]
	return "Teste de desenvolvimento em %s (a corrida da etapa será disputada pelos titulares)" % tr["name"]


func _save_career() -> void:
	var do_save := func():
		var ok := Game.save_career()
		career_dirty = not ok
		var vb := _page("Salvar carreira", "Carreira salva com sucesso." if ok else "Erro ao salvar: não foi possível gravar o arquivo.")
		_btn(vb, "Voltar ao escritório", _show_office)
		back_cb = _show_office
		_focus_first(vb)
	if Game.career_exists():
		_confirm("Salvar carreira", "Substituir o arquivo de carreira existente?", "Sobrescrever", do_save, _show_office)
	else:
		do_save.call()


func _show_advance() -> void:
	var c := Game.career
	var tr_idx := Game.round_track(int(c["round"]))
	var tr: Dictionary = Game.tracks[tr_idx]
	var vb := _page("Avançar tempo", "Etapa %d de %d — %s" % [int(c["round"]) + 1, Game.ROUNDS_PER_SEASON, tr["name"]])
	if Game.is_race_role():
		_label(vb, "Você vai disputar o fim de semana: classificação (3 voltas cronometradas) e corrida de %d voltas. Pontuação: 10-8-6-5-4-3-2-1." % int(Game.settings["career_laps"]))
		_btn(vb, "Confirmar e ir para a classificação", _career_quali.bind(tr_idx))
	else:
		var target := snappedf(Game.lap_estimate(tr_idx, "dry") * 1.045, 0.1)
		_label(vb, "A equipe pede um teste de desenvolvimento: 3 voltas, meta %s. Bater a meta melhora o kart e conta para a sua promoção. Depois, a corrida da etapa acontece sem você." % Game.fmt_time(target))
		_btn(vb, "Confirmar e ir para o teste", _career_dev_test.bind(tr_idx, target))
	_btn(vb, "Voltar", _show_office)
	back_cb = _show_office
	_focus_first(vb)


func _career_dev_test(tr_idx: int, target: float) -> void:
	var cfg := _career_cfg(int(Game.career["team"]))
	cfg.merge({"mode": "test", "track": tr_idx, "weather": "dry", "timed_laps": 3, "target": target,
		"title": "Teste de desenvolvimento — " + Game.tracks[tr_idx]["name"]})
	_start_session(cfg, _dev_test_result.bind(tr_idx, target))


func _dev_test_result(res: Dictionary, tr_idx: int, target: float) -> void:
	var c := Game.career
	var team_idx := int(c["team"])
	var team: Dictionary = Game.teams[team_idx]
	var best: float = res["best"]
	career_dirty = true
	var vb := _page("Teste de desenvolvimento", "Melhor volta %s  ·  meta %s" % [Game.fmt_time(best), Game.fmt_time(target)])
	if best <= target:
		c["evals"] = int(c["evals"]) + 1
		c["stats"]["tests"] = int(c["stats"]["tests"]) + 1
		var db: Dictionary = c["dev_bonus"]
		db[str(team_idx)] = float(db.get(str(team_idx), 0.0)) + 0.002
		_label(vb, "Teste aprovado. A equipe validou uma atualização de motor: +0,2% de potência para os dois karts.", 22, Color(0.4, 1.0, 0.5))
		Game.add_email(team["name"], "Evolução do kart", "Os dados do seu teste em %s confirmaram a nova calibração do motor (+0,2%% de potência). Avaliações positivas: %d." % [Game.tracks[tr_idx]["name"], int(c["evals"])])
		if int(c["evals"]) >= 2 and c["role"] == "test" and not c["offer_pending"]:
			c["offer_pending"] = true
			Game.add_email(team["name"], "Proposta: kart titular", "Seus testes convenceram a diretoria. Oferecemos a vaga de segundo piloto a partir da próxima etapa.", "promo_second")
			_label(vb, "Você recebeu uma proposta por e-mail.", 20, Color(1, 0.85, 0.3))
	else:
		_label(vb, "Meta não atingida. A atualização não foi validada nesta etapa.", 22, Color(1, 0.6, 0.4))
	var rows := Game.simulate_round(tr_idx)
	c["season_results"].append({"round": int(c["round"]) + 1, "track": tr_idx, "text": "Teste: %s (meta %s)" % [Game.fmt_time(best), Game.fmt_time(target)]})
	var winner := Game.driver_by_code(rows[0]["code"])
	_label(vb, "Corrida da etapa: vitória de %s." % winner["name"])
	c["round"] = int(c["round"]) + 1
	_btn(vb, "Continuar", _after_round)
	back_cb = Callable()
	_focus_first(vb)


func _career_field() -> Array:
	var out: Array = []
	for code in Game.season_drivers():
		if code != Game.career["code"]:
			out.append(Game.driver_by_code(code))
	return out


func _career_quali(tr_idx: int) -> void:
	var c := Game.career
	var cfg := _career_cfg(int(c["team"]))
	cfg.merge({"mode": "qualifying", "track": tr_idx, "weather": "dry", "timed_laps": 3,
		"title": "Classificação — GP de " + Game.tracks[tr_idx]["name"]})
	_start_session(cfg, func(res):
		var q := _quali_results(res, _career_field(), tr_idx, "dry", c["name"], c["code"], int(c["team"]))
		if q[0].get("player", false):
			c["stats"]["poles"] = int(c["stats"]["poles"]) + 1
		_show_quali_results(q, _career_race.bind(tr_idx, q)))


func _career_race(tr_idx: int, q: Array) -> void:
	var c := Game.career
	var g := _grid_from_quali(q)
	var cfg := _career_cfg(int(c["team"]))
	cfg.merge({"mode": "race", "track": tr_idx, "weather": "dry", "laps": int(Game.settings["career_laps"]),
		"field": g[0], "player_grid": g[1], "title": "GP de " + Game.tracks[tr_idx]["name"]})
	_start_session(cfg, _career_race_result.bind(tr_idx))


func _career_race_result(res: Dictionary, tr_idx: int) -> void:
	var c := Game.career
	var cls: Array = res["classification"]
	var order: Array = []
	var ppos := 0
	for k in cls.size():
		if cls[k]["status"] != "dnf":
			order.append(cls[k]["code"])
		if cls[k]["player"]:
			ppos = k + 1 if cls[k]["status"] != "dnf" else 0
	Game.award(order)
	var trophy := Game.award_track_trophy(tr_idx, ppos)
	var st: Dictionary = c["stats"]
	st["starts"] = int(st["starts"]) + 1
	if ppos == 1:
		st["wins"] = int(st["wins"]) + 1
	if ppos >= 1 and ppos <= 3:
		st["podiums"] = int(st["podiums"]) + 1
	var pts: int = Game.POINTS[ppos - 1] if ppos >= 1 and ppos <= Game.POINTS.size() else 0
	st["points"] = int(st["points"]) + pts
	if ppos > 0 and (int(st["best"]) == 0 or ppos < int(st["best"])):
		st["best"] = ppos
	var tm := Game.teammate_code()
	var tm_pos := 0
	for k in cls.size():
		if cls[k]["code"] == tm and cls[k]["status"] != "dnf":
			tm_pos = k + 1
	var note := "Você terminou em P%d (+%d pts)." % [ppos, pts] if ppos > 0 else "Você abandonou a corrida."
	if tm_pos > 0:
		note += "  Companheiro de equipe: P%d." % tm_pos
	c["season_results"].append({"round": int(c["round"]) + 1, "track": tr_idx, "text": ("P%d" % ppos if ppos > 0 else "Abandono") + " (%d pts)" % pts})
	var winner := Game.driver_by_code(order[0]) if order.size() > 0 else {"name": "-"}
	Game.add_news("GP de %s: vitória de %s. %s %s." % [Game.tracks[tr_idx]["name"], winner["name"], c["name"], ("terminou em P%d" % ppos) if ppos > 0 else "abandonou"])
	c["round"] = int(c["round"]) + 1
	career_dirty = true
	if not trophy.is_empty():
		_show_trophy_award(trophy, func(): _show_race_results(res, _after_round, {"note": note}), cls)
	else:
		_show_race_results(res, _after_round, {"note": note})


func _after_round() -> void:
	if int(Game.career["round"]) >= Game.ROUNDS_PER_SEASON:
		_show_season_end()
	else:
		_show_office()


func _show_season_end() -> void:
	var c := Game.career
	var standings := Game.driver_standings()
	var ppos := 0
	for k in standings.size():
		if standings[k]["code"] == c["code"]:
			ppos = k + 1
	var mine := Game.points_of(c["code"])
	var tm := Game.teammate_code()
	var tm_pts := Game.points_of(tm) if tm != "" else 0
	var champ := Game.driver_by_code(standings[0]["code"])
	var vb := _page("Fim da temporada %d" % int(c["season"]), "Campeão: %s (%d pts)" % [champ["name"], int(standings[0]["pts"])])
	c["history"].append({"season": int(c["season"]), "team": int(c["team"]), "role": c["role"], "points": mine, "pos": ppos})
	if Game.is_race_role():
		_label(vb, "Você: P%d no campeonato com %d pontos. Companheiro de equipe: %d pontos." % [ppos, mine, tm_pts])
		if c["role"] == "second" and mine > tm_pts:
			Game.add_email(Game.teams[int(c["team"])]["name"], "Proposta: primeiro piloto", "Você superou seu companheiro de equipe. Queremos você como primeiro piloto na próxima temporada.", "promo_first")
			_label(vb, "Proposta de promoção recebida por e-mail.", 20, Color(1, 0.85, 0.3))
		if ppos > 0 and ppos <= 6 and int(c["team"]) >= 5:
			var offer_team := 3 if randf() < 0.5 else 4
			Game.add_email(Game.teams[offer_team]["name"], "Proposta de transferência", "Acompanhamos sua temporada. Oferecemos um kart titular na %s para a próxima temporada." % Game.teams[offer_team]["name"], "team:%d" % offer_team)
			_label(vb, "Outra equipe enviou uma proposta de transferência.", 20, Color(1, 0.85, 0.3))
		if mine == 0 and tm_pts > 0:
			c["weak_seasons"] = int(c["weak_seasons"]) + 1
			if int(c["weak_seasons"]) >= 2:
				_leave_seat()
				c["role"] = "test"
				c["evals"] = 0
				_label(vb, "Duas temporadas sem pontos: a equipe devolveu você à função de piloto de testes.", 20, Color(1, 0.5, 0.4))
			else:
				_label(vb, "A equipe espera pontos na próxima temporada.", 20, Color(1, 0.6, 0.4))
		else:
			c["weak_seasons"] = 0
	else:
		_label(vb, "Você seguiu como piloto de testes. Avaliações positivas: %d." % int(c["evals"]))
	c["season"] = int(c["season"]) + 1
	c["round"] = 0
	c["dpoints"] = {}
	c["tpoints"] = {}
	c["dpos"] = {}
	c["season_results"] = []
	career_dirty = true
	if int(c["season"]) > Game.MAX_SEASONS:
		_btn(vb, "Ver resumo da carreira", _show_career_end)
	else:
		_btn(vb, "Ir para o escritório", _show_office)
	back_cb = Callable()
	_focus_first(vb)


func _show_career_end() -> void:
	var c := Game.career
	var vb := _page("Carreira concluída", "%s completou %d temporadas." % [c["name"], Game.MAX_SEASONS], true)
	_btn(vb, "Sala de troféus", _show_trophies)
	var rows: Array = []
	for h in c["history"]:
		rows.append([str(int(h["season"])), Game.teams[int(h["team"])]["name"], Game.ROLE_NAMES[h["role"]], str(int(h["points"])), "P%d" % int(h["pos"]) if int(h["pos"]) > 0 else "-"])
	_table(vb, ["Temp.", "Equipe", "Função", "Pts", "Camp."], rows, [70, 240, 200, 60, 80])
	var st: Dictionary = c["stats"]
	_label(vb, "Largadas %d · Vitórias %d · Pódios %d · Poles %d · Pontos %d" % [int(st["starts"]), int(st["wins"]), int(st["podiums"]), int(st["poles"]), int(st["points"])])
	_btn(vb, "Salvar e voltar ao menu", func():
		Game.save_career()
		career_dirty = false
		_show_main())
	_focus_first(vb)


func _leave_seat() -> void:
	var c := Game.career
	var lineup: Array = c["lineup"][str(int(c["team"]))]
	var k := lineup.find(c["code"])
	if k >= 0:
		lineup[k] = c.get("replaced", lineup[k])


func _join_team(team_idx: int) -> void:
	var c := Game.career
	_leave_seat()
	c["team"] = team_idx
	var lineup: Array = c["lineup"][str(team_idx)]
	var weakest := 0
	if Game.driver_by_code(lineup[1])["skill"] < Game.driver_by_code(lineup[0])["skill"]:
		weakest = 1
	c["replaced"] = lineup[weakest]
	lineup[weakest] = c["code"]
	c["role"] = "second"
	Game.add_news("%s se transfere para a %s." % [c["name"], Game.teams[team_idx]["name"]])


func _show_emails() -> void:
	var c := Game.career
	var vb := _page("E-mails", "", true)
	var emails: Array = c["emails"]
	if emails.is_empty():
		_label(vb, "Caixa de entrada vazia.")
	for k in emails.size():
		var e: Dictionary = emails[k]
		var b := _btn(vb, "%s%s — %s" % ["● " if not e["read"] else "", e["from"], e["subject"]], _show_email.bind(k))
		b.custom_minimum_size.x = 0
	_btn(vb, "Voltar", _show_office)
	back_cb = _show_office
	_focus_first(vb)


func _show_email(k: int) -> void:
	var e: Dictionary = Game.career["emails"][k]
	e["read"] = true
	var vb := _page(e["subject"], "De: %s  ·  Temporada %d, etapa %d" % [e["from"], int(e["season"]), int(e["round"]) + 1])
	_label(vb, e["body"])
	var offer: String = e.get("offer", "")
	if offer != "" and not e["answered"]:
		_btn(vb, "Aceitar proposta", func():
			e["answered"] = true
			_accept_offer(offer)
			career_dirty = true
			_show_emails())
		_btn(vb, "Recusar proposta", func():
			e["answered"] = true
			if offer == "promo_second":
				Game.career["offer_pending"] = false
				Game.career["evals"] = 0
			career_dirty = true
			_show_emails())
	elif offer != "":
		_label(vb, "Proposta já respondida.", 18, Color(0.7, 0.75, 0.9))
	_btn(vb, "Voltar", _show_emails)
	back_cb = _show_emails
	_focus_first(vb)


func _accept_offer(offer: String) -> void:
	var c := Game.career
	if offer == "promo_second":
		if c["role"] != "test":
			return
		Game.promote_to_race_seat()
		var lineup: Array = c["lineup"][str(int(c["team"]))]
		c["offer_pending"] = false
		_record_replaced(lineup)
	elif offer == "promo_first":
		c["role"] = "first"
		Game.add_news("%s é promovido a primeiro piloto da %s." % [c["name"], Game.teams[int(c["team"])]["name"]])
	elif offer.begins_with("team:"):
		_join_team(int(offer.substr(5)))


func _record_replaced(lineup: Array) -> void:
	## Guarda quem perdeu a vaga para devolvê-la se o jogador sair da equipe.
	var c := Game.career
	for d in Game.drivers:
		if int(d["team"]) == int(c["team"]) and not lineup.has(d["code"]):
			c["replaced"] = d["code"]


func _show_news() -> void:
	var vb := _page("Notícias", "", true)
	var news: Array = Game.career["news"]
	if news.is_empty():
		_label(vb, "Nenhuma notícia ainda.")
	for n in news:
		_label(vb, "Temp. %d, etapa %d — %s" % [int(n["season"]), int(n["round"]) + 1, n["text"]], 18).custom_minimum_size.x = 0
	_btn(vb, "Voltar", _show_office)
	back_cb = _show_office
	_focus_first(vb)


func _show_info() -> void:
	var vb := _page("Informações")
	_btn(vb, "Classificação de pilotos", _show_drivers_table)
	_btn(vb, "Classificação de construtores", _show_teams_table)
	_btn(vb, "Estatísticas do piloto", _show_stats)
	_btn(vb, "Resultados da temporada", _show_season_results)
	_btn(vb, "Calendário", _show_calendar)
	_btn(vb, "Voltar", _show_office)
	back_cb = _show_office
	_focus_first(vb)


func _show_drivers_table() -> void:
	var vb := _page("Pilotos — temporada %d" % int(Game.career["season"]), "", true)
	var rows: Array = []
	var hl := -1
	var st := Game.driver_standings()
	for k in st.size():
		var d := Game.driver_by_code(st[k]["code"])
		if st[k]["code"] == Game.career["code"]:
			hl = k
		rows.append([str(k + 1), d["name"], Game.teams[int(d["team"])]["name"], preload("res://scripts/rival_style.gd").title(String(d["code"])) if d["code"] != Game.career.get("code", "") else "Jogador", str(st[k]["pts"])])
	_table(vb, ["Pos", "Piloto", "Equipe", "Estilo", "Pts"], rows, [60, 230, 220, 150, 70], hl)
	_btn(vb, "Voltar", _show_info)
	back_cb = _show_info
	_focus_first(vb)


func _show_teams_table() -> void:
	var vb := _page("Construtores — temporada %d" % int(Game.career["season"]), "", true)
	var rows: Array = []
	var hl := -1
	var st := Game.team_standings()
	for k in st.size():
		if int(st[k]["team"]) == int(Game.career["team"]):
			hl = k
		rows.append([str(k + 1), Game.teams[st[k]["team"]]["name"], str(st[k]["pts"])])
	_table(vb, ["Pos", "Equipe", "Pts"], rows, [60, 300, 70], hl)
	_btn(vb, "Voltar", _show_info)
	back_cb = _show_info
	_focus_first(vb)


func _show_stats() -> void:
	var c := Game.career
	var st: Dictionary = c["stats"]
	var vb := _page("Estatísticas — " + c["name"], "%s  ·  capacete %s" % [Game.NATIONS[int(c["nation"])], Game.HELMET_NAMES[int(c["helmet"])]])
	var rows := [["Largadas", str(int(st["starts"]))], ["Vitórias", str(int(st["wins"]))], ["Pódios", str(int(st["podiums"]))],
		["Poles", str(int(st["poles"]))], ["Pontos na carreira", str(int(st["points"]))],
		["Melhor resultado", ("P%d" % int(st["best"])) if int(st["best"]) > 0 else "-"], ["Testes aprovados", str(int(st["tests"]))]]
	_table(vb, ["Item", "Valor"], rows, [260, 140])
	_btn(vb, "Voltar", _show_info)
	back_cb = _show_info
	_focus_first(vb)


func _show_season_results() -> void:
	var vb := _page("Resultados da temporada %d" % int(Game.career["season"]))
	var rows: Array = []
	for r in Game.career["season_results"]:
		rows.append([str(int(r["round"])), Game.tracks[int(r["track"])]["name"], r["text"]])
	if rows.is_empty():
		_label(vb, "Nenhuma etapa disputada nesta temporada.")
	else:
		_table(vb, ["Etapa", "Circuito", "Resultado"], rows, [70, 220, 300])
	_btn(vb, "Voltar", _show_info)
	back_cb = _show_info
	_focus_first(vb)


func _show_calendar() -> void:
	var c := Game.career
	var vb := _page("Calendário — temporada %d" % int(c["season"]), "Calendário fictício de %d etapas." % Game.ROUNDS_PER_SEASON)
	var rows: Array = []
	for r in Game.ROUNDS_PER_SEASON:
		var tr: Dictionary = Game.tracks[Game.round_track(r)]
		var status := "Concluída" if r < int(c["round"]) else ("Próxima" if r == int(c["round"]) else "")
		rows.append([str(r + 1), tr["name"], tr["place"], status])
	_table(vb, ["Etapa", "Circuito", "Local", "Situação"], rows, [70, 220, 180, 120], int(c["round"]))
	_btn(vb, "Voltar", _show_info)
	back_cb = _show_info
	_focus_first(vb)


# ---------------------------------------------------------------- teste automático

func _run_test() -> void:
	## --autotest=<pista>: corrida com piloto automático no kart do jogador, imprime voltas e posições.
	## --shot=<arquivo.png>: captura a câmera após alguns segundos.
	var track_idx := int(test_args.get("autotest", test_args.get("track", "0")))
	var mode: String = test_args.get("mode", "race")
	Engine.time_scale = float(test_args.get("speed", "1"))
	if test_args.has("diff"):
		Game.settings["difficulty"] = int(test_args["diff"])
	var cfg := _base_cfg(int(test_args.get("team", "5")))
	cfg.merge({"mode": mode, "track": track_idx, "weather": test_args.get("weather", "dry"),
		"laps": int(test_args.get("laps", "2")), "timed_laps": int(test_args.get("laps", "2")),
		"field": _ai_field(int(test_args.get("team", "5")), int(test_args.get("opp", "15")), []), "player_grid": int(test_args.get("grid", "8")),
		"pit_rule": int(test_args.get("pit", str(Game.settings["pit_stops"]))),
		"title": "Teste automático"})
	Game.settings["camera"] = int(test_args.get("cam", "0"))
	_start_session(cfg, func(res):
		print("RESULT best=", Game.fmt_time(res["best"]), " laps=", res["laps"].map(func(x): return Game.fmt_time(x)))
		for r in res.get("classification", []):
			print("  ", r["code"], " ", r["status"], " laps=", r["laps"], " t=", Game.fmt_time(r["time"]), " best=", Game.fmt_time(r["best"]), " stops=", r.get("stops", 0))
		get_tree().quit())
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if race == null:
		return
	race.autopilot = not test_args.has("manual") and not test_args.has("assist")
	if test_args.has("assist"):
		# --assist=<0|1|2>: frenagem automática nesse nível, acelerador sempre no fundo
		race.test_driver = true
		Game.settings["brake_assist"] = clampi(int(test_args["assist"]), 0, 1)
	if test_args.has("fuel"):
		# --fuel=<voltas> e --callpit: testa chegar ao box com o tanque seco
		race.player.fuel = float(test_args["fuel"])
	if test_args.has("callpit"):
		race.player.pit_request = true
	if test_args.has("place"):
		# --place=s:d:graus — posição inicial forçada (testes de recuperação contra o muro)
		var pl: PackedStringArray = String(test_args["place"]).split(":")
		race.player.place(race.track, float(pl[0]), float(pl[1]))
		race.player.h += deg_to_rad(float(pl[2]))
	print("TRACK ", Game.tracks[track_idx]["name"], " len=", race.track.length, " estimate=", Game.fmt_time(race.track.lap_estimate()))
	if test_args.has("shot"):
		var wait := float(test_args.get("shot_time", "6"))
		await get_tree().create_timer(wait, true, false, true).timeout
		if race and test_args.has("nohud"):
			race.hud.visible = false
			if race.touch:
				race.touch.visible = false
			await get_tree().process_frame
		if race and test_args.has("view"):
			# --view=s:altura:recuo — câmera livre olhando um ponto da pista (inspeção visual)
			var v: PackedStringArray = String(test_args["view"]).split(":")
			race.cam_mode = 99
			# 4º valor opcional: deslocamento lateral do ponto observado (ex.: pit lane)
			var tp: Vector3 = race.track.point_at(float(v[0]), float(v[3]) if v.size() > 3 else 0.0)
			var back: Vector3 = Vector3(-sin(race.track.heading_at(float(v[0]))), 0, -cos(race.track.heading_at(float(v[0])))) * -float(v[2])
			race.camera.global_position = tp + back + Vector3(0, float(v[1]), 0)
			race.camera.look_at(tp, Vector3.UP)
			race.camera.fov = 60.0
			race.camera.far = 6000.0
			await get_tree().process_frame
			await get_tree().process_frame
		if race:
			var img := get_viewport().get_texture().get_image()
			img.save_png(test_args["shot"])
			print("SHOT saved ", test_args["shot"], " fps=", Engine.get_frames_per_second())
		if not test_args.has("autotest"):
			get_tree().quit()
		return
	var last_lap := 0
	var trace: PackedStringArray = String(test_args.get("trace", "")).split(":")
	while race != null:
		await get_tree().create_timer(0.2 if trace.size() == 2 or test_args.has("pitshot") else 1.0, true, false, true).timeout
		if race == null:
			break
		var p = race.player
		if trace.size() == 2 and p.s >= float(trace[0]) and p.s <= float(trace[1]):
			print("  s=%.1f d=%.2f v=%.2f tgt=%.1f line=%.2f steer=%.2f sf=%.2f sr=%.2f thr=%.2f brk=%.2f r=%.2f g=%d rev=%.2f stuck=%.2f dh=%.2f" % [p.s, p.d, p.vx, race.track.speed_at(p.s) * p.pace, race.track.line_offset_at(p.s), p.steer, p.slip_f, p.slip_r, p.throttle, p.brake_in, p.r, p.gear, p.reverse_t, p.stuck_t, wrapf(p.h - race.track.heading_at(p.s), -PI, PI)])
		if test_args.has("verbose") and int(race.t) % 4 == 0:
			print("--- t=%.1f state=%s" % [race.t, race.state])
			for c in race.order:
				print("  %s lap=%d s=%.0f d=%.1f v=%.1f tgt=%.1f g=%d dmg=%.2f lane=%.1f surf=%d" % [c.driver["code"], c.max_lap, c.s, c.d, c.vx, race.track.speed_at(c.s) * c.pace, c.gear, c.damage, c.lane, c.surface])
		if p.max_lap != last_lap:
			last_lap = p.max_lap
			print("t=%.1f lap=%d pos=%d best=%s dmg=%.2f wear=%.2f max=%.2f fuel=%.2f stops=%d tyre=%d" % [race.t, p.max_lap, race.order.find(p) + 1, Game.fmt_time(p.best_lap), p.damage, p.wear, p.tyre_wear.max(), p.fuel, p.stops, p.compound])
		if test_args.has("pitshot") and p.pit_state == 2 and p.pit_timer > 1.5 and not p.has_meta("shot"):
			# --pitshot=<arquivo.png>: captura a parada do jogador no box
			p.set_meta("shot", true)
			get_viewport().get_texture().get_image().save_png(test_args["pitshot"])
			print("PITSHOT saved")
		if test_args.has("pitlog") and p.pit_state != int(p.get_meta("ps", 0)):
			p.set_meta("ps", p.pit_state)
			print("  PIT state=%d t=%.1f s=%.0f u=%.0f d=%.1f v=%.1f fuel=%.2f total=%.1f" % [p.pit_state, race.t, p.s, race.track.pit_u(p.s), p.d, p.vx, p.fuel, p.pit_total])
		if race.t > float(test_args.get("timeout", "900")):
			print("TIMEOUT state=", race.state, " s=", p.s, " lap=", p.lap)
			for c in race.cars:
				print("  ", c.driver["code"], " lap=", c.max_lap, " s=%.0f d=%.1f v=%.1f ret=%s dmg=%.2f" % [c.s, c.d, c.vx, str(c.retired), c.damage])
			get_tree().quit()
			break


func _flow_test() -> void:
	## --flowtest: percorre todas as telas e regras de carreira com resultados simulados (sem pilotar).
	var steps: Array = [
		_show_title, _show_main, _show_options.bind(_show_main), _show_controls, _show_quick, _show_tt, _show_weekend,
		_career_entry, _show_driver_creation,
	]
	for s in steps:
		s.call()
		print("ok screen ", s.get_method())
	Game.new_career("Rafael Moura", 0, 1)
	_show_garage()
	_show_helmet_customization()
	_show_team_selection()
	_show_briefing(5)
	var target := _recruit_target(5)
	_recruit_result({"best": target * 1.01, "laps": []}, 5, target)
	print("near miss role=", Game.career["role"], " attempts=", Game.career["attempts"])
	_recruit_result({"best": INF, "laps": []}, 5, target)
	print("rejected=", Game.career["rejected"])
	_show_briefing(6)
	_recruit_result({"best": _recruit_target(6) - 1.0, "laps": []}, 6, _recruit_target(6))
	print("hired role=", Game.career["role"], " team=", Game.career["team"])
	_show_office()
	_show_advance()
	for r in 2:
		var tr := Game.round_track(int(Game.career["round"]))
		_dev_test_result({"best": 10.0, "laps": []}, tr, 50.0)
		print("dev test round=", Game.career["round"], " evals=", Game.career["evals"], " bonus=", Game.career["dev_bonus"])
	_show_emails()
	_show_email(0)
	_accept_offer("promo_second")
	print("promoted role=", Game.career["role"], " lineup=", Game.career["lineup"][str(int(Game.career["team"]))], " replaced=", Game.career.get("replaced"))
	_show_office()
	_show_advance()
	var tr2 := Game.round_track(int(Game.career["round"]))
	var q := _quali_results({"best": 60.0}, _career_field(), tr2, "dry", Game.career["name"], Game.career["code"], int(Game.career["team"]))
	_show_quali_results(q, func(): pass)
	var g := _grid_from_quali(q)
	print("grid slot=", g[1], " field=", g[0].size())
	var cls: Array = []
	var k := 0
	for d in g[0]:
		cls.append({"code": d["code"], "name": d["name"], "team": int(d["team"]), "player": false, "best": 61.0, "penalty": 0.0, "laps": 5, "status": "ok", "time": 300.0 + k})
		k += 1
	cls.insert(2, {"code": Game.career["code"], "name": Game.career["name"], "team": int(Game.career["team"]), "player": true, "best": 60.5, "penalty": 5.0, "laps": 5, "status": "ok", "time": 301.5})
	cls[cls.size() - 1]["status"] = "dnf"
	_career_race_result({"classification": cls, "track": tr2, "weather": "dry", "cfg": {"laps": 5}, "best": 60.5, "laps": []}, tr2)
	assert(int(Game.trophy_for(tr2)["medals"][2]) == 1, "Career podium did not award bronze")
	print("after race round=", Game.career["round"], " pts=", Game.points_of(Game.career["code"]), " stats=", Game.career["stats"])
	for s in [_show_info, _show_drivers_table, _show_teams_table, _show_stats, _show_season_results, _show_calendar, _show_news, _show_trophies]:
		s.call()
	Game.career["round"] = Game.ROUNDS_PER_SEASON
	_after_round()
	print("season=", Game.career["season"], " round=", Game.career["round"], " history=", Game.career["history"])
	_show_emails()
	for e in Game.career["emails"]:
		if e["offer"] != "" and not e["answered"]:
			print("offer pending: ", e["offer"])
			_accept_offer(e["offer"])
			e["answered"] = true
	print("role=", Game.career["role"], " team=", Game.career["team"])
	Game.career["season"] = Game.MAX_SEASONS + 1
	_show_career_end()
	var path := Game.CAREER_PATH
	Game.save_career()
	print("saved=", FileAccess.file_exists(path), " load=", Game.load_career())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_show_tt_results({"best": INF, "laps": [], "track": 0, "weather": "dry"})
	print("FLOWTEST DONE")
	get_tree().quit()


func _trophy_preview(track_idx: int, place: int) -> void:
	bg.hero = null
	bg.queue_redraw()
	var vs := get_viewport().get_visible_rect().size
	var box := TrophyPreview.new()
	box.position = Vector2(vs.x * 0.52, roundf(vs.y * 0.115) + 35.0)
	box.size = Vector2(vs.x * 0.45, vs.y - roundf(vs.y * 0.1) - 85.0 - box.position.y)
	ui.add_child(box)
	screen_extras.append(box)
	box.setup(Game.tracks[track_idx], track_idx, place)


func _show_trophies(track_idx: int = 0, medal: int = 0) -> void:
	screen_id = "trophies"
	track_idx = wrapi(track_idx, 0, Game.tracks.size())
	var entry := Game.trophy_for(track_idx)
	if medal == 0:
		medal = int(entry.get("best_place", 1))
	var counts: Array = entry.get("medals", [0, 0, 0])
	var owned := int(counts[medal - 1]) > 0
	var vb := _page("Sala de troféus", "%d de %d pistas conquistadas · Os troféus são gravados ao salvar a carreira." % [Game.trophy_track_count(), Game.tracks.size()])
	_label(vb, "%02d / %02d · %s" % [track_idx + 1, Game.tracks.size(), Game.tracks[track_idx]["name"]], 23)
	_label(vb, TrophyModel.TITLES[track_idx], 27)
	_label(vb, "Ouro: %d   ·   Prata: %d   ·   Bronze: %d" % [int(counts[0]), int(counts[1]), int(counts[2])], 18)
	_selector(vb, "Exibir", ["Ouro", "Prata", "Bronze"], medal - 1, func(i): _show_trophies(track_idx, i + 1))
	_label(vb, ("Conquistado %d vez(es)." % int(counts[medal - 1])) if owned else ("Termine em %dº nesta pista, na carreira, para conquistar." % medal), 18)
	_btn(vb, "Pista anterior", _show_trophies.bind(track_idx - 1, medal))
	_btn(vb, "Próxima pista", _show_trophies.bind(track_idx + 1, medal))
	var back := _show_career_end if int(Game.career["season"]) > Game.MAX_SEASONS else _show_office
	_btn(vb, "Voltar", back)
	back_cb = back
	_trophy_preview(track_idx, medal if owned else 0)
	_focus_first(vb)


func _show_trophy_award(trophy: Dictionary, next: Callable, classification: Array = []) -> void:
	screen_id = "trophy_award"
	var track_idx := int(trophy["track"])
	var place := int(trophy["place"])
	var vb := _page("Troféu conquistado!", "Pódio da carreira · " + Game.tracks[track_idx]["name"])
	screen.add_theme_constant_override("margin_right", int(get_viewport().get_visible_rect().size.x * .65))
	_label(vb, ["OURO · VITÓRIA", "PRATA · 2º LUGAR", "BRONZE · 3º LUGAR"][place - 1], 28)
	_label(vb, TrophyModel.TITLES[track_idx], 25)
	_label(vb, "Novo troféu para sua coleção!" if trophy["first"] else "Mais uma conquista! Total desta versão: %d." % int(trophy["count"]), 19)
	_label(vb, "Salve a carreira para guardar a conquista na Sala de troféus.", 18)
	_btn(vb, "Ver resultado", next)
	back_cb = next
	if classification.is_empty():
		for i in 3:
			classification.append({"name": Game.career.get("name", "Piloto") if i + 1 == place else "Piloto", "team": maxi(0, int(Game.career.get("team", 0))), "player": i + 1 == place})
	_podium_preview(track_idx, classification, Game.career)
	_focus_first(vb)


func _show_helmet_customization() -> void:
	screen_id = "helmet"
	var vb := _page("Seu capacete", "Escolha sua identidade na pista. As alterações acompanham o salvamento da carreira.")
	var data := {"helmet": int(Game.career.get("helmet", 0)), "helmet_visor": int(Game.career.get("helmet_visor", 0)), "helmet_finish": int(Game.career.get("helmet_finish", 0))}
	var preview = _kart_preview(Color.WHITE)
	var refresh := func(): preview.set_design(data["helmet"], data["helmet_visor"], data["helmet_finish"])
	refresh.call()
	_selector(vb, "Pintura", Game.HELMET_NAMES, data["helmet"], func(i):
		data["helmet"] = i
		refresh.call())
	_selector(vb, "Viseira", Game.HelmetModel.VISORS, data["helmet_visor"], func(i):
		data["helmet_visor"] = i
		refresh.call())
	_selector(vb, "Acabamento", Game.HelmetModel.FINISHES, data["helmet_finish"], func(i):
		data["helmet_finish"] = i
		refresh.call())
	_btn(vb, "Aplicar", func():
		for key in data:
			Game.career[key] = data[key]
		career_dirty = true
		_show_office())
	_btn(vb, "Cancelar", _show_office)
	back_cb = _show_office
	_focus_first(vb)


func _show_garage() -> void:
	screen_id = "garage"
	var vb := _page("Sua garagem", "Arraste o modelo para girar. Use a roda do mouse para aproximar. Aplicar e salvar a carreira guarda seu visual.")
	bg.hero = null
	bg.queue_redraw()
	var data := {"appearance": Game.Appearance.normalized(Game.career.get("appearance", {})), "helmet": int(Game.career.get("helmet", 0)), "helmet_visor": int(Game.career.get("helmet_visor", 0)), "helmet_finish": int(Game.career.get("helmet_finish", 0))}
	var preview = preload("res://scripts/garage_preview.gd").new()
	var vs := get_viewport().get_visible_rect().size
	preview.position = Vector2(vs.x * 0.55, vs.y * 0.16)
	preview.size = Vector2(vs.x * 0.44, vs.y * 0.62)
	ui.add_child(preview)
	screen_extras.append(preview)
	preview.setup(Game.teams[maxi(0, int(Game.career.get("team", 0)))])
	preview.update_look(data)
	_selector(vb, "Visualizar", ["Kart completo", "Capacete", "Piloto e volante"], 0, func(i): preview.view_part(i))
	_selector(vb, "Kart", Game.Appearance.LIVERIES, data["appearance"]["livery"], func(i):
		data["appearance"]["livery"] = i
		preview.update_look(data), "A pintura é visual: sua equipe e o desempenho continuam os mesmos.")
	_selector(vb, "Macacão", Game.Appearance.OUTFITS, data["appearance"]["suit"], func(i):
		data["appearance"]["suit"] = i
		preview.update_look(data))
	_selector(vb, "Luvas", Game.Appearance.OUTFITS, data["appearance"]["gloves"], func(i):
		data["appearance"]["gloves"] = i
		preview.update_look(data))
	_selector(vb, "Capacete", Game.HELMET_NAMES, data["helmet"], func(i):
		data["helmet"] = i
		preview.update_look(data))
	_selector(vb, "Viseira", Game.HelmetModel.VISORS, data["helmet_visor"], func(i):
		data["helmet_visor"] = i
		preview.update_look(data))
	_selector(vb, "Acabamento", Game.HelmetModel.FINISHES, data["helmet_finish"], func(i):
		data["helmet_finish"] = i
		preview.update_look(data))
	_btn(vb, "Girar modelo", func(): preview.turn(PI / 4.0))
	_btn(vb, "Aproximar", func(): preview.dolly(-0.3))
	_btn(vb, "Afastar", func(): preview.dolly(0.3))
	_btn(vb, "Aplicar", func():
		for key in data: Game.career[key] = data[key]
		career_dirty = true
		_show_office())
	_btn(vb, "Cancelar", _show_office)
	back_cb = _show_office
	_focus_first(vb)


func _podium_preview(track_idx: int, classification: Array, look: Dictionary) -> void:
	bg.hero = null
	bg.queue_redraw()
	var preview = preload("res://scripts/podium_preview.gd").new()
	var vs := get_viewport().get_visible_rect().size
	preview.position = Vector2(vs.x * 0.37, vs.y * .14)
	preview.size = Vector2(vs.x * .62, vs.y * .65)
	ui.add_child(preview)
	screen_extras.append(preview)
	preview.setup(track_idx, classification, look)

func _show_race_podium(res: Dictionary, next: Callable) -> void:
	var vb := _page("Pódio do Grande Prêmio", Game.tracks[int(res["track"])]["name"])
	screen.add_theme_constant_override("margin_right", int(get_viewport().get_visible_rect().size.x * .65))
	var cls: Array = res.get("classification", [])
	for i in mini(3, cls.size()):
		if cls[i].get("status", "ok") != "dnf": _label(vb, "%dº  %s" % [i+1, cls[i]["name"]], 25)
	_btn(vb, "Ver resultado", next)
	back_cb = next
	_podium_preview(int(res["track"]), cls, {})
	_focus_first(vb)
