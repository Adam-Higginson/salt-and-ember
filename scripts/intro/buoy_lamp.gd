class_name BuoyLamp
extends Node3D
## The buoy's caged lamp (#228). It starts dead and dark; [method light_up]
## lights it, and the glow comes up over a moment: the glass starts to glow
## and a warm light spreads over the buoy.
##
## A Meshy buoy will come in two parts, the body and this lamp, so the lamp is
## its own node with its own light, and the buoy's gameplay only ever talks
## to this script.

## Emitted when the lamp is lit.
signal lit_up

## The lamp's glass, whose emission glows.
@export var glass: MeshInstance3D
## The light it throws once it's lit.
@export var light: OmniLight3D
## How bright the light is at full glow.
@export var light_energy: float = 3.0
## How bright the glass glows at full glow.
@export var glass_glow: float = 3.5
## The flame's colour.
@export var colour: Color = Color(1.0, 0.7, 0.35)
## Seconds the glow takes to come up.
@export var glow_seconds: float = 1.5

## Whether it's been lit.
var lit: bool = false

## How far the glow has come up, 0 to 1.
var glow: float = 0.0

var _glass_material: StandardMaterial3D = null


func _ready() -> void:
	# The glass's material is shared by every buoy: give this one its own, so
	# lighting it lights only it.
	if glass != null and glass.material_override is StandardMaterial3D:
		_glass_material = (glass.material_override as StandardMaterial3D).duplicate()
		_glass_material.emission = colour
		_glass_material.emission_enabled = false
		glass.material_override = _glass_material
	_apply()


func _physics_process(delta: float) -> void:
	var goal: float = 1.0 if lit else 0.0
	if is_equal_approx(glow, goal):
		return
	glow = move_toward(glow, goal, delta / maxf(glow_seconds, 0.01))
	_apply()


## Lights the lamp. Returns whether it was lit just now (false if it already
## was).
func light_up() -> bool:
	if lit:
		return false
	lit = true
	lit_up.emit()
	return true


func _apply() -> void:
	if light != null:
		light.light_color = colour
		light.light_energy = light_energy * glow
		light.visible = glow > 0.0
	if _glass_material != null:
		_glass_material.emission_enabled = glow > 0.0
		_glass_material.emission_energy_multiplier = glass_glow * glow
