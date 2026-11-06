extends RefCounted
const T := preload("res://scripts/trophy_model.gd")
const COLORS := ["d9a135","4bb5cd","379477","428bcf","8295c8","de6144","94bb46","bba2db","e2c343","ed9038","c9ae75","389c7a","ac85c5","51c5c9","33b47d","e6679b"]
const SPONSORS := ["IONIX","ROSSARO","KYNEX","ORBITAL","AUREON","NIVAL","SYLVA","PULSAR"]
static func box(root: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return T.add_mesh(root,mesh,pos,mat)
static func beam(root: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	var mi := T.add_mesh(root,mesh,(a+b)*.5,mat)
	mi.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))
static func text(root: Node3D, words: String, pos: Vector3, scale: float, color := Color.WHITE) -> void:
	var label := Label3D.new()
	label.text = words
	label.font_size = 96
	label.pixel_size = scale
	label.outline_size = 0
	label.modulate = color
	label.position = pos
	root.add_child(label)
static func build(track) -> void:
	var idx := 0
	for i in Game.tracks.size():
		if Game.tracks[i]["file"] == track.def["file"]: idx = i
	var accent := T.material(Color(COLORS[idx]),.18,.45)
	var steel := T.material(Color("495567"),.6,.45)
	var concrete := T.material(Color("d6d7d4"),0,.9)
	var count := 0
	var locations: Array = []
	# Check the full footprint against every nearby track segment and the pit entrance.
	for step in 48:
		if count >= (1 if Game.lite_models() else 2): break
		var s: float = fposmod(25.0 + step * track.length / 48.0, track.length)
		var i: int = track.idx_at(s)
		for side in [-1.0,1.0]:
			if track._pit_side_near(i,side,45.0): continue
			var off: float = track.wall_at(i,side) + (track.emb_r[i] if side>0 else track.emb_l[i]) + 17.0
			var pos: Vector3 = track._side_pt(i,side*off,0)
			if not track._free_at(pos,12.0,true): continue
			var separated := true
			for p in locations:
				if p.distance_to(pos)<65.0: separated=false
			if not separated: continue
			var stand := Node3D.new()
			stand.name = "Grandstand_%d" % count
			track.add_child(stand)
			stand.position = Vector3(pos.x,track.base_y,pos.z)
			stand.rotation.y = atan2(-track.rgts[i].x*side,-track.rgts[i].z*side)
			stand.set_meta("footprint_radius",12.0)
			grandstand(stand,accent,steel,concrete,idx)
			locations.append(pos)
			count+=1
			break
	# Distinct local monument and an event identity board near the start sector.
	for step in 64:
		var i: int = track.idx_at(step*track.length/64.0)
		var side := -1.0 if step%2==0 else 1.0
		if track._pit_side_near(i,side,30.0): continue
		var off: float = track.wall_at(i,side)+(track.emb_r[i] if side>0 else track.emb_l[i])+10.0
		var pos: Vector3 = track._side_pt(i,side*off,0)
		if not track._free_at(pos,7.0,true): continue
		var clear := true
		for p in locations:
			if p.distance_to(pos)<25.0: clear=false
		if not clear: continue
		var root := Node3D.new()
		root.name = "CircuitLandmark"
		track.add_child(root)
		root.position = Vector3(pos.x,track.base_y,pos.z)
		root.rotation.y = atan2(-track.rgts[i].x*side,-track.rgts[i].z*side)
		root.set_meta("footprint_radius",7.0)
		landmark(root,idx,accent,steel,concrete)
		text(root,String(track.def["name"]).to_upper(),Vector3(0,1.05,1.1),.006)
		break
	# Advertising remains behind the barriers and away from garage openings.
	for k in 16:
		var s: float = (k+.3)*track.length/16.0
		var i: int = track.idx_at(s)
		var side := -1.0 if k%2==0 else 1.0
		if track._pit_side_near(i,side,12): continue
		var pos: Vector3 = track._side_pt(i,side*(track.wall_at(i,side)+4.5),0)
		if not track._free_at(pos,2.8,false): continue
		var board := Node3D.new()
		board.name = "SponsorBoard_%d" % k
		track.add_child(board)
		board.position = pos
		board.rotation.y = atan2(-track.rgts[i].x*side,-track.rgts[i].z*side)
		box(board,Vector3(5.2,1.15,.12),Vector3(0,1.65,0),accent)
		for x in [-2.25,2.25]: box(board,Vector3(.1,2.1,.1),Vector3(x,1.05,0),steel)
		text(board,SPONSORS[(k+idx)%8],Vector3(0,1.65,.08),.006)
static func grandstand(root: Node3D, accent: Material, steel: Material, concrete: Material, idx: int) -> void:
	for row in 5:
		box(root,Vector3(18,.5,1.35),Vector3(0,.25+row*.55,2.6-row*1.35),concrete)
		box(root,Vector3(18,.14,.45),Vector3(0,.65+row*.55,2.2-row*1.35),accent)
	for x in [-8.6,8.6]:
		box(root,Vector3(.16,5.0,.16),Vector3(x,2.5,-3.4),steel)
		beam(root,Vector3(x,4.9,-3.4),Vector3(x,4.4,3.4),.07,steel)
	box(root,Vector3(19,.18,8),Vector3(0,4.8,0),accent)
	box(root,Vector3(18.8,.6,.1),Vector3(0,4.5,4),steel)
	text(root,SPONSORS[idx%8]+"  •  ARQUIBANCADA",Vector3(0,4.5,4.07),.012)
	# Instanced spectators: two draw calls, consistent cost on mobile/web.
	var body := CapsuleMesh.new()
	body.radius = .18
	body.height = .70
	body.radial_segments = 8
	body.rings = 3
	var head := SphereMesh.new()
	head.radius = .13
	head.height = .26
	head.radial_segments = 8
	head.rings = 4
	for part in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = body if part==0 else head
		mm.instance_count = 70
		for k in 70:
			var row := k/14
			var col := k%14
			var pos := Vector3(-7.8+col*1.2,.95+row*.55+(0.48 if part==1 else 0),2.15-row*1.35)
			mm.set_instance_transform(k,Transform3D(Basis.IDENTITY,pos))
			mm.set_instance_color(k,[Color("bcc9d5"),Color("e5b37c"),Color("325b85"),Color(COLORS[idx])][(k*7+idx)%4] if part==0 else Color("bc8f72"))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var mat := T.material(Color.WHITE)
		mat.vertex_color_use_as_albedo = true
		mi.material_override = mat
		root.add_child(mi)
static func landmark(root: Node3D, idx: int, accent: Material, steel: Material, concrete: Material) -> void:
	box(root,Vector3(6,1.6,2),Vector3(0,.8,0),steel)
	match idx:
		0,9: # Solar sculpture / mountain summit
			for side in [-1,1]: beam(root,Vector3(side*2,1.6,0),Vector3(0,7.0+idx*.1,0),.25,accent)
			var sun := SphereMesh.new()
			sun.radius = 1.2
			sun.height = 2.4
			T.add_mesh(root,sun,Vector3(0,6.4,0),accent)
		1,3,13: # River wings / harbour sails / Riviera waves
			for k in 3:
				var fin := PrismMesh.new()
				fin.size = Vector3(1.6,3.2+k*.8,.5)
				var mi := T.add_mesh(root,fin,Vector3(-1.7+k*1.7,3.0+k*.4,0),accent)
				mi.rotation.z = (-.35 if idx==1 else .12)*(k-1)
		2,6,11,14: # Wooded parks: sculptural layered tree canopy
			beam(root,Vector3(0,1.6,0),Vector3(0,6.0,0),.28,steel)
			for k in 3:
				var crown := CylinderMesh.new()
				crown.top_radius = .1 if idx!=14 else 1.6-k*.3
				crown.bottom_radius = 2.3-k*.45
				crown.height = 1.9
				crown.radial_segments = 5+idx%4
				T.add_mesh(root,crown,Vector3(0,3.3+k*1.25,0),accent)
		4,7,10: # Urban spires / plateau monument / strait beacon
			for k in 3:
				var h := 3.0 + ((k+idx)%3)*1.6
				box(root,Vector3(1.1,h,1),Vector3((k-1)*1.7,1.6+h*.5,0),accent)
				box(root,Vector3(1.4,.3,1.4),Vector3((k-1)*1.7,1.6+h,0),concrete)
		5,12: # Oriental gate / royal portal
			for side in [-1,1]: beam(root,Vector3(side*2.2,1.6,0),Vector3(side*2.2,6,0),.25,accent)
			box(root,Vector3(5.7,.4,.7),Vector3(0,5.8,0),accent)
			box(root,Vector3(4.8,.23,.45),Vector3(0,4.8,0),concrete)
		8,15: # Oval star / amusement wheel
			beam(root,Vector3(-2,1.6,0),Vector3(0,5,0),.2,steel)
			beam(root,Vector3(2,1.6,0),Vector3(0,5,0),.2,steel)
			var count := 10 if idx==8 else 16
			for k in count:
				var a := TAU*k/count
				var b := TAU*(k+1)/count
				var r := (2.2 if k%2==0 else 1.1) if idx==8 else 2.2
				var r2 := (2.2 if (k+1)%2==0 else 1.1) if idx==8 else 2.2
				var p := Vector3(sin(a)*r,5+cos(a)*r,0)
				var q := Vector3(sin(b)*r2,5+cos(b)*r2,0)
				beam(root,p,q,.11,accent)
				if idx==15:
					beam(root,Vector3(0,5,0),p,.05,steel)
					box(root,Vector3(.5,.55,.6),p,accent)
