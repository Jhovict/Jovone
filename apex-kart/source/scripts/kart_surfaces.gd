extends RefCounted
## Shared, smooth rotational surfaces replace scan noise on tyres and helmet shells.
static var cache: Dictionary = {}

static func tyre(width: float, radius: float, segments: int) -> ArrayMesh:
	var key := "tyre_%s_%s_%d" % [width, radius, segments]
	if cache.has(key):
		return cache[key]
	var w := width * 0.5
	var profile: Array[Vector2] = [Vector2(-w * 0.94, radius * 0.54), Vector2(-w, radius * 0.72), Vector2(-w * 0.96, radius * 0.89), Vector2(-w * 0.78, radius * 0.98), Vector2(-w * 0.48, radius), Vector2(w * 0.48, radius), Vector2(w * 0.78, radius * 0.98), Vector2(w * 0.96, radius * 0.89), Vector2(w, radius * 0.72), Vector2(w * 0.94, radius * 0.54)]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in profile.size():
		var tangent := profile[mini(j + 1, profile.size() - 1)] - profile[maxi(0, j - 1)]
		for i in segments + 1:
			var a := TAU * i / segments
			verts.append(Vector3(profile[j].x, profile[j].y * cos(a), profile[j].y * sin(a)))
			normals.append(Vector3(-tangent.y, tangent.x * cos(a), tangent.x * sin(a)).normalized())
			uv.append(Vector2(float(i) / segments, float(j) / (profile.size() - 1)))
			if j < profile.size() - 1 and i < segments:
				var k := j * (segments + 1) + i
				indices.append_array([k, k + segments + 1, k + 1, k + 1, k + segments + 1, k + segments + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	cache[key] = mesh
	return mesh

static func refine_wheel(mi: MeshInstance3D, lite: bool, accent: Color) -> void:
	var bounds := mi.mesh.get_aabb()
	var radius := (bounds.size.y + bounds.size.z) * 0.25
	var width := bounds.size.x
	mi.mesh = tyre(width, radius, 40 if lite else 64)
	var rim := MeshInstance3D.new()
	rim.mesh = rim_mesh(width, radius, lite)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = accent.lerp(Color(0.5, 0.52, 0.55), 0.35)
	metal.metallic = 0.8
	metal.roughness = 0.32
	rim.material_override = metal
	mi.add_child(rim)
	for side in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius * 0.77
		torus.outer_radius = radius * 0.80
		torus.rings = 32 if lite else 48
		torus.ring_segments = 6
		ring.mesh = torus
		ring.rotation.z = PI / 2.0
		ring.position.x = side * width * 0.502
		var ink := StandardMaterial3D.new()
		ink.albedo_color = Color(0.74, 0.74, 0.69)
		ink.roughness = 0.85
		ring.material_override = ink
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.name = "CompoundMark" + str(int(side))
		mi.add_child(ring)

static func helmet(lite: bool) -> ArrayMesh:
	var key := "helmet_lite" if lite else "helmet_full"
	if cache.has(key):
		return cache[key]
	var segments := 40 if lite else 64
	var rings := 20 if lite else 32
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in rings + 1:
		var v := float(j) / rings
		var y := lerpf(-0.080, 0.078, v)
		var radial := sqrt(maxf(0.000001, 1.0 - pow((y - 0.005) / (0.073 if y >= 0.005 else 0.096), 2.0)))
		for i in segments + 1:
			var u := float(i) / segments
			var a := (0.5 - u) * TAU
			var p := Vector3(sin(a) * 0.065 * radial, y, -cos(a) * 0.074 * radial)
			verts.append(p)
			normals.append(Vector3(p.x / (0.065 * 0.065), (p.y - 0.005) / (0.087 * 0.087), p.z / (0.074 * 0.074)).normalized())
			uv.append(Vector2(u, 1.0 - v))
			if j < rings and i < segments:
				var k := j * (segments + 1) + i
				indices.append_array([k, k + 1, k + segments + 1, k + 1, k + segments + 2, k + segments + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	cache[key] = mesh
	return mesh


static func rim_mesh(width: float, radius: float, lite: bool) -> ArrayMesh:
	var key := "rim_%s_%s_%s" % [width, radius, lite]
	if cache.has(key):
		return cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hub := CylinderMesh.new()
	hub.top_radius = radius * 0.17
	hub.bottom_radius = hub.top_radius
	hub.height = width * 0.97
	hub.radial_segments = 16
	st.append_from(hub, 0, Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3.ZERO))
	for side in [-1.0, 1.0]:
		var rim := TorusMesh.new()
		rim.inner_radius = radius * 0.47
		rim.outer_radius = radius * 0.55
		rim.rings = 32 if lite else 48
		rim.ring_segments = 8
		var origin := Vector3(side * width * 0.43, 0, 0)
		st.append_from(rim, 0, Transform3D(Basis(Vector3.FORWARD, PI / 2.0), origin))
		var spoke := BoxMesh.new()
		spoke.size = Vector3(width * 0.09, radius * 0.38, radius * 0.075)
		for i in 6:
			var rot := Basis(Vector3.RIGHT, TAU * i / 6.0)
			st.append_from(spoke, 0, Transform3D(rot, origin + rot * Vector3(0, radius * 0.32, 0)))
	var mesh := st.commit()
	cache[key] = mesh
	return mesh
