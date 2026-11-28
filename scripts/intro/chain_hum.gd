class_name ChainHum
extends AudioStreamPlayer3D
## The great chain's hum (#228): low and slow, felt more than heard. It's one
## thing with three faces: the sound you hear, the controller rumble you feel
## (a soft throb every [member pulse_seconds]), and [member shake], which the
## chain's links and drips follow so you see it too.
##
## It starts when you put a hand on the chain ([method start_humming]) and
## runs until something calls [method stop_humming]: the chain breaking
## (#229) stops all three together, and that's the moment the player notices.
##
## The sound is a placeholder made in code (a low sine and its octave,
## swelling once a pulse), rendered once into an [AudioStreamWAV] that loops,
## the same trick [Hum] uses.

## Emitted when the hum starts.
signal started
## Emitted when the hum stops.
signal stopped
## Emitted at the top of each throb, while it hums.
signal pulsed

## Samples a second. Low is fine for a hum.
const MIX_RATE: float = 22050.0

## How long one throb lasts, in seconds. The sound loops on exactly this.
@export var pulse_seconds: float = 1.6
## The note, in hertz. Pulses are rendered to hold a whole number of its
## cycles, so the loop doesn't click.
@export var pitch_hz: float = 55.0
## How loud the hum is, 0 to 1.
@export_range(0.0, 1.0) var loudness: float = 0.5:
	set(value):
		loudness = value
		volume_db = linear_to_db(maxf(loudness, 0.0001))
## Whether it rumbles a controller.
@export var rumble: bool = true
## How hard it rumbles, 0 to 1, on the controller's strong motor.
@export_range(0.0, 1.0) var rumble_strength: float = 0.35
## Seconds the shake takes to build up, and to die away.
@export var fade_seconds: float = 1.2

## Whether it's humming now.
var is_humming: bool = false

## How strongly it's felt, 0 to 1: it builds when the hum starts and dies away
## when it stops. The chain's shiver follows it.
var shake: float = 0.0

## How many throbs there have been since it started.
var pulse_count: int = 0

## The loop, rendered the first time a hum needs it.
static var _recording: AudioStreamWAV = null

var _clock: float = 0.0


func _ready() -> void:
	stream = recording(pulse_seconds, pitch_hz)
	unit_size = 6.0
	volume_db = linear_to_db(maxf(loudness, 0.0001))


func _physics_process(delta: float) -> void:
	var goal: float = 1.0 if is_humming else 0.0
	shake = move_toward(shake, goal, delta / maxf(fade_seconds, 0.01))
	if not is_humming:
		return
	_clock += delta
	# start_humming() throbs once, so pulse_count throbs are already done.
	if _clock >= pulse_seconds * pulse_count:
		_throb()


func _exit_tree() -> void:
	# Don't leave a controller rumbling if the scene goes.
	_stop_rumble()


## Starts the hum: the sound, the rumble and the shake. Does nothing if it's
## already humming.
func start_humming() -> void:
	if is_humming:
		return
	is_humming = true
	_clock = 0.0
	pulse_count = 0
	play()
	_throb()
	started.emit()


## Stops all of it at once: the sound, the rumble, and (as [member shake]
## dies away) the shiver. Does nothing if it isn't humming.
func stop_humming() -> void:
	if not is_humming:
		return
	is_humming = false
	stop()
	_stop_rumble()
	stopped.emit()


## One throb of the loop, as a sound: 16-bit mono at [constant MIX_RATE], made
## once and shared (unless the settings differ).
static func recording(seconds: float = 1.6, hertz: float = 55.0) -> AudioStreamWAV:
	if _recording != null and is_equal_approx(_recording.get_length(), seconds):
		return _recording
	var count: int = roundi(seconds * MIX_RATE)
	var data: PackedByteArray = PackedByteArray()
	data.resize(count * 2)
	for i: int in count:
		var level: float = clampf(sample(i / MIX_RATE, seconds, hertz), -1.0, 1.0)
		data.encode_s16(i * 2, roundi(level * 32767.0))
	var sound: AudioStreamWAV = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = int(MIX_RATE)
	sound.stereo = false
	sound.data = data
	sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sound.loop_begin = 0
	sound.loop_end = count
	_recording = sound
	return sound


## The hum's level (-1 to 1, before [member loudness]) [param t] seconds into
## a throb of [param seconds]: a low note swelling up and ebbing away once.
static func sample(t: float, seconds: float, hertz: float) -> float:
	# Whole cycles in the loop, so its end meets its start.
	var cycles: float = maxf(roundf(hertz * seconds), 1.0)
	var phase: float = TAU * cycles * t / seconds
	var swell: float = 0.55 + 0.45 * sin(TAU * t / seconds - PI / 2.0)
	return swell * (sin(phase) * 0.8 + sin(phase * 2.0) * 0.2)


func _throb() -> void:
	pulse_count += 1
	if rumble:
		for device: int in Input.get_connected_joypads():
			Input.start_joy_vibration(device, 0.0, rumble_strength, pulse_seconds * 0.6)
	pulsed.emit()


func _stop_rumble() -> void:
	for device: int in Input.get_connected_joypads():
		Input.stop_joy_vibration(device)
