extends Node3D
const H := preload("res://scripts/helmet_model.gd")
const T := preload("res://scripts/trophy_model.gd")
var arms: Array = []
var helmet: MeshInstance3D
var prize: Node3D
var elapsed := 0.0
var rank := 1
var suit: StandardMaterial3D
func segment(a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(radius * 2.0, a.distance_to(b) + radius * 0.6)
	mesh.radial_segments = 20
	mesh.rings = 8
	var mi := T.add_mesh(self, mesh, (a + b) * 0.5, material)
	mi.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	return mi
func setup(team: Dictionary, look: Dictionary, track: Dictionary, track_idx: int, place: int) -> void:
	rank = place
	var appearance := Game.Appearance.normalized(look.get("appearance", {}))
	var color: Color = team.get("c1", Color("b51e35"))
	if appearance["suit"] > 0: color = Game.Appearance.COLORS[appearance["suit"]]
	suit = T.material(color, 0.0, 0.86)
	var dark := T.material(Color("18202c"), 0, 0.9)
	var accent := T.material(team.get("c2", Color.WHITE), 0, 0.7)
	var glove_color: Color = Game.Appearance.COLORS[appearance["gloves"]] if appearance["gloves"] > 0 else Color("e4e7e9")
	var gloves := T.material(glove_color, 0, 0.8)
	# Tailored torso rings, a waist seam, long fitted legs and separate boots.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := [Vector3(0.79, 0.14, 0.10), Vector3(0.88, 0.15, 0.11), Vector3(1.04, 0.17, 0.11), Vector3(1.25, 0.205, 0.12), Vector3(1.33, 0.15, 0.095)]
	for j in rings.size() - 1:
		for k in 32:
			var a := TAU * k / 32.0
			var b := TAU * (k + 1) / 32.0
			var r: Vector3 = rings[j]
			var q: Vector3 = rings[j + 1]
			var vertices := [Vector3(sin(a)*r.y,r.x,cos(a)*r.z),Vector3(sin(b)*r.y,r.x,cos(b)*r.z),Vector3(sin(a)*q.y,q.x,cos(a)*q.z),Vector3(sin(b)*q.y,q.x,cos(b)*q.z)]
			for idx in [0,2,1,1,2,3]: st.add_vertex(vertices[idx])
	st.generate_normals()
	var torso := T.add_mesh(self, st.commit(), Vector3.ZERO, suit)
	(torso.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		segment(Vector3(side*.09,.82,0),Vector3(side*.12,.46,.015),.094,suit)
		segment(Vector3(side*.12,.48,.015),Vector3(side*.14,.14,0),.078,suit)
		segment(Vector3(side*.10,.86,0),Vector3(side*.10,.72,0),.10,suit)
		var boot := SphereMesh.new()
		boot.radius = 0.1
		boot.height = 0.2
		var foot := T.add_mesh(self,boot,Vector3(side*.14,.09,-.07),dark)
		foot.scale = Vector3(.8,.8,1.7)
		segment(Vector3(side*.178,1.23,-.02),Vector3(side*.15,.9,-.03),.014,accent)
		var upper := segment(Vector3(side*.20,1.25,0),Vector3(side*.29,1.02,-.02),.072,suit)
		var lower := segment(Vector3(side*.29,1.02,-.02),Vector3(side*.16,1.12,-.25),.060,suit)
		var glove_mesh := SphereMesh.new()
		glove_mesh.radius = .061
		glove_mesh.height = .14
		var glove := T.add_mesh(self,glove_mesh,Vector3.ZERO,gloves)
		arms.append([upper,lower,glove,side])
	segment(Vector3(0,1.29,0),Vector3(0,1.41,0),.072,dark)
	helmet = MeshInstance3D.new()
	helmet.position.y = 1.49
	helmet.scale = Vector3.ONE * 1.85
	add_child(helmet)
	H.apply(helmet,false,team.get("livery","scarlet"))
	if look.has("helmet"): H.customize(helmet,int(look["helmet"]),int(look.get("helmet_visor",0)),int(look.get("helmet_finish",0)))
	var badge := Label3D.new()
	badge.text = String(team.get("short", "APEX")) + "\nRACING"
	badge.font_size = 48
	badge.pixel_size = .0014
	badge.outline_size = 0
	badge.position = Vector3(0,1.15,-.122)
	badge.rotation.y = PI
	add_child(badge)
	prize = T.build(track,track_idx,place)
	prize.scale = Vector3.ONE * .28
	prize.rotation.y = PI
	add_child(prize)
	pose(0.0)
func move_segment(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	mi.position = (a+b)*.5
	mi.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
	(mi.mesh as CapsuleMesh).height = maxf((mi.mesh as CapsuleMesh).radius*2.0,a.distance_to(b)+.035)
func pose(time: float) -> void:
	# Bring the award from chest height to above the visor; hold before gently lowering.
	var lift := smoothstep(0.7,2.8,time) * (0.88 + 0.12*sin(time*1.1))
	var hand_y := 1.10 + lift * .60
	for arm in arms:
		var side: float = arm[3]
		var shoulder := Vector3(side*.20,1.25,0)
		var elbow := Vector3(side*(.30+.045*lift),1.0+.40*lift,-.10)
		var hand := Vector3(side*.13,hand_y,-.25)
		move_segment(arm[0],shoulder,elbow)
		move_segment(arm[1],elbow,hand)
		arm[2].position = hand
	prize.position = Vector3(0,hand_y-.035,-.27)
	helmet.rotation.y = sin(time*.7+rank)*.10
	rotation.z = sin(time*1.3+rank)*.012
func _process(delta: float) -> void:
	elapsed += delta
	pose(elapsed)
