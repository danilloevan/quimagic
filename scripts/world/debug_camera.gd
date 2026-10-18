class_name DebugCamera
extends Camera2D

@export var move_speed: float = 650.0
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.3
@export var max_zoom: float = 4.0
@export var map_generator: MapGenerator
## Alvo seguido pela câmera (personagem). [Tab] alterna para câmera livre de debug.
@export var target: Node2D
@export var follow_zoom: float = 2.5

var free_mode: bool = false

@onready var info_label: Label = $CanvasLayer/PanelContainer/MarginContainer/InfoLabel


func _ready() -> void:
	if map_generator:
		# Centralizar a câmera no meio do mapa por padrão
		position = Vector2(map_generator.map_width * 16, map_generator.map_height * 16)
		map_generator.map_generated.connect(_on_map_generated)
	_set_free_mode(target == null)
	_snap_to_target()
	_update_label()


func _process(delta: float) -> void:
	if not free_mode and target:
		global_position = target.global_position + Vector2(0, -12)
		return

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
	
	if event is InputEventKey and event.pressed and not event.echo:
		# Regenerar mapa com a tecla R
		if event.keycode == KEY_R and map_generator:
			var next_seed = randi() % 1000000
			map_generator.set_seed_and_generate(next_seed)
		# Alternar entre seguir a personagem e câmera livre
		elif event.keycode == KEY_TAB and target:
			_set_free_mode(not free_mode)


func _set_free_mode(enabled: bool) -> void:
	free_mode = enabled
	if target and "input_enabled" in target:
		target.set("input_enabled", not enabled)
	# Suavização e limites só no modo "seguir": no modo livre o mapa todo fica acessível
	position_smoothing_enabled = not enabled
	position_smoothing_speed = 7.0
	if enabled or not map_generator:
		limit_left = -10000000
		limit_top = -10000000
		limit_right = 10000000
		limit_bottom = 10000000
	else:
		var map_size := Vector2(map_generator.map_width, map_generator.map_height) * map_generator.tile_size
		var origin := map_generator.global_position
		limit_left = int(origin.x)
		limit_top = int(origin.y)
		limit_right = int(origin.x + map_size.x)
		limit_bottom = int(origin.y + map_size.y)
		_set_zoom_level(follow_zoom)
	_update_label()


func _snap_to_target() -> void:
	if target and not free_mode:
		global_position = target.global_position + Vector2(0, -12)
		reset_smoothing()


func _set_zoom_level(new_zoom: float) -> void:
	var clamped = clamp(new_zoom, min_zoom, max_zoom)
	zoom = Vector2(clamped, clamped)


func _on_map_generated(_current_seed: int) -> void:
	_snap_to_target()
	_update_label()


func _update_label() -> void:
	if not info_label:
		return
	var current_seed := map_generator.seed_val if map_generator else 0
	var controls := "[WASD / Setas] Mover Câmera" if free_mode else "[WASD / Setas] Andar"
	if target:
		controls += " | [Tab] " + ("Seguir Personagem" if free_mode else "Câmera Livre")
	info_label.text = "Quimagic — Protótipo de Cenário Procedural (Godot 4)\n" + \
		"Semente Atual: %d\n" % current_seed + \
		controls + " | [B] Bancada Alquímica | [Scroll] Zoom | [R] Nova Semente"

