class_name ShipLights
extends Node
## The ship's lamps, all at once (#249): puts every light aboard out, leaving
## the cold blue of the night and the stove's last embers glowing up as a
## guide, and brings them up again from the galley outwards.
##
## It finds the lights itself, so no lamp needs to know about it: every
## [Lantern], every [Flicker] (candles, stoves), every candle flame, and any
## other light in the ship (the glow through the skylight, the binnacle's
## lamp). The window glow is the [WindowDimmer]'s. The moonlight through the
## portholes is the night's own and is left alone, and so are the sets the
## cutscenes use ([member skip]).
##
## Each lamp comes on [code]distance / spread_speed[/code] seconds after the
## stove, fading up over [member fade_seconds], so the warm light is seen to
## spread through the ship, pushing the blue back. See [method go_dark] and
## [method bring_up].

## Emitted when the last lamp has finished coming on.
signal all_lit

## A light in this group stays at [member ember_level] when the ship's dark,
## instead of going out: the embers' glow that leads you to the galley.
const GUIDE_GROUP: StringName = &"ember_guide"

## The ship whose lights these are.
@export var ship: Ship
## Parts of the ship to leave alone: the sets cutscenes use.
@export var skip: Array[Node] = []
## Where the light spreads from: the stove.
@export var origin: Node3D
## The windows' glow, if there is one.
@export var windows: WindowDimmer
## The stove, which is lit by [method bring_up] (it fades up first).
@export var stove: GalleyStove
## How bright the guide lights are on the embers, as a share of their usual.
@export_range(0.0, 1.0) var ember_level: float = 0.3
## How fast the light spreads, in metres a second.
@export var spread_speed: float = 3.0
## How long each lamp takes to come up, in seconds.
@export var fade_seconds: float = 1.4
## How long after the stove the windows come on, in seconds.
@export var window_delay: float = 4.0
## The cold blue fill that's left when the ship's dark, and its brightness.
@export var cold_colour: Color = Color(0.35, 0.45, 0.8, 1.0)
@export var cold_energy: float = 0.6
@export var cold_range: float = 12.0

## Whether the ship's lights are out (they're not, until [method go_dark]).
var is_dark: bool:
	get:
		return _dark

## Whether the lights are coming on right now.
var is_coming_on: bool:
	get:
		return _running

var _dark: bool = false
var _running: bool = false
var _elapsed: float = 0.0
var _windows_on: bool = false
var _all: float = 0.0
var _lamps: Array[Entry] = []
var _cold: OmniLight3D = null


## One lamp: what it is, how bright it is when fully on, when it comes on
## and how far up it is now.
class Entry:
	var node: Node
	var full: float = 1.0
	var delay: float = 0.0
	var level: float = 1.0
	var guide: bool = false


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	# Windows follow the galley, after a beat.
	if not _windows_on and _elapsed >= window_delay:
		_windows_on = true
		if is_instance_valid(windows):
			windows.dimmed = false
	for lamp: Entry in _lamps:
		_apply(lamp, clampf((_elapsed - lamp.delay) / maxf(fade_seconds, 0.001), 0.0, 1.0))
	if is_instance_valid(_cold):
		var fade: float = clampf(_elapsed / maxf(_all, 0.001), 0.0, 1.0)
		_cold.light_energy = cold_energy * (1.0 - fade)
		_cold.visible = fade < 1.0
	if _elapsed >= _all:
		_running = false
		_dark = false
		if is_instance_valid(_cold):
			_cold.visible = false
		all_lit.emit()


## How many lamps there are aboard (found by the last [method go_dark]).
func lamp_count() -> int:
	return _lamps.size()


## How many of the lamps are lit at all just now.
func lit_count() -> int:
	var lit: int = 0
	for lamp: Entry in _lamps:
		var resting: float = ember_level if lamp.guide else 0.0
		if lamp.level > resting + 0.001:
			lit += 1
	return lit


## Puts every light out at once, leaving the guide lights on their embers
## and a cold blue glow, and the windows dark.
func go_dark() -> void:
	_running = false
	_dark = true
	_collect()
	for lamp: Entry in _lamps:
		_apply(lamp, ember_level if lamp.guide else 0.0)
	if is_instance_valid(windows):
		windows.dimmed = true
	if stove != null:
		stove.await_flame()
	_make_cold()
	_cold.light_energy = cold_energy
	_cold.visible = true


## Brings the lights up from the stove outwards. The stove's own fire
## comes up first. Emits [signal all_lit] when the last one's on.
func bring_up() -> void:
	if not _dark or _running:
		return
	_elapsed = 0.0
	_all = window_delay
	for lamp: Entry in _lamps:
		_all = maxf(_all, lamp.delay + fade_seconds)
	if stove != null:
		stove.light()
	_windows_on = false
	_running = true


## Puts every light fully on at once (a ship that was never dark, or a
## test that doesn't want to wait).
func light_all() -> void:
	_running = false
	_dark = false
	for lamp: Entry in _lamps:
		_apply(lamp, 1.0)
	if is_instance_valid(windows):
		windows.dimmed = false
	if stove != null:
		stove.light()
	if is_instance_valid(_cold):
		_cold.visible = false


func _collect() -> void:
	_lamps.clear()
	if ship == null:
		return
	_gather(ship)


func _gather(node: Node) -> void:
	for skipped: Node in skip:
		if skipped == node:
			return
	if node is Lantern or node is Flicker or node is CandleFlame or node is Light3D:
		_add(node)
		# A lantern looks after its own light.
		if node is Lantern:
			return
	for child: Node in node.get_children():
		_gather(child)


func _add(node: Node) -> void:
	var parent: Node = node.get_parent()
	if node is DirectionalLight3D or parent is Porthole:
		return
	var lamp: Entry = Entry.new()
	lamp.node = node
	if node is Light3D and not node is Flicker:
		lamp.full = (node as Light3D).light_energy
	var place: Node3D = node as Node3D
	var from: Vector3 = origin.global_position if origin != null else Vector3.ZERO
	var far: float = place.global_position.distance_to(from) if place != null else 0.0
	lamp.delay = far / maxf(spread_speed, 0.001)
	lamp.guide = node.is_in_group(GUIDE_GROUP)
	# The stove's own fire is lit by the stove.
	if stove != null and stove.is_ancestor_of(node):
		lamp.guide = false
		return
	_lamps.append(lamp)


func _apply(lamp: Entry, level: float) -> void:
	lamp.level = level
	var node: Node = lamp.node
	if not is_instance_valid(node):
		return
	if node is Lantern:
		(node as Lantern).set_glow(level)
	elif node is Flicker:
		var flicker: Flicker = node as Flicker
		flicker.level = level
		flicker.visible = level > 0.0
	elif node is CandleFlame:
		(node as CandleFlame).visible = level > 0.0
	elif node is Light3D:
		var light: Light3D = node as Light3D
		light.light_energy = lamp.full * level
		light.visible = level > 0.0


func _make_cold() -> void:
	if is_instance_valid(_cold) or ship == null:
		return
	_cold = OmniLight3D.new()
	_cold.name = "ColdFill"
	_cold.light_color = cold_colour
	_cold.omni_range = cold_range
	_cold.shadow_enabled = false
	ship.add_child(_cold)
	if origin != null:
		_cold.global_position = origin.global_position + Vector3(-1.5, 1.2, 1.5)
