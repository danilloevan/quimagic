class_name Player
extends CharacterBody2D

## Personagem jogável: movimento top-down em 8 direções (WASD / setas).
## Animação de caminhada em 4 direções e pose parada em 8 direções.

@export var move_speed: float = 85.0
## Aceleração/desaceleração (px/s²) — deixa o movimento suave sem perder resposta
@export var acceleration: float = 900.0
@export var friction: float = 1100.0
## Velocidade de referência da animação de caminhada (acima disso ela acelera proporcionalmente)
@export var walk_anim_reference_speed: float = 85.0
## Referência opcional ao gerador para bloquear água e bordas do mapa
@export var map_generator: MapGenerator

## Quando falso, a personagem ignora o teclado (ex.: câmera livre de debug ativa)
var input_enabled: bool = true

var _facing: Vector2 = Vector2.DOWN

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	sprite.play("idle_south")


func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if input_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	_block_unwalkable(delta)
	move_and_slide()
	_update_animation(input_dir)


## Impede entrar na água/fora do mapa testando o ponto dos pés no próximo frame.
## Testa os eixos separadamente para a personagem "deslizar" ao longo da margem.
func _block_unwalkable(delta: float) -> void:
	if not map_generator or velocity == Vector2.ZERO:
		return
	var next := global_position + velocity * delta
	if map_generator.is_world_pos_walkable(next):
		return
	var only_x := global_position + Vector2(velocity.x * delta, 0.0)
	var only_y := global_position + Vector2(0.0, velocity.y * delta)
	if velocity.x != 0.0 and map_generator.is_world_pos_walkable(only_x):
		velocity.y = 0.0
	elif velocity.y != 0.0 and map_generator.is_world_pos_walkable(only_y):
		velocity.x = 0.0
	else:
		velocity = Vector2.ZERO


func _update_animation(input_dir: Vector2) -> void:
	var moving := input_dir != Vector2.ZERO and velocity.length() > 5.0

	if moving:
		_facing = input_dir
		var anim := "walk_" + _walk_direction(input_dir)
		if sprite.animation != anim:
			sprite.play(anim)
		sprite.speed_scale = maxf(velocity.length() / walk_anim_reference_speed, 0.4)
	else:
		sprite.speed_scale = 1.0
		var idle := "idle_" + _idle_direction(_facing)
		if sprite.animation != idle:
			sprite.play(idle)


## Caminhada só tem 4 direções: escolhe o eixo dominante. Em diagonais perfeitas mantém a
## animação atual se ela ainda for coerente, evitando que o sprite fique "piscando".
func _walk_direction(dir: Vector2) -> String:
	var horizontal := "east" if dir.x > 0.0 else "west"
	var vertical := "south" if dir.y > 0.0 else "north"
	if is_zero_approx(dir.y):
		return horizontal
	if is_zero_approx(dir.x):
		return vertical
	var current := sprite.animation.trim_prefix("walk_")
	if current == horizontal or current == vertical:
		return current
	return horizontal if absf(dir.x) >= absf(dir.y) else vertical


## Pose parada em 8 direções (os PNGs de rotação cobrem as diagonais)
func _idle_direction(dir: Vector2) -> String:
	const NAMES := ["east", "south_east", "south", "south_west", "west", "north_west", "north", "north_east"]
	var octant := wrapi(roundi(dir.angle() / (PI / 4.0)), 0, 8)
	return NAMES[octant]


## Posiciona instantaneamente (spawn / regeneração do mapa)
func teleport(world_pos: Vector2) -> void:
	global_position = world_pos
	velocity = Vector2.ZERO
	_facing = Vector2.DOWN
	sprite.play("idle_south")
