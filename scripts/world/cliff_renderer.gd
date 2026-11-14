class_name CliffRenderer
extends Node2D

## Renderiza o paredão rochoso da montanha com silhueta contínua (sem degraus de tile).
## O contorno é calculado por coluna de pixel a partir de ruído suave e gravado numa textura
## de perfil; o shader desenha rochas arredondadas (Voronoi), a borda iluminada do planalto,
## as pedras recortadas da base e a sombra na grama. A colisão segue o mesmo contorno.

const CLIFF_SHADER := preload("res://assets/shaders/cliff.gdshader")
const SHADOW_PX := 6.0
## Quanto da base o personagem pode "sobrepor" antes de colidir (efeito de profundidade)
const COLLISION_INSET := 8.0
const COLLISION_STEP := 8

@export var baseline_row: float = 10.0
@export var amplitude_rows: float = 5.0
@export var min_row: float = 6.0
@export var max_row: float = 14.0
@export var wall_height_tiles: float = 2.5

var bottom_px := PackedFloat32Array()
var top_px := PackedFloat32Array()

var _tile_size := 32
var _width_tiles := 0
var _last_rows := PackedInt32Array()
var _rect: ColorRect
var _body: StaticBody2D


func generate(noise: FastNoiseLite, width_tiles: int, tile_size: int, seed_val: int) -> void:
	_clear()
	_tile_size = tile_size
	_width_tiles = width_tiles
	var w := width_tiles * tile_size
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 4242

	var base_rocks := _scallops(w, rng, 12, 28, 2.0, 6.0)
	var rim_rocks := _scallops(w, rng, 10, 24, 1.5, 4.5)

	bottom_px.resize(w)
	top_px.resize(w)
	var img := Image.create(w, 2, false, Image.FORMAT_RGBAF)
	var max_bottom := 0.0

	for x in range(w):
		var xf := (x + 0.5) / tile_size
		var row := baseline_row + noise.get_noise_2d(xf * 1.5, 0.0) * amplitude_rows
		row = _soft_clamp(row, min_row, max_row)
		var base := (row + 1.0) * tile_size
		var wall_h := wall_height_tiles * tile_size + noise.get_noise_2d(xf * 3.0, 50.0) * 10.0

		var bottom := base + base_rocks[x].x
		var top := base - wall_h - rim_rocks[x].x
		bottom_px[x] = bottom
		top_px[x] = top
		max_bottom = maxf(max_bottom, bottom)

		img.set_pixel(x, 0, Color(bottom, top, base_rocks[x].y, base_rocks[x].z))
		img.set_pixel(x, 1, Color(base, rim_rocks[x].y, rim_rocks[x].z, 0.0))

	_compute_last_rows()

	var h := int(ceil(max_bottom + SHADOW_PX + 2.0))
	var mat := ShaderMaterial.new()
	mat.shader = CLIFF_SHADER
	mat.set_shader_parameter("profile", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("area_size", Vector2(w, h))
	mat.set_shader_parameter("seed", float(seed_val % 1000) * 0.137)
	mat.set_shader_parameter("shadow_px", SHADOW_PX)

	_rect = ColorRect.new()
	_rect.name = "CliffSurface"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.position = Vector2.ZERO
	_rect.size = Vector2(w, h)
	_rect.material = mat
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_rect)

	_build_collision(w)


## Última linha de tiles (inclusive) ocupada pela falésia na coluna informada
func last_cliff_row(cx: int) -> int:
	if cx < 0 or cx >= _last_rows.size():
		return int(baseline_row)
	return _last_rows[cx]


func is_cliff_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= _last_rows.size():
		return false
	return cell.y <= _last_rows[cell.x]


func _compute_last_rows() -> void:
	_last_rows.resize(_width_tiles)
	for cx in range(_width_tiles):
		var deepest := 0.0
		for i in range(_tile_size):
			deepest = maxf(deepest, bottom_px[cx * _tile_size + i])
		# Ignora sobreposições mínimas (<= 4px) na célula de baixo
		_last_rows[cx] = int(floor((deepest - 4.0) / _tile_size))


func _build_collision(w: int, cave_pos: Vector2 = Vector2(-1.0, -1.0), doorway_half_width: float = 42.0, arch_half_width: float = 76.0) -> void:
	if _body:
		remove_child(_body)
		_body.queue_free()
	_body = StaticBody2D.new()
	_body.name = "CliffCollision"

	if cave_pos.x < 0.0:
		var poly := CollisionPolygon2D.new()
		var pts := PackedVector2Array()
		pts.append(Vector2(0, 0))
		var x := 0
		while x < w:
			pts.append(Vector2(x, bottom_px[x] - COLLISION_INSET))
			x += COLLISION_STEP
		pts.append(Vector2(w, bottom_px[w - 1] - COLLISION_INSET))
		pts.append(Vector2(w, 0))
		poly.polygon = pts
		_body.add_child(poly)
	else:
		var left_end := clampi(int(floor(cave_pos.x - doorway_half_width)), 0, w - 1)
		var right_start := clampi(int(ceil(cave_pos.x + doorway_half_width)), 0, w - 1)
		var left_arch_start := cave_pos.x - arch_half_width
		var right_arch_end := cave_pos.x + arch_half_width
		var pillar_max_y := cave_pos.y + 8.0

		if left_end > 0:
			var left_poly := CollisionPolygon2D.new()
			left_poly.name = "LeftCliffPolygon"
			var left_pts := PackedVector2Array()
			left_pts.append(Vector2(0, 0))
			var x := 0
			while x < left_end:
				var cy := bottom_px[x] - COLLISION_INSET
				if x >= left_arch_start:
					cy = minf(cy, pillar_max_y)
				left_pts.append(Vector2(x, cy))
				x += COLLISION_STEP
			var left_end_y := minf(bottom_px[left_end] - COLLISION_INSET, pillar_max_y)
			left_pts.append(Vector2(left_end, left_end_y))
			left_pts.append(Vector2(left_end, 0))
			left_poly.polygon = left_pts
			_body.add_child(left_poly)

		if right_start < w - 1:
			var right_poly := CollisionPolygon2D.new()
			right_poly.name = "RightCliffPolygon"
			var right_pts := PackedVector2Array()
			right_pts.append(Vector2(right_start, 0))
			var right_start_y := minf(bottom_px[right_start] - COLLISION_INSET, pillar_max_y)
			right_pts.append(Vector2(right_start, right_start_y))
			var x := right_start + COLLISION_STEP
			while x < w:
				var cy := bottom_px[x] - COLLISION_INSET
				if x <= right_arch_end:
					cy = minf(cy, pillar_max_y)
				right_pts.append(Vector2(x, cy))
				x += COLLISION_STEP
			right_pts.append(Vector2(w, bottom_px[w - 1] - COLLISION_INSET))
			right_pts.append(Vector2(w, 0))
			right_poly.polygon = right_pts
			_body.add_child(right_poly)

	add_child(_body)


## Abre uma passagem na colisão da falésia exatamente na entrada da caverna
func carve_cave_opening(cave_pos: Vector2, doorway_half_width: float = 42.0, arch_half_width: float = 76.0) -> void:
	var w := _width_tiles * _tile_size
	if w <= 0 or bottom_px.is_empty():
		return
	_build_collision(w, cave_pos, doorway_half_width, arch_half_width)


## Sequência de "rochas" lado a lado: cada uma gera um arco semicircular (bojo arredondado).
## Retorna por coluna: x = profundidade do bojo (px), y = posição relativa t (-1..1), z = largura.
func _scallops(w: int, rng: RandomNumberGenerator, min_w: int, max_w: int, min_d: float, max_d: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.resize(w)
	var x := -rng.randi_range(0, max_w)
	while x < w:
		var bw := rng.randi_range(min_w, max_w)
		var depth := rng.randf_range(min_d, max_d)
		for i in range(bw):
			var px := x + i
			if px < 0 or px >= w:
				continue
			var t := (i + 0.5) / bw * 2.0 - 1.0
			out[px] = Vector3(sqrt(maxf(1.0 - t * t, 0.0)) * depth, t, bw)
		x += bw
	return out


func _soft_clamp(v: float, lo: float, hi: float) -> float:
	var mid := (lo + hi) * 0.5
	var half := (hi - lo) * 0.5
	return mid + half * tanh((v - mid) / half)


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rect = null
	_body = null
