extends Node3D
## Sessão de pista (corrida, contrarrelógio, classificação ou teste):
## monta kartódromo/karts/câmera/HUD, controla largada, IA, colisões, cronometragem e resultado.

signal finished(result: Dictionary)
signal restart_requested

const Racecraft := preload("res://scripts/racecraft.gd")
const TrackScript := preload("res://scripts/track.gd")
const CarScript := preload("res://scripts/car.gd")
const HudScript := preload("res://scripts/hud.gd")
const AudioScript := preload("res://scripts/engine_audio.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")
const SUBSTEP := 1.0 / 240.0
## Parada no box: tempo fixo (macaco, entrada e saída), troca dos quatro pneus e reabastecimento.
const PIT_BASE_TIME := 1.6
const PIT_TYRE_TIME := 3.0
const PIT_FUEL_TIME := 2.5      # segundos por volta de combustível
const PIT_REPAIR_TIME := 10.0   # segundos para consertar o kart todo (proporcional ao dano)
const TYRE_PLAN := ["Automático", "Macio", "Duro", "Chuva", "Não trocar"]
const FUEL_PLAN := ["Até o fim", "+1 volta", "+2 voltas", "+3 voltas", "+4 voltas", "+6 voltas"]
const FUEL_PLAN_LAPS := [-1.0, 1.0, 2.0, 3.0, 4.0, 6.0]

var replay := preload("res://scripts/finish_replay.gd").new()
var weather_flow := preload("res://scripts/dynamic_weather.gd").new()
var radio
var ghost
var ghost_label: Label
var pending_result: Dictionary = {}
var replay_layer: CanvasLayer
var radio_position := -1
var radio_clock := 0.0
var cfg: Dictionary
var track
var cars: Array = []
var player
var camera: Camera3D
var hud
var audio
var rain: CPUParticles3D
var state := "intro"        # intro, lights, running, cooldown, done
var t := 0.0
var state_t := 0.0
var lights_on := 0
var go_delay := 0.0
var start_time := 0.0
var paused := false
var cam_mode := 0
var look_back := false
var shake := 0.0
# sensação de velocidade: aceleração e curva suavizadas para a câmera, tempo do tremor e riscos na tela
var camera_motion := preload("res://scripts/camera_motion.gd").new()
var cam_acc := 0.0
var cam_lat := 0.0
var cam_t := 0.0
var cam_prev_vx := 0.0
var speed_fx: ColorRect
var speed_flow := 0.0
var finish_count := 0
var race_over := false
var order: Array = []
var timed_done := 0
var player_steer := 0.0
var player_thr := 0.0
var player_brk := 0.0
var cam_pos := Vector3.ZERO
var cam_h := 0.0
var last_shift := 0
var touch: Control = null    # botões na tela (celular/tablet)
var autopilot := false      # usado pelo teste automático
var test_driver := false    # teste: acelerador no fundo, nunca freia e esterça para a linha (testa as assistências)
var pit_rule := 0           # 0 = combustível e pneus sem estratégia, 1 ou 2 = corrida pensada para 1 ou 2 paradas
var pit_plan := {"tyre": 0, "fuel": 0, "repair": true}   # o que o jogador quer na próxima parada (índices dos menus)


func setup(config: Dictionary) -> void:
	cfg = config
	if not cfg.has("weather"):
		cfg["weather"] = "dry"
	var wet: bool = cfg["weather"] != "dry"
	track = TrackScript.new()
	add_child(track)
	track.build(Game.tracks[cfg["track"]], cfg["weather"])
	track.set_line_visible(bool(Game.settings["racing_line"]))
	_build_environment(cfg["weather"])
	_spawn_cars(wet)
	camera = Camera3D.new()
	camera.near = 0.05
	camera.far = 5000.0
	add_child(camera)
	camera.current = true
	cam_mode = int(Game.settings["camera"])
	var fx_layer := CanvasLayer.new()
	fx_layer.layer = 0                 # abaixo do HUD
	add_child(fx_layer)
	speed_fx = ColorRect.new()
	speed_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	speed_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://scripts/speed_fx.gdshader")
	speed_fx.material = sm
	speed_fx.visible = false
	fx_layer.add_child(speed_fx)
	if TouchScript.should_show():
		var layer := CanvasLayer.new()
		layer.layer = 5
		add_child(layer)
		touch = TouchScript.new()
		layer.add_child(touch)
	hud = HudScript.new()
	add_child(hud)
	hud.setup(self)
	hud.pause_action.connect(_on_pause_action)
	audio = AudioScript.new()
	add_child(audio)
	audio.setup_ai(cars, player)
	audio.set_weather(cfg["weather"])
	audio.engine_start()
	radio = preload("res://scripts/team_radio.gd").new()
	add_child(radio)
	weather_flow.setup(self)
	if cfg["mode"] == "time_trial":
		ghost = preload("res://scripts/lap_ghost.gd").new()
		add_child(ghost)
		ghost.setup(player,int(cfg["track"]),cfg["weather"])
		ghost_label = Label.new()
		ghost_label.position = Vector2(24,95)
		ghost_label.add_theme_font_size_override("font_size",18)
		hud.root.add_child(ghost_label)
	camera.doppler_tracking = Camera3D.DOPPLER_TRACKING_IDLE_STEP
	_update_order()
	_update_camera(0.0, true)
	var title: String = cfg.get("title", "")
	hud.message(title, 2.5)


## Clima: céu (topo, horizonte), luz do sol, luz ambiente e neblina.
const SKY := {
	"dry": [Color(0.18, 0.4, 0.82), Color(0.72, 0.82, 0.95), 1.6, 0.7, 0.0009],
	"rain": [Color(0.34, 0.37, 0.42), Color(0.58, 0.6, 0.63), 0.55, 0.6, 0.0055],
	"storm": [Color(0.13, 0.14, 0.17), Color(0.33, 0.35, 0.38), 0.25, 0.42, 0.011],
	"snow": [Color(0.62, 0.66, 0.72), Color(0.86, 0.88, 0.91), 0.7, 0.85, 0.006],
}
var env: Environment
var sun: DirectionalLight3D
var flash_t := 0.0          # raio: tempo até o próximo, depois clarão
var flash := 0.0
var flash2 := -1.0         # segundo clarão do mesmo raio


func _build_environment(weather: String) -> void:
	var look: Array = SKY.get(weather, SKY["dry"])
	var sky_mat := ProceduralSkyMaterial.new()
	var horizon: Color = look[1]
	sky_mat.sky_top_color = look[0]
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon
	sky_mat.ground_bottom_color = Color(0.85, 0.87, 0.9) if weather == "snow" else Color(0.2, 0.24, 0.2)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = look[3]
	# luz ambiente menos azulada para preservar as cores originais da textura do kart
	e.ambient_light_sky_contribution = 0.55
	e.ambient_light_color = Color(0.85, 0.83, 0.8)
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	e.tonemap_exposure = 1.1
	e.ssao_enabled = true
	e.ssao_radius = 0.6
	e.ssao_intensity = 1.5
	e.fog_enabled = true
	e.fog_light_color = horizon
	e.fog_density = look[4]
	e.fog_sky_affect = 0.3
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	env = e
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 35, 0)
	sun.light_energy = look[2]
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	flash_t = randf_range(4.0, 9.0)
	var lite := Game.lite_models()
	match weather:
		"rain":
			rain = _drops(1800, 0.7, Vector3(0, -1, 0), 22.0, 28.0, 0.55, 0.35)
		"storm":
			# chuva forte e inclinada pelo vento
			rain = _drops(2000 if lite else 3800, 0.6, Vector3(0.28, -1, 0.12), 27.0, 34.0, 0.7, 0.42)
		"snow":
			rain = CPUParticles3D.new()
			rain.amount = 1200 if lite else 2600
			rain.lifetime = 4.0
			rain.preprocess = 4.0
			rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			rain.emission_box_extents = Vector3(24, 0.5, 24)
			rain.direction = Vector3(0.15, -1, 0.05)
			rain.spread = 25.0
			rain.gravity = Vector3.ZERO
			rain.initial_velocity_min = 2.2
			rain.initial_velocity_max = 3.6
			rain.scale_amount_min = 0.6
			rain.scale_amount_max = 1.4
			rain.local_coords = false
			var q := SphereMesh.new()          # floco redondo (um quadrado vira "pixel" perto da câmera)
			q.radius = 0.028
			q.height = 0.056
			q.radial_segments = 6
			q.rings = 3
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(1, 1, 1, 0.85)
			q.material = m
			rain.mesh = q
			add_child(rain)


func _drops(amount: int, life: float, dir: Vector3, vmin: float, vmax: float, length: float, alpha: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(18, 0.5, 18)
	p.direction = dir.normalized()
	p.spread = 3.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.local_coords = false
	var dm := BoxMesh.new()
	dm.size = Vector3(0.012, length, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.8, 0.85, 0.95, alpha)
	dm.material = m
	p.mesh = dm
	add_child(p)
	return p


func _lightning(delta: float) -> void:
	## Tempestade: raios de tempos em tempos (um ou dois clarões) e o trovão chega depois.
	if cfg["weather"] != "storm" or env == null:
		return
	flash_t -= delta
	if flash_t <= 0.0:
		flash = 1.0
		flash2 = randf_range(0.12, 0.3) if randf() < 0.6 else -1.0
		flash_t = randf_range(7.0, 16.0)
		audio.thunder(randf_range(0.4, 2.2), randf_range(0.6, 1.0))
	if flash2 > 0.0:
		flash2 -= delta
		if flash2 <= 0.0:
			flash = 0.85
	var look: Array = SKY["storm"]
	flash = maxf(0.0, flash - delta * 5.0)
	var f := flash * flash
	sun.light_energy = look[2] + f * 3.5
	env.ambient_light_energy = look[3] + f * 2.2
	env.fog_density = look[4] * (1.0 - 0.5 * f)


func _spawn_cars(wet: bool) -> void:
	var mode: String = cfg["mode"]
	var pdrv := {"name": cfg.get("player_name", "Jogador"), "code": cfg.get("player_code", "JOG"),
		"team": cfg["player_team"], "skill": 1.0, "num": cfg.get("player_num", 21)}
	var entries: Array = []
	if mode == "race":
		var field: Array = cfg["field"]
		var slot: int = clampi(cfg.get("player_grid", field.size()), 0, field.size())
		for k in field.size():
			if k == slot:
				entries.append([pdrv, true])
			entries.append([field[k], false])
		if slot >= field.size():
			entries.append([pdrv, true])
	else:
		entries.append([pdrv, true])
	var pace_mult: float = Game.DIFFICULTY_PACE[int(cfg.get("difficulty", 1))] * float(Game.WEATHER_PACE.get(cfg["weather"], 1.0))
	for k in entries.size():
		var drv: Dictionary = entries[k][0]
		var is_p: bool = entries[k][1]
		var car = CarScript.new()
		car.driver = drv
		car.team = Game.teams[int(drv["team"])]
		car.is_player = is_p
		# motor igual para todos fora da carreira (lá a equipe e o desenvolvimento contam)
		car.perf = Game.team_perf(int(drv["team"])) if cfg.get("career", false) else 1.0
		car.pace = float(drv["skill"]) * pace_mult
		car.weather_mu = float(Game.WEATHER_MU.get(cfg["weather"], 1.0))
		car.wet_track = wet
		car.damage_on = bool(Game.settings["damage"])
		if is_p:
			car.tc = bool(Game.settings["tc"])
			car.abs_on = bool(Game.settings["abs"])
			car.stability = bool(Game.settings["stability"])
			car.auto_gear = bool(Game.settings["auto_gear"])
		add_child(car)
		# capacete da pintura da equipe; na carreira o jogador usa a cor que escolheu
		car.build_model(Color(0, 0, 0, 0), not is_p and int(Game.settings.get("quality", 0)) == 0)
		if is_p and cfg.get("career", false):
			Game.Appearance.apply(car, cfg.get("appearance", {}))
			car.set_helmet_design(int(cfg.get("helmet", 0)), int(cfg.get("helmet_visor", 0)), int(cfg.get("helmet_finish", 0)))
		if mode == "race":
			var lat: float = track.GRID_LATERAL
			car.place(track, track.length - track.GRID_START - k * track.GRID_STEP, -lat if k % 2 == 0 else lat)
		else:
			car.place(track, track.length - 40.0, 0.0)
		car.lane = 0.0
		cars.append(car)
		if is_p:
			player = car
	_setup_strategy(wet)


func _setup_strategy(wet: bool) -> void:
	## Combustível e pneus no estilo das corridas com reabastecimento: com a regra ligada, o tanque e a vida
	## dos pneus são medidos pelo tamanho da corrida, então é preciso parar 1 ou 2 vezes. Cada equipe
	## tem o seu box (na ordem das garagens), com uma vaga para cada piloto.
	var race_mode: bool = cfg["mode"] == "race"
	pit_rule = int(cfg.get("pit_rule", Game.settings.get("pit_stops", 1))) if race_mode else 0
	var laps := float(cfg.get("laps", 3))
	var stint := laps / float(pit_rule + 1)
	var bays := {}
	for c in cars:
		c.pit_box = int(c.driver["team"]) % track.PIT_BOXES
		c.pit_bay = int(bays.get(c.pit_box, 0)) % track.PIT_BAYS
		bays[c.pit_box] = int(bays.get(c.pit_box, 0)) + 1
		c.pit_aggr = randf_range(0.0, 0.35)
		if wet:
			c.compound = 2
		elif c.is_player:
			c.compound = int(Game.settings.get("start_tyre", 1))
		else:
			c.compound = 0 if randf() < 0.3 else 1
		if pit_rule > 0:
			c.fuel_use = 1.0
			c.fuel_cap = stint * 1.3 + 0.5
			c.tyre_life = stint * 1.35
			# largada com combustível para parar no fim de uma volta inteira: o jogador vai até onde der,
			# cada adversário escolhe parar mais cedo ou mais tarde
			var first: float = ceilf(stint) if c.is_player or randf() < 0.5 else maxf(1.0, floorf(stint))
			c.fuel = minf(c.fuel_cap, first + 0.35)
		else:
			c.tyre_life = 25.0


# ---------------------------------------------------------------- laço principal

func _physics_process(dt: float) -> void:
	if paused or state in ["done", "replay"]:
		return
	t += dt
	state_t += dt
	_update_state()
	if state in ["done", "replay"]: return
	weather_flow.update(self,dt)
	_player_input(dt)
	for c in cars:
		if not c.is_player or autopilot:
			_ai_drive(c, dt)
	# pneus de kart são rígidos para a massa: integra em passos curtos e fixos,
	# independentemente da taxa de física ou da aceleração de tempo dos testes
	var n_sub := maxi(1, ceili(dt / SUBSTEP - 0.001))
	for k in n_sub:
		for c in cars:
			c.step(dt / n_sub)
		_collide_cars()
	for c in cars:
		_timing(c)
		_pit_logic(c, dt)
	_update_order()
	if cfg["mode"] == "race" and state in ["running", "cooldown"]: replay.capture(dt,cars)
	if ghost and state=="running" and player.lap>=1: ghost.record(dt,t-player.lap_start)
	_radio_update(dt)
	if player.retired and state == "running":
		hud.message("Sem combustível: abandono" if player.retire_reason == "combustível" else "Kart danificado: abandono", 3.0)
		state = "cooldown"
		state_t = 0.0


func _update_state() -> void:
	var mode: String = cfg["mode"]
	match state:
		"intro":
			if mode == "race":
				if state_t > 2.0:
					state = "lights"
					state_t = 0.0
					lights_on = 0
					go_delay = randf_range(0.4, 1.6)
					hud.set_lights(0, true)
			else:
				var left := 3 - int(state_t)
				if left > 0 and hud.msg_t < 0.2:
					hud.message(str(left), 0.9)
					audio.beep(700.0, 0.12)
				if state_t >= 3.0:
					_go()
		"lights":
			var want := mini(5, int(state_t) + 1)
			if want > lights_on and state_t < 5.0:
				lights_on = want
				track.set_start_lights(lights_on)
				hud.set_lights(lights_on, true)
				audio.beep(700.0, 0.15)
			if state_t >= 5.0 + go_delay:
				track.set_start_lights(0)
				hud.set_lights(0, false)
				_go()
		"cooldown":
			if state_t > 3.5:
				_finish(false)


func _go() -> void:
	state = "running"
	state_t = 0.0
	start_time = t
	for c in cars:
		c.held = false
	hud.message("VAI!", 1.2)
	radio.say("start")
	audio.beep(1200.0, 0.3)


func _player_input(dt: float) -> void:
	var p = player
	if autopilot:
		p.held = state != "running" and state != "cooldown"
		return
	if not p.held and _pit_auto(p):
		# no pit lane o kart anda sozinho (limitador, parada no box e saída), como nas transmissões
		_pit_drive(p, dt)
		return
	var thr := Input.get_action_strength("accelerate")
	var brk := Input.get_action_strength("brake")
	var st := Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
	if test_driver:
		var look := 3.5 + absf(p.vx) * 0.3
		var tg: Vector3 = track.point_at(p.s + look, track.line_offset_at(p.s + look))
		var to: Vector3 = tg - p.pos
		var al := atan2(to.dot(p.left()), to.dot(p.fwd()))
		st = clampf(p.steer_for_curvature(2.0 * sin(al) / maxf(to.length(), 1.0)), -0.98, 0.98)
		thr = 1.0
		brk = 0.0
	var sens: float = Game.settings["steer_sens"]
	var spd: float = absf(p.vx)
	var analog := absf(st) > 0.01 and absf(st) < 0.99
	if analog:
		# curva de resposta do analógico: precisão nos pequenos ajustes, curso todo no fim
		var shaped := signf(st) * pow(absf(st), 1.4)
		player_steer = move_toward(player_steer, shaped, dt * 9.0)
	else:
		# teclado: vira depressa em baixa velocidade e com calma em alta; contra-esterço e centro são rápidos
		var rate_in := lerpf(5.5, 3.0, clampf(spd / 30.0, 0.0, 1.0)) * sens
		var back := st == 0.0 or (player_steer != 0.0 and signf(st) != signf(player_steer))
		player_steer = move_toward(player_steer, st, dt * (7.0 * sens if back else rate_in))
	player_thr = move_toward(player_thr, thr, dt * (5.0 if thr > player_thr else 8.0))
	player_brk = move_toward(player_brk, brk, dt * 8.0)
	var t_in := player_thr
	var b_in := player_brk
	# assistência de frenagem "Leve" é o máximo de ajuda do jogo: só freia quando o kart não faria
	# a curva que vem pela frente; curvas suaves (de pé embaixo) ficam por conta do jogador. Ajuda pela
	# metade: entra mais tarde e com metade da força, o resto da frenagem é do jogador
	if int(Game.settings["brake_assist"]) == 1 and p.gear > 0:
		var need := _assist_speed(p, spd)
		if p.vx > need + 1.0:
			b_in = maxf(b_in, clampf(0.12 + (p.vx - need) * 0.15, 0.0, 0.45))
			t_in = 0.0
	p.throttle = t_in
	p.brake_in = b_in
	p.steer_in = player_steer
	if state == "cooldown" and p.finished:
		p.throttle = minf(p.throttle, 0.4)


## A assistência de frenagem só olha curvas fechadas (grampos e curvas lentas, raio até este valor em m):
## nas médias e rápidas a frenagem e a redução ficam com o jogador, mesmo onde a linha ideal fica vermelha.
const ASSIST_TIGHT_RADIUS := 22.0


func _assist_speed(p, spd: float) -> float:
	## Velocidade máxima com que dá para estar aqui e ainda fazer as curvas fechadas à frente: cada uma
	## pela aderência real do kart (pneus, chuva, danos). Curvas abertas não pedem freio.
	var lat: float = p.lat_limit() * 0.97
	var decel: float = lat * 0.95                 # freia perto do máximo dos pneus (pouca folga)
	var reach: float = spd * spd / (2.0 * decel) + 8.0
	var need := 1.0e9
	var x := 2.0
	while x <= reach:
		var k: float = absf(track.line_curv[track.idx_at(p.s + x)])
		if k > 1.0 / ASSIST_TIGHT_RADIUS:
			var v_corner := sqrt(lat / k)
			need = minf(need, sqrt(v_corner * v_corner + 2.0 * decel * maxf(0.0, x - 2.0)))
		x += 2.0
	return need


func _unhandled_input(e: InputEvent) -> void:
	if state == "replay":
		if e.is_action_pressed("ui_accept") or e.is_action_pressed("pause") or e.is_action_pressed("ui_cancel"):
			_end_replay()
			get_viewport().set_input_as_handled()
		return
	if state == "done":
		return
	if e.is_action_pressed("pause"):
		_set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if paused:
		if e.is_action_pressed("ui_cancel"):
			if hud.in_settings:
				Game.save_settings()
				_set_paused(true)
			else:
				_set_paused(false)
			get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("gear_up"):
		player.shift_up()
	elif e.is_action_pressed("gear_down"):
		if not player.shift_down() and player.gear > 1:
			hud.message("Redução recusada: rotação excessiva", 1.2)
	elif e.is_action_pressed("camera"):
		cam_mode = (cam_mode + 1) % 4
		hud.message("Câmera: " + Game.CAMERA_NAMES[cam_mode], 1.0)
	elif e.is_action_pressed("reset_car"):
		_reset_player()
	elif e.is_action_pressed("pit"):
		toggle_pit_request()
	elif e.is_action("look_back"):
		look_back = e.is_pressed()


func toggle_pause() -> void:
	if state != "done":
		_set_paused(not paused)


func _set_paused(on: bool) -> void:
	paused = on
	if radio: radio.suspended = on
	if touch:
		touch.release_all()
		touch.visible = not on
	audio.muted = on
	for c in cars: c.set_process(not on)
	var opts: Array = [["resume", "Continuar"], ["settings", "Configurações do kart"]]
	if track.has_pit:
		opts.append(["strategy", "Estratégia de box"])
	opts.append_array([["restart", "Reiniciar sessão"], ["camera", "Trocar câmera"]])
	if cfg["mode"] == "race":
		opts.append(["quit", "Abandonar corrida"])
	else:
		opts.append(["quit", "Encerrar sessão"])
	hud.show_pause(on, opts)


func _on_pause_action(action: String) -> void:
	Game.sfx("ok")
	match action:
		"resume":
			_set_paused(false)
		"restart":
			_set_paused(false)
			restart_requested.emit()
		"camera":
			cam_mode = (cam_mode + 1) % 4
			hud.message("Câmera: " + Game.CAMERA_NAMES[cam_mode], 1.0)
			_set_paused(false)
		"quit":
			_set_paused(false)
			_finish(cfg["mode"] == "race")
		"settings":
			hud.show_settings(_settings_entries())
		"strategy":
			hud.show_settings(_strategy_entries(), "ESTRATÉGIA DE BOX")
		"settings_back":
			Game.save_settings()
			_set_paused(true)


func _settings_entries() -> Array:
	## Opções que podem mudar no meio da corrida; valem na hora e ficam salvas.
	var s := Game.settings
	var on_off := ["Desligado", "Ligado"]
	var sens := [0.6, 0.8, 1.0, 1.2, 1.5]
	var custom := func():
		s["drive_mode"] = 0
		_apply_assists()
	var flag := func(key: String, label: String) -> Dictionary:
		return {"label": label, "options": on_off, "get": func(): return int(bool(s.get(key, false))),
			"set": func(i):
				s[key] = i == 1
				custom.call()}
	return [
		{"label": "Modo de pilotagem", "options": Game.DRIVE_MODES, "get": func(): return int(s["drive_mode"]),
			"set": func(i):
				Game.apply_drive_mode(i)
				_apply_assists()},
		{"label": "Assist. de frenagem", "options": Game.BRAKE_ASSIST_NAMES, "get": func(): return int(s["brake_assist"]),
			"set": func(i):
				s["brake_assist"] = i
				custom.call()},
		flag.call("tc", "Controle de tração"),
		flag.call("abs", "ABS"),
		flag.call("stability", "Estabilidade"),
		{"label": "Câmbio", "options": ["Manual", "Automático"], "get": func(): return int(bool(s["auto_gear"])),
			"set": func(i):
				s["auto_gear"] = i == 1
				custom.call()},
		{"label": "Linha ideal", "options": on_off, "get": func(): return int(bool(s["racing_line"])),
			"set": func(i):
				s["racing_line"] = i == 1
				custom.call()},
		{"label": "Sensib. da direção", "options": ["60%", "80%", "100%", "120%", "150%"],
			"get": func(): return maxi(0, sens.find(float(s["steer_sens"]))),
			"set": func(i): s["steer_sens"] = sens[i]},
		{"label": "Câmera", "options": Game.CAMERA_NAMES, "get": func(): return cam_mode,
			"set": func(i): cam_mode = i},
		{"label": "Sensação de veloc.", "options": Game.SPEED_FX_NAMES, "get": func(): return int(s.get("speed_fx", 2)),
			"set": func(i): s["speed_fx"] = i},
	]


func _strategy_entries() -> Array:
	## Plano da próxima parada (vale para quando o jogador entra no pit lane, chamado ou não).
	var out: Array = [
		{"label": "Box nesta volta", "options": ["Não", "Sim"], "get": func(): return int(player.pit_request),
			"set": func(i): player.pit_request = i == 1},
		{"label": "Pneus", "options": TYRE_PLAN, "get": func(): return int(pit_plan["tyre"]),
			"set": func(i): pit_plan["tyre"] = i},
	]
	if player.fuel_use > 0.0:
		out.append({"label": "Combustível", "options": FUEL_PLAN, "get": func(): return int(pit_plan["fuel"]),
			"set": func(i): pit_plan["fuel"] = i})
	if bool(Game.settings["damage"]):
		out.append({"label": "Reparar danos", "options": ["Não", "Sim"], "get": func(): return int(bool(pit_plan["repair"])),
			"set": func(i): pit_plan["repair"] = i == 1})
	return out


func toggle_pit_request() -> void:
	if not track.has_pit or player.pit_state > 0 or state == "done":
		return
	player.pit_request = not player.pit_request
	hud.message("Box chamado: entre no pit lane" if player.pit_request else "Box cancelado", 1.8)
	Game.sfx("ok")


func _apply_assists() -> void:
	## Passa as assistências escolhidas para o kart do jogador já na pista.
	var s := Game.settings
	player.tc = bool(s["tc"])
	player.abs_on = bool(s["abs"])
	player.stability = bool(s["stability"])
	player.auto_gear = bool(s["auto_gear"])
	track.set_line_visible(bool(s["racing_line"]))


func _reset_player() -> void:
	## Reposiciona no centro da pista na mesma distância percorrida (assistência de recuperação).
	if state != "running":
		return
	var p = player
	var keep_lap: int = p.lap
	var lane: float = clampf(p.d, -track.hw + 1.0, track.hw - 1.0)
	p.place(track, p.s, lane)
	p.pit_state = 0
	p.lap = keep_lap
	p.held = false
	if cfg["mode"] == "race":
		p.penalty += 3.0
		hud.message("Kart reposicionado (+3 s)", 2.0)
	else:
		p.lap_invalid = true
		hud.message("Kart reposicionado: volta inválida", 2.0)


# ---------------------------------------------------------------- IA

func _ai_drive(c, dt: float) -> void:
	if c.retired:
		c.throttle = 0.0
		c.brake_in = 1.0
		return
	if _pit_auto(c):
		_pit_drive(c, dt)
		return
	var spd: float = absf(c.vx)
	var lim: float = track.hw - 0.95
	var decision := Racecraft.decide(c, cars, track, dt, state == "running")
	var vt: float = decision["speed"]
	c.lane_target = decision["lane"]
	var lane_rate := 1.45 if absf(c.lane_target) > absf(c.lane) else 0.95
	c.lane = move_toward(c.lane, c.lane_target, dt * lane_rate)

	# direção: perseguição de ponto à frente
	var look := 3.5 + spd * 0.3
	var s_t: float = c.s + look
	var off_t := clampf(track.line_offset_at(s_t) + c.lane, -lim, lim)
	var target: Vector3 = track.point_at(s_t, off_t)
	var to: Vector3 = target - c.pos
	var lx: float = to.dot(c.fwd())
	var ly: float = to.dot(c.left())
	var alpha := atan2(ly, lx)
	var dist := maxf(to.length(), 1.0)
	c.steer_in = c.steer_for_curvature(2.0 * sin(alpha) / dist)

	var err: float = vt - c.vx
	if err > 0.0:
		c.throttle = clampf(err * 0.6 + 0.25, 0.0, 1.0)
		c.brake_in = 0.0
	else:
		c.throttle = 0.0
		c.brake_in = clampf(-err * 0.3, 0.0, 1.0) if err < -0.6 else 0.0

	# preso: dar ré por um instante
	if state == "running" and not c.finished and spd < 1.0 and c.reverse_t <= 0.0:
		c.stuck_t += dt
	else:
		c.stuck_t = 0.0
	if c.stuck_t > 1.2:
		c.reverse_t = 3.0
		c.stuck_t = 0.0
	if c.reverse_t > 0.0:
		# ré girando o bico em direção à pista; termina quando o carro aponta para a trajetória
		c.reverse_t -= dt
		c.want_reverse = true
		c.throttle = 0.0
		c.brake_in = 0.8
		c.steer_in = -signf(alpha)
		if absf(alpha) < 0.45 and c.reverse_t < 2.4:
			c.reverse_t = 0.0
	else:
		c.want_reverse = false


# ---------------------------------------------------------------- box

func _remaining_laps(c) -> float:
	## Voltas que faltam até a bandeirada (99 fora de corrida).
	if cfg["mode"] != "race":
		return 99.0
	return maxf(0.0, (float(cfg["laps"]) + 1.0) * track.length - c.progress()) / track.length


func _pit_auto(c) -> bool:
	## true quando o box assume o kart: já no pit lane, ou chamado e chegando na entrada.
	if not track.has_pit or c.retired:
		return false
	if c.pit_state > 0:
		return true
	if not c.pit_request or state != "running":
		return false
	var u: float = track.pit_u(c.s)
	return u < track.PIT_RAMP or track.length - u < 18.0


func _pit_logic(c, dt: float) -> void:
	# sem combustível só abandona parado na pista: quem chegou ao pit lane (mesmo no embalo) é atendido
	if c.out_of_fuel and c.pit_state == 0 and track.has_pit and track.on_pit_lane(c.s, c.d):
		c.pit_request = true
		c.pit_state = 1
	if c.out_of_fuel and c.pit_state == 0 and not c.retired and absf(c.vx) < 0.5:
		c.retired = true
		c.retire_reason = "combustível"
	if not track.has_pit or c.retired or c.finished:
		return
	var u: float = track.pit_u(c.s)
	match c.pit_state:
		0:
			if state != "running":
				return
			if c.pit_request and u < track.PIT_RAMP:
				c.pit_state = 1
			elif track.pit_divider(u) and c.d * track.pit_side > track.hw + track.PIT_WALL_OUT:
				c.pit_state = 1          # entrou no pit lane por conta própria
			elif (not c.is_player or autopilot) and not c.pit_request:
				_ai_pit_decision(c, u)
			if c.pit_state == 1 and c.is_player and not autopilot:
				hud.message("Pit lane: limite de 50 km/h", 2.0)
		1:
			if u >= track.PIT_LEN:
				c.pit_state = 0          # saiu sem parar (reposicionado)
		2:
			c.pit_timer += dt
			if c.pit_timer >= c.pit_total:
				_finish_service(c)
		3:
			if u >= track.PIT_LEN - 3.0:
				c.pit_state = 0
				c.pit_request = false


func _ai_pit_decision(c, u: float) -> void:
	## A IA chama o box na volta em que não chegaria à próxima entrada do pit lane com o combustível
	## (ou com os pneus) e ainda falta corrida; cada piloto antecipa um pouco diferente.
	var to_entry: float = track.length - u
	if to_entry > 90.0 or to_entry < 25.0:
		return
	var remaining := _remaining_laps(c)
	if remaining < 0.6:
		return
	var short_fuel: bool = c.fuel_use > 0.0 and c.fuel < remaining + 0.05 and c.fuel < 1.15 + c.pit_aggr
	# pneus: só para se eles não chegam à bandeirada (desgaste previsto pelo ritmo de gasto do composto)
	var per_lap: float = float(c.COMPOUNDS[c.compound]["wear"]) / c.tyre_life * (2.5 if c.compound == 2 and not track.wet else 1.0)
	var worn: bool = c.tyre_wear.max() > 0.75 and c.tyre_wear.max() + remaining * per_lap > 1.02
	var wrong_tyre: bool = weather_flow.active and ((weather_flow.wetness > .55 and c.compound != 2) or (weather_flow.wetness < .20 and c.compound == 2))
	if short_fuel or worn or wrong_tyre:
		c.pit_request = true


func _pit_drive(c, dt: float) -> void:
	## Pilota no pit lane: desce até o limite de velocidade, para na sua vaga do box da equipe (espera
	## só se a vaga estiver ocupada) e volta para a pista pela rampa de saída.
	var L: float = track.length
	var u: float = track.pit_u(c.s)
	if u >= track.PIT_LEN:
		u -= L                       # ainda chegando na entrada
	var spd: float = absf(c.vx)
	var box_u: float = track.pit_box_u(c.pit_box, c.pit_bay)
	var vt: float = track.speed_at(c.s + spd * 0.25) * c.pace
	var busy := _box_busy(c)
	if c.out_of_fuel and c.pit_state != 2:
		vt = minf(vt, 5.0)          # empurrado pelos mecânicos
	if c.pit_state <= 1:
		vt = minf(vt, sqrt(track.PIT_SPEED * track.PIT_SPEED + 2.0 * 7.0 * maxf(0.0, track.PIT_RAMP - u)))
		var stop_u: float = box_u - (5.0 if busy else 0.0)
		vt = minf(vt, sqrt(2.0 * 3.5 * maxf(0.0, stop_u - u)))
		if c.pit_state == 1 and not busy and u > box_u - 0.8 and spd < 0.7:
			_start_service(c)
	elif c.pit_state == 2:
		vt = 0.0
	elif u < track.PIT_LEN - track.PIT_RAMP:
		vt = track.PIT_SPEED
	var look := 3.0 + spd * 0.3
	var ut := u + look
	var off: float = track.pit_path(ut, _box_lane(c, ut, box_u))
	var target: Vector3 = track.point_at(c.s + look, off)
	var to: Vector3 = target - c.pos
	var alpha := atan2(to.dot(c.left()), to.dot(c.fwd()))
	c.steer_in = c.steer_for_curvature(2.0 * sin(alpha) / maxf(to.length(), 1.0))
	c.want_reverse = false
	var err: float = vt - c.vx
	if vt < 0.3:
		c.throttle = 0.0
		c.brake_in = 1.0
	elif err > 0.0:
		c.throttle = clampf(err * 0.6 + 0.2, 0.0, 1.0)
		c.brake_in = 0.0
	else:
		c.throttle = 0.0
		c.brake_in = clampf(-err * 0.35, 0.0, 1.0) if err < -0.3 else 0.0


func _box_lane(c, u: float, box_u: float) -> float:
	## 0 = faixa de passagem, 1 = faixa dos boxes (entra até 14 m antes da vaga e sai em até 12 m depois).
	## Se há um kart parado no caminho, entra depois dele ou sai antes dele, sem passar por cima.
	var cu: float = track.pit_u(c.s)
	var ramp_in := 14.0
	var ramp_out := 12.0
	for o in cars:
		if o == c or o.pit_state != 2:
			continue
		var ou: float = track.pit_u(o.s)
		if ou > cu - 1.0 and ou < box_u - 1.0:
			ramp_in = minf(ramp_in, maxf(2.0, box_u - ou - 2.4))
		elif ou > box_u + 1.0 and ou < box_u + 14.0:
			ramp_out = minf(ramp_out, maxf(1.5, ou - box_u - 2.6))
	if c.pit_state <= 1:
		return clampf(1.0 - (box_u - u - 2.0) / ramp_in, 0.0, 1.0)
	return clampf(1.0 - (u - box_u - 1.0) / ramp_out, 0.0, 1.0)


func _box_busy(c) -> bool:
	for o in cars:
		if o != c and o.pit_box == c.pit_box and o.pit_bay == c.pit_bay and o.pit_state == 2:
			return true
	return false


func _service_plan(c) -> Dictionary:
	## O que a equipe faz na parada: combustível para terminar a corrida (até onde cabe no tanque),
	## pneus pelo clima e pelo que falta de corrida, e conserto se houver dano.
	var remaining := _remaining_laps(c)
	var fuel_add := 0.0
	if c.fuel_use > 0.0:
		var want: float = remaining + 0.3 - c.fuel
		if c.is_player and not autopilot and int(pit_plan["fuel"]) > 0:
			want = FUEL_PLAN_LAPS[int(pit_plan["fuel"])]
		fuel_add = clampf(want, 0.0, c.fuel_cap - c.fuel)
		if c.fuel < 0.3:
			fuel_add = maxf(fuel_add, minf(0.5, c.fuel_cap - c.fuel))   # tanque vazio: nunca sai sem nada
	var tyre := -1
	var choice: int = int(pit_plan["tyre"]) if c.is_player and not autopilot else 0
	match choice:
		0:
			if track.wet:
				tyre = 2
			else:
				# macio se o que falta cabe na vida dele, senão duro
				tyre = 0 if remaining * 1.5 < c.tyre_life * 0.95 else 1
		1, 2, 3:
			tyre = choice - 1
		4:
			tyre = -1
	var repair: bool = c.damage > 0.02 and (bool(pit_plan["repair"]) if c.is_player else true)
	return {"fuel": fuel_add, "tyre": tyre, "repair": repair}


func _start_service(c) -> void:
	c.pit_state = 2
	if c.is_player: radio.say("pit")
	c.pit_timer = 0.0
	c.pit_service = _service_plan(c)
	var t_fuel: float = float(c.pit_service["fuel"]) * PIT_FUEL_TIME
	var t_tyre: float = PIT_TYRE_TIME if int(c.pit_service["tyre"]) >= 0 else 0.0
	var t_rep: float = c.damage * PIT_REPAIR_TIME if c.pit_service["repair"] else 0.0
	c.pit_total = PIT_BASE_TIME + maxf(t_fuel, t_tyre) + t_rep * (1.0 + randf_range(-0.05, 0.05))
	c.pit_total *= randf_range(0.97, 1.06)    # cada parada sai um pouco diferente


func _finish_service(c) -> void:
	var sv: Dictionary = c.pit_service
	c.fuel = minf(c.fuel_cap, c.fuel + float(sv["fuel"]))
	if c.fuel > 0.0:
		c.out_of_fuel = false
	if int(sv["tyre"]) >= 0:
		c.compound = int(sv["tyre"])
		c.tyre_wear = [0.0, 0.0, 0.0, 0.0]
		c.wear = 0.0
		c.tyre_temp = 0.35          # pneus novos saem frios
	if sv["repair"]:
		c.damage = 0.0
	c.stops += 1
	c.pit_request = false
	c.pit_state = 3
	if c.is_player: radio.say("out")
	if c.is_player and not autopilot:
		hud.message("Parada: %.1f s" % c.pit_total, 2.5)
		if state == "running":
			pit_plan["fuel"] = 0


func _animate_crew(delta: float) -> void:
	## Mecânicos esperam na garagem e vão até as rodas do kart da sua vaga durante a parada.
	if not track.has_pit or track.pit_crew.is_empty():
		return
	for b in track.pit_crew.size():
		var served = null
		for c in cars:
			if c.pit_state == 2 and c.pit_box * track.PIT_BAYS + c.pit_bay == b:
				served = c
		var crew: Array = track.pit_crew[b]
		for k in crew.size():
			var fig: Node3D = crew[k]
			var goal: Vector3 = track.pit_crew_home[b][k]
			if served != null:
				var fwd_off := 0.7 if k < 2 else -0.6
				var side := 1.05 if k % 2 == 0 else -1.05
				goal = served.pos + served.fwd() * fwd_off + served.left() * side
				var face: Vector3 = served.pos - fig.position
				if face.length() > 0.3:
					fig.rotation.y = atan2(face.x, face.z)
			fig.position = fig.position.move_toward(goal, delta * 7.0)


# ---------------------------------------------------------------- colisões

func _collide_cars() -> void:
	for i in cars.size():
		var a = cars[i]
		for j in range(i + 1, cars.size()):
			var b = cars[j]
			var dp: Vector3 = b.pos - a.pos
			if dp.x * dp.x + dp.z * dp.z > 9.0:
				continue
			var reach := 2.0 * CarScript.HIT_RADIUS
			for ca in CarScript.HIT_OFFSETS:
				for cb in CarScript.HIT_OFFSETS:
					var pa: Vector3 = a.pos + a.fwd() * ca
					var pb: Vector3 = b.pos + b.fwd() * cb
					var dd := Vector3(pb.x - pa.x, 0.0, pb.z - pa.z)
					var dist := dd.length()
					if dist >= reach or dist < 0.001:
						continue
					var nrm := dd / dist
					var pen := reach - dist
					a.pos -= nrm * pen * 0.5
					b.pos += nrm * pen * 0.5
					var va: Vector3 = a.world_vel()
					var vb: Vector3 = b.world_vel()
					var rel := (vb - va).dot(nrm)
					if rel < 0.0:
						var jimp := -1.3 * rel * 0.5
						va -= nrm * jimp
						vb += nrm * jimp
						a.set_world_vel(va)
						b.set_world_vel(vb)
						var la: Vector3 = pa - a.pos
						var lb: Vector3 = pb - b.pos
						var ja := -nrm * jimp * CarScript.MASS
						var jb := nrm * jimp * CarScript.MASS
						a.r += (la.z * ja.x - la.x * ja.z) / CarScript.INERTIA * 0.5
						b.r += (lb.z * jb.x - lb.x * jb.z) / CarScript.INERTIA * 0.5
						a.hit(-rel * 0.7)
						b.hit(-rel * 0.7)
						if a.is_player or b.is_player:
							audio.impact(clampf(-rel / 6.0, 0.2, 1.0))


# ---------------------------------------------------------------- cronometragem

func _timing(c) -> void:
	var L: float = track.length
	var cur: float = c.s
	var prev: float = c.last_s
	c.last_s = cur
	if state != "running" and state != "cooldown":
		return
	if prev > L - 100.0 and cur < 100.0:
		_cross_line(c)
	elif prev < 100.0 and cur > L - 100.0:
		c.lap -= 1
	elif c.lap >= 1 and c.lap == c.max_lap:
		if c.sector == 0 and prev < L / 3.0 and cur >= L / 3.0:
			_split(c, 0)
		elif c.sector == 1 and prev < 2.0 * L / 3.0 and cur >= 2.0 * L / 3.0:
			_split(c, 1)
	# limites de pista
	var lim: float = track.hw + track.kerb_w + 0.9
	if absf(c.d) > lim and c.pit_state == 0 and not track.on_pit_lane(c.s, c.d):
		if c.off_since < 0.0:
			c.off_since = t
		if cfg["mode"] != "race":
			c.lap_invalid = true
	elif c.off_since >= 0.0:
		var dur: float = t - c.off_since
		c.off_since = -1.0
		if cfg["mode"] == "race" and c.is_player and dur < 2.5 and absf(c.vx) > 15.0:
			c.warnings += 1
			if c.warnings >= 3:
				c.warnings = 0
				c.penalty += 5.0
				hud.message("Penalidade: +5 s por cortar a pista", 3.0)
			else:
				hud.message("Aviso de limites de pista (%d/3)" % c.warnings, 2.0)


func _split(c, k: int) -> void:
	c.splits[k] = t - c.sector_start
	c.sector_start = t
	c.sector = k + 1


func _cross_line(c) -> void:
	c.lap += 1
	if c.lap <= c.max_lap or c.finished:
		c.max_lap = maxi(c.max_lap, c.lap)
		return
	c.max_lap = c.lap
	var mode: String = cfg["mode"]
	if c.lap >= 2:
		var lt: float = t - c.lap_start
		c.splits[2] = t - c.sector_start
		var valid: bool = mode == "race" or not c.lap_invalid
		c.last_lap = lt
		if valid:
			c.lap_times.append(lt)
			if lt < c.best_lap:
				c.best_lap = lt
		if c.is_player:
			if ghost and ghost.complete(lt, valid and not c.lap_invalid): radio.say("ghost")
			timed_done += 1
			if not valid:
				hud.message("Volta inválida  %s" % Game.fmt_time(lt), 2.5)
			elif lt <= c.best_lap:
				hud.message("Melhor volta  %s" % Game.fmt_time(lt), 2.5)
			else:
				hud.message("Volta  %s" % Game.fmt_time(lt), 2.5)
	if c.is_player and ghost: ghost.begin_lap()
	c.lap_start = t
	c.sector = 0
	c.sector_start = t
	c.lap_invalid = false
	if mode == "race":
		var laps: int = cfg["laps"]
		if race_over or c.lap > laps:
			c.finished = true
			finish_count += 1
			c.finish_order = finish_count
			c.finish_time = t - start_time + c.penalty
			race_over = true
			if c.is_player:
				state = "cooldown"
				state_t = 0.0
				radio.say("win" if c.finish_order == 1 else "finish", "", true)
				hud.message("Bandeira quadriculada!  P%d" % (order.find(c) + 1), 3.5)
		elif c.is_player and c.lap == laps:
			radio.say("last_lap")
			hud.message("Última volta", 2.0)
	elif c.is_player:
		var tl: int = cfg.get("timed_laps", 0)
		if tl > 0 and timed_done >= tl:
			state = "cooldown"
			state_t = 0.0
			hud.message("Sessão encerrada", 3.0)


func _update_order() -> void:
	order = cars.duplicate()
	order.sort_custom(func(a, b):
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_order < b.finish_order
		if a.retired != b.retired:
			return b.retired
		return a.progress() > b.progress())


func _finish(abandoned: bool) -> void:
	if state in ["done", "replay"]:
		return
	state = "done"
	var L: float = track.length
	var res := {"mode": cfg["mode"], "track": cfg["track"], "weather": cfg["weather"], "abandoned": abandoned,
		"best": player.best_lap, "laps": player.lap_times.duplicate(), "cfg": cfg}
	if cfg["mode"] == "race":
		var rows: Array = []
		var elapsed: float = maxf(t - start_time, 1.0)
		var target: float = (int(cfg["laps"]) + 1) * L
		for c in order:
			var row := {"code": c.driver["code"], "name": c.driver["name"], "team": int(c.driver["team"]),
				"player": c.is_player, "best": c.best_lap, "penalty": c.penalty, "laps": maxi(c.max_lap - 1, 0),
				"stops": c.stops}
			if c.finished:
				row["status"] = "ok" if c.max_lap - 1 >= int(cfg["laps"]) else "lapped"
				row["time"] = c.finish_time
			elif c.retired or (c.is_player and abandoned):
				row["status"] = "dnf"
				row["time"] = INF
			else:
				var remaining: float = target - c.progress()
				var avg: float = maxf(c.progress() - (L - track.GRID_START), 1.0) / elapsed
				row["time"] = elapsed + remaining / maxf(avg, 10.0) + c.penalty
				row["status"] = "lapped" if remaining > L else "ok"
				row["laps"] = int(cfg["laps"]) - int(ceilf(remaining / L)) + 1 if remaining > L else int(cfg["laps"])
			rows.append(row)
		var ok_rows := rows.filter(func(x): return x["status"] != "dnf")
		var dnf_rows := rows.filter(func(x): return x["status"] == "dnf")
		ok_rows.sort_custom(func(a, b):
			if a["laps"] != b["laps"]:
				return a["laps"] > b["laps"]
			return a["time"] < b["time"])
		res["classification"] = ok_rows + dnf_rows
	if cfg["mode"] == "race" and not abandoned and bool(Game.settings.get("finish_replay", true)) and replay.begin():
		_start_replay(res)
	else:
		finished.emit(res)


# ---------------------------------------------------------------- câmera, HUD e som

func _process(delta: float) -> void:
	if paused: return
	if state == "replay":
		_play_replay(delta)
		return
	if ghost:
		ghost_label.text = ghost.display(t-player.lap_start, bool(Game.settings.get("ghost",true)) and player.lap>=1 and state=="running")
	if player == null:
		return
	_update_camera(delta, false)
	_animate_crew(delta)
	if rain:
		rain.global_position = camera.global_position + Vector3(0, 9, 0) + player.fwd() * 8.0
	_lightning(delta)
	audio.radio_duck = radio.voice.playing if radio else false
	audio.rpm = player.rpm
	audio.thr = player.throttle if not player.held else player.throttle * 0.6
	audio.slip = maxf(absf(player.slip_r), absf(player.slip_f)) * (1.0 if absf(player.vx) > 5.0 else 0.0) + (0.15 if player.locking or player.spinning else 0.0)
	audio.speed = absf(player.vx)
	audio.kerb = player.surface == 1 and absf(player.vx) > 3.0
	if player.shift_event != last_shift:
		last_shift = player.shift_event
		audio.shift()
	if player.impact > 0.3:
		audio.impact(player.impact)
	var near = null
	var nd := 1.0e9
	for c in cars:
		if c == player:
			continue
		var dd: float = c.pos.distance_squared_to(player.pos)
		if dd < nd:
			nd = dd
			near = c
	if near != null:
		audio.ai_rpm = near.rpm
		audio.ai_gain = clampf(1.0 - sqrt(nd) / 40.0, 0.0, 1.0)


func _update_camera(delta: float, snap: bool) -> void:
	var p = player
	var bt: Transform3D = p.body.global_transform if p.body else p.global_transform
	if p.helmet:
		p.helmet.visible = cam_mode != 0
	var fx: float = Game.SPEED_FX[clampi(int(Game.settings.get("speed_fx", 2)), 0, Game.SPEED_FX.size()-1)]
	var spd: float = absf(p.vx)
	camera_motion.update(delta, p.vx, p.r, p.surface, p.impact, fx, snap)
	cam_acc = camera_motion.acceleration
	cam_lat = camera_motion.lateral
	var jitter: Vector3 = camera_motion.jitter
	var speed_fov: float = camera_motion.fov if not look_back else 0.0
	var lean: float = camera_motion.roll
	var pitch: float = camera_motion.pitch

	match cam_mode:
		0:
			# olhos do piloto (capacete oculto nesta câmera): vê os braços, o volante e o bico do kart
			var head := Basis(Vector3.RIGHT, deg_to_rad(-9.0) - pitch) * Basis(Vector3.FORWARD, lean)
			var local := Transform3D(head, p.eye + camera_motion.offset + jitter)
			if look_back:
				local = Transform3D(Basis(Vector3.UP, PI), p.eye + Vector3(0, 0.04, 0.0))
			camera.global_transform = bt * local
			camera.fov = 62.0 + speed_fov
		1, 2:
			# a câmera fica para trás quando o kart acelera e chega perto na frenagem; baixa em alta
			var back: float = (3.8 if cam_mode == 1 else 2.5) + camera_motion.chase_distance
			var up: float = (1.55 if cam_mode == 1 else 0.6) + camera_motion.chase_height * (1.0 if cam_mode == 1 else 0.5)
			# segue a posição do carro rigidamente; só a direção é suavizada
			if snap:
				cam_h = p.h
			else:
				cam_h = lerp_angle(cam_h, p.h, 1.0 - exp(-delta * (6.0 if cam_mode == 1 else 10.0)))
			var f := Vector3(-sin(cam_h), 0.0, -cos(cam_h))
			if look_back:
				f = -f
			cam_pos = p.pos - f * back + Vector3(0, up, 0)
			camera.global_position = cam_pos + jitter
			camera.look_at(p.pos + f * 5.0 + Vector3(0, 0.45 if cam_mode == 1 else 0.4, 0), Vector3.UP)
			camera.rotate_object_local(Vector3.FORWARD, lean * 0.45 if not look_back else 0.0)
			camera.fov = 65.0 + speed_fov
		3:
			var best = null
			var bd := 1.0e12
			for tp in track.tv_points:
				var dd: float = tp.distance_squared_to(p.pos)
				if dd < bd:
					bd = dd
					best = tp
			if best == null:
				return
			camera.global_position = best
			camera.look_at(p.pos + Vector3(0, 0.4, 0), Vector3.UP)
			camera.fov = clampf(1100.0 / maxf(sqrt(bd), 6.0), 10.0, 60.0)
	_update_speed_fx(delta, fx, spd)


func _update_speed_fx(delta: float, fx: float, spd: float) -> void:
	## Riscos de vento e cantos escurecidos a partir de ~70 km/h (não na câmera de TV nem olhando para trás).
	var k := fx * smoothstep(18.0, 38.0, spd)
	if cam_mode == 3 or look_back or get_tree().paused:
		k = 0.0
	speed_fx.visible = k > 0.01
	if not speed_fx.visible:
		return
	speed_flow += delta * spd / 14.0
	var sm := speed_fx.material as ShaderMaterial
	sm.set_shader_parameter("intensity", k)
	sm.set_shader_parameter("flow", speed_flow)
	var vs := get_viewport().get_visible_rect().size
	sm.set_shader_parameter("aspect", vs.x / maxf(vs.y, 1.0))
	# o ponto de fuga acompanha a curva (a pista "escorre" para fora dela)
	sm.set_shader_parameter("center", Vector2(0.5 + clampf(cam_lat, -20.0, 20.0) * 0.004, 0.42))


func _radio_update(dt: float) -> void:
	if state != "running": return
	radio_clock += dt
	if radio_clock<2.0: return
	radio_clock = 0.0
	var place := order.find(player)+1
	if radio_position>0 and place!=radio_position and t-start_time>12.0:
		radio.say("gain" if place<radio_position else "loss", "P%d." % place)
	radio_position = place
	if player.fuel_use>0 and player.fuel<.8: radio.say("fuel")
	elif player.tyre_wear.max()>.72: radio.say("tyres")
	elif player.damage>.4: radio.say("damage")

func _start_replay(res: Dictionary) -> void:
	pending_result = res
	state = "replay"
	hud.hide()
	if touch: touch.hide()
	speed_fx.hide()
	radio.silence()
	audio.muted = true
	if ghost: ghost.hide()
	replay_layer = CanvasLayer.new()
	replay_layer.layer = 10
	add_child(replay_layer)
	var title := Label.new()
	title.text = "REPLAY DA CHEGADA  •  0,75×"
	title.position = Vector2(24,24)
	title.add_theme_font_size_override("font_size",26)
	replay_layer.add_child(title)
	var button := Button.new()
	button.text = "Pular replay  •  Enter / A"
	button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = Vector2(-330,-80)
	button.size = Vector2(300,55)
	button.pressed.connect(_end_replay)
	replay_layer.add_child(button)
	button.grab_focus()

func _play_replay(dt: float) -> void:
	var ended := replay.tick(dt,cars)
	var focus: Vector3 = player.global_position+Vector3(0,.5,0)
	camera.position = player.global_position + player.global_basis.z * 5.5 + Vector3(0,3.2,0)
	camera.look_at(focus,Vector3.UP)
	camera.fov = 48.0
	if ended: _end_replay()

func _end_replay() -> void:
	if state != "replay": return
	state = "done"
	finished.emit(pending_result)
