@tool
class_name HangingChain
extends MultiMeshInstance3D
## One of the enormous chains in the Grave of the Lanterns: iron links
## strung from [member top] down to [member bottom] (both in this node's own
## space), sagging a little between them, each link turned a quarter turn
## from the one before as real chain is. It runs in the editor too, so move
## its ends in the Inspector and the chain follows.
##
## All the links are one [MultiMesh] (many copies of one mesh drawn in a
## single go), which is how a long chain stays cheap.
##
## A link is a plain torus until [member link_model] (or [member link_mesh]) is
## set: then every link is that mesh instead, the Meshy chain link
## (assets/third_party/meshy/chain_link, #234). A link mesh lies the way the
## Meshy one does: its length along Y, its width along X, its thickness along
## Z. It is scaled so its length is [member link_length], and its own paint is
## used (so [member thickness] and [member iron] only dress the torus).

## Where the chain starts and ends, in metres in this node's own space.
@export var top: Vector3 = Vector3.ZERO:
	set(value):
		top = value
		_rebuild_if_ready()
@export var bottom: Vector3 = Vector3(0.0, -20.0, 0.0):
	set(value):
		bottom = value
		_rebuild_if_ready()
## How far the middle hangs below the straight line between the ends, in metres.
@export var sag: float = 1.5:
	set(value):
		sag = value
		_rebuild_if_ready()
## How long one link is, in metres.
@export var link_length: float = 0.7:
	set(value):
		link_length = maxf(value, 0.05)
		_rebuild_if_ready()
## How thick the iron of a link is, in metres.
@export var thickness: float = 0.08:
	set(value):
		thickness = maxf(value, 0.01)
		_rebuild_if_ready()
## The iron. Only for the plain torus: a link model brings its own paint.
@export var iron: Material:
	set(value):
		iron = value
		_rebuild_if_ready()
## A model file for one link (a .glb), under res://assets/third_party/. If the
## file isn't there (a fresh clone, or CI, has no art) the torus is used.
@export_file("*.glb", "*.gltf") var link_model: String = "":
	set(value):
		link_model = value
		_rebuild_if_ready()
## A mesh for one link, used instead of [member link_model] when set.
@export var link_mesh: Mesh:
	set(value):
		link_mesh = value
		_rebuild_if_ready()

## Link meshes already taken from their model files, so a chain rebuilt in the
## editor (or the Grave's three chains) reads each file once.
static var _loaded: Dictionary[String, Mesh] = {}


func _ready() -> void:
	rebuild()


## How many links the chain has.
func link_count() -> int:
	return multimesh.instance_count if multimesh != null else 0


## Where along the chain [param share] of the way down is (0 the top, 1 the
## bottom), in this node's own space: a gentle curve sagging below the line.
func point_at(share: float) -> Vector3:
	var middle: Vector3 = (top + bottom) * 0.5 + Vector3.DOWN * sag * 2.0
	var a: Vector3 = top.lerp(middle, share)
	var b: Vector3 = middle.lerp(bottom, share)
	return a.lerp(b, share)


## Builds the links again.
func rebuild() -> void:
	var count: int = _planned_count()
	var model: Mesh = _model_link()
	var torus: TorusMesh = null
	if model == null:
		torus = TorusMesh.new()
		torus.outer_radius = 0.5
		torus.inner_radius = 0.5 - thickness / link_length * 1.4
		torus.rings = 10
		torus.ring_segments = 6
		torus.material = iron
	var links: MultiMesh = MultiMesh.new()
	links.transform_format = MultiMesh.TRANSFORM_3D
	links.mesh = model if model != null else torus
	links.instance_count = count
	for index: int in count:
		links.set_instance_transform(index, link_transform(index, count, model))
	multimesh = links


## Where link [param index] of [param count] sits, in this node's own space.
## [param model] is the link mesh, or null for the torus.
func link_transform(index: int, count: int, model: Mesh) -> Transform3D:
	var share: float = (float(index) + 0.5) / count
	var here: Vector3 = point_at(share)
	var ahead: Vector3 = point_at(minf(share + 0.01, 1.0))
	var behind: Vector3 = point_at(maxf(share - 0.01, 0.0))
	var along: Vector3 = (ahead - behind).normalized()
	var side: Vector3 = along.cross(Vector3.FORWARD)
	if side.length() < 0.01:
		side = along.cross(Vector3.RIGHT)
	side = side.normalized()
	# Every other link is turned a quarter turn about the chain.
	if index % 2 == 1:
		side = along.cross(side).normalized()
	var axis: Vector3 = side.cross(along).normalized()
	if model != null:
		# X across the link, Y along the chain, Z through the iron; the mesh's
		# middle sits on the chain.
		var box: AABB = model.get_aabb()
		var scale_up: float = link_length / maxf(box.size.y, 0.0001)
		var fitted: Basis = Basis(side, along, axis) * Basis.from_scale(Vector3.ONE * scale_up)
		return Transform3D(fitted, here - fitted * box.get_center())
	# A torus lies flat in its own XZ plane: X across the link, Z along the
	# chain (stretched, as a link is longer than it's wide).
	var basis: Basis = Basis(side * link_length * 0.62, axis * link_length * 0.62,
			along * link_length)
	return Transform3D(basis, here)


# How many links fit along the chain.
func _planned_count() -> int:
	var span: float = 0.0
	var steps: int = 64
	for index: int in steps:
		span += point_at(float(index) / steps).distance_to(point_at(float(index + 1) / steps))
	# Links overlap where they hook through each other.
	var pitch: float = link_length * 0.78
	return maxi(int(span / pitch), 1)


# The mesh for one link from [member link_mesh] or [member link_model], or null
# for the plain torus.
func _model_link() -> Mesh:
	if link_mesh != null:
		return link_mesh
	if link_model.is_empty() or not ResourceLoader.exists(link_model):
		return null
	if not Engine.is_editor_hint() and _loaded.has(link_model):
		return _loaded[link_model]
	var scene: PackedScene = load(link_model) as PackedScene
	if scene == null:
		return null
	var root: Node = scene.instantiate()
	var mesh: Mesh = null
	for found: Node in root.find_children("*", "MeshInstance3D", true, false):
		mesh = (found as MeshInstance3D).mesh
		break
	root.free()
	if mesh == null:
		return null
	# Meshy's textures carry an alpha channel; the iron is solid.
	for surface: int in mesh.get_surface_count():
		var paint: BaseMaterial3D = mesh.surface_get_material(surface) as BaseMaterial3D
		if paint != null:
			paint.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	if not Engine.is_editor_hint():
		_loaded[link_model] = mesh
	return mesh


func _rebuild_if_ready() -> void:
	if is_node_ready():
		rebuild()
