extends CanvasLayer
## HUD de corrida: torre de posições, volta e tempos, posição, conta-giros, minimapa,
## pneus e combustível, estado do kart, avisos do box, mensagens, luzes de largada e menu de pausa.

signal pause_action(action: String)

const NAVY := Color(0.17, 0.2, 0.36, 0.92)
const PAPER := Color(0.97, 0.97, 0.98, 0.92)
const INK := Color(0.08, 0.08, 0.1)
const RED := Color(0.85, 0.08, 0.1, 0.95)

var race
var root: Control
var tower_rows: Array = []
var lap_label: Label
var time_title: Label
var time_label: Label
var best_label: Label
var sector_label: Label
var pos_label: Label
var pos_sub: Label
var gap_label: Label
var msg_label: Label
var msg_t := 0.0
var info_label: Label
var target_label: Label
var tyres: Control
var pit_label: Label
var tacho: Control
var minimap: Control
var lights: Control
var pause_panel: PanelContainer
var pause_box: VBoxContainer
var in_settings := false          # submenu "Configurações do kart" aberto na pausa
var font: Font


class Tacho extends Control:
	var rpm := 4000.0
	var gear := "1"
	var kmh := 0.0
	var font: Font

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, -6)
		var rad := minf(size.x, size.y) * 0.46
		draw_circle(c, rad + 6.0, Color(0.05, 0.05, 0.08, 0.55))
		draw_arc(c, rad, deg_to_rad(135), deg_to_rad(405), 48, Color(1, 1, 1, 0.9), 2.0)
		draw_arc(c, rad - 4.0, _ang(14000.0), deg_to_rad(405), 16, Color(0.95, 0.1, 0.1), 6.0)
		for k in 17:
			var a := _ang(k * 1000.0)
			var dirv := Vector2(cos(a), sin(a))
			var long := k % 2 == 0
			draw_line(c + dirv * (rad - (12.0 if long else 7.0)), c + dirv * rad, Color.WHITE, 2.0 if long else 1.0)
			if long:
				var txt := str(k)
				draw_string(font, c + dirv * (rad - 26.0) + Vector2(-7, 6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		var na := _ang(rpm)
		draw_line(c, c + Vector2(cos(na), sin(na)) * (rad - 8.0), Color(1, 0.25, 0.2), 3.0)
		draw_circle(c, 6.0, Color(0.9, 0.9, 0.9))
		# luzes de troca
		for k in 5:
			var on := rpm > 12800.0 + k * 380.0
			var col := Color(0.1, 0.9, 0.2) if k < 2 else (Color(1, 0.8, 0.1) if k < 4 else Color(1, 0.1, 0.1))
			draw_circle(c + Vector2(-40 + k * 20, -rad - 14), 6.0, col if on else Color(0.15, 0.15, 0.18, 0.8))
		draw_rect(Rect2(c + Vector2(rad * 0.3, rad * 0.22), Vector2(48, 44)), Color(0.97, 0.97, 0.98, 0.95))
		draw_string(font, c + Vector2(rad * 0.3 + 10, rad * 0.22 + 37), gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(0.08, 0.08, 0.1))
		draw_string(font, c + Vector2(-rad * 0.95, rad * 0.62), "%d km/h" % int(kmh), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

	func _ang(x: float) -> float:
		return deg_to_rad(135.0 + clampf(x / 16000.0, 0.0, 1.0) * 270.0)


class Minimap extends Control:
	var race
	var poly := PackedVector2Array()

	func setup(r) -> void:
		race = r
		var tr = r.track
		var rect: Rect2 = tr.bounds
		var sc := minf((size.x - 16.0) / rect.size.x, (size.y - 16.0) / rect.size.y)
		var off := (size - rect.size * sc) * 0.5
		for i in range(0, tr.n, 4):
			var p: Vector3 = tr.pts[i]
			poly.append(Vector2(p.x - rect.position.x, p.z - rect.position.y) * sc + off)
		poly.append(poly[0])
		set_meta("sc", sc)
		set_meta("off", off)

	func _draw() -> void:
		if race == null:
			return
		draw_polyline(poly, Color(0, 0, 0, 0.5), 7.0, true)
		draw_polyline(poly, Color(0.95, 0.95, 0.95, 0.95), 4.0, true)
		var rect: Rect2 = race.track.bounds
		var sc: float = get_meta("sc")
		var off: Vector2 = get_meta("off")
		var p0: Vector3 = race.track.pts[0]
		draw_circle(Vector2(p0.x - rect.position.x, p0.z - rect.position.y) * sc + off, 4.0, Color(0.1, 0.1, 0.1))
		for c in race.cars:
			var p := Vector2(c.pos.x - rect.position.x, c.pos.z - rect.position.y) * sc + off
			if c.is_player:
				continue
			draw_circle(p, 4.0, c.team["c1"])
			draw_arc(p, 4.0, 0, TAU, 10, Color(0, 0, 0, 0.7), 1.0)
		var pp := Vector2(race.player.pos.x - rect.position.x, race.player.pos.z - rect.position.y) * sc + off
		draw_circle(pp, 6.5, Color(0.95, 0.1, 0.1))
		draw_arc(pp, 6.5, 0, TAU, 12, Color.WHITE, 2.0)


class Tyres extends Control:
	## Kart visto de cima: cada pneu pintado pelo desgaste (verde, amarelo, vermelho), com o composto
	## e a porcentagem; azul enquanto frio. Embaixo, o combustível em voltas.
	var car
	var font: Font

	func _draw() -> void:
		if car == null:
			return
		var w := 34.0
		var h := 46.0
		var gap := Vector2(56.0, 70.0)
		var o := Vector2(8.0, 4.0)
		draw_rect(Rect2(o + Vector2(w * 0.5 + 8.0, h * 0.4), Vector2(gap.x - 16.0, gap.y + h * 0.2)), Color(0.05, 0.05, 0.08, 0.55))
		for k in 4:
			var p := o + Vector2((k % 2) * gap.x, (k / 2) * gap.y)
			var wv: float = car.tyre_wear[k]
			var col := Color(0.15, 0.8, 0.25).lerp(Color(0.98, 0.8, 0.1), clampf(wv / 0.6, 0.0, 1.0))
			if wv > 0.6:
				col = Color(0.98, 0.8, 0.1).lerp(Color(0.95, 0.12, 0.1), clampf((wv - 0.6) / 0.3, 0.0, 1.0))
			if car.tyre_temp < 0.9:
				col = col.lerp(Color(0.25, 0.55, 1.0), (0.9 - car.tyre_temp) / 0.6)
			draw_rect(Rect2(p, Vector2(w, h)), Color(0.03, 0.03, 0.04, 0.85))
			draw_rect(Rect2(p + Vector2(3, 3 + (h - 6) * wv), Vector2(w - 6, (h - 6) * (1.0 - wv))), col)
			draw_string(font, p + Vector2(0, h + 13), "%d%%" % int(round((1.0 - wv) * 100.0)), HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color.WHITE)
		var cmp: Dictionary = car.COMPOUNDS[car.compound]
		var cc := o + Vector2(gap.x * 0.5 + w * 0.5, gap.y * 0.5 + h * 0.5)
		draw_circle(cc, 13.0, Color(0.05, 0.05, 0.07))
		draw_arc(cc, 13.0, 0, TAU, 20, cmp["color"], 3.0)
		draw_string(font, cc + Vector2(-13, 6), cmp["short"], HORIZONTAL_ALIGNMENT_CENTER, 26, 17, cmp["color"])
		if car.fuel_use > 0.0:
			var fy := o.y + gap.y + h + 24.0
			var frac := clampf(car.fuel / maxf(car.fuel_cap, 0.1), 0.0, 1.0)
			var fcol := Color(0.95, 0.12, 0.1) if car.fuel < 1.0 else Color(0.98, 0.75, 0.15)
			draw_rect(Rect2(Vector2(o.x, fy), Vector2(gap.x + w, 10)), Color(0.03, 0.03, 0.04, 0.85))
			draw_rect(Rect2(Vector2(o.x + 2, fy + 2), Vector2((gap.x + w - 4) * frac, 6)), fcol)
			draw_string(font, Vector2(o.x, fy + 26), "Comb. %.1f v" % car.fuel, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)


class Lights extends Control:
	var count := 0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.07, 0.85))
		for k in 5:
			var c := Vector2(size.x * (k + 0.5) / 5.0, size.y * 0.5)
			draw_circle(c, size.y * 0.32, Color(0.95, 0.05, 0.05) if k < count else Color(0.2, 0.05, 0.05))


func setup(r) -> void:
	race = r
	font = ThemeDB.fallback_font
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# torre de posições (canto superior esquerdo)
	var tower := VBoxContainer.new()
	tower.position = Vector2(24, 24)
	tower.add_theme_constant_override("separation", 3)
	root.add_child(tower)
	for k in 5:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		var num := _box_label("", NAVY, Color.WHITE, 18, 36)
		var code := _box_label("", PAPER, INK, 18, 96)
		row.add_child(num[0])
		row.add_child(code[0])
		tower.add_child(row)
		tower_rows.append([num, code, row])

	# volta e cronômetro (topo)
	var top := HBoxContainer.new()
	_anchor(top, 0.5, 0.0, Vector2(-300, 24), Vector2.ZERO)
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	lap_label = _box_label("0/0", PAPER, INK, 22, 110)[1]
	top.add_child(lap_label.get_parent())
	var tbox := HBoxContainer.new()
	tbox.add_theme_constant_override("separation", 0)
	top.add_child(tbox)
	time_title = _box_label("Atual", PAPER, INK, 20, 110)[1]
	tbox.add_child(time_title.get_parent())
	time_label = _box_label("0:00.000", Color(0.05, 0.05, 0.07, 0.92), Color.WHITE, 22, 140)[1]
	tbox.add_child(time_label.get_parent())
	var under := VBoxContainer.new()
	_anchor(under, 0.5, 0.0, Vector2(-180, 70), Vector2.ZERO)
	root.add_child(under)
	best_label = _plain(18)
	under.add_child(best_label)
	sector_label = _plain(18)
	under.add_child(sector_label)
	target_label = _plain(18)
	under.add_child(target_label)

	# posição (canto superior direito)
	var pv := VBoxContainer.new()
	_anchor(pv, 1.0, 0.0, Vector2(-200, 20), Vector2.ZERO)
	pv.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(pv)
	pos_label = _plain(54)
	pos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pos_label.custom_minimum_size.x = 176
	pv.add_child(pos_label)
	pos_sub = _plain(18)
	pos_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pos_sub.custom_minimum_size.x = 176
	pv.add_child(pos_sub)
	gap_label = _plain(18)
	gap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gap_label.custom_minimum_size.x = 176
	pv.add_child(gap_label)

	# conta-giros (canto inferior direito)
	tacho = Tacho.new()
	tacho.font = font
	_anchor(tacho, 1.0, 1.0, Vector2(-250, -250), Vector2(230, 230))
	tacho.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tacho)

	# minimapa e estado do kart (canto inferior esquerdo)
	minimap = Minimap.new()
	_anchor(minimap, 0.0, 1.0, Vector2(20, -290), Vector2(190, 190))
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(minimap)
	minimap.setup(race)
	info_label = _plain(17)
	_anchor(info_label, 0.0, 1.0, Vector2(24, -96), Vector2(300, 90))
	root.add_child(info_label)
	tyres = Tyres.new()
	tyres.font = font
	tyres.car = race.player
	tyres.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(tyres, 0.0, 1.0, Vector2(222, -262), Vector2(110, 190))
	root.add_child(tyres)
	pit_label = _plain(24)
	pit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(pit_label, 0.5, 0.0, Vector2(-400, 150), Vector2(800, 70))
	root.add_child(pit_label)

	# com botões de toque: conta-giros embaixo no centro, minimapa sob a torre de posições
	if race.touch != null:
		_anchor(tacho, 0.5, 1.0, Vector2(-95, -195), Vector2(190, 190))
		_anchor(minimap, 0.0, 0.0, Vector2(20, 200), Vector2(150, 150))
		_anchor(info_label, 0.0, 0.0, Vector2(24, 356), Vector2(300, 90))
		_anchor(tyres, 0.0, 0.0, Vector2(186, 190), Vector2(110, 190))

	# mensagens e luzes
	msg_label = _plain(40)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(msg_label, 0.5, 0.5, Vector2(-450, -170), Vector2(900, 60))
	root.add_child(msg_label)
	lights = Lights.new()
	_anchor(lights, 0.5, 0.0, Vector2(-160, 130), Vector2(320, 70))
	lights.visible = false
	root.add_child(lights)

	# pausa
	pause_panel = PanelContainer.new()
	pause_panel.custom_minimum_size = Vector2(600, 552)
	_anchor(pause_panel, 0.5, 0.5, Vector2(-300, -276), Vector2(600, 552))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("101b2b")
	sb.set_corner_radius_all(12)
	sb.border_width_left = 6
	sb.border_color = Color("54d7e4")
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	pause_panel.add_theme_stylebox_override("panel", sb)
	pause_box = VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	pause_panel.add_child(scroll)
	pause_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pause_box)
	pause_panel.visible = false
	root.add_child(pause_panel)


func _anchor(c: Control, ax: float, ay: float, off: Vector2, sz: Vector2) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + sz.x
	c.offset_bottom = off.y + sz.y


func _box_label(text: String, bg: Color, fg: Color, fsize: int, min_w: float) -> Array:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(min_w, 0)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", fg)
	pc.add_child(l)
	return [pc, l]


func _plain(fsize: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func message(text: String, dur := 2.5) -> void:
	msg_label.text = text
	msg_t = dur


func set_lights(count: int, visible_now: bool) -> void:
	lights.visible = visible_now
	lights.count = count
	lights.queue_redraw()


func show_settings(entries: Array, heading := "CONFIGURAÇÕES DO KART") -> void:
	## Submenu da pausa: cada linha troca um valor (A/Enter/toque avança, ←/→ escolhem) e vale na hora.
	## entries: [{"label", "options", "get": Callable -> int, "set": Callable(int)}]
	in_settings = true
	pause_panel.visible = true
	for c in pause_box.get_children():
		c.queue_free()
	var title := Label.new()
	title.text = heading
	title.add_theme_font_size_override("font_size", 26)
	pause_box.add_child(title)
	var first: Button = null
	for e in entries:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var entry: Dictionary = e
		var refresh := func():
			var opts: Array = entry["options"]
			b.text = "%s:   ‹ %s ›" % [entry["label"], opts[clampi(entry["get"].call(), 0, opts.size() - 1)]]
		var step := func(d: int):
			var opts: Array = entry["options"]
			entry["set"].call((entry["get"].call() + d + opts.size()) % opts.size())
			Game.sfx("move")
			for c in pause_box.get_children():
				if c.has_meta("refresh"):
					(c.get_meta("refresh") as Callable).call()
		b.set_meta("refresh", refresh)
		refresh.call()
		b.pressed.connect(func(): step.call(1))
		b.gui_input.connect(func(ev: InputEvent):
			if ev.is_action_pressed("ui_left"):
				step.call(-1)
				b.accept_event()
			elif ev.is_action_pressed("ui_right"):
				step.call(1)
				b.accept_event())
		pause_box.add_child(b)
		if first == null:
			first = b
	var back := Button.new()
	back.text = "Voltar"
	back.custom_minimum_size = Vector2(0, 52)
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(func(): pause_action.emit("settings_back"))
	pause_box.add_child(back)
	first.call_deferred("grab_focus")


func show_pause(on: bool, options: Array) -> void:
	in_settings = false
	pause_panel.visible = on
	for c in pause_box.get_children():
		c.queue_free()
	if not on:
		return
	var title := Label.new()
	title.text = "PAUSA"
	title.add_theme_font_size_override("font_size", 30)
	pause_box.add_child(title)
	var first: Button = null
	for opt in options:
		var b := Button.new()
		b.text = opt[1]
		b.custom_minimum_size = Vector2(0, 52)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var action: String = opt[0]
		b.pressed.connect(func(): pause_action.emit(action))
		pause_box.add_child(b)
		if first == null:
			first = b
	first.call_deferred("grab_focus")


func _process(delta: float) -> void:
	if race == null or race.player == null:
		return
	var p = race.player
	var cfg: Dictionary = race.cfg
	var mode: String = cfg["mode"]
	msg_t -= delta
	msg_label.modulate.a = clampf(msg_t * 2.0, 0.0, 1.0)

	# volta
	if mode == "race":
		lap_label.text = "%d/%d" % [clampi(p.max_lap, 1, cfg["laps"]), cfg["laps"]]
	else:
		var tl: int = cfg.get("timed_laps", 0)
		lap_label.text = ("Volta %d/%d" % [clampi(p.max_lap, 1, tl), tl]) if tl > 0 else ("Volta %d" % maxi(p.max_lap, 1))
	var cur := 0.0
	if race.state == "running" or race.state == "cooldown":
		cur = race.t - p.lap_start if p.max_lap >= 1 else 0.0
		if mode == "race" and p.max_lap < 1:
			cur = race.t - race.start_time
	time_title.text = "Atual" + (" (inválida)" if p.lap_invalid and mode != "race" else "")
	time_label.text = Game.fmt_time(cur) if cur > 0.0 else "0:00.000"
	best_label.text = "Melhor volta  %s" % Game.fmt_time(p.best_lap)
	var sec_txt := "Setor %d" % (p.sector + 1)
	if p.sector > 0:
		sec_txt += "   S1 %.3f" % p.splits[0]
	if p.sector > 1:
		sec_txt += "   S2 %.3f" % p.splits[1]
	sector_label.text = sec_txt
	target_label.text = ("Meta  %s" % Game.fmt_time(cfg["target"])) if cfg.get("target", 0.0) > 0.0 else ""

	# posição
	if mode == "race":
		var idx: int = race.order.find(p)
		pos_label.text = "P%d" % (idx + 1)
		pos_sub.text = "de %d" % race.cars.size()
		if idx > 0:
			var ahead = race.order[idx - 1]
			var gap: float = (ahead.progress() - p.progress()) / maxf(absf(p.vx), 15.0)
			gap_label.text = "Frente  +%.1f s" % gap if not ahead.finished else ""
		else:
			gap_label.text = "Liderando"
		_tower(idx)
	else:
		pos_label.text = ""
		pos_sub.text = Game.fmt_time(Game.record_for(cfg["track"], cfg["weather"])) if mode == "time_trial" else ""
		if mode == "time_trial":
			pos_sub.text = "Recorde " + pos_sub.text
		gap_label.text = ""
		for row in tower_rows:
			row[2].visible = false

	# conta-giros e estado
	tacho.rpm = p.rpm
	tacho.gear = "R" if p.gear == -1 else str(p.gear)
	tacho.kmh = p.speed_kmh()
	tacho.queue_redraw()
	minimap.queue_redraw()
	tyres.queue_redraw()
	pit_label.text = _pit_text(p)
	var lines: Array = []
	if Game.settings["damage"]:
		lines.append("Danos %d%%" % int(round(p.damage * 100.0)))
	if p.penalty > 0.0:
		lines.append("Penalidade +%ds" % int(p.penalty))
	var assists := []
	if p.tc:
		assists.append("TC")
	if p.abs_on:
		assists.append("ABS")
	if p.stability:
		assists.append("EST")
	if int(Game.settings["brake_assist"]) == 1:
		assists.append("FRE")
	assists.append("AUTO" if p.auto_gear else "MANUAL")
	lines.append(" ".join(assists))
	info_label.text = "\n".join(lines)


func _pit_text(p) -> String:
	## Avisos do box: chamado, pit lane, contagem da parada e combustível no fim.
	match p.pit_state:
		1:
			if p.out_of_fuel:
				return "SEM COMBUSTÍVEL  ·  mecânicos empurrando até o box"
			return "PIT LANE  ·  limite 50 km/h"
		2:
			var sv: Dictionary = p.pit_service
			var parts: Array = []
			if int(sv.get("tyre", -1)) >= 0:
				parts.append("pneus " + String(p.COMPOUNDS[int(sv["tyre"])]["name"]).to_lower())
			if float(sv.get("fuel", 0.0)) > 0.05:
				parts.append("+%.1f voltas de combustível" % float(sv["fuel"]))
			if sv.get("repair", false):
				parts.append("reparo")
			return "PARADA  %.1f s\n%s" % [maxf(0.0, p.pit_total - p.pit_timer), ", ".join(parts) if not parts.is_empty() else "só verificação"]
		3:
			return "SAINDO DO BOX"
	if p.pit_request:
		return "BOX CHAMADO  ·  entre no pit lane"
	if race.cfg["mode"] == "race" and p.fuel_use > 0.0 and p.fuel < 1.15 and p.fuel < race._remaining_laps(p):
		return "COMBUSTÍVEL NO FIM  ·  pare no box"
	if p.tyre_wear.max() > 0.85:
		return "PNEUS NO FIM"
	return ""


func _tower(idx: int) -> void:
	var start := clampi(idx - 2, 0, maxi(0, race.order.size() - 5))
	for k in 5:
		var row: Array = tower_rows[k]
		var oi := start + k
		if oi >= race.order.size():
			row[2].visible = false
			continue
		row[2].visible = true
		var c = race.order[oi]
		var num_lbl: Label = row[0][1]
		var code_lbl: Label = row[1][1]
		num_lbl.text = str(oi + 1)
		code_lbl.text = c.driver["code"] + ("  BOX" if c.pit_state > 0 else "")
		var sb: StyleBoxFlat = row[0][0].get_theme_stylebox("panel")
		sb.bg_color = RED if c.is_player else NAVY
