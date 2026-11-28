extends GameTestSuite
## Tests for SeaSpray: spray that follows the boat and is handed the sea's
## waves and the posts standing in the water.

const SPRAY_SCENE: String = "res://scenes/prototype/weather/sea_spray.tscn"
const SEA_SCENE: String = "res://scenes/prototype/weather/sea_surface.tscn"
const DUSK_SWELL: WaveSettings = preload("res://data/sea/dusk_swell.tres")


func test_the_scene_loads_and_frees_cleanly() -> void:
	var spray: SeaSpray = (load(SPRAY_SCENE) as PackedScene).instantiate() as SeaSpray
	add_child(spray)
	assert_object(spray.process_material).is_instanceof(ShaderMaterial)
	spray.free()


func test_it_follows_the_boat_and_is_given_the_waves_and_posts() -> void:
	var world: Node3D = Node3D.new()
	auto_free(world)
	add_child(world)
	var sea: Sea = (load(SEA_SCENE) as PackedScene).instantiate() as Sea
	sea.settings = DUSK_SWELL
	world.add_child(sea)
	var boat: Node3D = Node3D.new()
	boat.position = Vector3(12.0, 0.4, -7.0)
	world.add_child(boat)
	var spray: SeaSpray = (load(SPRAY_SCENE) as PackedScene).instantiate() as SeaSpray
	spray.follow = boat
	spray.posts = PackedVector2Array([Vector2(1.0, 2.0), Vector2(3.0, 4.0)])
	world.add_child(spray)

	spray._process(1.0 / 60.0)

	assert_float(spray.global_position.x).is_equal_approx(12.0, 0.001)
	assert_float(spray.global_position.z).is_equal_approx(-7.0, 0.001)
	var material: ShaderMaterial = spray.process_material as ShaderMaterial
	assert_int(material.get_shader_parameter(&"wave_count")).is_equal(4)
	assert_int(material.get_shader_parameter(&"post_count")).is_equal(2)
	var posts: PackedVector3Array = material.get_shader_parameter(&"posts")
	assert_vector(posts[1]).is_equal(Vector3(3.0, 4.0, spray.post_radius))
