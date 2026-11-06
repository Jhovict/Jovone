extends SceneTree
## Capa do launcher: reduz uma captura de corrida para 640x360 (JPG).
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	img.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	img.save_jpg(a[1], 0.85)
	quit()
