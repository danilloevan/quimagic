class_name FurnaceLever
extends Control

## Alavanca interativa do Forno Alquímico (inspirada no controle Aquecer / Esfriar).
## Permite arrastar continuamente entre:
##   +1.0 (Aquecer Máximo — Fogo Forte)
##    0.0 (Neutro / Fogo Apagado)
##   -1.0 (Esfriar Máximo — Gelo no Forno)

signal value_changed(new_value: float, discrete_level: int)

const PIXEL_FONT := preload("res://assets/fonts/PixelifySans-Bold.ttf")

## Valor contínuo da alavanca: -1.0 (Gelo Máx) .. 0.0 (Apagado) .. +1.0 (Fogo Máx)
var value: float = 0.34
var _vis_value: float = 0.34
var _dragging: bool = false
var _hovering: bool = false
var _t: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(148, 172)
	size = Vector2(148, 172)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Alavanca do Forno: Arraste para cima (Aquecer com Fogo) ou para baixo (Esfriar com Gelo)"


func _ready() -> void:
	mouse_entered.connect(func() -> void: _hovering = true)
	mouse_exited.connect(func() -> void: _hovering = false)


func set_lever_value(new_val: float, emit_sig: bool = true) -> void:
	var clamped := clampf(new_val, -1.0, 1.0)
	if is_equal_approx(value, clamped):
		return
	value = clamped
	if emit_sig:
		value_changed.emit(value, get_discrete_level())
	queue_redraw()


func set_discrete_level(level: int, emit_sig: bool = true) -> void:
	var target := 0.0
	match clampi(level, -2, 3):
		-2: target = -1.0
		-1: target = -0.52
		0: target = 0.0
		1: target = 0.34
		2: target = 0.68
		3: target = 1.0
	set_lever_value(target, emit_sig)


func get_discrete_level() -> int:
	if value <= -0.72:
		return -2
	elif value <= -0.16:
		return -1
	elif value < 0.14:
		return 0
	elif value < 0.50:
		return 1
	elif value < 0.84:
		return 2
	else:
		return 3


func get_temperature_celsius() -> float:
	if value >= 0.0:
		# 0.0 -> 25°C, 0.34 -> ~85°C, 0.68 -> ~175°C, 1.0 -> 300°C
		return 25.0 + pow(value, 1.25) * 275.0
	else:
		# 0.0 -> 25°C, -0.5 -> -2°C, -1.0 -> -25°C
		return 25.0 - pow(-value, 0.9) * 50.0


func _process(delta: float) -> void:
	_t += delta
	_vis_value = move_toward(_vis_value, value, delta * 10.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_update_from_local_y(mb.position.y)
				accept_event()
			else:
				_dragging = false
				accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			set_lever_value(value + 0.14)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			set_lever_value(value - 0.14)
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_update_from_local_y(mm.position.y)
		accept_event()


func _track_top() -> float:
	return 32.0


func _track_bottom() -> float:
	return size.y - 32.0


func _track_center_y() -> float:
	return (_track_top() + _track_bottom()) * 0.5


func _value_to_y(v: float) -> float:
	var top := _track_top()
	var bot := _track_bottom()
	var t := (1.0 - clampf(v, -1.0, 1.0)) * 0.5
	return lerpf(top, bot, t)


func _update_from_local_y(local_y: float) -> void:
	var top := _track_top()
	var bot := _track_bottom()
	var norm := 1.0 - 2.0 * clampf((local_y - top) / maxf(1.0, bot - top), 0.0, 1.0)
	# Pequena trava (snap) no centro (0 = Desligado) para facilitar apagar o fogo
	if absf(norm) < 0.07:
		norm = 0.0
	set_lever_value(norm)


func _draw() -> void:
	var font: Font = PIXEL_FONT if PIXEL_FONT else get_theme_default_font()
	var top_y := _track_top()
	var bot_y := _track_bottom()
	var mid_y := _track_center_y()
	var knob_y := _value_to_y(_vis_value)
	var track_x := 88.0

	# 1. Haste mecânica de ferro conectando a caixa da alavanca ao forno à esquerda
	var rod_target := Vector2(-18.0, mid_y + (_vis_value * -14.0))
	var rod_origin := Vector2(18.0, knob_y)
	draw_line(rod_target, rod_origin, Color(0.08, 0.06, 0.05, 0.95), 10.0)
	draw_line(rod_target, rod_origin, Color(0.38, 0.34, 0.32, 1.0), 6.0)
	draw_line(rod_target + Vector2(0, -1), rod_origin + Vector2(0, -1), Color(0.62, 0.56, 0.50, 0.8), 2.0)

	# 2. Corpo metálico/pedra do controlador do forno (inspirado no balde do PhET, mas em estilo medieval pixel-art)
	var body_pts := PackedVector2Array([
		Vector2(6, 4),
		Vector2(size.x - 4, 4),
		Vector2(size.x - 10, size.y - 4),
		Vector2(12, size.y - 4),
	])
	var shadow_pts := PackedVector2Array()
	for p in body_pts:
		shadow_pts.append(p + Vector2(3, 5))
	draw_colored_polygon(shadow_pts, Color(0, 0, 0, 0.52))
	draw_colored_polygon(body_pts, Color(0.22, 0.19, 0.24, 0.97))

	# Faixa de brilho metálico interno no corpo
	var inner_pts := PackedVector2Array([
		Vector2(10, 8),
		Vector2(size.x - 8, 8),
		Vector2(size.x - 14, size.y - 8),
		Vector2(16, size.y - 8),
	])
	draw_colored_polygon(inner_pts, Color(0.30, 0.27, 0.33, 0.95))

	# Borda de bronze/ouro velho ao redor do controlador
	var border_col := Color(0.88, 0.69, 0.34) if (_hovering or _dragging) else Color(0.62, 0.46, 0.22)
	var closed_pts := body_pts.duplicate()
	closed_pts.append(body_pts[0])
	draw_polyline(closed_pts, Color(0.08, 0.06, 0.05), 5.0)
	draw_polyline(closed_pts, border_col, 2.5)

	# Rebites nos 4 cantos
	for rv in [Vector2(15, 13), Vector2(size.x - 13, 13), Vector2(size.x - 19, size.y - 13), Vector2(21, size.y - 13)]:
		draw_circle(rv + Vector2(1, 1), 3.2, Color(0.08, 0.06, 0.05))
		draw_circle(rv, 2.8, Color(0.75, 0.60, 0.32))
		draw_circle(rv + Vector2(-0.8, -0.8), 1.0, Color(1.0, 0.92, 0.68))

	# 3. Rótulos "Aquecer" (topo) e "Esfriar" (base) + marcações laterais (como na imagem de inspiração)
	var heat_active := clampf(_vis_value, 0.0, 1.0)
	var cool_active := clampf(-_vis_value, 0.0, 1.0)

	var top_col := Color(0.88, 0.78, 0.68).lerp(Color(1.0, 0.48, 0.15), heat_active)
	draw_string_outline(font, Vector2(12, 24), "Aquecer", HORIZONTAL_ALIGNMENT_LEFT, 68, 13, 4, Color(0.06, 0.04, 0.04, 0.95))
	draw_string(font, Vector2(12, 24), "Aquecer", HORIZONTAL_ALIGNMENT_LEFT, 68, 13, top_col)

	var mid_col := Color(0.85, 0.84, 0.80) if absf(_vis_value) < 0.12 else Color(0.58, 0.56, 0.60)
	draw_string_outline(font, Vector2(16, mid_y + 5), "Apagar", HORIZONTAL_ALIGNMENT_LEFT, 58, 11, 3, Color(0.06, 0.04, 0.04, 0.9))
	draw_string(font, Vector2(16, mid_y + 5), "Apagar", HORIZONTAL_ALIGNMENT_LEFT, 58, 11, mid_col)

	var bot_col := Color(0.78, 0.86, 0.95).lerp(Color(0.28, 0.86, 1.0), cool_active)
	draw_string_outline(font, Vector2(16, size.y - 12), "Esfriar", HORIZONTAL_ALIGNMENT_LEFT, 66, 13, 4, Color(0.06, 0.04, 0.04, 0.95))
	draw_string(font, Vector2(16, size.y - 12), "Esfriar", HORIZONTAL_ALIGNMENT_LEFT, 66, 13, bot_col)

	# 4. Fenda / Trilho Vertical colorido (Vermelho em cima para Aquecer, Azul embaixo para Esfriar)
	var slot_w := 14.0
	var slot_rect := Rect2(track_x - slot_w * 0.5, top_y, slot_w, bot_y - top_y)
	draw_rect(slot_rect.grow(3.0), Color(0.07, 0.06, 0.09))

	# Metade superior (Vermelho/Laranja - Aquecer)
	var steps := 12
	var half_h := (bot_y - top_y) * 0.5
	for i in range(steps):
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var y0 := lerpf(mid_y, top_y, t1)
		var y1 := lerpf(mid_y, top_y, t0)
		var c_hot := Color(0.42, 0.12, 0.25).lerp(Color(0.96, 0.18, 0.12), t1)
		if _vis_value > t0:
			c_hot = c_hot.lightened(0.18 * heat_active)
		draw_rect(Rect2(slot_rect.position.x, y0, slot_w, y1 - y0 + 0.6), c_hot)

	# Metade inferior (Azul/Ciano - Esfriar com Gelo)
	for i in range(steps):
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var y0 := lerpf(mid_y, bot_y, t0)
		var y1 := lerpf(mid_y, bot_y, t1)
		var c_cold := Color(0.26, 0.14, 0.45).lerp(Color(0.08, 0.52, 0.98), t1)
		if -_vis_value > t0:
			c_cold = c_cold.lightened(0.22 * cool_active)
		draw_rect(Rect2(slot_rect.position.x, y0, slot_w, y1 - y0 + 0.6), c_cold)

	# Borda interna da fenda
	draw_rect(slot_rect, Color(0.05, 0.04, 0.07), false, 2.0)

	# Traços de graduação (ticks) ao lado da fenda, idênticos à referência
	var tick_levels := [1.0, 0.66, 0.33, 0.0, -0.5, -1.0]
	for lv: float in tick_levels:
		var ty := _value_to_y(lv)
		var is_major := is_equal_approx(absf(lv), 1.0) or is_zero_approx(lv)
		var tick_len := 12.0 if is_major else 7.0
		var tick_col := Color(0.95, 0.90, 0.78) if is_major else Color(0.65, 0.62, 0.68)
		draw_line(Vector2(slot_rect.position.x - tick_len - 2, ty), Vector2(slot_rect.position.x - 2, ty), tick_col, 2.0 if is_major else 1.5)
		draw_line(Vector2(slot_rect.end.x + 2, ty), Vector2(slot_rect.end.x + 2 + tick_len * 0.7, ty), tick_col, 2.0 if is_major else 1.5)

	# 5. Alavanca / Puxador deslizante (Manopla Azul-Clara / Metálica com linha central como na imagem)
	var knob_w := 44.0
	var knob_h := 22.0
	var knob_rect := Rect2(track_x - knob_w * 0.5, knob_y - knob_h * 0.5, knob_w, knob_h)

	# Sombra da manopla
	var shadow_box := StyleBoxFlat.new()
	shadow_box.bg_color = Color(0, 0, 0, 0.55)
	shadow_box.set_corner_radius_all(6)
	draw_style_box(shadow_box, knob_rect.grow(1.0).abs())

	# Cor dinâmica da manopla (ciano metálico no neutro/frio, âmbar brilhante no quente, como no PhET)
	var knob_base := Color(0.48, 0.86, 0.98)
	if _vis_value > 0.08:
		knob_base = knob_base.lerp(Color(1.0, 0.76, 0.36), clampf(_vis_value * 0.85, 0.0, 1.0))
	elif _vis_value < -0.08:
		knob_base = knob_base.lerp(Color(0.32, 0.92, 1.0), clampf(-_vis_value, 0.0, 1.0))

	if _hovering or _dragging:
		knob_base = knob_base.lightened(0.14)

	var knob_style := StyleBoxFlat.new()
	knob_style.bg_color = knob_base
	knob_style.set_corner_radius_all(6)
	knob_style.set_border_width_all(2)
	knob_style.border_color = Color(0.08, 0.08, 0.12)
	if _hovering or _dragging:
		knob_style.shadow_color = Color(knob_base, 0.55)
		knob_style.shadow_size = 8
	draw_style_box(knob_style, knob_rect)

	# Brilho superior na manopla
	draw_rect(Rect2(knob_rect.position.x + 4, knob_rect.position.y + 3, knob_rect.size.x - 8, 4), Color(1, 1, 1, 0.45))
	# Ranhura central da alavanca (igual à imagem de referência)
	draw_line(
		Vector2(knob_rect.position.x + 5, knob_y),
		Vector2(knob_rect.end.x - 5, knob_y),
		Color(0.12, 0.22, 0.30, 0.9),
		2.2
	)
