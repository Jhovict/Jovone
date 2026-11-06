extends RefCounted
## Clean three-spoke kart wheel. The original pivot and column axis are retained for the hand rig.
static var cache: Dictionary = {}
const Finish := preload("res://scripts/steering_finish.gdshader")

static func apply(wheel: MeshInstance3D, axis: Vector3, lite: bool) -> void:
	var key := "lite" if lite else "full"
	if cache.has(key):
		wheel.mesh = cache[key]
		wheel.material_override = null
		return
	var x := Vector3.RIGHT
	var up := axis.cross(x).normalized()
	var plane := Basis(x, up, axis)
	var mesh := ArrayMesh.new()
	var grip := TorusMesh.new()
	grip.inner_radius = 0.064
	grip.outer_radius = 0.083
	grip.rings = 64 if lite else 96
	grip.ring_segments = 12 if lite else 20
	var rubber := ShaderMaterial.new()
	rubber.shader = Finish
	rubber.set_shader_parameter("wheel_up", up)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(grip, 0, Transform3D(plane * Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO))
	st.set_material(rubber)
	st.commit(mesh)
	# Flat carbon spokes and centre plate, with a separate machined mounting hub.
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := CylinderMesh.new()
	center.top_radius = 0.023
	center.bottom_radius = 0.023
	center.height = 0.006
	center.radial_segments = 32
	st.append_from(center, 0, Transform3D(plane * Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO))
	for angle in [0.12, PI - 0.12, PI * 1.5]:
		var spoke := BoxMesh.new()
		spoke.size = Vector3(0.059, 0.014, 0.005)
		var turn := Basis(Vector3.BACK, angle)
		st.append_from(spoke, 0, Transform3D(plane * turn, plane * (turn * Vector3(0.041, 0, 0))))
	var carbon := ShaderMaterial.new()
	carbon.shader = Finish
	carbon.set_shader_parameter("finish", 1)
	st.set_material(carbon)
	st.commit(mesh)
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var angle := TAU * i / 6.0
		var bolt := CylinderMesh.new()
		bolt.top_radius = 0.0021
		bolt.bottom_radius = 0.0021
		bolt.height = 0.002
		bolt.radial_segments = 6
		var pos := Vector3(cos(angle) * 0.0165, sin(angle) * 0.0165, 0.004)
		st.append_from(bolt, 0, Transform3D(plane * Basis(Vector3.RIGHT, PI / 2.0), plane * pos))
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.48, 0.51, 0.56)
	metal.metallic = 0.85
	metal.roughness = 0.3
	st.set_material(metal)
	st.commit(mesh)
	cache[key] = mesh
	wheel.mesh = mesh
	wheel.material_override = null
