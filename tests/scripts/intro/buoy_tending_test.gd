extends GameTestSuite
## Tests for tending the buoy (#228): tying up alongside, the climb, the chain's
## hum (and stopping it), the lamp the lantern lights with a little of his
## flame, and climbing back down, all on the home waters scene.

const SCENE: String = "res://scenes/prototype/intro/home_waters.tscn"

## Where the boat is put: flat across the water (x, z).
const NEAR_THE_BUOY: Vector2 = Vector2(-10, -132)
const ALONGSIDE: Vector2 = Vector2(-10, -126)

## Ticks enough for the boat to be tied up and the climb to finish.
const CLIMB_TICKS: int = 280
## Ticks enough for the lantern to float up and give the lamp his flame.
const LAMP_TICKS: int = 300

var _runner: GdUnitSceneRunner = null
var _beat: HomeWaters = null
var _tending: BuoyTending = null
var _said: Array[String] = []


func before_test() -> void:
	_runner = scene_runner(SCENE)
	_beat = _runner.scene() as HomeWaters
	_tending = _beat.tending
	_beat.sibling.hush()
	# He says his lines quickly, so tests needn't wait for them.
	var voice: Speaker = _beat.lantern
	voice.base_seconds = 0.05
	voice.seconds_per_letter = 0.0
	voice.pause_seconds = 0.02
	voice.bubble.fade_seconds = 0.02
	_said.clear()
	voice.said.connect(func(line: String) -> void: _said.append(line))


func test_tying_up_only_works_alongside() -> void:
	# Out on the water, there's nothing to tie up to.
	assert_bool(_tending.tie_up()).is_false()
	assert_bool(_tending.interact()).is_false()
	_place(NEAR_THE_BUOY)
	await physics_ticks(_runner, 10)
	assert_bool(_tending.tie_up()).is_false()
	assert_int(_tending.phase).is_equal(BuoyTending.Phase.ROWING)
	assert_str(_tending.prompt_text()).is_empty()

	_place(ALONGSIDE)
	await physics_ticks(_runner, 10)
	assert_int(_tending.phase).is_equal(BuoyTending.Phase.ALONGSIDE)
	assert_str(_tending.prompt_text()).is_equal("Tie up")
	assert_bool(_tending.prompt.visible).is_true()

	assert_bool(_tending.tie_up()).is_true()
	assert_int(_tending.phase).is_equal(BuoyTending.Phase.TYING_UP)
	# Already tying up: not again.
	assert_bool(_tending.tie_up()).is_false()


func test_the_interact_button_ties_up() -> void:
	_place(ALONGSIDE)
	await physics_ticks(_runner, 10)

	await press(_runner, "interact")

	assert_int(_tending.phase).is_not_equal(BuoyTending.Phase.ALONGSIDE)
	assert_int(_tending.phase).is_not_equal(BuoyTending.Phase.ROWING)


func test_the_boat_is_drawn_in_and_you_climb_onto_the_platform() -> void:
	await _climb_up()

	assert_int(_tending.phase).is_equal(BuoyTending.Phase.ON_BUOY)
	var top: Vector3 = _tending.climb_top.global_position
	assert_float(_tending.rower.global_position.distance_to(top)).is_less(0.05)
	# The boat is tied up at the tie point's distance from the buoy, bow in.
	var from_buoy: float = Vector2(_beat.boat.global_position.x - _beat.buoy.global_position.x,
			_beat.boat.global_position.z - _beat.buoy.global_position.z).length()
	assert_float(from_buoy).is_equal_approx(4.4, 0.05)
	# The camera follows you, not the boat, and the lantern has floated up.
	assert_object(_tending.camera.target).is_not_equal(_beat.boat)
	assert_bool(_tending.lantern.is_away).is_true()
	assert_bool(_tending.reticle.visible).is_true()


func test_the_climb_is_a_step_to_the_deck_then_straight_up() -> void:
	var from: Vector3 = Vector3(0, 0.3, 4.4)
	var deck: Vector3 = Vector3(0, 0.95, 1.5)
	var top: Vector3 = Vector3(0, 5.25, 1.0)

	assert_vector(BuoyTending.climb_point(from, deck, top, 0.0)).is_equal(from)
	assert_vector(BuoyTending.climb_point(from, deck, top, 1.0)).is_equal(top)
	assert_vector(BuoyTending.climb_point(from, deck, top, 0.35)).is_equal_approx(deck,
			Vector3(0.01, 0.01, 0.01))
	# Past the deck it's all up.
	assert_float(BuoyTending.climb_point(from, deck, top, 0.7).y) \
			.is_greater(BuoyTending.climb_point(from, deck, top, 0.5).y)


func test_the_chain_and_the_lamp_work_in_either_order() -> void:
	# Lamp first, then the chain.
	await _climb_up()
	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.LAMP))).is_true()
	await physics_ticks(_runner, LAMP_TICKS)
	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.CHAIN))).is_true()
	assert_bool(_tending.lamp.lit).is_true()
	assert_bool(_tending.chain_hand.is_humming()).is_true()
	assert_bool(_tending.is_ready_to_leave()).is_true()


func test_the_chain_then_the_lamp() -> void:
	await _climb_up()
	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.CHAIN))).is_true()
	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.LAMP))).is_true()
	await physics_ticks(_runner, LAMP_TICKS)

	assert_bool(_tending.lamp.lit).is_true()
	assert_bool(_tending.chain_hand.is_humming()).is_true()
	assert_bool(_tending.is_ready_to_leave()).is_true()


func test_spots_cant_be_used_before_you_are_up() -> void:
	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.CHAIN))).is_false()
	assert_bool(_tending.chain_hand.is_humming()).is_false()


func test_the_spot_the_camera_points_at_is_the_one_you_use() -> void:
	await _climb_up()
	var spots: Array[BuoySpot] = _tending.spots
	var from: Vector3 = _tending.climb_top.global_position
	# From the ladder side, looking towards the buoy's middle, the lamp is
	# dead ahead; the chain is well to the side; and the ladder is behind.
	var towards_lamp: Vector3 = _spot(BuoySpot.Kind.LAMP).global_position - from
	var towards_chain: Vector3 = _spot(BuoySpot.Kind.CHAIN).global_position - from
	var towards_ladder: Vector3 = _spot(BuoySpot.Kind.LADDER).global_position - from

	assert_object(BuoyTending.best_spot(spots, from, towards_lamp, 22.0)) \
			.is_same(_spot(BuoySpot.Kind.LAMP))
	assert_object(BuoyTending.best_spot(spots, from, towards_chain, 22.0)) \
			.is_same(_spot(BuoySpot.Kind.CHAIN))
	assert_object(BuoyTending.best_spot(spots, from, towards_ladder, 22.0)) \
			.is_same(_spot(BuoySpot.Kind.LADDER))
	# Between the lamp and the chain, far enough from both, nothing.
	var between: Vector3 = towards_lamp.normalized().rotated(Vector3.UP, deg_to_rad(40.0))
	assert_object(BuoyTending.best_spot(spots, from, between, 15.0)).is_null()


func test_looking_at_the_chain_and_pressing_interact_touches_it() -> void:
	await _climb_up()
	var camera: FollowCamera = _tending.camera
	# Turn the camera until it points at the chain: whichever way that is.
	var chain: Vector3 = _spot(BuoySpot.Kind.CHAIN).global_position
	for degrees: float in [53.0, -53.0]:
		camera.look(degrees, 0.0)
		await physics_ticks(_runner, 4)
		if _tending.focused != null and _tending.focused.kind == BuoySpot.Kind.CHAIN:
			break
		camera.look(-degrees, 0.0)
		await physics_ticks(_runner, 4)
	assert_object(_tending.focused).is_not_null()
	assert_int(_tending.focused.kind).is_equal(BuoySpot.Kind.CHAIN)
	assert_str(_tending.prompt_text()).is_equal("Put a hand on the chain")
	assert_vector(chain).is_not_equal(Vector3.ZERO)

	await press(_runner, "interact")

	assert_bool(_tending.chain_hand.is_humming()).is_true()


func test_a_hand_on_the_chain_starts_a_hum_you_can_hear_feel_and_see() -> void:
	await _climb_up()
	var hand: ChainHand = _tending.chain_hand
	var starts: Array[bool] = []
	hand.hum_started.connect(func() -> void: starts.append(true))
	assert_bool(hand.is_humming()).is_false()
	assert_float(hand.sway()).is_equal(0.0)

	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.CHAIN))).is_true()
	await physics_ticks(_runner, 60)

	assert_array(starts).is_equal([true])
	assert_bool(hand.is_humming()).is_true()
	# Heard: the sound is playing.
	assert_bool(hand.hum().playing).is_true()
	# Seen: the links shiver, and water drips.
	assert_float(hand.sway()).is_greater(0.01)
	assert_bool(hand.is_dripping()).is_true()
	# Felt: it throbs, steadily.
	var throbs: int = hand.hum().pulse_count
	await physics_ticks(_runner, 200)
	assert_int(hand.hum().pulse_count).is_greater(throbs)
	# Touching it again does nothing.
	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.CHAIN))).is_false()
	assert_array(starts).is_equal([true])


func test_stopping_the_hum_stops_the_sound_the_throb_and_the_shiver() -> void:
	await _climb_up()
	var hand: ChainHand = _tending.chain_hand
	var stops: Array[bool] = []
	hand.hum_stopped.connect(func() -> void: stops.append(true))
	_tending.use_spot(_spot(BuoySpot.Kind.CHAIN))
	await physics_ticks(_runner, 60)
	assert_float(hand.sway()).is_greater(0.01)

	hand.stop_hum()
	var throbs: int = hand.hum().pulse_count
	await physics_ticks(_runner, 200)

	assert_array(stops).is_equal([true])
	assert_bool(hand.is_humming()).is_false()
	assert_bool(hand.hum().playing).is_false()
	assert_int(hand.hum().pulse_count).is_equal(throbs)
	assert_float(hand.sway()).is_equal(0.0)
	# Stopping again does nothing.
	hand.stop_hum()
	assert_array(stops).is_equal([true])
	# And it can start again.
	hand.start_hum()
	assert_bool(hand.is_humming()).is_true()


func test_the_hum_sound_loops_cleanly() -> void:
	var sound: AudioStreamWAV = ChainHum.recording(1.6, 55.0)

	assert_int(sound.loop_mode).is_equal(AudioStreamWAV.LOOP_FORWARD)
	assert_float(sound.get_length()).is_equal_approx(1.6, 0.01)
	# The loop's end meets its start: both are silent-ish and the same level.
	assert_float(ChainHum.sample(0.0, 1.6, 55.0)).is_equal_approx(0.0, 0.001)
	assert_float(ChainHum.sample(1.6, 1.6, 55.0)).is_equal_approx(0.0, 0.001)


func test_lighting_the_lamp_dims_the_lantern_and_lights_the_lamp_once() -> void:
	await _climb_up()
	var lantern: BowLantern = _tending.lantern
	var lit: Array[bool] = []
	_tending.lamp_lit.connect(func() -> void: lit.append(true))
	var strength_before: float = lantern.face.strength
	var light_before: float = lantern.light.base_energy
	assert_float(lantern.warmth).is_equal(1.0)
	assert_bool(_tending.lamp.lit).is_false()

	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.LAMP))).is_true()
	await physics_ticks(_runner, LAMP_TICKS)

	assert_bool(_tending.lamp.lit).is_true()
	assert_array(lit).is_equal([true])
	assert_float(lantern.warmth).is_equal_approx(0.5, 0.001)
	# You can see it cost him: his flame is smaller and the light is dimmer.
	assert_float(lantern.face.strength).is_less(strength_before - 0.2)
	assert_float(lantern.light.base_energy).is_less(light_before * 0.8)
	assert_bool(_tending.spark.visible).is_false()
	# The lamp glows.
	await physics_ticks(_runner, 120)
	assert_float(_tending.lamp.glow).is_equal_approx(1.0, 0.001)
	assert_bool(_tending.lamp.light.visible).is_true()
	assert_float(_tending.lamp.light.light_energy).is_greater(1.0)

	# Not again: no more flame given, no second lighting.
	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.LAMP))).is_false()
	await physics_ticks(_runner, 60)
	assert_float(lantern.warmth).is_equal_approx(0.5, 0.001)
	assert_array(lit).is_equal([true])


func test_the_lantern_floats_up_to_the_lamp_to_give_it_his_flame() -> void:
	await _climb_up()
	_tending.use_spot(_spot(BuoySpot.Kind.LAMP))
	await physics_ticks(_runner, 20)

	# Busy: you can't touch the chain or climb down while he's giving.
	assert_int(_tending.lamp_phase).is_not_equal(BuoyTending.LampPhase.IDLE)
	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.CHAIN))).is_false()
	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.LADDER))).is_false()

	await physics_ticks(_runner, LAMP_TICKS)
	var spot: Vector3 = _tending.lantern_spot.global_position
	assert_float(_tending.lantern.face.global_position.distance_to(spot)).is_less(0.3)


func test_you_cant_climb_down_until_the_chain_and_the_lamp_are_done() -> void:
	await _climb_up()
	var ladder: BuoySpot = _spot(BuoySpot.Kind.LADDER)

	assert_bool(_tending.use_spot(ladder)).is_false()
	_tending.use_spot(_spot(BuoySpot.Kind.CHAIN))
	assert_bool(_tending.use_spot(ladder)).is_false()
	assert_int(_tending.phase).is_equal(BuoyTending.Phase.ON_BUOY)

	_tending.use_spot(_spot(BuoySpot.Kind.LAMP))
	await physics_ticks(_runner, LAMP_TICKS)
	assert_bool(_tending.use_spot(ladder)).is_true()
	assert_int(_tending.phase).is_equal(BuoyTending.Phase.CLIMBING_DOWN)


func test_climbing_down_ends_the_beat_and_emits_the_signal_once() -> void:
	await _climb_up()
	var tended: Array[bool] = []
	var beat_over: Array[bool] = []
	_tending.tended.connect(func() -> void: tended.append(true))
	_beat.buoy_tended.connect(func() -> void: beat_over.append(true))
	_tending.use_spot(_spot(BuoySpot.Kind.CHAIN))
	_tending.use_spot(_spot(BuoySpot.Kind.LAMP))
	await physics_ticks(_runner, LAMP_TICKS)
	assert_bool(_beat.ending.visible).is_false()

	_tending.use_spot(_spot(BuoySpot.Kind.LADDER))
	await physics_ticks(_runner, CLIMB_TICKS + 120)

	assert_int(_tending.phase).is_equal(BuoyTending.Phase.TENDED)
	assert_array(tended).is_equal([true])
	assert_array(beat_over).is_equal([true])
	assert_bool(_beat.ending.visible).is_true()
	# You're back in the boat, the camera is on it, and the lantern is on his pole.
	assert_bool(_tending.rower.top_level).is_false()
	assert_object(_tending.camera.target).is_same(_beat.boat)
	assert_bool(_tending.lantern.is_away).is_false()
	assert_bool(_tending.reticle.visible).is_false()
	# He has something to say about supper.
	assert_array(_said).contains(["Just a little. Doesn't hurt.", "Supper, then."])
	# The chain still hums: only the break (#229) stops it.
	assert_bool(_tending.chain_hand.is_humming()).is_true()

	# Nothing happens twice.
	assert_bool(_tending.use_spot(_spot(BuoySpot.Kind.LADDER))).is_false()
	assert_bool(_tending.interact()).is_false()
	await physics_ticks(_runner, 60)
	assert_array(tended).is_equal([true])
	assert_array(beat_over).is_equal([true])


func test_you_cant_leave_the_platform_except_by_climbing_down() -> void:
	await _climb_up()
	var boat: Vector3 = _beat.boat.global_position

	# Walking, rowing and interacting at nothing do nothing.
	await walk(_runner, "move_left", 60)
	await walk(_runner, "move_up", 60)
	await walk(_runner, "move_down", 60)
	_tending.focused = null
	assert_bool(_tending.interact()).is_false()
	await physics_ticks(_runner, 30)

	assert_int(_tending.phase).is_equal(BuoyTending.Phase.ON_BUOY)
	assert_float(_tending.rower.global_position
			.distance_to(_tending.climb_top.global_position)).is_less(0.05)
	assert_float(Vector2(_beat.boat.global_position.x, _beat.boat.global_position.z) \
			.distance_to(Vector2(boat.x, boat.z))).is_less(0.1)
	assert_bool(_beat.boat.controls_enabled).is_false()


func test_every_moment_has_lines() -> void:
	var moments: Array[StringName] = [BuoyTending.TIED_UP, BuoyTending.ON_PLATFORM,
			BuoyTending.HAND_ON_CHAIN, BuoyTending.LAMP_GIFT, BuoyTending.LAMP_LIT,
			BuoyTending.NOT_YET, BuoyTending.SUPPER]
	for moment: StringName in moments:
		assert_array(HomeWaters.lines_for(moment)) \
				.override_failure_message("home_waters.dlg: nothing [on %s]" % moment) \
				.is_not_empty()
	assert_str(HomeWaters.lines_for(BuoyTending.LAMP_GIFT)[0].text) \
			.is_equal("Just a little. Doesn't hurt.")


# Rows to the buoy, ties up and waits for the climb to finish.
func _climb_up() -> void:
	_place(ALONGSIDE)
	await physics_ticks(_runner, 10)
	_tending.tie_up()
	await physics_ticks(_runner, CLIMB_TICKS)


# The spot of [param kind] on the buoy.
func _spot(kind: BuoySpot.Kind) -> BuoySpot:
	for spot: BuoySpot in _tending.spots:
		if spot.kind == kind:
			return spot
	return null


# Puts the boat at [param spot] on the water, at rest.
func _place(spot: Vector2) -> void:
	_beat.boat.global_position = Vector3(spot.x, 0.0, spot.y)
	_beat.boat.velocity = Vector2.ZERO
