class_name World
extends Node2D

const BenchView = preload("res://scripts/bench/bench_view.gd")

## Controlador principal do mundo de jogo.

## Conecta a exploração top-down e o modo de síntese alquímica na bancada (tecla B).

@onready var map_generator: MapGenerator = $MapGenerator
@onready var player: Player = $MapGenerator/PropsContainer/Player
@onready var debug_camera: DebugCamera = $DebugCamera

var bench_view: BenchView
var _bench_hud_btn: Button
var _inventory_hud_label: Label


func _ready() -> void:
	_create_hud()
	_create_bench()


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)

	# Painel de atalho no topo superior direito
	var top_right := MarginContainer.new()
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.add_theme_constant_override("margin_top", 14)
	top_right.add_theme_constant_override("margin_right", 18)
	canvas.add_child(top_right)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	top_right.add_child(hbox)

	_bench_hud_btn = Button.new()
	_bench_hud_btn.text = "⚗ Abrir Bancada [B]"
	_bench_hud_btn.custom_minimum_size = Vector2(165, 40)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.1, 0.18, 0.92)
	btn_style.set_corner_radius_all(8)
	btn_style.set_border_width_all(2)
	btn_style.border_color = Color(0.95, 0.82, 0.38)
	_bench_hud_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.25, 0.2, 0.32, 0.95)
	_bench_hud_btn.add_theme_stylebox_override("hover", btn_hover)
	_bench_hud_btn.add_theme_font_size_override("font_size", 14)
	_bench_hud_btn.add_theme_color_override("font_color", Color(0.95, 0.82, 0.38))
	_bench_hud_btn.pressed.connect(_toggle_bench)
	hbox.add_child(_bench_hud_btn)

	# Painel de resumo de elementos no canto superior esquerdo (abaixo do info label)
	var top_left := MarginContainer.new()
	top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_left.position = Vector2(16, 86)
	canvas.add_child(top_left)

	var inv_panel := PanelContainer.new()
	var inv_style := StyleBoxFlat.new()
	inv_style.bg_color = Color(0.08, 0.07, 0.12, 0.8)
	inv_style.set_corner_radius_all(8)
	inv_panel.add_theme_stylebox_override("panel", inv_style)
	top_left.add_child(inv_panel)

	var inv_margin := MarginContainer.new()
	inv_margin.add_theme_constant_override("margin_left", 12)
	inv_margin.add_theme_constant_override("margin_right", 12)
	inv_margin.add_theme_constant_override("margin_top", 8)
	inv_margin.add_theme_constant_override("margin_bottom", 8)
	inv_panel.add_child(inv_margin)

	_inventory_hud_label = Label.new()
	_inventory_hud_label.add_theme_font_size_override("font_size", 13)
	inv_margin.add_child(_inventory_hud_label)

	GameState.inventory_changed.connect(_update_inventory_hud)
	_update_inventory_hud()


func _create_bench() -> void:
	var bench_scene := load("res://scenes/bench/bench_view.tscn") as PackedScene
	bench_view = bench_scene.instantiate() as BenchView
	bench_view.visible = false
	bench_view.closed.connect(_on_bench_closed)
	add_child(bench_view)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_bench") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B):
		_toggle_bench()
		get_viewport().set_input_as_handled()


func _toggle_bench() -> void:
	if bench_view.visible:
		bench_view.close_bench()
	else:
		_open_bench()


func _open_bench() -> void:
	if player:
		player.input_enabled = false
	bench_view.open_bench()


func _on_bench_closed() -> void:
	if player and (not debug_camera or not debug_camera.free_mode):
		player.input_enabled = true


func _update_inventory_hud() -> void:
	if not _inventory_hud_label:
		return
	var text := "Elementos: "
	var items: PackedStringArray = []
	for id: String in ["H", "O", "Na", "Cl", "C"]:
		items.append("%s: %d" % [id, GameState.get_count(id)])
	text += " | ".join(items)
	var compounds: PackedStringArray = []
	if GameState.is_discovered("H2O"):
		compounds.append("💧 H₂O: %d" % GameState.get_count("H2O"))
	if GameState.is_discovered("NaCl"):
		compounds.append("🧂 NaCl: %d" % GameState.get_count("NaCl"))
	if GameState.is_discovered("CO2"):
		compounds.append("💨 CO₂: %d" % GameState.get_count("CO2"))
	if not compounds.is_empty():
		text += " | " + " | ".join(compounds)
	_inventory_hud_label.text = text

	if _bench_hud_btn:
		if _has_craftable_recipe():
			_bench_hud_btn.text = "⚗ Bancada Pronta! [B]"
		else:
			_bench_hud_btn.text = "⚗ Abrir Bancada [B]"


func _has_craftable_recipe() -> bool:
	return (GameState.get_count("H") >= 2 and GameState.get_count("O") >= 1) \
		or (GameState.get_count("Na") >= 1 and GameState.get_count("Cl") >= 1) \
		or (GameState.get_count("C") >= 1 and GameState.get_count("O") >= 2)
