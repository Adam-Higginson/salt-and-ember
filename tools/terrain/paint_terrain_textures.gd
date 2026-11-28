extends SceneTree
## Paints the home island's terrain textures (assets/placeholder/textures/terrain/):
## grass, purple-grey rock, wet rock, shingle and flagstones, each as an albedo
## picture with its height in the alpha channel (name_albedo.png) and a normal
## map with its roughness in the alpha channel (name_normal.png), as Terrain3D
## wants them. They are made from seamless noise and cells in soft, blotchy
## colours, like the other painted placeholders (docs/look.md). The same seeds
## always paint the same files. From the project folder:
##   godot_console.exe --headless --path . --script tools/terrain/paint_terrain_textures.gd
## then import them (godot_console.exe --headless --path . --import).

const OUT: String = "res://assets/placeholder/textures/terrain/"
const ORIGINALS: String = "res://tools/terrain/originals/"
const SIZE: int = 512

## The textures to paint, and the order they go in the terrain's texture list.
const NAMES: Array[String] = ["grass", "rock", "wet_rock", "shingle", "flagstone"]

var _noises: Dictionary[String, Image] = {}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for name: String in NAMES:
		_paint(name)
	_paint_wall()
	print("PAINT_TERRAIN done")
	quit(0)


## The drystone wall's picture (a seamless painting made for the island), shrunk,
## with a normal map from its own brightness, for the walls and steps.
func _paint_wall() -> void:
	var source: Image = Image.load_from_file(ORIGINALS + "drystone_wall.png")
	source.convert(Image.FORMAT_RGB8)
	source.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var grey: Image = source.duplicate() as Image
	grey.convert(Image.FORMAT_L8)
	grey.resize(SIZE / 2, SIZE / 2, Image.INTERPOLATE_BILINEAR)
	grey.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	grey.bump_map_to_normal_map(4.0)
	source.save_png(OUT + "drystone_wall_albedo.png")
	grey.save_png(OUT + "drystone_wall_normal.png")
	print("PAINTED drystone_wall")


func _paint(name: String) -> void:
	_noises.clear()
	var colours: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	var rough: float = 0.9
	match name:
		"grass":
			rough = 0.95
			_grass(colours, heights)
		"rock":
			rough = 0.85
			_rock(colours, heights)
		"wet_rock":
			rough = 0.4
			_wet_rock(colours, heights)
		"shingle":
			rough = 0.75
			_shingle(colours, heights)
		"flagstone":
			rough = 0.9
			_flagstone(colours, heights)
	# Height goes in the albedo's alpha, the normal map is made from it.
	var strength: float = 3.0 if name != "grass" else 1.6
	var normals: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in SIZE:
		for x: int in SIZE:
			var c: Color = colours.get_pixel(x, y)
			c.a = clampf(heights[y * SIZE + x], 0.0, 1.0)
			colours.set_pixel(x, y, c)
			var dx: float = _h(heights, x + 1, y) - _h(heights, x - 1, y)
			var dy: float = _h(heights, x, y + 1) - _h(heights, x, y - 1)
			# DirectX style: green points down the picture.
			var n: Vector3 = Vector3(-dx * strength * 8.0, dy * strength * 8.0, 1.0).normalized()
			normals.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5,
					clampf(rough + (heights[y * SIZE + x] - 0.5) * -0.15, 0.0, 1.0)))
	colours.save_png(OUT + name + "_albedo.png")
	normals.save_png(OUT + name + "_normal.png")
	print("PAINTED ", name)


func _h(heights: PackedFloat32Array, x: int, y: int) -> float:
	return heights[posmod(y, SIZE) * SIZE + posmod(x, SIZE)]


## A seamless noise picture, cached for this texture: [param key] names it.
func _noise(key: String, seed_value: int, frequency: float, octaves: int = 3,
		ridged: bool = false) -> Image:
	if _noises.has(key):
		return _noises[key]
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = frequency
	n.fractal_octaves = octaves
	if ridged:
		n.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	var image: Image = n.get_seamless_image(SIZE, SIZE, false, false, 0.15, true)
	_noises[key] = image
	return image


## The noise at a pixel, 0 to 1.
func _v(image: Image, x: int, y: int) -> float:
	return image.get_pixel(x, y).r


## Cells scattered over the texture (so it tiles): returns (distance to the
## nearest point, distance to the second nearest, a random number for the
## nearest cell), the distances in cell widths.
func _cells(x: int, y: int, count: int, seed_value: int, jitter: float = 0.9) -> Vector3:
	var cell: float = float(SIZE) / float(count)
	var gx: int = int(x / cell)
	var gy: int = int(y / cell)
	var best: float = 99.0
	var second: float = 99.0
	var which: float = 0.0
	for oy: int in range(-1, 2):
		for ox: int in range(-1, 2):
			var cx: int = gx + ox
			var cy: int = gy + oy
			var wrapped: Vector2i = Vector2i(posmod(cx, count), posmod(cy, count))
			var r: float = _hash(wrapped.x, wrapped.y, seed_value)
			var r2: float = _hash(wrapped.x, wrapped.y, seed_value + 1000)
			var px: float = (cx + 0.5 + (r - 0.5) * jitter) * cell
			var py: float = (cy + 0.5 + (r2 - 0.5) * jitter) * cell
			var d: float = Vector2(x - px, y - py).length() / cell
			if d < best:
				second = best
				best = d
				which = _hash(wrapped.x, wrapped.y, seed_value + 2000)
			elif d < second:
				second = d
	return Vector3(best, second, which)


func _hash(a: int, b: int, seed_value: int) -> float:
	var h: int = (a * 374761393 + b * 668265263 + seed_value * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


func _grass(colours: Image, heights: PackedFloat32Array) -> void:
	var patches: Image = _noise("p", 101, 0.006)
	var blades: Image = _noise("b", 102, 0.05, 4)
	var grain: Image = _noise("g", 103, 0.22, 2)
	var deep: Color = Color(0.3, 0.47, 0.2)
	var mid: Color = Color(0.48, 0.64, 0.24)
	var light: Color = Color(0.74, 0.74, 0.3)
	for y: int in SIZE:
		for x: int in SIZE:
			var p: float = _v(patches, x, y)
			var b: float = _v(blades, x, y)
			var g: float = _v(grain, x, y)
			var base: Color = deep.lerp(mid, smoothstep(0.3, 0.6, p)).lerp(light, smoothstep(0.58, 0.85, p))
			base = base.lerp(deep, smoothstep(0.55, 0.9, 1.0 - b) * 0.45)
			base = base.lightened((g - 0.5) * 0.25)
			colours.set_pixel(x, y, base)
			heights[y * SIZE + x] = b * 0.6 + g * 0.4


func _rock(colours: Image, heights: PackedFloat32Array) -> void:
	var warp: Image = _noise("w", 201, 0.01)
	var cracks: Image = _noise("c", 202, 0.03, 3, true)
	var grain: Image = _noise("g", 203, 0.2, 3)
	var lichen: Image = _noise("l", 204, 0.05, 2)
	var dark: Color = Color(0.3, 0.25, 0.36)
	var base: Color = Color(0.58, 0.5, 0.5)
	var pale: Color = Color(0.66, 0.58, 0.64)
	var rust: Color = Color(0.72, 0.5, 0.32)
	for y: int in SIZE:
		for x: int in SIZE:
			var w: float = _v(warp, x, y)
			var strata: float = 0.5 + 0.5 * sin((float(y) / SIZE + w * 0.12) * TAU * 7.0)
			var strata2: float = 0.5 + 0.5 * sin((float(y) / SIZE + w * 0.2) * TAU * 17.0 + 1.3)
			var c: float = _v(cracks, x, y)
			var g: float = _v(grain, x, y)
			var col: Color = dark.lerp(base, 0.1 + 0.9 * strata).lerp(pale, smoothstep(0.6, 1.0, strata2) * 0.55)
			col = col.lightened((g - 0.5) * 0.28)
			col = col.lerp(dark, smoothstep(0.6, 0.85, c) * 0.6)
			col = col.lerp(rust, smoothstep(0.62, 0.8, _v(lichen, x, y)) * 0.35)
			colours.set_pixel(x, y, col)
			heights[y * SIZE + x] = clampf(0.45 * strata + 0.3 * (1.0 - c) + 0.25 * g, 0.0, 1.0)


func _wet_rock(colours: Image, heights: PackedFloat32Array) -> void:
	var warp: Image = _noise("w", 301, 0.012)
	var grain: Image = _noise("g", 302, 0.16, 3)
	var algae: Image = _noise("a", 303, 0.04, 2)
	var dark: Color = Color(0.16, 0.15, 0.27)
	var base: Color = Color(0.28, 0.27, 0.4)
	var green: Color = Color(0.24, 0.36, 0.3)
	for y: int in SIZE:
		for x: int in SIZE:
			var w: float = _v(warp, x, y)
			var g: float = _v(grain, x, y)
			var strata: float = 0.5 + 0.5 * sin((float(y) / SIZE + w * 0.15) * TAU * 6.0)
			var col: Color = dark.lerp(base, 0.3 + 0.6 * strata).lightened((g - 0.5) * 0.2)
			col = col.lerp(green, smoothstep(0.6, 0.85, _v(algae, x, y)) * 0.5)
			colours.set_pixel(x, y, col)
			heights[y * SIZE + x] = clampf(0.5 * strata + 0.5 * g, 0.0, 1.0)


func _shingle(colours: Image, heights: PackedFloat32Array) -> void:
	var grain: Image = _noise("g", 401, 0.25, 2)
	var palette: Array[Color] = [Color(0.55, 0.52, 0.5), Color(0.42, 0.4, 0.46),
			Color(0.66, 0.6, 0.52), Color(0.5, 0.4, 0.36), Color(0.36, 0.36, 0.4),
			Color(0.7, 0.66, 0.6)]
	for y: int in SIZE:
		for x: int in SIZE:
			var cell: Vector3 = _cells(x, y, 26, 5)
			var pebble: Color = palette[int(cell.z * palette.size()) % palette.size()]
			pebble = pebble.lightened((_v(grain, x, y) - 0.5) * 0.22)
			var edge: float = smoothstep(0.0, 0.18, cell.y - cell.x)
			var dome: float = clampf(1.0 - cell.x * 1.9, 0.0, 1.0)
			colours.set_pixel(x, y, Color(0.18, 0.17, 0.2).lerp(pebble, edge))
			heights[y * SIZE + x] = dome * edge


## The path is a painted picture made for the island (tools/terrain/originals/
## path_stones.png, seamless), not noise: shrunk to size, its height read from
## its own brightness (stones high, grass and gaps low) so the bumps line up.
func _flagstone(colours: Image, heights: PackedFloat32Array) -> void:
	var source: Image = Image.load_from_file(ORIGINALS + "path_stones.png")
	source.convert(Image.FORMAT_RGB8)
	source.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	var grey: Image = source.duplicate() as Image
	grey.convert(Image.FORMAT_L8)
	# A slight blur, by shrinking and growing it again.
	grey.resize(SIZE / 2, SIZE / 2, Image.INTERPOLATE_BILINEAR)
	grey.resize(SIZE, SIZE, Image.INTERPOLATE_BILINEAR)
	for y: int in SIZE:
		for x: int in SIZE:
			colours.set_pixel(x, y, source.get_pixel(x, y))
			heights[y * SIZE + x] = grey.get_pixel(x, y).r
