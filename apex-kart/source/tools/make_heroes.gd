extends SceneTree
## Gera as imagens de destaque dos menus a partir do kart do jogo (com janela):
##   Godot --path .. -s tools/make_heroes.gd
## Cada imagem: kart renderizado com fundo transparente, rastro de movimento (cópias deslocadas e
## esmaecidas) e tom azul prateado. Saída em ui/.

const OUT := "res://ui/"
## [arquivo, tamanho, posição da câmera, alvo, deslocamento do rastro por cópia (m), lados no rastro]
const SHOTS := [
	["hero_top.png", Vector2i(1100, 640), Vector3(0.0, 4.6, 0.01), Vector3(0.0, 0.2, 0.0), Vector3(-0.32, 0, 0), 7],
	["hero_side.png", Vector2i(1280, 520), Vector3(1.9, 0.75, -2.6), Vector3(-0.15, 0.35, 0.0), Vector3(-0.30, 0, 0), 6],
	["hero_front.png", Vector2i(900, 640), Vector3(-1.2, 1.4, -3.0), Vector3(0.1, 0.45, 0.0), Vector3(-0.25, 0, 0), 5],
]

var cam: Camera3D
var kart: Node3D
var vp: SubViewport


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_run.call_deferred()


func _scene(size: Vector2i) -> void:
	if vp:
		vp.queue_free()
	vp = SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.88, 0.95)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 40, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, -140, 0)
	fill.light_energy = 0.5
	vp.add_child(fill)
	kart = load("res://scripts/car.gd").new()
	kart.team = {"c1": Color(0.42, 0.45, 0.52), "livery": "polar"}
	vp.add_child(kart)
	kart.build_model()
	kart.rotation.y = -PI * 0.5        # frente apontando para a direita da imagem
	cam = Camera3D.new()
	cam.fov = 34
	vp.add_child(cam)


func _grab() -> Image:
	for k in 4:
		await process_frame
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


func _run() -> void:
	for s in SHOTS:
		_scene(s[1])
		cam.position = s[2]
		cam.look_at(s[3], Vector3.UP if absf(s[2].normalized().y) < 0.99 else Vector3.FORWARD)
		var frames: Array = []
		for k in range(s[5], -1, -1):
			kart.position = s[4] * float(k)
			kart.steer = 0.0
			frames.append(await _grab())
		var out := _composite(frames)
		_tint(out)
		out.save_png(ProjectSettings.globalize_path(OUT + s[0]))
		print("salvo ", s[0])
	quit()


func _composite(frames: Array) -> Image:
	## Das cópias mais distantes para a mais nítida: cada cópia do rastro entra esmaecida.
	var base: Image = Image.create(frames[0].get_width(), frames[0].get_height(), false, Image.FORMAT_RGBA8)
	var n := frames.size()
	for k in n:
		var f: Image = frames[k]
		var fade := 1.0 if k == n - 1 else 0.10 + 0.32 * float(k) / float(n - 1)
		var d := f.get_data()
		if fade < 1.0:
			for i in range(3, d.size(), 4):
				d[i] = int(d[i] * fade)
			f = Image.create_from_data(f.get_width(), f.get_height(), false, Image.FORMAT_RGBA8, d)
		base.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i.ZERO)
	return base


func _tint(img: Image) -> void:
	## Monocromático azul prateado, como uma ilustração de capa.
	var d := img.get_data()
	var dark := Color(0.06, 0.12, 0.26)
	var light := Color(0.93, 0.96, 1.0)
	for i in range(0, d.size(), 4):
		if d[i + 3] == 0:
			continue
		var l := (0.3 * d[i] + 0.59 * d[i + 1] + 0.11 * d[i + 2]) / 255.0
		l = clampf((l - 0.04) * 1.35, 0.0, 1.0)
		var c := dark.lerp(light, l)
		d[i] = int(c.r * 255.0)
		d[i + 1] = int(c.g * 255.0)
		d[i + 2] = int(c.b * 255.0)
	img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, d)
