extends RefCounted
## Stable track IDs are filenames, so changing the menu order never moves a trophy.
const TITLES := ["Sol de Ouro", "Asas do Rio", "Coroa dos Pinheiros", "Vela do Atlântico", "Torre da Vitória", "Chama do Dragão", "Folha do Campeão", "Cristal Magiar", "Estrela da Velocidade", "Cume Solar", "Portal do Oriente", "Cetro Imperial", "Coroa Real", "Onda da Riviera", "Esmeralda Tropical", "Laço do Oriente"]
const ACCENTS := ["e5a63d", "59c9db", "439b76", "368ed7", "818bb6", "e45349", "8ac34d", "9c80cf", "e5d278", "ef8645", "c9a073", "418b72", "9c6cc6", "5dd4cf", "27ba82", "db647f"]
static var outlines: Dictionary = {}

static func track_key(track: Dictionary) -> String:
	return String(track["file"]).get_file().get_basename()

static func material(color: Color, metal := 0.0, roughness := 0.35) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = roughness
	return m

static func add_mesh(root: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	root.add_child(mi)
	return mi

static func label(root: Node3D, text: String, pos: Vector3, size: int, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://fonts/ChakraPetch-SemiBold.ttf")
	l.font_size = size
	l.pixel_size = 0.0018
	l.outline_size = 0
	l.modulate = color
	l.position = pos
	root.add_child(l)

static func build(track: Dictionary, idx: int, place: int) -> Node3D:
	var root := Node3D.new()
	var metal_colors := [Color("6c7889"), Color("dfbd68"), Color("cbd8e5"), Color("c99166")]
	var metal := material(metal_colors[clampi(place, 0, 3)], 0.72, 0.28)
	var accent := material(Color(ACCENTS[idx % ACCENTS.size()]) if place > 0 else Color("465165"), 0.3, 0.3)
	var base_mat := material(Color("141b28"), 0.25, 0.3)
	var base := CylinderMesh.new()
	base.top_radius = 0.39
	base.bottom_radius = 0.43
	base.height = 0.16
	base.radial_segments = 8 if idx % 2 == 0 else 48
	add_mesh(root, base, Vector3(0, 0.08, 0), base_mat)
	var trim := CylinderMesh.new()
	trim.top_radius = 0.385
	trim.bottom_radius = 0.385
	trim.height = 0.022
	trim.radial_segments = base.radial_segments
	add_mesh(root, trim, Vector3(0, 0.17, 0), metal)
	# Distinct coloured fins support an upright sculpture of this exact circuit.
	for side in [-1.0, 1.0]:
		var fin := BoxMesh.new()
		fin.size = Vector3(0.035 + (idx % 3) * 0.008, 0.54, 0.065)
		var mi := add_mesh(root, fin, Vector3(side * 0.22, 0.425, -0.08), accent)
		mi.rotation.z = side * (0.16 + (idx % 4) * 0.04)
	var plinth := BoxMesh.new()
	plinth.size = Vector3(0.62, 0.075, 0.20)
	add_mesh(root, plinth, Vector3(0, 0.68, -0.045), metal)
	var circuit := outline(track)
	add_mesh(root, circuit, Vector3(0, 0.715 - circuit.get_aabb().position.y, 0), metal)
	var spine := BoxMesh.new()
	spine.size = Vector3(0.025, 0.5, 0.025)
	add_mesh(root, spine, Vector3(0, 0.42, 0.06), metal)
	var plaque := BoxMesh.new()
	plaque.size = Vector3(0.63, 0.13, 0.018)
	add_mesh(root, plaque, Vector3(0, 0.095, 0.435), metal)
	label(root, track["name"].to_upper(), Vector3(0, 0.12, 0.447), 22, Color("131a25"))
	label(root, ("%dº LUGAR" % place) if place > 0 else "A CONQUISTAR", Vector3(0, 0.066, 0.447), 18, Color("131a25"))
	var badge := CylinderMesh.new()
	badge.top_radius = 0.095
	badge.bottom_radius = 0.095
	badge.height = 0.025
	badge.radial_segments = 48
	var medal := add_mesh(root, badge, Vector3(0, 0.43, 0.09), metal)
	medal.rotation.x = PI / 2.0
	label(root, "%02d" % (idx + 1), Vector3(0, 0.43, 0.109), 48, Color("131a25"))
	return root

static func outline(track: Dictionary) -> ArrayMesh:
	var key := track_key(track)
	if outlines.has(key):
		return outlines[key]
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(track["file"]))
	var points: Array = data["pts"]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		var v := Vector2(float(p[0]), float(p[1]))
		lo = lo.min(v)
		hi = hi.max(v)
	var center := (lo + hi) * 0.5
	var size := maxf((hi - lo).x, (hi - lo).y)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := mini(180, points.size())
	for i in count:
		var pa: Array = points[i * points.size() / count]
		var pb: Array = points[((i + 1) % count) * points.size() / count]
		var a2 := (Vector2(pa[0], pa[1]) - center) * (0.88 / maxf(size, 1.0))
		var b2 := (Vector2(pb[0], pb[1]) - center) * (0.88 / maxf(size, 1.0))
		var a := Vector3(a2.x, -a2.y, 0)
		var b := Vector3(b2.x, -b2.y, 0)
		if a.distance_to(b) < 0.00001:
			continue
		var tube := CylinderMesh.new()
		tube.top_radius = 0.014
		tube.bottom_radius = 0.014
		tube.height = a.distance_to(b) + 0.008
		tube.radial_segments = 8
		st.append_from(tube, 0, Transform3D(Basis(Quaternion(Vector3.UP, (b - a).normalized())), (a + b) * 0.5))
	var mesh := st.commit()
	outlines[key] = mesh
	return mesh
