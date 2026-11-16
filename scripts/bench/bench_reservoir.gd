class_name BenchReservoir
extends Control

const ChemistryDB = preload("res://scripts/core/chemistry_db.gd")
const PIXEL_FONT := preload("res://assets/fonts/PixelifySans-Bold.ttf")

## Reservatório (frasco) de um elemento/composto na bancada.
## Arraste até o caldeirão (drag & drop) ou clique para adicionar 1 unidade (point & click).

signal quick_add(substance_id: String)

const JAR_SIZE := Vector2(68, 86)
const FULL_AT := 8.0
const COL_GOLD := Color(0.95, 0.78, 0.36)
const COL_TEXT := Color(0.98, 0.93, 0.82)

var substance_id: String = ""

var _hover := false
var _lift := 0.0
var _pulse := 0.0
var _t := randf() * 10.0


func setup(id: String) -> void:
	substance_id = id
	var data := ChemistryDB.get_substance(id)
	tooltip_text = "%s (%s)\n%s\n[Clique ou arraste até o caldeirão]" % [data["name"], data["formula"], data["info"]]


func _init() -> void:
	custom_minimum_size = Vector2(88, 126)
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
	if PIXEL_FONT:
		label.add_theme_font_override("font", PIXEL_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
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
	var font: Font = PIXEL_FONT if PIXEL_FONT else get_theme_default_font()

	var lift := -6.0 * _lift - 4.0 * sin(_pulse * PI)
	var jar := Rect2(Vector2((size.x - JAR_SIZE.x) / 2.0, 20.0 + lift), JAR_SIZE)

	# Sombra no tampo de madeira da bancada
	draw_set_transform(Vector2(size.x / 2.0, 20.0 + JAR_SIZE.y + 3.0), 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 32.0 - 4.0 * _lift, Color(0, 0, 0, 0.50))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Brilho ao passar o mouse
	if _lift > 0.01:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(col, 0.0)
		glow.set_corner_radius_all(16)
		glow.shadow_color = Color(col, 0.50 * _lift)
		glow.shadow_size = 16
		draw_style_box(glow, jar)

	# Gargalo + Rolha de cortiça
	var neck := Rect2(jar.position.x + jar.size.x * 0.30, jar.position.y - 12.0, jar.size.x * 0.40, 15.0)
	draw_style_box(_glass_style(5), neck)
	var cork := Rect2(neck.position.x - 2.0, neck.position.y - 9.0, neck.size.x + 4.0, 11.0)
	var cork_style := StyleBoxFlat.new()
	cork_style.bg_color = Color(0.58, 0.38, 0.21)
	cork_style.set_corner_radius_all(3)
	cork_style.border_color = Color(0.28, 0.16, 0.08)
	cork_style.set_border_width_all(2)
	draw_style_box(cork_style, cork)

	# Líquido / Reagente (altura proporcional à quantidade)
	var inner := jar.grow(-5.0)
	if not empty:
		var ratio := clampf(count / FULL_AT, 0.0, 1.0)
		var h := inner.size.y * (0.16 + 0.84 * ratio)
		var liquid := Rect2(inner.position.x, inner.end.y - h, inner.size.x, h)
		var ls := StyleBoxFlat.new()
		ls.bg_color = Color(col, 0.90)
		ls.corner_radius_bottom_left = 10
		ls.corner_radius_bottom_right = 10
		ls.corner_radius_top_left = 3
		ls.corner_radius_top_right = 3
		draw_style_box(ls, liquid)
		# Superfície ondulando
		var wave := PackedVector2Array()
		for i in range(13):
			var x := liquid.position.x + liquid.size.x * i / 12.0
			wave.append(Vector2(x, liquid.position.y + 1.5 + sin(_t * 3.0 + i * 0.9) * 1.2))
		draw_polyline(wave, col.lightened(0.45), 2.0)

	# Vidro por cima
	draw_style_box(_glass_style(13), jar)
	draw_rect(Rect2(jar.position.x + 7.0, jar.position.y + 9.0, 4.0, jar.size.y * 0.55), Color(1, 1, 1, 0.25))

	# Símbolo Químico
	var sym: String = data["formula"]
	var fsize := 26 if sym.length() <= 2 else 21
	var sym_pos := Vector2(jar.position.x, jar.get_center().y + fsize * 0.35)
	draw_string_outline(font, sym_pos, sym, HORIZONTAL_ALIGNMENT_CENTER, jar.size.x, fsize, 6, Color(0, 0, 0, 0.88))
	draw_string(font, sym_pos, sym, HORIZONTAL_ALIGNMENT_CENTER, jar.size.x, fsize, Color(1, 1, 1, 0.35) if empty else Color.WHITE)

	# Contador de unidades
	var badge := Vector2(jar.end.x - 2.0, jar.position.y + 2.0)
	draw_circle(badge, 12.5, Color(0.12, 0.08, 0.16))
	draw_arc(badge, 12.5, 0.0, TAU, 28, Color(0.85, 0.3, 0.3) if empty else COL_GOLD, 2.0, true)
	draw_string(font, badge + Vector2(-12.5, 5.0), str(count), HORIZONTAL_ALIGNMENT_CENTER, 25.0, 13, COL_GOLD if not empty else Color(0.9, 0.5, 0.5))

	# Nome da substância
	var name_col := COL_TEXT if not empty else Color(COL_TEXT, 0.48)
	draw_string_outline(font, Vector2(0, size.y - 3.0), data["name"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, 4, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(0, size.y - 3.0), data["name"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, name_col)


func _glass_style(radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.82, 0.92, 1.0, 0.12)
	s.set_corner_radius_all(radius)
	s.set_border_width_all(2)
	s.border_color = Color(0.92, 0.97, 1.0, 0.65)
	return s
