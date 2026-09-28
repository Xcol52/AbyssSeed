class_name GiantSquidRegionalSampler
extends RefCounted

const REGION_SIZE: float = 8192.0

const MINIMUM_DEPTH: float = 4800.0
const MAXIMUM_LIGHT: float = 0.0005
const MINIMUM_TRENCH_POTENTIAL: float = 0.82
const MINIMUM_ABYSSAL_INFLUENCE: float = 0.70

const HOME_ALTITUDE: float = 80.0
const MINIMUM_ALTITUDE: float = 35.0
const MAXIMUM_ALTITUDE: float = 220.0
const HOME_RADIUS: float = 1800.0

const REGION_JITTER_X_CHANNEL: int = 17401
const REGION_JITTER_Z_CHANNEL: int = 17402
const IDENTITY_CHANNEL: int = 17403
const HEADING_CHANNEL: int = 17404
const BEHAVIOR_CHANNEL: int = 17405

var _fauna_seed: int = 0


func _init(
	fauna_seed: int
) -> void:
	_fauna_seed = fauna_seed


func generate_for_chunk(
	terrain_data: TerrainChunkData,
	environment_sampler: EnvironmentSampler
) -> FaunaPopulationDescriptor:
	if terrain_data == null:
		return null

	if terrain_data.geology_data == null:
		return null

	if environment_sampler == null:
		return null

	var world_minimum: Vector2 = (
		terrain_data.geology_data.world_origin
	)

	var chunk_size: float = (
		float(terrain_data.cells_per_axis)
		* terrain_data.cell_size
	)

	if chunk_size <= 0.0:
		return null

	var world_maximum: Vector2 = (
		world_minimum
		+ Vector2.ONE * chunk_size
	)

	var minimum_region_x: int = (
		floori(world_minimum.x / REGION_SIZE) - 1
	)

	var minimum_region_z: int = (
		floori(world_minimum.y / REGION_SIZE) - 1
	)

	var maximum_region_x: int = (
		floori(world_maximum.x / REGION_SIZE) + 1
	)

	var maximum_region_z: int = (
		floori(world_maximum.y / REGION_SIZE) + 1
	)

	for region_z in range(
		minimum_region_z,
		maximum_region_z + 1
	):
		for region_x in range(
			minimum_region_x,
			maximum_region_x + 1
		):
			var region_coordinate: Vector2i = Vector2i(
				region_x,
				region_z
			)

			var candidate_xz: Vector2 = (
				get_candidate_position(
					_fauna_seed,
					region_coordinate
				)
			)

			if (
				candidate_xz.x < world_minimum.x
				or candidate_xz.y < world_minimum.y
				or candidate_xz.x >= world_maximum.x
				or candidate_xz.y >= world_maximum.y
			):
				continue

			var environment: EnvironmentSample = (
				environment_sampler.sample_world(
					terrain_data,
					candidate_xz
				)
			)

			if environment == null:
				continue

			if not is_habitat_eligible(
				environment.depth_below_surface,
				environment.light_availability,
				environment.trench_potential,
				environment.abyssal_province_influence
			):
				continue

			var stable_id: int = get_stable_id(
				_fauna_seed,
				region_coordinate
			)

			var behavior_seed: int = (
				StableSeed.derive_spatial_seed(
					_fauna_seed,
					BEHAVIOR_CHANNEL,
					region_coordinate
				)
			)

			var heading_seed: int = (
				StableSeed.derive_spatial_seed(
					_fauna_seed,
					HEADING_CHANNEL,
					region_coordinate
				)
			)

			var heading: float = (
				StableSeed.seed_to_unit_float(
					heading_seed
				) * TAU
			)

			var suitability: float = (
				calculate_suitability(
					environment.depth_below_surface,
					environment.light_availability,
					environment.trench_potential,
					environment.abyssal_province_influence
				)
			)

			return FaunaPopulationDescriptor.new(
				stable_id,
				FaunaIds.GIANT_SQUID,
				region_coordinate,
				terrain_data.chunk_coordinate,
				Vector3(
					candidate_xz.x,
					environment.seabed_elevation
						+ HOME_ALTITUDE,
					candidate_xz.y
				),
				1,
				MINIMUM_ALTITUDE,
				MAXIMUM_ALTITUDE,
				HOME_RADIUS,
				suitability,
				suitability,
				environment.trench_potential,
				heading,
				behavior_seed,
				FaunaTypes.OwnershipMode.REGIONAL_HOME
			)

	return null


static func is_habitat_eligible(
	depth_below_surface: float,
	light_availability: float,
	trench_potential: float,
	abyssal_influence: float
) -> bool:
	if (
		not is_finite(depth_below_surface)
		or not is_finite(light_availability)
		or not is_finite(trench_potential)
		or not is_finite(abyssal_influence)
	):
		return false

	return (
		depth_below_surface >= MINIMUM_DEPTH
		and light_availability <= MAXIMUM_LIGHT
		and trench_potential
			>= MINIMUM_TRENCH_POTENTIAL
		and abyssal_influence
			>= MINIMUM_ABYSSAL_INFLUENCE
	)


static func calculate_suitability(
	depth_below_surface: float,
	light_availability: float,
	trench_potential: float,
	abyssal_influence: float
) -> float:
	if not is_habitat_eligible(
		depth_below_surface,
		light_availability,
		trench_potential,
		abyssal_influence
	):
		return 0.0

	var depth_factor: float = clampf(
		(
			depth_below_surface
			- MINIMUM_DEPTH
		) / 1200.0,
		0.0,
		1.0
	)

	var darkness_factor: float = clampf(
		1.0
			- light_availability
				/ MAXIMUM_LIGHT,
		0.0,
		1.0
	)

	var trench_factor: float = clampf(
		(
			trench_potential
			- MINIMUM_TRENCH_POTENTIAL
		) / (
			1.0
			- MINIMUM_TRENCH_POTENTIAL
		),
		0.0,
		1.0
	)

	var abyssal_factor: float = clampf(
		(
			abyssal_influence
			- MINIMUM_ABYSSAL_INFLUENCE
		) / (
			1.0
			- MINIMUM_ABYSSAL_INFLUENCE
		),
		0.0,
		1.0
	)

	return clampf(
		depth_factor * 0.25
			+ darkness_factor * 0.20
			+ trench_factor * 0.35
			+ abyssal_factor * 0.20,
		0.0,
		1.0
	)


static func get_candidate_position(
	fauna_seed: int,
	region_coordinate: Vector2i
) -> Vector2:
	var center: Vector2 = Vector2(
		(float(region_coordinate.x) + 0.5)
			* REGION_SIZE,
		(float(region_coordinate.y) + 0.5)
			* REGION_SIZE
	)

	var x_seed: int = StableSeed.derive_spatial_seed(
		fauna_seed,
		REGION_JITTER_X_CHANNEL,
		region_coordinate
	)

	var z_seed: int = StableSeed.derive_spatial_seed(
		fauna_seed,
		REGION_JITTER_Z_CHANNEL,
		region_coordinate
	)

	var x_offset: float = (
		StableSeed.seed_to_unit_float(x_seed)
			* 2.0
			- 1.0
	) * REGION_SIZE * 0.34

	var z_offset: float = (
		StableSeed.seed_to_unit_float(z_seed)
			* 2.0
			- 1.0
	) * REGION_SIZE * 0.34

	return center + Vector2(
		x_offset,
		z_offset
	)


static func get_stable_id(
	fauna_seed: int,
	region_coordinate: Vector2i
) -> int:
	return StableSeed.derive_spatial_seed(
		fauna_seed,
		IDENTITY_CHANNEL,
		region_coordinate
	)
