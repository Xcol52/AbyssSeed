class_name TerrainMeshBuilder
extends RefCounted


## Compatibility path for tests and non-streaming callers.
##
## Runtime streaming should use build_from_data() so geometry preparation
## has already occurred in the generation job.
static func build(
	chunk_data: TerrainChunkData,
	build_profile: TerrainMeshBuildProfile = null
) -> ArrayMesh:
	var validation_error := (
		TerrainMeshPreparer.get_validation_error(
			chunk_data
		)
	)

	if not validation_error.is_empty():
		push_error(validation_error)
		return null

	var mesh_data := TerrainMeshPreparer.prepare(
		chunk_data
	)

	if mesh_data == null:
		push_error(
			"TerrainMeshPreparer returned no mesh data."
		)
		return null

	return build_from_data(
		mesh_data,
		build_profile
	)


## Retains compatibility with the Stage 4A method name.
static func build_with_arrays(
	chunk_data: TerrainChunkData,
	build_profile: TerrainMeshBuildProfile = null
) -> ArrayMesh:
	return build(
		chunk_data,
		build_profile
	)


## Main-thread-only resource construction.
##
## TerrainMeshData must already be complete and must not be mutated.
static func build_from_data(
	mesh_data: TerrainMeshData,
	build_profile: TerrainMeshBuildProfile = null
) -> ArrayMesh:
	var profiling_enabled := build_profile != null
	var build_started_usec: int = 0

	if profiling_enabled:
		build_profile.reset()
		build_started_usec = Time.get_ticks_usec()

	if mesh_data == null:
		push_error(
			"TerrainMeshBuilder requires TerrainMeshData."
		)

		_finish_failed_profile(
			build_profile,
			build_started_usec
		)

		return null

	var validation_error := mesh_data.get_validation_error()

	if not validation_error.is_empty():
		push_error(validation_error)

		_finish_failed_profile(
			build_profile,
			build_started_usec
		)

		return null

	if profiling_enabled:
		build_profile.set_topology(
			mesh_data.get_cells_per_axis()
		)

		build_profile.validation_usec = (
			Time.get_ticks_usec()
			- build_started_usec
		)

	var stage_started_usec: int = 0

	if profiling_enabled:
		stage_started_usec = Time.get_ticks_usec()

	var surface_arrays: Array = []
	surface_arrays.resize(Mesh.ARRAY_MAX)

	surface_arrays[Mesh.ARRAY_VERTEX] = (
		mesh_data.get_vertices_read_only()
	)
	surface_arrays[Mesh.ARRAY_NORMAL] = (
		mesh_data.get_normals_read_only()
	)
	surface_arrays[Mesh.ARRAY_TEX_UV] = (
		mesh_data.get_uvs_read_only()
	)
	surface_arrays[Mesh.ARRAY_COLOR] = (
		mesh_data.get_colors_read_only()
	)

	## Mesh.ARRAY_INDEX intentionally remains null.

	if profiling_enabled:
		build_profile.surface_array_assembly_usec = (
			Time.get_ticks_usec()
			- stage_started_usec
		)

		stage_started_usec = Time.get_ticks_usec()

	var mesh := ArrayMesh.new()
	var coordinate := mesh_data.get_chunk_coordinate()

	mesh.resource_name = (
		"Terrain Chunk %d,%d"
		% [
			coordinate.x,
			coordinate.y
		]
	)

	if profiling_enabled:
		build_profile.mesh_resource_setup_usec = (
			Time.get_ticks_usec()
			- stage_started_usec
		)

		stage_started_usec = Time.get_ticks_usec()

	mesh.add_surface_from_arrays(
		Mesh.PRIMITIVE_TRIANGLES,
		surface_arrays
	)

	if profiling_enabled:
		build_profile.mesh_submission_usec = (
			Time.get_ticks_usec()
			- stage_started_usec
		)

		build_profile.total_usec = (
			Time.get_ticks_usec()
			- build_started_usec
		)

	return mesh


static func _finish_failed_profile(
	build_profile: TerrainMeshBuildProfile,
	build_started_usec: int
) -> void:
	if build_profile == null:
		return

	var now_usec := Time.get_ticks_usec()

	build_profile.validation_usec = maxi(
		0,
		now_usec - build_started_usec
	)

	build_profile.total_usec = (
		build_profile.validation_usec
	)
