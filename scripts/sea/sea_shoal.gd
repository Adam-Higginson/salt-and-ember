class_name SeaShoal
extends MultiMeshInstance3D
## A few small shoals of fish just under the open sea, seen through the dusk
## water (home waters): they wander round the things in [member anchors] (the
## rowboat, the jetty), and dart off when the oars dip near them. Looks only.
##
## Every fish of every shoal is one [MultiMesh] instance, the same little fish
## as [FishShoal]'s, wagging its tail in shaders/fish.gdshader. Each shoal is
## a point that steers towards a wander target near its anchor; its fish keep
## their own places round that point (a boids-lite: no fish looks at another,
## so it costs next to nothing), strung out behind it along its heading.
## A shoal left far behind (the boat rowed away) slips back in near its
## anchor, out where the water is a mirror and nothing under it shows.

## Emitted when a shoal darts away from the oars.
signal scattered

## How long a startled shoal darts, in seconds, and how fast, in metres a second.
const DART_SECONDS: float = 1.4
const DART_SPEED: float = 3.2

## What each shoal swims round, in turn: shoal 0 round the first, and so on,
## wrapping. Anything with a [code]stroked[/code] signal (the [Rowboat])
## scatters the shoals near it each time its oars bite.
@export var anchors: Array[Node3D] = []
## How many shoals, and fish in each.
@export_range(1, 8) var shoals: int = 3
@export_range(1, 16) var fish_per_shoal: int = 8
## How far a shoal wanders from its anchor, in metres.
@export var roam: float = 6.0
## How fast a shoal cruises, in metres a second.
@export var speed: float = 0.8
## How far below the still sea they swim, in metres: the middle of each
## shoal, and how far a fish strays up or down from it.
@export var depth: float = 1.0
@export var depth_spread: float = 0.15
## How long a fish is, in metres.
@export var fish_length: float = 0.42
## How close the oars must dip to a shoal to scatter it, in metres.
@export var scatter_within: float = 5.0
## A shoal further than this from its anchor slips back in, [member regroup_at]
## metres from it.
@export var regroup_beyond: float = 30.0
@export var regroup_at: float = 18.0
## Which fish you get.
@export var shoal_seed: int = 7

var _random: RandomNumberGenerator = RandomNumberGenerator.new()
# Per shoal: where it is, how it's moving, where it's heading, and how long
# it has left to dart.
var _centres: PackedVector3Array = PackedVector3Array()
var _velocities: PackedVector3Array = PackedVector3Array()
var _targets: PackedVector3Array = PackedVector3Array()
var _darting: PackedFloat32Array = PackedFloat32Array()
# Per fish: its place in the shoal (sideways, up, back) and its own beat.
var _places: PackedVector3Array = PackedVector3Array()
var _beats: PackedFloat32Array = PackedFloat32Array()
var _time: float = 0.0
var _sea: Node3D = null


func _ready() -> void:
	# Placed afresh every drawn frame, so there's nothing to smooth.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_random.seed = shoal_seed
	for anchor: Node3D in anchors:
		# The same anchor can hold several shoals; it's heard once.
		if anchor == null or not anchor.has_signal(&"stroked"):
			continue
		if not anchor.is_connected(&"stroked", _on_stroked.bind(anchor)):
			anchor.connect(&"stroked", _on_stroked.bind(anchor))
	for shoal: int in shoals:
		var home: Vector3 = _anchor_spot(shoal)
		var start: Vector3 = home + _random_offset(roam)
		_centres.append(start)
		_velocities.append(Vector3.ZERO)
		_targets.append(home + _random_offset(roam))
		_darting.append(0.0)
	for index: int in shoals * fish_per_shoal:
		_places.append(Vector3(
			_random.randf_range(-0.6, 0.6),
			_random.randf_range(-1.0, 1.0) * depth_spread,
			_random.randf_range(-0.2, 1.4)))
		_beats.append(_random.randf_range(0.0, TAU))
	var many: MultiMesh = MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = FishShoal.fish_mesh()
	many.instance_count = shoals * fish_per_shoal
	multimesh = many
	# The shoals roam far from this node's own spot.
	custom_aabb = AABB(Vector3(-400.0, -10.0, -400.0), Vector3(800.0, 20.0, 800.0))
	_place_fish()


func _process(delta: float) -> void:
	_time += delta
	for shoal: int in shoals:
		_swim(shoal, delta)
	_place_fish()


## Where the middle of shoal [param shoal] is now.
func centre(shoal: int) -> Vector3:
	return _centres[shoal]


## Whether shoal [param shoal] is darting away right now.
func is_darting(shoal: int) -> bool:
	return _darting[shoal] > 0.0


## Sends every shoal within [member scatter_within] of [param from] darting
## away from it.
func scatter_from(from: Vector3) -> void:
	var any: bool = false
	for shoal: int in shoals:
		var away: Vector3 = _centres[shoal] - from
		away.y = 0.0
		if away.length() > scatter_within:
			continue
		if away.length() < 0.01:
			away = Vector3.RIGHT
		away = away.normalized()
		_darting[shoal] = DART_SECONDS
		_velocities[shoal] = away * DART_SPEED
		_targets[shoal] = _centres[shoal] + away * (scatter_within + 3.0)
		any = true
	if any:
		scattered.emit()


func _swim(shoal: int, delta: float) -> void:
	var home: Vector3 = _anchor_spot(shoal)
	var here: Vector3 = _centres[shoal]
	var flat: Vector3 = Vector3(here.x - home.x, 0.0, here.z - home.z)
	if flat.length() > regroup_beyond:
		# Left behind: slip back in round the anchor, far enough out that the
		# water there is a mirror and nothing below shows.
		var side: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, _random.randf_range(0.0, TAU))
		here = home + side * regroup_at
		_velocities[shoal] = Vector3.ZERO
		_targets[shoal] = home + _random_offset(roam)
	if _darting[shoal] > 0.0:
		_darting[shoal] = maxf(0.0, _darting[shoal] - delta)
	var target: Vector3 = _targets[shoal]
	var to_target: Vector3 = Vector3(target.x - here.x, 0.0, target.z - here.z)
	if to_target.length() < 1.0:
		_targets[shoal] = home + _random_offset(roam)
	var cruise: float = DART_SPEED if _darting[shoal] > 0.0 else speed
	var wanted: Vector3 = to_target.normalized() * cruise if to_target.length() > 0.01 else Vector3.ZERO
	# Steer smoothly: fish turn in arcs, not corners.
	var velocity: Vector3 = _velocities[shoal].lerp(wanted, 1.0 - exp(-1.2 * delta))
	_velocities[shoal] = velocity
	here += velocity * delta
	here.y = _still_level() - depth
	_centres[shoal] = here


func _place_fish() -> void:
	if multimesh == null:
		return
	for shoal: int in shoals:
		var heading: Vector3 = _velocities[shoal]
		heading.y = 0.0
		if heading.length() < 0.05:
			heading = Vector3.FORWARD.rotated(Vector3.UP, float(shoal) * 2.1)
		heading = heading.normalized()
		var side: Vector3 = Vector3(-heading.z, 0.0, heading.x)
		# A darting shoal strings out.
		var spread: float = 1.8 if _darting[shoal] > 0.0 else 1.0
		for fish: int in fish_per_shoal:
			var index: int = shoal * fish_per_shoal + fish
			var place: Vector3 = _places[index]
			var beat: float = _beats[index]
			# Each fish weaves a little about its place, on its own beat.
			var weave: float = sin(_time * 0.9 + beat) * 0.25
			var spot: Vector3 = _centres[shoal] + side * (place.x + weave) \
					- heading * place.z * spread + Vector3.UP * place.y
			var facing: Vector3 = (heading + side * cos(_time * 0.9 + beat) * 0.2).normalized()
			var turned: Basis = Basis.looking_at(facing, Vector3.UP).scaled(Vector3.ONE * fish_length)
			multimesh.set_instance_transform(index, Transform3D(turned, spot))


func _on_stroked(anchor: Node3D) -> void:
	scatter_from(anchor.global_position)


# Where shoal [param shoal]'s anchor is, or this node if it has none.
func _anchor_spot(shoal: int) -> Vector3:
	if anchors.is_empty():
		return global_position
	var anchor: Node3D = anchors[shoal % anchors.size()]
	if not is_instance_valid(anchor):
		return global_position
	return anchor.global_position


func _random_offset(within: float) -> Vector3:
	var angle: float = _random.randf_range(0.0, TAU)
	var out_by: float = sqrt(_random.randf()) * within
	return Vector3(cos(angle) * out_by, 0.0, sin(angle) * out_by)


# The sea's still level: its node's height (lowered under a ship), or 0.
func _still_level() -> float:
	if not is_instance_valid(_sea):
		_sea = get_tree().get_first_node_in_group(&"sea") as Node3D
	return _sea.global_position.y if _sea != null else 0.0
