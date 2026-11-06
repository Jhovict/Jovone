extends SceneTree
## Gera o ícone do jogo (icon.png) a partir de uma captura do kart.
func _initialize() -> void:
	var src := Image.load_from_file(OS.get_cmdline_user_args()[0])
	var r := Rect2i(470, 180, 440, 440)
	var img := src.get_region(r)
	img.resize(512, 512, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path("res://icon.png"))
	quit()
