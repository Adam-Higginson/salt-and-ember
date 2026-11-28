extends GameTestSuite
## Tests for HangingChain's links: the plain torus, and a link mesh (the Meshy
## chain link, #234) standing in for it.

const MISSING: String = "res://assets/third_party/meshy/not_a_real_link/model/model.glb"


func test_a_chain_is_made_of_torus_links_by_default() -> void:
	var chain: HangingChain = _new_chain()
	assert_object(chain.multimesh.mesh).is_instanceof(TorusMesh)
	assert_int(chain.link_count()).is_greater(10)


func test_a_missing_link_model_leaves_the_torus() -> void:
	# CI has no art: a model file that isn't there must not break the chain.
	var chain: HangingChain = _new_chain()
	chain.link_model = MISSING
	assert_object(chain.multimesh.mesh).is_instanceof(TorusMesh)


func test_a_link_mesh_is_used_for_every_link() -> void:
	var chain: HangingChain = _new_chain()
	var plain_count: int = chain.link_count()
	var link: BoxMesh = BoxMesh.new()
	link.size = Vector3(0.7, 1.0, 0.25)
	chain.link_mesh = link
	assert_object(chain.multimesh.mesh).is_same(link)
	assert_int(chain.link_count()).is_equal(plain_count)


func test_a_link_mesh_is_scaled_so_its_length_is_the_link_length() -> void:
	var chain: HangingChain = _new_chain()
	var link: BoxMesh = BoxMesh.new()
	# Twice the length of a link, lying along Y as the Meshy link does.
	link.size = Vector3(1.4, 2.0, 0.5)
	chain.link_mesh = link
	var basis: Basis = chain.link_transform(0, chain.link_count(), link).basis
	# The mesh's Y axis maps onto the chain, scaled by link_length / 2. (The
	# transforms are asked of the chain, not read back from the MultiMesh,
	# which a headless run doesn't keep.)
	assert_float(basis.y.length()).is_equal_approx(chain.link_length / 2.0, 0.001)
	assert_float(basis.x.length()).is_equal_approx(chain.link_length / 2.0, 0.001)
	assert_float(basis.determinant()).is_greater(0.0)


func test_a_link_mesh_is_centred_on_the_chain() -> void:
	var chain: HangingChain = _new_chain()
	# A box whose middle is 0.4 up from its own origin, like a model whose
	# origin is at its foot.
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.7, 1.0, 0.25)
	var arrays: Array = box.get_mesh_arrays()
	var corners: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index: int in corners.size():
		corners[index] += Vector3(0.0, 0.4, 0.0)
	arrays[Mesh.ARRAY_VERTEX] = corners
	var link: ArrayMesh = ArrayMesh.new()
	link.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	chain.link_mesh = link
	var placed: Transform3D = chain.link_transform(0, chain.link_count(), link)
	var middle: Vector3 = placed * link.get_aabb().get_center()
	var along: Vector3 = chain.point_at(0.5 / chain.link_count())
	assert_vector(middle).is_equal_approx(along, Vector3.ONE * 0.001)


func _new_chain() -> HangingChain:
	var chain: HangingChain = HangingChain.new()
	chain.top = Vector3.ZERO
	chain.bottom = Vector3(0.0, -10.0, -4.0)
	add_child(chain)
	auto_free(chain)
	return chain
