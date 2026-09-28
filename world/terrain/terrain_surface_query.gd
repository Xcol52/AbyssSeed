class_name TerrainSurfaceQuery
extends RefCounted

const LOCAL_BOUNDS_EPSILON_METERS: float = 0.0001


static func world_to_chunk_coordinate(
	world_position: Vector3,
	chunk_size_meters: float
) -> Vector2i:
	assert(chunk_size_meters > 0.0)

	return Vector2i(
		floori(
			world_position.x
			/ chunk_size_meters
		),
		floori(
			world_position.z
			/ chunk_size_meters
		)
	)


## Samples the same piecewise-planar triangle layout emitted by
## TerrainMeshPreparer.
static func sample_local(
	chunk_data: TerrainChunkData,
	local_position_xz: Vector2
) -> TerrainSurfaceQueryResult:
	var chunk_coordinate := Vector2i.ZERO

	if chunk_data != null:
		chunk_coordinate = (
			chunk_data.chunk_coordinate
		)

	var result := (
		TerrainSurfaceQueryResult
		.create_unavailable(
			Vector3(
				local_position_xz.x,
				0.0,
				local_position_xz.y
			),
			chunk_coordinate
		)
	)

	if chunk_data == null:
		return result

	if chunk_data.cells_per_axis < 1:
		return result

	if (
		not is_finite(chunk_data.cell_size)
		or chunk_data.cell_size <= 0.0
	):
		return result

	if (
		not is_finite(local_position_xz.x)
		or not is_finite(local_position_xz.y)
	):
		return result

	var cells := chunk_data.cells_per_axis
	var cell_size := chunk_data.cell_size

	var vertices_per_axis := cells + 1

	var expected_height_count := (
		vertices_per_axis
		* vertices_per_axis
	)

	if (
		chunk_data.height_values.size()
		!= expected_height_count
	):
		return result

	var chunk_size := (
		float(cells)
		* cell_size
	)

	var bounds_epsilon := maxf(
		LOCAL_BOUNDS_EPSILON_METERS,
		chunk_size * 0.0000001
	)

	if (
		local_position_xz.x < -bounds_epsilon
		or local_position_xz.y < -bounds_epsilon
		or local_position_xz.x
		> chunk_size + bounds_epsilon
		or local_position_xz.y
		> chunk_size + bounds_epsilon
	):
		return result

	var local_x := clampf(
		local_position_xz.x,
		0.0,
		chunk_size
	)

	var local_z := clampf(
		local_position_xz.y,
		0.0,
		chunk_size
	)

	var grid_x := local_x / cell_size
	var grid_z := local_z / cell_size

	var cell_x := mini(
		floori(grid_x),
		cells - 1
	)

	var cell_z := mini(
		floori(grid_z),
		cells - 1
	)

	var unit_x := clampf(
		grid_x - float(cell_x),
		0.0,
		1.0
	)

	var unit_z := clampf(
		grid_z - float(cell_z),
		0.0,
		1.0
	)

	var height_00 := chunk_data.get_height(
		cell_x,
		cell_z
	)

	var height_10 := chunk_data.get_height(
		cell_x + 1,
		cell_z
	)

	var height_01 := chunk_data.get_height(
		cell_x,
		cell_z + 1
	)

	var height_11 := chunk_data.get_height(
		cell_x + 1,
		cell_z + 1
	)

	var surface_height: float
	var triangle_index: int

	if unit_x + unit_z <= 1.0:
		## Triangle:
		##
		## point_00
		## point_01
		## point_10
		surface_height = (
			height_00
			* (1.0 - unit_x - unit_z)
			+ height_10 * unit_x
			+ height_01 * unit_z
		)

		triangle_index = 0
	else:
		## Triangle:
		##
		## point_10
		## point_01
		## point_11
		surface_height = (
			height_10
			* (1.0 - unit_z)
			+ height_01
			* (1.0 - unit_x)
			+ height_11
			* (unit_x + unit_z - 1.0)
		)

		triangle_index = 1

	result.available = true

	result.local_position_xz = Vector2(
		local_x,
		local_z
	)

	result.cell_coordinate = Vector2i(
		cell_x,
		cell_z
	)

	result.triangle_index = triangle_index
	result.surface_elevation_meters = surface_height

	result.surface_world_position = Vector3(
		local_x,
		surface_height,
		local_z
	)

	return result


## Samples retained data belonging to an active WorldChunk.
##
## This never generates terrain or creates a scheduler request.
static func sample_world_chunk(
	world_chunk: WorldChunk,
	world_position: Vector3
) -> TerrainSurfaceQueryResult:
	if (
		world_chunk == null
		or not is_instance_valid(world_chunk)
	):
		return (
			TerrainSurfaceQueryResult
			.create_unavailable(
				world_position,
				Vector2i.ZERO
			)
		)

	var chunk_data := world_chunk.get_chunk_data()

	if chunk_data == null:
		return (
			TerrainSurfaceQueryResult
			.create_unavailable(
				world_position,
				world_chunk.get_chunk_coordinate()
			)
		)

	var local_request := world_chunk.to_local(
		world_position
	)

	var result := sample_local(
		chunk_data,
		Vector2(
			local_request.x,
			local_request.z
		)
	)

	result.requested_world_position = world_position

	if not result.available:
		return result

	var local_surface_position := Vector3(
		result.local_position_xz.x,
		result.surface_elevation_meters,
		result.local_position_xz.y
	)

	var world_surface_position := (
		world_chunk.to_global(
			local_surface_position
		)
	)

	result.surface_world_position = (
		world_surface_position
	)

	result.surface_elevation_meters = (
		world_surface_position.y
	)

	return result
