class_name ChainHand
extends Node3D
## The last length of the great chain, hanging down the side of the buoy,
## where you put a hand on it (#228). When it hums (see [ChainHum]) you can
## see it: the links shiver, kicked a little at each throb, and water drips
## off them in time.
##
## This is also the one thing the chain's break needs (#229): [method
## stop_hum] stops the sound, the rumble and the shiver together.
##
## Scene: [code]Chain[/code] (the links, a [HangingChain] with its top at
## this node's origin, so it swings from the top), [code]Hum[/code] (the
## sound and rumble) and [code]Drips[/code] (a [CPUParticles3D]).

## Emitted when the hum starts.
signal hum_started
## Emitted when the hum stops.
signal hum_stopped

## How far the chain sways at full hum, in degrees.
@export var sway_degrees: float = 2.2
## How many sways a second.
@export var sway_rate: float = 1.1
## How much extra each throb kicks it, as a share of the usual sway.
@export var kick_amount: float = 1.4

var _kick: float = 0.0
var _time: float = 0.0

@onready var _chain: HangingChain = $Chain
@onready var _hum: ChainHum = $Hum
@onready var _drips: CPUParticles3D = $Drips


func _ready() -> void:
	_hum.started.connect(hum_started.emit)
	_hum.stopped.connect(hum_stopped.emit)
	_hum.pulsed.connect(_on_pulsed)
	_drips.emitting = false


func _process(delta: float) -> void:
	_time += delta
	_kick = move_toward(_kick, 0.0, delta * 1.6)
	var amount: float = sway()
	_chain.rotation = Vector3(
			sin(_time * TAU * sway_rate * 0.77) * amount * 0.6, 0.0,
			sin(_time * TAU * sway_rate) * amount)


## Starts the hum (and with it the sound, the rumble and the shiver).
func start_hum() -> void:
	_hum.start_humming()


## Stops the hum: all of it at once.
func stop_hum() -> void:
	_hum.stop_humming()


## Whether the chain is humming.
func is_humming() -> bool:
	return _hum.is_humming


## How much the links are shivering now, in radians of sway: nothing when it's
## still, more at the top of each throb.
func sway() -> float:
	return deg_to_rad(sway_degrees) * _hum.shake * (1.0 + _kick * kick_amount)


## The chain's hum, for volume and the like.
func hum() -> ChainHum:
	return _hum


## Whether the drips are falling.
func is_dripping() -> bool:
	return _drips.emitting


func _on_pulsed() -> void:
	_kick = 1.0
	_drips.restart()
	_drips.emitting = true
