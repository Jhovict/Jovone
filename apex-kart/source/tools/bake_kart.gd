extends SceneTree
## Preparação dos modelos (rodar uma vez, sem janela):
##   Godot --headless --path . -s tools/bake_kart.gd
## 1. Separa o volante do corpo do kart (mesmos vértices), para ele girar.
## 2. Tira dos pneus a luz "pintada" na textura: a claridade que varia em volta do eixo vira
##    uniforme (o desenho e as letras ficam), e o pneu girando deixa de parecer ter algo preso.
## 3. Prepara o tronco do piloto com ossos nos braços (ombro e cotovelo) para as mãos seguirem o volante.

const OUT := "res://models/baked/"
const COLOR_SRC := "res://models/kart_Color_e4453aa9-b808-4af6-876f-5ee945639d75.jpg"
## Volante no arquivo do kart (unidades do modelo): centro, eixo da coluna (aponta para o piloto) e limites.
const STEER_C := Vector3(0.0, 0.0975, -0.015)
const STEER_N := Vector3(0.0, 0.435, 0.9)
const STEER_AXIAL := Vector2(-0.032, 0.03)
const STEER_RADIUS := 0.105

const CarScript := preload("res://scripts/car.gd")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var kart: Node3D = load("res://models/kart.glb").instantiate()
	var body: MeshInstance3D = kart.get_node("body")
	_split_steering(body)
	_fix_tyres(kart)
	_rig_torso()
	print("BAKE DONE")
	quit()


# ---------------------------------------------------------------- volante

func _split_steering(body: MeshInstance3D) -> void:
	var mesh: Mesh = body.mesh
	var mat: Material = mesh.surface_get_material(0)
	var arr: Array = mesh.surface_get_arrays(0)
	var P: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var n := STEER_N.normalized()
	var inside := PackedByteArray()
	inside.resize(P.size())
	for v in P.size():
		var rel := P[v] - STEER_C
		var a := rel.dot(n)
		var rho := (rel - n * a).length()
		inside[v] = 1 if a >= STEER_AXIAL.x and a <= STEER_AXIAL.y and rho <= STEER_RADIUS else 0
	var body_idx := PackedInt32Array()
	var steer_idx := PackedInt32Array()
	for t in range(0, I.size(), 3):
		if inside[I[t]] == 1 and inside[I[t + 1]] == 1 and inside[I[t + 2]] == 1:
			steer_idx.append_array([I[t], I[t + 1], I[t + 2]])
		else:
			body_idx.append_array([I[t], I[t + 1], I[t + 2]])
	print("volante: ", steer_idx.size() / 3, " triângulos; corpo: ", body_idx.size() / 3)
	ResourceSaver.save(_lod_mesh(_subset(arr, body_idx), mat), OUT + "kart_body.res")
	ResourceSaver.save(_lod_mesh(_subset(arr, steer_idx), mat), OUT + "steering.res")


func _subset(arr: Array, idx: PackedInt32Array) -> Array:
	## Mantém só os vértices usados, sem alterar posição, normal ou UV.
	var P: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var N: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var T: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var tan = arr[Mesh.ARRAY_TANGENT]
	var remap := PackedInt32Array()
	remap.resize(P.size())
	remap.fill(-1)
	var p2 := PackedVector3Array()
	var n2 := PackedVector3Array()
	var t2 := PackedVector2Array()
	var tg := PackedFloat32Array()
	var i2 := PackedInt32Array()
	i2.resize(idx.size())
	for k in idx.size():
		var v := idx[k]
		if remap[v] < 0:
			remap[v] = p2.size()
			p2.append(P[v])
			n2.append(N[v])
			t2.append(T[v])
			if tan != null:
				for c in 4:
					tg.append(tan[v * 4 + c])
		i2[k] = remap[v]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = p2
	out[Mesh.ARRAY_NORMAL] = n2
	out[Mesh.ARRAY_TEX_UV] = t2
	if tan != null:
		out[Mesh.ARRAY_TANGENT] = tg
	out[Mesh.ARRAY_INDEX] = i2
	return out


func _lod_mesh(arrays: Array, mat: Material) -> ArrayMesh:
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, mat)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


# ---------------------------------------------------------------- pneus

func _fix_tyres(kart: Node3D) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(COLOR_SRC))
	img.convert(Image.FORMAT_RGB8)
	var W := img.get_width()
	var H := img.get_height()
	var visited := PackedByteArray()
	visited.resize(W * H)
	for wname in ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]:
		var mi: MeshInstance3D = kart.get_node(wname)
		var arr: Array = mi.mesh.surface_get_arrays(0)
		var P: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var T: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		# ajuste por anel (raio x posição no eixo): claridade = a + b·cos θ + c·sin θ
		var bins := {}
		for v in P.size():
			var p := P[v]
			var key := _bin(p)
			var th := atan2(p.y, p.z)
			var col := img.get_pixel(clampi(int(T[v].x * W), 0, W - 1), clampi(int(T[v].y * H), 0, H - 1))
			var l := col.get_luminance()
			if not bins.has(key):
				bins[key] = PackedFloat64Array([0, 0, 0, 0, 0, 0, 0, 0, 0])
			var s: PackedFloat64Array = bins[key]
			var c := cos(th)
			var sn := sin(th)
			s[0] += 1.0
			s[1] += c
			s[2] += sn
			s[3] += c * c
			s[4] += sn * sn
			s[5] += c * sn
			s[6] += l
			s[7] += l * c
			s[8] += l * sn
			bins[key] = s
		var fit := {}
		for key in bins.keys():
			fit[key] = _solve(bins[key])
		# aplica a correção pixel a pixel nas ilhas de UV de cada triângulo do pneu
		var fixed := 0
		for t in range(0, I.size(), 3):
			var a := I[t]
			var b := I[t + 1]
			var c := I[t + 2]
			var ua := Vector2(T[a].x * W, T[a].y * H)
			var ub := Vector2(T[b].x * W, T[b].y * H)
			var uc := Vector2(T[c].x * W, T[c].y * H)
			var den := (ub.y - uc.y) * (ua.x - uc.x) + (uc.x - ub.x) * (ua.y - uc.y)
			if absf(den) < 1e-9:
				continue
			var x0 := maxi(0, floori(minf(ua.x, minf(ub.x, uc.x))))
			var x1 := mini(W - 1, ceili(maxf(ua.x, maxf(ub.x, uc.x))))
			var y0 := maxi(0, floori(minf(ua.y, minf(ub.y, uc.y))))
			var y1 := mini(H - 1, ceili(maxf(ua.y, maxf(ub.y, uc.y))))
			for py in range(y0, y1 + 1):
				for px in range(x0, x1 + 1):
					var q := Vector2(px + 0.5, py + 0.5)
					var w1 := ((ub.y - uc.y) * (q.x - uc.x) + (uc.x - ub.x) * (q.y - uc.y)) / den
					var w2 := ((uc.y - ua.y) * (q.x - uc.x) + (ua.x - uc.x) * (q.y - uc.y)) / den
					var w3 := 1.0 - w1 - w2
					if w1 < -0.02 or w2 < -0.02 or w3 < -0.02:
						continue
					var pi := py * W + px
					if visited[pi] == 1:
						continue
					visited[pi] = 1
					var p := P[a] * w1 + P[b] * w2 + P[c] * w3
					var f: Vector3 = fit.get(_bin(p), Vector3.ZERO)
					if f == Vector3.ZERO:
						continue
					var th := atan2(p.y, p.z)
					var local := f.x + f.y * cos(th) + f.z * sin(th)
					if local <= 0.005:
						continue
					var k := clampf(f.x / local, 0.5, 2.0)
					var col := img.get_pixel(px, py)
					img.set_pixel(px, py, Color(minf(col.r * k, 1.0), minf(col.g * k, 1.0), minf(col.b * k, 1.0)))
					fixed += 1
		print(wname, ": ", fixed, " pixels corrigidos")
	img.save_png(ProjectSettings.globalize_path(OUT + "wheels_color.png"))


func _bin(p: Vector3) -> Vector2i:
	return Vector2i(floori(sqrt(p.y * p.y + p.z * p.z) / 0.004), floori(p.x / 0.006))


func _solve(s: PackedFloat64Array) -> Vector3:
	## Mínimos quadrados de l = a + b cos θ + c sin θ; só vale com volta completa bem amostrada.
	if s[0] < 24.0 or absf(s[1]) / s[0] > 0.35 or absf(s[2]) / s[0] > 0.35:
		return Vector3.ZERO
	var m := [[s[0], s[1], s[2]], [s[1], s[3], s[5]], [s[2], s[5], s[4]]]
	var r := [s[6], s[7], s[8]]
	var det := _det(m)
	if absf(det) < 1e-9:
		return Vector3.ZERO
	var out := Vector3.ZERO
	for col in 3:
		var mm := [m[0].duplicate(), m[1].duplicate(), m[2].duplicate()]
		for row in 3:
			mm[row][col] = r[row]
		out[col] = _det(mm) / det
	return out


func _det(m: Array) -> float:
	return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0])


# ---------------------------------------------------------------- tronco com ossos

func _rig_torso() -> void:
	var drv: Node3D = load("res://models/driver.glb").instantiate()
	var mi: MeshInstance3D = drv.get_node("torso")
	var arr: Array = mi.mesh.surface_get_arrays(0)
	var P: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var N: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var nv := P.size()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(nv * 4)
	weights.resize(nv * 4)
	var moved := 0
	for v in nv:
		P[v] += mi.position          # vértices no espaço do piloto
		var q := P[v]
		var sx := 1.0 if q.x >= 0.0 else -1.0
		var ax := q.x * sx
		var fore := 0.0
		var upper := 0.0
		if ax > 0.055:
			fore = clampf((0.11 - q.z) / 0.04, 0.0, 1.0)
			if q.z < 0.11:
				upper = 1.0 - fore
			else:
				upper = clampf((0.165 - q.z) / 0.045, 0.0, 1.0) * clampf((ax - 0.07) / 0.025, 0.0, 1.0)
		var root := 1.0 - fore - upper
		var ub := CarScript.BONE_UPPER_R if sx > 0.0 else CarScript.BONE_UPPER_L
		var fb := CarScript.BONE_FORE_R if sx > 0.0 else CarScript.BONE_FORE_L
		bones[v * 4] = 0
		bones[v * 4 + 1] = ub
		bones[v * 4 + 2] = fb
		bones[v * 4 + 3] = 0
		weights[v * 4] = root
		weights[v * 4 + 1] = upper
		weights[v * 4 + 2] = fore
		weights[v * 4 + 3] = 0.0
		if root < 0.999:
			moved += 1
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = P
	out[Mesh.ARRAY_NORMAL] = N
	out[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
	out[Mesh.ARRAY_BONES] = bones
	out[Mesh.ARRAY_WEIGHTS] = weights
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	print("tronco: ", moved, " vértices nos braços de ", nv)
	ResourceSaver.save(am, OUT + "torso_rig.res")
