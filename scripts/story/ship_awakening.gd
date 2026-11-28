class_name ShipAwakening
extends Node
## The ship comes alive (#249): the beat after you climb aboard. You stand on
## a dark deck at night. The lantern floats weak at your shoulder, his light
## reaching only a few metres, and murmurs where the warmth is. The stove's
## last embers glow up through the hatch. At the stove you ask him to light
## it: he gives some of his own flame and goes dimmer (the buoy's lamp, #228,
## set that up), and warm light spreads through the ship, galley first. Then a
## cough from the captain's cabin draws you to him: slumped by his door, cold,
## barely awake. One weak exchange, and he's asleep again. After that the
## first quest (warming the lantern with spicy tomato soup) is yours.
##
## It's driven from here and from three dialogue files: [code]awakening.dlg[/code]
## (the stove), [code]heron.dlg[/code] (the captain's few words) and the flags
## below. #231 (the ship finds you) will call [method begin]; until then set
## [member start_here] to open the game on it.
##
## The captain's cabin is still a facade (see the GDD), so he's slumped on the
## deck in the lee of its door instead, which needs no interior.

## Emitted when the lantern has lit the stove.
signal stove_lit
## Emitted when the captain coughs, calling you.
signal captain_called
## Emitted when you've spoken with the captain and the first quest begins.
signal finished

## Where you are in it.
enum Step {
	## Not begun.
	WAITING,
	## The ship's dark; find the stove.
	DARK,
	## The lantern is lighting the stove.
	LIGHTING,
	## The stove's lit and the lights are coming on.
	LIT,
	## The captain's coughing: go and find him.
	CAPTAIN_CALLS,
	## You've spoken with him: the first quest.
	DONE,
}

## Set (and kept) while the captain is asleep, cold, in the cabin's lee. The
## first meal clears it (#244).
const ASLEEP_FLAG: StringName = &"captain_asleep"
## Set when the lantern has lit the stove.
const STOVE_FLAG: StringName = &"stove_lit"
## Set by the captain's talk once he's said his few words.
const STIRRED_FLAG: StringName = &"captain_stirred"
## Set when it's over and the first quest begins.
const QUEST_FLAG: StringName = &"first_quest_begun"
## The cutscene file: a section [code]stove[/code].
const CUTSCENE: StringName = &"awakening"

## Open the game straight on the dark deck, with no title or rescue. (The
## [Opening] stands aside for it.)
@export var start_here: bool = false
## The player who arrives.
@export var player: Player3D
## The ship they arrive on.
@export var ship: Ship
## The ship's lights, put out by [method begin].
@export var lights: ShipLights
## The galley stove, left to its embers.
@export var stove: GalleyStove
## Where you stand on the dark deck, in the ship's space.
@export var arrival_spot: Vector3 = Vector3(1.8, 5.35, 6.0)
## Who the captain is: a crewmate's [member Person.id], and the file of his
## talk.
@export var captain: StringName = &"heron"
## The mark he's slumped at, in the group [constant ActorCues.GROUP].
@export var asleep_mark: StringName = &"CaptainAsleep"
## How far forward he's slumped, in degrees.
@export var slump_degrees: float = 28.0
## How warm the lantern is when you begin: weak, but with something to give.
@export_range(0.0, 1.0) var starting_warmth: float = 0.5
## How much of his warmth he gives the stove.
@export_range(0.0, 1.0) var flame_given: float = 0.3
## How long you wander before his first murmur, and between them, in seconds.
@export var hint_after: float = 8.0
@export var hint_every: float = 15.0
## What he murmurs while you're up on deck, in order, then again.
@export var deck_hints: PackedStringArray = PackedStringArray([
	"...so dark. I can barely see my own glass.",
	"...warm... somewhere below...",
	"...do you feel that? A little warmth, under the deck.",
	"...the hatch. Try the hatch."])
## What he murmurs once you're below.
@export var below_hints: PackedStringArray = PackedStringArray([
	"...warmer. This way.",
	"...embers. I can feel embers.",
	"...the galley. It must be the galley."])
## What he says when you're by the stove.
@export var stove_hint: String = "...there. The stove. It's nearly out."
## How near the stove you must be for that, in metres.
@export var stove_hint_range: float = 3.5
## How long after the lights are all on the captain coughs, and between
## coughs, in seconds.
@export var cough_after: float = 3.0
@export var cough_every: float = 20.0
## What the lantern says the first time he coughs.
@export var cough_hint: String = "...did you hear that? From the captain's cabin."

## Where you are in it.
var stage: Step:
	get:
		return _stage

var _stage: Step = Step.WAITING
var _ignited: bool = false
var _clock: float = 0.0
var _hints_said: int = 0
var _said_stove_hint: bool = false
var _coughed: bool = false


func _ready() -> void:
	if stove != null:
		stove.flame_asked.connect(light_stove)
	_listen.call_deferred()
	if start_here:
		# After the crew have taken their posts.
		begin.call_deferred()


func _physics_process(delta: float) -> void:
	match _stage:
		Step.DARK:
			_clock += delta
			_wander_hints()
		Step.LIT:
			if lights != null and lights.is_coming_on:
				return
			_clock += delta
			if _clock >= cough_after:
				_cough()
		Step.CAPTAIN_CALLS:
			_clock += delta
			if _clock >= cough_every:
				_cough()


## Begins: you're on the dark deck, the ship dark, the lantern weak at your
## shoulder, the captain asleep in the lee of his cabin. #231 calls this once
## you've climbed aboard. Does nothing if it has begun.
func begin() -> void:
	if _stage != Step.WAITING:
		return
	_stage = Step.DARK
	_ignited = false
	_clock = 0.0
	_hints_said = 0
	_said_stove_hint = false
	_coughed = false
	Game.dialogue.set_flag(LanternSpirit.LOW_FLAG)
	Game.dialogue.set_flag(ASLEEP_FLAG)
	Game.dialogue.clear(STOVE_FLAG)
	Game.dialogue.clear(STIRRED_FLAG)
	Game.dialogue.clear(QUEST_FLAG)
	if player != null and ship != null:
		player.global_position = ship.to_global(arrival_spot)
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		player.camera_rig.yaw = ship.global_rotation.y
		player.controls_enabled = true
	var spirit: LanternSpirit = _spirit()
	if spirit != null:
		spirit.leave_home()
		spirit.low_warmth = starting_warmth
		spirit.warmth = starting_warmth
		spirit.snap_to_player()
	if lights != null:
		lights.go_dark()
	_place_captain()


## Asks the lantern to light the stove, which he does by giving some of his
## own flame. Works once, at the stove (its Interact calls this), and only
## while the ship's dark. Returns whether it began.
func light_stove(who: Player3D) -> bool:
	if _stage != Step.DARK:
		return false
	_stage = Step.LIGHTING
	_play_stove(who)
	return true


## Whether the captain is still slumped asleep.
func is_captain_asleep() -> bool:
	return Game.dialogue.is_set(ASLEEP_FLAG)


# The cutscene, if there is one to play it with, and then the lighting (which
# the script may already have started with its stove_lit flag).
func _play_stove(who: Player3D) -> void:
	var conversation: Conversation = Conversation.find(self)
	if conversation != null and conversation.play(CUTSCENE, who, &"stove"):
		await conversation.ended
	_ignite()


# The flame passes from him to the stove: he goes dimmer and the ship's
# warm light begins to spread. Only once.
func _ignite() -> void:
	if _ignited:
		return
	_ignited = true
	_stage = Step.LIT
	_clock = 0.0
	var spirit: LanternSpirit = _spirit()
	if spirit != null:
		spirit.give_flame(flame_given)
	Game.dialogue.set_flag(STOVE_FLAG)
	if lights != null:
		lights.bring_up()
	stove_lit.emit()


func _listen() -> void:
	Game.dialogue.flag_changed.connect(func(flag: StringName, value: int) -> void:
		if flag == STOVE_FLAG and value != 0 and _stage == Step.LIGHTING:
			_ignite()
		elif flag == ASLEEP_FLAG and value == 0:
			_wake_captain_body())
	var conversation: Conversation = Conversation.find(self)
	if conversation != null:
		conversation.ended.connect(func(tree_id: StringName) -> void:
			if tree_id == captain and _stage == Step.CAPTAIN_CALLS \
					and Game.dialogue.is_set(STIRRED_FLAG):
				_finish())


func _finish() -> void:
	_stage = Step.DONE
	Game.dialogue.set_flag(QUEST_FLAG)
	finished.emit()


# The captain's cough, from his cabin: a nudge towards him.
func _cough() -> void:
	_clock = 0.0
	if _stage == Step.LIT:
		_stage = Step.CAPTAIN_CALLS
	var crewmate: Crewmate = _find_captain()
	if crewmate != null and crewmate.head != null:
		crewmate.head.say("*cough*... *cough*")
	var spirit: LanternSpirit = _spirit()
	if spirit != null and not _coughed:
		spirit.murmur(cough_hint)
	_coughed = true
	captain_called.emit()


# His murmurs while you look for the stove: where the warmth is, never a
# marker.
func _wander_hints() -> void:
	var spirit: LanternSpirit = _spirit()
	if spirit == null or player == null or ship == null or spirit.saying() != "":
		return
	if _clock < hint_after:
		return
	var local: Vector3 = ship.to_local(player.global_position)
	var below: bool = local.y < 4.5
	if below and not _said_stove_hint and stove != null \
			and player.global_position.distance_to(stove.global_position) < stove_hint_range:
		_said_stove_hint = true
		_clock = 0.0
		spirit.murmur(stove_hint)
		return
	var lines: PackedStringArray = below_hints if below else deck_hints
	if lines.is_empty():
		return
	spirit.murmur(lines[_hints_said % lines.size()])
	_hints_said += 1
	_clock = hint_after - hint_every


func _place_captain() -> void:
	var crewmate: Crewmate = _find_captain()
	var mark: Node3D = _find_mark(asleep_mark)
	if crewmate == null or mark == null:
		return
	var walker: CrewWalker = crewmate.get_node_or_null("Walker") as CrewWalker
	if walker != null:
		walker.stop()
	crewmate.global_transform = mark.global_transform
	crewmate.reset_physics_interpolation()
	crewmate.rest()
	crewmate.set_present(true)
	var model: Node3D = crewmate.get_node_or_null("Model") as Node3D
	if model != null:
		model.rotation.x = -deg_to_rad(slump_degrees)


# He's round (the first meal, #244): he straightens.
func _wake_captain_body() -> void:
	var crewmate: Crewmate = _find_captain()
	if crewmate == null:
		return
	var model: Node3D = crewmate.get_node_or_null("Model") as Node3D
	if model != null:
		model.rotation.x = 0.0


func _spirit() -> LanternSpirit:
	if player == null:
		return null
	return player.get_node_or_null("LanternSpirit") as LanternSpirit


func _find_captain() -> Crewmate:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(Crewmate.GROUP):
		var crewmate: Crewmate = node as Crewmate
		if crewmate != null and crewmate.person != null and crewmate.person.id == captain:
			return crewmate
	return null


func _find_mark(mark_name: StringName) -> Node3D:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(ActorCues.GROUP):
		if node.name == mark_name:
			return node as Node3D
	return null
