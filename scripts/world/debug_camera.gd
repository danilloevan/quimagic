class_name DebugCamera
extends Camera2D

@export var move_speed: float = 650.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.3
@export var max_zoom: float = 2.5
@export var map_generator: MapGenerator

@onready var info_label: Label = $CanvasLayer/PanelContainer/MarginContainer/InfoLabel


func _ready() -> void:
	# Centralizar a câmera no meio do mapa por padrão
	if map_generator:
		position = Vector2(map_generator.map_width * 16, map_generator.map_height * 16)
		map_generator.map_generated.connect(_on_map_generated)
		_update_label(map_generator.seed_val)


func _process(delta: float) -> void:
	var move_vec = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_vec.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_vec.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_vec.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_vec.x += 1.0
	
	if move_vec != Vector2.ZERO:
		position += move_vec.normalized() * (move_speed / zoom.x) * delta


func _unhandled_input(event: InputEvent) -> void:
	# Zoom com a roda do mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom_level(zoom.x + zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom_level(zoom.x - zoom_speed)
	
	# Regenerar mapa com a tecla R
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and map_generator:
			var next_seed = randi() % 1000000
			map_generator.set_seed_and_generate(next_seed)


func _set_zoom_level(new_zoom: float) -> void:
	var clamped = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(clamped, clamped)


func _on_map_generated(current_seed: int) -> void:
	_update_label(current_seed)


func _update_label(current_seed: int) -> void:
	if info_label:
		info_label.text = "Quimagic — Protótipo de Cenário Procedural (Godot 4)\n" + \
			"Semente Atual: %d\n" % current_seed + \
			"[WASD / Setas] Mover Câmera | [Scroll] Zoom | [R] Nova Semente Procedural"
