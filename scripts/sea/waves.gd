class_name Waves
extends RefCounted
## The sea's wave maths, the same as the water shader's, so scripts can ask
## how high the sea is anywhere (under the ship, for instance).
##
## Each [WaveLayer] moves every point of the flat sea in a circle: up and down
## by its amplitude, and sideways along its direction. Because points move
## sideways, the point that ends up above a spot started somewhere else, so
## [method height_at] searches back for it.

## How many search steps [method height_at] takes. Three or four is plenty for
## gentle seas.
const HEIGHT_STEPS: int = 4
## How many search steps it takes when the waves are peaked (a sharper
## search, Newton's method, as they push the surface further sideways).
const PEAKED_HEIGHT_STEPS: int = 5


## Where the still-water point [param still] (x and z) is moved to at
## [param time] seconds, as an offset: x and z sideways, y up.
static func offset(settings: WaveSettings, still: Vector2, time: float) -> Vector3:
	var moved: Vector3 = Vector3.ZERO
	var t: float = time * settings.time_scale
	for layer: WaveLayer in settings.used_layers():
		var dir: Vector2 = layer.direction()
		var k: float = layer.wave_number()
		var phase: float = k * (dir.dot(still) - layer.speed() * t)
		var side: float = layer.sideways() * layer.amplitude * cos(phase)
		moved += Vector3(dir.x * side, layer.amplitude * sin(phase), dir.y * side)
	return moved


## How high the sea's surface is above the still-water level at the world
## spot [param spot] (x and z), at [param time] seconds.
static func height_at(settings: WaveSettings, spot: Vector2, time: float) -> float:
	return offset(settings, still_point(settings, spot, time), time).y


## The still-water point that the waves carry to the world spot
## [param spot] at [param time]: searched back, since points move sideways.
static func still_point(settings: WaveSettings, spot: Vector2, time: float) -> Vector2:
	var still: Vector2 = spot
	if settings.is_peaked():
		for i: int in PEAKED_HEIGHT_STEPS:
			still = _newton_step(settings, spot, still, time)
		return still
	for i: int in HEIGHT_STEPS:
		var moved: Vector3 = offset(settings, still, time)
		still = spot - Vector2(moved.x, moved.z)
	return still


# One step of Newton's method towards the still point that lands on
# [param spot]: the plain search (above) crawls where peaked crests push
# points far sideways, so this also follows how the push changes from one
# point to the next (its slope, a 2x2 matrix) and lands in a few steps.
static func _newton_step(settings: WaveSettings, spot: Vector2, still: Vector2,
		time: float) -> Vector2:
	var t: float = time * settings.time_scale
	var miss: Vector2 = still - spot
	# The slope of where a point lands, starting from "unmoved" (identity).
	var xx: float = 1.0
	var xz: float = 0.0
	var zz: float = 1.0
	for layer: WaveLayer in settings.used_layers():
		var dir: Vector2 = layer.direction()
		var phase: float = layer.wave_number() * (dir.dot(still) - layer.speed() * t)
		var push: float = layer.sideways() * layer.amplitude
		miss += dir * push * cos(phase)
		var bend: float = -layer.sharpness() * sin(phase)
		xx += bend * dir.x * dir.x
		xz += bend * dir.x * dir.y
		zz += bend * dir.y * dir.y
	var det: float = xx * zz - xz * xz
	if absf(det) < 0.001:
		return still - miss
	return still - Vector2(zz * miss.x - xz * miss.y, xx * miss.y - xz * miss.x) / det
