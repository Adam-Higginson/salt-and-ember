extends GameTestSuite
## Tests for the home island's terrain: the shape's numbers, the island
## scene loading, and every prop in home waters standing on the ground rather
## than floating above it or buried in it. They need Terrain3D (committed, in
## addons/) and the saved region files, never the art.

const ISLAND: String = "res://scenes/props/home/home_island.tscn"
const HOME_WATERS: String = "res://scenes/prototype/intro/home_waters.tscn"
## How far a building may be from the ground's height at its middle: its shelf
## is flat, but the heightmap is a vertex every half metre.
const TOLERANCE: float = 0.6

var _shape: HomeIslandShape = HomeIslandShape.new()


func test_the_shapes_shelves_are_at_their_buildings_heights() -> void:
	for shelf: Dictionary in HomeIslandShape.SHELVES:
		var pos: Vector3 = shelf["pos"]
		assert_float(_shape.height_at(pos.x, pos.z)).override_failure_message(
				"%s's shelf isn't level with it" % shelf["name"]).is_equal_approx(pos.y, 0.3)


func test_the_summit_is_flat_under_the_mooring() -> void:
	assert_float(_shape.height_at(0.0, 70.0)).is_equal_approx(HomeIslandShape.SUMMIT, 0.3)
	assert_float(_shape.height_at(3.0, 67.0)).is_equal_approx(HomeIslandShape.SUMMIT, 0.5)


func test_the_path_follows_the_heights_it_was_given() -> void:
	for path: PackedVector3Array in HomeIslandShape.paths:
		for point: Vector3 in path:
			assert_float(_shape.height_at(point.x, point.z)).override_failure_message(
					"The path at %s" % point).is_equal_approx(point.y, 0.3)


func test_the_shape_is_the_same_every_time() -> void:
	var other: HomeIslandShape = HomeIslandShape.new()
	assert_float(other.height_at(-17.3, 41.9)).is_equal(_shape.height_at(-17.3, 41.9))
	assert_int(other.rocks().size()).is_equal(_shape.rocks().size())


func test_the_sea_floor_is_under_water_far_from_the_island() -> void:
	assert_float(_shape.height_at(-100.0, 10.0)).is_less(-5.0)
	assert_float(_shape.height_at(100.0, 120.0)).is_less(-5.0)


func test_the_island_scene_loads_with_its_regions() -> void:
	var island: Node3D = _new_scene(ISLAND) as Node3D
	var terrain: Terrain3D = island.get_node("Terrain") as Terrain3D
	assert_int(terrain.data.get_region_count()).is_equal(2)
	assert_float(terrain.data.get_height(Vector3(0.0, 0.0, 70.0))).is_equal_approx(
			HomeIslandShape.SUMMIT, 0.5)
	assert_bool(island.has_node("Dressing")).is_true()


func test_the_dressing_stands_on_the_ground() -> void:
	var island: Node3D = _new_scene(ISLAND) as Node3D
	var terrain: Terrain3D = island.get_node("Terrain") as Terrain3D
	var dressing: Node3D = island.get_node("Dressing") as Node3D
	assert_int(dressing.get_child_count()).is_greater(0)
	for piece: Node in dressing.get_children():
		var node: Node3D = piece as Node3D
		var ground: float = terrain.data.get_height(node.global_position)
		assert_float(node.global_position.y - ground).override_failure_message(
				"%s is off the ground" % node.name).is_between(-0.5, 6.0)


func test_home_waters_props_sit_on_the_terrain() -> void:
	var world: Node3D = _new_scene(HOME_WATERS) as Node3D
	var terrain: Terrain3D = world.get_node("Island/Terrain/Terrain") as Terrain3D
	var on_land: PackedStringArray = ["Island/JettyCottage", "Island/Cottage2",
			"Island/Cottage3", "Island/Cottage4", "Island/Cottage5", "Island/Cottage6",
			"Island/Mooring", "Island/Lamps/Lamp3", "Island/Lamps/Lamp4",
			"Island/Lamps/Lamp5", "Island/Lamps/Lamp6"]
	for path: String in on_land:
		var prop: Node3D = world.get_node(path) as Node3D
		var ground: float = terrain.data.get_height(prop.global_position)
		assert_float(prop.global_position.y - ground).override_failure_message(
				"%s is %.2f m off the ground" % [path, prop.global_position.y - ground]
				).is_between(-TOLERANCE, TOLERANCE)


func test_the_jetty_stands_in_water_beside_the_beach() -> void:
	var world: Node3D = _new_scene(HOME_WATERS) as Node3D
	var terrain: Terrain3D = world.get_node("Island/Terrain/Terrain") as Terrain3D
	var jetty: Node3D = world.get_node("Island/Jetty") as Node3D
	# Its sea end is in deep enough water for the boat, its land end is dry.
	var sea_end: Vector3 = jetty.global_position + Vector3(0.0, 0.0, -4.0)
	var land_end: Vector3 = jetty.global_position + Vector3(0.0, 0.0, 5.0)
	assert_float(terrain.data.get_height(sea_end)).is_less(-0.5)
	assert_float(terrain.data.get_height(land_end)).is_greater_equal(-0.5)


func _new_scene(path: String) -> Node:
	var node: Node = (load(path) as PackedScene).instantiate()
	add_child(node)
	auto_free(node)
	return node
