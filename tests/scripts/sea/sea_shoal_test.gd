extends GameTestSuite
## Tests for SeaShoal: shoals of fish under the open sea that wander round
## their anchors, stay under water, scatter from the oars and come back.

const SHOAL_SCENE: String = "res://scenes/prototype/weather/sea_shoal.tscn"


func test_the_scene_loads_and_frees_cleanly() -> void:
	var shoal: SeaShoal = (load(SHOAL_SCENE) as PackedScene).instantiate() as SeaShoal
	add_child(shoal)
	assert_int(shoal.multimesh.instance_count).is_equal(shoal.shoals * shoal.fish_per_shoal)
	shoal.free()


func test_shoals_swim_under_the_water_near_their_anchor() -> void:
	var shoal: SeaShoal = _world()
	var anchor: Node3D = shoal.anchors[0]
	for tick: int in 300:
		shoal._process(1.0 / 60.0)
	for index: int in shoal.shoals:
		var centre: Vector3 = shoal.centre(index)
		assert_float(centre.y).is_less(-0.9)
		var flat: Vector2 = Vector2(centre.x - anchor.global_position.x,
				centre.z - anchor.global_position.z)
		assert_float(flat.length()).is_less(shoal.roam + 4.0)


func test_a_stroke_scatters_the_shoals_near_the_boat_only() -> void:
	var shoal: SeaShoal = _world()
	var anchor: Node3D = shoal.anchors[0]
	# Put one shoal right by the boat and one well away.
	shoal._centres[0] = anchor.global_position + Vector3(1.0, -1.2, 0.0)
	shoal._centres[1] = anchor.global_position + Vector3(20.0, -1.2, 0.0)
	var heard: Array[bool] = [false]
	shoal.scattered.connect(func() -> void: heard[0] = true)

	anchor.emit_signal(&"stroked")

	assert_bool(heard[0]).is_true()
	assert_bool(shoal.is_darting(0)).is_true()
	assert_bool(shoal.is_darting(1)).is_false()
	for tick: int in 30:
		shoal._process(1.0 / 60.0)
	var away: float = (shoal.centre(0) - anchor.global_position).length()
	assert_float(away).is_greater(1.5)


func test_a_shoal_left_far_behind_comes_back_near_its_anchor() -> void:
	var shoal: SeaShoal = _world()
	var anchor: Node3D = shoal.anchors[0]
	shoal._centres[0] = anchor.global_position + Vector3(200.0, -1.2, 0.0)
	shoal._process(1.0 / 60.0)
	var flat: Vector3 = shoal.centre(0) - anchor.global_position
	flat.y = 0.0
	assert_float(flat.length()).is_less_equal(shoal.regroup_at + 0.5)


# A shoal round a boat stand-in (its first anchor, with a stroked signal
# like the Rowboat's), in a world freed after the test. Tests step the shoal themselves.
func _world() -> SeaShoal:
	var world: Node3D = Node3D.new()
	auto_free(world)
	add_child(world)
	var boat: Node3D = Node3D.new()
	boat.add_user_signal("stroked")
	boat.position = Vector3(5.0, 0.0, -3.0)
	world.add_child(boat)
	var shoal: SeaShoal = (load(SHOAL_SCENE) as PackedScene).instantiate() as SeaShoal
	shoal.anchors = [boat, boat]
	shoal.shoals = 2
	shoal.set_process(false)
	world.add_child(shoal)
	return shoal
