class_name BuoySpot
extends Marker3D
## Something on the buoy you can use with the interact button (#228): the
## chain, the lamp, the ladder down. You can't walk about up there, so you
## look at a spot (turn the camera towards it) and press interact; see
## [BuoyTending].
##
## A spot is just a marker with a [member kind] and the words its prompt shows.
## A Meshy buoy later keeps the same markers, so the gameplay doesn't change.

## What a spot does.
enum Kind {
	## Put a hand on the chain and feel it hum.
	CHAIN,
	## The dead lamp, which the lantern lights.
	LAMP,
	## The way back down to the boat.
	LADDER,
}

## What using this spot does.
@export var kind: Kind = Kind.CHAIN
## What the prompt says: "Put a hand on the chain".
@export var prompt_text: String = "Use"

## Whether it's been used (the chain touched, the lamp lit).
var used: bool = false
