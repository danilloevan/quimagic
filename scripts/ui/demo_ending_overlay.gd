class_name DemoEndingOverlay
extends CanvasLayer

## Tela de encerramento da demonstração exibida ao entrar na caverna com mensagem
## alquímica de despedida e opções para reiniciar ou voltar ao menu principal.

const PIXEL_FONT := preload("res://assets/fonts/PixelifySans-Bold.ttf")
const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var _backdrop: ColorRect
var _card: PanelContainer


func _ready() -> void:
	layer = 20
	_build_ui()
	_animate_in()


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.color = Color(0.04, 0.03, 0.08, 0.86)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(680, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.08, 0.16, 0.97)
	card_style.set_corner_radius_all(16)
	card_style.set_border_width_all(3)
	card_style.border_color = Color(0.95, 0.82, 0.38)
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	card_style.shadow_size = 18
	_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	_card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var subtitle := Label.new()
	subtitle.text = "⚗ FIM DA DEMONSTRAÇÃO"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_override("font", PIXEL_FONT)
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.90, 1.0))
	vbox.add_child(subtitle)

	var title := Label.new()
	title.text = "✦ O Limiar da Caverna ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.38))
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.modulate = Color(0.95, 0.82, 0.38, 0.35)
	vbox.add_child(sep)

	var message := RichTextLabel.new()
	message.bbcode_enabled = true
	message.fit_content = true
	message.scroll_active = false
	message.add_theme_font_size_override("normal_font_size", 16)
	message.add_theme_font_size_override("bold_font_size", 16)
	message.add_theme_color_override("default_color", Color(0.92, 0.90, 0.96))
	message.text = (
		"[center]\"Pelos éteres da transmutação e pela força das ligações covalentes, "
		+ "você sintetizou o [color=#6ee7ff][b]Solvente Universal (H₂O)[/b][/color] "
		+ "e rompeu o primeiro selo de sal!\n\n"
		+ "Nas profundezas desta caverna jazem compostos ainda mais voláteis e os "
		+ "segredos ocultos de [color=#f2d161][b]Ur-Novem Duo[/b][/color]...\n\n"
		+ "Guarde bem suas fórmulas, jovem alquimista: a Tabela Periódica será sempre "
		+ "o seu grimório mais poderoso. Que os gases nobres guiem seus passos até o "
		+ "nosso próximo experimento!\"[/center]"
	)
	vbox.add_child(message)

	var stats := Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", Color(0.72, 0.68, 0.82))
	var discovered_count := GameState.discovered.size()
	if discovered_count > 0:
		stats.text = "Compostos descobertos nesta jornada: %s" % ", ".join(GameState.discovered)
	else:
		stats.text = "Sua jornada alquímica está apenas começando."
	vbox.add_child(stats)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 18)
	vbox.add_child(btn_row)

	var replay_btn := _make_button("Jogar Novamente", true)
	replay_btn.pressed.connect(_on_replay_pressed)
	btn_row.add_child(replay_btn)

	var menu_btn := _make_button("Menu Principal", false)
	menu_btn.pressed.connect(_on_menu_pressed)
	btn_row.add_child(menu_btn)


func _make_button(label_text: String, primary: bool) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(200, 46)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_override("font", PIXEL_FONT)
	btn.add_theme_font_size_override("font_size", 16)

	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(8)
	normal.set_border_width_all(2)
	if primary:
		normal.bg_color = Color(0.24, 0.16, 0.36, 0.96)
		normal.border_color = Color(0.95, 0.82, 0.38)
		btn.add_theme_color_override("font_color", Color(0.98, 0.88, 0.52))
	else:
		normal.bg_color = Color(0.14, 0.12, 0.22, 0.92)
		normal.border_color = Color(0.55, 0.48, 0.72)
		btn.add_theme_color_override("font_color", Color(0.88, 0.86, 0.94))

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = hover.bg_color.lightened(0.12)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn


func _animate_in() -> void:
	_backdrop.modulate.a = 0.0
	_card.scale = Vector2(0.94, 0.94)
	_card.pivot_offset = _card.size * 0.5

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_backdrop, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_replay_pressed() -> void:
	GameState.reset_all()
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	GameState.reset_all()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
