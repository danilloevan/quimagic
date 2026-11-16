class_name CauldronFX
extends Node2D

const ChemistryDB = preload("res://scripts/core/chemistry_db.gd")
const PIXEL_FONT := preload("res://assets/fonts/PixelifySans-Bold.ttf")

## Efeitos procedurais do Caldeirão, Forno Alquímico (Fogo e Gelo) e Termômetro.
## Calibrado para o viewport 1280x720 e inspirado no Figma (node 2010:74) e simulador térmico.

const MOUTH_CENTER := Vector2(639, 302)
const MOUTH_RADIUS := Vector2(96, 35)
const FURNACE_CENTER := Vector2(639, 532)
const THERM_CENTER := Vector2(796, 276)

## Nível discreto (-2 = Gelo Máx, -1 = Esfriar, 0 = Apagado, 1 = Baixo, 2 = Médio, 3 = Alto)
var heat: int = 1:
	set(v):
		heat = clampi(v, -2, 3)
		match heat:
			-2: thermal_level = -1.0
			-1: thermal_level = -0.52
			0: thermal_level = 0.0
			1: thermal_level = 0.34
			2: thermal_level = 0.68
			3: thermal_level = 1.0

## Nível contínuo da alavanca (-1.0 = Gelo Máximo .. 0.0 = Apagado .. +1.0 = Fogo Máximo)
var thermal_level: float = 0.34
var highlight: bool = false
var agitation: float = 0.0

var _liquid_color := Color(0.22, 0.62, 0.98)
var _has_reagents := false
var _fill := 0.28
var _fill_vis := 0.28
var _therm_vis := 0.34
var _temp_c_vis := 85.0
var _highlight_vis := 0.0
var _t := 0.0
var _spawn_acc := 0.0
var _ember_acc := 0.0
var _bubbles: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
var _frost_motes: Array[Dictionary] = []

var _glow: Node2D
var _smoke: CPUParticles2D
var _splash: CPUParticles2D
var _sparks: CPUParticles2D
var _blast: CPUParticles2D
var _steam: CPUParticles2D


func _ready() -> void:
	# Brilho aditivo do fogo ou do gelo num nó próprio
	_glow = Node2D.new()
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add_mat
	_glow.draw.connect(_draw_glow)
	add_child(_glow)

	var soft := _soft_circle_texture()

	_steam = _make_particles(22, 2.6, soft)
	_steam.one_shot = false
	_steam.explosiveness = 0.0
	_steam.emission_rect_extents = Vector2(68, 6)
	_steam.initial_velocity_min = 18.0
	_steam.initial_velocity_max = 42.0
	_steam.scale_amount_min = 1.2
	_steam.scale_amount_max = 2.6
	_steam.color = Color(0.82, 0.92, 1.0, 0.18)

	_smoke = _make_particles(70, 2.4, soft)
	_smoke.scale_amount_min = 2.0
	_smoke.scale_amount_max = 4.0

	_splash = _make_particles(18, 0.7, null)
	_splash.position = MOUTH_CENTER + Vector2(0, -4)
	_splash.emission_rect_extents = Vector2(34, 5)
	_splash.spread = 52.0
	_splash.gravity = Vector2(0, 420)
	_splash.initial_velocity_min = 95.0
	_splash.initial_velocity_max = 175.0
	_splash.scale_amount_min = 3.0
	_splash.scale_amount_max = 5.5
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


func set_thermal_continuous(val: float, discrete_lvl: int) -> void:
	var prev_heat := heat
	heat = clampi(discrete_lvl, -2, 3)
	thermal_level = clampf(val, -1.0, 1.0)
	# Solta uma leve fumaça ao apagar o fogo completamente
	if prev_heat > 0 and heat == 0:
		puff(Color(0.55, 0.55, 0.60, 0.35), 0.22)


func get_temperature_celsius() -> float:
	return _temp_c_vis


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
		_has_reagents = true
		_liquid_color = Color(mix.r / total, mix.g / total, mix.b / total, 1.0)
		_fill = 0.45 + 0.55 * clampf(float(total) / max_units, 0.0, 1.0)
	else:
		_has_reagents = false
		_liquid_color = Color(0.20, 0.58, 0.95, 1.0)
		_fill = 0.28


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


func _target_temperature_c() -> float:
	if thermal_level >= 0.0:
		return 25.0 + pow(thermal_level, 1.25) * 275.0
	else:
		return 25.0 - pow(-thermal_level, 0.9) * 50.0


func _process(delta: float) -> void:
	_t += delta
	_fill_vis = move_toward(_fill_vis, _fill, delta * 2.0)
	_therm_vis = move_toward(_therm_vis, thermal_level, delta * 5.2)
	_temp_c_vis = move_toward(_temp_c_vis, _target_temperature_c(), delta * 520.0)
	_highlight_vis = move_toward(_highlight_vis, 1.0 if highlight else 0.0, delta * 6.0)

	_steam.emitting = _fill_vis > 0.05 and _therm_vis > 0.25
	_update_bubbles(delta)
	_update_furnace_particles(delta)
	queue_redraw()
	_glow.queue_redraw()


func _update_bubbles(delta: float) -> void:
	var heat_pos := maxf(0.0, _therm_vis)
	# Quando está congelando (_therm_vis < -0.2), as bolhas param de surgir
	if _fill_vis > 0.05 and _therm_vis > -0.2:
		var rate := (heat_pos * 24.0) + agitation * 42.0 + (0.8 if _therm_vis >= 0.0 else 0.0)
		_spawn_acc += rate * delta
		while _spawn_acc >= 1.0:
			_spawn_acc -= 1.0
			var a := randf() * TAU
			var r := sqrt(randf()) * 0.78
			_bubbles.append({
				"pos": Vector2(cos(a) * MOUTH_RADIUS.x * r, sin(a) * MOUTH_RADIUS.y * r * 0.82),
				"size": randf_range(3.0, 6.5 + heat_pos * 5.5 + agitation * 4.0),
				"life": 0.0,
				"max": randf_range(0.42, 0.95 - heat_pos * 0.25),
			})
	for i in range(_bubbles.size() - 1, -1, -1):
		var b := _bubbles[i]
		b["life"] = float(b["life"]) + delta
		if float(b["life"]) >= float(b["max"]):
			_bubbles.remove_at(i)


func _update_furnace_particles(delta: float) -> void:
	# Fagulhas subindo do fogo quando aquecido
	if _therm_vis > 0.08:
		var ember_rate := _therm_vis * 26.0
		_ember_acc += ember_rate * delta
		while _ember_acc >= 1.0:
			_ember_acc -= 1.0
			_embers.append({
				"pos": FURNACE_CENTER + Vector2(randf_range(-58.0, 58.0) * (0.5 + 0.5 * _therm_vis), randf_range(-6.0, 12.0)),
				"vel": Vector2(randf_range(-22.0, 22.0), -randf_range(48.0, 115.0) * (0.6 + 0.6 * _therm_vis)),
				"size": randf_range(2.0, 4.2),
				"life": 0.0,
				"max": randf_range(0.45, 0.95),
			})
	elif _therm_vis < -0.08:
		# Partículas de névoa fria e cristais de gelo quando resfriando
		var frost_rate := (-_therm_vis) * 20.0
		_ember_acc += frost_rate * delta
		while _ember_acc >= 1.0:
			_ember_acc -= 1.0
			_frost_motes.append({
				"pos": FURNACE_CENTER + Vector2(randf_range(-68.0, 68.0), randf_range(-34.0, 14.0)),
				"vel": Vector2(randf_range(-28.0, 28.0), randf_range(-18.0, 24.0)),
				"size": randf_range(2.5, 5.5),
				"life": 0.0,
				"max": randf_range(0.65, 1.3),
			})

	for i in range(_embers.size() - 1, -1, -1):
		var e := _embers[i]
		var l := float(e["life"]) + delta
		e["life"] = l
		var p: Vector2 = e["pos"]
		var v: Vector2 = e["vel"]
		e["pos"] = p + v * delta + Vector2(sin(_t * 10.0 + float(i)) * 18.0 * delta, 0)
		if l >= float(e["max"]):
			_embers.remove_at(i)

	for i in range(_frost_motes.size() - 1, -1, -1):
		var f := _frost_motes[i]
		var l := float(f["life"]) + delta
		f["life"] = l
		var p: Vector2 = f["pos"]
		var v: Vector2 = f["vel"]
		f["pos"] = p + v * delta
		if l >= float(f["max"]):
			_frost_motes.remove_at(i)


func _liquid_center() -> Vector2:
	return MOUTH_CENTER + Vector2(0, (1.0 - _fill_vis) * 10.0)


func _draw() -> void:
	# 1. Forno Alquímico sob o Caldeirão (Câmara curva, Lenha, Fogo Procedural ou Gelo Procedural)
	_draw_furnace_chamber()
	if _therm_vis > 0.01:
		_draw_procedural_fire(clampf(_therm_vis, 0.0, 1.0))
	elif _therm_vis < -0.01:
		_draw_procedural_ice(clampf(-_therm_vis, 0.0, 1.0))
	_draw_furnace_tripod_and_rim()

	# 2. Líquido, Bolhas, Crosta de Gelo e Vapor Procedural na boca do Caldeirão
	_draw_cauldron_contents()

	# 3. Termômetro Alquímico ao lado do Caldeirão (inspirado no Figma 2010:74 + PhET)
	_draw_thermometer()


func _draw_furnace_chamber() -> void:
	var heat_k := clampf(_therm_vis, 0.0, 1.0)
	var cold_k := clampf(-_therm_vis, 0.0, 1.0)

	# Bacia circular/elíptica do braseiro do forno encaixada exatamente entre as pernas do tripé
	var basin_outer := _ellipse(Vector2(639, 535), Vector2(114, 38), 0.0)
	draw_colored_polygon(basin_outer, Color(0.18, 0.15, 0.18))
	var basin_rim := basin_outer.duplicate()
	basin_rim.append(basin_outer[0])
	draw_polyline(basin_rim, Color(0.07, 0.05, 0.06), 4.0)

	# Interior escuro da fornalha (esconde o fogo estático do background quando desligado ou com gelo)
	var pit_pts := _ellipse(Vector2(639, 534), Vector2(102, 32), 0.0)
	var pit_col := Color(0.08, 0.06, 0.08).lerp(Color(0.24, 0.08, 0.04), heat_k * 0.45).lerp(Color(0.08, 0.22, 0.36), cold_k * 0.55)
	draw_colored_polygon(pit_pts, pit_col)
	draw_polyline(pit_pts, Color(0.32, 0.26, 0.30).lerp(Color(0.45, 0.78, 0.96), cold_k * 0.6), 2.5)

	# Sombreamento da barriga inferior do caldeirão (para cobrir o reflexo laranja estático do JPG quando frio/apagado)
	var lower_belly := PackedVector2Array()
	for i in range(25):
		var t := float(i) / 24.0
		var a := lerpf(0.12 * PI, 0.88 * PI, t)
		lower_belly.append(Vector2(639.0 + cos(a) * 128.0, 444.0 + sin(a) * 62.0))
	for i in range(25):
		var t := float(24 - i) / 24.0
		var a := lerpf(0.16 * PI, 0.84 * PI, t)
		lower_belly.append(Vector2(639.0 + cos(a) * 118.0, 434.0 + sin(a) * 48.0))
	var belly_col := Color(0.26, 0.17, 0.12, 0.92).lerp(Color(0.55, 0.24, 0.08, 0.35), heat_k).lerp(Color(0.28, 0.46, 0.62, 0.92), cold_k * 0.75)
	draw_colored_polygon(lower_belly, belly_col)

	# Toras de lenha cruzadas no forno (estilo Figma 2010:74)
	var wood_dark := Color(0.24, 0.14, 0.09).lerp(Color(0.18, 0.10, 0.08), heat_k * 0.5).lerp(Color(0.26, 0.38, 0.48), cold_k * 0.55)
	var wood_light := Color(0.42, 0.25, 0.14).lerp(Color(0.98, 0.38, 0.08), heat_k * 0.8).lerp(Color(0.62, 0.88, 1.0), cold_k * 0.7)

	var logs := [
		[Vector2(560, 548), Vector2(634, 522)],
		[Vector2(718, 548), Vector2(644, 522)],
		[Vector2(580, 528), Vector2(698, 548)],
		[Vector2(594, 553), Vector2(684, 553)],
	]
	for lg in logs:
		var p0: Vector2 = lg[0]
		var p1: Vector2 = lg[1]
		draw_line(p0, p1, Color(0.06, 0.04, 0.04), 15.0, true)
		draw_line(p0, p1, wood_dark, 11.0, true)
		draw_line(p0 + Vector2(0, -2), p1 + Vector2(0, -2), wood_light, 3.8, true)
		draw_circle(p0, 6.0, wood_dark.darkened(0.2))
		draw_circle(p0, 3.2, wood_light)

	# Brasas pulsantes quando há calor
	if heat_k > 0.01:
		var pulse := 0.78 + 0.22 * sin(_t * 9.0)
		for i in range(7):
			var ex := 575.0 + i * 21.0 + sin(float(i) * 2.1) * 4.0
			var ey := 542.0 + cos(float(i) * 1.7) * 5.0
			draw_circle(Vector2(ex, ey), (5.0 + 4.5 * heat_k) * pulse, Color(1.0, 0.32, 0.06, 0.78 * heat_k))
			draw_circle(Vector2(ex, ey), (2.5 + 2.5 * heat_k) * pulse, Color(1.0, 0.88, 0.30, 0.92 * heat_k))


func _draw_procedural_fire(k: float) -> void:
	# Quanto mais quente (k -> 1.0), mais alto, largo e intenso o fogo;
	# Quanto mais frio (k -> 0.0), as chamas diminuem até se apagarem.
	var flame_count := 11
	var max_w := lerpf(30.0, 86.0, k)

	# Base ovalada de fogo envolvendo as toras para não ficar reta embaixo
	var bed_pts := _ellipse(Vector2(FURNACE_CENTER.x, 540.0), Vector2(max_w * 0.95, 14.0 + 10.0 * k), 2.2)
	draw_colored_polygon(bed_pts, Color(0.92, 0.22, 0.05, 0.85 * clampf(k * 1.5, 0.0, 1.0)))
	var inner_bed := _ellipse(Vector2(FURNACE_CENTER.x, 540.0), Vector2(max_w * 0.68, 9.0 + 7.0 * k), 1.8)
	draw_colored_polygon(inner_bed, Color(1.0, 0.68, 0.14, 0.88 * clampf(k * 1.5, 0.0, 1.0)))

	for layer in range(3):
		for i in range(flame_count):
			var norm_i := (float(i) / float(flame_count - 1)) * 2.0 - 1.0 # -1 .. +1
			var edge_fade := 1.0 - pow(absf(norm_i), 1.35) * lerpf(0.88, 0.28, k)
			if edge_fade <= 0.08:
				continue

			var fx := FURNACE_CENTER.x + norm_i * max_w
			# Base acompanha a curvatura elíptica da fornalha
			var base_y := 542.0 + cos(norm_i * PI * 0.5) * 10.0
			var speed := 8.5 + float(i % 3) * 2.4 + k * 5.2
			var phase := float(i) * 1.25 + float(layer) * 0.85
			var sway := sin(_t * speed + phase) * (5.0 + 12.0 * k)
			var flicker := 0.84 + 0.16 * sin(_t * (speed * 1.4) + phase * 1.7)

			var h := (16.0 + 76.0 * pow(k, 0.85)) * edge_fade * flicker
			var w := (13.0 + 21.0 * k) * edge_fade

			var col := Color(0.94, 0.20, 0.06, 0.88)
			if layer == 1:
				h *= 0.76
				w *= 0.72
				col = Color(1.0, 0.58, 0.10, 0.94)
			elif layer == 2:
				h *= 0.48
				w *= 0.46
				col = Color(1.0, 0.92, 0.35, 0.96)

			var pts := PackedVector2Array([
				Vector2(fx - w, base_y),
				Vector2(fx - w * 0.82 + sway * 0.25, base_y - h * 0.32),
				Vector2(fx - w * 0.42 + sway * 0.65, base_y - h * 0.68),
				Vector2(fx + sway, base_y - h),
				Vector2(fx + w * 0.42 + sway * 0.65, base_y - h * 0.68),
				Vector2(fx + w * 0.82 + sway * 0.25, base_y - h * 0.32),
				Vector2(fx + w, base_y),
				Vector2(fx, base_y + 6.0),
			])
			draw_colored_polygon(pts, col)

	# Núcleo branco-incandescente quando o fogo está forte
	if k > 0.42:
		var core_alpha := clampf((k - 0.42) / 0.58, 0.0, 1.0)
		var core_pts := _ellipse(Vector2(FURNACE_CENTER.x, 536.0), Vector2(42.0 * k, 13.0 * k), 2.5)
		draw_colored_polygon(core_pts, Color(1.0, 0.98, 0.84, 0.88 * core_alpha))

	# Fagulhas procedurais subindo
	for e in _embers:
		var ratio := 1.0 - float(e["life"]) / float(e["max"])
		var p: Vector2 = e["pos"]
		var sz: float = float(e["size"]) * ratio
		draw_circle(p, sz * 1.6, Color(1.0, 0.42, 0.08, 0.45 * ratio))
		draw_circle(p, sz, Color(1.0, 0.92, 0.42, 0.95 * ratio))


func _draw_procedural_ice(k: float) -> void:
	# Inspirado diretamente na imagem de referência com gelo:
	# Cubos e cristais de gelo azuis translúcidos emergem do forno sob o caldeirão!
	var base_y := 548.0
	var lift := lerpf(12.0, 58.0, pow(k, 0.85))

	# Camada de névoa gelada na base
	var mist_pts := _ellipse(Vector2(FURNACE_CENTER.x, base_y - 6.0), Vector2(88.0 + 26.0 * k, 20.0 + 10.0 * k), 1.8)
	draw_colored_polygon(mist_pts, Color(0.45, 0.86, 1.0, 0.38 * k))

	# Definição dos blocos/cubos de gelo empilhados até tocar o fundo do caldeirão
	var cubes := [
		{"dx": -66.0, "dy": -4.0, "w": 26.0, "h": 24.0, "ang": -0.18, "min_k": 0.20},
		{"dx": 66.0, "dy": -4.0, "w": 26.0, "h": 24.0, "ang": 0.18, "min_k": 0.20},
		{"dx": -42.0, "dy": -10.0, "w": 30.0, "h": 28.0, "ang": -0.10, "min_k": 0.02},
		{"dx": 42.0, "dy": -10.0, "w": 30.0, "h": 28.0, "ang": 0.12, "min_k": 0.02},
		{"dx": -14.0, "dy": -12.0, "w": 32.0, "h": 30.0, "ang": -0.06, "min_k": 0.0},
		{"dx": 16.0, "dy": -12.0, "w": 32.0, "h": 30.0, "ang": 0.08, "min_k": 0.0},
		{"dx": -52.0, "dy": -24.0, "w": 26.0, "h": 24.0, "ang": -0.22, "min_k": 0.35},
		{"dx": 52.0, "dy": -24.0, "w": 26.0, "h": 24.0, "ang": 0.22, "min_k": 0.35},
		{"dx": -24.0, "dy": -28.0, "w": 30.0, "h": 28.0, "ang": 0.14, "min_k": 0.28},
		{"dx": 24.0, "dy": -28.0, "w": 30.0, "h": 28.0, "ang": -0.14, "min_k": 0.28},
		{"dx": 0.0, "dy": -34.0, "w": 32.0, "h": 30.0, "ang": -0.04, "min_k": 0.42},
		{"dx": -34.0, "dy": -42.0, "w": 26.0, "h": 24.0, "ang": -0.12, "min_k": 0.58},
		{"dx": 34.0, "dy": -42.0, "w": 26.0, "h": 24.0, "ang": 0.12, "min_k": 0.58},
		{"dx": 0.0, "dy": -48.0, "w": 28.0, "h": 26.0, "ang": 0.06, "min_k": 0.68},
	]

	for c_info: Dictionary in cubes:
		var min_k := float(c_info["min_k"])
		if k <= min_k:
			continue
		var local_k := clampf((k - min_k) / maxf(0.15, 1.0 - min_k), 0.0, 1.0)
		var pos := Vector2(
			FURNACE_CENTER.x + float(c_info["dx"]),
			base_y + float(c_info["dy"]) * (0.45 + 0.55 * k) - lift * 0.22 * local_k
		)
		var sz := Vector2(float(c_info["w"]), float(c_info["h"])) * (0.58 + 0.42 * local_k)
		_draw_ice_cube(pos, sz, float(c_info["ang"]), local_k)

	# Cristais de geada / estalactites de gelo grudados na barriga inferior do caldeirão
	if k > 0.25:
		var frost_a := clampf((k - 0.25) / 0.75, 0.0, 1.0)
		for i in range(9):
			var a := lerpf(-0.75, 0.75, float(i) / 8.0)
			var rx := FURNACE_CENTER.x + sin(a) * 96.0
			var ry := 482.0 + cos(a) * 20.0
			var spike_h := (9.0 + (i % 3) * 5.0) * frost_a
			var sp_pts := PackedVector2Array([
				Vector2(rx - 5.0, ry),
				Vector2(rx + 5.0, ry),
				Vector2(rx, ry + spike_h),
			])
			draw_colored_polygon(sp_pts, Color(0.72, 0.95, 1.0, 0.88 * frost_a))

	# Partículas de ar congelante e flocos brilhantes
	for f in _frost_motes:
		var ratio := 1.0 - float(f["life"]) / float(f["max"])
		var p: Vector2 = f["pos"]
		var sz: float = float(f["size"]) * (0.6 + 0.4 * ratio)
		draw_circle(p, sz * 1.8, Color(0.35, 0.82, 1.0, 0.28 * ratio))
		draw_line(p + Vector2(-sz, 0), p + Vector2(sz, 0), Color(0.92, 0.99, 1.0, 0.85 * ratio), 1.5)
		draw_line(p + Vector2(0, -sz), p + Vector2(0, sz), Color(0.92, 0.99, 1.0, 0.85 * ratio), 1.5)


func _draw_ice_cube(center: Vector2, sz: Vector2, angle: float, alpha_scale: float) -> void:
	draw_set_transform(center, angle, Vector2.ONE)
	var hw := sz.x * 0.5
	var hh := sz.y * 0.5
	var rect := Rect2(-hw, -hh, sz.x, sz.y)

	# Corpo azul-gelo translúcido
	var cube_style := StyleBoxFlat.new()
	cube_style.bg_color = Color(0.18, 0.68, 0.98, 0.88 * alpha_scale)
	cube_style.set_corner_radius_all(5)
	cube_style.set_border_width_all(2)
	cube_style.border_color = Color(0.78, 0.96, 1.0, 0.92 * alpha_scale)
	draw_style_box(cube_style, rect)

	# Faceta superior clara
	var top_facet := PackedVector2Array([
		Vector2(-hw + 3, -hh + 3),
		Vector2(hw - 3, -hh + 3),
		Vector2(hw - 7, -hh + hh * 0.65),
		Vector2(-hw + 5, -hh + hh * 0.65),
	])
	draw_colored_polygon(top_facet, Color(0.58, 0.92, 1.0, 0.72 * alpha_scale))

	# Reflexo diagonal branco (brilho cristalino)
	draw_line(
		Vector2(-hw + 5, -hh + 6),
		Vector2(-hw + sz.x * 0.55, hh - 6),
		Color(0.95, 1.0, 1.0, 0.85 * alpha_scale),
		2.2
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_furnace_tripod_and_rim() -> void:
	# Redesenha a curva inferior do caldeirão e as 3 pernas do tripé de ferro na frente do fogo/gelo
	var belly_bottom := PackedVector2Array()
	for i in range(25):
		var t := float(i) / 24.0
		var a := lerpf(0.14 * PI, 0.86 * PI, t)
		belly_bottom.append(Vector2(639.0 + cos(a) * 125.0, 445.0 + sin(a) * 59.0))

	# Reflexo térmico na base do caldeirão (laranja quando quente, azul-gelo quando frio)
	if _therm_vis > 0.02:
		draw_polyline(belly_bottom, Color(1.0, 0.45, 0.12, 0.68 * _therm_vis), 9.0, true)
	elif _therm_vis < -0.02:
		draw_polyline(belly_bottom, Color(0.45, 0.88, 1.0, 0.72 * (-_therm_vis)), 9.0, true)
	draw_polyline(belly_bottom, Color(0.09, 0.06, 0.05, 0.98), 4.0, true)

	# Pernas laterais do tripé de ferro (esquerda e direita)
	var side_legs := [
		[Vector2(525, 480), Vector2(506, 568)],
		[Vector2(753, 480), Vector2(772, 568)],
	]
	for sl in side_legs:
		var p0: Vector2 = sl[0]
		var p1: Vector2 = sl[1]
		draw_line(p0, p1, Color(0.08, 0.06, 0.06), 16.0, true)
		draw_line(p0, p1, Color(0.26, 0.22, 0.24), 10.0, true)
		draw_line(p0 + Vector2(1, 0), p1 + Vector2(1, 0), Color(0.46, 0.39, 0.42, 0.7), 2.5, true)

	# Perna frontal central do tripé de ferro do caldeirão
	var leg_rect := Rect2(630, 476, 18, 92)
	var leg_style := StyleBoxFlat.new()
	leg_style.bg_color = Color(0.24, 0.20, 0.22)
	leg_style.set_corner_radius_all(4)
	leg_style.set_border_width_all(2)
	leg_style.border_color = Color(0.08, 0.06, 0.06)
	draw_style_box(leg_style, leg_rect)
	draw_line(Vector2(635, 480), Vector2(635, 564), Color(0.45, 0.38, 0.40, 0.75), 2.0)

	# Argola frontal na base do tripé
	draw_arc(Vector2(639, 558), 22.0, PI, TAU, 18, Color(0.08, 0.06, 0.06), 8.0)
	draw_arc(Vector2(639, 558), 22.0, PI, TAU, 18, Color(0.32, 0.27, 0.29), 4.0)


func _draw_cauldron_contents() -> void:
	if _fill_vis > 0.02:
		var center := _liquid_center()
		var rx := MOUTH_RADIUS.x * (0.88 + 0.11 * _fill_vis)
		var ry := MOUTH_RADIUS.y * (0.82 + 0.16 * _fill_vis)
		var alpha := clampf(_fill_vis * 2.2, 0.0, 1.0)
		var heat_pos := maxf(0.0, _therm_vis)
		var cold_pos := maxf(0.0, -_therm_vis)
		var wobble := (1.2 + heat_pos * 2.8 + agitation * 3.0) * (1.0 - cold_pos * 0.85)

		var base_col := _liquid_color
		if cold_pos > 0.1:
			base_col = base_col.lerp(Color(0.55, 0.90, 1.0), cold_pos * 0.55)

		# Camadas do líquido dentro da boca do caldeirão
		draw_colored_polygon(_ellipse(center, Vector2(rx, ry), wobble), Color(base_col.darkened(0.38), alpha))
		draw_colored_polygon(_ellipse(center + Vector2(-4, -2), Vector2(rx * 0.86, ry * 0.74), wobble), Color(base_col, alpha))
		draw_colored_polygon(_ellipse(center + Vector2(-26, -7), Vector2(rx * 0.32, ry * 0.20), 0.0), Color(1, 1, 1, 0.28 * alpha))

		# Se estiver resfriando com gelo, desenha cristais de gelo solidificando na superfície!
		if cold_pos > 0.18:
			var freeze_a := clampf((cold_pos - 0.18) / 0.82, 0.0, 1.0)
			var ice_sheet := _ellipse(center, Vector2(rx * (0.55 + 0.38 * freeze_a), ry * (0.55 + 0.38 * freeze_a)), 0.4)
			draw_colored_polygon(ice_sheet, Color(0.75, 0.95, 1.0, 0.52 * freeze_a))
			# Veios cristalinos de gelo na superfície
			for i in range(6):
				var ang := float(i) * TAU / 6.0 + 0.3
				var p_end := center + Vector2(cos(ang) * rx * 0.78 * freeze_a, sin(ang) * ry * 0.78 * freeze_a)
				draw_line(center, p_end, Color(0.92, 0.99, 1.0, 0.78 * freeze_a), 2.0)
				var branch := center.lerp(p_end, 0.6)
				draw_line(branch, branch + Vector2(cos(ang + 0.6) * 14.0, sin(ang + 0.6) * 6.0), Color(0.92, 0.99, 1.0, 0.65 * freeze_a), 1.5)

		# Bolhas de fervura
		for b in _bubbles:
			var k := float(b["life"]) / float(b["max"])
			var p: Vector2 = center + b["pos"]
			var s: float = float(b["size"]) * (0.4 + k)
			draw_circle(p, s, Color(base_col.lightened(0.38), 0.62 * (1.0 - k) * alpha))
			draw_arc(p, s, 0, TAU, 12, Color(1, 1, 1, 0.72 * (1.0 - k) * alpha), 1.4)

		# Plumas de vapor procedurais subindo do caldeirão (inspiradas na arte do Figma 2010:74!)
		if _therm_vis > 0.08:
			_draw_procedural_vapor(center, clampf(_therm_vis, 0.0, 1.0), base_col)

	# Destaque dourado da borda ao arrastar um frasco por cima
	if _highlight_vis > 0.01:
		var pulse := 0.7 + 0.3 * sin(_t * 8.0)
		var rim := _ellipse(MOUTH_CENTER + Vector2(0, -2), MOUTH_RADIUS + Vector2(18, 12), 0.0)
		rim.append(rim[0])
		draw_polyline(rim, Color(1.0, 0.85, 0.4, 0.9 * _highlight_vis * pulse), 4.0, true)
		draw_polyline(rim, Color(1.0, 0.95, 0.7, 0.35 * _highlight_vis), 10.0, true)


func _draw_procedural_vapor(origin: Vector2, heat_k: float, tint: Color) -> void:
	var vapor_col := tint.lightened(0.45)
	vapor_col.a = 0.16 + 0.22 * heat_k
	var max_h := 70.0 + 115.0 * heat_k

	for wisp in range(3):
		var offset_x := (wisp - 1) * 32.0
		var phase := _t * (2.2 + heat_k * 1.8) + float(wisp) * 2.1
		var pts_l := PackedVector2Array()
		var pts_r := PackedVector2Array()
		var steps := 14
		for i in range(steps):
			var frac := float(i) / float(steps - 1)
			var y := origin.y - 8.0 - frac * max_h
			var wave := sin(frac * 4.5 - phase) * (10.0 + 18.0 * frac)
			var half_w := (8.0 + 22.0 * sin(frac * PI)) * (1.0 - frac * 0.35)
			var cx := origin.x + offset_x * (1.0 - frac * 0.25) + wave
			pts_l.append(Vector2(cx - half_w, y))
			pts_r.append(Vector2(cx + half_w, y))
		pts_r.reverse()
		pts_l.append_array(pts_r)
		draw_colored_polygon(pts_l, vapor_col)


func _draw_thermometer() -> void:
	# Termômetro medieval / pixel-art ao lado direito do caldeirão (inspirado no Figma 2010:74 + PhET)
	var font: Font = PIXEL_FONT if PIXEL_FONT else ThemeDB.fallback_font
	var body_rect := Rect2(THERM_CENTER.x - 22, THERM_CENTER.y - 104, 44, 200)

	# Sombra
	var sh_style := StyleBoxFlat.new()
	sh_style.bg_color = Color(0, 0, 0, 0.52)
	sh_style.set_corner_radius_all(22)
	draw_style_box(sh_style, body_rect.grow(2.0))

	# Moldura metálica/pedra do termômetro
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = Color(0.68, 0.72, 0.78, 0.96)
	body_style.set_corner_radius_all(22)
	body_style.set_border_width_all(3)
	body_style.border_color = Color(0.14, 0.12, 0.16)
	draw_style_box(body_style, body_rect)

	var inner_plate := body_rect.grow(-5.0)
	var plate_style := StyleBoxFlat.new()
	plate_style.bg_color = Color(0.86, 0.89, 0.93, 0.96)
	plate_style.set_corner_radius_all(17)
	plate_style.set_border_width_all(1)
	plate_style.border_color = Color(0.45, 0.48, 0.54)
	draw_style_box(plate_style, inner_plate)

	var tube_top := body_rect.position.y + 20.0
	var bulb_center := Vector2(THERM_CENTER.x, body_rect.end.y - 24.0)
	var tube_bot := bulb_center.y - 8.0
	var tube_w := 10.0

	# Marcações graduadas (ticks) ao longo do tubo
	var ticks := 10
	for i in range(ticks + 1):
		var ty := lerpf(tube_top + 4.0, tube_bot - 4.0, float(i) / float(ticks))
		var is_major := (i % 2 == 0)
		var t_len := 8.0 if is_major else 5.0
		var t_col := Color(0.18, 0.18, 0.22) if is_major else Color(0.42, 0.44, 0.48)
		draw_line(Vector2(THERM_CENTER.x - tube_w * 0.5 - t_len, ty), Vector2(THERM_CENTER.x - tube_w * 0.5 - 1, ty), t_col, 2.0 if is_major else 1.2)
		draw_line(Vector2(THERM_CENTER.x + tube_w * 0.5 + 1, ty), Vector2(THERM_CENTER.x + tube_w * 0.5 + t_len, ty), t_col, 2.0 if is_major else 1.2)

	# Tubo capilar de vidro vazio
	var tube_rect := Rect2(THERM_CENTER.x - tube_w * 0.5, tube_top, tube_w, tube_bot - tube_top + 6.0)
	var glass_tube := StyleBoxFlat.new()
	glass_tube.bg_color = Color(0.20, 0.22, 0.26, 0.85)
	glass_tube.set_corner_radius_all(5)
	draw_style_box(glass_tube, tube_rect)

	# Nível normalizado da coluna de mercúrio/álcool (0.08 no frio máx, 0.30 no ambiente, 1.0 no fogo máx)
	var level_norm := 0.30
	if _therm_vis >= 0.0:
		level_norm = lerpf(0.30, 0.96, clampf(_therm_vis, 0.0, 1.0))
	else:
		level_norm = lerpf(0.30, 0.07, clampf(-_therm_vis, 0.0, 1.0))

	# Cor do fluido do termômetro (vermelho rubi no ambiente/quente, azul-ciano quando abaixo de 0°C)
	var fluid_col := Color(0.92, 0.16, 0.18)
	if _therm_vis < -0.1:
		fluid_col = fluid_col.lerp(Color(0.16, 0.72, 1.0), clampf((-_therm_vis - 0.1) / 0.7, 0.0, 1.0))
	elif _therm_vis > 0.5:
		fluid_col = fluid_col.lerp(Color(1.0, 0.38, 0.12), (_therm_vis - 0.5) * 0.8)

	var fill_top_y := lerpf(tube_bot, tube_top + 4.0, level_norm)
	var fill_rect := Rect2(THERM_CENTER.x - (tube_w - 3.0) * 0.5, fill_top_y, tube_w - 3.0, bulb_center.y - fill_top_y)
	draw_rect(fill_rect, fluid_col)
	draw_rect(Rect2(fill_rect.position.x + 1.0, fill_rect.position.y, 2.0, fill_rect.size.y), Color(1, 1, 1, 0.42))

	# Bulbo esférico inferior
	draw_circle(bulb_center, 15.0, Color(0.14, 0.12, 0.16))
	draw_circle(bulb_center, 12.5, fluid_col)
	draw_circle(bulb_center + Vector2(-4, -4), 4.0, Color(1, 1, 1, 0.55))

	# Ponteiro triangular lateral (inspirado no termômetro do PhET) acompanhando o nível
	var ptr_y := fill_top_y
	var ptr_pts := PackedVector2Array([
		Vector2(body_rect.position.x - 3, ptr_y),
		Vector2(body_rect.position.x - 14, ptr_y - 6),
		Vector2(body_rect.position.x - 14, ptr_y + 6),
	])
	draw_colored_polygon(ptr_pts, fluid_col.lightened(0.2))
	var ptr_border := ptr_pts.duplicate()
	ptr_border.append(ptr_pts[0])
	draw_polyline(ptr_border, Color(0.08, 0.06, 0.08), 2.0)

	# Plaqueta superior com a temperatura em °C
	var temp_badge := Rect2(THERM_CENTER.x - 38, body_rect.position.y - 30, 76, 24)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.12, 0.09, 0.16, 0.94)
	badge_style.set_corner_radius_all(6)
	badge_style.set_border_width_all(2)
	badge_style.border_color = fluid_col.lightened(0.25)
	draw_style_box(badge_style, temp_badge)

	var temp_str := "%d °C" % int(roundf(_temp_c_vis))
	draw_string_outline(font, Vector2(temp_badge.position.x, temp_badge.position.y + 17), temp_str, HORIZONTAL_ALIGNMENT_CENTER, temp_badge.size.x, 14, 4, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(temp_badge.position.x, temp_badge.position.y + 17), temp_str, HORIZONTAL_ALIGNMENT_CENTER, temp_badge.size.x, 14, fluid_col.lightened(0.35))


func _draw_glow() -> void:
	var flick := 1.0 + sin(_t * 13.0) * 0.06 + sin(_t * 7.3) * 0.05
	if _therm_vis > 0.02:
		var strength := clampf(_therm_vis, 0.0, 1.0)
		for i in range(6):
			var r := (38.0 + strength * 76.0) * (1.0 - i * 0.14) * flick
			_glow.draw_circle(FURNACE_CENTER + Vector2(0, -14), r, Color(1.0, 0.45 + i * 0.07, 0.12, (0.04 + 0.08 * strength)))
		# Reflexo quente no bojo do caldeirão
		_glow.draw_set_transform(FURNACE_CENTER + Vector2(0, -64), 0.0, Vector2(1.0, 0.45))
		_glow.draw_circle(Vector2.ZERO, (95.0 + 45.0 * strength) * flick, Color(1.0, 0.42, 0.10, 0.09 * strength))
		_glow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif _therm_vis < -0.02:
		var cold_strength := clampf(-_therm_vis, 0.0, 1.0)
		for i in range(5):
			var r := (34.0 + cold_strength * 64.0) * (1.0 - i * 0.15)
			_glow.draw_circle(FURNACE_CENTER + Vector2(0, -18), r, Color(0.20, 0.75, 1.0, 0.05 * cold_strength))


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
	p.emission_rect_extents = Vector2(76, 10)
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
