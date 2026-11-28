class_name WaveLayer
extends Resource
## One layer of Gerstner waves: a train of waves rolling one way. Several
## layers added together make the sea (a long swell plus a finer chop). See
## [WaveSettings].
##
## A Gerstner wave moves the surface in circles rather than just up and down,
## so crests come out sharp and troughs wide, like real water.

## Which way the waves roll, in degrees: 0 rolls towards -Z, 90 towards -X.
@export_range(0.0, 360.0) var direction_degrees: float = 0.0
## Crest to crest, in metres.
@export_range(1.0, 500.0) var wavelength: float = 60.0
## Height of a crest above the still water level, in metres.
@export_range(0.0, 10.0) var amplitude: float = 1.0
## How pointed the crests are, 0 (smooth rolling) to 1 (as sharp as it gets
## before the surface folds over itself).
@export_range(0.0, 1.0) var steepness: float = 0.3
## Peaked crests: the true Gerstner steepness, 0 to 1. Above 0 it
## replaces [member steepness]: each point is pushed sideways by this share
## of how far it could go before the surface folds over, so the crest
## narrows to a point and the trough widens, whatever the wave's size. 0.5 is
## a clear peak; keep the layers' peaks added up under 1, or the crests fold
## where they meet. 0 (the night seas) leaves the older, gentler shape.
@export_range(0.0, 1.0) var peak: float = 0.0


## The flat direction the waves roll, as x and z.
func direction() -> Vector2:
	var angle: float = deg_to_rad(direction_degrees)
	return Vector2(-sin(angle), -cos(angle))


## The wave number: how many radians of wave fit in a metre.
func wave_number() -> float:
	return TAU / wavelength


## How fast the crests travel, in metres per second. Deep-water waves travel
## at a speed set by their length alone, so long swells are fast.
func speed() -> float:
	return sqrt(9.8 / wave_number())


## How far a point is pushed sideways at a crest, as a fraction of the
## amplitude, kept low enough that the surface never folds over.
func sideways() -> float:
	var k_a: float = wave_number() * amplitude
	if k_a <= 0.0:
		return 0.0
	if peak > 0.0:
		return peak / k_a
	return minf(steepness, 1.0 / k_a)


## How pointed a crest of this layer is at its tip, 0 (round) to 1 (a cusp):
## the sideways push times the wave's slope.
func sharpness() -> float:
	return sideways() * wave_number() * amplitude
