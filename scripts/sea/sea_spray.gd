class_name SeaSpray
extends GPUParticles3D
## Spray blown off the bigger wave crests near [member follow] (the rowboat),
## and thrown up round the posts standing in the water (the jetty's piles):
## little painted droplets that catch the low sun.
##
## The graphics card does the work (shaders/sea_spray.gdshader): it works
## out the same waves as the water and only lets droplets fly where a crest
## is pointed enough, or where the water rises round a post. This script just
## keeps it over the boat and hands it the sea's waves every frame.

## The process shader has room for this many posts.
const MAX_POSTS: int = 8

## The sea whose waves throw the spray. Empty finds the scene's [Sea].
@export var sea: Sea
## What the spray gathers round (the rowboat). Empty: round this node.
@export var follow: Node3D
## How far from [member follow] spray comes off the crests, in metres.
@export var radius: float = 14.0
## Posts standing in the water, as world x and z, and how thick they are
## (their radius, in metres). Up to eight.
@export var posts: PackedVector2Array = PackedVector2Array()
@export var post_radius: float = 0.3

var _process_material: ShaderMaterial = null


func _ready() -> void:
	# Moved every drawn frame, so there's nothing to smooth between ticks.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_process_material = process_material as ShaderMaterial
	_send_posts()


func _process(_delta: float) -> void:
	if not is_instance_valid(sea):
		sea = get_tree().get_first_node_in_group(&"sea") as Sea
	if is_instance_valid(follow):
		global_position = Vector3(follow.global_position.x, global_position.y,
				follow.global_position.z)
	if _process_material == null or sea == null:
		return
	sea.apply_waves_to(_process_material)
	global_position.y = sea.global_position.y
	_process_material.set_shader_parameter(&"sea_level", sea.global_position.y)
	_process_material.set_shader_parameter(&"centre",
			Vector2(global_position.x, global_position.z))
	_process_material.set_shader_parameter(&"radius", radius)


func _send_posts() -> void:
	if _process_material == null:
		return
	var packed: PackedVector3Array = PackedVector3Array()
	for post: Vector2 in posts.slice(0, MAX_POSTS):
		packed.append(Vector3(post.x, post.y, post_radius))
	var count: int = packed.size()
	while packed.size() < MAX_POSTS:
		packed.append(Vector3.ZERO)
	_process_material.set_shader_parameter(&"posts", packed)
	_process_material.set_shader_parameter(&"post_count", count)
