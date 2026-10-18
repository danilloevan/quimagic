class_name PathTilesetBuilder
extends RefCounted

## Gera proceduralmente um TileSet de caminho de terra com 16 variações (marching squares).
## Cada tile é escolhido pelos 4 cantos marcados como "caminho": TL=1, TR=2, BR=4, BL=8.
## Todas as variações compartilham a mesma textura base periódica e a mesma função de
## borda, então os tiles se encaixam sem emendas, formando um caminho contínuo e coeso.
## As áreas fora do caminho são transparentes: a grama da camada de baixo aparece.

const SOURCE_ID := 0
const COLS := 4

const COLOR_DIRT := Color8(0xA7, 0x7A, 0x41)
const COLOR_DIRT_LIGHT := Color8(0xB6, 0x8A, 0x50)
const COLOR_DIRT_DARK := Color8(0x96, 0x6B, 0x38)
const COLOR_DIRT_INNER_RIM := Color8(0x8A, 0x60, 0x31)
const COLOR_DIRT_RIM := Color8(0x6E, 0x4B, 0x27)
const COLOR_PEBBLE := Color8(0xCC, 0xB2, 0x86)
const COLOR_PEBBLE_SHADOW := Color8(0x7A, 0x56, 0x2E)
const COLOR_GRASS_LIP := Color(0.53, 0.80, 0.18, 0.9)
const COLOR_GRASS_SHADOW := Color(0.16, 0.33, 0.04, 0.35)

## Pedrinhas fixas (posição dentro do tile, largura). Só aparecem longe da borda.
const PEBBLES := [
	Vector3i(5, 6, 3), Vector3i(20, 3, 2), Vector3i(13, 18, 2),
	Vector3i(25, 23, 3), Vector3i(3, 26, 2), Vector3i(27, 11, 2),
]


static func atlas_coords(mask: int) -> Vector2i:
	return Vector2i(mask % COLS, mask / COLS)


static func build(tile_size: int = 32) -> TileSet:
	var s := tile_size
	var img := Image.create(s * COLS, s * COLS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for mask in range(1, 16):
		var origin := atlas_coords(mask) * s
		for py in range(s):
			for px in range(s):
				img.set_pixel(origin.x + px, origin.y + py, _pixel(mask, px, py, s))

	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(s, s)
	for mask in range(1, 16):
		src.create_tile(atlas_coords(mask))

	var ts := TileSet.new()
	ts.tile_size = Vector2i(s, s)
	ts.add_source(src, SOURCE_ID)
	return ts


static func _pixel(mask: int, px: int, py: int, s: int) -> Color:
	var tl := 1.0 if mask & 1 else 0.0
	var tr := 1.0 if mask & 2 else 0.0
	var br := 1.0 if mask & 4 else 0.0
	var bl := 1.0 if mask & 8 else 0.0

	var u := (px + 0.5) / s
	var v := (py + 0.5) / s

	# Campo bilinear entre os cantos e seu gradiente (por pixel)
	var f := lerpf(lerpf(tl, tr, u), lerpf(bl, br, u), v)
	var gu := lerpf(tr - tl, br - bl, v)
	var gv := lerpf(bl - tl, br - tr, u)
	var grad := Vector2(gu, gv).length() / s

	# Distância assinada aproximada até a borda, em pixels (+ = dentro do caminho)
	var sd: float
	if grad < 0.00001:
		sd = 100.0 if f > 0.5 else -100.0
	else:
		sd = clampf((f - 0.5) / grad, -100.0, 100.0)
	sd += _edge_jitter(px, py, s)

	if sd < -2.0:
		return Color(0, 0, 0, 0)
	if sd < -1.0:
		return COLOR_GRASS_SHADOW
	if sd < 0.0:
		return COLOR_GRASS_LIP
	if sd < 1.25:
		return COLOR_DIRT_RIM
	if sd < 2.5:
		return COLOR_DIRT_INNER_RIM
	return _dirt_texture(px, py, s, sd)


## Ondulação periódica da borda (período = tamanho do tile), garantindo continuidade
## entre tiles vizinhos. Amplitude ~1px para dar um contorno orgânico, mas uniforme.
static func _edge_jitter(px: int, py: int, s: int) -> float:
	var x := float(px) / s * TAU
	var y := float(py) / s * TAU
	var j := 0.55 * sin(2.0 * x + y) + 0.35 * sin(3.0 * x - 2.0 * y + 1.7) + 0.3 * sin(5.0 * y - x + 0.6)
	return j * 0.9


static func _dirt_texture(px: int, py: int, s: int, sd: float) -> Color:
	# Pedrinhas (apenas no miolo do caminho)
	if sd > 4.0:
		for p in PEBBLES:
			var dx: int = px - p.x
			var dy: int = py - p.y
			if dx >= 0 and dx < p.z and dy >= 0 and dy < 2:
				return COLOR_PEBBLE if dy == 0 else COLOR_PEBBLE_SHADOW

	var x := float(px) / s * TAU
	var y := float(py) / s * TAU
	# Manchas suaves de baixa frequência (periódicas)
	var patch := 0.5 * sin(x + 2.0 * y + 0.8) + 0.5 * sin(2.0 * x - y + 2.1)
	var h := _hash(px % s, py % s)

	if h < 0.05:
		return COLOR_DIRT_DARK
	if h > 0.95:
		return COLOR_DIRT_LIGHT
	if patch > 0.72:
		return COLOR_DIRT_LIGHT
	if patch < -0.78:
		return COLOR_DIRT_DARK
	return COLOR_DIRT


static func _hash(x: int, y: int) -> float:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0
