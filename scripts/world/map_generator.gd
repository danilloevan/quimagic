class_name MapGenerator
extends Node2D

## Configurações do Gerador Procedural
@export_group("Dimensões do Mapa")
@export var map_width: int = 64
@export var map_height: int = 48
@export var tile_size: int = 32

@export_group("Semente e Ruído")
@export var seed_val: int = 0
@export var auto_randomize_seed: bool = true
@export var terrain_frequency: float = 0.04
@export var path_frequency: float = 0.06

@export_group("Caminhos")
## Raio do traçado em tiles (1.0 = caminho com ~2 tiles de largura constante)
@export var path_radius: float = 1.0
## Desvio lateral máximo das curvas, em tiles
@export var path_wobble: float = 3.5
## Raio da praça de terra ao redor do poço
@export var plaza_radius: float = 2.6

@export_group("Camadas de Terreno")
@export var ground_layer: TileMapLayer
@export var path_layer: TileMapLayer
@export var decor_layer: TileMapLayer
@export var props_container: Node2D

# Definições de coordenadas no Atlas (TileSetAtlasSource)
const TILE_SOURCE_ID = 0

# Linha 0: Grama, Terra, Água
const TILE_GRASS_PLAIN = Vector2i(0, 0)
const TILE_GRASS_TUFT = Vector2i(1, 0)
const TILE_GRASS_DETAIL = Vector2i(2, 0)
const TILE_DIRT_EDGE = Vector2i(3, 0)
const TILE_DIRT_PLAIN = Vector2i(4, 0)
const TILE_DIRT_PATH = Vector2i(5, 0)
const TILE_SAND = Vector2i(6, 0)
const TILE_DEEP_WATER = Vector2i(7, 0)

# Linha 1: Caminho de Pedras (Cobblestone)
const TILE_COBBLE_CENTER = Vector2i(0, 1)
const TILE_COBBLE_HORIZ = Vector2i(1, 1)
const TILE_COBBLE_VERT = Vector2i(2, 1)
const TILE_COBBLE_CROSS = Vector2i(3, 1)
const TILE_COBBLE_CORNER = Vector2i(4, 1)
const TILE_COBBLE_EDGE = Vector2i(5, 1)
const TILE_WATER_SHALLOW = Vector2i(6, 1)
const TILE_WATER_RIPPLE = Vector2i(7, 1)

# Linha 2: Penhascos e Falésias
const TILE_CLIFF_TOP = Vector2i(0, 2)
const TILE_CLIFF_TOP_EDGE = Vector2i(1, 2)
const TILE_CLIFF_WALL_1 = Vector2i(2, 2)
const TILE_CLIFF_WALL_2 = Vector2i(3, 2)
const TILE_CLIFF_WALL_3 = Vector2i(4, 2)
const TILE_CLIFF_LEDGE = Vector2i(5, 2)
const TILE_CLIFF_BASE = Vector2i(6, 2)
const TILE_CLIFF_CORNER = Vector2i(7, 2)

# Linha 3: Trigo e Flora
const TILE_WHEAT_1 = Vector2i(0, 3)
const TILE_WHEAT_2 = Vector2i(1, 3)
const TILE_WHEAT_3 = Vector2i(2, 3)
const TILE_SAND_DETAIL = Vector2i(3, 3)
const TILE_STONE_SLAB = Vector2i(7, 3)

# Linha 4: Margens e Costas da Praia (Shorelines)
const TILE_SHORE_N = Vector2i(0, 4)
const TILE_SHORE_S = Vector2i(1, 4)
const TILE_SHORE_E = Vector2i(2, 4)
const TILE_SHORE_W = Vector2i(3, 4)
const TILE_SHORE_INNER_SE = Vector2i(4, 4)
const TILE_SHORE_CORNER_NW = Vector2i(5, 4)
const TILE_SHORE_CORNER_NE = Vector2i(6, 4)
const TILE_SHORE_CORNER_SW = Vector2i(7, 4)

# Cenas dos Props Temáticos
const SCENE_CAVE = preload("res://scenes/props/cave_entrance.tscn")
const SCENE_WELL = preload("res://scenes/props/well.tscn")
const SCENE_STONEHENGE = preload("res://scenes/props/stonehenge.tscn")
const SCENE_SALT_CRYSTAL = preload("res://scenes/props/salt_crystals.tscn")
const SCENE_EMERALD_CRYSTAL = preload("res://scenes/props/emerald_crystal.tscn")
const SCENE_RUBY_CRYSTAL = preload("res://scenes/props/ruby_crystal.tscn")
const SCENE_ORE_ROCK = preload("res://scenes/props/ore_rock.tscn")
const SCENE_HEDGE_MAZE = preload("res://scenes/props/hedge_maze.tscn")
const SCENE_TREE = preload("res://scenes/props/tree.tscn")
const SCENE_PALM_TREE = preload("res://scenes/props/palm_tree.tscn")
const SCENE_BOULDER = preload("res://scenes/props/boulder.tscn")

var elevation_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var path_noise: FastNoiseLite

# Campo do caminho em vértices (cantos dos tiles) e células resultantes (célula -> máscara)
var _path_vertices: Dictionary = {}
var _path_cells: Dictionary = {}

signal map_generated(current_seed: int)


func _ready() -> void:
	if auto_randomize_seed and seed_val == 0:
		randomize()
		seed_val = randi() % 1000000
	generate_map()


func set_seed_and_generate(new_seed: int) -> void:
	seed_val = new_seed
	generate_map()


func generate_map() -> void:
	_ensure_path_layer()
	_init_noises()
	_clear_map()
	
	_generate_base_terrain()
	_generate_cliffs()
	_generate_paths()
	_generate_water_shores()
	_render_paths()
	_generate_wheat_fields()
	_spawn_landmarks_and_props()
	
	map_generated.emit(seed_val)
	print("[Quimagic Procedural World] Mapa gerado com sucesso! Semente: ", seed_val)


func _init_noises() -> void:
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = seed_val
	elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elevation_noise.frequency = terrain_frequency
	elevation_noise.fractal_octaves = 4

	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = seed_val + 101
	moisture_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	moisture_noise.frequency = terrain_frequency * 1.2
	moisture_noise.fractal_octaves = 3

	# Ruído suave (contínuo) para curvas orgânicas sem degraus
	path_noise = FastNoiseLite.new()
	path_noise.seed = seed_val + 202
	path_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	path_noise.frequency = path_frequency
	path_noise.fractal_octaves = 2


func _ensure_path_layer() -> void:
	if not path_layer:
		path_layer = TileMapLayer.new()
		path_layer.name = "PathLayer"
		add_child(path_layer)
		if ground_layer:
			move_child(path_layer, ground_layer.get_index() + 1)
	if not path_layer.tile_set:
		path_layer.tile_set = PathTilesetBuilder.build(tile_size)
	path_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _clear_map() -> void:
	if ground_layer:
		ground_layer.clear()
	if path_layer:
		path_layer.clear()
	_path_vertices.clear()
	_path_cells.clear()
	if decor_layer:
		decor_layer.clear()
	if props_container:
		for child in props_container.get_children():
			child.queue_free()


func _generate_base_terrain() -> void:
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y)
			var n_val = moisture_noise.get_noise_2d(x, y)
			
			# Variação sutil na grama base
			if n_val > 0.25:
				ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_GRASS_TUFT)
			elif n_val < -0.3:
				ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_GRASS_DETAIL)
			else:
				ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_GRASS_PLAIN)


func _generate_cliffs() -> void:
	# Falésias no terço superior (Norte) com profundidade de paredão rochoso
	for x in range(map_width):
		var local_cliff_y = _cliff_y_at(x)
		
		# Topo e paredes da montanha
		for y in range(0, local_cliff_y - 2):
			ground_layer.set_cell(Vector2i(x, y), TILE_SOURCE_ID, TILE_CLIFF_TOP)
		
		ground_layer.set_cell(Vector2i(x, local_cliff_y - 2), TILE_SOURCE_ID, TILE_CLIFF_TOP_EDGE)
		ground_layer.set_cell(Vector2i(x, local_cliff_y - 1), TILE_SOURCE_ID, TILE_CLIFF_WALL_1 if x % 2 == 0 else TILE_CLIFF_WALL_2)
		ground_layer.set_cell(Vector2i(x, local_cliff_y), TILE_SOURCE_ID, TILE_CLIFF_BASE)


func _generate_water_shores() -> void:
	# Mapa de elevação e tipos de terreno aquático no canto sudeste
	var water_grid: Dictionary = {}
	var river_origin = Vector2(map_width - 1, map_height - 1)
	
	# 1. Classificação das zonas marítimas e costeiras com ruído orgânico
	for x in range(int(map_width * 0.40), map_width):
		for y in range(int(map_height * 0.40), map_height):
			var dist = Vector2(x, y).distance_to(river_origin)
			var n1 = moisture_noise.get_noise_2d(x * 2.2, y * 2.2) * 5.0
			var n2 = elevation_noise.get_noise_2d(x * 4.0, y * 4.0) * 2.5
			var threshold = 21.0 + n1 + n2
			
			if dist < threshold - 5.5:
				water_grid[Vector2i(x, y)] = "DEEP"
			elif dist < threshold:
				water_grid[Vector2i(x, y)] = "SHALLOW"
			elif dist < threshold + 3.5:
				water_grid[Vector2i(x, y)] = "SAND"

	# 2. Renderizar Faixa de Areia e Detalhes
	for pos in water_grid:
		if water_grid[pos] == "SAND":
			if (pos.x * 3 + pos.y * 7) % 5 == 0:
				ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_SAND_DETAIL)
			else:
				ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_SAND)

	# 3. Renderizar Água e Margens de Espuma (Auto-tiling da Costa)
	for pos in water_grid:
		var wtype = water_grid[pos]
		if wtype == "DEEP":
			ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_DEEP_WATER)
		elif wtype == "SHALLOW":
			# Checar vizinhos para determinar a transição da praia
			var n_up = _is_land_pos(water_grid, pos + Vector2i(0, -1))
			var n_left = _is_land_pos(water_grid, pos + Vector2i(-1, 0))
			var n_right = _is_land_pos(water_grid, pos + Vector2i(1, 0))
			var n_down = _is_land_pos(water_grid, pos + Vector2i(0, 1))
			
			if n_up and n_left:
				ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_SHORE_INNER_SE)
			elif n_up:
				ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_SHORE_N)
			elif n_left:
				ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_SHORE_E)
			elif n_right:
				ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_SHORE_W)
			elif n_down:
				ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_SHORE_S)
			else:
				# Variação sutil na água rasa cristalina
				if (pos.x + pos.y) % 7 == 0:
					ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_WATER_RIPPLE)
				else:
					ground_layer.set_cell(pos, TILE_SOURCE_ID, TILE_WATER_SHALLOW)


func _cliff_y_at(x: int) -> int:
	var cliff_baseline = 10
	var elev_offset = int(elevation_noise.get_noise_2d(x * 1.5, 0) * 5.0)
	return clampi(cliff_baseline + elev_offset, 6, 14)


func _generate_paths() -> void:
	# Ponto de partida: Saída da caverna (porção superior central), logo abaixo do paredão
	var start_x = int(map_width * 0.35)
	var start_y = _cliff_y_at(start_x) + 1
	
	# Ponto do poço central
	var well_pos = Vector2i(int(map_width * 0.45), int(map_height * 0.52))
	
	# Ponto das ruínas antigas
	var ruins_pos = Vector2i(int(map_width * 0.72), int(map_height * 0.35))
	
	# Ponto da borda sul
	var south_pos = Vector2i(int(map_width * 0.40), map_height - 2)

	_carve_path(Vector2i(start_x, start_y), well_pos, 0)
	_carve_path(well_pos, ruins_pos, 1)
	_carve_path(well_pos, south_pos, 2)
	
	# Praça de terra circular ao redor do poço (mesmo material do caminho = coeso)
	_stamp_disc(Vector2(well_pos) + Vector2(0.5, 0.5), plaza_radius)


## Traça uma curva suave entre dois pontos e "carimba" um disco de raio constante ao longo
## dela no grid de vértices. O desvio lateral vem de ruído contínuo e é atenuado nas pontas
## (envelope senoidal), então os trechos sempre se conectam exatamente nos destinos.
func _carve_path(from: Vector2i, to: Vector2i, path_index: int) -> void:
	var a := Vector2(from) + Vector2(0.5, 0.5)
	var b := Vector2(to) + Vector2(0.5, 0.5)
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var normal := (b - a).normalized().orthogonal()
	var amp := clampf(length * 0.15, 1.0, path_wobble)
	var steps := int(ceil(length / 0.25))
	
	for i in range(steps + 1):
		var t := float(i) / steps
		var envelope := sin(PI * t)
		var n := path_noise.get_noise_2d(t * length, path_index * 137.0) * 2.0
		var p := a.lerp(b, t) + normal * n * amp * envelope
		_stamp_disc(p, path_radius)


func _stamp_disc(center: Vector2, radius: float) -> void:
	var r2 := radius * radius
	for vx in range(floori(center.x - radius), ceili(center.x + radius) + 1):
		for vy in range(floori(center.y - radius), ceili(center.y + radius) + 1):
			if vx < 0 or vy < 0 or vx > map_width or vy > map_height:
				continue
			# Comparação estrita: com raio 1.0 garante exatamente 2 vértices de largura
			if Vector2(vx, vy).distance_squared_to(center) < r2:
				_path_vertices[Vector2i(vx, vy)] = true


## Converte o campo de vértices em tiles (marching squares): cada célula olha seus 4 cantos
## e recebe a variação correspondente, gerando bordas e curvas suaves e contínuas.
func _render_paths() -> void:
	var valid: Dictionary = {}
	for v in _path_vertices:
		if _is_vertex_walkable(v):
			valid[v] = true
	
	for x in range(map_width):
		for y in range(map_height):
			var mask := 0
			if valid.has(Vector2i(x, y)): mask |= 1
			if valid.has(Vector2i(x + 1, y)): mask |= 2
			if valid.has(Vector2i(x + 1, y + 1)): mask |= 4
			if valid.has(Vector2i(x, y + 1)): mask |= 8
			if mask == 0:
				continue
			var pos := Vector2i(x, y)
			path_layer.set_cell(pos, PathTilesetBuilder.SOURCE_ID, PathTilesetBuilder.atlas_coords(mask))
			_path_cells[pos] = mask


## Um vértice só pode ser caminho se nenhuma das 4 células ao redor for água ou falésia
func _is_vertex_walkable(v: Vector2i) -> bool:
	for cell in [v, v + Vector2i(-1, 0), v + Vector2i(0, -1), v + Vector2i(-1, -1)]:
		if not _is_within_bounds(cell):
			continue
		var tile := ground_layer.get_cell_atlas_coords(cell)
		if _is_water_tile(tile) or _is_cliff_tile(tile):
			return false
	return true


func _is_near_path(pos: Vector2i, margin: int = 0) -> bool:
	for ox in range(-margin, margin + 1):
		for oy in range(-margin, margin + 1):
			if _path_cells.has(pos + Vector2i(ox, oy)):
				return true
	return false


func _generate_wheat_fields() -> void:
	# Campos dourados de trigo em bolsões abertos no leste/centro
	for x in range(int(map_width * 0.48), int(map_width * 0.82)):
		for y in range(int(map_height * 0.38), int(map_height * 0.68)):
			var pos = Vector2i(x, y)
			var n = moisture_noise.get_noise_2d(x * 1.8, y * 1.8)
			var current_ground = ground_layer.get_cell_atlas_coords(pos)
			
			# O trigo só nasce em grama pura! Jamais em água, areia ou caminhos de pedra
			if _is_water_or_sand(current_ground) or _is_near_path(pos, 1):
				continue
			
			if n > 0.34:
				if n > 0.48:
					decor_layer.set_cell(pos, TILE_SOURCE_ID, TILE_WHEAT_2)
				else:
					decor_layer.set_cell(pos, TILE_SOURCE_ID, TILE_WHEAT_1)


func _spawn_landmarks_and_props() -> void:
	if not props_container:
		return

	# 1. Entrada da Caverna na falésia
	var cave_x = int(map_width * 0.35)
	var cave_y = 10
	var cave_world_pos = Vector2(cave_x * tile_size, cave_y * tile_size)
	_instantiate_prop(SCENE_CAVE, cave_world_pos)
	
	# Cristais elementares próximos à entrada da caverna
	_instantiate_prop(SCENE_SALT_CRYSTAL, cave_world_pos + Vector2(70, 15))
	_instantiate_prop(SCENE_SALT_CRYSTAL, cave_world_pos + Vector2(-80, 25))
	_instantiate_prop(SCENE_EMERALD_CRYSTAL, cave_world_pos + Vector2(-120, -15))
	_instantiate_prop(SCENE_RUBY_CRYSTAL, cave_world_pos + Vector2(-150, 10))
	_instantiate_prop(SCENE_ORE_ROCK, cave_world_pos + Vector2(120, 20))

	# 2. Poço Central de Pedra
	var well_x = int(map_width * 0.45)
	var well_y = int(map_height * 0.52)
	var well_pos = Vector2(well_x * tile_size, well_y * tile_size)
	_instantiate_prop(SCENE_WELL, well_pos)
	
	# Palmeiras e flores ao redor do poço
	_instantiate_prop(SCENE_PALM_TREE, well_pos + Vector2(-70, -40))
	_instantiate_prop(SCENE_PALM_TREE, well_pos + Vector2(80, 50))
	_instantiate_prop(SCENE_BOULDER, well_pos + Vector2(60, -60))

	# 3. Ruínas Megalíticas (Stonehenge) no nordeste
	var ruins_x = int(map_width * 0.75)
	var ruins_y = int(map_height * 0.32)
	var ruins_pos = Vector2(ruins_x * tile_size, ruins_y * tile_size)
	_instantiate_prop(SCENE_STONEHENGE, ruins_pos)
	_instantiate_prop(SCENE_BOULDER, ruins_pos + Vector2(-90, 50))
	_instantiate_prop(SCENE_BOULDER, ruins_pos + Vector2(80, -40))

	# 4. Labirinto de Arbustos / Cerca Viva (Topiary Hedge Maze)
	var maze_x = int(map_width * 0.28)
	var maze_y = int(map_height * 0.72)
	var maze_pos = Vector2(maze_x * tile_size, maze_y * tile_size)
	_instantiate_prop(SCENE_HEDGE_MAZE, maze_pos)
	_instantiate_prop(SCENE_HEDGE_MAZE, maze_pos + Vector2(180, 40))

	# 5. Palmeiras Tropicais naturais ao longo da praia de areia
	var sand_cells: Array[Vector2i] = []
	for x in range(int(map_width * 0.40), map_width):
		for y in range(int(map_height * 0.40), map_height):
			var pos = Vector2i(x, y)
			var ground_tile = ground_layer.get_cell_atlas_coords(pos)
			if (ground_tile == TILE_SAND or ground_tile == TILE_SAND_DETAIL) and not _is_near_path(pos, 1):
				sand_cells.append(pos)
	
	if sand_cells.size() > 0:
		sand_cells.shuffle()
		var palms_placed = 0
		for p in sand_cells:
			if palms_placed >= 4:
				break
			var world_pos = Vector2(p.x * tile_size + 16, p.y * tile_size + 16)
			_instantiate_prop(SCENE_PALM_TREE, world_pos)
			palms_placed += 1

	# 6. Árvores e Rochas Orgânicas pelo Mapa (Apenas em terra firme)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val + 999
	
	for i in range(35):
		var rx = rng.randi_range(3, map_width - 4)
		var ry = rng.randi_range(14, map_height - 6)
		var tile_coord = Vector2i(rx, ry)
		var ground_tile = ground_layer.get_cell_atlas_coords(tile_coord)
		
		# Nunca instanciar em água, areia ou estrada de pedras
		if not _is_water_or_sand(ground_tile) and not _is_near_path(tile_coord, 1):
			var world_pos = Vector2(rx * tile_size, ry * tile_size)
			
			# Distância segura do poço e caverna
			if world_pos.distance_to(well_pos) > 120 and world_pos.distance_to(cave_world_pos) > 140:
				var roll = rng.randf()
				if roll < 0.50:
					_instantiate_prop(SCENE_TREE, world_pos)
				elif roll < 0.70:
					_instantiate_prop(SCENE_PALM_TREE, world_pos)
				else:
					_instantiate_prop(SCENE_BOULDER, world_pos)


func _instantiate_prop(scene: PackedScene, pos: Vector2) -> void:
	if not scene or not props_container:
		return
	var inst = scene.instantiate()
	inst.position = pos
	props_container.add_child(inst)


func _is_within_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < map_width and pos.y >= 0 and pos.y < map_height


func _is_land_pos(water_grid: Dictionary, pos: Vector2i) -> bool:
	if not _is_within_bounds(pos):
		return false
	if not water_grid.has(pos):
		return true
	return water_grid[pos] == "SAND"


func _is_water_tile(tile: Vector2i) -> bool:
	return tile == TILE_DEEP_WATER or tile == TILE_WATER_SHALLOW or tile == TILE_WATER_RIPPLE \
		or tile == TILE_SHORE_N or tile == TILE_SHORE_S or tile == TILE_SHORE_E or tile == TILE_SHORE_W \
		or tile == TILE_SHORE_INNER_SE or tile == TILE_SHORE_CORNER_NW or tile == TILE_SHORE_CORNER_NE or tile == TILE_SHORE_CORNER_SW


func _is_cliff_tile(tile: Vector2i) -> bool:
	return tile == TILE_CLIFF_TOP or tile == TILE_CLIFF_TOP_EDGE or tile == TILE_CLIFF_WALL_1 \
		or tile == TILE_CLIFF_WALL_2 or tile == TILE_CLIFF_WALL_3 or tile == TILE_CLIFF_LEDGE \
		or tile == TILE_CLIFF_BASE or tile == TILE_CLIFF_CORNER


func _is_water_or_sand(tile: Vector2i) -> bool:
	return _is_water_tile(tile) or tile == TILE_SAND or tile == TILE_SAND_DETAIL
