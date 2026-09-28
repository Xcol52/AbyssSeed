class_name TerrainSampler
extends RefCounted

const DETAIL_SOFT_LIMIT_START: float = 0.65
const DETAIL_EPSILON: float = 0.000001


## Compatibility entry point retained for Sessions 3 and 4.
func generate(
	request: TerrainGenerationRequest
) -> TerrainChunkData:
	if request == null:
		push_error(
			"TerrainSampler requires a generation request."
		)
		return null

	var validation_errors := request.validate()

	if not validation_errors.is_empty():
		for message in validation_errors:
			push_error(
				"Invalid TerrainGenerationRequest: %s"
				% message
			)
		return null

	var snapshot := TerrainGenerationSnapshot.new(
		1,
		1,
		request.chunk_coordinate,
		request.generation_version,
		request.terrain_subsystem_seed,
		request.grid_settings.chunk_size,
		request.grid_settings.cells_per_axis,
		request.terrain_settings.base_seabed_depth,
		request.terrain_settings.test_elevation_amplitude,
		request.terrain_settings.test_noise_frequency,
		0
	)

	return generate_from_snapshot(snapshot)


static func generate_from_snapshot(
	snapshot: TerrainGenerationSnapshot
) -> TerrainChunkData:
	if snapshot == null:
		return null

	if not snapshot.get_validation_error().is_empty():
		return null

	var world_origin := Vector2(
		float(snapshot.chunk_coordinate.x)
			* snapshot.chunk_size,
		float(snapshot.chunk_coordinate.y)
			* snapshot.chunk_size
	)

	return _generate_region(
		snapshot,
		world_origin,
		snapshot.cells_per_axis,
		snapshot.get_cell_size(),
		snapshot.chunk_coordinate
	)


## Generates authoritative terrain for an arbitrary world-space region.
##
## This is used by debug tools that need to inspect terrain outside the
## normal chunk grid. The same detail noise, geological sampling, and
## depth limiting used by runtime chunks are applied here.
static func generate_region_from_snapshot(
	snapshot: TerrainGenerationSnapshot,
	world_origin: Vector2,
	cells_per_axis: int,
	cell_size: float,
	logical_coordinate: Vector2i = Vector2i.ZERO
) -> TerrainChunkData:
	if snapshot == null:
		return null

	if not snapshot.get_validation_error().is_empty():
		return null

	if (
		cells_per_axis < 1
		or not is_finite(cell_size)
		or cell_size <= 0.0
	):
		return null

	return _generate_region(
		snapshot,
		world_origin,
		cells_per_axis,
		cell_size,
		logical_coordinate
	)


static func _generate_region(
	snapshot: TerrainGenerationSnapshot,
	world_origin: Vector2,
	cells_per_axis: int,
	cell_size: float,
	logical_coordinate: Vector2i
) -> TerrainChunkData:
	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = snapshot.terrain_subsystem_seed
	detail_noise.frequency = snapshot.test_noise_frequency

	detail_noise.noise_type = (
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	)

	detail_noise.fractal_type = (
		FastNoiseLite.FRACTAL_NONE
	)

	var samples_per_axis := cells_per_axis + 1
	var geology_data: GeologyChunkData = null

	if snapshot.geology_snapshot != null:
		var geology_sampler := GeologySampler.new(
			snapshot.geology_snapshot
		)

		geology_data = geology_sampler.generate_region(
			world_origin,
			cells_per_axis,
			cell_size,
			logical_coordinate
		)

		if geology_data == null:
			return null

	var height_values := PackedFloat32Array()

	height_values.resize(
		samples_per_axis
		* samples_per_axis
	)

	for local_z in range(samples_per_axis):
		for local_x in range(samples_per_axis):
			var world_xz := world_origin + Vector2(
				float(local_x) * cell_size,
				float(local_z) * cell_size
			)

			var detail_value := detail_noise.get_noise_2d(
				world_xz.x,
				world_xz.y
			)

			var index := (
				local_z * samples_per_axis
				+ local_x
			)

			if geology_data == null:
				height_values[index] = (
					-snapshot.base_seabed_depth
					+ detail_value
					* snapshot.test_elevation_amplitude
				)
			else:
				var tectonic_activity := maxf(
					geology_data.ridge_potential[index],
					maxf(
						geology_data.trench_potential[index],
						maxf(
							geology_data
								.convergent_potential[index],
							geology_data.shear_strength[index]
						)
					)
				)

				var detail_scale := clampf(
					1.0
					- geology_data
						.sediment_potential[index]
					* 0.60
					+ tectonic_activity
					* 0.30,
					0.30,
					1.30
				)

				var detail_contribution := (
					detail_value
					* snapshot.test_elevation_amplitude
					* detail_scale
				)

				height_values[index] = (
					_apply_bounded_detail(
						geology_data.macro_elevation[index],
						detail_contribution,
						snapshot
							.geology_snapshot
							.minimum_seabed_depth,
						snapshot
							.geology_snapshot
							.maximum_seabed_depth
					)
				)

	return TerrainChunkData.new(
		logical_coordinate,
		cells_per_axis,
		cell_size,
		height_values,
		geology_data
	)


static func _apply_bounded_detail(
	macro_elevation: float,
	detail_contribution: float,
	minimum_seabed_depth: float,
	maximum_seabed_depth: float
) -> float:
	var maximum_elevation := (
		-minimum_seabed_depth
	)

	var minimum_elevation := (
		-maximum_seabed_depth
	)

	if detail_contribution > 0.0:
		var upper_headroom := (
			maximum_elevation
			- macro_elevation
		)

		var applied_positive := (
			_apply_soft_limited_magnitude(
				detail_contribution,
				upper_headroom
			)
		)

		return clampf(
			macro_elevation + applied_positive,
			minimum_elevation,
			maximum_elevation
		)

	if detail_contribution < 0.0:
		var lower_headroom := (
			macro_elevation
			- minimum_elevation
		)

		var applied_negative := (
			_apply_soft_limited_magnitude(
				-detail_contribution,
				lower_headroom
			)
		)

		return clampf(
			macro_elevation - applied_negative,
			minimum_elevation,
			maximum_elevation
		)

	return clampf(
		macro_elevation,
		minimum_elevation,
		maximum_elevation
	)


static func _apply_soft_limited_magnitude(
	requested_magnitude: float,
	available_headroom: float
) -> float:
	if requested_magnitude <= 0.0:
		return 0.0

	if available_headroom <= DETAIL_EPSILON:
		return 0.0

	var linear_limit := (
		available_headroom
		* DETAIL_SOFT_LIMIT_START
	)

	if requested_magnitude <= linear_limit:
		return requested_magnitude

	var soft_range := maxf(
		available_headroom - linear_limit,
		DETAIL_EPSILON
	)

	var excess := (
		requested_magnitude
		- linear_limit
	)

	return (
		linear_limit
		+ soft_range
		* (
			1.0
			- exp(
				-excess
				/ soft_range
			)
		)
	)
