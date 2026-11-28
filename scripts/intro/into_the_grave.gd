class_name IntoTheGrave
extends Node3D
## The opening's fourth beat (#230): swept into the Grave of the Lanterns, the
## capsize and the rescue. It starts "already swept in": the sea has the boat
## ([member SeaCurrent.takeover] at 1, so the oars do nothing) and you drift
## on, free only to turn the camera. Something later joins it to the chain
## breaking (#229) by calling [method begin]; until then it begins by itself
## ([member begin_on_start]), so you can open
## scenes/prototype/intro/into_the_grave.tscn and press F6.
##
## The beats, in order ([enum Beat]):
## [br]1. [b]Lights[/b]: the Grave's lights come up under the sea, and the
## lantern on the bow pole is thrilled ("There you are...") until he sees
## what they are: dead lanterns, his own kind. Then the ringing. This is
## the first section of data/dialogue/into_the_grave.dlg.
## [br]2. [b]Pull[/b]: the Grave pulls him off the pole into the water, and
## he sinks, glowing, beside the boat.
## [br]3. [b]Reach[/b]: "Reach for him" is offered. It's your choice: there's
## no timer and no way to fail. [method reach] answers Interact, once.
## [br]4. [b]Capsize[/b]: the boat tips over and you go in after him
## ([member Rowboat.capsize_roll]), then the screen goes black.
## [br]5. [b]Rescue[/b]: the rescue as built (the underwater set), with his
## lines written for a friend (the dlg's second section).
##
## It ends on the rescue's white ([signal finished]), with "To be continued"
## until the ship finds you (#231). All the talking is a cutscene run by the
## scene's [Conversation] with nobody in particular to talk to, so there's no
## player here, only a boat.

## Emitted when the Grave has taken him off the pole and he's sinking.
signal pulled_off
## Emitted when "Reach for him" is offered.
signal reach_offered
## Emitted when the boat has gone over, just before the screen goes black.
signal capsized
## Emitted once, when the rescue is over.
signal finished

## Where the beat is up to.
enum Beat {
	## Not begun.
	WAITING,
	## The lights come up and he says what they are.
	LIGHTS,
	## He's being pulled off the pole.
	PULL,
	## "Reach for him" is on offer.
	REACH,
	## The boat is going over.
	CAPSIZE,
	## You're in the water and he comes to you.
	RESCUE,
	## It's over.
	DONE,
}

## The file his lines are in.
const LINES: StringName = &"into_the_grave"
## The section that plays while you drift over the Grave.
const REVEAL: StringName = DialogueTree.START
## The section that plays in the water.
const RESCUE_SECTION: StringName = &"the_rescue"
## What the prompt says.
const REACH_WORDS: String = "Reach for him"

## The boat you're in.
@export var boat: Rowboat
## The current that has it.
@export var current: SeaCurrent
## The sea, whose Grave lights come up.
@export var sea: Sea
## The lantern on the bow pole, whose [member LanternFace.look_name] is
## "bow_lantern" in the script.
@export var lantern: LanternFace
## The light he gives off on the bow pole. It goes with him.
@export var lantern_light: Light3D
## The conversation that plays his lines.
@export var conversation: Conversation
## The black the screen goes to for the rescue.
@export var fade: ScreenFade
## Where "Reach for him" is shown.
@export var prompt: CutscenePrompt
## Where his words are shown. Given to [member conversation].
@export var dialogue_box: DialogueBox
## The blips under his words. Optional.
@export var dialogue_sounds: DialogueSounds
## Shown when it's over, until #231 carries on from there.
@export var ending: Control
## Whether to begin as soon as the scene is ready. Off when something else
## (the chain breaking, #229) begins it.
@export var begin_on_start: bool = true

@export_group("Timing")
## How long the Grave's lights take to come up under the sea, in seconds.
@export var lights_seconds: float = 8.0
## How long he takes to be pulled off the pole and sink, in seconds.
@export var pull_seconds: float = 3.0
## How long the boat takes to go over, in seconds.
@export var capsize_seconds: float = 1.6
## How long you're left in the water before the screen goes black, in seconds.
@export var settle_seconds: float = 0.7
## How long the black takes to come, in seconds.
@export var fade_seconds: float = 0.8

@export_group("The pull")
## Where he's flung to off the pole, in the pole's own space (metres): out
## ahead, to one side, and down to the water.
@export var flung_to: Vector3 = Vector3(1.0, -0.4, -2.2)
## How deep he sinks below the pole, in metres.
@export var sink_depth: float = 5.0
## How far the boat tips, in degrees (a little past on its side).
@export var capsize_degrees: float = 110.0

## Where it's up to.
var beat: Beat = Beat.WAITING

var _lights_tween: Tween = null
var _tween: Tween = null
# What the sunk lantern hangs from once the boat starts to go over: it follows
# the boat along but never rolls with it.
var _sunk_hook: Node3D = null


func _ready() -> void:
	RowingGreybox.clear_hull_cutout(sea)
	if ending != null:
		ending.visible = false
	if conversation != null:
		if dialogue_box != null:
			conversation.box = dialogue_box
			if dialogue_sounds != null:
				dialogue_sounds.setup(conversation, dialogue_box)
		conversation.ended.connect(_on_talk_ended)
	if begin_on_start:
		begin.call_deferred()


func _process(_delta: float) -> void:
	RowingGreybox.centre_sea_under(sea, boat)
	if _sunk_hook != null:
		_sunk_hook.global_position = boat.global_position


func _unhandled_input(event: InputEvent) -> void:
	# The mouse turns the camera only while it's captured: Esc frees it, and a
	# click captures it again (as in the rowing greybox).
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if beat == Beat.REACH and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		reach()


## Starts the beat: the sea has the boat and the lights come up. Does nothing
## if it's already begun. Returns whether it began.
func begin() -> bool:
	if beat != Beat.WAITING:
		return false
	beat = Beat.LIGHTS
	boat.controls_enabled = false
	current.takeover = 1.0
	_lights_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_lights_tween.tween_property(sea, "grave", 1.0, lights_seconds)
	if conversation == null or not conversation.play(LINES, null, REVEAL):
		push_warning("IntoTheGrave: couldn't play '%s' from '%s'" % [LINES, REVEAL])
		_pull()
	return true


## Reaches for him: the boat goes over and you go in after him. Only works
## once, and only while "Reach for him" is on offer. Returns whether it did.
func reach() -> bool:
	if beat != Beat.REACH:
		return false
	beat = Beat.CAPSIZE
	if prompt != null:
		prompt.hide_prompt()
	_capsize()
	return true


## Whether "Reach for him" is on offer.
func can_reach() -> bool:
	return beat == Beat.REACH


func _on_talk_ended(tree_id: StringName) -> void:
	if tree_id != LINES:
		return
	if beat == Beat.LIGHTS:
		_pull()
	elif beat == Beat.RESCUE:
		_finish()


# The Grave takes him off the pole: flung out over the water, then sinking
# with his light. Then "Reach for him".
func _pull() -> void:
	beat = Beat.PULL
	# However the lights were coming up, they're all the way up now.
	if _lights_tween != null and _lights_tween.is_valid():
		_lights_tween.kill()
	sea.grave = 1.0
	lantern.direct("pleading")
	if lantern_light != null:
		lantern_light.reparent(lantern, true)
	pulled_off.emit()
	var start: Vector3 = lantern.position
	var fling_seconds: float = minf(0.7, pull_seconds * 0.3)
	var fling: Callable = func(share: float) -> void:
		lantern.position = start.lerp(start + flung_to, share) \
				+ Vector3.UP * sin(share * PI) * 0.5
		lantern.rotation.z = share * 1.2
	var pulled: Tween = _new_tween()
	pulled.tween_method(fling, 0.0, 1.0, fling_seconds).set_ease(Tween.EASE_IN)
	var sinking: PropertyTweener = pulled.tween_property(lantern, "position:y",
			start.y + flung_to.y - sink_depth, pull_seconds - fling_seconds)
	sinking.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if lantern_light != null:
		# A Flicker rewrites light_energy every frame from its base, so it's the
		# base that has to dim.
		var dimmed: StringName = &"base_energy" if lantern_light is Flicker \
				else &"light_energy"
		pulled.parallel().tween_property(lantern_light, NodePath(dimmed), 0.3,
				pull_seconds - fling_seconds)
	await pulled.finished
	if beat != Beat.PULL:
		return
	beat = Beat.REACH
	if prompt != null:
		prompt.show_prompt(REACH_WORDS, true)
	reach_offered.emit()


# The boat tips and you're in the water; then black.
func _capsize() -> void:
	_hang_lantern_clear_of_boat()
	var tipping: Tween = _new_tween()
	tipping.tween_property(boat, "capsize_roll", deg_to_rad(capsize_degrees), capsize_seconds) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tipping.tween_interval(settle_seconds)
	await tipping.finished
	capsized.emit()
	if fade != null:
		await fade.fade_out(fade_seconds)
	_start_rescue()


# The lantern is under the bow pole, so rolling the boat would swing him up out
# of the water. Hang him from a hook that follows the boat but doesn't turn.
func _hang_lantern_clear_of_boat() -> void:
	if _sunk_hook != null:
		return
	_sunk_hook = Node3D.new()
	_sunk_hook.name = "SunkHook"
	add_child(_sunk_hook)
	_sunk_hook.global_position = boat.global_position
	lantern.reparent(_sunk_hook, true)


func _start_rescue() -> void:
	beat = Beat.RESCUE
	if conversation == null or not conversation.play(LINES, null, RESCUE_SECTION):
		push_warning("IntoTheGrave: couldn't play '%s' from '%s'" % [LINES, RESCUE_SECTION])
		_finish()


func _finish() -> void:
	if beat == Beat.DONE:
		return
	beat = Beat.DONE
	# The talk's end has just begun fading the screen in (FadeCues): end on the
	# rescue's white instead, so the drifting boat isn't shown behind the words.
	if fade != null:
		fade.cover_white_now()
	if ending != null:
		ending.visible = true
	finished.emit()


# A tween that runs on physics ticks, like everything that moves here.
func _new_tween() -> Tween:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	return _tween
