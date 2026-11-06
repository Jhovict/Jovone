extends RefCounted
## Full-face racing shell in the original head coordinates. Front is -Z.
const DESIGNS := ["Clássico amarelo", "Clássico vermelho", "Clássico azul", "Clássico branco", "Clássico verde", "Clássico laranja", "Brasil", "Argentina", "Itália", "França", "Alemanha", "Japão", "Reino Unido", "Tribal Ônix", "Tribal Chama", "Aurora", "Apex Neon", "Heritage"]
const FILES := ["classic-yellow", "classic-red", "classic-blue", "classic-white", "classic-green", "classic-orange", "brazil", "argentina", "italy", "france", "germany", "japan", "britain", "tribal-onyx", "tribal-flame", "aurora", "neon", "heritage"]
const VISORS := ["Fumê", "Dourada", "Azul iridium", "Prata espelhada"]
const FINISHES := ["Brilhante", "Acetinado", "Fosco"]
const PROFILE := [
	Vector4(-0.079, 0.045, 0.055, 0.007), Vector4(-0.069, 0.053, 0.065, 0.001),
	Vector4(-0.052, 0.058, 0.075, -0.004), Vector4(-0.032, 0.062, 0.078, -0.002),
	Vector4(-0.010, 0.065, 0.076, 0.002), Vector4(0.014, 0.066, 0.073, 0.006),
	Vector4(0.035, 0.063, 0.069, 0.009), Vector4(0.053, 0.054, 0.060, 0.011),
	Vector4(0.067, 0.040, 0.046, 0.012), Vector4(0.077, 0.020, 0.024, 0.012),
	Vector4(0.080, 0.0, 0.0, 0.012)]
const VisorShader := preload("res://scripts/visor_finish.gdshader")
static var cache: Dictionary = {}

static func _profile(y: float) -> Vector3:
	var idx := 0
	while idx < PROFILE.size() - 2 and y > PROFILE[idx + 1].x:
		idx += 1
	var p0: Vector4 = PROFILE[maxi(0, idx - 1)]
	var p1: Vector4 = PROFILE[idx]
	var p2: Vector4 = PROFILE[idx + 1]
	var p3: Vector4 = PROFILE[mini(PROFILE.size() - 1, idx + 2)]
	var t := clampf((y - p1.x) / (p2.x - p1.x), 0, 1)
	var v := 0.5 * ((p1 * 2.0) + (-p0 + p2) * t + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * t * t + (-p0 + p1 * 3.0 - p2 * 3.0 + p3) * t * t * t)
	return Vector3(maxf(0.00003, v.y), maxf(0.00003, v.z), v.w)

static func point(a: float, y: float, offset := 0.0) -> Vector3:
	var p := _profile(y)
	return Vector3(sin(a) * (p.x + offset), y, p.z - cos(a) * (p.y + offset))

static func normal_at(a: float, y: float) -> Vector3:
	var across := point(a + 0.001, y) - point(a - 0.001, y)
	var vertical := point(a, minf(0.07999, y + 0.0001)) - point(a, maxf(-0.079, y - 0.0001))
	return vertical.cross(across).normalized()

static func _array_mesh(verts: PackedVector3Array, normals: PackedVector3Array, uv: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

static func visor_y(a: float, t: float) -> float:
	return lerpf(-0.013 + 0.006 * pow(absf(a) / 1.12, 3.0), 0.030 + 0.003 * cos(a), t)

static func shell(lite: bool) -> ArrayMesh:
	var key := "shell_lite" if lite else "shell_full"
	if cache.has(key): return cache[key]
	var cols := 64 if lite else 96
	var rows := 40 if lite else 64
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var ix := PackedInt32Array()
	for j in rows + 1:
		var t := float(j) / rows
		var y := lerpf(-0.079, 0.080, t)
		for i in cols + 1:
			var u := float(i) / cols
			var a := -PI + u * TAU
			v.append(point(a, y))
			n.append(normal_at(a, y))
			uv.append(Vector2(1.0 - u, 1.0 - t))
			if j < rows and i < cols:
				var am := a + PI / cols
				var ym := y + 0.159 / (2.0 * rows)
				# Real eye opening, covered by a separate curved visor and seal.
				if absf(am) < 1.04 and ym > visor_y(am, 0) + 0.002 and ym < visor_y(am, 1) - 0.002:
					continue
				var k := j * (cols + 1) + i
				ix.append_array([k, k + 1, k + cols + 1, k + 1, k + cols + 2, k + cols + 1])
	var mesh := _array_mesh(v, n, uv, ix)
	cache[key] = mesh
	return mesh

static func panel(a0: float, a1: float, y0: float, y1: float, offset: float, visor := false) -> ArrayMesh:
	var cols := 48 if visor else 12
	var rows := 12 if visor else 3
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var ix := PackedInt32Array()
	for j in rows + 1:
		var t := float(j) / rows
		for i in cols + 1:
			var u := float(i) / cols
			var a := lerpf(a0, a1, u)
			var y := visor_y(a, t) if visor else lerpf(y0, y1, t)
			v.append(point(a, y, offset))
			n.append(normal_at(a, y))
			uv.append(Vector2(u, t))
			if j < rows and i < cols:
				var k := j * (cols + 1) + i
				ix.append_array([k, k + 1, k + cols + 1, k + 1, k + cols + 2, k + cols + 1])
	return _array_mesh(v, n, uv, ix)

static func material(c: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func child(parent: Node3D, name_: String, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi

static func _tube(st: SurfaceTool, points: PackedVector3Array, radius: float) -> void:
	for i in points.size() - 1:
		var d := points[i + 1] - points[i]
		if d.length_squared() < 0.0000000001: continue
		var tube := CylinderMesh.new()
		tube.top_radius = radius
		tube.bottom_radius = radius
		tube.height = d.length() + radius * 0.35
		tube.radial_segments = 6
		st.append_from(tube, 0, Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())), (points[i + 1] + points[i]) * 0.5))

static func details() -> Dictionary:
	if cache.has("details"): return cache["details"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for edge in [0.0, 1.0]:
		var line := PackedVector3Array()
		for i in 49:
			var a := lerpf(-1.12, 1.12, float(i) / 48)
			line.append(point(a, visor_y(a, edge), 0.0022))
		_tube(st, line, 0.0012)
	for a in [-1.12, 1.12]:
		var line := PackedVector3Array()
		for i in 12: line.append(point(a, visor_y(a, float(i) / 11), 0.0022))
		_tube(st, line, 0.0012)
	var neck := PackedVector3Array()
	for i in 65: neck.append(point(TAU * i / 64, -0.077, -0.0005))
	_tube(st, neck, 0.0023)
	# Intake recesses on chin and brow; all details follow the shell curvature.
	st.append_from(panel(-0.34, 0.34, -0.057, -0.035, 0.0012), 0, Transform3D.IDENTITY)
	for side in [-1.0, 1.0]:
		st.append_from(panel(side * 0.48 - 0.11, side * 0.48 + 0.11, 0.045, 0.060, 0.0012), 0, Transform3D.IDENTITY)
	var seals := st.commit()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in [-0.053, -0.046, -0.039]:
		st.append_from(panel(-0.32, 0.32, y, y + 0.0018, 0.002), 0, Transform3D.IDENTITY)
	var louvers := st.commit()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [-1.20, 1.20]:
		var norm := normal_at(a, 0.008)
		var disk := CylinderMesh.new()
		disk.top_radius = 0.006
		disk.bottom_radius = 0.006
		disk.height = 0.002
		disk.radial_segments = 24
		st.append_from(disk, 0, Transform3D(Basis(Quaternion(Vector3.UP, norm)), point(a, 0.008, 0.002)))
	var pivots := st.commit()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for a in [-1.20, 1.20]:
		var norm := normal_at(a, 0.008)
		var bolt := CylinderMesh.new()
		bolt.top_radius = 0.0022
		bolt.bottom_radius = 0.0022
		bolt.height = 0.001
		bolt.radial_segments = 6
		st.append_from(bolt, 0, Transform3D(Basis(Quaternion(Vector3.UP, norm)), point(a, 0.008, 0.004)))
	cache["details"] = {"seals": seals, "louvers": louvers, "pivots": pivots, "bolts": st.commit(), "visor": panel(-1.12, 1.12, 0, 0, 0.002, true)}
	return cache["details"]

static func apply(head: MeshInstance3D, lite: bool, team_key: String) -> void:
	head.mesh = shell(lite)
	var paint := material(Color.WHITE, 0.12, 0.24)
	paint.albedo_texture = load("res://models/helmets/teams/" + team_key + ".png")
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.65
	paint.clearcoat_roughness = 0.22
	head.material_override = paint
	var d := details()
	child(head, "SealAndIntakes", d["seals"], material(Color("101318"), 0.0, 0.85))
	child(head, "VentLouvers", d["louvers"], material(Color("39404c"), 0.4, 0.45))
	child(head, "VisorPivots", d["pivots"], material(Color("202630"), 0.4, 0.38))
	child(head, "PivotBolts", d["bolts"], material(Color("929ca8"), 0.8, 0.25))
	var visor := ShaderMaterial.new()
	visor.shader = VisorShader
	child(head, "Visor", d["visor"], visor)

static func customize(head: MeshInstance3D, design: int, visor: int, finish: int) -> void:
	var paint := head.material_override as StandardMaterial3D
	paint.albedo_texture = load("res://models/helmets/" + FILES[clampi(design, 0, FILES.size() - 1)] + ".png")
	paint.albedo_color = Color.WHITE
	set_finish(head, visor, finish)

static func set_finish(head: MeshInstance3D, visor: int, finish: int) -> void:
	var paint := head.material_override as StandardMaterial3D
	paint.roughness = [0.24, 0.45, 0.78][clampi(finish, 0, 2)]
	paint.clearcoat_enabled = finish == 0
	var shader := head.get_node("Visor").material_override as ShaderMaterial
	shader.set_shader_parameter("tint", [Color("18283c"), Color("a67d25"), Color("155eaa"), Color("9eafc4")][clampi(visor, 0, 3)])
