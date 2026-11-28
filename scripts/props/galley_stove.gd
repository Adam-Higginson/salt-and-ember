class_name GalleyStove
extends StaticBody3D
## The galley's hearth: a stone fireplace with flames licking up from the
## logs in its mouth, embers drifting up from the fire, and an iron chimney carrying the smoke
## from its stone flue up through the ceiling and the deck. Its firelight
## ([Flicker]) is the warmest light aboard. Steam comes from the pans cooking
## on its hobs ([PanFeel]), not from the hearth itself (#204).
##
## It can be left down to its last embers (#249: the ship starts dark): the
## tongues of flame and the painted fire are out, the firelight is low, and
## Interact asks the lantern for a little of his own flame. See
## [method await_flame] and [method light].
##
## The flames (#207) are tongues drawn by a shader ([code]hearth_flame[/code]),
## standing on the logs and always facing you. The embers and smoke are
## particle systems. All are built here in code, so
## their settings sit in one place (like [RainEffect]). They start at the
## FlameSpot, EmberSpot and SmokeSpot markers. All three move with the stove
## (local coordinates), so they don't smear as the ship sails; the smoke, out
## in the wind on deck, leans astern as it rises. The flames (#204) dance over
## the fire painted in the Meshy hearth's mouth, so it burns, not just glows.

## The tongues of flame, each as x (across), y (up from the logs), width and
## height, in metres: a big one in the middle and two smaller either side.
const TONGUES: Array[Vector4] = [Vector4(0.0, 0.0, 0.34, 0.46), Vector4(-0.12, 0.0, 0.24, 0.32),
		Vector4(0.12, 0.0, 0.22, 0.3)]
## Emitted when the player asks the lantern to light the stove (only while
## it's waiting for a flame).
signal flame_asked(player: Player3D)

const FLAME_SHADER: Shader = preload("res://shaders/hearth_flame.gdshader")

## How far behind the FlameSpot the flames stand, into the mouth, in metres.
@export var flame_depth: float = -0.1
## Embers a second from the fire door.
@export var ember_rate: float = 3.0
## Puffs of smoke a second from the chimney.
@export var smoke_rate: float = 5.0

## How bright the firelight is on its last embers, as a share of its usual.
@export_range(0.0, 1.0) var ember_level: float = 0.18

## Whether the fire is burning. Down to embers, it isn't.
var burning: bool:
	get:
		return _burning

var _burning: bool = true
var _flames: Node3D = null
var _embers: GPUParticles3D = null
var _smoke: GPUParticles3D = null

@onready var _fire_light: Flicker = $FireLight
## The greybox's painted fire, which the Meshy hearth replaces (so it may be gone).
@onready var _fire: MeshInstance3D = get_node_or_null("Fire") as MeshInstance3D
@onready var _reach: Interactable3D = $Reach
@onready var _flame_spot: Marker3D = $FlameSpot
@onready var _ember_spot: Marker3D = $EmberSpot
@onready var _smoke_spot: Marker3D = $SmokeSpot


func _ready() -> void:
	_flames = _make_flames()
	_flame_spot.add_child(_flames)
	_embers = _make_embers()
	_ember_spot.add_child(_embers)
	_smoke = _make_smoke()
	_smoke_spot.add_child(_smoke)
	_reach.enabled = false
	_reach.interacted.connect(func(player: Player3D) -> void: flame_asked.emit(player))
	_reach.describe_interact = func(_player: Player3D) -> String:
		return "Ask him to light the stove"


## Lets the fire sink to its last embers and waits for a flame: Interact
## now asks the lantern to light it ([signal flame_asked]).
func await_flame() -> void:
	_burning = false
	_reach.enabled = true
	_show_fire(ember_level)


## Lights the fire again, at once: the flames, the painted fire and the
## firelight all come up. (A fade is [method set_fire_level].)
func light() -> void:
	_burning = true
	_reach.enabled = false
	_show_fire(1.0)


## Sets how strongly the fire burns, 0 to 1, for a fade between embers and
## flame. At 1 it counts as burning.
func set_fire_level(level: float) -> void:
	_show_fire(level)
	_burning = level >= 1.0


## The flames rising from the logs.
func flames() -> Node3D:
	return _flames


## The embers drifting from the fire.
func embers() -> GPUParticles3D:
	return _embers


## The smoke from the chimney, up on deck.
func smoke() -> GPUParticles3D:
	return _smoke


func _show_fire(level: float) -> void:
	_fire_light.level = level
	_fire_light.visible = level > 0.0
	_flames.visible = level > 0.5
	if is_instance_valid(_fire):
		_fire.visible = level > 0.5


func _make_flames() -> Node3D:
	var fire: Node3D = Node3D.new()
	fire.name = "Flames"
	# Set back into the mouth, over the logs (the particle flames hung out in
	# front of it and ghosted in the firelight, #207).
	fire.position = Vector3(0.0, 0.0, flame_depth)
	for tongue: Vector4 in TONGUES:
		var mesh: QuadMesh = QuadMesh.new()
		mesh.size = Vector2(tongue.z, tongue.w)
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = FLAME_SHADER
		material.set_shader_parameter(&"seed", tongue.x * 3.1 + tongue.y)
		material.set_shader_parameter(&"speed", 1.4 + tongue.z * 2.0)
		var quad: MeshInstance3D = MeshInstance3D.new()
		quad.name = "Tongue"
		quad.mesh = mesh
		quad.material_override = material
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Standing on the logs: its middle half its height up.
		quad.position = Vector3(tongue.x, tongue.y + tongue.w / 2.0, 0.0)
		fire.add_child(quad)
	return fire


func _make_smoke() -> GPUParticles3D:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.1
	process.direction = Vector3.UP
	process.spread = 10.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 1.4
	# Warm, so it keeps rising, and the wind of the ship's sailing leans it
	# astern (+z); it swells and thins out as it goes.
	process.gravity = Vector3(0.0, 0.25, 0.55)
	process.damping_min = 0.05
	process.damping_max = 0.1
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.12
	process.turbulence_noise_scale = 2.0
	process.scale_min = 0.8
	process.scale_max = 1.2
	process.scale_curve = _curve_texture([Vector2(0.0, 0.4), Vector2(1.0, 1.9)])
	process.color_ramp = _fade([0.0, 0.15, 1.0], [0.0, 0.55, 0.0])

	# Smoke is dark and lit by the night, unlike the bright steam indoors.
	var material: StandardMaterial3D = _soft_material(Color(0.62, 0.62, 0.66, 1.0))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.5, 0.5)
	mesh.material = material

	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Smoke"
	particles.local_coords = true
	particles.lifetime = 4.0
	particles.amount = maxi(ceili(smoke_rate * particles.lifetime), 1)
	particles.preprocess = 4.0
	particles.process_material = process
	particles.draw_pass_1 = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-6, -1, -6), Vector3(12, 8, 12))
	return particles


func _make_embers() -> GPUParticles3D:
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.12, 0.04, 0.02)
	process.direction = Vector3(0.0, 1.0, 0.6)
	process.spread = 25.0
	process.initial_velocity_min = 0.2
	process.initial_velocity_max = 0.45
	# Warm air lifts them; a wobble makes them drift rather than fly straight.
	process.gravity = Vector3(0.0, 0.25, 0.0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	process.turbulence_noise_scale = 1.5
	process.scale_min = 0.6
	process.scale_max = 1.2
	process.color_ramp = _fade([0.0, 0.1, 0.7, 1.0], [0.0, 1.0, 0.8, 0.0])

	var material: StandardMaterial3D = _soft_material(Color(1.0, 0.55, 0.18, 1.0))
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.12)
	material.emission_energy_multiplier = 6.0
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(0.025, 0.025)
	mesh.material = material

	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Embers"
	particles.local_coords = true
	particles.lifetime = 2.2
	particles.amount = maxi(ceili(ember_rate * particles.lifetime), 1)
	particles.process_material = process
	particles.draw_pass_1 = mesh
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 3, 2))
	return particles


# A camera-facing puff drawn as a chunky pixel blob (a small texture shown
# with sharp, nearest filtering), fading by the particles' colour.
func _soft_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var soft: Gradient = Gradient.new()
	soft.set_color(0, Color(1, 1, 1, 1))
	soft.set_color(1, Color(1, 1, 1, 0))
	var disc: GradientTexture2D = GradientTexture2D.new()
	disc.gradient = soft
	disc.fill = GradientTexture2D.FILL_RADIAL
	disc.fill_from = Vector2(0.5, 0.5)
	disc.fill_to = Vector2(1.0, 0.5)
	disc.width = 16
	disc.height = 16
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.albedo_texture = disc
	return material


func _curve_texture(points: Array[Vector2]) -> CurveTexture:
	var curve: Curve = Curve.new()
	curve.max_value = 2.0
	for point: Vector2 in points:
		curve.add_point(point)
	var texture: CurveTexture = CurveTexture.new()
	texture.curve = curve
	return texture


# A white ramp whose alpha passes through [param alphas] at [param offsets].
func _fade(offsets: Array[float], alphas: Array[float]) -> GradientTexture1D:
	var gradient: Gradient = Gradient.new()
	var packed_offsets: PackedFloat32Array = PackedFloat32Array()
	var colors: PackedColorArray = PackedColorArray()
	for i: int in offsets.size():
		packed_offsets.append(offsets[i])
		colors.append(Color(1, 1, 1, alphas[i]))
	gradient.offsets = packed_offsets
	gradient.colors = colors
	var texture: GradientTexture1D = GradientTexture1D.new()
	texture.gradient = gradient
	return texture
