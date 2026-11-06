extends CanvasLayer
const TEXT := {"start":"Boa corrida. Mantenha a concentração.","last_lap":"Última volta!","win":"Vitória! Excelente corrida!","finish":"Bandeirada. Bom trabalho!","rain_soon":"Chuva se aproximando. Atenção à aderência.","wet":"Pista molhada. Considere pneus de chuva.","drying":"A pista está secando. Avalie pneus de seco.","tyres":"Pneus gastos. Considere uma parada.","fuel":"Combustível baixo. Precisamos entrar nos boxes.","damage":"Temos danos. Cuidado nas próximas curvas.","gain":"Ganhamos uma posição!","loss":"Perdemos uma posição. Mantenha a calma.","pit":"Entrada nos boxes. Respeite o limite.","out":"Serviço concluído. Cuidado ao voltar à pista.","ghost":"Nova melhor volta. Fantasma atualizado."}
var voice: AudioStreamPlayer
var caption: Label
var messages: Array = []
var clock := 0.0
var until := 0.0
var last: Dictionary = {}
var suspended := false
func _ready() -> void:
	layer = 4
	voice = AudioStreamPlayer.new()
	add_child(voice)
	caption = Label.new()
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	caption.position = Vector2(-330,148)
	caption.size = Vector2(660,66)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size",20)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(.04,.09,.14,.88)
	box.set_corner_radius_all(6)
	caption.add_theme_stylebox_override("normal",box)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
	caption.hide()
func say(key: String, detail := "", priority := false) -> void:
	if not TEXT.has(key) or not bool(Game.settings.get("radio",true)): return
	if clock - float(last.get(key,-100.0)) < (20.0 if key in ["gain","loss"] else 45.0): return
	last[key] = clock
	if priority:
		messages.clear()
		voice.stop()
		until = clock
	messages.append({"key":key,"text":TEXT[key]+(" "+detail if detail!="" else ""),"expires":clock+12.0})
	if messages.size()>3: messages.pop_front()
func silence() -> void:
	messages.clear()
	voice.stop()
	caption.hide()
	until = clock
func _process(dt: float) -> void:
	voice.stream_paused = suspended
	if suspended: return
	clock += dt
	voice.volume_db = linear_to_db(maxf(.0001,float(Game.settings["volume"])*.8))
	if not bool(Game.settings.get("radio",true)):
		silence()
		return
	if clock >= until:
		caption.hide()
		if not messages.is_empty():
			var msg: Dictionary = messages.pop_front()
			if float(msg["expires"])<clock: return
			caption.text = "RÁDIO  •  "+msg["text"]
			caption.show()
			voice.stream = load("res://sounds/radio/"+msg["key"]+".wav")
			voice.play()
			until = clock + maxf(4.0,voice.stream.get_length()+1.0)
