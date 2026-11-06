extends Node3D
## Kart de câmbio (classe KZ): modelo 3D importado e simulação veicular.
## Dirigibilidade do Pulse Kart (raio de curva limitado pela aderência), motor 2 tempos com curva de torque e câmbio de 6 marchas. Sem downforce.
## Convenções: frente = -Z local; h = guinada (rotation.y); vx para a frente, vy para a esquerda,
## r > 0 = girando para a esquerda; esterço > 0 = esquerda.

## Kart das 8 pinturas (tools/bake_kart2.mjs e bake_kart2.py): malha única em 27 peças, completa no PC e
## leve no celular/navegador; cada equipe tem sua pintura (materiais e texturas em liveries.json).
const SteeringModel := preload("res://scripts/steering_model.gd")
const DriverRig := preload("res://scripts/driver_rig.gd")
const Surfaces := preload("res://scripts/kart_surfaces.gd")
const SuitPaint := preload("res://scripts/suit_paint.gdshader")
const HelmetModel := preload("res://scripts/helmet_model.gd")
const KART2 := "res://models/kart2/"
## Escala uniforme do modelo (o arquivo vem com ~0,98 unidade de comprimento; o kart tem 1,85 m).
const MODEL_SCALE := 1.888
## Ponto mais baixo dos pneus e eixo dianteiro no arquivo (unidades do modelo), para alinhar à física.
const MODEL_GROUND := -0.232
const MODEL_FRONT_Z := -0.188
## Peças do arquivo: pneus dianteiros, traseiros (com os aros), volante, cabeça do piloto.
const PART_FRONT := [8, 9]
const PART_REAR := [12, 13, 14, 19]
const PART_STEER := 10
const PART_HEAD := 5
## Olhos do piloto (unidades do modelo, relativos à cabeça) e giro máximo do volante (rad).
const EYE_OFFSET := Vector3(0.0, 0.035, 0.015)
const STEER_TURN := 0.9

const G := 9.81
const MASS := 175.0
const CG_F := 0.60
const CG_R := 0.423
const WHEELBASE := 1.023
const INERTIA := 75.0
const CG_H := 0.15
const WHEEL_R := 0.14
const FRONT_WHEEL_R := 0.148
const MU := 1.75
## Dirigibilidade do Pulse Kart: o volante pede uma fração da curva mais fechada que a aderência
## permite (raio = v² / aceleração lateral máxima), então o kart nunca passa do limite e não roda.
## A velocidade lateral some depressa (o kart "assenta" na curva) e parte dela volta para a frente.
const LAT_ACCEL := 18.5                   # aceleração lateral máxima no seco (m/s²)
const MIN_RADIUS := 2.9                   # raio mínimo de curva (m)
const STEER_RATE := 5.5                   # velocidade do volante (fração por segundo)
const SIDE_GRIP := 10.0                   # taxa com que a velocidade lateral desaparece (1/s)
const SIDE_GRIP_LOOSE := 4.0              # na grama ou com a roda patinando
const SIDE_TO_FORWARD := 0.45             # parte da velocidade lateral perdida que volta para a frente
const WHEEL_LOCK := 0.42                  # ângulo visual máximo das rodas dianteiras (rad)
const RATIOS: Array[float] = [12.8, 9.9, 8.1, 6.9, 6.0, 5.3]
const RPM_IDLE := 3500.0
const RPM_LIMIT := 14800.0
const BRAKE_FORCE := 3600.0
const CDA := 0.55
const CLA := 0.0
## Colisão: dois círculos ao longo do eixo do kart (deslocamentos para a frente) e raio.
const HIT_OFFSETS: Array[float] = [0.6, -0.15]
const HIT_RADIUS := 0.62
## Compostos de pneu: aderência e desgaste relativos (o de chuva só rende na pista molhada).
const COMPOUNDS := [
	{"name": "Macio", "short": "M", "grip": 1.035, "wear": 1.5, "color": Color(0.92, 0.16, 0.12)},
	{"name": "Duro", "short": "D", "grip": 1.0, "wear": 1.0, "color": Color(0.95, 0.95, 0.95)},
	{"name": "Chuva", "short": "C", "grip": 1.0, "wear": 1.0, "color": Color(0.2, 0.55, 0.95)},
]
const FUEL_KG := 3.0                      # massa de uma volta de combustível (kg)

var driver: Dictionary
var team: Dictionary
var is_player := false
var perf := 1.0
var pace := 1.0

# estado da simulação
var pos := Vector3.ZERO
var h := 0.0
var vx := 0.0
var vy := 0.0
var r := 0.0
var steer := 0.0
var steer_in := 0.0
var throttle := 0.0
var brake_in := 0.0
var gear := 1
var rpm := RPM_IDLE
var shift_cut := 0.0
var shift_cool := 0.0
var ax := 0.0
var slip_f := 0.0
var slip_r := 0.0
var spinning := false
var locking := false
var surface := 0          # 0 asfalto, 1 zebra, 2 grama/escape
var wear := 0.0           # média dos quatro pneus (0 novo, 1 acabado)
var tyre_wear: Array = [0.0, 0.0, 0.0, 0.0]   # dianteiro esq., dianteiro dir., traseiro esq., traseiro dir.
var compound := 1
var tyre_temp := 1.0      # 0 = pneu frio (acabou de sair do box), 1 = na temperatura
var tyre_life := 25.0     # voltas para gastar um jogo de pneus duros (a corrida ajusta)
var track_wetness := -1.0
var wet_track := false
var fuel := 1.0           # combustível no tanque, em voltas
var fuel_cap := 99.0
var fuel_use := 0.0       # 0 = o combustível não acaba (regra desligada ou fora de corrida)
var out_of_fuel := false
var retire_reason := ""
var damage := 0.0
var held := true
var retired := false
var impact := 0.0
var rev_timer := 0.0
var want_reverse := false
var pitch := 0.0
var shift_event := 0

# assistências
var tc := true
var abs_on := true
var stability := false
var auto_gear := true
var damage_on := true
var weather_mu := 1.0

# posição na pista
var track
var ti := -1
var s := 0.0
var d := 0.0

# cronometragem
var lap := 0
var max_lap := 0
var last_s := 0.0
var lap_start := 0.0
var best_lap := INF
var last_lap := 0.0
var lap_invalid := false
var sector := 0
var sector_start := 0.0
var splits := [0.0, 0.0, 0.0]
var finished := false
var finish_time := 0.0
var finish_order := 0
var penalty := 0.0
var warnings := 0
var off_since := -1.0
var lap_times: Array = []

# box
var pit_state := 0        # 0 na pista, 1 a caminho do box, 2 parado sendo atendido, 3 saindo do box
var pit_request := false
var pit_box := 0
var pit_bay := 0              # vaga dentro do box da equipe
var pit_timer := 0.0
var pit_total := 0.0
var pit_service := {}
var stops := 0
var pit_aggr := 0.0       # IA: quão cedo antecipa a parada

# IA
var racecraft: Dictionary = {}
var lane := 0.0
var lane_target := 0.0
var mistake_t := 0.0
var stuck_t := 0.0
var reverse_t := 0.0

# visual
var visual_parts: Dictionary = {}
var dirt := 0.0
var tyre_wear_material: ShaderMaterial
var wear_material: ShaderMaterial
var celebration_strength := 0.0
var replaying := false
var driver_rig: Node3D
var visual_steer := 0.0
var _visual_compound := -1
var body: Node3D
var front_wheels: Array = []
var rear_wheels: Array = []
var helmet: MeshInstance3D
var steering_wheel: Node3D
var steer_axis := Vector3.FORWARD     # eixo da coluna de direção (espaço do volante)
var steer_rest := Basis()
var eye := Vector3(0.0, 0.76, 0.06)   # olhos do piloto no espaço de body (câmera do piloto)
static var _cache := {}
var spin_f := 0.0
var spin_r := 0.0
var body_pitch := 0.0
var body_roll := 0.0


# ---------------------------------------------------------------- modelo

func build_model(helmet_color := Color(0, 0, 0, 0), force_lite := false) -> void:
	## Kart e piloto do arquivo das 8 pinturas, com a pintura da equipe. Pneus e aros giram em torno do
	## próprio centro, os dianteiros esterçam e o volante gira na coluna. helmet_color (alfa > 0) troca o
	## capacete da pintura por um de cor lisa (piloto do jogador na carreira).
	body = Node3D.new()
	add_child(body)
	var root := Node3D.new()
	root.scale = Vector3.ONE * MODEL_SCALE
	# eixo dianteiro a CG_F à frente do centro de gravidade (origem do kart), pneus no chão
	root.position = Vector3(0.0, -MODEL_GROUND * MODEL_SCALE, -CG_F - MODEL_FRONT_Z * MODEL_SCALE)
	body.add_child(root)
	var lite := Game.lite_models() or force_lite
	var kart: Node3D = _cached(KART2 + ("kart2_lite.glb" if lite else "kart2_full.glb")).instantiate()
	root.add_child(kart)
	var parts := {}
	var key: String = team.get("livery", "scarlet")
	for c in kart.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var idx := int(String(mi.name).get_slice("_", 2))
		mi.material_override = _livery_material(key, String(mi.name))
		parts[idx] = mi
		if idx in [8, 9, 12, 13]:
			Surfaces.refine_wheel(mi, lite, team.get("c2", Color(0.7, 0.72, 0.75)))
		elif idx in [14, 19]:
			mi.visible = false
		if PART_FRONT.has(idx):
			front_wheels.append(mi)
		elif PART_REAR.has(idx):
			rear_wheels.append(mi)
		elif idx == PART_STEER:
			steering_wheel = mi
			steer_rest = mi.basis
			steer_axis = _steer_axis(mi.mesh)
			SteeringModel.apply(mi, steer_axis, lite)
		elif idx == PART_HEAD:
			helmet = mi
			HelmetModel.apply(helmet, lite, key)
			eye = root.transform * (mi.position + EYE_OFFSET)
	for w in front_wheels + rear_wheels:
		w.set_meta("rest", (w as Node3D).basis)
	var suit := ShaderMaterial.new()
	suit.shader = SuitPaint
	suit.set_shader_parameter("paint", (parts[4].material_override as StandardMaterial3D).albedo_texture)
	parts[4].material_override = suit
	driver_rig = DriverRig.new()
	kart.add_child(driver_rig)
	driver_rig.setup(parts, lite)
	visual_parts = parts
	if helmet_color.a > 0.0:
		set_helmet_color(helmet_color)
	_update_rig()


func set_helmet_color(c: Color) -> void:
	if helmet:
		var paint := helmet.material_override as StandardMaterial3D
		paint.albedo_texture = null
		paint.albedo_color = c


func set_helmet_design(design: int, visor: int = 0, finish: int = 0) -> void:
	if helmet:
		HelmetModel.customize(helmet, design, visor, finish)


static func _cached(path: String) -> Resource:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


static func _livery_material(key: String, part: String) -> Material:
	## Material de uma peça na pintura da equipe (cor, metal, rugosidade e textura), um por pintura e peça.
	var ck := key + "/" + part
	if _cache.has(ck):
		return _cache[ck]
	if not _cache.has("liveries"):
		_cache["liveries"] = JSON.parse_string(FileAccess.get_file_as_string(KART2 + "liveries.json"))
	var liv: Dictionary = _cache["liveries"].get(key, _cache["liveries"]["scarlet"])
	var spec: Dictionary = liv["parts"].get(part, {})
	var m := StandardMaterial3D.new()
	var c: Array = spec.get("c", [0.5, 0.5, 0.5])
	m.albedo_color = Color(c[0], c[1], c[2])
	m.metallic = float(spec.get("m", 0.0))
	m.roughness = float(spec.get("r", 0.8))
	if spec.has("tex"):
		m.albedo_texture = load(KART2 + "%s/%s.jpg" % [liv.get("dir", key), spec["tex"]])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if spec["tex"] in ["side", "nose", "bumper"]:
			m.clearcoat_enabled = true
			m.clearcoat = 0.35
			m.clearcoat_roughness = 0.3
			m.roughness = maxf(m.roughness, 0.36)
	_cache[ck] = m
	return m


static func _steer_axis(mesh: Mesh) -> Vector3:
	## Eixo da coluna: normal do aro do volante (direção de menor espalhamento dos vértices no plano YZ;
	## o volante é simétrico em X), apontando para trás, para o piloto.
	if _cache.has("steer_axis"):
		return _cache["steer_axis"]
	var v: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var my := 0.0
	var mz := 0.0
	for p in v:
		my += p.y
		mz += p.z
	my /= v.size()
	mz /= v.size()
	var cyy := 0.0
	var czz := 0.0
	var cyz := 0.0
	for p in v:
		cyy += (p.y - my) * (p.y - my)
		czz += (p.z - mz) * (p.z - mz)
		cyz += (p.y - my) * (p.z - mz)
	var major := 0.5 * atan2(2.0 * cyz, cyy - czz)        # direção do aro no plano YZ
	var n := Vector3(0.0, -sin(major), cos(major))
	if n.z < 0.0:
		n = -n
	_cache["steer_axis"] = n
	return n


func _process(dt: float) -> void:
	if not replaying:
		var safe := finished and finish_order == 1 and absf(vx) < 24.0 and absf(r) < 0.18 and surface == 0 and pit_state == 0
		celebration_strength = move_toward(celebration_strength, 1.0 if safe else 0.0, dt * 2.5)
		_update_race_wear(dt)
	_update_rig(dt)
	if _visual_compound != compound:
		_visual_compound = compound
		var key := "compound_mark_%d" % compound
		if not _cache.has(key):
			_cache[key] = _mat(COMPOUNDS[compound]["color"], 0.0, 0.85)
		for wheel in front_wheels + rear_wheels:
			for detail in wheel.get_children():
				if String(detail.name).begins_with("CompoundMark"):
					detail.material_override = _cache[key]


func _update_rig(dt: float = 0.0) -> void:
	## Volante gira com o esterço em torno da coluna.
	if steering_wheel == null:
		return
	visual_steer = lerpf(visual_steer, steer, 1.0 - exp(-dt * 22.0)) if dt > 0.0 else steer
	var rotation_basis := Basis(steer_axis, visual_steer * STEER_TURN)
	steering_wheel.basis = rotation_basis * steer_rest
	if driver_rig:
		driver_rig.celebration = celebration_strength
		driver_rig.animate(dt, rotation_basis, steering_wheel.position, vx * r, ax, visual_steer, vx, held)


func _mat(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m


# ---------------------------------------------------------------- utilidades

func fwd() -> Vector3:
	return Vector3(-sin(h), 0.0, -cos(h))


func left() -> Vector3:
	return Vector3(-cos(h), 0.0, sin(h))


func world_vel() -> Vector3:
	return fwd() * vx + left() * vy


func set_world_vel(v: Vector3) -> void:
	vx = v.dot(fwd())
	vy = v.dot(left())


func speed_kmh() -> float:
	return absf(vx) * 3.6


func tyre_grip(k: int) -> float:
	## Aderência de um pneu pelo desgaste: cai pouco até 70 % e despenca no fim da vida.
	var w: float = tyre_wear[k]
	return 1.0 - 0.1 * w - (0.3 * (w - 0.7) / 0.3 if w > 0.7 else 0.0)


func compound_mu() -> float:
	if track_wetness >= 0.0:
		return lerpf(0.90, 1.0, track_wetness) if compound == 2 else float(COMPOUNDS[compound]["grip"]) * lerpf(1.0, 0.82, track_wetness)
	if compound == 2:
		return 1.0 if wet_track else 0.9
	var g: float = COMPOUNDS[compound]["grip"]
	return g * 0.82 if wet_track else g      # pneu liso na pista molhada


func grip_factor() -> float:
	## Aderência relativa dos pneus dianteiros agora (composto, desgaste e temperatura).
	return compound_mu() * (tyre_grip(0) + tyre_grip(1)) * 0.5 * (0.9 + 0.1 * tyre_temp)


func lat_limit() -> float:
	## Aceleração lateral disponível agora (piso, chuva, pneus e danos).
	var surf_mu := 0.9 if surface == 1 else (0.55 if surface == 2 else 1.0)
	return LAT_ACCEL * surf_mu * weather_mu * grip_factor() * (1.0 - 0.15 * damage)


func turn_radius() -> float:
	## Raio da curva com o volante todo virado na velocidade atual.
	return maxf(MIN_RADIUS, vx * vx / lat_limit())


func steer_for_curvature(k: float) -> float:
	## Converte a curvatura desejada (1/m, > 0 = esquerda) na posição do volante (-1..1).
	return clampf(k * turn_radius(), -1.0, 1.0)


func progress() -> float:
	return lap * track.length + s


func place(tr, at_s: float, lateral: float) -> void:
	track = tr
	pos = tr.point_at(at_s, lateral)
	h = tr.heading_at(at_s)
	vx = 0.0
	vy = 0.0
	r = 0.0
	ti = -1
	var q: Dictionary = tr.query(pos, -1)
	ti = q["i"]
	s = q["s"]
	d = q["d"]
	pos.y = q["y"]
	last_s = s
	gear = 1
	_update_visual(0.0)


func shift_up() -> bool:
	if gear == -1:
		gear = 1
		return true
	if gear >= RATIOS.size() or shift_cool > 0.0:
		return false
	gear += 1
	shift_cut = 0.05
	shift_cool = 0.15
	shift_event += 1
	return true


func shift_down() -> bool:
	## Recusa reduções que levariam o motor acima do limite (proteção contra excesso de rotação).
	if gear <= 1 or shift_cool > 0.0:
		return false
	var new_rpm := absf(vx) / WHEEL_R * RATIOS[gear - 2] * 9.549
	if new_rpm > RPM_LIMIT + 500.0:
		return false
	gear -= 1
	shift_cut = 0.05
	shift_cool = 0.15
	shift_event += 1
	return true


static func torque_at(x: float) -> float:
	## Torque do motor 125 cc 2 tempos (N·m no virabrequim).
	if x < 8000.0:
		return lerpf(12.0, 22.0, clampf((x - RPM_IDLE) / 4500.0, 0.0, 1.0))
	if x < 12000.0:
		return lerpf(22.0, 26.0, (x - 8000.0) / 4000.0)
	if x < 14000.0:
		return lerpf(26.0, 23.0, (x - 12000.0) / 2000.0)
	return lerpf(23.0, 19.0, clampf((x - 14000.0) / 800.0, 0.0, 1.0))


# ---------------------------------------------------------------- simulação

func step(dt: float) -> void:
	shift_cut = maxf(0.0, shift_cut - dt)
	shift_cool = maxf(0.0, shift_cool - dt)
	impact = maxf(0.0, impact - dt * 2.0)
	var spd := absf(vx)
	var thr := throttle
	var brk := brake_in
	if retired:
		thr = 0.0
		brk = 1.0
	if out_of_fuel:
		# motor morto; no pit lane os mecânicos empurram o kart até o box (devagar)
		thr = minf(thr, 0.35) if pit_state > 0 else 0.0
	if held or pit_state == 2:
		# no grid ou parado no box sendo atendido
		var rev := thr
		if not is_player:
			# no grid os pilotos aceleram em golpes, cada um no seu ritmo
			var tt := Time.get_ticks_msec() * 0.001 + float(driver.get("num", 0)) * 1.7
			rev = 0.12 + (0.6 if sin(tt * 2.3) > 0.55 else 0.0)
		rpm = lerpf(rpm, RPM_IDLE + rev * 9000.0, minf(1.0, dt * 6.0))
		vx = 0.0
		vy = 0.0
		r = 0.0
		_update_visual(dt)
		return

	# marcha à ré: segurar o freio parado por um instante
	if gear > 0 and spd < 0.5 and pit_state == 0 and ((brk > 0.5 and thr < 0.05) or want_reverse):
		rev_timer += dt
		if rev_timer > 0.6 or want_reverse:
			gear = -1
	else:
		rev_timer = 0.0
	if gear == -1 and not want_reverse and thr > 0.1 and vx > -0.5:
		gear = 1
	var drive_in := thr
	var brake_cmd := brk
	if gear == -1:
		drive_in = 0.0
		brake_cmd = thr

	steer = move_toward(steer, steer_in, STEER_RATE * dt)
	var lat := lat_limit()
	# frenagem leve na entrada da curva joga peso na frente e ajuda o kart a fechar
	if brake_cmd > 0.05 and brake_cmd < 0.7 and spd > 6.0:
		lat *= 1.08
	# combustível pesa: o kart cheio acelera e freia um pouco pior
	var m := MASS + (fuel * FUEL_KG if fuel_use > 0.0 else 0.0)
	var rear_g := (tyre_grip(2) + tyre_grip(3)) * 0.5
	var front_g := (tyre_grip(0) + tyre_grip(1)) * 0.5
	var grip_long := lat * m * 1.1 * rear_g / maxf(0.3, front_g)   # força longitudinal máxima dos pneus

	# motor
	if gear > 0:
		var wheel_rpm := spd / WHEEL_R * RATIOS[gear - 1] * 9.549
		rpm = maxf(RPM_IDLE, wheel_rpm)
		if spinning:
			rpm = minf(RPM_LIMIT, rpm + 2500.0)
	else:
		rpm = maxf(RPM_IDLE, spd / WHEEL_R * 12.0 * 9.549)
	var fx_drive := 0.0
	if gear > 0 and shift_cut <= 0.0 and rpm < RPM_LIMIT:
		fx_drive = torque_at(rpm) * RATIOS[gear - 1] / WHEEL_R * 0.92 * perf * drive_in
	elif gear == -1 and vx > -3.0:
		# karts não têm ré: equivale a empurrar o kart de volta (assistência do jogo)
		fx_drive = -brk * 420.0
	# tração: com TC o motor nunca passa da aderência; sem TC a roda patina e a traseira solta
	spinning = false
	if fx_drive > grip_long:
		if tc:
			fx_drive = grip_long
		else:
			spinning = true
			fx_drive = 0.85 * grip_long

	# freios: com ABS no limite da aderência; sem ABS a roda trava e o volante perde efeito
	locking = false
	var bf := brake_cmd * BRAKE_FORCE
	if bf > grip_long:
		if abs_on:
			bf = grip_long
		else:
			bf = 0.8 * grip_long
			locking = true

	# forças que só freiam (aplicadas sem inverter o sentido do movimento)
	var stop_f := bf + 25.0
	if surface == 2:
		stop_f += 0.08 * MASS * G + 6.0 * spd
	if gear > 0 and drive_in < 0.05:
		stop_f += 260.0 * (rpm / RPM_LIMIT)
	var drag := 0.6 * CDA * vx * absf(vx)
	var fx := fx_drive - drag - m * G * pitch
	ax = clampf((fx - stop_f * signf(vx)) / m, -60.0, 30.0)
	vx += fx / m * dt
	vx = move_toward(vx, 0.0, stop_f / m * dt)

	# direção: guinada = volante × velocidade / raio limitado pela aderência
	var radius := maxf(MIN_RADIUS, vx * vx / lat) * (1.6 if surface == 2 else 1.0)
	var authority := 0.35 if locking else 1.0
	r = steer * authority * vx / radius
	var dh := r * dt
	# girar o kart gira o vetor velocidade no referencial do kart (a velocidade fica para trás)
	var cvx := vx * cos(dh) + vy * sin(dh)
	vy = vy * cos(dh) - vx * sin(dh)
	vx = cvx
	# aderência lateral: a velocidade lateral some depressa e parte volta para a frente
	var grip := SIDE_GRIP_LOOSE if surface == 2 or spinning else SIDE_GRIP
	if stability:
		grip *= 1.4
	grip *= 0.55 + 0.45 * rear_g       # traseiros gastos: a traseira escorrega mais
	var nvy := vy * exp(-grip * dt)
	if impact <= 0.05 and vx > 0.0:
		vx += absf(vy - nvy) * SIDE_TO_FORWARD
	vy = nvy
	slip_r = atan2(vy, maxf(spd, 3.0))
	slip_f = absf(steer) * 0.12 * clampf(spd / 15.0, 0.0, 1.0) + (0.15 if locking else 0.0)

	# câmbio automático
	if auto_gear and gear > 0 and shift_cool <= 0.0:
		if rpm > 14300.0 and gear < RATIOS.size():
			shift_up()
		elif gear > 1 and rpm < 9500.0 and spd / WHEEL_R * RATIOS[gear - 2] * 9.549 < 13800.0:
			shift_down()

	# integração no mundo
	var v := world_vel()
	pos += v * dt
	h += dh

	_tyres_and_fuel(dt, spd, drive_in)

	_track_contact(dt)
	_update_visual(dt)


func _tyres_and_fuel(dt: float, spd: float, drive_in: float) -> void:
	## Desgaste de cada pneu pela carga que leva (lado de fora da curva, dianteiros na freada, traseiros
	## na tração, muito mais derrapando, patinando ou travando), aquecimento e consumo de combustível.
	var lat_g := clampf(vx * r / LAT_ACCEL, -1.5, 1.5)      # > 0 = curva à esquerda: carga nos pneus da direita
	var lon_g := clampf(ax / 12.0, -1.5, 1.5)
	var slide := absf(slip_r) * 4.0
	var lock := 1.5 if locking else 0.0
	var spin := 1.5 if spinning else 0.0
	var loads := [
		1.0 + maxf(0.0, -lat_g) * 0.9 + maxf(0.0, -lon_g) * 0.5 + lock,
		1.0 + maxf(0.0, lat_g) * 0.9 + maxf(0.0, -lon_g) * 0.5 + lock,
		1.0 + maxf(0.0, -lat_g) * 0.9 + maxf(0.0, lon_g) * 0.5 + slide + spin,
		1.0 + maxf(0.0, lat_g) * 0.9 + maxf(0.0, lon_g) * 0.5 + slide + spin,
	]
	var rate: float = spd * dt / (track.length * tyre_life) * float(COMPOUNDS[compound]["wear"])
	if compound == 2 and not wet_track:
		rate *= 2.5          # pneu de chuva no seco se desmancha
	var total := 0.0
	for k in 4:
		tyre_wear[k] = minf(1.0, tyre_wear[k] + rate * (0.35 + 0.65 * float(loads[k])) / 1.25)
		total += tyre_wear[k]
	wear = total * 0.25
	if spd > 3.0:
		tyre_temp = minf(1.0, tyre_temp + dt * (0.02 + 0.06 * clampf(absf(lat_g) + absf(lon_g), 0.0, 1.5)))
	if fuel_use > 0.0 and not out_of_fuel:
		fuel = maxf(0.0, fuel - spd * dt * (0.3 + 0.7 * drive_in) / (track.length * 0.62) * fuel_use)
		if fuel <= 0.0:
			out_of_fuel = true


func _track_contact(_dt: float) -> void:
	var prev_d := d
	var q: Dictionary = track.query(pos, ti)
	ti = q["i"]
	s = q["s"]
	d = q["d"]
	pos.y = q["y"]
	pitch = atan(float(track.grade[ti]) * fwd().dot(track.tans[ti]))
	var ad := absf(d)
	if ad <= track.hw:
		surface = 0
	elif ad <= track.hw + track.kerb_w and track.kerb_zone[ti] == 1:
		surface = 1
	else:
		surface = 2
	if surface == 2 and track.on_pit_lane(s, d):
		surface = 0
	var lim: float = track.wall_at(ti, d) - 0.7
	if ad > lim:
		var nrm: Vector3 = track.rgts[ti] * signf(d)
		pos -= nrm * (ad - lim)
		var v := world_vel()
		var vn := v.dot(nrm)
		if vn > 0.0:
			# remove a componente contra o muro (com leve rebote) e aplica atrito
			# proporcional à força do contato, para raspar no muro não travar o kart
			var vt := v - nrm * vn
			vt = vt.move_toward(Vector3.ZERO, vn * 0.6)
			set_world_vel(vt - nrm * vn * 0.3)
			r *= clampf(1.0 - vn * 0.12, 0.4, 1.0)
			hit(vn)
		d = signf(d) * lim
	# muro entre a pista e o pit lane: empurra de volta para o lado de onde o kart veio
	if track.has_pit and track.pit_divider(track.pit_u(s)):
		var sg: float = track.pit_side
		var inner: float = track.hw + track.PIT_WALL_IN - 0.7
		var outer: float = track.hw + track.PIT_WALL_OUT + 0.7
		var sd: float = d * sg
		if sd > inner and sd < outer:
			var from_track: bool = prev_d * sg < track.hw + (track.PIT_WALL_IN + track.PIT_WALL_OUT) * 0.5
			var target: float = inner if from_track else outer
			var nrm: Vector3 = track.rgts[ti] * sg * (1.0 if from_track else -1.0)
			pos -= nrm * absf(sd - target)
			var v := world_vel()
			var vn := v.dot(nrm)
			if vn > 0.0:
				var vt := v - nrm * vn
				vt = vt.move_toward(Vector3.ZERO, vn * 0.6)
				set_world_vel(vt - nrm * vn * 0.3)
				r *= clampf(1.0 - vn * 0.12, 0.4, 1.0)
				hit(vn)
			d = target * sg


func hit(strength: float) -> void:
	impact = maxf(impact, clampf(strength / 10.0, 0.0, 1.0))
	if damage_on and strength > 4.0:
		damage = minf(1.0, damage + (strength - 4.0) * 0.008)
		if damage >= 1.0:
			retired = true
			retire_reason = "dano"


func _update_visual(dt: float) -> void:
	position = pos
	rotation = Vector3(0.0, h, 0.0)
	body_pitch = lerpf(body_pitch, clampf(ax * 0.002, -0.025, 0.025) + pitch, 1.0 - exp(-dt * 8.0))
	var lat_acc := vx * r
	body_roll = lerpf(body_roll, clampf(-lat_acc * 0.0012, -0.025, 0.025), 1.0 - exp(-dt * 8.0))
	if body:
		body.rotation = Vector3(body_pitch, 0.0, body_roll)
		# eixo traseiro rígido: as duas rodas traseiras giram juntas; dianteiras livres
		var rear_w := vx / WHEEL_R
		if spinning:
			rear_w += 12.0 * signf(vx if vx != 0.0 else 1.0)
		if locking:
			rear_w *= 0.2
		spin_r = wrapf(spin_r - rear_w * dt, -PI, PI)
		spin_f = wrapf(spin_f - vx / FRONT_WHEEL_R * dt, -PI, PI)
		for w in rear_wheels:
			w.basis = Basis(Vector3.RIGHT, spin_r) * (w.get_meta("rest") as Basis)
		for w in front_wheels:
			w.basis = Basis(Vector3.UP, _front_angle(w.position.x)) * Basis(Vector3.RIGHT, spin_f) * (w.get_meta("rest") as Basis)


func _front_angle(wheel_x: float) -> float:
	# Ackermann: the wheel on the inside of the corner turns further.
	var angle := visual_steer * WHEEL_LOCK
	if absf(angle) < 0.0001:
		return 0.0
	var radius := WHEELBASE / tan(absf(angle))
	var inside := wheel_x * angle < 0.0
	return signf(angle) * atan(WHEELBASE / maxf(0.1, radius + (-0.43 if inside else 0.43)))


func _update_race_wear(dt: float) -> void:
	if track == null or held: return
	dirt = minf(.8, dirt + absf(vx)*dt*(.0004 if surface==2 else (.00006 if wet_track else .000008)))
	if wear_material == null and (dirt>.025 or damage>.04):
		wear_material = ShaderMaterial.new()
		wear_material.shader = preload("res://scripts/race_wear.gdshader")
		for idx in ([3,6,20] if Game.lite_models() else [3,6,7,20,22]):
			if visual_parts.has(idx): visual_parts[idx].material_overlay = wear_material
	if wear_material:
		wear_material.set_shader_parameter("dirt", dirt)
		wear_material.set_shader_parameter("damage", damage)
	if tyre_wear_material == null and (wear>.02 or dirt>.04) and (is_player or not Game.lite_models()):
		tyre_wear_material = ShaderMaterial.new()
		tyre_wear_material.shader = preload("res://scripts/race_wear.gdshader")
		tyre_wear_material.set_shader_parameter("tyre", true)
		for wheel in front_wheels + rear_wheels: wheel.material_overlay = tyre_wear_material
	if tyre_wear_material:
		tyre_wear_material.set_shader_parameter("dirt", minf(.8, dirt + wear*.5))
		tyre_wear_material.set_shader_parameter("damage", wear*.2)
	for idx in [3,20]:
		if visual_parts.has(idx):
			var part: MeshInstance3D = visual_parts[idx]
			if not part.has_meta("wear_basis"): part.set_meta("wear_basis",part.basis)
			part.basis = (part.get_meta("wear_basis") as Basis)*Basis(Vector3.FORWARD,damage*.025*(1.0 if idx==3 else -1.0))
