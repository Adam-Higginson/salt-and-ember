class_name IslandDressing
extends Node3D
## Greybox stand-ins for what dresses the home island: wind-bent trees, heather,
## and drystone walls below the cottages. They are placed where the island's
## map says (see [HomeIslandShape]) and set on the terrain's surface when the
## scene starts, so they follow any change to the heightmap. The Meshy kit
## replaces them: delete this node's children and put the kit's pieces here, or
## turn this off with [member enabled].

## Where the ground is read from.
@export var terrain: Terrain3D = null
## Whether to build the stand-ins.
@export var enabled: bool = true
## The stone texture the walls are boxed in.
@export var wall_material: Material = null

## Trees: x, z. Chosen to sit between the cottages, off the path.
const TREES: Array[Vector2] = [
	Vector2(-24, 47), Vector2(-20, 57), Vector2(-11, 63), Vector2(-28, 58),
	Vector2(27, 56), Vector2(28, 69), Vector2(17, 79), Vector2(-3, 81),
	Vector2(-17, 72), Vector2(24, 51), Vector2(4, 58), Vector2(-26, 66),
]
const HEATHER_COUNT: int = 36
const HEATHER_SEED: int = 19

var _shape: HomeIslandShape = HomeIslandShape.new()


func _ready() -> void:
	if enabled and terrain != null:
		_build()


func _build() -> void:
	var bark: StandardMaterial3D = _flat(Color(0.34, 0.24, 0.2))
	var leaf: StandardMaterial3D = _flat(Color(0.36, 0.6, 0.22))
	var heather: StandardMaterial3D = _flat(Color(0.5, 0.32, 0.6))
	for spot: Vector2 in TREES:
		var ground: float = _ground(spot.x, spot.y)
		if is_nan(ground) or ground < 2.0 or _shape.path_at(spot.x, spot.y).x < 3.5:
			continue
		_tree(Vector3(spot.x, ground, spot.y), bark, leaf)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = HEATHER_SEED
	var placed: int = 0
	var tries: int = 0
	while placed < HEATHER_COUNT and tries < 600:
		tries += 1
		var at: Vector2 = HomeIslandShape.CENTRE + Vector2(rng.randf_range(-34, 34),
				rng.randf_range(-34, 34))
		var ground: float = _ground(at.x, at.y)
		if is_nan(ground) or ground < 5.0 or _shape.path_at(at.x, at.y).x < 2.5:
			continue
		if _slope(at.x, at.y) > 0.5 or _near_shelf(at):
			continue
		_blob(Vector3(at.x, ground, at.y), rng.randf_range(0.5, 1.1), heather)
		placed += 1
	for i: int in range(1, HomeIslandShape.SHELVES.size()):
		_wall_below(i)


func _tree(base: Vector3, bark: Material, leaf: Material) -> void:
	var tree: Node3D = Node3D.new()
	tree.name = "Tree"
	tree.position = base
	# Bent a little, the way wind-blown island trees lean.
	tree.rotation = Vector3(0.0, base.x * 1.7, 0.12)
	var trunk: MeshInstance3D = MeshInstance3D.new()
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.4
	trunk_mesh.height = 3.4
	trunk.mesh = trunk_mesh
	trunk.material_override = bark
	trunk.position = Vector3(0.0, 1.5, 0.0)
	tree.add_child(trunk)
	var crown: MeshInstance3D = MeshInstance3D.new()
	var crown_mesh: SphereMesh = SphereMesh.new()
	crown_mesh.radius = 2.6
	crown_mesh.height = 3.2
	crown.mesh = crown_mesh
	crown.material_override = leaf
	crown.position = Vector3(0.6, 3.9, 0.0)
	tree.add_child(crown)
	add_child(tree)


func _blob(base: Vector3, size: float, material: Material) -> void:
	var blob: MeshInstance3D = MeshInstance3D.new()
	blob.name = "Heather"
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 0.9
	mesh.radial_segments = 8
	mesh.rings = 4
	blob.mesh = mesh
	blob.material_override = material
	blob.position = base + Vector3(0.0, size * 0.15, 0.0)
	add_child(blob)


## A drystone wall (a box) on the downhill side of shelf [param index].
func _wall_below(index: int) -> void:
	var shelf: Dictionary = HomeIslandShape.SHELVES[index]
	var pos: Vector3 = shelf["pos"]
	var half: Vector2 = shelf["half"]
	var downhill: Vector2 = Vector2(
			_ground(pos.x - 1.0, pos.z) - _ground(pos.x + 1.0, pos.z),
			_ground(pos.x, pos.z - 1.0) - _ground(pos.x, pos.z + 1.0))
	# Heading away from the middle of the island if the shelf is flat.
	if downhill.length() < 0.01:
		downhill = Vector2(pos.x, pos.z) - HomeIslandShape.CENTRE
	downhill = downhill.normalized()
	var at: Vector2 = Vector2(pos.x, pos.z) + downhill * (maxf(half.x, half.y) + 1.4)
	var ground: float = _ground(at.x, at.y)
	if is_nan(ground):
		return
	var wall: MeshInstance3D = MeshInstance3D.new()
	wall.name = "Wall%d" % (index + 1)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(7.0, 1.4, 0.6)
	wall.mesh = mesh
	wall.material_override = wall_material
	wall.position = Vector3(at.x, ground + 0.5, at.y)
	wall.rotation.y = atan2(-downhill.y, downhill.x) + PI * 0.5
	add_child(wall)


func _ground(x: float, z: float) -> float:
	return terrain.data.get_height(Vector3(x, 0.0, z))


func _slope(x: float, z: float) -> float:
	var dx: float = _ground(x + 1.0, z) - _ground(x - 1.0, z)
	var dz: float = _ground(x, z + 1.0) - _ground(x, z - 1.0)
	return Vector2(dx, dz).length() * 0.5


func _near_shelf(at: Vector2) -> bool:
	for i: int in HomeIslandShape.SHELVES.size():
		if _shape.outside_shelf(i, at.x, at.y) < 2.5:
			return true
	return false


func _flat(colour: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.95
	return material
