class_name SaltCrystal
extends StaticBody2D

## Barreira de Sal (NaCl): pode ser dissolvida pela jogadora usando 1× Água (H₂O)
## sintetizada na Bancada de Mendeleev, liberando a passagem com animação de solvatação.

signal dissolved

const DISSOLVE_SHADER := preload("res://assets/shaders/salt_dissolve.gdshader")
const PIXEL_FONT := preload("res://assets/fonts/PixelifySans-Bold.ttf")

@export var interaction_radius: float = 48.0
@export var dissolve_duration: float = 1.15

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D_0

var _player_in_range: bool = false
var _is_dissolving: bool = false
var _prompt_root: Node2D
var _prompt_label: Label
var _warning_timer: float = 0.0
var _base_sprite_pos: Vector2


func _ready() -> void:
	_base_sprite_pos = sprite.position
	_setup_interaction_zone()
	_setup_prompt()
	GameState.inventory_changed.connect(_refresh_prompt)


func _process(delta: float) -> void:
	if _warning_timer > 0.0:
		_warning_timer -= delta
		if _warning_timer <= 0.0:
			_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _is_dissolving or not _player_in_range:
		return
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		_try_dissolve()
		get_viewport().set_input_as_handled()


func _setup_interaction_zone() -> void:
	var zone := Area2D.new()
	zone.name = "InteractionZone"
	zone.position = Vector2(0, -15)
	zone.monitoring = true
	zone.monitorable = false
	zone.collision_layer = 0
	zone.collision_mask = 1

	var shape := CircleShape2D.new()
	shape.radius = interaction_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	zone.add_child(col)

	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)
	add_child(zone)


func _setup_prompt() -> void:
	_prompt_root = Node2D.new()
	_prompt_root.name = "PromptAnchor"
	_prompt_root.position = Vector2(0, -68)
	_prompt_root.z_index = 25
	_prompt_root.visible = false
	add_child(_prompt_root)

	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(-140, -18)
	_prompt_label.size = Vector2(280, 36)
	_prompt_label.add_theme_font_override("font", PIXEL_FONT)
	_prompt_label.add_theme_font_size_override("font_size", 12)
	_prompt_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.1, 0.96))
	_prompt_label.add_theme_constant_override("outline_size", 5)
	_prompt_root.add_child(_prompt_label)


func _on_body_entered(body: Node2D) -> void:
	if _is_dissolving or not body.is_in_group("player"):
		return
	_player_in_range = true
	_refresh_prompt()
	_prompt_root.visible = true


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_range = false
	_warning_timer = 0.0
	if _prompt_root:
		_prompt_root.visible = false


func _refresh_prompt() -> void:
	if not _prompt_label or _is_dissolving or _warning_timer > 0.0:
		return
	if GameState.get_count("H2O") >= 1:
		_prompt_label.text = "[E] Dissolver Sal com H₂O"
		_prompt_label.add_theme_color_override("font_color", Color(0.45, 0.95, 1.0))
	else:
		_prompt_label.text = "Sal (NaCl) — Precisa de H₂O [Bancada B]"
		_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))


func _try_dissolve() -> void:
	if not GameState.take("H2O", 1):
		_show_missing_water_feedback()
		return
	_play_dissolve_animation()


func _show_missing_water_feedback() -> void:
	_warning_timer = 1.6
	if _prompt_label:
		_prompt_label.text = "Sem H₂O! Colete 2 H + 1 O e sintetize [B]"
		_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.42))

	var shake := create_tween()
	shake.tween_property(sprite, "position:x", _base_sprite_pos.x - 4.0, 0.04)
	shake.tween_property(sprite, "position:x", _base_sprite_pos.x + 4.0, 0.05)
	shake.tween_property(sprite, "position:x", _base_sprite_pos.x - 3.0, 0.05)
	shake.tween_property(sprite, "position:x", _base_sprite_pos.x, 0.04)


func _play_dissolve_animation() -> void:
	_is_dissolving = true
	_player_in_range = false
	if _prompt_root:
		_prompt_root.visible = false

	var mat := ShaderMaterial.new()
	mat.shader = DISSOLVE_SHADER
	mat.set_shader_parameter("dissolve_amount", 0.0)
	sprite.material = mat

	_spawn_dissolve_particles()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		func(val: float) -> void:
			mat.set_shader_parameter("dissolve_amount", val),
		0.0,
		1.0,
		dissolve_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite, "scale", Vector2(0.56, 0.34), dissolve_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position:y", _base_sprite_pos.y + 10.0, dissolve_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Libera a passagem assim que o cristal derrete o suficiente
	get_tree().create_timer(dissolve_duration * 0.7).timeout.connect(func() -> void:
		if is_instance_valid(collision_shape):
			collision_shape.disabled = true
	)

	await tween.finished
	sprite.visible = false
	dissolved.emit()

	# Aguarda partículas terminarem antes de remover o nó
	await get_tree().create_timer(0.85).timeout
	queue_free()


func _spawn_dissolve_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.name = "DissolveParticles"
	particles.position = Vector2(0, -22)
	particles.z_index = 10
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 0.85
	particles.explosiveness = 0.25
	particles.direction = Vector2(0, -1)
	particles.spread = 160.0
	particles.initial_velocity_min = 18.0
	particles.initial_velocity_max = 54.0
	particles.gravity = Vector2(0, 65.0)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.5

	var grad := Gradient.new()
	grad.set_color(0, Color(0.85, 0.98, 1.0, 0.95))
	grad.add_point(0.45, Color(0.35, 0.86, 1.0, 0.85))
	grad.set_color(1, Color(0.25, 0.72, 0.98, 0.0))
	particles.color_ramp = grad

	add_child(particles)
