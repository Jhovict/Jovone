extends SceneTree
## Versão leve dos modelos para celular e navegador (rodar depois de tools/bake_kart.gd):
##   Godot --headless --path . -s tools/bake_lite.gd
## Usa um dos níveis de detalhe que o próprio Godot calcula para cada malha (mesmo formato, menos
## triângulos), compacta os vértices e reduz as texturas. Gera models/lite/.

const OUT := "res://models/lite/"
const SRC_TEX := {
	"color": ["res://models/kart_Color_e4453aa9-b808-4af6-876f-5ee945639d75.jpg", 2048],
	"orm": ["res://models/kart_ORM_e4453aa9-b808-4af6-876f-5ee945639d75.jpg", 1024],
	"normal": ["res://models/kart_NormalGL_e4453aa9-b808-4af6-876f-5ee945639d75.png", 1024],
	"wheels": ["res://models/baked/wheels_color.png", 2048],
}
## Triângulos desejados por peça.
const TARGET := {"body": 90000, "steering": 9000, "wheel": 7000, "legs": 9000, "helmet": 5000, "glove": 1500, "torso": 14000}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for k in SRC_TEX.keys():
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC_TEX[k][0]))
		var sz: int = SRC_TEX[k][1]
		img.resize(sz, sz, Image.INTERPOLATE_LANCZOS)
		img.save_jpg(ProjectSettings.globalize_path(OUT + k + ".jpg"), 0.9) if k != "normal" else img.save_png(ProjectSettings.globalize_path(OUT + k + ".png"))
	# kart: corpo e volante já separados; rodas do arquivo original
	var kart: Node3D = load("res://models/kart.glb").instantiate()
	var scene := Node3D.new()
	scene.name = "kart_lite"
	_add(scene, "body", _reduce(load("res://models/baked/kart_body.res"), TARGET["body"]), Transform3D())
	_add(scene, "steering", _reduce(load("res://models/baked/steering.res"), TARGET["steering"]), Transform3D())
	for w in ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]:
		var mi: MeshInstance3D = kart.get_node(w)
		_add(scene, w, _reduce(mi.mesh, TARGET["wheel"]), mi.transform)
	_save_scene(scene, OUT + "kart_lite.scn")
	# piloto
	var drv: Node3D = load("res://models/driver.glb").instantiate()
	var ds := Node3D.new()
	ds.name = "driver_lite"
	for part in ["legs", "helmet", "glove_l", "glove_r"]:
		var mi: MeshInstance3D = drv.get_node(part)
		var t: int = TARGET["glove"] if part.begins_with("glove") else TARGET[part]
		_add(ds, part, _reduce(mi.mesh, t), mi.transform)
	_save_scene(ds, OUT + "driver_lite.scn")
	ResourceSaver.save(_reduce(load("res://models/baked/torso_rig.res"), TARGET["torso"], true), OUT + "torso_rig.res")
	print("LITE DONE")
	quit()


func _add(parent: Node3D, n: String, mesh: Mesh, xf: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.transform = xf
	parent.add_child(mi)
	mi.owner = parent


func _save_scene(root: Node3D, path: String) -> void:
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, path)


func _reduce(mesh: Mesh, target: int, skinned := false) -> ArrayMesh:
	var arr: Array = mesh.surface_get_arrays(0)
	var I: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var tris := I.size() / 3
	var im := ImporterMesh.new()
	var flags := 0
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, null, "", flags)
	im.generate_lods(25.0, 60.0, [])
	var best := I
	for l in im.get_surface_lod_count(0):
		var li: PackedInt32Array = im.get_surface_lod_indices(0, l)
		if absi(li.size() / 3 - target) < absi(best.size() / 3 - target):
			best = li
	var out := _compact(arr, best, skinned)
	print("  ", tris, " -> ", best.size() / 3, " triângulos")
	var am: ArrayMesh
	if skinned:
		am = ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	else:
		var im2 := ImporterMesh.new()
		im2.add_surface(Mesh.PRIMITIVE_TRIANGLES, out)
		im2.generate_lods(25.0, 60.0, [])
		am = im2.get_mesh()
	return am


func _compact(arr: Array, idx: PackedInt32Array, skinned: bool) -> Array:
	var P: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var N: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var T = arr[Mesh.ARRAY_TEX_UV]
	var B = arr[Mesh.ARRAY_BONES]
	var W = arr[Mesh.ARRAY_WEIGHTS]
	var remap := PackedInt32Array()
	remap.resize(P.size())
	remap.fill(-1)
	var p2 := PackedVector3Array()
	var n2 := PackedVector3Array()
	var t2 := PackedVector2Array()
	var b2 := PackedInt32Array()
	var w2 := PackedFloat32Array()
	var i2 := PackedInt32Array()
	i2.resize(idx.size())
	for k in idx.size():
		var v := idx[k]
		if remap[v] < 0:
			remap[v] = p2.size()
			p2.append(P[v])
			n2.append(N[v])
			if T != null:
				t2.append(T[v])
			if skinned:
				for c in 4:
					b2.append(B[v * 4 + c])
					w2.append(W[v * 4 + c])
		i2[k] = remap[v]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = p2
	out[Mesh.ARRAY_NORMAL] = n2
	if T != null:
		out[Mesh.ARRAY_TEX_UV] = t2
	if skinned:
		out[Mesh.ARRAY_BONES] = b2
		out[Mesh.ARRAY_WEIGHTS] = w2
	out[Mesh.ARRAY_INDEX] = i2
	return out
