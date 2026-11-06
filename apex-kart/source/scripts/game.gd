extends Node
## Estado global: configurações, controles, equipes, pilotos, circuitos,
## recordes, carreira (dados e regras) e sons de interface.

const TrackScript := preload("res://scripts/track.gd")

const SETTINGS_PATH := "user://settings.json"
const CAREER_PATH := "user://career.json"
## v2: curvas fechadas suavizadas (tools/reshape.py) mudaram o traçado, então os recordes antigos não valem mais.
const RECORDS_PATH := "user://records_v2.json"
const POINTS := [10, 8, 6, 5, 4, 3, 2, 1]
const ROUNDS_PER_SEASON := 4
const MAX_SEASONS := 5
const DIFFICULTY_NAMES := ["Fácil", "Médio", "Difícil"]
## Ritmo da IA sobre o perfil de velocidade da pista (o perfil é conservador: o kart faz as curvas
## com uns 18 % mais aderência, então o Difícil passa de 1,0). Só muda a velocidade nas curvas e frenagens:
## na reta todos têm o mesmo motor (fora da carreira) e a mesma velocidade máxima.
const DIFFICULTY_PACE := [0.94, 1.03, 1.13]
const CAMERA_NAMES := ["Cockpit", "Perseguição", "Traseira baixa", "TV"]
const ROLE_NAMES := {"candidate": "Candidato", "test": "Piloto de testes", "second": "Segundo piloto", "first": "Primeiro piloto"}
const NATIONS := ["Brasil", "Portugal", "Argentina", "Espanha", "Itália", "Reino Unido", "França", "Alemanha", "Japão", "Estados Unidos", "México", "Canadá"]
const HelmetModel := preload("res://scripts/helmet_model.gd")
const Appearance := preload("res://scripts/appearance.gd")
const HELMET_NAMES := HelmetModel.DESIGNS
const HELMET_COLORS := [Color(1.0, 0.85, 0.1), Color(0.85, 0.1, 0.1), Color(0.1, 0.3, 0.9), Color(0.95, 0.95, 0.95), Color(0.1, 0.7, 0.3), Color(1.0, 0.5, 0.05)]

const ACTIONS := {
	"accelerate": "Acelerar", "brake": "Frear / ré", "steer_left": "Esterçar à esquerda",
	"steer_right": "Esterçar à direita", "gear_up": "Subir marcha", "gear_down": "Reduzir marcha",
	"camera": "Trocar câmera", "look_back": "Olhar para trás", "reset_car": "Reposicionar kart",
	"pit": "Chamar o box", "pause": "Pausar",
}
const DEFAULT_KEYS := {
	"accelerate": KEY_W, "brake": KEY_S, "steer_left": KEY_A, "steer_right": KEY_D,
	"gear_up": KEY_E, "gear_down": KEY_Q, "camera": KEY_C, "look_back": KEY_B,
	"reset_car": KEY_R, "pit": KEY_F, "pause": KEY_ESCAPE,
}
## Botões do controle; -1 = só eixo (gatilhos e analógico continuam valendo sempre).
const DEFAULT_PADS := {
	"accelerate": -1, "brake": -1, "steer_left": -1, "steer_right": -1,
	"gear_up": JOY_BUTTON_RIGHT_SHOULDER, "gear_down": JOY_BUTTON_LEFT_SHOULDER, "camera": JOY_BUTTON_Y,
	"look_back": JOY_BUTTON_X, "reset_car": JOY_BUTTON_BACK, "pit": JOY_BUTTON_DPAD_UP, "pause": JOY_BUTTON_START,
}
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Guide", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "D-pad ↑", JOY_BUTTON_DPAD_DOWN: "D-pad ↓",
	JOY_BUTTON_DPAD_LEFT: "D-pad ←", JOY_BUTTON_DPAD_RIGHT: "D-pad →",
}
const PAD_AXIS_NAMES := {"accelerate": "RT", "brake": "LT", "steer_left": "analógico ←", "steer_right": "analógico →"}
const SECONDARY_KEYS := {
	"accelerate": KEY_UP, "brake": KEY_DOWN, "steer_left": KEY_LEFT, "steer_right": KEY_RIGHT,
	"pause": KEY_P,
}

# Equipes e pilotos são fictícios. "livery" é a pintura do kart (models/kart2/<livery>/); c1 e c2 são as
# cores da pintura usadas no placar, nos boxes e nos mecânicos.
var teams: Array = [
	{"name": "Valtrex Racing", "short": "VAL", "livery": "scarlet", "c1": Color("#ff3043"), "c2": Color("#a50722"), "perf": 1.000, "rookie": false},
	{"name": "Aurora GP", "short": "AUR", "livery": "nova", "c1": Color("#655cff"), "c2": Color("#18255c"), "perf": 0.995, "rookie": false},
	{"name": "Hartmann Motorsport", "short": "HAR", "livery": "aureon", "c1": Color("#d9b76a"), "c2": Color("#101319"), "perf": 0.990, "rookie": false},
	{"name": "Celeste Kart Team", "short": "CEL", "livery": "polar", "c1": Color("#065cb8"), "c2": Color("#e9eff2"), "perf": 0.983, "rookie": false},
	{"name": "Brennan Racing", "short": "BRE", "livery": "verde", "c1": Color("#b9ee2a"), "c2": Color("#063f30"), "perf": 0.977, "rookie": false},
	{"name": "Kestrel Racing", "short": "KES", "livery": "papaya", "c1": Color("#f56712"), "c2": Color("#131c2b"), "perf": 0.968, "rookie": true, "test_track": 1, "test_weather": "dry",
		"pitch": "Equipe jovem e agressiva. Procura um piloto rápido em pista seca e ondulada."},
	{"name": "Vortice Junior", "short": "VOR", "livery": "magenta", "c1": Color("#ef1681"), "c2": Color("#392052"), "perf": 0.963, "rookie": true, "test_track": 0, "test_weather": "dry",
		"pitch": "Equipe de formação. Avalia precisão nas curvas de média velocidade."},
	{"name": "Nordhaus GP", "short": "NOR", "livery": "volt", "c1": Color("#00e6c0"), "c2": Color("#082f35"), "perf": 0.958, "rookie": true, "test_track": 2, "test_weather": "rain",
		"pitch": "Equipe metódica. Quer ver controle do kart com a pista molhada."},
]

var drivers: Array = [
	{"name": "Dario Castell", "code": "CAS", "team": 0, "skill": 0.995, "num": 1},
	{"name": "Henrik Solberg", "code": "SOL", "team": 0, "skill": 0.985, "num": 2},
	{"name": "Luca Ferrandi", "code": "FER", "team": 1, "skill": 0.990, "num": 3},
	{"name": "Tomás Ribeiro", "code": "RIB", "team": 1, "skill": 0.980, "num": 4},
	{"name": "Felix Brandt", "code": "BRA", "team": 2, "skill": 0.988, "num": 5},
	{"name": "Kenji Arata", "code": "ARA", "team": 2, "skill": 0.975, "num": 6},
	{"name": "Alexei Morozov", "code": "MOR", "team": 3, "skill": 0.978, "num": 7},
	{"name": "Pierre Duval", "code": "DUV", "team": 3, "skill": 0.970, "num": 8},
	{"name": "Sean Whitlock", "code": "WHI", "team": 4, "skill": 0.972, "num": 9},
	{"name": "Rafael Ortega", "code": "ORT", "team": 4, "skill": 0.965, "num": 10},
	{"name": "Jonas Lindqvist", "code": "LIN", "team": 5, "skill": 0.965, "num": 11},
	{"name": "Bruno Salles", "code": "SAL", "team": 5, "skill": 0.955, "num": 12},
	{"name": "Matteo Greco", "code": "GRE", "team": 6, "skill": 0.962, "num": 14},
	{"name": "Yuki Tanabe", "code": "TAN", "team": 6, "skill": 0.952, "num": 15},
	{"name": "Erik Vogel", "code": "VOG", "team": 7, "skill": 0.958, "num": 16},
	{"name": "Andrés Paredes", "code": "PAR", "team": 7, "skill": 0.950, "num": 17},
]

# Kartódromos: traçados gerados a partir das imagens da pasta do projeto (tracks/*.json, ver tools/).
const TRACK_INDEX := "res://tracks/index.json"
var tracks: Array = []

var settings: Dictionary = {
	"tc": true, "abs": true, "stability": true, "brake_assist": 1, "drive_mode": 0, "racing_line": true,
	"auto_gear": true, "steer_sens": 1.0, "damage": true, "camera": 0, "volume": 0.8,
	"difficulty": 1, "career_laps": 5, "keys": {}, "pads": {}, "input_mode": 0, "touch_layout": {}, "quality": 0,
	"pit_stops": 1, "start_tyre": 1, "speed_fx": 2, "radio": true, "weather_change": false, "ghost": true, "finish_replay": true,
}
## Sensação de velocidade (câmera, riscos de vento na tela): nome e intensidade.
const SPEED_FX_NAMES := ["Desligada", "Suave", "Forte"]
const SPEED_FX := [0.0, 0.55, 1.0]
const PIT_STOP_NAMES := ["Sem estratégia", "1 parada", "2 paradas"]
## Clima: chave usada nas configurações e recordes, nome, aderência da pista e ritmo da IA.
const WEATHERS := ["dry", "rain", "storm", "snow"]
const WEATHER_NAMES := ["Seco", "Chuva", "Tempestade", "Neve"]
const WEATHER_MU := {"dry": 1.0, "rain": 0.72, "storm": 0.62, "snow": 0.5}
const WEATHER_PACE := {"dry": 1.0, "rain": 0.97, "storm": 0.95, "snow": 0.93}
const START_TYRE_NAMES := ["Macio", "Duro"]
var records: Dictionary = {}
var career: Dictionary = {}
var _estimates: Dictionary = {}
var _sfx: Dictionary = {}
var _sfx_players: Array = []
var _sfx_next := 0


func _ready() -> void:
	_load_tracks()
	_load_settings()
	_load_records()
	apply_keys()
	_build_sfx()


func _load_tracks() -> void:
	var idx = JSON.parse_string(FileAccess.get_file_as_string(TRACK_INDEX))
	tracks.clear()
	for t in idx:
		var L := float(t["length"])
		tracks.append({"name": t["name"], "place": t["place"], "theme": t["theme"], "file": t["file"],
			"length": L, "laps": clampi(int(round(6000.0 / L)), 3, 5)})


# ---------------------------------------------------------------- controles

func key_for(action: String) -> int:
	var keys: Dictionary = settings["keys"]
	if keys.has(action):
		return int(keys[action])
	return int(DEFAULT_KEYS[action])


func set_key(action: String, physical_key: int) -> void:
	var keys: Dictionary = settings["keys"]
	keys[action] = physical_key
	apply_keys()
	save_settings()


func reset_keys() -> void:
	settings["keys"] = {}
	settings["pads"] = {}
	apply_keys()
	save_settings()


func key_name(action: String) -> String:
	return OS.get_keycode_string(key_for(action))


func apply_keys() -> void:
	for action in ACTIONS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		InputMap.action_erase_events(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = key_for(action)
		InputMap.action_add_event(action, ev)
		if SECONDARY_KEYS.has(action):
			var ev2 := InputEventKey.new()
			ev2.physical_keycode = SECONDARY_KEYS[action]
			InputMap.action_add_event(action, ev2)
	_add_axis("accelerate", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_axis("brake", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_axis("steer_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("steer_right", JOY_AXIS_LEFT_X, 1.0)
	for action in ACTIONS.keys():
		var b := pad_for(action)
		if b >= 0:
			_add_button(action, b)
	# menus: A confirma e B volta (o Godot não liga esses botões por padrão)
	for pair in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var has := false
		for ev in InputMap.action_get_events(pair[0]):
			if ev is InputEventJoypadButton and ev.button_index == pair[1]:
				has = true
		if not has:
			_add_button(pair[0], pair[1])


const INPUT_MODES := ["Automático", "Teclado", "Controle (joypad)", "Toque na tela"]
const DRIVE_MODES := ["Personalizado", "Assistido", "Simulação"]
const BRAKE_ASSIST_NAMES := ["Desligada", "Leve"]
## Pacotes de assistências do "Modo de pilotagem".
const DRIVE_PRESETS := {
	# "Assistido" é o máximo de ajuda que o jogo oferece (também é o padrão de um jogo novo)
	1: {"tc": true, "abs": true, "stability": true, "brake_assist": 1, "auto_gear": true, "racing_line": true},
	2: {"tc": false, "abs": false, "stability": false, "brake_assist": 0, "auto_gear": false, "racing_line": false},
}


func apply_drive_mode(mode: int) -> void:
	settings["drive_mode"] = mode
	if DRIVE_PRESETS.has(mode):
		settings.merge(DRIVE_PRESETS[mode], true)
const QUALITY_NAMES := ["Automático", "Alta (PC)", "Leve (celular)"]


func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


func touch_buttons() -> bool:
	## Botões na tela: escolhidos em Opções, ou automático só em celular/tablet.
	var mode := int(settings.get("input_mode", 0))
	return mode == 3 or (mode == 0 and is_mobile())


func lite_models() -> bool:
	## Modelos leves no celular e no navegador (lá os completos nem são exportados).
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return true
	return int(settings.get("quality", 0)) == 2


func pad_for(action: String) -> int:
	var pads: Dictionary = settings.get("pads", {})
	if pads.has(action):
		return int(pads[action])
	return int(DEFAULT_PADS[action])


func set_pad(action: String, button: int) -> void:
	var pads: Dictionary = settings["pads"]
	pads[action] = button
	apply_keys()
	save_settings()


func pad_name(action: String) -> String:
	var b := pad_for(action)
	var parts: Array = []
	if PAD_AXIS_NAMES.has(action):
		parts.append(PAD_AXIS_NAMES[action])
	if b >= 0:
		parts.append(PAD_NAMES.get(b, "Botão %d" % b))
	return " / ".join(parts)


func _add_axis(action: String, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)


func _add_button(action: String, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- persistência

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _write_json(path: String, data: Variant) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	return true


func _load_settings() -> void:
	var data = _read_json(SETTINGS_PATH)
	if data is Dictionary:
		for k in data.keys():
			if settings.has(k):
				settings[k] = data[k]
	settings["camera"] = int(settings["camera"])
	settings["difficulty"] = int(settings["difficulty"])
	settings["career_laps"] = int(settings["career_laps"])
	settings["input_mode"] = int(settings["input_mode"])
	# frenagem "Quase automática" e ajuda de direção saíram do jogo: "Leve" é o máximo
	settings["brake_assist"] = clampi(int(settings["brake_assist"]), 0, 1)
	settings.erase("steer_assist")
	settings["drive_mode"] = int(settings["drive_mode"])
	settings["quality"] = int(settings["quality"])
	settings["pit_stops"] = clampi(int(settings["pit_stops"]), 0, 2)
	settings["start_tyre"] = clampi(int(settings["start_tyre"]), 0, 1)
	if not (settings["pads"] is Dictionary):
		settings["pads"] = {}
	if not (settings["touch_layout"] is Dictionary):
		settings["touch_layout"] = {}
	if not (settings["keys"] is Dictionary):
		settings["keys"] = {}


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)


func _load_records() -> void:
	var data = _read_json(RECORDS_PATH)
	if data is Dictionary:
		records = data


func record_for(track_idx: int, weather: String) -> float:
	var key := "%d_%s" % [track_idx, weather]
	if records.has(key):
		return float(records[key]["time"])
	return INF


func submit_record(track_idx: int, weather: String, time: float, who: String) -> bool:
	if time >= record_for(track_idx, weather):
		return false
	records["%d_%s" % [track_idx, weather]] = {"time": time, "driver": who}
	_write_json(RECORDS_PATH, records)
	return true


func career_exists() -> bool:
	return FileAccess.file_exists(CAREER_PATH)


func save_career() -> bool:
	return _write_json(CAREER_PATH, career)


func load_career() -> bool:
	var data = _read_json(CAREER_PATH)
	if data is Dictionary and data.has("name"):
		career = data
		career["appearance"] = Appearance.normalized(career.get("appearance", {}))
		career["helmet"] = clampi(int(career.get("helmet", 0)), 0, HELMET_NAMES.size() - 1)
		career["helmet_visor"] = clampi(int(career.get("helmet_visor", 0)), 0, 3)
		career["helmet_finish"] = clampi(int(career.get("helmet_finish", 0)), 0, 2)
		ensure_trophies()
		return true
	return false


# ---------------------------------------------------------------- utilidades

func fmt_time(t: float) -> String:
	if t == INF or t <= 0.0:
		return "--:--.---"
	var ms := int(round(t * 1000.0))
	return "%d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]


func lap_estimate(track_idx: int, weather: String) -> float:
	## Tempo de referência calculado pelo perfil de velocidade do circuito (não é um tempo histórico).
	var key := "%d_%s" % [track_idx, weather]
	if not _estimates.has(key):
		var tr = TrackScript.new()
		tr.build(tracks[track_idx], weather, false)
		_estimates[key] = tr.lap_estimate()
		tr.free()
	return _estimates[key]


func weather_name(w: String) -> String:
	var k := WEATHERS.find(w)
	return WEATHER_NAMES[k] if k >= 0 else w


func driver_by_code(code: String) -> Dictionary:
	if not career.is_empty() and code == career.get("code", ""):
		return {"name": career["name"], "code": code, "team": int(career["team"]), "skill": 1.0, "num": 21}
	for d in drivers:
		if d["code"] == code:
			return d
	return {"name": code, "code": code, "team": 0, "skill": 0.95, "num": 0}


# ---------------------------------------------------------------- carreira

func new_career(driver_name: String, nation: int, helmet: int) -> void:
	var parts := driver_name.strip_edges().split(" ", false)
	var surname: String = parts[parts.size() - 1] if parts.size() > 0 else "JOG"
	var code := surname.substr(0, 3).to_upper()
	while code.length() < 3:
		code += "X"
	for d in drivers:
		if d["code"] == code:
			code = code.substr(0, 2) + "Z"
	career = {
		"name": driver_name.strip_edges(), "code": code, "nation": nation, "helmet": clampi(helmet, 0, HELMET_NAMES.size() - 1), "helmet_visor": 0, "helmet_finish": 0, "appearance": Appearance.normalized({}),
		"team": -1, "role": "candidate", "season": 1, "round": 0,
		"rejected": [], "attempts": 0, "evals": 0, "offer_pending": false,
		"dev_bonus": {}, "emails": [], "news": [], "lineup": {},
		"dpoints": {}, "tpoints": {}, "dpos": {}, "season_results": [],
		"stats": {"starts": 0, "wins": 0, "podiums": 0, "points": 0, "poles": 0, "best": 0, "tests": 0},
		"history": [], "weak_seasons": 0, "recruit": {},
		"trophies": {}, "trophy_events": {},
	}
	for t in teams.size():
		var codes: Array = []
		for d in drivers:
			if int(d["team"]) == t:
				codes.append(d["code"])
		career["lineup"][str(t)] = codes
	add_email("Federação", "Bem-vindo ao paddock", "Olá, %s. Três equipes abriram vagas de teste para novos pilotos. Escolha uma delas e mostre o seu ritmo no contrarrelógio de avaliação." % career["name"])


func add_email(from: String, subject: String, body: String, offer := "") -> void:
	var emails: Array = career["emails"]
	emails.push_front({"from": from, "subject": subject, "body": body, "read": false, "offer": offer, "answered": false,
		"season": int(career["season"]), "round": int(career["round"])})


func add_news(text: String) -> void:
	var news: Array = career["news"]
	news.push_front({"text": text, "season": int(career["season"]), "round": int(career["round"])})
	while news.size() > 40:
		news.pop_back()


func unread_emails() -> int:
	var n := 0
	for e in career["emails"]:
		if not e["read"]:
			n += 1
	return n


func round_track(round_idx: int) -> int:
	# Preserve completed stages from older saves when showing their calendar.
	for result in career.get("season_results", []):
		if int(result.get("round", 0)) == round_idx + 1:
			return int(result["track"])
	return (round_idx + (int(career["season"]) - 1) * ROUNDS_PER_SEASON) % tracks.size()


func team_perf(team_idx: int) -> float:
	var bonus := 0.0
	if not career.is_empty():
		var db: Dictionary = career.get("dev_bonus", {})
		bonus = float(db.get(str(team_idx), 0.0))
	return float(teams[team_idx]["perf"]) + bonus


func is_race_role() -> bool:
	return career.get("role", "") == "second" or career.get("role", "") == "first"


func season_drivers() -> Array:
	## Os 16 pilotos titulares desta etapa (o jogador entra no lugar de um piloto quando é titular).
	var out: Array = []
	for t in teams.size():
		for code in career["lineup"][str(t)]:
			out.append(code)
	return out


func teammate_code() -> String:
	for code in career["lineup"][str(int(career["team"]))]:
		if code != career["code"]:
			return code
	return ""


func promote_to_race_seat() -> void:
	var t := str(int(career["team"]))
	var lineup: Array = career["lineup"][t]
	if lineup.has(career["code"]):
		return
	# Substitui o piloto de menor ritmo da equipe, que passa a reserva.
	var weakest := 0
	if driver_by_code(lineup[1])["skill"] < driver_by_code(lineup[0])["skill"]:
		weakest = 1
	var out: String = lineup[weakest]
	lineup[weakest] = career["code"]
	career["role"] = "second"
	add_news("%s assume um kart titular da %s no lugar de %s." % [career["name"], teams[int(t)]["name"], driver_by_code(out)["name"]])


func points_of(code: String) -> int:
	return int(career["dpoints"].get(code, 0))


func award(classification: Array) -> void:
	## classification: códigos em ordem de chegada; null/"" para não classificados.
	for i in classification.size():
		var code: String = classification[i]
		var dpos: Dictionary = career["dpos"]
		if not dpos.has(code):
			dpos[code] = [0, 0, 0, 0, 0, 0, 0, 0]
		if i < POINTS.size():
			career["dpoints"][code] = points_of(code) + POINTS[i]
			var team := str(int(driver_by_code(code)["team"]))
			career["tpoints"][team] = int(career["tpoints"].get(team, 0)) + POINTS[i]
			dpos[code][i] = int(dpos[code][i]) + 1


func driver_standings() -> Array:
	var rows: Array = []
	var seen := {}
	for code in season_drivers():
		seen[code] = true
	for code in career["dpoints"].keys():
		seen[code] = true
	for code in seen.keys():
		rows.append({"code": code, "pts": points_of(code), "pos": career["dpos"].get(code, [0, 0, 0, 0, 0, 0, 0, 0])})
	rows.sort_custom(func(a, b):
		if a["pts"] != b["pts"]:
			return a["pts"] > b["pts"]
		for i in 8:
			if int(a["pos"][i]) != int(b["pos"][i]):
				return int(a["pos"][i]) > int(b["pos"][i])
		return a["code"] < b["code"])
	return rows


func team_standings() -> Array:
	var rows: Array = []
	for t in teams.size():
		rows.append({"team": t, "pts": int(career["tpoints"].get(str(t), 0))})
	rows.sort_custom(func(a, b): return a["pts"] > b["pts"] if a["pts"] != b["pts"] else a["team"] < b["team"])
	return rows


func simulate_round(track_idx: int) -> Array:
	## Etapa disputada sem o jogador: resultado por ritmo de piloto/equipe e variação aleatória.
	var rows: Array = []
	for code in season_drivers():
		var d := driver_by_code(code)
		var rating: float = float(d["skill"]) * team_perf(int(d["team"])) + randf_range(-0.018, 0.018)
		rows.append({"code": code, "r": rating, "dnf": randf() < 0.06})
	rows.sort_custom(func(a, b):
		if a["dnf"] != b["dnf"]:
			return b["dnf"]
		return a["r"] > b["r"])
	var order: Array = []
	for row in rows:
		if not row["dnf"]:
			order.append(row["code"])
	award(order)
	var winner := driver_by_code(order[0])
	add_news("GP de %s: vitória de %s (%s)." % [tracks[track_idx]["name"], winner["name"], teams[int(winner["team"])]["name"]])
	return rows


# ---------------------------------------------------------------- áudio de interface

func _build_sfx() -> void:
	_sfx["move"] = _tone(660.0, 0.05, 0.25)
	_sfx["ok"] = _tone(880.0, 0.09, 0.3, 600.0)
	_sfx["back"] = _tone(440.0, 0.09, 0.3, -500.0)
	_sfx["beep"] = _tone(900.0, 0.18, 0.35)
	_sfx["go"] = _tone(1200.0, 0.35, 0.35)
	for i in 3:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)


func sfx(kind: String) -> void:
	if not _sfx.has(kind):
		return
	var p: AudioStreamPlayer = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = _sfx[kind]
	p.volume_db = linear_to_db(maxf(0.001, float(settings["volume"])))
	p.play()


func _tone(freq: float, dur: float, vol: float, slide := 0.0) -> AudioStreamWAV:
	var rate := 22050
	var count := int(dur * rate)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var env := (1.0 - float(i) / count) * minf(1.0, t * 200.0)
		phase += (freq + slide * t) / rate
		var v := sin(TAU * phase) * env * vol
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


# Circuit trophies remain part of the career save, across season resets and transfers.
func ensure_trophies() -> void:
	if not (career.get("trophies") is Dictionary):
		career["trophies"] = {}
	if not (career.get("trophy_events") is Dictionary):
		career["trophy_events"] = {}


func trophy_for(track_idx: int) -> Dictionary:
	if career.is_empty() or track_idx < 0 or track_idx >= tracks.size():
		return {}
	ensure_trophies()
	var key := String(tracks[track_idx]["file"]).get_file().get_basename()
	return career["trophies"].get(key, {})


func trophy_track_count() -> int:
	var count := 0
	for i in tracks.size():
		if not trophy_for(i).is_empty():
			count += 1
	return count


func award_track_trophy(track_idx: int, place: int) -> Dictionary:
	if career.is_empty() or track_idx < 0 or track_idx >= tracks.size() or place < 1 or place > 3:
		return {}
	ensure_trophies()
	var key := String(tracks[track_idx]["file"]).get_file().get_basename()
	var event := "%d:%d:%s" % [int(career["season"]), int(career["round"]), key]
	if career["trophy_events"].has(event):
		return {}
	var entry: Dictionary = career["trophies"].get(key, {"medals": [0, 0, 0], "best_place": 4})
	var medals: Array = entry["medals"]
	var first := int(medals[place - 1]) == 0
	medals[place - 1] = int(medals[place - 1]) + 1
	entry["best_place"] = mini(int(entry["best_place"]), place)
	entry["last_season"] = int(career["season"])
	entry["last_round"] = int(career["round"]) + 1
	career["trophies"][key] = entry
	career["trophy_events"][event] = true
	return {"track": track_idx, "place": place, "first": first, "count": int(medals[place - 1])}
