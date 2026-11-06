extends Node3D
## GPU-skinned driver: independent two-bone arm chains keep both gloves on the wheel.
## All coordinates are in the original kart model space, before MODEL_SCALE.
static var mesh_cache: Dictionary = {}
var skeleton: Skeleton3D
var torso: MeshInstance3D
var hands: Array[MeshInstance3D] = []
var hand_rest: Array[Transform3D] = []
var shoulders: Array[Vector3] = []
var elbows: Array[Vector3] = []
var wrists: Array[Vector3] = []
var head: MeshInstance3D
var head_rest := Transform3D.IDENTITY
var neck := Vector3(0, 0.093, 0.205)
var clock := 0.0
var celebration := 0.0
var lean := 0.0
var nod := 0.0
var head_yaw := 0.0
var wrist_error := 0.0

func setup(parts: Dictionary, lite: bool) -> void:
	torso = parts[4]
	head = parts[5]
	head_rest = head.transform
	for idx in [16, 17]:
		var hand: MeshInstance3D = parts[idx]
		hands.append(hand)
		hand_rest.append(hand.transform)
		var side := signf(hand.position.x)
		shoulders.append(Vector3(side * 0.092, 0.082, 0.206))
		elbows.append(Vector3(side * 0.121, -0.018, 0.108))
		wrists.append(hand.position + Vector3(0, -0.005, 0.023))
	skeleton = Skeleton3D.new()
	skeleton.name = "DriverSkeleton"
	add_child(skeleton)
	var origins: Array[Vector3] = [Vector3.ZERO]
	for i in 2:
		origins.append_array([shoulders[i], elbows[i], wrists[i]])
	for i in origins.size():
		skeleton.add_bone("body" if i == 0 else "arm_%d" % i)
		skeleton.set_bone_rest(i, Transform3D(Basis.IDENTITY, origins[i]))
		skeleton.set_bone_pose_position(i, origins[i])
	var key := "lite" if lite else "full"
	if not mesh_cache.has(key):
		mesh_cache[key] = _weighted_mesh(torso)
	torso.mesh = mesh_cache[key]
	torso.owner = null
	torso.reparent(self, false)
	torso.transform = Transform3D.IDENTITY
	torso.skeleton = torso.get_path_to(skeleton)
	torso.skin = skeleton.create_skin_from_rest_transforms()
	torso.custom_aabb = AABB(Vector3(-0.25, -0.15, -0.1), Vector3(0.5, 0.5, 0.5))

func _weighted_mesh(mi: MeshInstance3D) -> ArrayMesh:
	var arr := mi.mesh.surface_get_arrays(0).duplicate(true)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(verts.size() * 4)
	weights.resize(verts.size() * 4)
	for i in verts.size():
		verts[i] = mi.transform * verts[i]
		normals[i] = (mi.basis * normals[i]).normalized()
		var p := verts[i]
		var side := 0 if p.x < 0.0 else 1
		var arm := smoothstep(0.052, 0.078, absf(p.x))
		var front := 1.0 - smoothstep(0.118, 0.190, p.z)
		var upper := arm * front
		var fore := upper * (1.0 - smoothstep(0.078, 0.125, p.z))
		var cuff := fore * (1.0 - smoothstep(0.028, 0.055, p.z))
		bones[i * 4] = 0
		bones[i * 4 + 1] = 1 + side * 3
		bones[i * 4 + 2] = 2 + side * 3
		bones[i * 4 + 3] = 3 + side * 3
		weights[i * 4] = 1.0 - upper
		weights[i * 4 + 1] = upper - fore
		weights[i * 4 + 2] = fore - cuff
		weights[i * 4 + 3] = cuff
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh

func animate(dt: float, steering: Basis, center: Vector3, lateral: float, accel: float, turn: float, speed: float, held: bool) -> void:
	clock += dt
	var k := 1.0 - exp(-dt * 9.0) if dt > 0.0 else 1.0
	lean = lerpf(lean, clampf(lateral * 0.002, -0.045, 0.045), k)
	nod = lerpf(nod, clampf(accel * 0.002, -0.035, 0.035), k)
	head_yaw = lerpf(head_yaw, turn * 0.16 * smoothstep(1.0, 10.0, absf(speed)), k)
	var breath := sin(clock * 2.1) * (0.0006 if held else 0.0003)
	var pivot := Vector3(0, -0.025, 0.21)
	var rot := Basis.from_euler(Vector3(nod, 0, lean))
	var chest := Transform3D(rot, pivot - rot * pivot + Vector3(0, breath, 0))
	skeleton.set_bone_pose_position(0, chest.origin)
	skeleton.set_bone_pose_rotation(0, rot.get_rotation_quaternion())
	wrist_error = 0.0
	for i in 2:
		var hand_pose := Transform3D(steering * hand_rest[i].basis, center + steering * (hand_rest[i].origin - center))
		hands[i].transform = hand_pose
		var target := center + steering * (wrists[i] - center)
		if i == 0 and celebration > 0.0:
			var raised := chest * shoulders[i] + Vector3(-0.035, 0.17, -0.055)
			target = target.lerp(raised, celebration)
			hands[i].position += target - (center + steering * (wrists[i] - center))
			hands[i].basis = hands[i].basis.slerp(rot * Basis(Vector3.RIGHT, -0.8), celebration)
		var shoulder := chest * shoulders[i]
		var upper_len := shoulders[i].distance_to(elbows[i])
		var fore_len := elbows[i].distance_to(wrists[i])
		var ray := target - shoulder
		var dist := clampf(ray.length(), absf(upper_len - fore_len) + 0.0001, upper_len + fore_len - 0.0001)
		var axis := ray.normalized()
		# Keep the natural elbow plane: no flipping at opposite steering locks.
		var pole := chest * elbows[i] - shoulder
		var bend := (pole - axis * pole.dot(axis)).normalized()
		var along := (upper_len * upper_len - fore_len * fore_len + dist * dist) / (2.0 * dist)
		var elbow := shoulder + axis * along + bend * sqrt(maxf(0.0, upper_len * upper_len - along * along))
		var upper_rot := Quaternion((elbows[i] - shoulders[i]).normalized(), (elbow - shoulder).normalized())
		var fore_rot := Quaternion((wrists[i] - elbows[i]).normalized(), (target - elbow).normalized())
		var bone := 1 + i * 3
		skeleton.set_bone_pose_position(bone, shoulder)
		skeleton.set_bone_pose_rotation(bone, upper_rot)
		skeleton.set_bone_pose_position(bone + 1, elbow)
		skeleton.set_bone_pose_rotation(bone + 1, fore_rot)
		skeleton.set_bone_pose_position(bone + 2, target)
		skeleton.set_bone_pose_rotation(bone + 2, steering.get_rotation_quaternion())
		wrist_error = maxf(wrist_error, absf(target.distance_to(elbow) - fore_len))
	var head_rot := rot * Basis(Vector3.UP, head_yaw) * Basis(Vector3.RIGHT, nod * 0.25)
	head.transform = Transform3D(head_rot * head_rest.basis, chest * neck + head_rot * (head_rest.origin - neck))
