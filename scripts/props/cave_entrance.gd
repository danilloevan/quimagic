class_name CaveEntrance
extends StaticBody2D

## Entrada da Caverna: detecta quando a jogadora atravessa o portal desobstruído
## e dispara o encerramento da demonstração.

signal player_entered

var _triggered: bool = false


func _ready() -> void:
	add_to_group("cave_entrance")
	_setup_entrance_trigger()


func _setup_entrance_trigger() -> void:
	var trigger := Area2D.new()
	trigger.name = "EntranceTrigger"
	trigger.position = Vector2(0, -28)
	trigger.monitoring = true
	trigger.monitorable = false
	trigger.collision_layer = 0
	trigger.collision_mask = 1

	var shape := RectangleShape2D.new()
	shape.size = Vector2(44, 24)
	var col := CollisionShape2D.new()
	col.shape = shape
	trigger.add_child(col)

	trigger.body_entered.connect(_on_body_entered)
	add_child(trigger)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	player_entered.emit()
