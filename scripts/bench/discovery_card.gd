class_name DiscoveryCard
extends Control

const ChemistryDB = preload("res://scripts/core/chemistry_db.gd")

## Modal de celebração e revelação de nova carta/composto químico sintetizado.


signal closed

const GOLD := Color(0.95, 0.82, 0.38)
const BG_DARK := Color(0.08, 0.07, 0.12, 0.94)

var _t: float = 0.0
var _card_panel: PanelContainer
var _title_label: Label
var _formula_label: Label
var _name_label: Label
var _equation_label: Label
var _lesson_label: Label
var _close_btn: Button


func _ready() -> void:
	custom_minimum_size = Vector2(1280, 720)
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	_build_ui()
	hide()


func _build_ui() -> void:
	# Fundo escuro com desfoque
	var bg := ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.75)
	add_child(bg)

	# Container central
	var center := CenterContainer.new()
	center.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center)

	_card_panel = PanelContainer.new()
	_card_panel.custom_minimum_size = Vector2(460, 560)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = BG_DARK
	card_style.set_corner_radius_all(16)
	card_style.set_border_width_all(3)
	card_style.border_color = GOLD
	card_style.shadow_color = Color(GOLD, 0.35)
	card_style.shadow_size = 28
	_card_panel.add_theme_stylebox_override("panel", card_style)
	center.add_child(_card_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	_card_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "✦ NOVA CARTA QUÍMICA! ✦"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", GOLD)
	vbox.add_child(_title_label)

	# Orbe com fórmula
	var orb_center := CenterContainer.new()
	orb_center.custom_minimum_size = Vector2(0, 140)
	vbox.add_child(orb_center)

	var orb := Panel.new()
	orb.custom_minimum_size = Vector2(120, 120)
	var orb_style := StyleBoxFlat.new()
	orb_style.bg_color = Color(0.18, 0.35, 0.65, 0.95)
	orb_style.set_corner_radius_all(60)
	orb_style.set_border_width_all(4)
	orb_style.border_color = Color.WHITE
	orb_style.shadow_color = Color(0.25, 0.65, 1.0, 0.6)
	orb_style.shadow_size = 22
	orb.add_theme_stylebox_override("panel", orb_style)
	orb_center.add_child(orb)

	_formula_label = Label.new()
	_formula_label.text = "H₂O"
	_formula_label.set_anchors_preset(PRESET_FULL_RECT)
	_formula_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formula_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_formula_label.add_theme_font_size_override("font_size", 42)
	_formula_label.add_theme_color_override("font_color", Color.WHITE)
	_formula_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_formula_label.add_theme_constant_override("outline_size", 8)
	orb.add_child(_formula_label)

	_name_label = Label.new()
	_name_label.text = "Água (Solvente Universal)"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_name_label)

	# Equação
	var eq_panel := PanelContainer.new()
	var eq_style := StyleBoxFlat.new()
	eq_style.bg_color = Color(0.12, 0.1, 0.18, 0.85)
	eq_style.set_corner_radius_all(8)
	eq_style.set_border_width_all(1)
	eq_style.border_color = Color(0.4, 0.4, 0.5, 0.5)
	eq_panel.add_theme_stylebox_override("panel", eq_style)
	vbox.add_child(eq_panel)

	var eq_margin := MarginContainer.new()
	eq_margin.add_theme_constant_override("margin_left", 12)
	eq_margin.add_theme_constant_override("margin_right", 12)
	eq_margin.add_theme_constant_override("margin_top", 8)
	eq_margin.add_theme_constant_override("margin_bottom", 8)
	eq_panel.add_child(eq_margin)

	_equation_label = Label.new()
	_equation_label.text = "2 H + O → H₂O"
	_equation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equation_label.add_theme_font_size_override("font_size", 16)
	_equation_label.add_theme_color_override("font_color", Color(0.65, 0.88, 1.0))
	eq_margin.add_child(_equation_label)

	# Lição didática
	_lesson_label = Label.new()
	_lesson_label.text = "Dois hidrogênios para cada oxigênio! A água é o solvente universal."
	_lesson_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lesson_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lesson_label.add_theme_font_size_override("font_size", 13)
	_lesson_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.88))
	vbox.add_child(_lesson_label)

	# Espaçador flexível
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Botão Guardar
	_close_btn = Button.new()
	_close_btn.text = "Guardar no Grimório"
	_close_btn.custom_minimum_size = Vector2(0, 42)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.72, 0.54, 0.18)
	btn_style.set_corner_radius_all(8)
	_close_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = GOLD
	_close_btn.add_theme_stylebox_override("hover", btn_hover)
	_close_btn.add_theme_font_size_override("font_size", 15)
	_close_btn.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
	_close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(_close_btn)


func display(product_id: String, recipe: Dictionary) -> void:
	var sub := ChemistryDB.get_substance(product_id)
	_formula_label.text = sub["formula"]
	_name_label.text = sub["name"]
	_equation_label.text = recipe.get("equation", "")
	_lesson_label.text = recipe.get("lesson", sub["info"])
	show()


func _on_close_pressed() -> void:
	hide()
	closed.emit()
