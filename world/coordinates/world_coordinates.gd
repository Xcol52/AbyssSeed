class_name WorldCoordinates
extends RefCounted


## Mathematical floor division for a positive divisor.
## Unlike truncating integer division, -1 / 64 maps to -1.
static func floor_divide(
	numerator: int,
	positive_divisor: int
) -> int:
	assert(positive_divisor > 0)

	return int(
		floor(float(numerator) / float(positive_divisor))
	)


static func positive_modulo(
	value: int,
	positive_divisor: int
) -> int:
	assert(positive_divisor > 0)

	var quotient := floor_divide(value, positive_divisor)
	return value - quotient * positive_divisor


## Vector2.x represents world X.
## Vector2.y represents world Z.
static func world_to_chunk(
	world_xz: Vector2,
	grid_settings: WorldGridSettings
) -> Vector2i:
	assert(grid_settings != null)
	assert(grid_settings.chunk_size > 0.0)

	return Vector2i(
		int(floor(world_xz.x / grid_settings.chunk_size)),
		int(floor(world_xz.y / grid_settings.chunk_size))
	)


static func chunk_to_world_origin(
	chunk_coordinate: Vector2i,
	grid_settings: WorldGridSettings
) -> Vector2:
	assert(grid_settings != null)

	return Vector2(
		float(chunk_coordinate.x) * grid_settings.chunk_size,
		float(chunk_coordinate.y) * grid_settings.chunk_size
	)


static func world_to_chunk_local(
	world_xz: Vector2,
	grid_settings: WorldGridSettings
) -> Vector2:
	var chunk_coordinate := world_to_chunk(
		world_xz,
		grid_settings
	)
	var chunk_origin := chunk_to_world_origin(
		chunk_coordinate,
		grid_settings
	)

	return world_xz - chunk_origin


static func chunk_local_to_world(
	chunk_coordinate: Vector2i,
	local_xz: Vector2,
	grid_settings: WorldGridSettings
) -> Vector2:
	return (
		chunk_to_world_origin(chunk_coordinate, grid_settings)
		+ local_xz
	)


## local_sample may include cells_per_axis so mesh boundaries overlap.
static func chunk_local_sample_to_global(
	chunk_coordinate: Vector2i,
	local_sample: Vector2i,
	cells_per_axis: int
) -> Vector2i:
	assert(cells_per_axis > 0)
	assert(local_sample.x >= 0)
	assert(local_sample.y >= 0)
	assert(local_sample.x <= cells_per_axis)
	assert(local_sample.y <= cells_per_axis)

	return Vector2i(
		chunk_coordinate.x * cells_per_axis + local_sample.x,
		chunk_coordinate.y * cells_per_axis + local_sample.y
	)


## Returns the canonical half-open owner of a global sample.
static func global_sample_to_chunk(
	global_sample: Vector2i,
	cells_per_axis: int
) -> Vector2i:
	return Vector2i(
		floor_divide(global_sample.x, cells_per_axis),
		floor_divide(global_sample.y, cells_per_axis)
	)


## Returns a canonical local sample in 0 through N - 1.
## A shared mesh boundary may still be addressed as N by its lower chunk.
static func global_sample_to_local(
	global_sample: Vector2i,
	cells_per_axis: int
) -> Vector2i:
	return Vector2i(
		positive_modulo(global_sample.x, cells_per_axis),
		positive_modulo(global_sample.y, cells_per_axis)
	)


static func global_sample_to_world_xz(
	global_sample: Vector2i,
	cell_size: float
) -> Vector2:
	return Vector2(
		float(global_sample.x) * cell_size,
		float(global_sample.y) * cell_size
	)
