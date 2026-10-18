class_name CauldronFX
extends Node2D

const ChemistryDB = preload("res://scripts/core/chemistry_db.gd")

## Efeitos do caldeirão desenhados sobre a arte de fundo (coordenadas da imagem 1376x768):

## líquido com a cor da mistura, bolhas, brilho do fogo e partículas (fumaça, faíscas, explosão).

const MOUTH_CENTER := Vector2(690, 324)
const MOUTH_RADIUS := Vector2(98, 34)
const FIRE_CENTER := Vector2(688, 566)

var heat: int = 0
var highlight: bool = false
## 0..1 — bolhas extras enquanto a reação acontece
var agitation: float = 0.0

var _liquid_color := Color(0.3, 0.6, 1.0)
var _fill := 0.0
var _fill_vis := 0.0
var _heat_vis := 0.0
var _highlight_vis := 0.0
var _t := 0.0
var _spawn_acc := 0.0
var _bubbles: Array[Dictionary] = []

var _glow: Node2D
var _smoke: CPUParticles2D
var _splash: CPUParticles2D
var _sparks: CPUParticles2D
var _blast: CPUParticles2D
var _steam: CPUParticles2D


func _ready() -> void:
	# Brilho do fogo em modo aditivo, desenhado num nó próprio
	_glow = Node2D.new()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add_mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)

	var soft := _soft_circle_texture()

	_steam = _make_particles(18, 2.6, soft)
	_steam.one_shot = false
	_steam.explosiveness = 0.0
	_steam.emission_rect_extents = Vector2(70, 6)
	_steam.initial_velocity_min = 15.0
	_steam.initial_velocity_max = 35.0
	_steam.scale_amount_min = 1.2
	_steam.scale_amount_max = 2.4
	_steam.color = Color(1, 1, 1, 0.16)

	_smoke = _make_particles(70, 2.4, soft)
	_smoke.scale_amount_min = 2.0
	_smoke.scale_amount_max = 4.0

	_splash = _make_particles(16, 0.7, null)
	_splash.position = MOUTH_CENTER + Vector2(0, -4)
	_splash.emission_rect_extents = Vector2(30, 4)
	_splash.spread = 50.0
	_splash.gravity = Vector2(0, 420)
	_splash.initial_velocity_min = 90.0
	_splash.initial_velocity_max = 170.0
	_splash.scale_amount_min = 3.0
	_splash.scale_amount_max = 5.0
	_splash.explosiveness = 0.95

	_sparks = _make_particles(60, 1.6, null)
	_sparks.spread = 55.0
	_sparks.gravity = Vector2(0, 160)
	_sparks.initial_velocity_min = 140.0
	_sparks.initial_velocity_max = 300.0
	_sparks.scale_amount_min = 3.0
	_sparks.scale_amount_max = 6.0
	_sparks.explosiveness = 0.85
	_sparks.angular_velocity_min = -200.0
	_sparks.angular_velocity_max = 200.0

	_blast = _make_particles(140, 1.8, soft)
	_blast.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_blast.emission_sphere_radius = 40.0
	_blast.spread = 180.0
	_blast.gravity = Vector2(0, -60)
	_blast.initial_velocity_min = 180.0
	_blast.initial_velocity_max = 480.0
	_blast.damping_min = 120.0
	_blast.damping_max = 200.0
	_blast.scale_amount_min = 2.5
	_blast.scale_amount_max = 6.0
	_blast.explosiveness = 1.0
	var fire_ramp := Gradient.new()
	fire_ramp.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	fire_ramp.set_color(1, Color(0.1, 0.08, 0.08, 0.0))
	fire_ramp.add_point(0.25, Color(1.0, 0.5, 0.15, 0.95))
	fire_ramp.add_point(0.6, Color(0.25, 0.2, 0.2, 0.7))
	_blast.color_ramp = fire_ramp


## Atualiza cor/nível do líquido a partir do conteúdo {id: quantidade}
func set_contents(contents: Dictionary, max_units: int) -> void:
	var total := 0
	var mix := Color(0, 0, 0, 0)
	for id: String in contents:
		var n := int(contents[id])
		total += n
		var c := ChemistryDB.color_of(id)
		mix += Color(c.r * n, c.g * n, c.b * n, n)
	if total > 0:
		_liquid_color = Color(mix.r / total, mix.g / total, mix.b / total, 1.0)
		_fill = 0.35 + 0.65 * clampf(float(total) / max_units, 0.0, 1.0)
	else:
		_fill = 0.0


func splash(color: Color) -> void:
	_splash.color = color.lightened(0.2)
	_fire(_splash)


func puff(color: Color, amount: float = 1.0) -> void:
	_smoke.color = color
	_smoke.amount = maxi(8, int(70 * amount))
	_fire(_smoke)


func celebrate(color: Color) -> void:
	puff(Color(color.lightened(0.5), 0.8), 0.6)
	_sparks.color = Color(1.0, 0.86, 0.45)
	_fire(_sparks)


func explode() -> void:
	_fire(_blast)
	_sparks.color = Color(1.0, 0.6, 0.2)
	_fire(_sparks)
	puff(Color(0.05, 0.05, 0.06, 0.95), 1.0)


func _fire(p: CPUParticles2D) -> void:
	p.restart()
	p.emitting = true


func _process(delta: float) -> void:
	_t += delta
	_fill_vis = move_toward(_fill_vis, _fill, delta * 1.5)
	_heat_vis = move_toward(_heat_vis, float(heat), delta * 3.0)
	_highlight_vis = move_toward(_highlight_vis, 1.0 if highlight else 0.0, delta * 6.0)

	_steam.emitting = _fill_vis > 0.05 and heat >= 2
	_update_bubbles(delta)
	queue_redraw()
	_glow.queue_redraw()


func _update_bubbles(delta: float) -> void:
	if _fill_vis > 0.05:
		var rate := _heat_vis * 5.0 + agitation * 40.0 + 0.6
		_spawn_acc += rate * delta
		while _spawn_acc >= 1.0:
			_spawn_acc -= 1.0
			var a := randf() * TAU
			var r := sqrt(randf()) * 0.8
			_bubbles.append({
				"pos": Vector2(cos(a) * MOUTH_RADIUS.x * r, sin(a) * MOUTH_RADIUS.y * r * 0.8),
				"size": randf_range(2.5, 6.0 + agitation * 4.0),
				"life": 0.0,
				"max": randf_range(0.5, 1.1),
			})
	for i in range(_bubbles.size() - 1, -1, -1):
		var b := _bubbles[i]
		b["life"] = float(b["life"]) + delta
		if float(b["life"]) >= float(b["max"]):
			_bubbles.remove_at(i)


func _liquid_center() -> Vector2:
	return MOUTH_CENTER + Vector2(0, (1.0 - _fill_vis) * 12.0)


func _draw() -> void:
	# líquido
	if _fill_vis > 0.02:
		var center := _liquid_center()
		var rx := MOUTH_RADIUS.x * (0.86 + 0.12 * _fill_vis)
		var ry := MOUTH_RADIUS.y * (0.78 + 0.18 * _fill_vis)
		var alpha := clampf(_fill_vis * 2.0, 0.0, 1.0)
		var wobble := 1.5 + _heat_vis * 0.8 + agitation * 3.0
		draw_colored_polygon(_ellipse(center, Vector2(rx, ry), wobble), Color(_liquid_color.darkened(0.35), alpha))
		draw_colored_polygon(_ellipse(center + Vector2(-6, -3), Vector2(rx * 0.86, ry * 0.72), wobble), Color(_liquid_color, alpha))
		draw_colored_polygon(_ellipse(center + Vector2(-28, -8), Vector2(rx * 0.3, ry * 0.18), 0.0), Color(1, 1, 1, 0.28 * alpha))
		# bolhas
		for b in _bubbles:
			var k := float(b["life"]) / float(b["max"])
			var p: Vector2 = center + b["pos"]
			var s: float = float(b["size"]) * (0.4 + k)
			draw_circle(p, s, Color(_liquid_color.lightened(0.35), 0.55 * (1.0 - k) * alpha))
			draw_arc(p, s, 0, TAU, 12, Color(1, 1, 1, 0.6 * (1.0 - k) * alpha), 1.2)

	# destaque da borda ao arrastar um frasco por cima
	if _highlight_vis > 0.01:
		var pulse := 0.7 + 0.3 * sin(_t * 8.0)
		var rim := _ellipse(MOUTH_CENTER + Vector2(0, -6), MOUTH_RADIUS + Vector2(22, 16), 0.0)
		rim.append(rim[0])
		draw_polyline(rim, Color(1.0, 0.85, 0.4, 0.9 * _highlight_vis * pulse), 4.0, true)
		draw_polyline(rim, Color(1.0, 0.95, 0.7, 0.35 * _highlight_vis), 10.0, true)


func _draw_glow() -> void:
	if _heat_vis <= 0.01:
		return
	var flick := 1.0 + sin(_t * 13.0) * 0.06 + sin(_t * 7.3) * 0.05
	var strength := _heat_vis / 3.0
	for i in range(6):
		var r := (36.0 + _heat_vis * 26.0) * (1.0 - i * 0.14) * flick
		_glow.draw_circle(FIRE_CENTER, r, Color(1.0, 0.45 + i * 0.07, 0.12, 0.05 + 0.05 * strength))
	# reflexo do fogo no bojo do caldeirão
	_glow.draw_set_transform(FIRE_CENTER + Vector2(0, -60), 0.0, Vector2(1.0, 0.45))
	_glow.draw_circle(Vector2.ZERO, 120.0 * flick, Color(1.0, 0.4, 0.1, 0.06 * strength))
	_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(center: Vector2, radius: Vector2, wobble: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	const N := 48
	for i in range(N):
		var a := TAU * i / N
		var w := sin(a * 5.0 + _t * 3.0) * wobble
		pts.append(center + Vector2(cos(a) * (radius.x + w), sin(a) * (radius.y + w * 0.4)))
	return pts


func _make_particles(amount: int, lifetime: float, texture: Texture2D) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.55
	p.texture = texture
	p.position = MOUTH_CENTER + Vector2(0, -10)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(80, 10)
	p.direction = Vector2(0, -1)
	p.spread = 22.0
	p.gravity = Vector2(0, -35)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	var grow := Curve.new()
	grow.max_value = 2.0
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)
	return p


func _soft_circle_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32
	return tex
