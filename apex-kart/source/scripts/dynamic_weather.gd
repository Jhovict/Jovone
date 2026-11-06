extends RefCounted
var active := false
var start_wet := false
var elapsed := 0.0
var duration := 180.0
var rain := 0.0
var wetness := 0.0
var forecast_sent := false
var wet_sent := false
var dry_sent := false
var profile_clock := 0.0
var base_pace: Array = []
func setup(race) -> void:
	active = race.cfg["mode"]=="race" and race.cfg["weather"] in ["dry","rain"] and bool(race.cfg.get("weather_change",Game.settings.get("weather_change",false)))
	start_wet = race.cfg["weather"]=="rain"
	wetness = 1.0 if start_wet else 0.0
	rain = wetness
	duration = maxf(70.0,race.track.lap_estimate()*int(race.cfg.get("laps",3)))
	for car in race.cars: base_pace.append(car.pace / float(Game.WEATHER_PACE.get(race.cfg["weather"],1.0)))
	if active and race.rain==null:
		race.rain = race._drops(900 if Game.lite_models() else 1600,.7,Vector3(0,-1,0),22,28,.55,.35)
		race.rain.emitting = false
func advance(dt: float) -> void:
	elapsed += dt
	var progress := elapsed/duration
	var target := 0.0
	if start_wet: target = 1.0-smoothstep(.35,.65,progress)
	else: target = smoothstep(.24,.40,progress)*(1.0-smoothstep(.74,.92,progress))
	rain = move_toward(rain,target,dt*.08)
	wetness = move_toward(wetness,rain,dt*(.045 if rain>wetness else .018))
func update(race,dt: float) -> void:
	if not active or race.state!="running": return
	advance(dt)
	if not start_wet and not forecast_sent and elapsed>duration*.13:
		forecast_sent = true
		race.radio.say("rain_soon")
	if wetness>.45 and not wet_sent:
		wet_sent = true
		race.radio.say("wet", "", true)
	if wet_sent and wetness<.28 and not dry_sent:
		dry_sent = true
		race.radio.say("drying")
	race.track.wet = wetness>.35
	race.track.mu_scale = lerpf(1,.72,wetness)
	profile_clock += dt
	if profile_clock>=1.0:
		profile_clock = 0
		race.track._compute_profile()
	for i in race.cars.size():
		var car = race.cars[i]
		car.wet_track = race.track.wet
		car.track_wetness = wetness
		car.weather_mu = race.track.mu_scale
		car.pace = base_pace[i]*lerpf(1,.97,wetness)
	if race.track._asphalt:
		race.track._asphalt.roughness = lerpf(.88,.27,wetness)
		race.track._asphalt.albedo_color = Color.WHITE.lerp(Color(.68,.72,.77),wetness)
	var sky: ProceduralSkyMaterial = race.env.sky.sky_material
	sky.sky_top_color = (race.SKY["dry"][0] as Color).lerp(race.SKY["rain"][0],rain)
	sky.sky_horizon_color = (race.SKY["dry"][1] as Color).lerp(race.SKY["rain"][1],rain)
	race.sun.light_energy = lerpf(1.6,.55,rain)
	race.env.fog_density = lerpf(.0009,.0055,rain)
	sky.ground_horizon_color = sky.sky_horizon_color
	race.env.fog_light_color = sky.sky_horizon_color
	if race.rain:
		race.rain.emitting = rain>.06
		var mat := race.rain.mesh.material as StandardMaterial3D
		if mat: mat.albedo_color.a = rain*.35
	race.audio.rain_amount = rain*.45
