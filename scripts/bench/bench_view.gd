class_name BenchView
extends CanvasLayer

const ChemistryDB = preload("res://scripts/core/chemistry_db.gd")
const BenchReservoir = preload("res://scripts/bench/bench_reservoir.gd")
const CauldronDropZone = preload("res://scripts/bench/cauldron_drop_zone.gd")
const CauldronFX = preload("res://scripts/bench/cauldron_fx.gd")
const DiscoveryCard = preload("res://scripts/bench/discovery_card.gd")

## Visão em Primeira Pessoa da Bancada de Alquimia / Síntese Química de Mendeleev.

## Permite combinar reagentes por Drag & Drop ou clique direto, controlar o fogo do
## fogareiro e sintetizar compostos químicos como a Água (H₂O) e o Sal (NaCl).

signal closed

const BG_IMAGE_PATH := "res://assets/sprites/bench/bench_background.jpg"
const GOLD := Color(0.95, 0.82, 0.38)

## Reagentes atualmente inseridos no caldeirão: { substance_id: int }
var cauldron_contents: Dictionary = {}
var current_heat: int = 1 # Inicia em fogo baixo por padrão

var _bg_texture: Texture2D
var _fx: CauldronFX
var _drop_zone: CauldronDropZone
var _card_modal: DiscoveryCard

# Elementos de UI
var _reservoirs_container: HBoxContainer
var _contents_container: HBoxContainer
var _status_label: Label
var _heat_label: Label
var _heat_buttons: Array[Button] = []
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
		if event.keycode == KEY_B or event.keycode == KEY_ESCAPE:
			close_bench()
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


func open_bench() -> void:
	visible = true
	_refresh_reservoirs()
	_update_cauldron_ui()
	var total_stock := 0
	for id: String in ChemistryDB.ELEMENT_ORDER:
		total_stock += GameState.get_count(id)
	if total_stock == 0 and cauldron_contents.is_empty():
		_status_label.text = "Estoque vazio! Explore o mapa para coletar elementos químicos (H, O, Na, Cl, C)."
	else:
		_status_label.text = "Arraste frascos ao caldeirão ou clique neles. Ajuste o fogo e sintetize!"
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))


func close_bench() -> void:
	# Ao fechar, se houver reagentes no caldeirão, devolve ao inventário para não perder itens
	_return_all_to_inventory()
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

	# 2. Efeitos Visuais do Caldeirão (CauldronFX)
	_fx = CauldronFX.new()
	_fx.heat = current_heat
	_root_control.add_child(_fx)

	# 3. Zona de Soltura (Drop Zone) sobre a boca do caldeirão
	# Centro calibrado com a boca do caldeirão no background (x: 690, y: 324)
	_drop_zone = CauldronDropZone.new()
	_drop_zone.position = Vector2(560, 240)
	_drop_zone.size = Vector2(260, 180)
	_drop_zone.substance_dropped.connect(_on_substance_dropped)
	_drop_zone.hover_changed.connect(func(active: bool) -> void: _fx.highlight = active)
	_root_control.add_child(_drop_zone)

	# 4. Barra Superior (Cabeçalho & Controles)
	_build_header()

	# 5. Painel de Controle de Reagentes no Caldeirão
	_build_cauldron_control_panel()

	# 6. Fogareiro / Controle de Temperatura (Heat Control)
	_build_heat_controls()

	# 7. Bancada Inferior / Prateleira de Frascos (Reservatórios)
	_build_bench_shelf()

	# 8. Modal de Descoberta de Carta
	_card_modal = DiscoveryCard.new()
	_root_control.add_child(_card_modal)


func _build_header() -> void:
	var top_bar := PanelContainer.new()
	top_bar.custom_minimum_size = Vector2(0, 56)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.08, 0.07, 0.12, 0.88)
	bar_style.border_width_bottom = 2
	bar_style.border_color = GOLD
	top_bar.add_theme_stylebox_override("panel", bar_style)
	_root_control.add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	top_bar.add_child(hbox)

	var margin_title := MarginContainer.new()
	margin_title.add_theme_constant_override("margin_left", 20)
	hbox.add_child(margin_title)

	var title := Label.new()
	title.text = "⚗ BANCADA DE MENDELEEV"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", GOLD)
	margin_title.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Arraste os elementos até o caldeirão ou clique neles."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	hbox.add_child(_status_label)

	var hint := Label.new()
	hint.text = "[Tecla B ou ESC para voltar ao mapa]"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hbox.add_child(hint)

	var close_btn := Button.new()
	close_btn.text = "✕ Voltar ao Mapa"
	close_btn.custom_minimum_size = Vector2(130, 36)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.15, 0.2, 0.9)
	btn_style.set_corner_radius_all(6)
	btn_style.set_border_width_all(1)
	btn_style.border_color = Color(0.8, 0.4, 0.4)
	close_btn.add_theme_stylebox_override("normal", btn_style)
	close_btn.pressed.connect(close_bench)
	hbox.add_child(close_btn)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(spacer)


func _build_cauldron_control_panel() -> void:
	# Painel suspenso na lateral esquerda mostrando o que está dentro do caldeirão
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 76)
	panel.custom_minimum_size = Vector2(280, 260)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.85)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(GOLD, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	_root_control.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "CONTEÚDO DO CALDEIRÃO"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", GOLD)
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 110)
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
	_clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear_btn.pressed.connect(_return_all_to_inventory)
	btn_row.add_child(_clear_btn)

	_synthesize_btn = Button.new()
	_synthesize_btn.text = "⚡ SINTETIZAR"
	_synthesize_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var synth_style := StyleBoxFlat.new()
	synth_style.bg_color = Color(0.72, 0.54, 0.18)
	synth_style.set_corner_radius_all(6)
	_synthesize_btn.add_theme_stylebox_override("normal", synth_style)
	var synth_hover := synth_style.duplicate() as StyleBoxFlat
	synth_hover.bg_color = GOLD
	_synthesize_btn.add_theme_stylebox_override("hover", synth_hover)
	_synthesize_btn.add_theme_font_size_override("font_size", 14)
	_synthesize_btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	_synthesize_btn.pressed.connect(_on_synthesize_pressed)
	btn_row.add_child(_synthesize_btn)


func _build_heat_controls() -> void:
	# Painel de controle do fogareiro na lateral direita
	var panel := PanelContainer.new()
	panel.position = Vector2(980, 76)
	panel.custom_minimum_size = Vector2(276, 200)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.85)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(1.0, 0.45, 0.2, 0.5)
	panel.add_theme_stylebox_override("panel", style)
	_root_control.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "🔥 CONTROLE DO FOGAREIRO"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.25))
	vbox.add_child(title)

	_heat_label = Label.new()
	_heat_label.text = "Fogo: Médio"
	_heat_label.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_heat_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	var levels := ["Apagado", "Baixo", "Médio", "Alto"]
	for i in range(levels.size()):
		var btn := Button.new()
		btn.text = levels[i]
		btn.custom_minimum_size = Vector2(115, 36)
		var lvl := i
		btn.pressed.connect(func() -> void: _set_heat(lvl))
		grid.add_child(btn)
		_heat_buttons.append(btn)


func _build_bench_shelf() -> void:
	# Prateleira / Mesa inferior contendo os frascos
	var shelf := PanelContainer.new()
	shelf.position = Vector2(0, 560)
	shelf.size = Vector2(1280, 160)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.09, 0.92)
	style.border_width_top = 3
	style.border_color = GOLD
	shelf.add_theme_stylebox_override("panel", style)
	_root_control.add_child(shelf)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	shelf.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var shelf_title := Label.new()
	shelf_title.text = "RESERVATÓRIOS ALQUÍMICOS (Arraste para o caldeirão ou clique para adicionar)"
	shelf_title.add_theme_font_size_override("font_size", 12)
	shelf_title.add_theme_color_override("font_color", Color(GOLD, 0.75))
	vbox.add_child(shelf_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_reservoirs_container = HBoxContainer.new()
	_reservoirs_container.add_theme_constant_override("separation", 18)
	scroll.add_child(_reservoirs_container)


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
		_status_label.text = "Você não tem mais amostras de %s!" % ChemistryDB.name_of(substance_id)
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
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

	for c in _contents_container.get_children():
		c.queue_free()

	if cauldron_contents.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Caldeirão vazio."
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_contents_container.add_child(empty_lbl)
		return

	for id: String in cauldron_contents:
		var count: int = cauldron_contents[id]
		var col := ChemistryDB.color_of(id)
		var badge := Button.new()
		badge.text = "%s × %d (remover)" % [ChemistryDB.formula_of(id), count]
		badge.tooltip_text = "Clique para devolver 1 %s ao inventário" % ChemistryDB.name_of(id)
		var badge_style := StyleBoxFlat.new()
		badge_style.bg_color = Color(col.darkened(0.5), 0.9)
		badge_style.set_corner_radius_all(6)
		badge_style.set_border_width_all(1)
		badge_style.border_color = col
		badge.add_theme_stylebox_override("normal", badge_style)
		var sub_id := id
		badge.pressed.connect(func() -> void: _return_one_from_cauldron(sub_id))
		_contents_container.add_child(badge)


func _set_heat(level: int) -> void:
	current_heat = level
	_fx.heat = level
	_update_heat_ui()


func _update_heat_ui() -> void:
	var heat_names := ["Desligado", "Fogo Baixo", "Fogo Médio", "Fogo Alto"]
	_heat_label.text = "Fogo: %s" % heat_names[current_heat]

	var colors := [
		Color(0.6, 0.6, 0.6),
		Color(1.0, 0.8, 0.3),
		Color(1.0, 0.55, 0.15),
		Color(1.0, 0.25, 0.1),
	]
	_heat_label.add_theme_color_override("font_color", colors[current_heat])

	for i in range(_heat_buttons.size()):
		var b := _heat_buttons[i]
		if i == current_heat:
			b.modulate = Color(1.2, 1.2, 1.2)
		else:
			b.modulate = Color(0.7, 0.7, 0.7)


func _on_synthesize_pressed() -> void:
	if cauldron_contents.is_empty():
		_status_label.text = "Adicione elementos antes de tentar sintetizar!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		return

	var result := ChemistryDB.evaluate(cauldron_contents, current_heat)

	match result.get("type", ""):
		"success":
			var product: String = result["product"]
			var amount: int = result["amount"]
			var recipe: Dictionary = result["recipe"]
			var is_new := GameState.discover(product)
			GameState.add(product, amount)
			_fx.celebrate(ChemistryDB.color_of(product))
			cauldron_contents.clear()
			_update_cauldron_ui()
			_refresh_reservoirs()

			_status_label.text = "Sucesso! Você sintetizou %s (%s)!" % [ChemistryDB.name_of(product), ChemistryDB.formula_of(product)]
			_status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
			_card_modal.display(product, recipe)

		"needs_heat":
			_fx.puff(Color(0.8, 0.8, 0.8), 0.5)
			_status_label.text = result["message"]
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

		"fail":
			_fx.puff(Color(0.12, 0.12, 0.14), 1.0)
			_status_label.text = result["message"]
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

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
	# Atualiza os números nos frascos
	for c in _reservoirs_container.get_children():
		if c is BenchReservoir:
			c.bump()
