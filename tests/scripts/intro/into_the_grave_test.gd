extends GameTestSuite
## Tests for IntoTheGrave (#230): the boat can't be steered while the Grave's
## lights come up, the reveal lines play once and in order, "Reach for him"
## only appears after he's pulled off the pole and works once, the boat
## capsizes, the rescue plays after it, and the end signal fires once.

const SCENE: PackedScene = preload("res://scenes/prototype/intro/into_the_grave.tscn")

var _runner: GdUnitSceneRunner = null
var _beat: IntoTheGrave = null


func before_test() -> void:
	Game.dialogue.reset()


func after_test() -> void:
	Game.dialogue.reset()


func test_it_waits_to_be_begun_when_told_to() -> void:
	_start(false)
	await physics_ticks(_runner, 5)

	assert_int(_beat.beat).is_equal(IntoTheGrave.Beat.WAITING)
	assert_float(_beat.current.takeover).is_equal(0.0)
	assert_bool(_beat.conversation.is_active()).is_false()

	assert_bool(_beat.begin()).is_true()
	assert_bool(_beat.begin()).is_false()
	assert_float(_beat.current.takeover).is_equal(1.0)


func test_the_boat_cant_be_steered() -> void:
	_start()
	await physics_ticks(_runner, 5)

	await walk(_runner, "move_up", 90)
	await walk(_runner, "move_right", 60)

	# The sea has it: the stick rows nothing and turns nothing, and it's
	# carried the way the water runs (towards -Z) no faster than the water.
	assert_float(_beat.boat.own_share()).is_equal(0.0)
	assert_bool(_beat.boat.controls_enabled).is_false()
	assert_bool(_beat.boat.is_stroking()).is_false()
	assert_float(_beat.boat.position.z).is_less(-1.0)
	assert_float(absf(_beat.boat.position.x)).is_less(0.2)
	assert_float(_beat.boat.velocity.length()).is_less_equal(_beat.current.speed + 0.01)


func test_the_lights_come_up_under_the_sea() -> void:
	_start()
	_beat.lights_seconds = 0.5
	await physics_ticks(_runner, 5)
	assert_float(_beat.sea.grave).is_less(0.5)

	_beat.conversation.skip()
	await physics_ticks(_runner, 5)

	assert_float(_beat.sea.grave).is_equal(1.0)


func test_the_reveal_plays_each_line_once_in_order() -> void:
	_start()
	var sections: Array[StringName] = []
	_beat.conversation.line_said.connect(func(_speaker: Person) -> void:
		sections.append(_beat.conversation.section()))
	await physics_ticks(_runner, 5)
	var arrivals: Array[StringName] = []
	_beat.conversation.ended.connect(func(tree_id: StringName) -> void: arrivals.append(tree_id))

	await _read_to_end()
	var lines_said: int = sections.size()
	await physics_ticks(_runner, 120)

	var tree: DialogueTree = DialogueLibrary.find(IntoTheGrave.LINES)
	var expected: Array[StringName] = []
	for section: StringName in [&"start", &"the_dead"]:
		for step: DialogueStep in Remark.steps_of(tree, section):
			if step.kind == DialogueStep.Kind.LINE:
				expected.append(section)
	assert_array(sections).is_equal(expected)
	assert_int(lines_said).is_greater(5)
	# Nothing starts it again, and the beat has moved on to the pull.
	assert_array(arrivals).is_equal([IntoTheGrave.LINES])
	assert_int(sections.size()).is_equal(lines_said)
	assert_int(_beat.beat).is_greater_equal(IntoTheGrave.Beat.PULL)
	assert_bool(_beat.begin()).is_false()


func test_reach_for_him_only_comes_after_he_is_pulled_off() -> void:
	_start()
	_hurry()
	await physics_ticks(_runner, 5)
	# While the lights come up there's nothing to reach for.
	assert_bool(_beat.can_reach()).is_false()
	assert_bool(_beat.reach()).is_false()
	assert_bool(_beat.prompt.is_prompting).is_false()

	var start_y: float = _beat.lantern.position.y
	var offered: Array[bool] = []
	_beat.reach_offered.connect(func() -> void: offered.append(true))
	_beat.conversation.skip()
	await physics_ticks(_runner, 3)

	# He's being pulled off, but it isn't on offer until he's in the water.
	assert_int(_beat.beat).is_equal(IntoTheGrave.Beat.PULL)
	assert_bool(_beat.can_reach()).is_false()
	assert_bool(_beat.reach()).is_false()
	assert_bool(_beat.prompt.is_prompting).is_false()

	await physics_ticks(_runner, 60)

	assert_array(offered).is_equal([true])
	assert_bool(_beat.can_reach()).is_true()
	assert_bool(_beat.prompt.is_prompting).is_true()
	# He's sunk below where he hung, with his light.
	assert_float(_beat.lantern.position.y).is_less(start_y - 3.0)
	assert_object(_beat.lantern_light.get_parent()).is_same(_beat.lantern)


func test_reach_works_once_and_starts_the_capsize() -> void:
	_start()
	_hurry()
	var capsizes: Array[bool] = []
	_beat.capsized.connect(func() -> void: capsizes.append(true))
	await _reach_for_him()

	assert_bool(_beat.reach()).is_true()
	assert_bool(_beat.reach()).is_false()
	assert_int(_beat.beat).is_equal(IntoTheGrave.Beat.CAPSIZE)
	assert_bool(_beat.prompt.is_prompting).is_false()
	await physics_ticks(_runner, 40)

	# The boat has gone over, once.
	assert_array(capsizes).is_equal([true])
	assert_float(_beat.boat.capsize_roll).is_equal_approx(deg_to_rad(_beat.capsize_degrees), 0.01)


func test_the_rescue_starts_after_the_capsize_under_black() -> void:
	_start()
	_hurry()
	await _reach_for_him()
	assert_bool(_beat.conversation.is_active()).is_false()

	_beat.reach()
	await physics_ticks(_runner, 5)
	# Still going over: the rescue hasn't started.
	assert_bool(_beat.conversation.is_active()).is_false()
	assert_int(_beat.beat).is_equal(IntoTheGrave.Beat.CAPSIZE)
	await physics_ticks(_runner, 60)

	assert_int(_beat.beat).is_equal(IntoTheGrave.Beat.RESCUE)
	assert_str(_beat.conversation.talking).is_equal(IntoTheGrave.LINES)
	assert_bool(_underwater().is_open).is_true()


func test_the_end_signal_fires_once_when_the_rescue_is_over() -> void:
	_start()
	_hurry()
	var ends: Array[bool] = []
	_beat.finished.connect(func() -> void: ends.append(true))
	await _reach_for_him()
	_beat.reach()
	await physics_ticks(_runner, 60)
	assert_array(ends).is_empty()
	assert_bool(_beat.ending.visible).is_false()

	_beat.conversation.skip()
	await physics_ticks(_runner, 30)
	await physics_ticks(_runner, 60)

	assert_array(ends).is_equal([true])
	assert_int(_beat.beat).is_equal(IntoTheGrave.Beat.DONE)
	assert_bool(_beat.ending.visible).is_true()
	assert_bool(_beat.conversation.is_active()).is_false()
	# The stage is put away at the end.
	assert_bool(_underwater().is_open).is_false()


func test_every_section_it_plays_is_in_the_script() -> void:
	var tree: DialogueTree = DialogueLibrary.find(IntoTheGrave.LINES)

	assert_object(tree).is_not_null()
	assert_array(tree.errors).is_empty()
	assert_bool(tree.has_section(IntoTheGrave.REVEAL)).is_true()
	assert_bool(tree.has_section(IntoTheGrave.RESCUE_SECTION)).is_true()


# Loads the scene and begins it (or not).
func _start(begin_now: bool = true) -> void:
	_beat = SCENE.instantiate() as IntoTheGrave
	_beat.begin_on_start = begin_now
	auto_free(_beat)
	_runner = scene_runner(_beat)


# Makes everything that takes seconds take a moment.
func _hurry() -> void:
	_beat.lights_seconds = 0.3
	_beat.pull_seconds = 0.3
	_beat.capsize_seconds = 0.2
	_beat.settle_seconds = 0.1
	_beat.fade_seconds = 0.1
	_beat.fade.fade_seconds = 0.1
	_beat.prompt.delay_seconds = 0.0


# Reads the conversation under way a line at a time until it's over.
func _read_to_end() -> void:
	var presses: int = 0
	while _beat.conversation.is_active() and presses < 600:
		await physics_ticks(_runner, 4)
		_beat.conversation.press()
		presses += 1


# Skips the reveal and waits for "Reach for him" to come on offer.
func _reach_for_him() -> void:
	await physics_ticks(_runner, 5)
	_beat.conversation.skip()
	var waited: int = 0
	while not _beat.can_reach() and waited < 200:
		await physics_ticks(_runner, 1)
		waited += 1
	assert_bool(_beat.can_reach()).is_true()


func _underwater() -> Stage:
	return _beat.get_node("Stages/Underwater") as Stage
