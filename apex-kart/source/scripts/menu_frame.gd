extends Control
## Solid surfaces keep all navigation and copy independent from the hero artwork.
const FONT_TITLE := preload("res://fonts/ChakraPetch-BoldItalic.ttf")
const FONT_TEXT := preload("res://fonts/ChakraPetch-SemiBold.ttf")
var mode := "menu"
var title := ""
var hint := ""
var controls := ""
var tip := ""
var hero: Texture2D
var hero_node: Control
var wide := false
var t := 0.0
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _process(delta: float) -> void:
	t += delta
	if mode in ["loading","title"]: queue_redraw()
func set_page(page_title: String, page_hint: String, hero_tex: Texture2D = null, is_wide := false) -> void:
	mode = "menu"
	title = page_title
	hint = page_hint
	hero = hero_tex
	wide = is_wide
	queue_redraw()
func set_hint(text: String) -> void:
	hint = text
	queue_redraw()
func top_h() -> float: return 94.0
func bottom_h() -> float: return 34.0
func hint_y() -> float: return size.y-100.0
func content_rect(is_wide: bool) -> Rect2:
	return Rect2(48,126,size.x*(.92 if is_wide else .48)-48,size.y-238)
func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b121e"))
	draw_rect(Rect2(0,0,w,94),Color("101b2b"))
	draw_line(Vector2(48,94),Vector2(w-48,94),Color("304257"),1)
	draw_rect(Rect2(48,94,64,3),Color("f06047"))
	if mode == "title":
		_text(Vector2(48,58),"APEX / MOTORSPORT",18,Color("67e0e8"))
		_text(Vector2(48,210),"APEX KART",72,Color.WHITE,true)
		_text(Vector2(52,256),"GRAND PRIX",28,Color("67e0e8"))
		_text(Vector2(52,310),"SUA EQUIPE. SUA TRAJETÓRIA.",18,Color("b4c3d6"))
		_draw_hero(Rect2(w*.40,140,w*.56,h-245))
		_card(Rect2(48,h-155,480,64),Color("22384d"))
		_text(Vector2(70,h-115),"ENTER / START / TOQUE PARA COMEÇAR",19,Color.WHITE)
	elif mode == "loading":
		_text(Vector2(48,59),"PREPARANDO A PISTA",28,Color.WHITE,true)
		_draw_hero(Rect2(w*.2,110,w*.6,h-340))
		_text(Vector2(48,h-190),"DICA DE PILOTAGEM",16,Color("67e0e8"))
		_wrapped(Rect2(48,h-166,w-96,112),tip,22,Color.WHITE)
		draw_rect(Rect2(48,h-34,w-96,3),Color("263b51"))
		draw_rect(Rect2(48+(w-216)*(.5+.5*sin(t*2)),h-34,120,3),Color("67e0e8"))
	else:
		_text(Vector2(48,36),"APEX KART / GRAND PRIX",14,Color("67e0e8"))
		_text(Vector2(48,75),title.to_upper(),32,Color.WHITE,true,w-96)
		if not wide:
			_card(Rect2(w*.55,126,w*.41,h-242),Color("111e2f"))
			_draw_hero(Rect2(w*.56,156,w*.39,h-305))
			if hero: _text(Vector2(w*.57,h-145),"KZ / RACE DIVISION",14,Color("7e94ae"))
		draw_rect(Rect2(0,h-100,w,100),Color("101b2b"))
		draw_line(Vector2(48,h-100),Vector2(w-48,h-100),Color("304257"),1)
		_wrapped(Rect2(48,h-86,w-96,52),hint,17,Color("c1cede"))
		_text(Vector2(48,h-16),controls,13,Color("7e94ae"))
func _card(r: Rect2,c: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = c
	style.set_corner_radius_all(12)
	draw_style_box(style,r)
func _draw_hero(r: Rect2) -> void:
	if hero == null: return
	var sz := hero.get_size()
	var scale_factor := minf(r.size.x/sz.x,r.size.y/sz.y)
	sz *= scale_factor
	draw_texture_rect(hero,Rect2(r.position+(r.size-sz)*.5,sz),false)
func _text(pos: Vector2,text: String,fs: int,col: Color,heading := false,max_width := -1.0) -> void:
	var font := FONT_TITLE if heading else FONT_TEXT
	if max_width>0:
		while fs>18 and font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>max_width: fs-=1
	draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,max_width,fs,col)
func _wrapped(rect: Rect2,text: String,fs: int,col: Color) -> void:
	draw_multiline_string(FONT_TEXT,rect.position+Vector2(0,fs),text,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x,fs,3,col)
