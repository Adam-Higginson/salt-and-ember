extends GameTestSuite
## Tests for the chain's hum (#228): its throbs come once every pulse, counted
## from the moment it starts.


func test_throbs_are_spaced_one_pulse_apart() -> void:
	var world: Node3D = Node3D.new()
	auto_free(world)
	var hum: ChainHum = ChainHum.new()
	hum.rumble = false
	hum.pulse_seconds = 0.5
	world.add_child(hum)
	var runner: GdUnitSceneRunner = scene_runner(world)
	var ticks: Array[int] = [0]
	var throbs: Array[int] = []
	hum.pulsed.connect(func() -> void: throbs.append(ticks[0]))
	hum.start_humming()
	# 0.5 s is 30 physics ticks: throbs at 0, 30, 60, 90 and 120.
	for i: int in 132:
		await physics_ticks(runner, 1)
		ticks[0] += 1
	assert_int(throbs.size()).is_equal(5)
	for i: int in range(1, throbs.size()):
		assert_int(throbs[i] - throbs[i - 1]).is_between(29, 31)
