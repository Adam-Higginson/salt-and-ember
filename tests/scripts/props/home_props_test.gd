extends GameTestSuite
## Tests for the home-waters props and the rowboat dressed with Meshy models
## (#234): each is one reusable part with named attach points, and each keeps
## its greybox stand-ins so the scene works with no art (a fresh clone, CI).
## These test the markers and the stand-in wiring, never the models.

const HOME: String = "res://scenes/props/home/"
const BOAT: String = "res://scenes/prototype/intro/rowboat.tscn"

## Scene file, then the attach points (paths) it must have.
const PARTS: Dictionary[String, Array] = {
	"cottage.tscn": ["SmokeOut", "SmokeOut/Smoke", "WindowLight"],
	"jetty_cottage.tscn": ["LanternHook", "SmokeOut", "SmokeOut/Smoke", "SiblingVoice",
			"BigWindow", "WindowLight"],
	"jetty.tscn": ["TieUp"],
	"lamp_post.tscn": ["LanternHook", "LanternHook/Lantern"],
	"mooring.tscn": ["ChainEye"],
	"hydrangea_pots.tscn": [],
}


func test_each_prop_has_its_attach_points() -> void:
	for file: String in PARTS:
		var prop: Node = _new_scene(HOME + file)
		for path: String in PARTS[file]:
			assert_bool(prop.has_node(path)).override_failure_message(
					"%s has no %s" % [file, path]).is_true()


func test_each_prop_has_a_model_node_with_stand_ins() -> void:
	for file: String in PARTS:
		var prop: Node = _new_scene(HOME + file)
		var found: int = 0
		for node: Node in prop.find_children("*", "Node3D", true, false):
			var model: ThirdPartyModel = node as ThirdPartyModel
			if model == null:
				continue
			found += 1
			assert_str(model.path).starts_with("res://assets/third_party/meshy/")
			assert_array(model.stand_ins).is_not_empty()
		assert_int(found).override_failure_message(
				"%s has no ThirdPartyModel" % file).is_greater(0)


func test_the_great_chain_starts_where_the_mooring_eye_is() -> void:
	# home_waters.tscn puts the Chain's top at the mooring's ChainEye by number.
	var world: Node3D = _new_scene("res://scenes/prototype/intro/home_waters.tscn") as Node3D
	var mooring: Node3D = world.get_node("Island/Mooring") as Node3D
	var eye: Marker3D = mooring.get_node("ChainEye") as Marker3D
	var chain: HangingChain = world.get_node("Chain") as HangingChain
	assert_vector(chain.top).is_equal_approx(chain.to_local(eye.global_position),
			Vector3.ONE * 0.5)


func test_the_lamp_posts_lantern_hangs_from_its_hook() -> void:
	var post: Node3D = _new_scene(HOME + "lamp_post.tscn") as Node3D
	var hook: Marker3D = post.get_node("LanternHook") as Marker3D
	var lantern: Lantern = hook.get_node("Lantern") as Lantern
	assert_vector(lantern.global_position).is_equal_approx(hook.global_position,
			Vector3.ONE * 0.001)
	# The lantern is the post's light: no second light on the post itself.
	assert_object(post.get_node_or_null("Light")).is_null()


func test_the_boats_oars_pivot_at_its_oarlocks() -> void:
	var boat: Node3D = _new_scene(BOAT) as Node3D
	for side: String in ["Port", "Starboard"]:
		var lock: Marker3D = boat.get_node("Oarlock" + side) as Marker3D
		var pivot: Node3D = boat.get_node("Oar" + side) as Node3D
		assert_vector(pivot.position).is_equal_approx(lock.position, Vector3.ONE * 0.001)


func test_the_boats_lantern_hangs_from_the_bow_pole_hook() -> void:
	var boat: Node3D = _new_scene(BOAT) as Node3D
	var hook: Marker3D = boat.get_node("BowPole/LanternHook") as Marker3D
	var lantern: Node3D = boat.get_node("BowPole/Lantern") as Node3D
	# The lantern's ring is 0.21 above its middle, so it hangs a little below.
	assert_float(lantern.global_position.y).is_less(hook.global_position.y)
	assert_float(lantern.global_position.y).is_greater(hook.global_position.y - 0.4)
	assert_float(lantern.global_position.z).is_equal_approx(hook.global_position.z, 0.001)


func _new_scene(path: String) -> Node:
	var node: Node = (load(path) as PackedScene).instantiate()
	add_child(node)
	auto_free(node)
	return node


func test_the_cottage_windows_show_in_front_of_the_greybox_wall() -> void:
	# With no art the Body stays visible, so each window glow must sit out
	# past its front face (z = 2.5) or the wall hides it.
	var windows: Dictionary[String, Array] = {
		"cottage.tscn": ["WindowUpper", "WindowLower"],
		"jetty_cottage.tscn": ["BigWindowGreybox"],
	}
	for file: String in windows:
		var prop: Node3D = _new_scene(HOME + file) as Node3D
		var model: ThirdPartyModel = prop.find_children("*", "ThirdPartyModel", true, false)[0]
		model.path = ""  # no art, even on a machine that has it
		var body: MeshInstance3D = prop.get_node("Body") as MeshInstance3D
		var box: BoxMesh = body.mesh as BoxMesh
		var front: float = body.position.z + box.size.z / 2.0
		assert_bool(body.visible).is_true()
		for window_name: String in windows[file]:
			var window: MeshInstance3D = prop.get_node(window_name) as MeshInstance3D
			var window_box: BoxMesh = window.mesh as BoxMesh
			var window_front: float = window.position.z \
					+ window_box.size.z * window.scale.z / 2.0
			assert_bool(window.visible).is_true()
			assert_float(window_front).override_failure_message(
					"%s/%s is behind the wall" % [file, window_name]).is_greater(front)
