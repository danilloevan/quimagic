class_name BeachRenderer
extends Node2D

## Renderiza proceduralmente a praia (transição grama/areia, areia molhada, conchinhas)
## e o mar animado com ondas, espuma de arrebentação, cáusticas e reflexos solares.
## A linha d'água e a largura da faixa de areia são pré-calculadas num perfil SDF 2D
## para manter silhueta orgânica contínua e colisão suave pixel a pixel.

const BEACH_SHADER := preload("res://assets/shaders/beach.gdshader")
const SDF_STEP := 4
const WALKABLE_WATER_EDGE_PX := 2.0

var _tile_size := 32
var _area_origin := Vector2.ZERO
var _area_size := Vector2.ZERO
var _grid_w := 0
var _grid_h := 0
var _shore_sdf := PackedFloat32Array()
var _sand_width_sdf := PackedFloat32Array()
var _rect: ColorRect


func generate(map_width: int, map_height: int, tile_size: int, seed_val: int) -> void:
	_clear()
	_tile_size = tile_size

	var start_tx := floori(map_width * 0.25)
	var start_ty := floori(map_height * 0.28)
	_area_origin = Vector2(start_tx * tile_size, start_ty * tile_size)
	_area_size = Vector2(map_width * tile_size, map_height * tile_size) - _area_origin

	_grid_w = int(ceil(_area_size.x / SDF_STEP)) + 1
	_grid_h = int(ceil(_area_size.y / SDF_STEP)) + 1
	_shore_sdf.resize(_grid_w * _grid_h)
	_sand_width_sdf.resize(_grid_w * _grid_h)

	var coast_noise := FastNoiseLite.new()
	coast_noise.seed = seed_val + 303
	coast_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	coast_noise.frequency = 0.0018
	coast_noise.fractal_octaves = 3

	var cove_noise := FastNoiseLite.new()
	cove_noise.seed = seed_val + 505
	cove_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cove_noise.frequency = 0.0032
	cove_noise.fractal_octaves = 2

	var width_noise := FastNoiseLite.new()
	width_noise.seed = seed_val + 404
	width_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	width_noise.frequency = 0.0026
	width_noise.fractal_octaves = 2

	# Origem ligeiramente além do canto SE evita qualquer singularidade dentro do mapa
	var sea_origin := Vector2((map_width + 2.0) * tile_size, (map_height + 2.0) * tile_size)
	var base_radius := minf(float(map_width), float(map_height)) * 0.43 * tile_size + 2.4 * tile_size

	var img := Image.create(_grid_w, _grid_h, false, Image.FORMAT_RGF)

	for gy in range(_grid_h):
		var wy := _area_origin.y + gy * SDF_STEP
		var dy := (wy - sea_origin.y) / 0.92
		for gx in range(_grid_w):
			var wx := _area_origin.x + gx * SDF_STEP
			var dx := (wx - sea_origin.x) / 1.15
			var ellip_dist := sqrt(dx * dx + dy * dy)

			# Ruído suave multi-oitava para enseadas e pontas orgânicas
			var coast_offset := coast_noise.get_noise_2d(wx, wy) * 115.0 + cove_noise.get_noise_2d(wx, wy) * 34.0
			var shore_dist := ellip_dist - (base_radius + coast_offset)
			var sand_w := clampf(148.0 + width_noise.get_noise_2d(wx, wy) * 52.0, 96.0, 200.0)

			var idx := gy * _grid_w + gx
			_shore_sdf[idx] = shore_dist
			_sand_width_sdf[idx] = sand_w
			img.set_pixel(gx, gy, Color(shore_dist, sand_w, 0.0, 1.0))

	var mat := ShaderMaterial.new()
	mat.shader = BEACH_SHADER
	mat.set_shader_parameter("profile", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("profile_size", Vector2(_grid_w, _grid_h))
	mat.set_shader_parameter("sdf_step", float(SDF_STEP))
	mat.set_shader_parameter("area_origin", _area_origin)
	mat.set_shader_parameter("area_size", _area_size)
	mat.set_shader_parameter("seed", float(seed_val % 1000) * 0.173)

	_rect = ColorRect.new()
	_rect.name = "BeachSurface"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.position = _area_origin
	_rect.size = _area_size
	_rect.material = mat
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_rect)


func is_water_at(local_pos: Vector2) -> bool:
	if _shore_sdf.is_empty():
		return false
	if local_pos.x < _area_origin.x or local_pos.y < _area_origin.y:
		return false
	if local_pos.x > _area_origin.x + _area_size.x or local_pos.y > _area_origin.y + _area_size.y:
		return false
	return _sample_sdf(_shore_sdf, local_pos) < WALKABLE_WATER_EDGE_PX


func is_water_cell(cell: Vector2i) -> bool:
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * _tile_size
	if is_water_at(center):
		return true
	# Verifica cantos também para impedir caminhos ou props rente demais à água
	var half := _tile_size * 0.35
	for offset: Vector2 in [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half)]:
		if is_water_at(center + offset):
			return true
	return false


func is_sand_cell(cell: Vector2i) -> bool:
	if _shore_sdf.is_empty():
		return false
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * _tile_size
	if center.x < _area_origin.x or center.y < _area_origin.y:
		return false
	var sd := _sample_sdf(_shore_sdf, center)
	var sw := _sample_sdf(_sand_width_sdf, center)
	return sd >= 32.0 and sd <= sw - 22.0


func is_beach_or_water_cell(cell: Vector2i) -> bool:
	if _shore_sdf.is_empty():
		return false
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * _tile_size
	if center.x < _area_origin.x or center.y < _area_origin.y:
		return false
	var sd := _sample_sdf(_shore_sdf, center)
	var sw := _sample_sdf(_sand_width_sdf, center)
	return sd <= sw + 14.0


func get_sand_cells(map_width: int, map_height: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var start_tx := maxi(floori(_area_origin.x / _tile_size), 0)
	var start_ty := maxi(floori(_area_origin.y / _tile_size), 0)
	for x in range(start_tx, map_width - 1):
		for y in range(start_ty, map_height - 1):
			var cell := Vector2i(x, y)
			if is_sand_cell(cell):
				cells.append(cell)
	return cells


func _sample_sdf(arr: PackedFloat32Array, local_pos: Vector2) -> float:
	var gx := clampf((local_pos.x - _area_origin.x) / SDF_STEP, 0.0, float(_grid_w - 1))
	var gy := clampf((local_pos.y - _area_origin.y) / SDF_STEP, 0.0, float(_grid_h - 1))
	var x0 := mini(int(floor(gx)), _grid_w - 2)
	var y0 := mini(int(floor(gy)), _grid_h - 2)
	var fx := gx - x0
	var fy := gy - y0

	var i00 := y0 * _grid_w + x0
	var i10 := i00 + 1
	var i01 := i00 + _grid_w
	var i11 := i01 + 1

	var top := lerpf(arr[i00], arr[i10], fx)
	var bot := lerpf(arr[i01], arr[i11], fx)
	return lerpf(top, bot, fy)


func _clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rect = null
	_shore_sdf.clear()
	_sand_width_sdf.clear()
