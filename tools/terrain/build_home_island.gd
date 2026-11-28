extends SceneTree
## Sculpts and paints the home island's terrain: samples
## [HomeIslandShape] into a heightmap, works out which texture each spot gets
## (grass on gentle ground, rock on steep, wet rock and shingle at the
## waterline, flagstones on the path) and a tint for it, and saves Terrain3D's
## region files, texture list and material under data/terrain/home_island/.
## Run it again after changing the shape or the textures; hand sculpting in the
## editor is kept only until you do. From the project folder:
##   godot_console.exe --headless --path . --script tools/terrain/build_home_island.gd
## Add `-- --preview=C:/somewhere/island.png` to also save a top-down picture
## (height shading, coloured by texture) to check the layout without playing.

const DIRECTORY: String = "res://data/terrain/home_island"
const TEXTURES: String = "res://assets/placeholder/textures/terrain/"
## One vertex every half metre; each region is 256 of them, so 128 m square.
const SPACING: float = 0.5
const REGION_SIZE: int = 256
## What the heightmap covers, in metres: x from -128 to 128, z from 0 to 128.
const ORIGIN: Vector2 = Vector2(-128.0, 0.0)
const WIDTH: int = 512
const HEIGHT: int = 256

## The texture list, in the order the terrain numbers them.
const GRASS: int = 0
const ROCK: int = 1
const WET_ROCK: int = 2
const SHINGLE: int = 3
const FLAGSTONE: int = 4
## Name, how many metres one repeat covers (texture's uv scale is its inverse).
const LAYERS: Array[Dictionary] = [
	{"name": "grass", "title": "Grass", "tile": 7.0},
	{"name": "rock", "title": "Purple-grey rock", "tile": 9.0},
	{"name": "wet_rock", "title": "Wet rock", "tile": 8.0},
	{"name": "shingle", "title": "Shingle", "tile": 4.0},
	{"name": "flagstone", "title": "Flagstones", "tile": 3.0},
]


func _initialize() -> void:
	_run()


func _run() -> void:
	var shape: HomeIslandShape = HomeIslandShape.new()
	var heights: PackedFloat32Array = _sample_heights(shape)
	var control: PackedFloat32Array = PackedFloat32Array()
	control.resize(WIDTH * HEIGHT)
	var colours: Image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	var picture: Image = Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGB8)
	_paint(shape, heights, control, colours, picture)

	var height_image: Image = Image.create_from_data(WIDTH, HEIGHT, false, Image.FORMAT_RF,
			heights.to_byte_array())
	var control_image: Image = Image.create_from_data(WIDTH, HEIGHT, false, Image.FORMAT_RF,
			control.to_byte_array())

	var terrain: Terrain3D = Terrain3D.new()
	terrain.region_size = Terrain3D.SIZE_256
	terrain.vertex_spacing = SPACING
	root.add_child(terrain)
	await process_frame
	var images: Array[Image] = [height_image, control_image, colours]
	terrain.data.import_images(images, Vector3(ORIGIN.x, 0.0, ORIGIN.y), 0.0, 1.0)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	# Remove old region files first, so a smaller island leaves no stale ones.
	for file: String in DirAccess.get_files_at(DIRECTORY):
		if file.begins_with("terrain3d"):
			DirAccess.remove_absolute(DIRECTORY.path_join(file))
	terrain.data.save_directory(DIRECTORY)
	var assets: Terrain3DAssets = _make_assets()
	var saved_assets: Error = ResourceSaver.save(assets, DIRECTORY.path_join("assets.tres"))
	var material: Terrain3DMaterial = _make_material()
	var saved_material: Error = ResourceSaver.save(material, DIRECTORY.path_join("material.tres"))
	print("BUILD_HOME_ISLAND regions %d, assets %s, material %s" % [
			terrain.data.get_region_count(), error_string(saved_assets),
			error_string(saved_material)])
	var preview: String = _preview_path()
	if preview != "":
		picture.save_png(preview)
		print("BUILD_HOME_ISLAND preview ", preview)
	terrain.free()
	quit(0)


func _sample_heights(shape: HomeIslandShape) -> PackedFloat32Array:
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(WIDTH * HEIGHT)
	for j: int in HEIGHT:
		for i: int in WIDTH:
			heights[j * WIDTH + i] = shape.height_at(ORIGIN.x + i * SPACING, ORIGIN.y + j * SPACING)
	return heights


## Fills [param control] (which texture, and the blend), [param colours] (the
## tint) and [param picture] (for checking) from the heights.
func _paint(shape: HomeIslandShape, heights: PackedFloat32Array, control: PackedFloat32Array,
		colours: Image, picture: Image) -> void:
	var heather: FastNoiseLite = FastNoiseLite.new()
	heather.seed = 41
	heather.frequency = 0.09
	var warm: FastNoiseLite = FastNoiseLite.new()
	warm.seed = 42
	warm.frequency = 0.03
	var wet_edge: FastNoiseLite = FastNoiseLite.new()
	wet_edge.seed = 43
	wet_edge.frequency = 0.25
	var sun: Vector3 = Vector3(-0.3, 0.6, -0.5).normalized()
	for j: int in HEIGHT:
		for i: int in WIDTH:
			var x: float = ORIGIN.x + i * SPACING
			var z: float = ORIGIN.y + j * SPACING
			var h: float = heights[j * WIDTH + i]
			var gx: float = (_at(heights, i + 1, j) - _at(heights, i - 1, j)) / (2.0 * SPACING)
			var gz: float = (_at(heights, i, j + 1) - _at(heights, i, j - 1)) / (2.0 * SPACING)
			var slope: float = Vector2(gx, gz).length()
			var steep: float = smoothstep(1.35, 2.3, slope)

			# Rock where it's steep, grass where it isn't.
			var base: int = ROCK if steep > 0.5 else GRASS
			var overlay: int = ROCK if base == GRASS else GRASS
			var blend: float = steep if base == GRASS else 1.0 - steep

			# Wet, dark rock and weed at the waterline.
			var wet: float = smoothstep(2.4, 0.5, h + wet_edge.get_noise_2d(x, z) * 0.9)
			if wet > 0.0 and h > -1.0:
				overlay = WET_ROCK
				blend = maxf(wet, 0.0)
			# Shingle in the cove and on the beach (but not on a cliff).
			var shingle: float = shape.shingle_at(x, z) * (1.0 - steep)
			if shingle > 0.02 and h > -0.8:
				overlay = SHINGLE
				blend = shingle
			# The path's flagstones, on top of everything.
			var path: Vector2 = shape.path_at(x, z)
			var path_weight: float = 1.0 - smoothstep(HomeIslandShape.PATH_HALF_WIDTH * 0.8,
					HomeIslandShape.PATH_HALF_WIDTH + 0.5, path.x)
			if path_weight > 0.02:
				overlay = FLAGSTONE
				blend = path_weight
			if h <= -1.0:
				# Under the sea: nobody sees it, so it's plain wet rock.
				base = WET_ROCK
				overlay = WET_ROCK
				blend = 0.0

			var packed: int = Terrain3DUtil.enc_base(base) | Terrain3DUtil.enc_overlay(overlay) \
					| Terrain3DUtil.enc_blend(int(clampf(blend, 0.0, 1.0) * 255.0))
			control[j * WIDTH + i] = Terrain3DUtil.as_float(packed)

			# The tint: warm gold and cool green in patches, and purple heather
			# on the grassy slopes, never over the path.
			var tint: Color = Color(1, 1, 1, 0.5)
			if base == GRASS and overlay != FLAGSTONE:
				var w: float = warm.get_noise_2d(x, z) * 0.5 + 0.5
				tint = Color(0.88, 0.9, 0.7).lerp(Color(1.0, 0.96, 0.78), w)
				var heath: float = smoothstep(0.28, 0.5, heather.get_noise_2d(x, z)) \
						* smoothstep(4.0, 7.0, h) * (1.0 - steep) * (1.0 - path_weight)
				tint = tint.lerp(Color(0.78, 0.58, 0.92), heath * 0.75)
				tint.a = 0.5
			elif base == ROCK or base == WET_ROCK:
				# Moss and weed on the rock that faces up, patchy.
				var up: float = 1.0 / sqrt(1.0 + slope * slope)
				var moss: float = smoothstep(0.0, 0.45, heather.get_noise_2d(x * 1.7 + 50.0, z * 1.7)) 						* smoothstep(0.3, 0.7, up) * smoothstep(-1.0, 3.0, h)
				tint = Color(1, 1, 1, 0.5).lerp(Color(0.72, 0.95, 0.5, 0.5), moss * 0.85)
			colours.set_pixel(i, j, tint)

			# The preview: shaded relief, coloured by what's painted.
			var normal: Vector3 = Vector3(-gx, 1.0, -gz).normalized()
			var shade: float = clampf(normal.dot(sun) * 0.8 + 0.3, 0.1, 1.0)
			var key: Color = _preview_colour(base, overlay, blend, h)
			picture.set_pixel(i, j, key * shade)


func _at(heights: PackedFloat32Array, i: int, j: int) -> float:
	return heights[clampi(j, 0, HEIGHT - 1) * WIDTH + clampi(i, 0, WIDTH - 1)]


func _preview_colour(base: int, overlay: int, blend: float, h: float) -> Color:
	if h < 0.0:
		return Color(0.15, 0.25, 0.5).lerp(Color(0.1, 0.12, 0.3), clampf(-h / 20.0, 0.0, 1.0))
	var colours: Array[Color] = [Color(0.45, 0.65, 0.3), Color(0.55, 0.45, 0.6),
			Color(0.3, 0.3, 0.45), Color(0.85, 0.8, 0.65), Color(0.95, 0.85, 0.4)]
	return colours[base].lerp(colours[overlay], blend)


func _make_assets() -> Terrain3DAssets:
	var assets: Terrain3DAssets = Terrain3DAssets.new()
	for i: int in LAYERS.size():
		var layer: Dictionary = LAYERS[i]
		var texture: Terrain3DTextureAsset = Terrain3DTextureAsset.new()
		texture.name = layer["title"]
		texture.id = i
		texture.albedo_texture = load(TEXTURES + "%s_albedo.png" % layer["name"])
		texture.normal_texture = load(TEXTURES + "%s_normal.png" % layer["name"])
		var tile: float = layer["tile"]
		texture.uv_scale = 1.0 / tile
		texture.normal_depth = 0.8
		texture.detiling_rotation = 0.4
		texture.detiling_shift = 0.3
		assets.set_texture_asset(i, texture)
	return assets


func _make_material() -> Terrain3DMaterial:
	var material: Terrain3DMaterial = Terrain3DMaterial.new()
	# Nothing beyond the regions: the sea is drawn there.
	material.world_background = Terrain3DMaterial.NONE
	# Steep faces get their texture projected sideways, so rock isn't smeared.
	material.projection_enabled = true
	# The grass and the rock vary in tint over the island, not just in repeats.
	material.macro_variation_enabled = true
	material.auto_shader_enabled = false
	return material


func _preview_path() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--preview="):
			return argument.trim_prefix("--preview=")
	return ""
