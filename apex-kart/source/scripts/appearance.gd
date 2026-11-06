extends RefCounted
const KEYS := ["", "volt", "scarlet", "papaya", "nova", "aureon", "polar", "verde", "magenta"]
const LIVERIES := ["Da equipe", "Volt / Ionix", "Scarlet / Rossaro", "Papaya / Kynex", "Nova / Orbital", "Aureon", "Polar / Nival", "Verde / Sylva", "Magenta / Pulsar"]
const OUTFITS := ["Da equipe", "Grafite", "Branco", "Brasil", "Vermelho", "Azul", "Laranja"]
const COLORS := [Color.WHITE, Color("263140"), Color("e1e5e8"), Color("198b53"), Color("bc243b"), Color("2568c6"), Color("ed731d")]
static func normalized(raw) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	return {"livery": clampi(int(source.get("livery", 0)), 0, 8), "suit": clampi(int(source.get("suit", 0)), 0, 6), "gloves": clampi(int(source.get("gloves", 0)), 0, 6)}
static func apply(car, raw) -> void:
	var data := normalized(raw)
	var key: String = car.team.get("livery", "scarlet") if data["livery"] == 0 else KEYS[data["livery"]]
	for idx in car.visual_parts:
		var part: MeshInstance3D = car.visual_parts[idx]
		if idx in [4, 5, 8, 9, 10, 12, 13, 14, 19]: continue
		part.material_override = car._livery_material(key, String(part.name))
	var suit := ShaderMaterial.new()
	suit.shader = car.SuitPaint
	# The source part names are retained even after skinning/reparenting.
	suit.set_shader_parameter("paint", car._livery_material(key, String(car.visual_parts[4].name)).albedo_texture)
	suit.set_shader_parameter("custom_style", data["suit"] != 0)
	suit.set_shader_parameter("style_color", COLORS[data["suit"]])
	car.visual_parts[4].material_override = suit
	for idx in [16, 17]:
		if data["gloves"] == 0: continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = COLORS[data["gloves"]]
		mat.roughness = 0.83
		car.visual_parts[idx].material_override = mat
