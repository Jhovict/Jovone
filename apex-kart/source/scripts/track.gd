extends Node3D
## Kartódromo fechado lido de tracks/*.json (linha central com relevo, distância das barreiras e dos
## taludes por amostra, zonas de ponte): consultas (s, d, altura), linha ideal, perfil de velocidade
## de referência e toda a geometria 3D, construída na ordem asfalto → zebras → escape → barreiras →
## taludes/ponte → cenário.

const DF_K := 0.0             # karts não geram downforce
const LINE_MU := 1.6
const KART_MASS := 175.0
const KART_CDA := 0.55
const KART_POWER := 30000.0   # potência efetiva na roda (W)
const TOP_SPEED := 42.0
const GRID_START := 6.0       # distância da linha até o 1º kart do grid
const GRID_STEP := 3.5        # distância entre karts consecutivos (fila dupla alternada)
const GRID_LATERAL := 1.5
const BARRIER_H := 1.0
const GRID_CELL := 24.0
## Pit lane (lado e início escolhidos por tools/pits.py): rampa de entrada, folga, 8 boxes (um por equipe),
## folga e rampa de saída, paralelo à pista e separado dela por um muro baixo. Cada box tem uma vaga por
## piloto da equipe (com os seus mecânicos), então o grid cheio de 16 karts nunca forma fila.
const PIT_RAMP := 28.0
const PIT_PAD := 8.0
const PIT_BOX := 8.0
const PIT_BOXES := 8
const PIT_BAYS := 2           # vagas por box: uma para cada piloto da equipe
const PIT_BAY_GAP := 4.4      # distância entre as duas vagas do mesmo box
const PIT_LEN := PIT_RAMP * 2.0 + PIT_PAD * 2.0 + PIT_BOX * PIT_BOXES
const PIT_WALL_IN := 0.5      # muro divisório de hw + 0.5 a hw + 1.1
const PIT_WALL_OUT := 1.1
const PIT_W := 5.5            # largura do pit lane (faixa de passagem + faixa dos boxes)
const PIT_SPEED := 13.9       # limite de velocidade (50 km/h)

var def: Dictionary
var theme := "hills"
var pts := PackedVector3Array()
var tans := PackedVector3Array()
var rgts := PackedVector3Array()
var curv := PackedFloat32Array()
var grade := PackedFloat32Array()
var line_off := PackedFloat32Array()
var line_curv := PackedFloat32Array()
var speed := PackedFloat32Array()
var kerb_zone := PackedByteArray()
var wall_l := PackedFloat32Array()
var wall_r := PackedFloat32Array()
var emb_l := PackedFloat32Array()
var emb_r := PackedFloat32Array()
var embh_l := PackedFloat32Array()   # NAN = desce até o terreno
var embh_r := PackedFloat32Array()
var bridge := PackedByteArray()
var n := 0
var ds := 1.0
var length := 0.0
var hw := 4.5
var kerb_w := 1.0
var wall := 11.0              # maior distância de barreira (referência para câmeras e cenário)
var base_y := 0.0
var mu_scale := 1.0
var wet := false              # chuva, tempestade ou neve: asfalto molhado
var weather := "dry"
var start_light_mats: Array = []
var tv_points: Array = []
var line_mesh: MeshInstance3D
var bounds := Rect2()
var _grid := {}
var has_pit := false
var pit_side := 1.0           # 1 = à direita da pista, -1 = à esquerda
var pit_s0 := 0.0             # distância do início da rampa de entrada
var pit_garages := false
var pit_crew: Array = []      # por vaga (box * PIT_BAYS + vaga): mecânicos (Node3D)
var pit_crew_home: Array = [] # por vaga: onde cada mecânico espera


func build(track_def: Dictionary, weather_key: String, with_meshes := true) -> void:
	def = track_def
	weather = weather_key
	wet = weather != "dry"
	mu_scale = float(Game.WEATHER_MU.get(weather, 1.0))
	_load()
	_compute_line()
	_compute_profile()
	if with_meshes:
		_build_meshes()


# ---------------------------------------------------------------- caminho

func _load() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(def["file"]))
	theme = String(data.get("theme", def.get("theme", "hills")))
	hw = float(data.get("hw", 4.5))
	var raw: Array = data["pts"]
	n = raw.size()
	pts.resize(n)
	for i in n:
		var p: Array = raw[i]
		pts[i] = Vector3(p[0], p[2], p[1])
	length = 0.0
	for i in n:
		length += Vector2(pts[i].x - pts[(i + 1) % n].x, pts[i].z - pts[(i + 1) % n].z).length()
	ds = length / n
	wall_l = _floats(data["wall_l"])
	wall_r = _floats(data["wall_r"])
	emb_l = _floats(data["emb_l"])
	emb_r = _floats(data["emb_r"])
	embh_l = _floats(data["embh_l"])
	embh_r = _floats(data["embh_r"])
	bridge.resize(n)
	var bz: Array = data["bridge"]
	for i in n:
		bridge[i] = int(bz[i])
	_load_pit(data.get("pit", null))
	wall = 0.0
	for i in n:
		wall = maxf(wall, maxf(wall_l[i], wall_r[i]))
	base_y = INF
	var minx := INF
	var maxx := -INF
	var minz := INF
	var maxz := -INF
	for i in n:
		base_y = minf(base_y, pts[i].y)
		minx = minf(minx, pts[i].x)
		maxx = maxf(maxx, pts[i].x)
		minz = minf(minz, pts[i].z)
		maxz = maxf(maxz, pts[i].z)
	base_y -= 0.6
	bounds = Rect2(minx, minz, maxx - minx, maxz - minz)
	tans.resize(n)
	rgts.resize(n)
	grade.resize(n)
	curv.resize(n)
	for i in n:
		var t := pts[(i + 1) % n] - pts[(i - 1 + n) % n]
		grade[i] = t.y / (2.0 * ds)
		t.y = 0.0
		t = t.normalized()
		tans[i] = t
		rgts[i] = Vector3(-t.z, 0.0, t.x)
	for i in n:
		var h0 := _heading(tans[(i - 1 + n) % n])
		var h1 := _heading(tans[(i + 1) % n])
		curv[i] = wrapf(h1 - h0, -PI, PI) / (2.0 * ds)


func _load_pit(pit) -> void:
	## Abre espaço para o pit lane: a barreira daquele lado recua até a borda externa do pit lane e,
	## atrás dos boxes, o terreno fica livre (sem árvores).
	has_pit = pit != null
	if not has_pit:
		return
	pit_side = float(pit["side"])
	pit_s0 = float(pit["s_in"])
	pit_garages = bool(pit["garages"])
	var W: PackedFloat32Array = wall_r if pit_side > 0.0 else wall_l
	var E: PackedFloat32Array = emb_r if pit_side > 0.0 else emb_l
	for i in n:
		var u := pit_u(i * ds)
		if u < PIT_LEN:
			W[i] = maxf(W[i], pit_outer(u) + 0.4)
			if pit_garages and _in_garages(u):
				E[i] = maxf(E[i], 10.5)
	if pit_side > 0.0:
		wall_r = W
		emb_r = E
	else:
		wall_l = W
		emb_l = E


func _floats(a: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(a.size())
	for i in a.size():
		out[i] = NAN if a[i] == null else float(a[i])
	return out


static func _heading(t: Vector3) -> float:
	return atan2(-t.x, -t.z)


func _blur(src: PackedFloat32Array, radius: int, passes: int) -> PackedFloat32Array:
	var a := src.duplicate()
	var w := 1.0 / (2 * radius + 1)
	for p in passes:
		var b := PackedFloat32Array()
		b.resize(n)
		var acc := 0.0
		for k in range(-radius, radius + 1):
			acc += a[(k + n) % n]
		for i in n:
			b[i] = acc * w
			acc += a[(i + radius + 1) % n] - a[(i - radius + n) % n]
		a = b
	return a


# ---------------------------------------------------------------- linha ideal e perfil

func _compute_line() -> void:
	var cs := _blur(curv, 4, 2)
	var raw := PackedFloat32Array()
	raw.resize(n)
	for i in n:
		raw[i] = -clampf(cs[i] * 15.0, -1.0, 1.0)
	var narrow := _blur(raw, 10, 3)
	var wide := _blur(raw, 40, 3)
	var lim := hw - 0.9
	line_off.resize(n)
	for i in n:
		line_off[i] = clampf((1.7 * narrow[i] - 1.0 * wide[i]) * lim, -lim, lim)
	# curvatura da própria linha ideal
	var lp := PackedVector3Array()
	lp.resize(n)
	for i in n:
		lp[i] = pts[i] + rgts[i] * line_off[i]
	var lc := PackedFloat32Array()
	lc.resize(n)
	for i in n:
		var a := lp[(i - 1 + n) % n]
		var b := lp[i]
		var c := lp[(i + 1) % n]
		var h0 := _heading(Vector3(b.x - a.x, 0, b.z - a.z).normalized())
		var h1 := _heading(Vector3(c.x - b.x, 0, c.z - b.z).normalized())
		lc[i] = wrapf(h1 - h0, -PI, PI) / maxf(0.5 * (a.distance_to(b) + b.distance_to(c)), 0.1)
	line_curv = _blur(lc, 3, 2)
	# zonas de zebra: trechos de curva
	kerb_zone.resize(n)
	for i in n:
		kerb_zone[i] = 0
	for i in n:
		if absf(cs[i]) > 0.02:
			for k in range(-12, 13):
				kerb_zone[(i + k + n) % n] = 1


func _compute_profile() -> void:
	var mu := LINE_MU * mu_scale
	speed.resize(n)
	for i in n:
		var c := absf(line_curv[i])
		var den := c - mu * DF_K
		speed[i] = TOP_SPEED if den <= 0.00002 else minf(TOP_SPEED, sqrt(mu * 9.81 / den))
	for rep in 2:
		for j in range(n - 1, -1, -1):
			var nx: float = speed[(j + 1) % n]
			var dec := mu * 0.85 * (9.81 + DF_K * nx * nx) + 0.6 * KART_CDA * nx * nx / KART_MASS
			speed[j] = minf(speed[j], sqrt(nx * nx + 2.0 * dec * ds))
	for rep in 2:
		for j in n:
			var pv: float = speed[(j - 1 + n) % n]
			var trac := mu * 0.55 * (9.81 + DF_K * pv * pv)
			var acc := minf(trac, KART_POWER / (KART_MASS * maxf(pv, 1.0))) - 0.6 * KART_CDA * pv * pv / KART_MASS
			speed[j] = minf(speed[j], sqrt(pv * pv + 2.0 * maxf(acc, 0.05) * ds))


func lap_estimate() -> float:
	var t := 0.0
	for i in n:
		t += ds / maxf(speed[i], 1.0)
	return t


# ---------------------------------------------------------------- consultas

func locate(p: Vector3, hint: int) -> int:
	var best := 0
	var best_d := INF
	if hint < 0:
		for i in n:
			var dd := Vector2(p.x - pts[i].x, p.z - pts[i].z).length_squared() + absf(p.y - pts[i].y) * 4.0
			if dd < best_d:
				best_d = dd
				best = i
		return best
	for k in range(-24, 25):
		var i := (hint + k + n) % n
		var dd := Vector2(p.x - pts[i].x, p.z - pts[i].z).length_squared()
		if dd < best_d:
			best_d = dd
			best = i
	return best


func query(p: Vector3, hint: int) -> Dictionary:
	var i := locate(p, hint)
	var a := pts[i]
	var rel := Vector3(p.x - a.x, 0.0, p.z - a.z)
	var along := rel.dot(tans[i])
	var j := (i + 1) % n if along >= 0.0 else (i - 1 + n) % n
	var f := clampf(absf(along) / ds, 0.0, 1.0)
	return {
		"i": i,
		"s": fposmod(i * ds + along, length),
		"d": rel.dot(rgts[i]),
		"y": lerpf(a.y, pts[j].y, f),
	}


func wall_at(i: int, d: float) -> float:
	## Distância da barreira do lado em que está o deslocamento d.
	return wall_r[i] if d >= 0.0 else wall_l[i]


func idx_at(s: float) -> int:
	return int(fposmod(s, length) / ds) % n


func speed_at(s: float) -> float:
	var x := fposmod(s, length) / ds
	var i := int(x) % n
	return lerpf(speed[i], speed[(i + 1) % n], x - floorf(x))


func line_offset_at(s: float) -> float:
	var x := fposmod(s, length) / ds
	var i := int(x) % n
	return lerpf(line_off[i], line_off[(i + 1) % n], x - floorf(x))


func point_at(s: float, off: float) -> Vector3:
	var x := fposmod(s, length) / ds
	var i := int(x) % n
	var j := (i + 1) % n
	var f := x - floorf(x)
	return pts[i].lerp(pts[j], f) + rgts[i].lerp(rgts[j], f).normalized() * off


func heading_at(s: float) -> float:
	return _heading(tans[idx_at(s)])


# ---------------------------------------------------------------- pit lane

func pit_u(s: float) -> float:
	## Distância percorrida dentro do pit lane desde o início da rampa de entrada (>= PIT_LEN: fora dele).
	return fposmod(s - pit_s0, length)


func pit_open(u: float) -> float:
	## 0 nas pontas, 1 no trecho paralelo: as rampas de entrada e saída abrem e fecham suavemente.
	if u >= PIT_LEN:
		return 0.0
	return minf(smoothstep(0.0, PIT_RAMP, u), smoothstep(PIT_LEN, PIT_LEN - PIT_RAMP, u))


func pit_outer(u: float) -> float:
	## Borda externa do pit lane (distância do eixo da pista, sem sinal).
	return lerpf(hw, hw + PIT_WALL_OUT + PIT_W, pit_open(u))


func pit_path(u: float, to_box: float) -> float:
	## Deslocamento lateral (com sinal) da trajetória no pit lane: to_box 0 = faixa de passagem,
	## 1 = faixa dos boxes. Nas rampas a trajetória sai da beira da pista e volta para ela.
	var lane := lerpf(hw + PIT_WALL_OUT + 1.6, hw + PIT_WALL_OUT + PIT_W - 1.5, to_box)
	return pit_side * lerpf(hw - 1.6, lane, pit_open(u))


func pit_divider(u: float) -> bool:
	return has_pit and u >= PIT_RAMP and u <= PIT_LEN - PIT_RAMP


func pit_box_u(box: int, bay := -1) -> float:
	## Centro do box ou, com bay >= 0, ponto de parada daquela vaga.
	var u := PIT_RAMP + PIT_PAD + (box + 0.5) * PIT_BOX
	return u if bay < 0 else u + (bay - (PIT_BAYS - 1) * 0.5) * PIT_BAY_GAP


func on_pit_lane(s: float, d: float) -> bool:
	## true se o ponto (s, d) está sobre o asfalto do pit lane (inclusive rampas).
	if not has_pit:
		return false
	var u := pit_u(s)
	if u >= PIT_LEN:
		return false
	var sd := d * pit_side
	return sd > hw + 0.15 and sd < pit_outer(u) + 0.5


func _in_garages(u: float) -> bool:
	return u >= PIT_RAMP + PIT_PAD and u <= PIT_LEN - PIT_RAMP - PIT_PAD


func _pit_side_near(i: int, side: float, margin: float) -> bool:
	## true se a amostra i, do lado `side`, fica no pit lane ou a menos de `margin` metros dele.
	if not has_pit or side != pit_side:
		return false
	var u := pit_u(i * ds)
	return u < PIT_LEN + margin or u > length - margin


func set_line_visible(v: bool) -> void:
	if line_mesh:
		line_mesh.visible = v


func set_start_lights(count: int) -> void:
	for k in start_light_mats.size():
		var m: StandardMaterial3D = start_light_mats[k]
		m.emission_enabled = k < count
		m.albedo_color = Color(0.9, 0.05, 0.05) if k < count else Color(0.12, 0.02, 0.02)


# ---------------------------------------------------------------- ocupação do terreno

func _build_grid() -> void:
	_grid.clear()
	for i in n:
		var key := Vector2i(floori(pts[i].x / GRID_CELL), floori(pts[i].z / GRID_CELL))
		if not _grid.has(key):
			_grid[key] = PackedInt32Array()
		_grid[key].append(i)


func _free_at(p: Vector3, radius: float, beyond_slope := true) -> bool:
	## true se um objeto de raio `radius` em p fica fora das barreiras (e, se pedido, fora dos taludes)
	## de todos os trechos da pista.
	var reach := radius + wall + (32.0 if beyond_slope else 2.0)
	var cells := ceili(reach / GRID_CELL)
	var c := Vector2i(floori(p.x / GRID_CELL), floori(p.z / GRID_CELL))
	for gx in range(c.x - cells, c.x + cells + 1):
		for gz in range(c.y - cells, c.y + cells + 1):
			var key := Vector2i(gx, gz)
			if not _grid.has(key):
				continue
			for i in _grid[key]:
				var rel := Vector3(p.x - pts[i].x, 0.0, p.z - pts[i].z)
				var dist := rel.length()
				var right := rel.dot(rgts[i]) >= 0.0
				var need := (wall_r[i] if right else wall_l[i]) + radius + 1.0
				if beyond_slope:
					need += emb_r[i] if right else emb_l[i]
				if dist < need:
					return false
	return true


# ---------------------------------------------------------------- materiais e malhas auxiliares

func _mat(color: Color, rough := 0.9, tex: Texture2D = null, uv := Vector3.ONE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if tex:
		m.albedo_texture = tex
		m.uv1_scale = uv
	return m


func _noise_tex(c1: Color, c2: Color, size: int, grain: float, blotch := 0.0) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	noise.seed = randi()
	for y in size:
		for x in size:
			var v := randf() * grain + (1.0 - grain) * 0.5
			if blotch > 0.0:
				v = clampf(v + noise.get_noise_2d(x, y) * blotch, 0.0, 1.0)
			img.set_pixel(x, y, c1.lerp(c2, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _commit(st: SurfaceTool, mat: Material, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _quad(st: SurfaceTool, a0: Vector3, a1: Vector3, b1: Vector3, b0: Vector3, ua: float, ub: float, col := Color.WHITE, nrm := Vector3.ZERO) -> void:
	## Quadrilátero a0-a1 (seção i) até b0-b1 (seção i+1); u percorre a pista, v atravessa.
	var nn := nrm
	if nn == Vector3.ZERO:
		nn = (b0 - a0).cross(a1 - a0).normalized()
		if nn.y < 0.0:
			nn = -nn
	for q in [[a0, Vector2(0, ua)], [a1, Vector2(1, ua)], [b1, Vector2(1, ub)], [a0, Vector2(0, ua)], [b1, Vector2(1, ub)], [b0, Vector2(0, ub)]]:
		st.set_color(col)
		st.set_normal(nn)
		st.set_uv(q[1])
		st.add_vertex(q[0])


func _side_pt(i: int, off: float, y: float) -> Vector3:
	return Vector3(pts[i].x + rgts[i].x * off, pts[i].y + y, pts[i].z + rgts[i].z * off)


func _box(size: Vector3, pos: Vector3, yaw: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = yaw
	add_child(mi)
	return mi


var _white: StandardMaterial3D
func white_mat() -> StandardMaterial3D:
	if _white == null:
		_white = _mat(Color(0.95, 0.95, 0.95), 0.8)
	return _white


# ---------------------------------------------------------------- montagem

func _build_meshes() -> void:
	_build_grid()
	_build_asphalt()
	_build_kerbs()
	_build_runoff()
	_build_pit_lane()
	_build_barriers()
	_build_slopes()
	_build_bridges()
	_build_ground()
	_build_start()
	_build_racing_line()
	_build_boards()
	_build_scenery()
	for k in range(0, n, int(80.0 / ds)):
		var side := -1.0 if (k / int(80.0 / ds)) % 2 == 0 else 1.0
		var off := (wall_r[k] if side > 0.0 else wall_l[k]) + 3.0
		var up := 4.5
		if _pit_side_near(k, side, 10.0):
			off += 9.0      # atrás dos boxes, não dentro deles
			up = 8.0
		tv_points.append(_side_pt(k, side * off, up))


# 1. asfalto -------------------------------------------------------------

var _asphalt: StandardMaterial3D


func _build_asphalt() -> void:
	var col := Color(0.20, 0.20, 0.22) if wet else Color(0.31, 0.31, 0.33)
	if weather == "snow":
		col = Color(0.33, 0.34, 0.37)        # asfalto úmido com sal e neve fina
	var asphalt := _mat(Color.WHITE, 0.35 if wet else 0.88, _noise_tex(col * 0.82, col * 1.15, 256, 0.8, 0.35), Vector3(2, 1, 1))
	asphalt.metallic_specular = 0.7 if wet else 0.3
	_asphalt = asphalt
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var j := (i + 1) % n
		var ua := i * ds / 8.0
		var ub := (i + 1) * ds / 8.0
		_quad(st, _side_pt(i, -hw, 0.0), _side_pt(i, hw, 0.0), _side_pt(j, hw, 0.0), _side_pt(j, -hw, 0.0), ua, ub)
		for sg in [-1.0, 1.0]:
			var o0: float = sg * (hw - 0.35)
			var o1: float = sg * (hw - 0.12)
			_quad(lines, _side_pt(i, o0, 0.012), _side_pt(i, o1, 0.012), _side_pt(j, o1, 0.012), _side_pt(j, o0, 0.012), ua, ub)
	_commit(st, asphalt)
	_commit(lines, _mat(Color(0.92, 0.92, 0.92), 0.7), false)


# 2. zebras --------------------------------------------------------------

func _build_kerbs() -> void:
	## Zebra modular vermelha e branca, com rampa e borda externa elevada (como as peças de referência).
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		for i in n:
			if kerb_zone[i] == 0 or _pit_side_near(i, side, 0.0):
				continue
			var j := (i + 1) % n
			var col := Color(0.82, 0.07, 0.07) if int(i * ds / 1.5) % 2 == 0 else Color(0.95, 0.95, 0.95)
			# a zebra termina antes da barreira (nos grampos fechados a barreira fica colada na pista)
			var W: PackedFloat32Array = wall_r if side > 0.0 else wall_l
			var kw: float = clampf(minf(W[i], W[j]) - 0.15 - hw, 0.2, kerb_w)
			var o0: float = side * hw
			var om: float = side * (hw + kw * 0.75)
			var o1: float = side * (hw + kw)
			_quad(st, _side_pt(i, o0, 0.01), _side_pt(i, om, 0.07), _side_pt(j, om, 0.07), _side_pt(j, o0, 0.01), 0, 1, col)
			_quad(st, _side_pt(i, om, 0.07), _side_pt(i, o1, 0.07), _side_pt(j, o1, 0.07), _side_pt(j, om, 0.07), 0, 1, col)
			_quad(st, _side_pt(i, o1, 0.07), _side_pt(i, o1, -0.04), _side_pt(j, o1, -0.04), _side_pt(j, o1, 0.07), 0, 1, col * 0.8, rgts[i] * side)
	var m := _mat(Color.WHITE, 0.6)
	m.vertex_color_use_as_albedo = true
	_commit(st, m)


# 3. área de escape: grama, brita nas saídas de curva fechada, concreto na rua ---

func _build_runoff() -> void:
	var city := theme == "city"
	var grass_col := _grass_color()
	var grass := _mat(Color.WHITE, 0.95, _noise_tex(grass_col * 0.8, grass_col * 1.12, 128, 0.7, 0.5), Vector3(3, 1, 1))
	if city:
		grass = _mat(Color.WHITE, 0.9, _noise_tex(Color(0.5, 0.5, 0.5), Color(0.62, 0.62, 0.6), 64, 1.0), Vector3(3, 1, 1))
	var gravel := _mat(Color.WHITE, 1.0, _noise_tex(Color(0.55, 0.5, 0.42), Color(0.78, 0.73, 0.62), 128, 1.0), Vector3(6, 1, 1))
	if weather == "snow":
		gravel = _mat(Color.WHITE, 1.0, _noise_tex(Color(0.78, 0.79, 0.82), Color(0.95, 0.96, 0.98), 128, 1.0), Vector3(6, 1, 1))
	var cs := _blur(curv, 6, 2)
	var st_g := SurfaceTool.new()
	st_g.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_b := SurfaceTool.new()
	st_b.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var W: PackedFloat32Array = wall_r if side > 0.0 else wall_l
		for i in n:
			var j := (i + 1) % n
			var outside: bool = kerb_zone[i] == 1 and absf(cs[i]) > 0.03 and signf(cs[i]) == side
			var target := st_b if outside and not city else st_g
			var ua := i * ds / 12.0
			var ub := (i + 1) * ds / 12.0
			_quad(target, _side_pt(i, side * hw, -0.03), _side_pt(i, side * W[i], -0.03), _side_pt(j, side * W[j], -0.03), _side_pt(j, side * hw, -0.03), ua, ub)
	_commit(st_g, grass)
	_commit(st_b, gravel)


func _grass_color() -> Color:
	if weather == "snow":
		return Color(0.88, 0.9, 0.94)        # tudo coberto de neve
	match theme:
		"desert":
			return Color(0.62, 0.55, 0.38)
		"tropical":
			return Color(0.18, 0.42, 0.14)
		"coast":
			return Color(0.36, 0.48, 0.24)
		"forest":
			return Color(0.20, 0.38, 0.15)
	return Color(0.24, 0.44, 0.17)


# 3b. pit lane: asfalto, muro divisório, faixas pintadas, linhas do limite de velocidade e placas

func _build_pit_lane() -> void:
	if not has_pit:
		return
	var sg := pit_side
	var e0 := hw + PIT_WALL_OUT
	var e1 := e0 + PIT_W
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall_st := SurfaceTool.new()
	wall_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var white := Color(0.93, 0.93, 0.93)
	var yellow := Color(0.95, 0.78, 0.1)
	for i in n:
		var u := pit_u(i * ds)
		if u >= PIT_LEN:
			continue
		var j := (i + 1) % n
		var uj := minf(u + ds, PIT_LEN)
		var oi := pit_outer(u)
		var oj := pit_outer(uj)
		# o asfalto vai até a barreira / fachada dos boxes (sem faixa de grama no meio)
		_strip(st, i, j, hw, oi + 0.45, hw, oj + 0.45, 0.0, u / 8.0, uj / 8.0, Color.WHITE)
		# linha branca na borda externa e linha amarela que separa a faixa dos boxes
		if pit_open(u) > 0.05:
			_strip(paint, i, j, oi - 0.3, oi - 0.15, oj - 0.3, oj - 0.15, 0.012, 0, 1, white)
		if pit_divider(u) and int(u / 2.0) % 2 == 0:
			var m := e0 + 3.0
			_strip(paint, i, j, m - 0.07, m + 0.07, m - 0.07, m + 0.07, 0.012, 0, 1, yellow)
		# muro divisório (concreto, 0,9 m), com frente e costas
		if pit_divider(u) and pit_divider(uj):
			var a := hw + PIT_WALL_IN
			var b := e0
			var h := 0.9
			_quad(wall_st, _side_pt(i, sg * a, -0.02), _side_pt(i, sg * a, h), _side_pt(j, sg * a, h), _side_pt(j, sg * a, -0.02), u / 4.0, uj / 4.0, Color.WHITE, -rgts[i] * sg)
			_quad(wall_st, _side_pt(i, sg * b, -0.02), _side_pt(i, sg * b, h), _side_pt(j, sg * b, h), _side_pt(j, sg * b, -0.02), u / 4.0, uj / 4.0, Color.WHITE, rgts[i] * sg)
			_quad(wall_st, _side_pt(i, sg * a, h), _side_pt(i, sg * b, h), _side_pt(j, sg * b, h), _side_pt(j, sg * a, h), 0, 1, Color.WHITE, Vector3.UP)
	# vagas dos boxes pintadas na cor de cada equipe (uma por piloto)
	for b in PIT_BOXES:
		var c: Color = Game.teams[b]["c1"] if b < Game.teams.size() else white
		for bay in PIT_BAYS:
			var ub := pit_box_u(b, bay)
			var k0 := idx_at(pit_s0 + ub - 1.7)
			for k in int(3.4 / ds):
				var i := (k0 + k) % n
				var j := (i + 1) % n
				_strip(paint, i, j, e1 - 3.0, e1 - 0.35, e1 - 3.0, e1 - 0.35, 0.011, 0, 1, c * 0.75)
	# linhas do limite de velocidade
	for ul in [PIT_RAMP, PIT_LEN - PIT_RAMP]:
		var i := idx_at(pit_s0 + ul)
		var j := (i + 1) % n
		_strip(paint, i, j, e0, e1, e0, e1, 0.013, 0, 1, white)
		var lbl := Label3D.new()
		lbl.text = "PIT 50" if ul == PIT_RAMP else "FIM 50"
		lbl.font_size = 96
		lbl.pixel_size = 0.012
		lbl.modulate = white
		lbl.outline_size = 0
		lbl.shaded = true
		var at := _side_pt(idx_at(pit_s0 + ul + (3.0 if ul == PIT_RAMP else -3.0)), sg * (e0 + PIT_W * 0.5), 0.02)
		lbl.position = at
		lbl.rotation = Vector3(-PI * 0.5, _heading(tans[i]), 0.0)
		add_child(lbl)
	_commit(st, _asphalt if _asphalt else _mat(Color(0.31, 0.31, 0.33), 0.88))
	var pm := _mat(Color.WHITE, 0.7)
	pm.vertex_color_use_as_albedo = true
	pm.vertex_color_is_srgb = true
	_commit(paint, pm, false)
	_commit(wall_st, _mat(Color.WHITE, 0.8, _pit_wall_tex()))
	# amortecedor amarelo e preto na ponta do muro, de frente para quem chega
	var nose_i := idx_at(pit_s0 + PIT_RAMP)
	var nose := _box(Vector3(PIT_WALL_OUT - PIT_WALL_IN, 0.9, 1.2), _side_pt(nose_i, sg * (hw + (PIT_WALL_IN + PIT_WALL_OUT) * 0.5), 0.45) - tans[nose_i] * 0.6, _heading(tans[nose_i]), _mat(Color.WHITE, 0.6, _chevron_tex()))
	nose.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# placas de entrada e saída
	for spec in [[6.0, "PIT IN"], [PIT_LEN - 6.0, "PIT OUT"]]:
		var i := idx_at(pit_s0 + float(spec[0]))
		var p := _side_pt(i, sg * (wall_at(i, sg) + 1.0), 0.0)
		_box(Vector3(0.12, 2.6, 0.12), p + Vector3(0, 1.3, 0), _heading(tans[i]), _mat(Color(0.5, 0.5, 0.52), 0.5))
		_box(Vector3(2.0, 0.8, 0.08), p + Vector3(0, 2.7, 0), _heading(tans[i]), _mat(Color(0.05, 0.05, 0.08), 0.6))
		for face in [-1.0, 1.0]:
			var l := Label3D.new()
			l.text = spec[1]
			l.font_size = 72
			l.pixel_size = 0.008
			l.modulate = Color(1.0, 0.85, 0.15)
			l.outline_size = 0
			l.position = p + Vector3(0, 2.7, 0) + tans[i] * 0.05 * face
			l.rotation.y = _heading(tans[i]) + (0.0 if face < 0.0 else PI)
			add_child(l)


func _strip(st: SurfaceTool, i: int, j: int, a_i: float, b_i: float, a_j: float, b_j: float, y: float, u0: float, u1: float, col: Color) -> void:
	## Faixa horizontal do lado do pit lane, de a a b metros do eixo (sem sinal), sempre com a face
	## para cima (do lado esquerdo a ordem dos vértices se inverte).
	var sg := pit_side
	if sg > 0.0:
		_quad(st, _side_pt(i, a_i, y), _side_pt(i, b_i, y), _side_pt(j, b_j, y), _side_pt(j, a_j, y), u0, u1, col)
	else:
		_quad(st, _side_pt(i, -b_i, y), _side_pt(i, -a_i, y), _side_pt(j, -a_j, y), _side_pt(j, -b_j, y), u0, u1, col)


func _pit_wall_tex() -> ImageTexture:
	## Concreto branco com faixas vermelhas (o muro do pit fica bem visível).
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var c := Color(0.9, 0.9, 0.88) * randf_range(0.95, 1.03)
			if (y / 16) % 2 == 0 and x > 8 and x < 24:
				c = Color(0.82, 0.1, 0.1)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _chevron_tex() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, Color(0.95, 0.8, 0.05) if ((x + y) / 8) % 2 == 0 else Color(0.05, 0.05, 0.05))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# 4. barreiras: pneus nas retas, Tecpro vermelha/branca nas curvas, concreto na rua e na ponte

func _build_barriers() -> void:
	var city := theme == "city"
	var mats := {
		"tire": _mat(Color.WHITE, 0.85, _tire_tex()),
		"tecpro": _mat(Color.WHITE, 0.5, _tecpro_tex()),
		"concrete": _mat(Color.WHITE, 0.8, _concrete_tex()),
	}
	var tools := {}
	for k in mats.keys():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[k] = st
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var W: PackedFloat32Array = wall_r if side > 0.0 else wall_l
		var u := 0.0
		for i in n:
			var j := (i + 1) % n
			var kind := "tire"
			if has_pit and pit_garages and side == pit_side and _in_garages(pit_u(i * ds)):
				# a fachada dos boxes faz o papel da barreira
				var w0 := _side_pt(i, side * W[i], -0.05)
				u += Vector2(_side_pt(j, side * W[j], -0.05).x - w0.x, _side_pt(j, side * W[j], -0.05).z - w0.z).length()
				continue
			if bridge[i] == 1 or city:
				kind = "concrete"
			elif kerb_zone[i] == 1:
				kind = "tecpro"
			var a0 := _side_pt(i, side * W[i], -0.05)
			var b0 := _side_pt(j, side * W[j], -0.05)
			var seg := Vector2(b0.x - a0.x, b0.z - a0.z).length()
			var period := 2.4 if kind == "tire" else (3.0 if kind == "tecpro" else 4.0)
			var ua := u / period
			u += seg
			var ub := u / period
			var nrm: Vector3 = -rgts[i] * side
			_quad(tools[kind], a0, a0 + Vector3(0, BARRIER_H + 0.05, 0), b0 + Vector3(0, BARRIER_H + 0.05, 0), b0, ua, ub, Color.WHITE, nrm)
			# face de trás e tampa (a barreira tem espessura)
			var t := 0.45
			var a2 := _side_pt(i, side * (W[i] + t), -0.05)
			var b2 := _side_pt(j, side * (W[j] + t), -0.05)
			_quad(tools[kind], a2, a2 + Vector3(0, BARRIER_H + 0.05, 0), b2 + Vector3(0, BARRIER_H + 0.05, 0), b2, ua, ub, Color.WHITE, rgts[i] * side)
			_quad(cap, a0 + Vector3(0, BARRIER_H + 0.05, 0), a2 + Vector3(0, BARRIER_H + 0.05, 0), b2 + Vector3(0, BARRIER_H + 0.05, 0), b0 + Vector3(0, BARRIER_H + 0.05, 0), 0, 1)
	for k in tools.keys():
		_commit(tools[k], mats[k])
	_commit(cap, _mat(Color(0.12, 0.12, 0.13) if not city else Color(0.6, 0.6, 0.6), 0.8))


func _tire_tex() -> ImageTexture:
	## Pilhas de 5 pneus vistas de frente. x da imagem = altura, y = comprimento.
	var img := Image.create(40, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 40:
			var stack := y / 8
			var band := x % 8
			var col := y % 8
			var c := Color(0.07, 0.07, 0.075) * randf_range(0.85, 1.15)
			if band == 0 or band == 7:
				c = Color(0.02, 0.02, 0.02)
			if col == 0:
				c = Color(0.01, 0.01, 0.01)
			if x >= 32 and band > 0 and band < 7 and col > 0:
				c = Color(0.9, 0.9, 0.9) if stack % 2 == 0 else Color(0.8, 0.12, 0.1)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _tecpro_tex() -> ImageTexture:
	## Blocos Tecpro alternando vermelho e branco, com frisos horizontais.
	var img := Image.create(32, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 32:
			var block := y / 16
			var c := Color(0.82, 0.08, 0.07) if block % 2 == 0 else Color(0.93, 0.93, 0.92)
			if x % 8 == 0 or y % 16 == 0:
				c *= 0.72
			if x < 2 or x > 29:
				c = Color(0.25, 0.25, 0.27)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _concrete_tex() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var c := Color(0.72, 0.72, 0.7) * randf_range(0.93, 1.05)
			if (y / 16) % 2 == 0 and x > 6 and x < 20:
				c = Color(0.8, 0.12, 0.1) if theme == "city" else c
			if y % 16 == 0:
				c *= 0.75
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# 5. taludes: descem das barreiras até o terreno (ou até o meio do caminho para o trecho vizinho)

func _build_slopes() -> void:
	var grass_col := _grass_color()
	var grass := _mat(Color.WHITE, 0.95, _noise_tex(grass_col * 0.78, grass_col * 1.08, 128, 0.7, 0.5), Vector3(4, 1, 1))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side in [-1.0, 1.0]:
		var W: PackedFloat32Array = wall_r if side > 0.0 else wall_l
		var E: PackedFloat32Array = emb_r if side > 0.0 else emb_l
		var EH: PackedFloat32Array = embh_r if side > 0.0 else embh_l
		for i in n:
			var j := (i + 1) % n
			if bridge[i] == 1 or bridge[j] == 1:
				continue
			var ua := i * ds / 12.0
			var ub := (i + 1) * ds / 12.0
			var oi: float = side * (W[i] + 0.45)
			var oj: float = side * (W[j] + 0.45)
			var ei: float = side * (W[i] + 0.45 + E[i])
			var ej: float = side * (W[j] + 0.45 + E[j])
			var hi: float = base_y if is_nan(EH[i]) else minf(EH[i], pts[i].y - 0.03)
			var hj: float = base_y if is_nan(EH[j]) else minf(EH[j], pts[j].y - 0.03)
			var a0 := _side_pt(i, oi, -0.03)
			var b0 := _side_pt(j, oj, -0.03)
			var a1 := _side_pt(i, ei, 0.0)
			var b1 := _side_pt(j, ej, 0.0)
			a1.y = hi
			b1.y = hj
			_quad(st, a0, a1, b1, b0, ua, ub)
			# saia vertical até o terreno, fechando qualquer vão por baixo
			if hi > base_y + 0.01 or hj > base_y + 0.01:
				var a2 := Vector3(a1.x, base_y - 0.1, a1.z)
				var b2 := Vector3(b1.x, base_y - 0.1, b1.z)
				_quad(st, a1, a2, b2, b1, ua, ub, Color.WHITE, rgts[i] * side)
	_commit(st, grass)


# 6. pontes (cruzamentos) --------------------------------------------------

func _build_bridges() -> void:
	var concrete := _mat(Color(0.62, 0.62, 0.6), 0.85, _concrete_tex(), Vector3(1, 1, 1))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for i in n:
		var j := (i + 1) % n
		if bridge[i] == 0 and bridge[j] == 0:
			continue
		any = true
		var l0 := -(wall_l[i] + 0.45)
		var r0 := wall_r[i] + 0.45
		var l1 := -(wall_l[j] + 0.45)
		var r1 := wall_r[j] + 0.45
		# laje: fundo e laterais
		_quad(st, _side_pt(i, l0, -0.9), _side_pt(i, r0, -0.9), _side_pt(j, r1, -0.9), _side_pt(j, l1, -0.9), 0, 1)
		_quad(st, _side_pt(i, l0, -0.05), _side_pt(i, l0, -0.9), _side_pt(j, l1, -0.9), _side_pt(j, l1, -0.05), 0, 1, Color.WHITE, -rgts[i])
		_quad(st, _side_pt(i, r0, -0.05), _side_pt(i, r0, -0.9), _side_pt(j, r1, -0.9), _side_pt(j, r1, -0.05), 0, 1, Color.WHITE, rgts[i])
	if not any:
		return
	_commit(st, concrete)
	# pilares a cada 7 m, fora de qualquer outro trecho de pista
	for i in range(0, n, 7):
		if bridge[i] == 0:
			continue
		for side in [-1.0, 1.0]:
			var off: float = side * ((wall_r[i] if side > 0.0 else wall_l[i]) - 0.3)
			var top := _side_pt(i, off, -0.9)
			if top.y - base_y < 2.5:
				continue
			var foot := Vector3(top.x, base_y, top.z)
			if not _pillar_clear(foot, i):
				continue
			var h := top.y - base_y
			_box(Vector3(0.6, h, 0.6), Vector3(top.x, base_y + h * 0.5, top.z), 0.0, concrete)


func _pillar_clear(p: Vector3, own: int) -> bool:
	## O pilar não pode cair sobre outro trecho (nem sobre suas barreiras).
	for i in n:
		var a := absi(i - own)
		if mini(a, n - a) < 40:
			continue
		var rel := Vector3(p.x - pts[i].x, 0.0, p.z - pts[i].z)
		if rel.length() < wall_at(i, rel.dot(rgts[i])) + 1.2:
			return false
	return true


func _build_ground() -> void:
	var col := _grass_color() * 0.95
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(6000, 6000)
	ground.mesh = pm
	ground.material_override = _mat(Color.WHITE, 1.0, _noise_tex(col * 0.8, col * 1.05, 128, 0.6, 0.5), Vector3(400, 400, 1))
	ground.position = Vector3(bounds.get_center().x, base_y - 0.05, bounds.get_center().y)
	add_child(ground)
	if theme == "coast":
		var sea := MeshInstance3D.new()
		var sp := PlaneMesh.new()
		sp.size = Vector2(6000, 3000)
		sea.mesh = sp
		var sea_mat := _mat(Color(0.10, 0.35, 0.55), 0.12)
		sea_mat.metallic_specular = 0.9
		sea.material_override = sea_mat
		sea.position = Vector3(bounds.get_center().x, base_y + 0.02, bounds.position.y - 1700.0)
		add_child(sea)


# 7. largada, linha ideal e placas -----------------------------------------

func _build_start() -> void:
	var p0 := pts[0]
	var yaw := _heading(tans[0])
	var img := Image.create(16, 2, false, Image.FORMAT_RGB8)
	for x in 16:
		for y in 2:
			img.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color(0.05, 0.05, 0.05))
	var cm := _mat(Color.WHITE, 0.8, ImageTexture.create_from_image(img))
	cm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var line := _box(Vector3(hw * 2.0, 0.02, 1.0), p0 + Vector3(0, 0.005, 0), yaw, cm)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# marcações do grid (caixas em U, como na peça de largada)
	for k in 22:
		var gs := length - GRID_START - k * GRID_STEP
		var lat := -GRID_LATERAL if k % 2 == 0 else GRID_LATERAL
		var gp := point_at(gs + 1.35, lat)
		var gh := heading_at(gs)
		_box(Vector3(1.3, 0.02, 0.12), gp + Vector3(0, 0.01, 0), gh, white_mat())
		for sg in [-1.0, 1.0]:
			var sp := point_at(gs + 0.95, lat + sg * 0.62)
			_box(Vector3(0.1, 0.02, 0.8), sp + Vector3(0, 0.01, 0), gh, white_mat())
	# pórtico treliçado com luzes de largada e painel de LED
	var steel := _mat(Color(0.55, 0.57, 0.6), 0.45)
	steel.metallic = 0.6
	var right := rgts[0]
	# colunas fora da pista; do lado do pit lane, dentro do muro divisório ou depois do pit lane
	var post := {-1.0: -(hw + 1.5), 1.0: hw + 1.5}
	if has_pit and pit_u(0.0) < PIT_LEN:
		var u0 := pit_u(0.0)
		post[pit_side] = pit_side * ((hw + (PIT_WALL_IN + PIT_WALL_OUT) * 0.5) if pit_divider(u0) else pit_outer(u0) + 0.8)
	var span: float = post[1.0] - post[-1.0]
	var mid: float = (post[1.0] + post[-1.0]) * 0.5
	for sgn in [-1.0, 1.0]:
		for e in [-0.25, 0.25]:
			_box(Vector3(0.12, 4.8, 0.12), p0 + right * post[sgn] + tans[0] * e + Vector3(0, 2.4, 0), yaw, steel)
		for h in range(1, 9):
			_box(Vector3(0.06, 0.06, 0.5), p0 + right * post[sgn] + Vector3(0, h * 0.55, 0), yaw, steel)
	for e in [-0.25, 0.25]:
		for hh in [4.1, 4.8]:
			var bar := _box(Vector3(span, 0.1, 0.1), p0 + right * mid + tans[0] * e + Vector3(0, hh, 0), yaw, steel)
			bar.rotation.y = yaw
	var panel_m := _mat(Color(0.03, 0.03, 0.04), 0.4)
	_box(Vector3(4.2, 1.0, 0.25), p0 + Vector3(0, 5.5, 0), yaw, panel_m)
	var led := Label3D.new()
	led.text = "APEX KART GP"
	led.font_size = 72
	led.pixel_size = 0.009
	led.modulate = Color(1.0, 0.65, 0.1)
	led.outline_size = 0
	led.shaded = false
	led.position = p0 + Vector3(0, 5.5, 0) - tans[0] * 0.14
	led.rotation.y = yaw
	add_child(led)
	var led2 := led.duplicate()
	led2.position = p0 + Vector3(0, 5.5, 0) + tans[0] * 0.14
	led2.rotation.y = yaw + PI
	add_child(led2)
	for k in 5:
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.12, 0.02, 0.02)
		lm.emission = Color(1.0, 0.05, 0.02)
		lm.emission_energy_multiplier = 3.0
		lm.emission_enabled = false
		start_light_mats.append(lm)
		var lp := p0 + right * (-1.4 + k * 0.7) + Vector3(0, 4.45, 0) - tans[0] * 0.3
		_box(Vector3(0.45, 0.45, 0.1), lp, yaw, lm)


func _build_racing_line() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var j := (i + 1) % n
		var dv: float = speed[j] - speed[i]
		var col := Color(0.1, 0.9, 0.2, 0.55)
		if dv < -0.05:
			col = Color(0.95, 0.1, 0.1, 0.6)
		elif dv < -0.005 or speed[i] < 18.0 and absf(dv) < 0.02:
			col = Color(0.95, 0.8, 0.1, 0.55)
		var a := pts[i] + rgts[i] * line_off[i] + Vector3(0, 0.02, 0)
		var b := pts[j] + rgts[j] * line_off[j] + Vector3(0, 0.02, 0)
		var w := 0.25
		for p in [a - rgts[i] * w, a + rgts[i] * w, b + rgts[j] * w, a - rgts[i] * w, b + rgts[j] * w, b - rgts[j] * w]:
			st.set_color(col)
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	line_mesh = MeshInstance3D.new()
	line_mesh.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_mesh.material_override = m
	line_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line_mesh)


func _build_boards() -> void:
	## Placas de distância (150, 100, 50 m) antes das freadas fortes, só onde a reta comporta.
	var board := _mat(Color(0.96, 0.96, 0.96), 0.6)
	var post := _mat(Color(0.5, 0.5, 0.52), 0.5)
	var last_b := -1000
	for i in n:
		var pv: float = speed[(i - 1 + n) % n]
		var nx: float = speed[(i + 1) % n]
		if not (pv <= speed[i] + 0.01 and nx < speed[i] - 0.05):
			continue
		var min_ahead := speed[i]
		for k in range(1, 120):
			min_ahead = minf(min_ahead, speed[(i + k) % n])
		if min_ahead > speed[i] * 0.75 or i - last_b < 60:
			continue
		last_b = i
		var side := 1.0 if line_curv[(i + 40) % n] > 0.0 else -1.0
		for dist in [150, 100, 50]:
			var s: float = i * ds - dist
			var ok := true
			for k in range(int(dist / ds) + 1):
				if absf(line_curv[(i - k + n) % n]) > 0.015:
					ok = false
			if not ok:
				continue
			var bi := idx_at(s)
			if _pit_side_near(bi, side, 5.0):
				continue
			var off: float = minf(hw + 2.2, (wall_r[bi] if side > 0.0 else wall_l[bi]) - 0.7)
			var p := _side_pt(bi, side * off, 0.0)
			_box(Vector3(0.08, 1.1, 0.08), p + Vector3(0, 0.55, 0), heading_at(s), post)
			_box(Vector3(0.7, 0.5, 0.05), p + Vector3(0, 1.25, 0), heading_at(s), board)
			var lbl := Label3D.new()
			lbl.text = str(dist)
			lbl.font_size = 64
			lbl.pixel_size = 0.005
			lbl.modulate = Color(0.05, 0.05, 0.1)
			lbl.outline_size = 0
			lbl.position = p + Vector3(0, 1.25, 0) - tans[bi] * 0.04
			lbl.rotation.y = heading_at(s)
			add_child(lbl)


# 8. cenário: boxes, árvores, prédios e colinas (sem arquibancadas) ----

func _build_scenery() -> void:
	if has_pit:
		_build_garages()
	else:
		_build_paddock()
	preload("res://scripts/circuit_details.gd").build(self)
	if theme == "city":
		_scatter_buildings()
		_scatter_trees(180)
	else:
		var trees := 900 if theme == "forest" or theme == "tropical" else 600
		_scatter_trees(trees / 3 if Game.lite_models() else trees)
	_build_hills()


func _stand_fits(i: int, side: float, off: float) -> bool:
	## O prédio (24 m x 11 m) não pode tocar nenhum outro trecho nem suas barreiras.
	for along in [-12.0, -6.0, 0.0, 6.0, 12.0]:
		for depth in [0.0, 5.5, 11.0]:
			var k := (i + int(along / ds) + n) % n
			var p := _side_pt(k, side * (off + depth), 0.0)
			for m in n:
				var a := absi(m - k)
				if mini(a, n - a) < 25:
					continue
				var rel := Vector3(p.x - pts[m].x, 0.0, p.z - pts[m].z)
				if rel.length() < wall_at(m, rel.dot(rgts[m])) + 3.0:
					return false
	return true


func _build_paddock() -> void:
	## Boxes do paddock ao lado da reta (decorativos), onde houver espaço livre.
	var building := _mat(Color(0.9, 0.9, 0.92), 0.6)
	var dark := _mat(Color(0.08, 0.08, 0.1), 0.9)
	var stripe := _mat(Color(0.8, 0.1, 0.1), 0.6)
	var s1 := 20.0
	while s1 < 140.0:
		var i := idx_at(s1)
		var side := 1.0
		var off := wall_r[i] + 2.5
		var p := _side_pt(i, side * (off + 5.0), 0.0)
		if _free_at(p, 7.0, false) and _stand_fits(i, side, off):
			var yaw := _heading(tans[i]) + PI * 0.5
			var hgt := 4.5 + (pts[i].y - base_y)
			_box(Vector3(11.0, hgt, 9.0), Vector3(p.x, base_y + hgt * 0.5, p.z), yaw, building).rotation.y = yaw
			var door := _side_pt(i, side * (off + 0.48), 1.5)
			_box(Vector3(8.0, 3.0, 0.1), door, yaw, dark).rotation.y = yaw
			var band := _side_pt(i, side * (off + 0.45), 3.9)
			_box(Vector3(11.0, 0.4, 0.1), band, yaw, stripe).rotation.y = yaw
		s1 += 11.5


func _build_garages() -> void:
	## Prédio dos boxes atrás do pit lane: uma garagem por equipe (porta aberta, faixa e sigla na cor da
	## equipe) e quatro mecânicos por vaga, que vão até as rodas quando o kart daquela vaga para.
	## pit_crew e pit_crew_home são indexados por vaga: box * PIT_BAYS + vaga.
	var building := _mat(Color(0.9, 0.9, 0.92), 0.6)
	var inside := _mat(Color(0.16, 0.16, 0.18), 0.9)
	var roof := _mat(Color(0.32, 0.34, 0.38), 0.5)
	var sg := pit_side
	pit_crew.clear()
	pit_crew_home.clear()
	for b in PIT_BOXES:
		var team: Dictionary = Game.teams[b % Game.teams.size()]
		var ub := pit_box_u(b)
		var i := idx_at(pit_s0 + ub)
		var W: float = wall_at(i, sg)
		var yaw := _heading(tans[i]) + PI * 0.5
		if pit_garages:
			var depth := 9.0
			var hgt := 4.6 + (pts[i].y - base_y)
			var c := _side_pt(i, sg * (W + depth * 0.5), 0.0)
			# paredes laterais, fundo e laje; o vão da frente fica aberto
			for e in [-1.0, 1.0]:
				var wp: Vector3 = c + tans[i] * e * (PIT_BOX * 0.5 - 0.15)
				_box(Vector3(depth, hgt, 0.3), Vector3(wp.x, base_y + hgt * 0.5, wp.z), yaw, building).rotation.y = yaw + PI * 0.5
			var back := _side_pt(i, sg * (W + depth - 0.15), 0.0)
			_box(Vector3(PIT_BOX, hgt, 0.3), Vector3(back.x, base_y + hgt * 0.5, back.z), yaw, building).rotation.y = yaw
			var floor_p := _side_pt(i, sg * (W + depth * 0.5), 0.0)
			_box(Vector3(PIT_BOX, 0.1, depth), floor_p + Vector3(0, -0.02, 0), yaw, inside).rotation.y = yaw
			var top := _side_pt(i, sg * (W + depth * 0.5), 0.0)
			_box(Vector3(PIT_BOX + 0.2, 0.35, depth + 0.6), Vector3(top.x, pts[i].y + 4.6, top.z), yaw, roof).rotation.y = yaw
			# fachada: faixa na cor da equipe com a sigla, sobre a porta
			var band := _side_pt(i, sg * (W - 0.05), 3.75)
			_box(Vector3(PIT_BOX - 0.3, 0.9, 0.12), band, yaw, _mat(team["c1"], 0.5)).rotation.y = yaw
			var l := Label3D.new()
			l.text = String(team["short"])
			l.font_size = 96
			l.pixel_size = 0.009
			l.modulate = team["c2"]
			l.outline_size = 0
			l.position = band - rgts[i] * sg * 0.08
			l.rotation.y = _heading(tans[i]) + (-PI * 0.5 if sg > 0.0 else PI * 0.5)
			add_child(l)
			# fundo escuro da garagem (dá profundidade ao vão aberto)
			var dark := _side_pt(i, sg * (W + depth - 0.35), 1.6)
			_box(Vector3(PIT_BOX - 0.4, 3.2, 0.05), dark, yaw, inside).rotation.y = yaw
		var mesh := _crew_mesh(team["c1"], team["c2"])
		for bay in PIT_BAYS:
			var crew: Array = []
			var homes: Array = []
			var along := pit_box_u(b, bay) - ub
			for k in 4:
				var fig := MeshInstance3D.new()
				fig.mesh = mesh
				fig.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var home := _side_pt(i, sg * (W + 1.0 + (k % 2) * 1.0), 0.0) + tans[i] * (along - 1.2 + k * 0.8)
				fig.position = home
				fig.rotation.y = _heading(rgts[i] * -sg)
				add_child(fig)
				crew.append(fig)
				homes.append(home)
			pit_crew.append(crew)
			pit_crew_home.append(homes)


static var _crew_cache := {}
func _crew_mesh(body_c: Color, head_c: Color) -> Mesh:
	## Mecânico simples (macacão na cor da equipe e capacete): uma malha só, com cores por vértice.
	var key := str(body_c) + str(head_c)
	if _crew_cache.has(key):
		return _crew_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 1.35
	cap.radial_segments = 8
	cap.rings = 2
	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.3
	head.radial_segments = 8
	head.rings = 4
	for part in [[cap, Transform3D(Basis(), Vector3(0, 0.68, 0)), body_c], [head, Transform3D(Basis(), Vector3(0, 1.5, 0)), head_c]]:
		var arr: Array = (part[0] as PrimitiveMesh).get_mesh_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var xf: Transform3D = part[1]
		for q in idx:
			st.set_color(part[2])
			st.set_normal(nrms[q])
			st.add_vertex(xf * verts[q])
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.7
	st.set_material(m)
	var mesh := st.commit()
	_crew_cache[key] = mesh
	return mesh


func _build_hills() -> void:
	var hill := _mat(_grass_color() * 0.9 if theme != "desert" or weather == "snow" else Color(0.7, 0.6, 0.42), 1.0)
	var c := bounds.get_center()
	var rad := maxf(bounds.size.x, bounds.size.y) * 0.5 + 700.0
	for k in 30:
		var ang := TAU * k / 30.0
		var hp := Vector3(c.x + cos(ang) * rad, base_y - 25.0, c.y + sin(ang) * rad)
		if theme == "coast" and hp.z < bounds.position.y - 100.0:
			continue
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 16
		sm.rings = 8
		mi.mesh = sm
		mi.material_override = hill
		mi.scale = Vector3(randf_range(180, 320), randf_range(50, 140), randf_range(180, 320))
		mi.position = hp
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


# árvores: várias espécies montadas com primitivas, cor variando por instância

func _tree_meshes() -> Dictionary:
	var out := {}
	# pinheiro: quatro cones sobrepostos
	var pine := SurfaceTool.new()
	pine.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 4:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 2.4 - k * 0.45
		cm.height = 3.2 - k * 0.3
		cm.radial_segments = 9
		cm.rings = 1
		pine.append_from(cm, 0, Transform3D(Basis(Vector3.UP, k * 0.7), Vector3(0, 2.6 + k * 1.6, 0)))
	out["pine"] = [_trunk(0.22, 2.4), pine.commit()]
	# folhosa: copa de esferas agrupadas
	var leafy := SurfaceTool.new()
	leafy.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 6:
		var sm := SphereMesh.new()
		var r := randf_range(1.4, 2.1)
		sm.radius = r
		sm.height = r * 1.8
		sm.radial_segments = 10
		sm.rings = 6
		var a := k * TAU / 6.0
		var p := Vector3(cos(a) * 1.3, 4.6 + randf_range(-0.4, 0.8), sin(a) * 1.3) if k > 0 else Vector3(0, 5.6, 0)
		leafy.append_from(sm, 0, Transform3D(Basis(), p))
	out["leafy"] = [_trunk(0.3, 4.2), leafy.commit()]
	# cipreste: copa alta e fina
	var cyp := SurfaceTool.new()
	cyp.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cs := SphereMesh.new()
	cs.radius = 1.1
	cs.height = 7.5
	cs.radial_segments = 10
	cs.rings = 8
	cyp.append_from(cs, 0, Transform3D(Basis(), Vector3(0, 5.0, 0)))
	out["cypress"] = [_trunk(0.18, 1.6), cyp.commit()]
	# palmeira: tronco inclinado e folhas caídas
	var trunk := SurfaceTool.new()
	trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 6:
		var seg := CylinderMesh.new()
		seg.top_radius = 0.17
		seg.bottom_radius = 0.22
		seg.height = 1.25
		seg.radial_segments = 7
		trunk.append_from(seg, 0, Transform3D(Basis(Vector3.FORWARD, k * 0.04), Vector3(k * k * 0.03, 0.6 + k * 1.2, 0)))
	var fronds := SurfaceTool.new()
	fronds.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3(0.75, 7.6, 0.0)
	for k in 9:
		var a := k * TAU / 9.0
		var dir := Vector3(cos(a), 0.0, sin(a))
		var side := Vector3(-dir.z, 0.0, dir.x) * 0.45
		var mid := top + dir * 1.8 + Vector3(0, 0.35, 0)
		var tip := top + dir * 3.4 - Vector3(0, 1.1, 0)
		for tri in [[top, mid - side, mid + side], [mid - side, tip, mid + side]]:
			var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			if nrm.y < 0.0:
				nrm = -nrm
			for v in tri:
				fronds.set_normal(nrm)
				fronds.add_vertex(v)
	out["palm"] = [trunk.commit(), fronds.commit()]
	# arbusto
	var bush := SurfaceTool.new()
	bush.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var sm := SphereMesh.new()
		sm.radius = 0.9
		sm.height = 1.3
		sm.radial_segments = 8
		sm.rings = 5
		bush.append_from(sm, 0, Transform3D(Basis(), Vector3((k - 1) * 0.8, 0.5, randf_range(-0.3, 0.3))))
	out["bush"] = [null, bush.commit()]
	return out


func _trunk(r: float, h: float) -> Mesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.7
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(cm, 0, Transform3D(Basis(), Vector3(0, h * 0.5, 0)))
	return st.commit()


func _species_mix() -> Dictionary:
	match theme:
		"forest":
			return {"pine": 0.55, "leafy": 0.2, "cypress": 0.15, "bush": 0.1}
		"desert":
			return {"palm": 0.45, "bush": 0.55}
		"tropical":
			return {"palm": 0.4, "leafy": 0.45, "bush": 0.15}
		"coast":
			return {"palm": 0.45, "cypress": 0.25, "leafy": 0.15, "bush": 0.15}
		"city":
			return {"leafy": 0.6, "cypress": 0.4}
	return {"leafy": 0.4, "pine": 0.3, "cypress": 0.15, "bush": 0.15}


func _scatter_trees(count: int) -> void:
	var meshes := _tree_meshes()
	var mix := _species_mix()
	var lists := {}
	for k in mix.keys():
		lists[k] = []
	var tries := 0
	var placed := 0
	var margin := 260.0
	while placed < count and tries < count * 8:
		tries += 1
		var p := Vector3(randf_range(bounds.position.x - margin, bounds.end.x + margin), base_y, randf_range(bounds.position.y - margin, bounds.end.y + margin))
		if theme == "coast" and p.z < bounds.position.y - 40.0:
			continue
		if not _free_at(p, 3.0) or not _clear_decoration(p, 5.0):
			continue
		var r := randf()
		var pick: String = mix.keys()[0]
		for k in mix.keys():
			r -= float(mix[k])
			if r <= 0.0:
				pick = k
				break
		lists[pick].append(p)
		placed += 1
	var bark := _mat(Color(0.36, 0.25, 0.16), 1.0)
	var palm_bark := _mat(Color(0.5, 0.42, 0.3), 1.0)
	var leaves := _mat(Color.WHITE, 0.9)
	leaves.vertex_color_use_as_albedo = true
	var base_cols := {"pine": Color(0.12, 0.3, 0.14), "leafy": Color(0.22, 0.45, 0.16), "cypress": Color(0.14, 0.32, 0.16),
		"palm": Color(0.25, 0.5, 0.16), "bush": Color(0.2, 0.4, 0.14)}
	for k in lists.keys():
		var arr: Array = lists[k]
		if arr.is_empty():
			continue
		var parts: Array = meshes[k]
		for part in 2:
			if parts[part] == null:
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = part == 1
			mm.mesh = parts[part]
			mm.instance_count = arr.size()
			seed(hash(k) + arr.size())
			for q in arr.size():
				var sc := randf_range(0.75, 1.35)
				var basis := Basis(Vector3.UP, randf() * TAU).scaled(Vector3(sc, sc * randf_range(0.9, 1.15), sc))
				mm.set_instance_transform(q, Transform3D(basis, arr[q]))
				if part == 1:
					var c: Color = base_cols[k]
					if weather == "snow":
						c = c.lerp(Color(0.92, 0.94, 0.97), 0.55)   # copas com neve
					mm.set_instance_color(q, Color(c.r * randf_range(0.8, 1.2), c.g * randf_range(0.85, 1.15), c.b * randf_range(0.8, 1.2)))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = leaves if part == 1 else (palm_bark if k == "palm" else bark)
			add_child(mmi)
	randomize()


func _scatter_buildings() -> void:
	var cols := [Color(0.85, 0.8, 0.7), Color(0.75, 0.72, 0.68), Color(0.9, 0.88, 0.82), Color(0.7, 0.6, 0.5), Color(0.6, 0.65, 0.72)]
	var mats: Array = []
	for c in cols:
		mats.append(_mat(c, 0.9))
	var placed := 0
	var tries := 0
	while placed < 220 and tries < 4000:
		tries += 1
		var p := Vector3(randf_range(bounds.position.x - 200, bounds.end.x + 200), base_y, randf_range(bounds.position.y - 200, bounds.end.y + 200))
		var size := Vector3(randf_range(12, 26), randf_range(10, 40), randf_range(12, 26))
		if not _free_at(p, size.length() * 0.5) or not _clear_decoration(p, size.length() * 0.5):
			continue
		_box(size, Vector3(p.x, base_y + size.y * 0.5, p.z), randf() * 0.2, mats[placed % mats.size()])
		placed += 1


func _clear_decoration(p: Vector3, radius: float) -> bool:
	for child in get_children():
		if child.has_meta("footprint_radius") and Vector2(p.x-child.position.x,p.z-child.position.z).length() < radius + float(child.get_meta("footprint_radius")):
			return false
	return true
