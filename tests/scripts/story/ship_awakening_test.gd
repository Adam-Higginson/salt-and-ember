extends GameTestSuite
## Tests for the ship coming alive (#249), in the real scene
## (scenes/prototype/sea.tscn), opened straight on the dark deck: the ship
## dark, the lantern weak, the stove lit once, the captain's cough and few
## words, and then the first quest.

const SEA: String = "res://scenes/prototype/sea.tscn"

var _sea: Node
var _awakening: ShipAwakening
var _lights: ShipLights
var _player: Player3D
var _ship: Ship
var _stove: GalleyStove
var _conversation: Conversation
var _spirit: LanternSpirit


func before_test() -> void:
	Game.dialogue.reset()
	SaveGame.erase()


func after_test() -> void:
	Game.dialogue.reset()
	SaveGame.erase()


func test_the_ship_starts_dark_with_the_stove_on_its_embers_and_the_captain_asleep() -> void:
	var runner: GdUnitSceneRunner = _build()
	await physics_ticks(runner, 5)

	assert_int(_awakening.stage).is_equal(ShipAwakening.Step.DARK)
	assert_bool(_lights.is_dark).is_true()
	assert_int(_lights.lamp_count()).is_greater(10)
	assert_int(_lights.lit_count()).is_equal(0)
	var windows: WindowDimmer = _awakening.get_node("Windows") as WindowDimmer
	assert_bool(windows.dimmed).is_true()
	assert_bool(_stove.burning).is_false()
	# The embers glow, but only dimly: the guide up the hatch.
	var fire: Flicker = _stove.get_node("FireLight") as Flicker
	assert_float(fire.level).is_between(0.01, 0.5)
	# No crew about but the captain, slumped asleep by his cabin door.
	assert_bool(_awakening.is_captain_asleep()).is_true()
	var captain: Crewmate = _captain()
	var mark: Node3D = _mark(&"CaptainAsleep")
	assert_float(captain.global_position.distance_to(mark.global_position)).is_less(0.1)
	assert_float((captain.get_node("Model") as Node3D).rotation.x).is_less(-0.2)
	# You're on deck, free to move, and he's weak at your shoulder.
	assert_bool(_player.controls_enabled).is_true()
	assert_bool(_spirit.is_low()).is_true()
	assert_bool(_ship.to_local(_player.global_position).y > 4.5).is_true()


func test_the_lanterns_float_is_weaker_the_dimmer_he_is() -> void:
	var runner: GdUnitSceneRunner = _build()
	await physics_ticks(runner, 5)
	var peak: float = 1.0 / (4.0 * _spirit.bob_rate)
	_spirit.warmth = 1.0
	assert_float(_spirit.weakness()).is_equal(0.0)
	var strong: Vector3 = _spirit.goal_spot()
	var strong_bob: float = absf(_spirit.bob_offset(peak))
	var light: Flicker = _spirit.get_node("Light") as Flicker
	_spirit.rekindle(0.0)
	var calm_amount: float = light.amount
	_spirit.warmth = _spirit.min_warmth
	assert_float(_spirit.weakness()).is_equal(1.0)
	var weak: Vector3 = _spirit.goal_spot()
	var weak_bob: float = absf(_spirit.bob_offset(peak))
	# Lower, and bobbing more.
	assert_float(strong.y - weak.y).is_equal_approx(_spirit.weak_drop, 0.001)
	assert_float(weak_bob).is_greater(strong_bob)
	# His light gutters harder than when he's well.
	_spirit.rekindle(0.0)
	assert_float(light.amount).is_greater(calm_amount)
	# Starting out, he's weak but not as weak as he'll be.
	assert_float(_awakening.starting_warmth).is_greater(_spirit.min_warmth)


func test_lighting_the_stove_works_only_at_the_stove_and_only_once() -> void:
	var runner: GdUnitSceneRunner = _build(false)
	# Before the ship's dark, it can't be asked.
	var reach: Interactable3D = _stove.get_node("Reach") as Interactable3D
	reach.interact(_player)
	assert_int(_awakening.stage).is_equal(ShipAwakening.Step.WAITING)
	assert_bool(_awakening.light_stove(_player)).is_false()
	_awakening.begin()
	await physics_ticks(runner, 5)
	assert_bool(reach.enabled).is_true()
	assert_str(reach.interact_prompt(_player)).is_not_empty()
	var warmth_before: float = _spirit.warmth
	var told: Array[int] = [0]
	_awakening.stove_lit.connect(func() -> void: told[0] += 1)

	reach.interact(_player)
	assert_int(_awakening.stage).is_equal(ShipAwakening.Step.LIGHTING)
	await _finish_cutscene(runner)
	assert_int(told[0]).is_equal(1)
	assert_bool(Game.dialogue.is_set(ShipAwakening.STOVE_FLAG)).is_true()
	assert_bool(_stove.burning).is_true()
	assert_bool(_lights.is_coming_on).is_true()
	# He gave some of his own flame: dimmer than he started.
	assert_float(_spirit.warmth).is_less(warmth_before)
	assert_float(_spirit.warmth).is_equal_approx(_spirit.min_warmth, 0.001)

	# Once: the stove no longer answers, and nothing starts again.
	assert_bool(reach.enabled).is_false()
	reach.interact(_player)
	assert_bool(_awakening.light_stove(_player)).is_false()
	assert_int(told[0]).is_equal(1)


func test_the_lights_come_on_from_the_galley_outwards() -> void:
	var runner: GdUnitSceneRunner = _build()
	await physics_ticks(runner, 5)
	_lights.spread_speed = 4.0
	_lights.window_delay = 1.0
	_awakening.light_stove(_player)
	await _finish_cutscene(runner)
	var windows: WindowDimmer = _awakening.get_node("Windows") as WindowDimmer
	await physics_ticks(runner, 30)
	var early: int = _lights.lit_count()
	assert_int(early).is_greater(0)
	assert_bool(_lights.is_dark).is_true()
	assert_bool(await wait_for_signal(_lights.all_lit, 12.0)).is_true()
	assert_int(_lights.lit_count()).is_greater(early)
	assert_bool(windows.dimmed).is_false()
	assert_bool(_lights.is_dark).is_false()


func test_the_cough_and_the_captains_words_come_after_the_stove_once() -> void:
	var runner: GdUnitSceneRunner = _build()
	await physics_ticks(runner, 5)
	_lights.spread_speed = 200.0
	_lights.fade_seconds = 0.1
	_lights.window_delay = 0.1
	_awakening.cough_after = 0.2
	var coughs: Array[int] = [0]
	_awakening.captain_called.connect(func() -> void: coughs[0] += 1)

	# Before the stove: nothing from him, and finding him changes nothing.
	await physics_ticks(runner, 60)
	assert_int(coughs[0]).is_equal(0)
	_captain().start_talking(_player)
	await _finish_cutscene(runner)
	assert_bool(Game.dialogue.is_set(ShipAwakening.STIRRED_FLAG)).is_false()
	assert_int(_awakening.stage).is_equal(ShipAwakening.Step.DARK)

	_awakening.light_stove(_player)
	await _finish_cutscene(runner)
	assert_bool(await wait_for_signal(_awakening.captain_called, 6.0)).is_true()
	assert_int(_awakening.stage).is_equal(ShipAwakening.Step.CAPTAIN_CALLS)
	assert_bool(Game.dialogue.is_set(ShipAwakening.QUEST_FLAG)).is_false()

	# He stirs, says a few weak words, hands over the pot and sleeps again.
	var done: Array[int] = [0]
	_awakening.finished.connect(func() -> void: done[0] += 1)
	_captain().start_talking(_player)
	await _finish_cutscene(runner)
	assert_bool(Game.dialogue.is_set(ShipAwakening.STIRRED_FLAG)).is_true()
	assert_bool(Game.dialogue.is_set(&"has_saucepan")).is_true()
	assert_bool(_awakening.is_captain_asleep()).is_true()
	assert_int(done[0]).is_equal(1)

	# Once: speaking to him again doesn't repeat it.
	_captain().start_talking(_player)
	await _finish_cutscene(runner)
	assert_int(done[0]).is_equal(1)


func test_the_first_quest_starts_afterwards() -> void:
	var runner: GdUnitSceneRunner = _build()
	await physics_ticks(runner, 5)
	_lights.spread_speed = 200.0
	_lights.fade_seconds = 0.1
	_awakening.cough_after = 0.2
	_awakening.light_stove(_player)
	await _finish_cutscene(runner)
	assert_bool(await wait_for_signal(_awakening.captain_called, 6.0)).is_true()
	_captain().start_talking(_player)
	await _finish_cutscene(runner)

	assert_int(_awakening.stage).is_equal(ShipAwakening.Step.DONE)
	assert_bool(Game.dialogue.is_set(ShipAwakening.QUEST_FLAG)).is_true()
	# He's still low, so the first quest's soup is what brings him back, and
	# its first meal brings the captain round too.
	assert_bool(_spirit.is_low()).is_true()
	Game.dialogue.clear(ShipAwakening.ASLEEP_FLAG)
	assert_float((_captain().get_node("Model") as Node3D).rotation.x).is_equal(0.0)


func test_a_flicker_and_a_lantern_can_be_brought_up_by_level() -> void:
	var flicker: Flicker = auto_free(Flicker.new())
	flicker.level = 0.0
	assert_float(flicker.energy_at(1.0)).is_equal(0.0)
	flicker.level = 0.5
	assert_float(flicker.energy_at(1.0)).is_less_equal(flicker.base_energy * 1.5 * 0.5 + 0.001)
	var lantern: Lantern = auto_free(
			(load("res://scenes/prototype/props/lantern.tscn") as PackedScene).instantiate())
	add_child(lantern)
	lantern.set_glow(0.4)
	assert_bool(lantern.lit).is_true()
	assert_float(lantern.flame_burning()).is_equal_approx(0.4, 0.001)
	lantern.set_glow(0.0)
	assert_bool(lantern.lit).is_false()
	lantern.set_lit(true)
	assert_float(lantern.flame_burning()).is_equal(1.0)
	remove_child(lantern)


func _build(begin: bool = true) -> GdUnitSceneRunner:
	_sea = (load(SEA) as PackedScene).instantiate()
	auto_free(_sea)
	_awakening = _sea.get_node("Awakening") as ShipAwakening
	_awakening.start_here = begin
	# Not beginning yet: the opening mustn't play either.
	(_sea.get_node("Opening") as Opening).skip = not begin
	_lights = _awakening.get_node("Lights") as ShipLights
	_ship = _sea.get_node("Ship") as Ship
	_player = _sea.get_node("Player") as Player3D
	_conversation = _sea.get_node("Story/Conversation") as Conversation
	_spirit = _player.get_node("LanternSpirit") as LanternSpirit
	_stove = _ship.get_node("Galley/Stove") as GalleyStove
	return scene_runner(_sea)


# Lets whatever conversation is playing run to its end.
func _finish_cutscene(runner: GdUnitSceneRunner) -> void:
	await physics_ticks(runner, 3)
	if _conversation.is_active():
		_conversation.skip()
		for tick: int in 900:
			if not _conversation.is_active():
				break
			# An ordinary talk isn't skipped: read it line by line.
			if not _conversation.is_cutscene() and tick % 4 == 0:
				_conversation.press()
			await physics_ticks(runner, 1)
	await physics_ticks(runner, 3)


func _captain() -> Crewmate:
	for node: Node in _sea.get_tree().get_nodes_in_group(Crewmate.GROUP):
		if (node as Crewmate).person.id == &"heron":
			return node as Crewmate
	return null


func _mark(mark_name: StringName) -> Node3D:
	for node: Node in _sea.get_tree().get_nodes_in_group(ActorCues.GROUP):
		if node.name == mark_name:
			return node as Node3D
	return null
