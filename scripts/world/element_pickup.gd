class_name ElementPickup
extends Area2D

const ChemistryDB = preload("res://scripts/core/chemistry_db.gd")

## Coletável de elemento químico no mapa top-down (H, O, Na, Cl, C).
## Ao encostar (ou se aproximar dentro do raio magnético), adiciona o elemento ao GameState
## para uso na Bancada de Mendeleev.

signal collected(element_id: String, amount: int)

@export var element_id: String = "H":
	set(value):
		element_id = value
		_refresh_visuals()

@export var amount: int = 1
@export var pickup_radius: float = 15.0
@export var magnet_radius: float = 42.0
@export var magnet_speed: float = 185.0

var _collected: bool = false
var _time: float = 0.0
var _symbol_label: Label
var _collision_shape: CollisionShape2D


func _init() -> void:
	_time = randf() * TAU


func _ready() -> void:
	add_to_group("element_pickups")
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1

	_ensure_nodes()
	_refresh_visuals()
	body_entered.connect(_on_body_entered)


func setup(id: String, qty: int = 1) -> void:
	element_id = id
	amount = maxi(qty, 1)
	_refresh_visuals()


func _ensure_nodes() -> void:
	if not _collision_shape:
		_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		var shape := CircleShape2D.new()
		shape.radius = pickup_radius
		_collision_shape.shape = shape
		add_child(_collision_shape)
	elif _collision_shape.shape is CircleShape2D:
		(_collision_shape.shape as CircleShape2D).radius = pickup_radius

	if not _symbol_label:
		_symbol_label = get_node_or_null("SymbolLabel") as Label
	if not _symbol_label:
		_symbol_label = Label.new()
		_symbol_label.name = "SymbolLabel"
		_symbol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_symbol_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_symbol_label.position = Vector2(-18, -28)
		_symbol_label.size = Vector2(36, 20)
		_symbol_label.add_theme_font_size_override("font_size", 11)
		_symbol_label.add_theme_color_override("font_color", Color.WHITE)
		_symbol_label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 0.95))
		_symbol_label.add_theme_constant_override("outline_size", 4)
		add_child(_symbol_label)


func _refresh_visuals() -> void:
	if _symbol_label:
		_symbol_label.text = ChemistryDB.formula_of(element_id)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _collected:
		return

	_time += delta
	var bob := sin(_time * 3.0) * 2.5
	if _symbol_label:
		_symbol_label.position.y = -30.0 + bob

	# Atração magnética suave quando a jogadora se aproxima
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		var to_player := player.global_position - global_position
		var dist := to_player.length()
		if dist <= pickup_radius:
			_collect()
			return
		if dist < magnet_radius and dist > 0.001:
			var pull := (1.0 - dist / magnet_radius) * 0.65 + 0.35
			global_position += to_player.normalized() * magnet_speed * pull * delta

	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _collected:
		return
	if body and body.is_in_group("player"):
		_collect()


func _collect() -> void:
	if _collected:
		return
	_collected = true
	set_deferred("monitoring", false)

	var gs := get_node_or_null("/root/GameState")
	if gs:
		gs.add(element_id, amount)
	collected.emit(element_id, amount)
	_spawn_floating_feedback()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.45, 1.45), 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)


func _spawn_floating_feedback() -> void:
	var host := get_parent()
	if not host:
		return
	var data := ChemistryDB.get_substance(element_id)
	var col: Color = data["color"]

	var lbl := Label.new()
	lbl.text = "+%d %s (%s)" % [amount, data["formula"], data["name"]]
	lbl.position = position + Vector2(-70, -40)
	lbl.size = Vector2(140, 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 50
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", col.lightened(0.25))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.95))
	lbl.add_theme_constant_override("outline_size", 4)
	host.add_child(lbl)

	var tw := lbl.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 26.0, 0.85).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.85).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)


func _draw() -> void:
	var col := ChemistryDB.color_of(element_id)
	var bob := sin(_time * 3.0) * 2.5
	var pulse := 0.5 + 0.5 * sin(_time * 4.2)
	var center := Vector2(0.0, -10.0 + bob)

	# Sombra no chão
	draw_set_transform(Vector2(0.0, 1.0), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 9.0 - bob * 0.3, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Aura pulsante
	draw_circle(center, 14.0 + pulse * 2.5, Color(col.r, col.g, col.b, 0.16 + pulse * 0.08))
	draw_circle(center, 9.5 + pulse * 1.2, Color(col.r, col.g, col.b, 0.28))

	# Cristal hexagonal facetado
	var crystal := PackedVector2Array([
		center + Vector2(0.0, -9.5),
		center + Vector2(7.0, -3.5),
		center + Vector2(5.5, 6.5),
		center + Vector2(0.0, 9.5),
		center + Vector2(-5.5, 6.5),
		center + Vector2(-7.0, -3.5),
	])
	draw_colored_polygon(crystal, col)

	# Faceta iluminada superior esquerda
	var highlight := PackedVector2Array([
		center + Vector2(0.0, -9.5),
		center + Vector2(0.0, 0.0),
		center + Vector2(-7.0, -3.5),
	])
	draw_colored_polygon(highlight, col.lightened(0.45))

	# Contorno nítido
	var outline := crystal.duplicate()
	outline.append(crystal[0])
	draw_polyline(outline, col.darkened(0.45), 1.4, true)

	# Partícula orbital sutil
	var orbit := Vector2(cos(_time * 2.4) * 11.5, sin(_time * 2.4) * 5.5)
	draw_circle(center + orbit, 1.8, Color(1.0, 1.0, 1.0, 0.85))
