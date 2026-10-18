class_name BenchReservoir
extends Control

const ChemistryDB = preload("res://scripts/core/chemistry_db.gd")

## Reservatório (frasco) de um elemento/composto na bancada.

## Arraste até o caldeirão (drag & drop) ou clique para adicionar 1 unidade (point & click).

signal quick_add(substance_id: String)

const JAR_SIZE := Vector2(74, 98)
const FULL_AT := 8.0
const COL_GOLD := Color(0.88, 0.69, 0.35)
const COL_TEXT := Color(0.95, 0.9, 0.78)

var substance_id: String = ""

var _hover := false
var _lift := 0.0
var _pulse := 0.0
var _t := randf() * 10.0


func setup(id: String) -> void:
	substance_id = id
	var data := ChemistryDB.get_substance(id)
	tooltip_text = "%s (%s)\n%s" % [data["name"], data["formula"], data["info"]]


func _init() -> void:
	custom_minimum_size = Vector2(92, 142)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)


## Pequeno "pulo" visual quando a quantidade muda
func bump() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if _hover and _count() > 0 else 0.0
	_lift = move_toward(_lift, target, delta * 7.0)
	_pulse = move_toward(_pulse, 0.0, delta * 3.0)
	queue_redraw()


func _count() -> int:
	return GameState.get_count(substance_id)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		quick_add.emit(substance_id)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _count() <= 0:
		return null
	set_drag_preview(_make_preview())
	return {"type": "substance", "id": substance_id}


func _make_preview() -> Control:
	var col := ChemistryDB.color_of(substance_id)
	var holder := Control.new()
	var orb := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(col, 0.92)
	style.set_corner_radius_all(30)
	style.set_border_width_all(3)
	style.border_color = Color(1, 1, 1, 0.85)
	style.shadow_color = Color(col, 0.55)
	style.shadow_size = 14
	orb.add_theme_stylebox_override("panel", style)
	orb.size = Vector2(60, 60)
	orb.position = -orb.size / 2.0
	var label := Label.new()
	label.text = ChemistryDB.formula_of(substance_id)
	label.size = orb.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	orb.add_child(label)
	holder.add_child(orb)
	holder.rotation = -0.12
	return holder


func _draw() -> void:
	var data := ChemistryDB.get_substance(substance_id)
	var col: Color = data["color"]
	var count := _count()
	var empty := count <= 0
	var font := get_theme_default_font()

	var lift := -7.0 * _lift - 4.0 * sin(_pulse * PI)
	var jar := Rect2(Vector2((size.x - JAR_SIZE.x) / 2.0, 26.0 + lift), JAR_SIZE)

	# sombra no tampo da mesa
	draw_set_transform(Vector2(size.x / 2.0, 26.0 + JAR_SIZE.y + 3.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 34.0 - 4.0 * _lift, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# brilho ao passar o mouse
	if _lift > 0.01:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(col, 0.0)
		glow.set_corner_radius_all(18)
		glow.shadow_color = Color(col, 0.45 * _lift)
		glow.shadow_size = 18
		draw_style_box(glow, jar)

	# gargalo + rolha
	var neck := Rect2(jar.position.x + jar.size.x * 0.31, jar.position.y - 14.0, jar.size.x * 0.38, 18.0)
	draw_style_box(_glass_style(6), neck)
	var cork := Rect2(neck.position.x - 3.0, neck.position.y - 10.0, neck.size.x + 6.0, 12.0)
	var cork_style := StyleBoxFlat.new()
	cork_style.bg_color = Color(0.55, 0.36, 0.2)
	cork_style.set_corner_radius_all(3)
	cork_style.border_color = Color(0.33, 0.2, 0.1)
	cork_style.set_border_width_all(1)
	draw_style_box(cork_style, cork)

	# líquido (altura proporcional à quantidade)
	var inner := jar.grow(-5.0)
	if not empty:
		var ratio := clampf(count / FULL_AT, 0.0, 1.0)
		var h := inner.size.y * (0.14 + 0.86 * ratio)
		var liquid := Rect2(inner.position.x, inner.end.y - h, inner.size.x, h)
		var ls := StyleBoxFlat.new()
		ls.bg_color = Color(col, 0.88)
		ls.corner_radius_bottom_left = 10
		ls.corner_radius_bottom_right = 10
		ls.corner_radius_top_left = 3
		ls.corner_radius_top_right = 3
		draw_style_box(ls, liquid)
		# superfície ondulando
		var wave := PackedVector2Array()
		for i in range(13):
			var x := liquid.position.x + liquid.size.x * i / 12.0
			wave.append(Vector2(x, liquid.position.y + 1.5 + sin(_t * 3.0 + i * 0.9) * 1.2))
		draw_polyline(wave, col.lightened(0.45), 2.0)

	# vidro por cima
	draw_style_box(_glass_style(14), jar)
	draw_rect(Rect2(jar.position.x + 8.0, jar.position.y + 10.0, 4.0, jar.size.y * 0.55), Color(1, 1, 1, 0.22))

	# símbolo
	var sym: String = data["formula"]
	var fsize := 30 if sym.length() <= 2 else 24
	var sym_pos := Vector2(jar.position.x, jar.get_center().y + fsize * 0.35)
	draw_string_outline(font, sym_pos, sym, HORIZONTAL_ALIGNMENT_CENTER, jar.size.x, fsize, 7, Color(0, 0, 0, 0.8))
	draw_string(font, sym_pos, sym, HORIZONTAL_ALIGNMENT_CENTER, jar.size.x, fsize, Color(1, 1, 1, 0.35) if empty else Color.WHITE)

	# contador
	var badge := Vector2(jar.end.x - 2.0, jar.position.y + 2.0)
	draw_circle(badge, 13.0, Color(0.1, 0.07, 0.17))
	draw_arc(badge, 13.0, 0.0, TAU, 28, Color(0.85, 0.3, 0.3) if empty else COL_GOLD, 2.0, true)
	draw_string(font, badge + Vector2(-13.0, 5.0), str(count), HORIZONTAL_ALIGNMENT_CENTER, 26.0, 14, COL_GOLD if not empty else Color(0.9, 0.5, 0.5))

	# nome
	var name_col := COL_TEXT if not empty else Color(COL_TEXT, 0.45)
	draw_string_outline(font, Vector2(0, size.y - 4.0), data["name"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, 5, Color(0, 0, 0, 0.75))
	draw_string(font, Vector2(0, size.y - 4.0), data["name"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, name_col)


func _glass_style(radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.8, 0.9, 1.0, 0.1)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(2)
	s.border_color = Color(0.9, 0.96, 1.0, 0.6)
	return s
