class_name CauldronDropZone
extends Control

## Área de soltura sobre o caldeirão: recebe os frascos arrastados.

signal substance_dropped(substance_id: String)
signal hover_changed(active: bool)

var _hovering := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Caldeirão — solte os frascos aqui"


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok: bool = (data is Dictionary) and String((data as Dictionary).get("type", "")) == "substance"
	_set_hover(ok)
	return ok



func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_hover(false)
	substance_dropped.emit(String((data as Dictionary)["id"]))


func _process(_delta: float) -> void:
	# Garante que o destaque some ao sair da área ou ao terminar o arraste
	if _hovering:
		var inside := Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
		if not inside or not get_viewport().gui_is_dragging():
			_set_hover(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_hover(false)


func _set_hover(value: bool) -> void:
	if _hovering == value:
		return
	_hovering = value
	hover_changed.emit(value)
