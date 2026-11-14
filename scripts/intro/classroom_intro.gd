class_name ClassroomIntro
extends Control

## Cena de Prólogo / Sala de Aula e Laboratório de Mendeleev (baseada nos frames do Figma).
##
## Para editar as falas ou adicionar novos diálogos, basta alterar o array `STORY_SCENES` abaixo!

const WORLD_SCENE := "res://scenes/world/world.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

const PIXEL_FONT := preload("res://assets/fonts/PixelifySans-Bold.ttf")
const BG_CLASSROOM_1 := preload("res://assets/sprites/intro/classroom_1.png")
const BG_CLASSROOM_2 := preload("res://assets/sprites/intro/classroom_2.png")
const BG_WIZARD_LAB := preload("res://assets/sprites/intro/wizard_lab.png")
const ICON_LIGHTBULB := preload("res://assets/sprites/intro/icon_lightbulb.svg")
const ICON_SETTINGS := preload("res://assets/sprites/intro/icon_settings.svg")
const ICON_HELP := preload("res://assets/sprites/intro/icon_help.svg")

## Roteiro completo da introdução dividido pelos 3 quadros do Figma.
const STORY_SCENES := [
	{
		"id": "classroom_1",
		"background": BG_CLASSROOM_1,
		"lightbulb_pos": Vector2(523, 78),
		"curiosity_title": "💡 Curiosidade Química: Hidrogênio (H₂) e Água (H₂O)",
		"curiosity_text": (
			"• [b]Hidrogênio (H):[/b] É o primeiro elemento da Tabela Periódica (número atômico 1) e o mais abundante do universo!\n\n" +
			"• [b]A Molécula de Água (H₂O):[/b] Formada pela ligação covalente entre [b]2 átomos de Hidrogênio[/b] e [b]1 átomo de Oxigênio[/b].\n\n" +
			"• [b]Solvente Universal:[/b] Graças à sua polaridade elétrica, a água consegue dissolver sais como o Cloreto de Sódio ([b]NaCl[/b])!"
		),
		"dialogues": [
			{
				"speaker": "Professora:",
				"text": "Atenção, turma! Olhem para o quadro: hoje vamos revisar o Hidrogênio (H₂) e como os elementos se combinam para formar a Água!"
			},
			{
				"speaker": "Professora:",
				"text": "Lembrem-se sempre da proporção: dois átomos de Hidrogênio ligados a um átomo de Oxigênio formam o H₂O, o nosso solvente universal!"
			},
			{
				"speaker": "Hidro:",
				"text": "(Bocejo)... A aula teórica não acaba nunca... Eu queria mesmo era testar essas misturas no laboratório de verdade..."
			}
		]
	},
	{
		"id": "classroom_2",
		"background": BG_CLASSROOM_2,
		"lightbulb_pos": Vector2(1135, 182),
		"curiosity_title": "💡 Curiosidade Química: Reações e Mudança de Estado",
		"curiosity_text": (
			"• [b]Reação Química:[/b] Ocorre quando substâncias reagentes entram em contato e transformam suas ligações, gerando novos produtos, calor ou gases.\n\n" +
			"• [b]Segurança no Laboratório:[/b] Nunca devemos cochilar perto de vidrarias! Alguns reagentes liberam vapores intensos ao entrar em contato com o ar ou catalisadores."
		),
		"dialogues": [
			{
				"speaker": "Hidro:",
				"text": "Zzz... Só vou encostar a cabeça na carteira por um segundinho..."
			},
			{
				"speaker": "Professora:",
				"text": "CUIDADO, HIDRO!! Você esbarrou no frasco de reagente experimental na carteira! Afaste-se dessa fumaça!"
			},
			{
				"speaker": "Hidro:",
				"text": "Cof, cof! Que névoa esverdeada brilhante é essa?! A sala de aula inteira está desaparecendo...!"
			}
		]
	},
	{
		"id": "wizard_lab",
		"background": BG_WIZARD_LAB,
		"lightbulb_pos": Vector2(1066, 98),
		"curiosity_title": "💡 Curiosidade Química: Mendeleev e a Tabela Periódica",
		"curiosity_text": (
			"• [b]Dmitri Mendeleev (1834–1907):[/b] Foi o químico russo que organizou os elementos químicos na [b]Tabela Periódica[/b], prevendo até elementos que ainda não haviam sido descobertos!\n\n" +
			"• [b]Sua Missão no Jogo:[/b] Coletar [b]Hidrogênio (H)[/b] e [b]Oxigênio (O)[/b] pelo mapa e usar a Bancada [b][B][/b] na proporção [b]2:1[/b] para criar Água ([b]H₂O[/b])!"
		),
		"dialogues": [
			{
				"speaker": "Hidro:",
				"text": "Hã?! Onde eu estou?! Que lugar cheio de poções é esse... e por que estou vestida de maga alquimista?!"
			},
			{
				"speaker": "Mendeleev:",
				"text": "Pelos gases nobres! A névoa do paradoxo alquímico trouxe uma jovem estudante do futuro direto para a minha oficina!"
			},
			{
				"speaker": "Mendeleev:",
				"text": "Eu sou Mendeleev, o Arquiteto da Tabela! O tirano Ur-Novem Duo espalhou barreiras de Sal (NaCl) por todo o reino para impedir a ciência de avançar."
			},
			{
				"speaker": "Mendeleev:",
				"text": "Para abrir caminho e voltar para o seu tempo, você precisará explorar o vilarejo, coletar Hidrogênio (H) e Oxigênio (O) e sintetizar Água pura no nosso caldeirão!"
			},
			{
				"speaker": "Hidro:",
				"text": "Dois de Hidrogênio e um de Oxigênio para formar H₂O e dissolver o sal?! Foi exatamente o que a professora acabou de ensinar na sala de aula! Vamos nessa!"
			}
		]
	}
]

const CHAR_REVEAL_INTERVAL := 0.024

var _scene_index: int = 0
var _dialogue_index: int = 0
var _is_typing: bool = false
var _char_timer: float = 0.0
var _full_current_text: String = ""

var _bg_rect: TextureRect
var _lightbulb_btn: TextureButton
var _lightbulb_tween: Tween
var _speaker_label: Label
var _dialogue_label: RichTextLabel
var _next_btn: Button
var _next_btn_label: Label
var _arrow_indicator: Polygon2D
var _curiosity_overlay: ColorRect
var _curiosity_title_label: Label
var _curiosity_body_label: RichTextLabel
var _fade_rect: ColorRect


func _ready() -> void:
	_build_ui()
	_load_scene(0, false)


func _process(delta: float) -> void:
	if _is_typing:
		_char_timer += delta
		var chars_to_add := int(_char_timer / CHAR_REVEAL_INTERVAL)
		if chars_to_add > 0:
			_char_timer = fmod(_char_timer, CHAR_REVEAL_INTERVAL)
			_dialogue_label.visible_characters += chars_to_add
			if _dialogue_label.visible_characters >= _full_current_text.length():
				_finish_typing()


func _unhandled_input(event: InputEvent) -> void:
	if _curiosity_overlay and _curiosity_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_SPACE, KEY_ENTER]:
			_curiosity_overlay.visible = false
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_RIGHT]:
			_on_next_pressed()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 1. Imagem de fundo do quadro atual (1280x720)
	_bg_rect = TextureRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_bg_rect)

	# 2. Ícones do topo direito (como no Figma 2004:25 + botão Pular Intro)
	var skip_btn := Button.new()
	skip_btn.text = "Pular Intro ⏭"
	skip_btn.position = Vector2(930, 32)
	skip_btn.size = Vector2(150, 44)
	skip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.add_theme_font_override("font", PIXEL_FONT)
	skip_btn.add_theme_font_size_override("font_size", 18)
	skip_btn.add_theme_color_override("font_color", Color.WHITE)
	var skip_style := StyleBoxFlat.new()
	skip_style.bg_color = Color(0.1, 0.08, 0.16, 0.82)
	skip_style.border_color = Color(0.95, 0.82, 0.38)
	skip_style.set_border_width_all(2)
	skip_style.set_corner_radius_all(8)
	skip_btn.add_theme_stylebox_override("normal", skip_style)
	var skip_hover := skip_style.duplicate() as StyleBoxFlat
	skip_hover.bg_color = Color(0.24, 0.18, 0.36, 0.92)
	skip_btn.add_theme_stylebox_override("hover", skip_hover)
	skip_btn.pressed.connect(_start_game_world)
	add_child(skip_btn)

	var settings_btn := _create_top_icon(ICON_SETTINGS, Vector2(1098, 28), "Voltar ao Menu Inicial")
	settings_btn.pressed.connect(func() -> void: _transition_to_file(MAIN_MENU_SCENE))
	add_child(settings_btn)

	var help_btn := _create_top_icon(ICON_HELP, Vector2(1178, 28), "Ver Curiosidade Química da Cena")
	help_btn.pressed.connect(_on_lightbulb_pressed)
	add_child(help_btn)

	# 3. Botão da Lâmpada (💡 mdi:lightbulb do Figma)
	_lightbulb_btn = TextureButton.new()
	_lightbulb_btn.texture_normal = ICON_LIGHTBULB
	_lightbulb_btn.ignore_texture_size = true
	_lightbulb_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_lightbulb_btn.size = Vector2(74, 74)
	_lightbulb_btn.tooltip_text = "Clique para ver a Curiosidade Química!"
	_lightbulb_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_lightbulb_btn.pivot_offset = Vector2(37, 37)
	_lightbulb_btn.pressed.connect(_on_lightbulb_pressed)
	add_child(_lightbulb_btn)
	_start_lightbulb_pulse()

	# 4. Caixa de Diálogo estilo Pergaminho e Madeira (fiel ao frame 2011:81 do Figma)
	_build_dialogue_box()

	# 5. Botão "Próximo" (fiel ao Rectangle 1 + texto Próximo do Figma)
	_build_next_button()

	# 6. Modal de Curiosidade Química (ao clicar na lâmpada 💡)
	_build_curiosity_modal()

	# 7. Camada de fade para transições suaves
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)


func _create_top_icon(tex: Texture2D, pos: Vector2, tooltip: String) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = tex
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.position = pos
	btn.size = Vector2(52, 52)
	btn.tooltip_text = tooltip
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_entered.connect(func() -> void: btn.modulate = Color(1.0, 0.9, 0.5))
	btn.mouse_exited.connect(func() -> void: btn.modulate = Color.WHITE)
	return btn


func _build_dialogue_box() -> void:
	# Container principal na parte inferior da tela (inspirado no frame 2011:81)
	var box_container := Control.new()
	box_container.position = Vector2(110, 515)
	box_container.size = Vector2(980, 185)
	add_child(box_container)

	# Moldura externa de madeira escura
	var wood_frame := Panel.new()
	wood_frame.position = Vector2(0, 22)
	wood_frame.size = Vector2(980, 160)
	var wood_style := StyleBoxFlat.new()
	wood_style.bg_color = Color("#8c5838")
	wood_style.border_color = Color("#2b1508")
	wood_style.set_border_width_all(5)
	wood_style.set_corner_radius_all(8)
	wood_frame.add_theme_stylebox_override("panel", wood_style)
	box_container.add_child(wood_frame)

	# Fundo interno de pergaminho claro
	var parchment := Panel.new()
	parchment.position = Vector2(14, 34)
	parchment.size = Vector2(952, 136)
	var parch_style := StyleBoxFlat.new()
	parch_style.bg_color = Color("#e3be91")
	parch_style.border_color = Color("#54311b")
	parch_style.set_border_width_all(4)
	parch_style.set_corner_radius_all(4)
	parchment.add_theme_stylebox_override("panel", parch_style)
	box_container.add_child(parchment)

	# Plaquinha superior com o nome do personagem (ex.: "Professora:", "Hidro:")
	var nameplate := Panel.new()
	nameplate.position = Vector2(36, 0)
	nameplate.size = Vector2(235, 52)
	var name_style := StyleBoxFlat.new()
	name_style.bg_color = Color("#6e4429")
	name_style.border_color = Color("#2b1508")
	name_style.set_border_width_all(4)
	name_style.set_corner_radius_all(6)
	nameplate.add_theme_stylebox_override("panel", name_style)
	box_container.add_child(nameplate)

	_speaker_label = Label.new()
	_speaker_label.position = Vector2(16, 6)
	_speaker_label.size = Vector2(203, 40)
	_speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speaker_label.add_theme_font_override("font", PIXEL_FONT)
	_speaker_label.add_theme_font_size_override("font_size", 26)
	_speaker_label.add_theme_color_override("font_color", Color.WHITE)
	_speaker_label.add_theme_color_override("font_shadow_color", Color(0.12, 0.06, 0.02))
	_speaker_label.add_theme_constant_override("shadow_offset_x", 2)
	_speaker_label.add_theme_constant_override("shadow_offset_y", 2)
	nameplate.add_child(_speaker_label)

	# Texto da fala dentro do pergaminho
	_dialogue_label = RichTextLabel.new()
	_dialogue_label.position = Vector2(40, 56)
	_dialogue_label.size = Vector2(860, 102)
	_dialogue_label.bbcode_enabled = false
	_dialogue_label.scroll_active = false
	_dialogue_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_dialogue_label.add_theme_font_override("normal_font", PIXEL_FONT)
	_dialogue_label.add_theme_font_size_override("normal_font_size", 26)
	_dialogue_label.add_theme_color_override("default_color", Color("#1c1008"))
	box_container.add_child(_dialogue_label)

	# Setinha triangular no canto inferior direito do pergaminho
	_arrow_indicator = Polygon2D.new()
	_arrow_indicator.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(24, 0),
		Vector2(12, 14),
	])
	_arrow_indicator.color = Color("#b8804a")
	_arrow_indicator.position = Vector2(922, 142)
	box_container.add_child(_arrow_indicator)

	# Clique no próprio pergaminho também avança / revela o texto
	parchment.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_next_pressed()
	)


func _build_next_button() -> void:
	# Posição e estilo idênticos ao botão "Próximo" do Figma (border-4 border-black rounded-[10px] bg-white text-[#4520ff])
	_next_btn = Button.new()
	_next_btn.position = Vector2(1032, 548)
	_next_btn.size = Vector2(218, 72)
	_next_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_next_btn.focus_mode = Control.FOCUS_NONE

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color.WHITE
	normal_style.border_color = Color.BLACK
	normal_style.set_border_width_all(4)
	normal_style.set_corner_radius_all(10)
	_next_btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color(0.93, 0.92, 1.0)
	_next_btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.84, 0.82, 1.0)
	_next_btn.add_theme_stylebox_override("pressed", pressed_style)

	_next_btn_label = Label.new()
	_next_btn_label.text = "Próximo"
	_next_btn_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_next_btn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_btn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_next_btn_label.add_theme_font_override("font", PIXEL_FONT)
	_next_btn_label.add_theme_font_size_override("font_size", 38)
	_next_btn_label.add_theme_color_override("font_color", Color("#4520ff"))
	_next_btn.add_child(_next_btn_label)

	_next_btn.pressed.connect(_on_next_pressed)
	add_child(_next_btn)


func _build_curiosity_modal() -> void:
	_curiosity_overlay = ColorRect.new()
	_curiosity_overlay.color = Color(0.04, 0.02, 0.08, 0.78)
	_curiosity_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curiosity_overlay.visible = false
	add_child(_curiosity_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curiosity_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 360)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#e3be91")
	style.border_color = Color("#3b1e0d")
	style.set_border_width_all(6)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	_curiosity_title_label = Label.new()
	_curiosity_title_label.add_theme_font_override("font", PIXEL_FONT)
	_curiosity_title_label.add_theme_font_size_override("font_size", 26)
	_curiosity_title_label.add_theme_color_override("font_color", Color("#4520ff"))
	_curiosity_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_curiosity_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_curiosity_title_label)

	_curiosity_body_label = RichTextLabel.new()
	_curiosity_body_label.bbcode_enabled = true
	_curiosity_body_label.fit_content = true
	_curiosity_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_curiosity_body_label.add_theme_font_size_override("normal_font_size", 19)
	_curiosity_body_label.add_theme_color_override("default_color", Color("#1c1008"))
	vbox.add_child(_curiosity_body_label)

	var close_btn := Button.new()
	close_btn.text = "Entendi!"
	close_btn.custom_minimum_size = Vector2(170, 48)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_btn.add_theme_font_override("font", PIXEL_FONT)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.add_theme_color_override("font_color", Color("#4520ff"))
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color.WHITE
	close_style.border_color = Color.BLACK
	close_style.set_border_width_all(3)
	close_style.set_corner_radius_all(8)
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.pressed.connect(func() -> void: _curiosity_overlay.visible = false)
	vbox.add_child(close_btn)


func _start_lightbulb_pulse() -> void:
	if _lightbulb_tween:
		_lightbulb_tween.kill()
	_lightbulb_tween = create_tween().set_loops()
	_lightbulb_tween.tween_property(_lightbulb_btn, "scale", Vector2(1.12, 1.12), 0.65).set_trans(Tween.TRANS_SINE)
	_lightbulb_tween.tween_property(_lightbulb_btn, "scale", Vector2(1.0, 1.0), 0.65).set_trans(Tween.TRANS_SINE)


func _load_scene(index: int, with_fade: bool = true) -> void:
	_scene_index = index
	_dialogue_index = 0
	var scene_data: Dictionary = STORY_SCENES[_scene_index]

	if with_fade:
		var tween := create_tween()
		tween.tween_property(_fade_rect, "color:a", 1.0, 0.22)
		tween.tween_callback(func() -> void:
			_apply_scene_visuals(scene_data)
			_show_dialogue_line(0)
		)
		tween.tween_property(_fade_rect, "color:a", 0.0, 0.25)
	else:
		_apply_scene_visuals(scene_data)
		_show_dialogue_line(0)


func _apply_scene_visuals(scene_data: Dictionary) -> void:
	_bg_rect.texture = scene_data["background"]
	_lightbulb_btn.position = scene_data["lightbulb_pos"]
	_curiosity_title_label.text = scene_data["curiosity_title"]
	_curiosity_body_label.text = scene_data["curiosity_text"]


func _show_dialogue_line(line_idx: int) -> void:
	var dialogues: Array = STORY_SCENES[_scene_index]["dialogues"]
	var line_data: Dictionary = dialogues[line_idx]

	_speaker_label.text = line_data["speaker"]
	_full_current_text = line_data["text"]
	_dialogue_label.text = _full_current_text
	_dialogue_label.visible_characters = 0
	_char_timer = 0.0
	_is_typing = true
	_arrow_indicator.visible = false

	var is_last_scene := (_scene_index == STORY_SCENES.size() - 1)
	var is_last_line := (line_idx == dialogues.size() - 1)
	if is_last_scene and is_last_line:
		_next_btn_label.text = "Explorar!"
	else:
		_next_btn_label.text = "Próximo"


func _finish_typing() -> void:
	_is_typing = false
	_dialogue_label.visible_characters = -1
	_arrow_indicator.visible = true


func _on_next_pressed() -> void:
	if _is_typing:
		_finish_typing()
		return

	var dialogues: Array = STORY_SCENES[_scene_index]["dialogues"]
	if _dialogue_index + 1 < dialogues.size():
		_dialogue_index += 1
		_show_dialogue_line(_dialogue_index)
	elif _scene_index + 1 < STORY_SCENES.size():
		_load_scene(_scene_index + 1, true)
	else:
		_start_game_world()


func _on_lightbulb_pressed() -> void:
	_curiosity_overlay.visible = true


func _start_game_world() -> void:
	_transition_to_file(WORLD_SCENE)


func _transition_to_file(target_scene: String) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_rect, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(target_scene))
