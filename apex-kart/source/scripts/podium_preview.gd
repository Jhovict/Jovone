extends SubViewportContainer
const T := preload("res://scripts/trophy_model.gd")
const Pilot := preload("res://scripts/podium_driver.gd")
var pilots: Array = []
func setup(track_idx: int, results: Array, player_look: Dictionary) -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := SubViewport.new()
	sv.own_world_3d = true
	sv.transparent_bg = true
	sv.msaa_3d = Viewport.MSAA_4X
	add_child(sv)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("d3dced")
	e.ambient_light_energy = .7
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.environment = e
	sv.add_child(env)
	for angle in [Vector3(-35,-25,0),Vector3(-20,150,0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = angle
		light.light_energy = 1.2
		sv.add_child(light)
	var stage := Node3D.new()
	sv.add_child(stage)
	var base := BoxMesh.new()
	base.size = Vector3(4.4,.12,2.5)
	T.add_mesh(stage,base,Vector3(0,-.07,0),T.material(Color("1a2333"),.3,.35))
	var wall := BoxMesh.new()
	wall.size = Vector3(4.4,2.9,.10)
	T.add_mesh(stage,wall,Vector3(0,1.35,-.7),T.material(Color("12243c")))
	T.label(stage,"APEX KART GP",Vector3(0,2.55,-.63),100,Color.WHITE)
	T.label(stage,String(Game.tracks[track_idx]["name"]).to_upper(),Vector3(0,2.28,-.63),55,Color("d3b56b"))
	for row in 3:
		for col in 5:
			T.label(stage,["IONIX","ROSSARO","KYNEX","NIVAL","PULSAR"][(row+col)%5],Vector3(-1.65+col*.83,.45+row*.55,-.63),30,Color("6c829f"))
	for i in mini(3,results.size()):
		var entry: Dictionary = results[i]
		if entry.get("status","ok") == "dnf": continue
		var x: float = [0.0,-1.35,1.35][i]
		var height: float = [.55,.35,.23][i]
		var block := BoxMesh.new()
		block.size = Vector3(1.2,height,1.1)
		T.add_mesh(stage,block,Vector3(x,height*.5,.05),T.material([Color("a28340"),Color("788697"),Color("95664b")][i],.5,.3))
		T.label(stage,str(i+1),Vector3(x,height*.5,.615),110,Color.WHITE)
		T.label(stage,String(entry.get("name","Piloto")),Vector3(x,.06,.64),25,Color.WHITE)
		var pilot := Pilot.new()
		stage.add_child(pilot)
		pilot.position = Vector3(x,height,0)
		pilot.rotation.y = PI
		var team_idx := clampi(int(entry.get("team",0)),0,Game.teams.size()-1)
		pilot.setup(Game.teams[team_idx],player_look if entry.get("player",false) else {},Game.tracks[track_idx],track_idx,i+1)
		pilot.elapsed = float(i)*.2
		pilots.append(pilot)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.9
	cam.position = Vector3(3.2,2.8,8)
	sv.add_child(cam)
	cam.look_at(Vector3(0,1.25,0))
