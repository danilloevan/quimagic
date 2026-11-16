class_name BenchView
extends CanvasLayer

const ChemistryDB = preload("res://scripts/core/chemistry_db.gd")
const BenchReservoir = preload("res://scripts/bench/bench_reservoir.gd")
const CauldronDropZone = preload("res://scripts/bench/cauldron_drop_zone.gd")
const CauldronFX = preload("res://scripts/bench/cauldron_fx.gd")
const DiscoveryCard = preload("res://scripts/bench/discovery_card.gd")
const FurnaceLever = preload("res://scripts/bench/furnace_lever.gd")
const PIXEL_FONT := preload("res://assets/fonts/PixelifySans-Bold.ttf")

## Visão em Primeira Pessoa da Bancada de Alquimia / Síntese Química de Mendeleev.
## Inclui Caldeirão procedural, Termômetro lateral, Alavanca contínua do Forno
## (Aquecer com Fogo / Apagar / Esfriar com Gelo) e Grimório de Fórmulas.

signal closed

const BG_IMAGE_PATH := "res://assets/sprites/bench/bench_background.jpg"
const GOLD := Color(0.95, 0.82, 0.38)
const WOOD_DARK := Color(0.14, 0.09, 0.07, 0.92)
const WOOD_BORDER := Color(0.46, 0.29, 0.15)

## Reagentes atualmente inseridos no caldeirão: { substance_id: int }
var cauldron_contents: Dictionary = {}
## Nível discreto térmico (-2 = Gelo Máx, -1 = Esfriar, 0 = Apagado, 1 = Baixo, 2 = Médio, 3 = Alto)
var current_heat: int = 1
var current_lever_value: float = 0.34

var _bg_texture: Texture2D
var _fx: CauldronFX
var _drop_zone: CauldronDropZone
var _furnace_lever: FurnaceLever
var _card_modal: DiscoveryCard
var _grimoire_modal: Control

# Elementos de UI
var _reservoirs_container: HBoxContainer
var _contents_container: HBoxContainer
var _status_label: Label
var _heat_label: Label
var _temp_detail_label: Label
var _state_badge_label: Label
var _heat_buttons: Dictionary = {} # { level_int: Button }
var _synthesize_btn: Button
var _clear_btn: Button
var _root_control: Control
var _shake_time: float = 0.0


func _ready() -> void:
	layer = 15
	if ResourceLoader.exists(BG_IMAGE_PATH):
		_bg_texture = load(BG_IMAGE_PATH)
	_build_ui()
	_refresh_reservoirs()
	_update_heat_ui()
	_update_cauldron_ui()

	GameState.inventory_changed.connect(_on_inventory_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _grimoire_modal and _grimoire_modal.visible and event.keycode == KEY_ESCAPE:
			_grimoire_modal.visible = false
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_B or event.keycode == KEY_ESCAPE:
			close_bench()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_UP, KEY_W]:
			_furnace_lever.set_lever_value(_furnace_lever.value + 0.16)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_DOWN, KEY_S]:
			_furnace_lever.set_lever_value(_furnace_lever.value - 0.16)
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	if _shake_time > 0.0:
		_shake_time -= delta
		var offset := Vector2(randf_range(-12, 12), randf_range(-12, 12)) * (_shake_time / 0.8)
		_root_control.position = offset
	else:
		_root_control.position = Vector2.ZERO

	if _fx and _temp_detail_label:
		var temp_c := int(roundf(_fx.get_temperature_celsius()))
		_temp_detail_label.text = "Temperatura: %d °C  |  %s" % [temp_c, _describe_matter_state(temp_c)]


func open_bench() -> void:
	visible = true
	_refresh_reservoirs()
	_update_cauldron_ui()
	var total_stock := 0
	for id: String in ChemistryDB.ELEMENT_ORDER:
		total_stock += GameState.get_count(id)
	if total_stock == 0 and cauldron_contents.is_empty():
		_status_label.text = "Estoque vazio! Colete elementos no mapa ou clique em '🧪 Kit Teste'."
	else:
		_status_label.text = "Use a ALAVANCA do forno para Aquecer 🔥 ou Esfriar com Gelo ❄️!"
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84))


func close_bench() -> void:
	# Ao fechar, se houver reagentes no caldeirão, devolve ao inventário para não perder itens
	_return_all_to_inventory()
	if _grimoire_modal:
		_grimoire_modal.visible = false
	visible = false
	closed.emit()


func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root_control)

	# 1. Imagem de Fundo (1280x720)
	var bg := TextureRect.new()
	bg.texture = _bg_texture
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.add_child(bg)

	# 2. Efeitos Visuais Procedurais do Caldeirão, Forno (Fogo + Gelo) e Termômetro
	_fx = CauldronFX.new()
	_fx.set_thermal_continuous(current_lever_value, current_heat)
	_root_control.add_child(_fx)

	# 3. Alavanca Interativa do Forno (ao lado direito da fornalha do caldeirão)
	_furnace_lever = FurnaceLever.new()
	_furnace_lever.position = Vector2(764, 396)
	_furnace_lever.set_lever_value(current_lever_value, false)
	_furnace_lever.value_changed.connect(_on_lever_value_changed)
	_root_control.add_child(_furnace_lever)

	# 4. Zona de Soltura (Drop Zone) calibrada sobre a boca do caldeirão (x: 639, y: 302)
	_drop_zone = CauldronDropZone.new()
	_drop_zone.position = Vector2(510, 210)
	_drop_zone.size = Vector2(258, 185)
	_drop_zone.substance_dropped.connect(_on_substance_dropped)
	_drop_zone.hover_changed.connect(func(active: bool) -> void: _fx.highlight = active)
	_root_control.add_child(_drop_zone)

	# 5. Barra Superior (Cabeçalho, Kit de Teste, Grimório e Fechar)
	_build_header()

	# 6. Painel Esquerdo: Conteúdo do Caldeirão e Síntese
	_build_cauldron_control_panel()

	# 7. Painel Direito: Controle Térmico (Fogo / Gelo) sincronizado com a Alavanca
	_build_heat_controls()

	# 8. Bancada Inferior: Prateleira de Frascos sobre a mesa de madeira
	_build_bench_shelf()

	# 9. Modal de Grimório de Receitas (inspirado no ícone de livro do Figma 2010:74)
	_build_grimoire_modal()

	# 10. Modal de Descoberta de Carta Química
	_card_modal = DiscoveryCard.new()
	_root_control.add_child(_card_modal)


func _apply_pixel_font(ctrl: Control, font_size: int, col: Color = Color.WHITE) -> void:
	if PIXEL_FONT:
		ctrl.add_theme_font_override("font", PIXEL_FONT)
	ctrl.add_theme_font_size_override("font_size", font_size)
	if ctrl is Label:
		(ctrl as Label).add_theme_color_override("font_color", col)
	elif ctrl is Button:
		(ctrl as Button).add_theme_color_override("font_color", col)


func _make_wood_panel_style(border_col: Color = GOLD, bg_alpha: float = 0.90) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.11, 0.08, 0.12, bg_alpha)
	s.set_corner_radius_all(10)
	s.set_border_width_all(3)
	s.border_color = border_col
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 10
	return s


func _build_header() -> void:
	var top_bar := PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 54)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.09, 0.06, 0.11, 0.92)
	bar_style.border_width_bottom = 3
	bar_style.border_color = GOLD
	top_bar.add_theme_stylebox_override("panel", bar_style)
	_root_control.add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	top_bar.add_child(hbox)

	var margin_title := MarginContainer.new()
	margin_title.add_theme_constant_override("margin_left", 18)
	hbox.add_child(margin_title)

	var title := Label.new()
	title.text = "⚗ BANCADA DE MENDELEEV"
	_apply_pixel_font(title, 20, GOLD)
	margin_title.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Arraste os elementos até o caldeirão e controle o forno pela alavanca."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.clip_text = true
	_apply_pixel_font(_status_label, 14, Color(0.92, 0.90, 0.85))
	hbox.add_child(_status_label)

	# Botão Kit de Teste (para testar reações, fogo e gelo rapidamente na bancada)
	var sample_btn := Button.new()
	sample_btn.text = "🧪 Kit Teste"
	sample_btn.tooltip_text = "Receber amostras extras de elementos e H₂O para experimentar no caldeirão"
	sample_btn.custom_minimum_size = Vector2(112, 36)
	sample_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_pixel_font(sample_btn, 14, Color(0.75, 0.95, 1.0))
	var sample_style := StyleBoxFlat.new()
	sample_style.bg_color = Color(0.14, 0.24, 0.34, 0.92)
	sample_style.set_corner_radius_all(6)
	sample_style.set_border_width_all(2)
	sample_style.border_color = Color(0.38, 0.78, 0.98)
	sample_btn.add_theme_stylebox_override("normal", sample_style)
	sample_btn.pressed.connect(_on_grant_test_samples)
	hbox.add_child(sample_btn)

	# Botão Grimório (inspirado no livro no canto superior direito do Figma 2010:74)
	var grimoire_btn := Button.new()
	grimoire_btn.text = "📖 Grimório"
	grimoire_btn.tooltip_text = "Abrir o Grimório Alquímico com receitas e guia de temperatura"
	grimoire_btn.custom_minimum_size = Vector2(118, 36)
	grimoire_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_pixel_font(grimoire_btn, 14, GOLD)
	var grim_style := StyleBoxFlat.new()
	grim_style.bg_color = Color(0.28, 0.18, 0.10, 0.95)
	grim_style.set_corner_radius_all(6)
	grim_style.set_border_width_all(2)
	grim_style.border_color = GOLD
	grimoire_btn.add_theme_stylebox_override("normal", grim_style)
	grimoire_btn.pressed.connect(func() -> void: _grimoire_modal.visible = true)
	hbox.add_child(grimoire_btn)

	var close_btn := Button.new()
	close_btn.text = "✕ Mapa [B]"
	close_btn.custom_minimum_size = Vector2(116, 36)
	close_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_pixel_font(close_btn, 14, Color(1.0, 0.85, 0.85))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.32, 0.14, 0.18, 0.92)
	btn_style.set_corner_radius_all(6)
	btn_style.set_border_width_all(2)
	btn_style.border_color = Color(0.88, 0.42, 0.42)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.pressed.connect(close_bench)
	hbox.add_child(close_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(spacer)


func _build_cauldron_control_panel() -> void:
	# Painel na lateral esquerda mostrando o que está dentro do caldeirão e botão Sintetizar
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 68)
	panel.custom_minimum_size = Vector2(292, 268)
	panel.add_theme_stylebox_override("panel", _make_wood_panel_style(Color(GOLD, 0.72)))
	_root_control.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "⚗ CONTEÚDO DO CALDEIRÃO"
	_apply_pixel_font(title, 15, GOLD)
	vbox.add_child(title)

	_state_badge_label = Label.new()
	_state_badge_label.text = "Estado: 💧 Líquido Aquecido"
	_apply_pixel_font(_state_badge_label, 13, Color(0.75, 0.88, 1.0))
	vbox.add_child(_state_badge_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 108)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_contents_container = HBoxContainer.new()
	_contents_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_contents_container)

	# Botões de Ação
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	_clear_btn = Button.new()
	_clear_btn.text = "Limpar"
	_clear_btn.custom_minimum_size = Vector2(0, 38)
	_clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_pixel_font(_clear_btn, 14, Color(0.9, 0.88, 0.85))
	var clear_style := StyleBoxFlat.new()
	clear_style.bg_color = Color(0.22, 0.18, 0.25, 0.95)
	clear_style.set_corner_radius_all(6)
	clear_style.set_border_width_all(2)
	clear_style.border_color = Color(0.5, 0.45, 0.55)
	_clear_btn.add_theme_stylebox_override("normal", clear_style)
	_clear_btn.pressed.connect(_return_all_to_inventory)
	btn_row.add_child(_clear_btn)

	_synthesize_btn = Button.new()
	_synthesize_btn.text = "⚡ SINTETIZAR"
	_synthesize_btn.custom_minimum_size = Vector2(0, 38)
	_synthesize_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synthesize_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_pixel_font(_synthesize_btn, 15, Color(0.12, 0.08, 0.04))
	var synth_style := StyleBoxFlat.new()
	synth_style.bg_color = Color(0.85, 0.65, 0.22)
	synth_style.set_corner_radius_all(6)
	synth_style.set_border_width_all(2)
	synth_style.border_color = Color(1.0, 0.92, 0.55)
	_synthesize_btn.add_theme_stylebox_override("normal", synth_style)
	var synth_hover := synth_style.duplicate() as StyleBoxFlat
	synth_hover.bg_color = GOLD.lightened(0.12)
	_synthesize_btn.add_theme_stylebox_override("hover", synth_hover)
	_synthesize_btn.pressed.connect(_on_synthesize_pressed)
	btn_row.add_child(_synthesize_btn)


func _build_heat_controls() -> void:
	# Painel de controle térmico na lateral direita (sincronizado com a alavanca do forno)
	var panel := PanelContainer.new()
	panel.position = Vector2(964, 68)
	panel.custom_minimum_size = Vector2(296, 268)
	panel.add_theme_stylebox_override("panel", _make_wood_panel_style(Color(1.0, 0.55, 0.24, 0.78)))
	_root_control.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "🔥❄️ CONTROLE DO FORNO"
	_apply_pixel_font(title, 15, Color(1.0, 0.68, 0.32))
	vbox.add_child(title)

	_heat_label = Label.new()
	_heat_label.text = "Alavanca: Fogo Baixo"
	_apply_pixel_font(_heat_label, 15, Color(1.0, 0.82, 0.35))
	vbox.add_child(_heat_label)

	_temp_detail_label = Label.new()
	_temp_detail_label.text = "Temperatura: 85 °C  |  Líquido"
	_apply_pixel_font(_temp_detail_label, 12, Color(0.84, 0.86, 0.92))
	vbox.add_child(_temp_detail_label)

	var sub_hint := Label.new()
	sub_hint.text = "Arraste a alavanca no forno ou escolha:"
	_apply_pixel_font(sub_hint, 11, Color(0.72, 0.70, 0.76))
	vbox.add_child(sub_hint)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	var presets := [
		{"level": -2, "label": "❄️ Gelo Máx", "col": Color(0.16, 0.52, 0.85)},
		{"level": -1, "label": "🧊 Esfriar", "col": Color(0.20, 0.42, 0.68)},
		{"level": 0, "label": "⭕ Apagado", "col": Color(0.25, 0.24, 0.28)},
		{"level": 1, "label": "🔥 Baixo", "col": Color(0.55, 0.36, 0.14)},
		{"level": 2, "label": "🔥🔥 Médio", "col": Color(0.68, 0.28, 0.12)},
		{"level": 3, "label": "🔥🔥🔥 Alto", "col": Color(0.78, 0.16, 0.12)},
	]

	for p_info: Dictionary in presets:
		var lvl: int = p_info["level"]
		var btn := Button.new()
		btn.text = p_info["label"]
		btn.custom_minimum_size = Vector2(128, 34)
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_pixel_font(btn, 13, Color.WHITE)

		var b_style := StyleBoxFlat.new()
		b_style.bg_color = p_info["col"]
		b_style.set_corner_radius_all(6)
		b_style.set_border_width_all(2)
		b_style.border_color = (p_info["col"] as Color).lightened(0.35)
		btn.add_theme_stylebox_override("normal", b_style)

		var b_hover := b_style.duplicate() as StyleBoxFlat
		b_hover.bg_color = (p_info["col"] as Color).lightened(0.15)
		btn.add_theme_stylebox_override("hover", b_hover)

		btn.pressed.connect(func() -> void: _set_heat(lvl))
		grid.add_child(btn)
		_heat_buttons[lvl] = btn


func _build_bench_shelf() -> void:
	# Prateleira de Frascos posicionada sobre o tampo de madeira (y >= 574),
	# deixando o Forno, as Chamas e o Gelo (y = 475..572) 100% visíveis!
	var shelf := PanelContainer.new()
	shelf.position = Vector2(18, 574)
	shelf.size = Vector2(1244, 142)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.08, 0.05, 0.72)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(GOLD, 0.75)
	shelf.add_theme_stylebox_override("panel", style)
	_root_control.add_child(shelf)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	shelf.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)

	var shelf_title := Label.new()
	shelf_title.text = "RESERVATÓRIOS ALQUÍMICOS (Arraste ao caldeirão ou clique para adicionar 1 amostra)"
	_apply_pixel_font(shelf_title, 12, Color(GOLD, 0.90))
	vbox.add_child(shelf_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_reservoirs_container = HBoxContainer.new()
	_reservoirs_container.add_theme_constant_override("separation", 16)
	scroll.add_child(_reservoirs_container)


func _build_grimoire_modal() -> void:
	_grimoire_modal = ColorRect.new()
	_grimoire_modal.color = Color(0.04, 0.02, 0.08, 0.80)
	_grimoire_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grimoire_modal.visible = false
	_root_control.add_child(_grimoire_modal)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grimoire_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 440)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.89, 0.76, 0.56)
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
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "📖 GRIMÓRIO DE MENDELEEV — FÓRMULAS & FORNO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_pixel_font(title, 22, Color(0.28, 0.12, 0.48))
	vbox.add_child(title)

	var body := RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("normal_font_size", 15)
	body.add_theme_color_override("default_color", Color(0.16, 0.09, 0.04))
	body.text = (
		"[b]1. Controle da Alavanca do Forno (Fogo e Gelo):[/b]\n" +
		"• [b]Aquecer (Subir Alavanca 🔥):[/b] Quanto mais alto, mais forte o fogo e maior a temperatura no termômetro.\n" +
		"• [b]Apagar (Centro ⭕):[/b] Diminuindo o calor, o fogo vai se apagando até restarem apenas brasas.\n" +
		"• [b]Esfriar com Gelo (Descer Alavanca ❄️):[/b] Cubos de gelo emergem do forno para resfriar e congelar a mistura (< 0 °C)!\n\n" +
		"[b]2. Sínteses Alquímicas Conhecidas:[/b]\n" +
		"• [b]Água (H₂O):[/b] [code]2 H + 1 O[/code] com [b]Fogo Baixo ou maior[/b] → Solvente universal que dissolve as Barreiras de Sal!\n" +
		"• [b]Cloreto de Sódio (NaCl):[/b] [code]1 Na + 1 Cl[/code] em [b]Temperatura Ambiente ou maior[/b] → Sal de cozinha.\n" +
		"• [b]Dióxido de Carbono (CO₂):[/b] [code]1 C + 2 O[/code] com [b]Fogo Médio ou Alto[/b] → Combustão do carbono.\n\n" +
		"[b]3. Estados Físicos & Perigos:[/b]\n" +
		"• Coloque [b]H₂O[/b] no caldeirão e use [b]Gelo ❄️[/b] para ver a [i]Solidificação[/i] ou [b]Fogo Forte 🔥[/b] para ver a [i]Vaporização[/i]!\n" +
		"• [b]⚠️ Perigo Exotérmico:[/b] Nunca aqueça Sódio ([b]Na[/b]) + Água ([b]H₂O[/b]) em fogo alto! Use [b]Gelo ❄️[/b] para conter o calor."
	)
	vbox.add_child(body)

	var close_grim := Button.new()
	close_grim.text = "Fechar Grimório"
	close_grim.custom_minimum_size = Vector2(180, 42)
	close_grim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_grim.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_pixel_font(close_grim, 16, Color(0.28, 0.12, 0.48))
	var close_s := StyleBoxFlat.new()
	close_s.bg_color = Color.WHITE
	close_s.border_color = Color.BLACK
	close_s.set_border_width_all(3)
	close_s.set_corner_radius_all(8)
	close_grim.add_theme_stylebox_override("normal", close_s)
	close_grim.pressed.connect(func() -> void: _grimoire_modal.visible = false)
	vbox.add_child(close_grim)


func _on_grant_test_samples() -> void:
	GameState.add("H", 2)
	GameState.add("O", 2)
	GameState.add("Na", 1)
	GameState.add("Cl", 1)
	GameState.add("C", 1)
	GameState.discover("H2O")
	GameState.add("H2O", 1)
	_refresh_reservoirs()
	_status_label.text = "🧪 Kit de Teste adicionado! Experimente arrastar reagentes e usar a alavanca de Fogo 🔥 e Gelo ❄️!"
	_status_label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))


func _refresh_reservoirs() -> void:
	for c in _reservoirs_container.get_children():
		c.queue_free()

	# Mostra elementos base
	for el_id: String in ChemistryDB.ELEMENT_ORDER:
		_add_reservoir(el_id)

	# Mostra compostos que o jogador já descobriu
	for comp_id: String in ChemistryDB.COMPOUND_ORDER:
		if GameState.is_discovered(comp_id) or GameState.get_count(comp_id) > 0:
			_add_reservoir(comp_id)


func _add_reservoir(id: String) -> void:
	var res := BenchReservoir.new()
	res.setup(id)
	res.quick_add.connect(_on_reservoir_quick_add)
	_reservoirs_container.add_child(res)


func _on_reservoir_quick_add(substance_id: String) -> void:
	_add_substance_to_cauldron(substance_id)


func _on_substance_dropped(substance_id: String) -> void:
	_add_substance_to_cauldron(substance_id)


func _add_substance_to_cauldron(substance_id: String) -> void:
	if not GameState.take(substance_id, 1):
		_status_label.text = "Você não tem mais amostras de %s! Explore o mapa ou clique em '🧪 Kit Teste'." % ChemistryDB.name_of(substance_id)
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
		return

	cauldron_contents[substance_id] = int(cauldron_contents.get(substance_id, 0)) + 1
	_fx.splash(ChemistryDB.color_of(substance_id))
	_update_cauldron_ui()


func _return_one_from_cauldron(substance_id: String) -> void:
	if not cauldron_contents.has(substance_id):
		return
	var count: int = cauldron_contents[substance_id]
	if count <= 1:
		cauldron_contents.erase(substance_id)
	else:
		cauldron_contents[substance_id] = count - 1

	GameState.add(substance_id, 1)
	_update_cauldron_ui()


func _return_all_to_inventory() -> void:
	for id: String in cauldron_contents:
		var amount: int = cauldron_contents[id]
		GameState.add(id, amount)
	cauldron_contents.clear()
	_update_cauldron_ui()


func _update_cauldron_ui() -> void:
	_fx.set_contents(cauldron_contents, 8)
	_update_matter_state_badge()

	for c in _contents_container.get_children():
		c.queue_free()

	if cauldron_contents.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Caldeirão em repouso (adicione reagentes)."
		_apply_pixel_font(empty_lbl, 12, Color(0.68, 0.66, 0.72))
		_contents_container.add_child(empty_lbl)
		return

	for id: String in cauldron_contents:
		var count: int = cauldron_contents[id]
		var col := ChemistryDB.color_of(id)
		var badge := Button.new()
		badge.text = "%s × %d (✕)" % [ChemistryDB.formula_of(id), count]
		badge.tooltip_text = "Clique para devolver 1 %s ao inventário" % ChemistryDB.name_of(id)
		badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_pixel_font(badge, 13, Color.WHITE)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(col.darkened(0.52), 0.92)
		badge_style.set_corner_radius_all(6)
		badge_style.set_border_width_all(2)
		badge_style.border_color = col
		badge.add_theme_stylebox_override("normal", badge_style)
		var sub_id := id
		badge.pressed.connect(func() -> void: _return_one_from_cauldron(sub_id))
		_contents_container.add_child(badge)


func _on_lever_value_changed(new_val: float, discrete_lvl: int) -> void:
	current_lever_value = new_val
	current_heat = discrete_lvl
	_fx.set_thermal_continuous(new_val, discrete_lvl)
	_update_heat_ui()
	_update_matter_state_badge()


func _set_heat(level: int) -> void:
	current_heat = clampi(level, -2, 3)
	if _furnace_lever:
		_furnace_lever.set_discrete_level(current_heat, false)
		current_lever_value = _furnace_lever.value
	_fx.set_thermal_continuous(current_lever_value, current_heat)
	_update_heat_ui()
	_update_matter_state_badge()


func _describe_matter_state(temp_c: int) -> String:
	if temp_c <= 0:
		return "❄️ Sólido / Congelando"
	elif temp_c >= 100:
		return "💨 Ebulição / Vapor"
	else:
		return "💧 Líquido"


func _update_matter_state_badge() -> void:
	if not _state_badge_label:
		return
	if current_heat <= -1:
		_state_badge_label.text = "Estado no Caldeirão: ❄️ Resfriado com Gelo"
		_state_badge_label.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
	elif current_heat == 0:
		_state_badge_label.text = "Estado no Caldeirão: 💧 Temperatura Ambiente"
		_state_badge_label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92))
	elif current_heat == 1:
		_state_badge_label.text = "Estado no Caldeirão: 🔥 Aquecimento Leve"
		_state_badge_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	else:
		_state_badge_label.text = "Estado no Caldeirão: 💨 Fervura / Vapor Intenso"
		_state_badge_label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.25))


func _update_heat_ui() -> void:
	var label_map := {
		-2: "❄️ Gelo Máximo (Congelante)",
		-1: "🧊 Esfriando com Gelo",
		0: "⭕ Fogo Apagado (Ambiente)",
		1: "🔥 Fogo Baixo",
		2: "🔥🔥 Fogo Médio",
		3: "🔥🔥🔥 Fogo Alto (Máximo)",
	}
	var color_map := {
		-2: Color(0.35, 0.92, 1.0),
		-1: Color(0.55, 0.85, 1.0),
		0: Color(0.78, 0.78, 0.82),
		1: Color(1.0, 0.82, 0.35),
		2: Color(1.0, 0.56, 0.18),
		3: Color(1.0, 0.28, 0.14),
	}

	_heat_label.text = String(label_map.get(current_heat, "Ambiente"))
	_heat_label.add_theme_color_override("font_color", color_map.get(current_heat, Color.WHITE))

	for lvl: int in _heat_buttons:
		var b: Button = _heat_buttons[lvl]
		if lvl == current_heat:
			b.modulate = Color(1.25, 1.25, 1.25)
		else:
			b.modulate = Color(0.68, 0.68, 0.72)


func _on_synthesize_pressed() -> void:
	if cauldron_contents.is_empty():
		_status_label.text = "Adicione elementos ao caldeirão antes de tentar sintetizar!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		return

	var result := ChemistryDB.evaluate(cauldron_contents, current_heat)

	match result.get("type", ""):
		"success":
			var product: String = result["product"]
			var amount: int = result["amount"]
			var recipe: Dictionary = result["recipe"]
			GameState.discover(product)
			GameState.add(product, amount)
			_fx.celebrate(ChemistryDB.color_of(product))
			cauldron_contents.clear()
			_update_cauldron_ui()
			_refresh_reservoirs()

			_status_label.text = "Sucesso! Você sintetizou %s (%s)!" % [ChemistryDB.name_of(product), ChemistryDB.formula_of(product)]
			_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			_card_modal.display(product, recipe)

		"state_change":
			var st: String = result.get("state", "liquid")
			if st == "solid":
				_fx.puff(Color(0.65, 0.94, 1.0, 0.85), 0.5)
				_status_label.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
			elif st == "gas":
				_fx.puff(Color(0.92, 0.96, 1.0, 0.85), 0.7)
				_status_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.38))
			else:
				_fx.splash(Color(0.25, 0.68, 1.0))
				_status_label.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
			_status_label.text = result["message"]

		"needs_heat":
			var puff_col := Color(0.65, 0.90, 1.0) if current_heat < 0 else Color(0.8, 0.8, 0.8)
			_fx.puff(puff_col, 0.5)
			_status_label.text = result["message"]
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))

		"fail":
			var fail_col := Color(0.55, 0.85, 1.0) if current_heat < 0 else Color(0.12, 0.12, 0.14)
			_fx.puff(fail_col, 0.85)
			_status_label.text = result["message"]
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))

		"explosion":
			_trigger_explosion(result)


func _trigger_explosion(hazard_data: Dictionary) -> void:
	_fx.explode()
	_shake_time = 0.8
	cauldron_contents.clear()
	_update_cauldron_ui()

	# GDD: o vilão Ur-Novem Duo destrói o laboratório e os reagentes
	GameState.reset_inventory()
	_refresh_reservoirs()

	_status_label.text = "💥 EXPLOSÃO! Ur-Novem Duo destruiu seus reagentes! Inventário resetado."
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))

	var dialog := AcceptDialog.new()
	dialog.title = hazard_data.get("title", "Desastre Alquímico!")
	dialog.dialog_text = hazard_data.get("message", "A reação explodiu e destruiu o laboratório!")
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(dialog.queue_free)


func _on_inventory_changed() -> void:
	for c in _reservoirs_container.get_children():
		if c is BenchReservoir:
			c.bump()
