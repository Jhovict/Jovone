extends Node
## Som do jogo com gravações reais do Freesound (CC0 e CC-BY 4.0; créditos em sounds/CREDITOS.txt):
## - motor do jogador por síntese granular: ciclos de explosão recortados das gravações (marcha lenta de
##   um kart de verdade, kart acelerando gravado a bordo, 2 tempos em giro alto; tools/make_grains.py)
##   são disparados um a cada explosão do motor do jogo, então o ronco segue o RPM e o acelerador na
##   hora (sem cara de gravação tocando por cima); um filtro abafa o som quando o pé sai;
## - motores dos adversários em 3D presos a cada kart, com efeito Doppler;
## - partida real de kart no grid, pneu cantando, batida, bipe da largada e ambiente do kartódromo;
## - clima: chuva em loop (mais alta na tempestade) e trovões que chegam depois do clarão do raio;
## - vento e trepidação da zebra continuam sintetizados (são ruídos simples).

const ENGINE_MID := preload("res://sounds/engine_mid.wav")
const GRAINS_PATH := "res://sounds/engine_grains.json"
## Explosões por segundo = RPM / 60 × FIRE_SCALE (marcha lenta do jogo, 3500 rpm, no tom da gravação).
const FIRE_SCALE := 47.5 * 60.0 / 3500.0
const VOICES := 16
const START := preload("res://sounds/start.wav")
const SKID := preload("res://sounds/skid.wav")
const BEEP := preload("res://sounds/beep.wav")
const AMBIENCE := preload("res://sounds/ambience.wav")
const CRASHES := [preload("res://sounds/crash_1.wav"), preload("res://sounds/crash_2.wav")]
const RAIN := preload("res://sounds/rain.wav")
const THUNDERS := [preload("res://sounds/thunder_1.wav"), preload("res://sounds/thunder_2.wav")]
## Clima: volume da chuva e do vento.
const WEATHER_MIX := {"dry": [0.0, 1.0], "rain": [0.45, 1.0], "storm": [0.85, 1.6], "snow": [0.0, 1.5]}
## RPM do jogo que corresponde ao tom da gravação usada pelos adversários.
const REF_MID := 3500.0 * 92.0 / 47.5
const RATE := 22050.0
const BUS := "Motor"

var muted := false
var rain_amount := -1.0
var radio_duck := false

# valores atualizados pela corrida
var rpm := 3500.0
var thr := 0.0
var slip := 0.0
var speed := 0.0
var kerb := false
var ai_rpm := 0.0          # mantidos por compatibilidade (o som dos adversários agora é 3D)
var ai_gain := 0.0

var _skid: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _rain: AudioStreamPlayer
var _thunder: AudioStreamPlayer
var _thunder_q: Array = []      # [segundos até tocar, força]
var _weather := "dry"
var _beep: AudioStreamPlayer
var _start: AudioStreamPlayer
var _crash: Array = []
var _ai: Array = []        # [kart, AudioStreamPlayer3D]
var _lp: AudioEffectLowPassFilter
var _rpm := 3500.0
var _thr := 0.0
var _engine_gain := 1.0    # sobe depois da partida
var _cut := 0.0
var _gain_smooth := 0.0
var _body_phase := 0.0
var _shift_tick := 0.0
var _last_thr := 0.0
var _overrun := 0.0
var _last_hit := -1.0
var _t := 0.0

# motor granular: grãos por conjunto (marcha lenta, médio, alto) e vozes tocando
var _eng_player: AudioStreamPlayer
var _eng: AudioStreamGeneratorPlayback
var _grains: Array = []                 # conjunto -> Array de PackedFloat32Array
var _v_grain: Array = []                # voz -> grão (PackedFloat32Array) ou null
var _v_pos := PackedInt32Array()
var _v_gain := PackedFloat32Array()
var _fire_ph := 0.0
var _eng_gain := 0.0

# sintetizador simples: vento e zebra
var _gen_player: AudioStreamPlayer
var _gen: AudioStreamGeneratorPlayback
var _wind := 0.0
var _roar := 0.0
var _roar2 := 0.0
var _gust_t := 0.0
var _rb_ph := 0.0


func _ready() -> void:
	_make_bus()
	for loop in [ENGINE_MID, SKID, AMBIENCE, RAIN]:
		_set_loop(loop)
	_rain = _player(RAIN)
	_rain.volume_db = -80.0
	_thunder = _player(null, "Master", false)
	_load_grains()
	_eng_player = AudioStreamPlayer.new()
	_eng_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var eg := AudioStreamGenerator.new()
	eg.mix_rate = RATE
	eg.buffer_length = 0.05          # pouco atraso entre o pedal e o som
	_eng_player.stream = eg
	_eng_player.bus = BUS
	add_child(_eng_player)
	_eng_player.play()
	_eng = _eng_player.get_stream_playback()
	_amb = _player(AMBIENCE)
	_amb.volume_db = -80.0
	_beep = _player(BEEP, "Master", false)
	_skid = _player(SKID)
	_skid.volume_db = -80.0
	_start = _player(START, "Master", false)
	for k in 2:
		_crash.append(_player(null, "Master", false))
	_gen_player = AudioStreamPlayer.new()
	_gen_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	var g := AudioStreamGenerator.new()
	g.mix_rate = RATE
	g.buffer_length = 0.1
	_gen_player.stream = g
	add_child(_gen_player)
	_gen_player.play()
	_gen = _gen_player.get_stream_playback()


func _load_grains() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(GRAINS_PATH))
	if not (data is Dictionary):
		return
	for st in data["sets"]:
		var arr: Array = []
		for g in st["grains"]:
			arr.append(PackedFloat32Array(g))
		_grains.append(arr)
	_v_grain.resize(VOICES)
	_v_pos.resize(VOICES)
	_v_gain.resize(VOICES)
	for k in VOICES:
		_v_pos[k] = -1


func _make_bus() -> void:
	## Barramento do motor do jogador com passa-baixas (abre com o acelerador).
	var idx := AudioServer.get_bus_index(BUS)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS)
		AudioServer.set_bus_send(idx, "Master")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 6000.0
		lp.resonance = 0.6
		AudioServer.add_bus_effect(idx, lp)
	_lp = AudioServer.get_bus_effect(idx, 0)
	# limitador no volume geral: 16 motores juntos no grid não saturam a saída
	var master := AudioServer.get_bus_index("Master")
	var has_limiter := false
	for k in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, k) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		lim.pre_gain_db = 0.0
		AudioServer.add_bus_effect(master, lim)


static func _set_loop(s: AudioStreamWAV) -> void:
	if s.loop_mode == AudioStreamWAV.LOOP_FORWARD:
		return
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)


func _player(stream: AudioStream, bus := "Master", autoplay := true) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	add_child(p)
	if autoplay and stream:
		p.play()
	return p


func _vol() -> float:
	return float(Game.settings["volume"]) * (0.0 if muted else 1.0)


# ---------------------------------------------------------------- eventos

func engine_start() -> void:
	## Partida no grid: toca a gravação do motor pegando e o loop do motor entra depois.
	_engine_gain = 0.0
	_start.volume_db = linear_to_db(maxf(0.001, _vol() * 0.9))
	_start.play()


func setup_ai(cars: Array, player_car) -> void:
	## Cada adversário leva o próprio motor em 3D (o volume cai com a distância; Doppler ao passar).
	for c in cars:
		if c == player_car:
			continue
		var p := AudioStreamPlayer3D.new()
		p.stream = ENGINE_MID
		p.unit_size = 5.0
		p.max_distance = 110.0
		p.max_db = 0.0
		p.volume_db = -13.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		p.attenuation_filter_cutoff_hz = 4000.0
		p.position = Vector3(0, 0.4, 0.4)
		c.add_child(p)
		p.play(randf() * 0.4)
		_ai.append([c, p])


func set_weather(w: String) -> void:
	_weather = w


func thunder(delay: float, strength: float) -> void:
	## Trovão: chega `delay` segundos depois do clarão (raio mais longe = mais atraso e mais fraco).
	_thunder_q.append([delay, strength])


func impact(strength: float) -> void:
	if strength < 0.12 or _t - _last_hit < 0.25:
		return
	_last_hit = _t
	var p: AudioStreamPlayer = _crash[randi() % _crash.size()]
	p.stream = CRASHES[randi() % CRASHES.size()]
	p.pitch_scale = randf_range(0.85, 1.15)
	p.volume_db = linear_to_db(maxf(0.001, _vol() * clampf(strength, 0.25, 1.0)))
	p.play()


func beep(freq: float, _dur: float) -> void:
	## Bipe gravado; o tom sobe para o sinal de largada (frequência maior).
	_beep.pitch_scale = clampf(freq / 760.0, 0.7, 2.0)
	_beep.volume_db = linear_to_db(maxf(0.001, _vol() * 0.7))
	_beep.play()


func shift() -> void:
	_cut = 0.075
	_shift_tick = 1.0


# ---------------------------------------------------------------- mistura

func _process(delta: float) -> void:
	_t += delta
	var v := _vol()
	for p in [_eng_player, _skid, _amb, _rain, _thunder, _gen_player]:
		(p as AudioStreamPlayer).stream_paused = muted
	for a in _ai:
		(a[1] as AudioStreamPlayer3D).stream_paused = muted
	if muted:
		return
	# motor do jogador
	_rpm = lerpf(_rpm, rpm, minf(1.0, delta * 30.0))
	_thr = lerpf(_thr, thr, minf(1.0, delta * 25.0))
	# a gravação da partida pega aos ~3,8 s; o motor entra por baixo dela
	if not _start.playing or _start.get_playback_position() > 3.9:
		_engine_gain = move_toward(_engine_gain, 1.0, delta * 0.8)
	_cut = maxf(0.0, _cut - delta)
	var cut := 0.24 if _cut > 0.0 else 1.0
	if _last_thr > 0.55 and thr < 0.15 and rpm > 6500.0:
		_overrun = 0.35
	_last_thr = thr
	_overrun = maxf(0.0, _overrun - delta)
	_eng_gain = _engine_gain * cut * v * (0.60 if radio_duck else 1.0)
	_engine_fill()
	var mix: Array = WEATHER_MIX.get(_weather, WEATHER_MIX["dry"])
	_amb.volume_db = linear_to_db(maxf(0.0005, v * 0.35 * (0.5 if _weather == "storm" else 1.0)))
	_rain.volume_db = linear_to_db(maxf(0.0005, v * (float(mix[0]) if rain_amount < 0.0 else rain_amount)))
	for q in _thunder_q.duplicate():
		q[0] -= delta
		if q[0] <= 0.0:
			_thunder_q.erase(q)
			_thunder.stream = THUNDERS[randi() % THUNDERS.size()]
			_thunder.pitch_scale = randf_range(0.85, 1.05)
			_thunder.volume_db = linear_to_db(maxf(0.001, v * float(q[1])))
			_thunder.play()
	if _lp:
		_lp.cutoff_hz = lerpf(1600.0, 9000.0, _thr) + clampf(_rpm / 14800.0, 0.0, 1.0) * 2500.0
	# pneu cantando
	var squeal := clampf((slip - 0.07) * 3.0, 0.0, 1.0)
	_skid.volume_db = linear_to_db(maxf(0.0005, squeal * v * 0.7))
	_skid.pitch_scale = 0.9 + 0.2 * clampf(speed / 30.0, 0.0, 1.0)
	# adversários
	for a in _ai:
		var c = a[0]
		var p: AudioStreamPlayer3D = a[1]
		var voice := 0.975 + float(c.get_instance_id() % 11) * 0.005
		p.pitch_scale = lerpf(p.pitch_scale, clampf(float(c.rpm) / REF_MID * voice, 0.45, 2.15), 1.0 - exp(-delta * 18.0))
		p.volume_db = -13.0 + linear_to_db(maxf(0.001, v * (0.55 + 0.45 * float(c.throttle))))
	_synth(v)


func _fire() -> void:
	## Uma explosão: escolhe um grão do conjunto da faixa de rotação (sorteio pesado, o que mistura os
	## timbres na transição) e põe numa voz livre. Sem acelerador em giro alto o 2 tempos falha e estala.
	if _grains.is_empty():
		return
	var w_idle := clampf((6500.0 - _rpm) / 2500.0, 0.0, 1.0)
	var w_high := clampf((_rpm - 9500.0) / 3000.0, 0.0, 1.0)
	var r := randf()
	var set_i := 0 if r < w_idle else (2 if r > 1.0 - w_high else 1)
	set_i = mini(set_i, _grains.size() - 1)
	var gain := (0.34 + 0.66 * _thr) * randf_range(0.94, 1.04)
	if _thr < 0.1 and _rpm > 7000.0:
		var x := randf()
		if x < 0.22:
			return                  # falha de ignição
		if x > 0.985 and _overrun > 0.0:
			gain *= 1.25             # estalo no escapamento
	var grains: Array = _grains[set_i]
	var g: PackedFloat32Array = grains[randi() % grains.size()]
	# mais explosões sobrepostas em giro alto: compensa para o volume não disparar
	var overlap := float(g.size()) * (_rpm / 60.0 * FIRE_SCALE) / RATE
	gain *= pow(clampf(2.0 / maxf(overlap, 0.1), 0.35, 1.0), 0.6)
	var slot := -1
	for k in VOICES:
		if _v_pos[k] < 0:
			slot = k
			break
	if slot < 0:
		return
	_v_grain[slot] = g
	_v_pos[slot] = 0
	_v_gain[slot] = gain


func _engine_fill() -> void:
	if _eng == null:
		return
	var frames := _eng.get_frames_available()
	if frames <= 0:
		return
	var step: float = clampf(_rpm, 1500.0, 16000.0) / 60.0 * FIRE_SCALE / RATE
	var buf := PackedVector2Array()
	buf.resize(frames)
	var vol := _eng_gain * 0.66
	for i in frames:
		_fire_ph += step
		if _fire_ph >= 1.0:
			_fire_ph -= 1.0
			_fire()
		var out := 0.0
		for k in VOICES:
			var pos := _v_pos[k]
			if pos < 0:
				continue
			var g: PackedFloat32Array = _v_grain[k]
			out += g[pos] * _v_gain[k]
			pos += 1
			_v_pos[k] = pos if pos < g.size() else -1
		# Short continuous gain ramps eliminate buffer-edge clicks on pedal and shifts.
		_gain_smooth += (vol - _gain_smooth) * 0.006
		_body_phase = fmod(_body_phase + step * 0.5, 1.0)
		var body := (sin(_body_phase * TAU) + 0.28 * sin(_body_phase * TAU * 2.0)) * (0.035 + 0.055 * _thr)
		var click := sin(_body_phase * TAU * 7.0) * _shift_tick * 0.09
		_shift_tick *= 0.995
		out = (out + body + click) * _gain_smooth
		out = out / (1.0 + absf(out) * 0.32)
		buf[i] = Vector2(out, out)
	_eng.push_buffer(buf)


func _synth(v: float) -> void:
	if _gen == null:
		return
	var frames := _gen.get_frames_available()
	if frames <= 0:
		return
	var wind_gain := clampf(speed / 40.0, 0.0, 1.0)
	_gust_t += float(frames) / RATE
	# rajadas: o vento sobe e desce devagar, como no capacete
	var gust := 0.8 + 0.2 * sin(_gust_t * 0.9) + 0.12 * sin(_gust_t * 2.3 + 1.0)
	var roar_gain := wind_gain * 0.16                   # ronco grave dos pneus no asfalto
	wind_gain *= wind_gain * 0.2 * gust * float(WEATHER_MIX.get(_weather, WEATHER_MIX["dry"])[1])
	var kerb_gain := 0.16 if kerb else 0.0
	var buf := PackedVector2Array()
	buf.resize(frames)
	for i in frames:
		var out := 0.0
		var noise := randf() * 2.0 - 1.0
		_wind += (noise - _wind) * 0.05
		out += _wind * wind_gain
		_roar += (noise - _roar) * 0.012
		_roar2 += (_roar - _roar2) * 0.05
		out += _roar2 * roar_gain * 4.0
		if kerb_gain > 0.0:
			_rb_ph = fmod(_rb_ph + 34.0 / RATE, 1.0)
			out += (sin(_rb_ph * TAU) + 0.35 * sin(_rb_ph * TAU * 2.0)) * kerb_gain
		out = clampf(out * v, -1.0, 1.0)
		buf[i] = Vector2(out, out)
	_gen.push_buffer(buf)
