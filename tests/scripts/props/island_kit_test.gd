extends GameTestSuite
## Tests for the home island's landscape kit (Meshy models: cliffs, boulders,
## a wind-bent tree, heather). Each prop keeps a greybox stand-in so the scene
## works with no art (a fresh clone, CI). These test the stand-in wiring, never
## the models.

const ISLAND: String = "res://scenes/props/home/island/"
const PROPS: Array[String] = [
	"cliff_a.tscn", "cliff_corner.tscn", "boulders.tscn", "tree_windbent.tscn", "heather.tscn",
]


func test_each_prop_has_a_model_node_with_stand_ins() -> void:
	for file: String in PROPS:
		var prop: Node3D = _new_scene(ISLAND + file)
		var model: ThirdPartyModel = prop.get_node("Model") as ThirdPartyModel
		assert_str(model.path).starts_with("res://assets/third_party/meshy/")
		assert_array(model.stand_ins).is_not_empty()


func test_without_the_art_the_stand_ins_show() -> void:
	for file: String in PROPS:
		var prop: Node3D = _new_scene(ISLAND + file)
		var model: ThirdPartyModel = prop.get_node("Model") as ThirdPartyModel
		model.path = ""  # no art, even on a machine that has it
		for stand_in: VisualInstance3D in model.stand_ins:
			assert_bool(stand_in.visible).override_failure_message(
					"%s: a stand-in is hidden" % file).is_true()


func test_the_gallery_lays_out_all_five_props() -> void:
	var gallery: Node3D = _new_scene(ISLAND + "kit_gallery.tscn")
	for prop_name: String in ["CliffA", "CliffCorner", "Boulders", "TreeWindbent", "Heather"]:
		assert_bool(gallery.has_node(prop_name)).override_failure_message(
				"gallery has no %s" % prop_name).is_true()


func _new_scene(path: String) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	add_child(node)
	auto_free(node)
	return node
