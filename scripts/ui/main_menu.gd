class_name MainMenu
extends Control

## Tela Inicial (Home) baseada no design do Figma (node 1:2).
## Apresenta os 5 botões principais (JOGAR, CONTINUAR, OPÇÕES, CRÉDITOS, SAÍDA)
## e os ícones superiores de Configurações e Ajuda.

const CLASSROOM_INTRO_SCENE := "res://scenes/intro/classroom_intro.tscn"
const WORLD_SCENE := "res://scenes/world/world.tscn"

const PIXEL_FONT := preload("res://assets/fonts/PixelifySans-Bold.ttf")
const HOME_BG := preload("res://assets/sprites/intro/home_bg.png")
const ICON_SETTINGS := preload("res://assets/sprites/intro/icon_settings.svg")
const ICON_HELP := preload("res://assets/sprites/intro/icon_help.svg")

var _modal_overlay: ColorRect
var _modal_title: Label
var _modal_body: RichTextLabel


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Fundo principal do Figma (1280x720)
	var bg := TextureRect.new()
	bg.texture = HOME_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)

	# Os 5 botões alinhados sobre as molduras pixel-art da imagem de fundo do Figma
	var buttons_data := [
		{"text": "JOGAR", "rect": Rect2(37, 162, 263, 62), "action": _on_play_pressed},
		{"text": "CONTINUAR", "rect": Rect2(37, 257, 263, 63), "action": _on_continue_pressed},
		{"text": "OPÇÕES", "rect": Rect2(37, 353, 263, 62), "action": _on_options_pressed},
		{"text": "CRÉDITOS", "rect": Rect2(37, 448, 263, 62), "action": _on_credits_pressed},
		{"text": "SAÍDA", "rect": Rect2(37, 543, 263, 62), "action": _on_quit_pressed},
	]

	for b_info: Dictionary in buttons_data:
		var btn := _create_menu_button(b_info["text"], b_info["rect"])
		btn.pressed.connect(b_info["action"])
		add_child(btn)

	# Ícones no canto superior direito (Configurações e Ajuda) do Figma
	var settings_btn := _create_icon_button(ICON_SETTINGS, Vector2(1098, 32), Vector2(54, 54), "Configurações")
	settings_btn.pressed.connect(_on_options_pressed)
	add_child(settings_btn)

	var help_btn := _create_icon_button(ICON_HELP, Vector2(1178, 32), Vector2(54, 54), "Como Jogar")
	help_btn.pressed.connect(_on_help_pressed)
	add_child(help_btn)

	_build_modal()


func _create_menu_button(label_text: String, rect: Rect2) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.position = rect.position
	btn.size = rect.size
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE

	btn.add_theme_font_override("font", PIXEL_FONT)
	btn.add_theme_font_size_override("font_size", 38)
	# Cor roxa vibrante (#a812ff) definida no Figma
	var purple := Color("#a812ff")
	var purple_hover := Color("#7a00cc")
	btn.add_theme_color_override("font_color", purple)
	btn.add_theme_color_override("font_hover_color", purple_hover)
	btn.add_theme_color_override("font_pressed_color", Color("#4a0080"))

	var normal_style := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.66, 0.07, 1.0, 0.12)
	hover_style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.66, 0.07, 1.0, 0.24)
	pressed_style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn


func _create_icon_button(icon_tex: Texture2D, pos: Vector2, btn_size: Vector2, tooltip: String) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = icon_tex
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.position = pos
	btn.size = btn_size
	btn.tooltip_text = tooltip
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.mouse_entered.connect(func() -> void: btn.modulate = Color(1.0, 0.9, 0.5))
	btn.mouse_exited.connect(func() -> void: btn.modulate = Color.WHITE)
	return btn


func _build_modal() -> void:
	_modal_overlay = ColorRect.new()
	_modal_overlay.color = Color(0.04, 0.02, 0.08, 0.78)
	_modal_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.visible = false
	add_child(_modal_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_modal_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 340)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.89, 0.74, 0.54)
	style.border_color = Color(0.32, 0.18, 0.09)
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

	_modal_title = Label.new()
	_modal_title.add_theme_font_override("font", PIXEL_FONT)
	_modal_title.add_theme_font_size_override("font_size", 32)
	_modal_title.add_theme_color_override("font_color", Color("#4520ff"))
	_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_modal_title)

	_modal_body = RichTextLabel.new()
	_modal_body.bbcode_enabled = true
	_modal_body.fit_content = true
	_modal_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_modal_body.add_theme_font_size_override("normal_font_size", 18)
	_modal_body.add_theme_color_override("default_color", Color(0.14, 0.08, 0.04))
	vbox.add_child(_modal_body)

	var close_btn := Button.new()
	close_btn.text = "Fechar"
	close_btn.custom_minimum_size = Vector2(160, 48)
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
	close_btn.pressed.connect(func() -> void: _modal_overlay.visible = false)
	vbox.add_child(close_btn)


func _show_modal(title: String, bbcode_text: String) -> void:
	_modal_title.text = title
	_modal_body.text = bbcode_text
	_modal_overlay.visible = true


func _on_play_pressed() -> void:
	_transition_to_scene(CLASSROOM_INTRO_SCENE)


func _on_continue_pressed() -> void:
	_transition_to_scene(WORLD_SCENE)


func _on_options_pressed() -> void:
	_show_modal(
		"OPÇÕES",
		"[b]Controles do Jogo:[/b]\n" +
		"• [b]W, A, S, D[/b] ou [b]Setas[/b]: Movimentar Hidro pelo mapa\n" +
		"• [b]Tecla B[/b]: Abrir / Fechar a Bancada Alquímica\n" +
		"• [b]Mouse (Clique / Arrastar)[/b]: Avançar diálogos e combinar elementos no caldeirão\n\n" +
		"[i]Dica: Clique em JOGAR para ver a história inicial na sala de aula ou em CONTINUAR para ir direto ao mapa![/i]"
	)


func _on_credits_pressed() -> void:
	_show_modal(
		"CRÉDITOS",
		"[center][b]QUIMAGIC — Master of Alchemical Wonders[/b]\n\n" +
		"Um RPG educativo de alquimia e química onde você ajuda o mago Mendeleev a reconstruir o conhecimento dos elementos!\n\n" +
		"Desenvolvido na Godot Engine 4.7[/center]"
	)


func _on_help_pressed() -> void:
	_show_modal(
		"COMO JOGAR",
		"1. [b]Prólogo na Sala de Aula:[/b] Acompanhe a aula de química e descubra como Hidro foi parar no laboratório de Mendeleev.\n" +
		"2. [b]Curiosidades (💡):[/b] Clique na lâmpada amarela durante as cenas para aprender conceitos reais de química.\n" +
		"3. [b]Exploração e Alquimia:[/b] Colete Hidrogênio (H) e Oxigênio (O) pelo mapa e pressione [b][B][/b] para sintetizar Água (H₂O) no caldeirão!"
	)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _transition_to_scene(scene_path: String) -> void:
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(scene_path))

