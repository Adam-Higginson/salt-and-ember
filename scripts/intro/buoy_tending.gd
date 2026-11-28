class_name BuoyTending
extends Node
## The opening's second beat (#228): tending the buoy. You're the chain-tender,
## and this is the nightly job: tie up, climb onto the buoy, put a hand on the
## chain and feel its hum, give the dead lamp a little of the lantern's flame,
## and climb back down for supper.
##
## It's guided, not free walking. [HomeWaters] hands over when you come
## alongside ([method arrive]); from there it goes [enum Phase] by phase:
## [br]- [b]Alongside:[/b] interact ties up. The boat is drawn to the buoy.
## [br]- [b]Climbing up:[/b] a short shot: you step onto the float and up the
## ladder, the camera following.
## [br]- [b]On the buoy:[/b] you stand to one side of the lamp, on the platform,
## and look around (mouse or right stick; the camera stays where you point it). Turn towards something and the prompt
## names it: the chain, the lamp, the ladder (each a [BuoySpot]). Interact
## uses it. The chain and the lamp work in any order, and you can't leave
## except down the ladder, which only works once both are done.
## [br]- [b]Climbing down, tended:[/b] you climb back into the boat, the
## lantern says it's time for supper, and [signal tended] is emitted once.
##
## The chain: touching it starts its hum ([ChainHand]), and it goes on until
## something stops it (the break, #229). The lamp: the lantern floats up to
## it, passes it a little of his flame and dims ([BowLantern]), and the lamp
## lights ([BuoyLamp]).
##
## What the lantern says is in data/dialogue/home_waters.dlg, by moment.

## Emitted whenever the phase changes.
signal phase_changed(phase: Phase)
## Emitted when you put a hand on the chain, the first time.
signal chain_touched
## Emitted when the lamp is lit, once.
signal lamp_lit
## Emitted once, when you've climbed back down into the boat with the job done.
## The beat is over; the next one (the chain breaking, #229) starts here.
signal tended

## Where in the tending you are.
enum Phase {
	## Still rowing out.
	ROWING,
	## Alongside the buoy: interact ties up.
	ALONGSIDE,
	## The boat is being drawn in and tied.
	TYING_UP,
	## Climbing up onto the platform.
	CLIMBING_UP,
	## On the platform, looking round and using things.
	ON_BUOY,
	## Climbing back down into the boat.
	CLIMBING_DOWN,
	## Done: back in the boat.
	TENDED,
}

## What the lantern gives the lamp does, step by step.
enum LampPhase {
	## Nothing yet.
	IDLE,
	## He's floating up to the lamp.
	RISING,
	## He's passing it his flame.
	GIVING,
	## It's lit.
	LIT,
}

## The moments in data/dialogue/home_waters.dlg this says.
const TIED_UP: StringName = &"tied_up"
const ON_PLATFORM: StringName = &"on_platform"
const HAND_ON_CHAIN: StringName = &"hand_on_chain"
const LAMP_GIFT: StringName = &"lamp_gift"
const LAMP_LIT: StringName = &"lamp_lit"
const NOT_YET: StringName = &"not_yet"
const SUPPER: StringName = &"supper"

## How far through the climb you reach the top of the ladder; the rest is the
## walk across the platform to where you stand.
const PLATFORM_SHARE_START: float = 0.8

## The boat you row.
@export var boat: Rowboat
## Your figure in the boat, which climbs the buoy.
@export var rower: Node3D
## The camera that follows the boat, and then you.
@export var camera: FollowCamera
## The lantern on the bow pole.
@export var lantern: BowLantern
## The buoy.
@export var buoy: Node3D
## Where the boat ties up: its distance from the buoy's middle, which leaves a
## small gap between the bow and the float. The boat ties up on whichever side
## it came in on.
@export var tie_point: Marker3D
## The top of the ladder, where the climb comes up onto the platform.
@export var climb_top: Marker3D
## Where you stand on the platform: to one side, clear of the lamp.
@export var stand_spot: Marker3D
## Where the lantern hovers by you on the platform.
@export var lantern_perch: Marker3D
## Where the lantern hovers to light the lamp.
@export var lantern_spot: Marker3D
## The things you can use up there.
@export var spots: Array[BuoySpot] = []
## The chain you put a hand on.
@export var chain_hand: ChainHand
## The lamp.
@export var lamp: BuoyLamp
## A small light that carries the flame from the lantern to the lamp.
@export var spark: Node3D
## The line at the bottom of the screen that names what you're looking at.
@export var prompt: Label
## A dot in the middle of the screen, shown while you look round the buoy.
@export var reticle: Control

@export_group("Timing")
## Seconds the boat takes to be drawn in and tied.
@export var tie_seconds: float = 1.0
## Seconds the climb takes, up or down.
@export var climb_seconds: float = 2.4
## The longest the lantern is waited for, floating up to the lamp, in seconds.
@export var rise_seconds: float = 2.5
## How much of his warmth the lantern gives the lamp, 0 to 1.
@export var flame_gift: float = 0.5

@export_group("Looking")
## How close, in degrees across the water, the camera must point at a spot.
@export var focus_degrees: float = 40.0
## How far, in degrees, the camera is turned off the line from you to the lamp,
## so you aren't standing between it and the lamp. At rest it looks past you
## at the chain side.
@export var view_offset_degrees: float = 35.0
## How far behind you the camera sits on the platform, in metres.
@export var platform_zoom: float = 4.0
## How high the float's deck is above the water, where you step off the boat.
@export var deck_height: float = 0.95

## Where you are in the tending.
var phase: Phase = Phase.ROWING:
	set(value):
		if value == phase:
			return
		phase = value
		phase_changed.emit(phase)

## The spot the camera is pointing at, if any (only while you're on the buoy).
var focused: BuoySpot = null

## Where the lamp is in being lit.
var lamp_phase: LampPhase = LampPhase.IDLE

var _tie_local: Vector3 = Vector3.ZERO
var _boat_from: Vector3 = Vector3.ZERO
var _boat_heading_from: float = 0.0
var _tie_heading: float = 0.0
var _progress: float = 0.0
var _rower_rest: Vector3 = Vector3.ZERO
var _rower_rest_yaw: float = 0.0
var _zoom_before: float = 6.5
var _lamp_seconds: float = 0.0
var _gift_start: float = 1.0
var _stand: Node3D = Node3D.new()


func _ready() -> void:
	# Run after the boat has moved and the walls have held it off each tick.
	process_physics_priority = 11
	_stand.name = "Stand"
	add_child(_stand)
	if lantern != null:
		lantern.flame_given.connect(_on_flame_given)
	if spark != null:
		spark.visible = false
	_show_prompt("")
	if reticle != null:
		reticle.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and interact():
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	match phase:
		Phase.TYING_UP:
			_tie_step(delta)
		Phase.CLIMBING_UP:
			_hold_boat()
			_climb_step(delta, true)
		Phase.ON_BUOY:
			_hold_boat()
			_stand_on_platform()
			refresh_focus()
			_lamp_step(delta)
		Phase.CLIMBING_DOWN:
			_hold_boat()
			_climb_step(delta, false)
		Phase.TENDED:
			_hold_boat()
	_update_prompt()


## Called by [HomeWaters] when you come alongside the buoy.
func arrive() -> void:
	if phase == Phase.ROWING:
		phase = Phase.ALONGSIDE


## Does what interact does now: ties up when you're alongside, or uses the
## spot you're looking at when you're on the buoy. Returns whether it did
## anything.
func interact() -> bool:
	match phase:
		Phase.ALONGSIDE:
			return tie_up()
		Phase.ON_BUOY:
			if focused != null:
				return use_spot(focused)
	return false


## Ties the boat up and starts the climb. Only works alongside the buoy.
func tie_up() -> bool:
	if phase != Phase.ALONGSIDE:
		return false
	# Tie up on the side the boat came in on, at the tie point's distance.
	var out: Vector3 = boat.global_position - buoy.global_position
	var flat: Vector2 = Vector2(out.x, out.z)
	var direction: Vector2 = flat.normalized() if flat.length() > 0.01 else Vector2.DOWN
	var radius: float = Vector2(tie_point.position.x, tie_point.position.z).length()
	var spot: Vector2 = Vector2(buoy.global_position.x, buoy.global_position.z) \
			+ direction * radius
	_tie_local = buoy.to_local(Vector3(spot.x, boat.global_position.y, spot.y))
	_boat_from = boat.global_position
	_boat_heading_from = boat.heading
	# Bow towards the buoy.
	_tie_heading = atan2(direction.x, direction.y)
	_progress = 0.0
	_zoom_before = camera.distance if camera != null else 6.5
	phase = Phase.TYING_UP
	_say(TIED_UP, func() -> bool: return phase <= Phase.CLIMBING_UP)
	return true


## Uses [param spot], if you're on the buoy and it can be used now. Returns
## whether it did anything.
func use_spot(spot: BuoySpot) -> bool:
	if phase != Phase.ON_BUOY or spot == null or _is_busy():
		return false
	match spot.kind:
		BuoySpot.Kind.CHAIN:
			return _touch_chain(spot)
		BuoySpot.Kind.LAMP:
			return _light_lamp(spot)
		BuoySpot.Kind.LADDER:
			return _climb_down()
	return false


## Whether the job is done and you may climb down: a hand on the chain and
## the lamp lit.
func is_ready_to_leave() -> bool:
	return chain_hand != null and chain_hand.is_humming() and lamp != null and lamp.lit


## Works out which spot the camera is pointing at.
func refresh_focus() -> void:
	focused = null
	if phase != Phase.ON_BUOY or camera == null or stand_spot == null:
		return
	focused = best_spot(spots, stand_spot.global_position, -camera.global_basis.z,
			focus_degrees)


## The spot of [param spots] that [param forward] points most nearly at from
## [param from], measured flat across the platform, or null if none is within
## [param max_degrees].
static func best_spot(candidates: Array[BuoySpot], from: Vector3, forward: Vector3,
		max_degrees: float) -> BuoySpot:
	var ahead: Vector2 = Vector2(forward.x, forward.z)
	if ahead.length() < 0.001:
		return null
	ahead = ahead.normalized()
	var best: BuoySpot = null
	var best_angle: float = deg_to_rad(max_degrees)
	for spot: BuoySpot in candidates:
		var towards: Vector2 = Vector2(spot.global_position.x - from.x,
				spot.global_position.z - from.z)
		if towards.length() < 0.05:
			continue
		var angle: float = ahead.angle_to(towards.normalized())
		if absf(angle) <= best_angle:
			best_angle = absf(angle)
			best = spot
	return best


## Where you are [param progress] (0 to 1) of the way up from [param from]
## (in the boat), by way of [param deck] (the float's deck) to [param top] (the
## platform): a step to the deck, then straight up.
static func climb_point(from: Vector3, deck: Vector3, top: Vector3,
		progress: float) -> Vector3:
	var p: float = clampf(progress, 0.0, 1.0)
	var split: float = 0.35
	if p < split:
		var t: float = p / split
		return from.lerp(deck, smoothstep(0.0, 1.0, t)) + Vector3.UP * sin(PI * t) * 0.25
	return deck.lerp(top, smoothstep(0.0, 1.0, (p - split) / (1.0 - split)))


## Where you are [param progress] (0 to 1) of the way up the ladder and across
## to your standing place: [method climb_point] to [param top] (the top of the
## ladder) for most of it, then a few steps across the platform to [param stand].
static func climb_path(from: Vector3, deck: Vector3, top: Vector3, stand: Vector3,
		progress: float) -> Vector3:
	var p: float = clampf(progress, 0.0, 1.0)
	if p < PLATFORM_SHARE_START:
		return climb_point(from, deck, top, p / PLATFORM_SHARE_START)
	var t: float = (p - PLATFORM_SHARE_START) / (1.0 - PLATFORM_SHARE_START)
	return top.lerp(stand, smoothstep(0.0, 1.0, t))


# --- The boat -------------------------------------------------------------

# Draws the boat in to its tie point.
func _tie_step(delta: float) -> void:
	_progress = minf(_progress + delta / maxf(tie_seconds, 0.01), 1.0)
	var t: float = smoothstep(0.0, 1.0, _progress)
	var goal: Vector3 = buoy.to_global(_tie_local)
	var here: Vector3 = _boat_from.lerp(goal, t)
	boat.global_position = Vector3(here.x, boat.global_position.y, here.z)
	boat.heading = lerp_angle(_boat_heading_from, _tie_heading, t)
	boat.velocity = Vector2.ZERO
	if _progress >= 1.0:
		_begin_climb()


# Keeps the tied boat where it is, riding the swell.
func _hold_boat() -> void:
	var goal: Vector3 = buoy.to_global(_tie_local)
	boat.global_position = Vector3(goal.x, boat.global_position.y, goal.z)
	boat.heading = _tie_heading
	boat.velocity = Vector2.ZERO


# --- The climb ------------------------------------------------------------

func _begin_climb() -> void:
	_progress = 0.0
	_rower_rest = rower.position
	_rower_rest_yaw = rower.rotation.y
	var here: Vector3 = rower.global_position
	rower.top_level = true
	rower.global_position = here
	rower.reset_physics_interpolation()
	_stand.global_position = here
	_stand.rotation.y = boat.heading
	camera.target = _stand
	camera.zoom_to(platform_zoom)
	lantern.carry_to(lantern_perch, rower)
	phase = Phase.CLIMBING_UP


# One phase of the climb up ([param up] true) or down.
func _climb_step(delta: float, up: bool) -> void:
	_progress = minf(_progress + delta / maxf(climb_seconds, 0.01), 1.0)
	var p: float = _progress if up else 1.0 - _progress
	var boat_spot: Vector3 = boat.to_global(_rower_rest)
	var deck: Vector3 = buoy.to_global(Vector3(climb_top.position.x, deck_height,
			climb_top.position.z + 0.5))
	var at: Vector3 = climb_path(boat_spot, deck, climb_top.global_position,
			stand_spot.global_position, p)
	rower.global_position = at
	rower.rotation.y = _yaw_towards_buoy(at)
	_stand.global_position = at
	_stand.rotation.y = rower.rotation.y + deg_to_rad(view_offset_degrees)
	if _progress >= 1.0:
		if up:
			_arrive_on_buoy()
		else:
			_finish()


func _arrive_on_buoy() -> void:
	phase = Phase.ON_BUOY
	# You aim by looking, so the camera stays where you point it.
	camera.hold_look = true
	if reticle != null:
		reticle.visible = true
	# "Chain first, then the lamp" is only worth saying while neither is done.
	_say(ON_PLATFORM, func() -> bool:
		return phase == Phase.ON_BUOY and lamp_phase == LampPhase.IDLE \
				and (chain_hand == null or not chain_hand.is_humming()))


func _stand_on_platform() -> void:
	rower.global_position = stand_spot.global_position
	rower.rotation.y = _yaw_towards_buoy(rower.global_position)
	_stand.global_position = rower.global_position
	_stand.rotation.y = rower.rotation.y + deg_to_rad(view_offset_degrees)


# Back in the boat: the job's done.
func _finish() -> void:
	rower.top_level = false
	rower.position = _rower_rest
	rower.rotation.y = _rower_rest_yaw
	rower.reset_physics_interpolation()
	camera.target = boat
	camera.hold_look = false
	camera.zoom_to(_zoom_before)
	phase = Phase.TENDED
	_say(SUPPER)
	tended.emit()


# The turn (about Y) that faces the buoy's middle from [param spot].
func _yaw_towards_buoy(spot: Vector3) -> float:
	var look: Vector3 = buoy.global_position - spot
	return atan2(-look.x, -look.z)


# --- The things to use ----------------------------------------------------

func _touch_chain(spot: BuoySpot) -> bool:
	if spot.used:
		return false
	spot.used = true
	chain_hand.start_hum()
	chain_touched.emit()
	_say(HAND_ON_CHAIN)
	return true


func _light_lamp(spot: BuoySpot) -> bool:
	if spot.used or lamp_phase != LampPhase.IDLE:
		return false
	lamp_phase = LampPhase.RISING
	_lamp_seconds = 0.0
	lantern.carry_to(lantern_spot, lamp)
	return true


func _climb_down() -> bool:
	if not is_ready_to_leave():
		# Not yet: say so, but don't talk over himself.
		if lantern.voice != null and not lantern.voice.is_busy():
			_say(NOT_YET, func() -> bool: return phase == Phase.ON_BUOY)
		return false
	if reticle != null:
		reticle.visible = false
	focused = null
	camera.hold_look = false
	lantern.send_home()
	_progress = 0.0
	phase = Phase.CLIMBING_DOWN
	return true


# Whether something is already going on that interact shouldn't interrupt.
func _is_busy() -> bool:
	return lamp_phase == LampPhase.RISING or lamp_phase == LampPhase.GIVING


# The lamp, phase by phase: he floats up, then passes it his flame, and it lights.
func _lamp_step(delta: float) -> void:
	match lamp_phase:
		LampPhase.RISING:
			_lamp_seconds += delta
			if lantern.has_arrived() or _lamp_seconds >= rise_seconds:
				_begin_gift()
		LampPhase.GIVING:
			_carry_spark()


func _begin_gift() -> void:
	lamp_phase = LampPhase.GIVING
	_gift_start = lantern.warmth
	lantern.give_flame(flame_gift)
	lantern.face.expression = LanternFace.Look.PLEASED
	if spark != null:
		spark.visible = true
	_say(LAMP_GIFT)


# Moves the spark from the lantern to the lamp as his flame goes down.
func _carry_spark() -> void:
	if spark == null:
		return
	var given: float = _gift_start - lantern.warmth
	var total: float = maxf(_gift_start - maxf(_gift_start - flame_gift, lantern.min_warmth),
			0.001)
	var t: float = clampf(given / total, 0.0, 1.0)
	spark.global_position = lantern.face.global_position.lerp(lamp.global_position, t)


# He's given all he was giving: the lamp lights.
func _on_flame_given() -> void:
	if lamp_phase != LampPhase.GIVING:
		return
	lamp_phase = LampPhase.LIT
	if spark != null:
		spark.visible = false
	lantern.face.expression = LanternFace.Look.CALM
	for spot: BuoySpot in spots:
		if spot.kind == BuoySpot.Kind.LAMP:
			spot.used = true
	if lamp.light_up():
		lamp_lit.emit()
	_say(LAMP_LIT)


# --- Words and prompts ----------------------------------------------------

# Says [param moment]'s lines after whatever he's saying. [param still_wanted]
# is asked when each line's turn comes: false drops it, so a line about a
# state (chain first, then the lamp) doesn't play once that state has passed.
func _say(moment: StringName, still_wanted: Callable = Callable()) -> void:
	if lantern == null or lantern.voice == null:
		return
	for line: DialogueStep in HomeWaters.lines_for(moment):
		lantern.voice.say(line.text, Speaker.style_for(line.tag), still_wanted)


# The words that name what interact would do now ("" for nothing).
func prompt_text() -> String:
	match phase:
		Phase.ALONGSIDE:
			return "Tie up"
		Phase.ON_BUOY:
			if focused == null or focused.used or _is_busy():
				return ""
			return focused.prompt_text
	return ""


func _update_prompt() -> void:
	_show_prompt(prompt_text())


func _show_prompt(words: String) -> void:
	if prompt == null:
		return
	prompt.text = "[E]  %s" % words if not words.is_empty() else ""
	prompt.visible = not words.is_empty()
