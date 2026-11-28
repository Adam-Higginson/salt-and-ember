class_name BowLantern
extends Node3D
## The lantern on the rowing boat's bow pole, as the opening plays (#228): how
## warm he is, and going where the story needs him.
##
## [b]Warmth.[/b] He starts at full flame. [method give_flame] hands some of it
## away over a few seconds (to the buoy's lamp): his flame shrinks and cools
## (his [LanternFace]'s strength, the same look the companion has) and the
## boat's light dims with it, so you can see it cost him. It sets up the ship's
## stove, which he lights with the rest (#231).
##
## [b]Going places.[/b] [method carry_to] floats him, his light and his
## voice to a spot (up on the buoy's platform, beside the lamp) and
## [method send_home] floats them back to the pole. While he's away they
## leave the boat (top level), then rejoin it on arriving home.

## Emitted when he has given away the flame he was giving.
signal flame_given

## The least warmth he fades to: dim, but never out. Matches [LanternSpirit].
@export var min_warmth: float = 0.25
## How much warmth he gives or regains a second, while giving.
@export var warmth_per_second: float = 0.3
## How quickly he glides to where he's going: higher is snappier.
@export var glide_response: float = 3.5
## How near counts as arrived, in metres.
@export var arrive_distance: float = 0.08
## How far he bobs up and down while away, in metres.
@export var bob_height: float = 0.05
## His body.
@export var face: LanternFace
## The boat's light that goes with him.
@export var light: Flicker
## His voice (where his speech bubble floats).
@export var voice: Speaker

## How warm and bright he is, 0 to 1.
var warmth: float = 1.0:
	set(value):
		warmth = clampf(value, min_warmth, 1.0)
		_apply()

## Whether he's away from the pole, or on his way there or back.
var is_away: bool:
	get:
		return _goal != null

var _goal: Node3D = null
## Whether he's on his way back to the pole.
var _returning: bool = false
## Whether he's giving flame away just now.
var _giving: bool = false
var _looking_at: Node3D = null
var _warmth_goal: float = 1.0
var _time: float = 0.0
var _base_energy: float = 1.0
var _base_range: float = 1.0
## Where each part sits on the pole: its position and, for his body, its turn.
var _rest: Dictionary[Node3D, Vector3] = {}
var _rest_yaw: float = 0.0


func _ready() -> void:
	if light != null:
		_base_energy = light.base_energy
		_base_range = light.omni_range
	for part: Node3D in _parts():
		_rest[part] = part.position
	if face != null:
		_rest_yaw = face.rotation.y
	_apply()


func _physics_process(delta: float) -> void:
	_time += delta
	if not is_equal_approx(warmth, _warmth_goal):
		var was: float = warmth
		warmth = move_toward(warmth, _warmth_goal, warmth_per_second * delta)
		if not is_equal_approx(was, _warmth_goal) and is_equal_approx(warmth, _warmth_goal) \
				and _warmth_goal < was:
			flame_given.emit()
	if _goal != null:
		_glide(delta)


## Starts handing away [param amount] of his warmth (a share of full): he
## dims over a few seconds, then [signal flame_given] is emitted.
func give_flame(amount: float) -> void:
	_warmth_goal = maxf(warmth - amount, min_warmth)
	_giving = not is_equal_approx(warmth, _warmth_goal)


## Whether he's still giving away the flame he was asked to.
func is_giving() -> bool:
	return _giving


## Floats him (with his light and voice) to [param spot], turned to look at
## [param watching] if there is one.
func carry_to(spot: Node3D, watching: Node3D = null) -> void:
	if _goal == null:
		for part: Node3D in _parts():
			var here: Vector3 = part.global_position
			part.top_level = true
			part.global_position = here
			part.reset_physics_interpolation()
	_goal = spot
	_looking_at = watching
	_returning = false


## Floats him back to the pole.
func send_home() -> void:
	if _goal == null:
		return
	_goal = get_parent() as Node3D
	_looking_at = null
	_returning = true


## Whether he's arrived at the spot he was sent to (or back on the pole).
func has_arrived() -> bool:
	if _goal == null:
		return true
	return face.global_position.distance_to(_goal_point()) <= arrive_distance


## How strong his flame is for how warm he is, 0 to 1: never quite out.
func flame_strength() -> float:
	return remap(warmth, min_warmth, 1.0, 0.35, 1.0)


func _parts() -> Array[Node3D]:
	var parts: Array[Node3D] = []
	for part: Node3D in [face, light, voice]:
		if part != null:
			parts.append(part)
	return parts


# Where his body should be: the spot (bobbing a little), or its place on the
# pole once he's headed home.
func _goal_point() -> Vector3:
	if _returning:
		return get_parent_node_3d().to_global(_rest[face])
	return _goal.global_position + Vector3.UP * sin(_time * TAU * 0.6) * bob_height


func _glide(delta: float) -> void:
	var step: float = 1.0 - exp(-glide_response * delta)
	var goal: Vector3 = _goal_point()
	var before: Vector3 = face.global_position
	var after: Vector3 = before.lerp(goal, step)
	var move: Vector3 = after - before
	for part: Node3D in _parts():
		part.global_position += move
	if _looking_at != null:
		var look: Vector3 = _looking_at.global_position - face.global_position
		if Vector2(look.x, look.z).length() > 0.01:
			face.rotation.y = lerp_angle(face.rotation.y, atan2(-look.x, -look.z),
					1.0 - exp(-6.0 * delta))
	if _returning and face.global_position.distance_to(goal) <= arrive_distance:
		_rejoin()


# Back on the pole: the parts ride the boat again.
func _rejoin() -> void:
	for part: Node3D in _parts():
		part.top_level = false
		part.position = _rest[part]
		part.reset_physics_interpolation()
	if face != null:
		face.rotation.y = _rest_yaw
	_goal = null
	_returning = false


# His flame and the boat's light follow his warmth.
func _apply() -> void:
	if face != null:
		face.strength = flame_strength()
	if light != null:
		light.base_energy = _base_energy * lerpf(0.35, 1.0, warmth)
		light.omni_range = _base_range * lerpf(0.55, 1.0, warmth)
