class_name FaunaPopulationSampler
extends RefCounted

const EPSILON: float = 0.000001
const SURFACE_CLEARANCE: float = 1.0

var _fauna_seed: int
var _catalog: FaunaCatalogSnapshot
var _validation_error: String = ""

## species_id -> FastNoiseLite
var _patch_noises: Dictionary = {}


func _init(
	fauna_seed: int,
	catalog: FaunaCatalogSnapshot
) -> void:
	assert(catalog != null)

	_fauna_seed = fauna_seed
	_catalog = catalog
	_validation_error = catalog.get_validation_error()

	if not _validation_error.is_empty():
		return

	for species in catalog.species:
		var noise := FastNoiseLite.new()

		noise.seed = StableSeed.derive_channel_seed(
			_fauna_seed,
			FaunaChannels.for_species(
				FaunaChannels.PATCH_NOISE_BASE,
				species.species_id
			)
		)

		noise.frequency = 1.0 / species.patch_size
		noise.noise_type = (
			FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		)
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 3
		noise.fractal_gain = 0.5
		noise.fractal_lacunarity = 2.0

		_patch_noises[species.species_id] = noise


func get_validation_error() -> String:
	return _validation_error


func generate_chunk(
	terrain_data: TerrainChunkData,
	environment_sampler: EnvironmentSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> FaunaChunkData:
	if not _validation_error.is_empty():
		return null

	if (
		terrain_data == null
		or terrain_data.geology_data == null
		or environment_sampler == null
		or biome_sampler == null
	):
		return null

	var world_origin := terrain_data.geology_data.world_origin

	var chunk_size := (
		float(terrain_data.cells_per_axis)
		* terrain_data.cell_size
	)

	if chunk_size <= 0.0:
		return null

	var world_maximum := (
		world_origin
		+ Vector2.ONE * chunk_size
	)

	var output: Array[FaunaPopulationDescriptor] = []

	for species in _catalog.species:
		_generate_species(
			species,
			terrain_data,
			environment_sampler,
			biome_sampler,
			world_origin,
			world_maximum,
			output
		)

	output.sort_custom(_descriptor_less_than)

	return FaunaChunkData.new(
		terrain_data.chunk_coordinate,
		world_origin,
		chunk_size,
		output
	)


func _generate_species(
	species: FaunaSpeciesSnapshot,
	terrain_data: TerrainChunkData,
	environment_sampler: EnvironmentSampler,
	biome_sampler: BiomeSuitabilitySampler,
	world_minimum: Vector2,
	world_maximum: Vector2,
	output: Array[FaunaPopulationDescriptor]
) -> void:
	var spacing := species.candidate_spacing

	var minimum_x := floori(world_minimum.x / spacing) - 1
	var minimum_z := floori(world_minimum.y / spacing) - 1
	var maximum_x := floori(world_maximum.x / spacing) + 1
	var maximum_z := floori(world_maximum.y / spacing) + 1

	for cell_z in range(minimum_z, maximum_z + 1):
		for cell_x in range(minimum_x, maximum_x + 1):
			var candidate_cell := Vector2i(
				cell_x,
				cell_z
			)

			var world_xz := _candidate_position(
				species,
				candidate_cell
			)

			## Half-open ownership.
			if (
				world_xz.x < world_minimum.x
				or world_xz.y < world_minimum.y
				or world_xz.x >= world_maximum.x
				or world_xz.y >= world_maximum.y
			):
				continue

			var environment := (
				environment_sampler.sample_world(
					terrain_data,
					world_xz
				)
			)

			if environment == null:
				continue

			var biome_result := biome_sampler.evaluate(
				environment
			)

			if biome_result == null:
				continue

			var suitability := _evaluate_species(
				species.species_id,
				environment,
				biome_result
			)

			if suitability < species.minimum_suitability:
				continue

			var patch_strength := _sample_patch(
				species,
				world_xz
			)

			var patch_factor := lerpf(
				1.0,
				patch_strength,
				species.patchiness
			)

			var carrying_capacity := clampf(
				suitability * patch_factor,
				0.0,
				1.0
			)

			var placement_probability := clampf(
				species.base_spawn_probability
				* _smoothstep(
					species.minimum_suitability,
					1.0,
					suitability
				)
				* patch_factor,
				0.0,
				1.0
			)

			var spawn_roll := _unit_value(
				FaunaChannels.for_species(
					FaunaChannels.SPAWN_ROLL_BASE,
					species.species_id
				),
				candidate_cell
			)

			if spawn_roll >= placement_probability:
				continue

			var available_water_height := maxf(
				environment.depth_below_surface
					- SURFACE_CLEARANCE,
				0.0
			)

			var maximum_altitude := minf(
				species.maximum_altitude,
				available_water_height
			)

			if maximum_altitude < species.minimum_altitude:
				continue

			var altitude_roll := _unit_value(
				FaunaChannels.for_species(
					FaunaChannels.ALTITUDE_ROLL_BASE,
					species.species_id
				),
				candidate_cell
			)

			var altitude := lerpf(
				species.minimum_altitude,
				maximum_altitude,
				altitude_roll
			)

			var population_roll := _unit_value(
				FaunaChannels.for_species(
					FaunaChannels.POPULATION_ROLL_BASE,
					species.species_id
				),
				candidate_cell
			)

			var population_range := (
				species.maximum_population
				- species.minimum_population
			)

			var population_factor := clampf(
				carrying_capacity
				* lerpf(0.78, 1.0, population_roll),
				0.0,
				1.0
			)

			var population_count := (
				species.minimum_population
				+ roundi(
					float(population_range)
					* population_factor
				)
			)

			population_count = clampi(
				population_count,
				species.minimum_population,
				species.maximum_population
			)

			var stable_id := (
				StableSeed.derive_spatial_seed(
					_fauna_seed,
					FaunaChannels.for_species(
						FaunaChannels.IDENTITY_BASE,
						species.species_id
					),
					candidate_cell
				)
			)

			var behavior_seed := (
				StableSeed.derive_spatial_seed(
					_fauna_seed,
					FaunaChannels.for_species(
						FaunaChannels.BEHAVIOR_BASE,
						species.species_id
					),
					candidate_cell
				)
			)

			var heading_roll := _unit_value(
				FaunaChannels.for_species(
					FaunaChannels.HEADING_ROLL_BASE,
					species.species_id
				),
				candidate_cell
			)

			var descriptor := FaunaPopulationDescriptor.new(
				stable_id,
				species.species_id,
				candidate_cell,
				terrain_data.chunk_coordinate,
				Vector3(
					world_xz.x,
					environment.seabed_elevation
						+ altitude,
					world_xz.y
				),
				population_count,
				species.minimum_altitude,
				maximum_altitude,
				species.home_radius,
				suitability,
				carrying_capacity,
				patch_strength,
				heading_roll * TAU,
				behavior_seed,
				species.ownership_mode
			)

			output.append(descriptor)


func _evaluate_species(
	species_id: int,
	environment: EnvironmentSample,
	biome_result: BiomeSuitabilityResult
) -> float:
	var depth_density := _depth_density(
		environment.depth_below_surface
	)

	if depth_density <= 0.0:
		return 0.0

	var maximum_biome_weight := 0.0

	for biome_id in range(BiomeIds.COUNT):
		maximum_biome_weight = maxf(
			maximum_biome_weight,
			biome_result.get_weight(biome_id)
		)

	var biome_support := clampf(
		0.70 + maximum_biome_weight * 0.30,
		0.0,
		1.0
	)

	match species_id:
		FaunaIds.SHELF_BAITFISH:
			var depth := _band(
				environment.depth_below_surface,
				5.0,
				18.0,
				320.0,
				760.0
			)

			var current := _band(
				environment.current_exposure,
				0.0,
				0.08,
				0.72,
				1.0
			)

			var biological := clampf(
				environment.biological_potential,
				0.0,
				1.0
			)

			var nutrient := clampf(
				environment.nutrient_potential,
				0.0,
				1.0
			)

			return _geometric_mean([
				depth,
				depth_density,
				current,
				lerpf(0.20, 1.0, biological),
				lerpf(0.35, 1.0, nutrient),
				biome_support,
			])

		FaunaIds.KELP_GRAZER:
			var depth := _band(
				environment.depth_below_surface,
				3.0,
				10.0,
				190.0,
				310.0
			)

			var light := _band(
				environment.light_availability,
				0.01,
				0.05,
				1.0,
				1.0
			)

			var substrate := clampf(
				maxf(
					environment.rock_substrate,
					environment.sand_substrate * 0.55
				),
				0.0,
				1.0
			)

			return _geometric_mean([
				depth,
				depth_density,
				light,
				lerpf(0.22, 1.0, substrate),
				lerpf(
					0.20,
					1.0,
					environment.biological_potential
				),
				biome_support,
			])
			
		FaunaIds.GIANT_SQUID:
			# Large regional fauna must never be independently
			# generated by ordinary terrain chunks.
			return 0.0

		FaunaIds.REEF_HUNTER:
			var depth := _band(
				environment.depth_below_surface,
				12.0,
				35.0,
				520.0,
				980.0
			)

			var terrain_support := clampf(
				maxf(
					environment.rock_substrate,
					environment.roughness_strength
				),
				0.0,
				1.0
			)

			## Static prey support, not instantiated runtime prey.
			var prey_support := clampf(
				maxf(
					environment.biological_potential,
					environment.nutrient_potential * 0.72
				),
				0.0,
				1.0
			)

			return _geometric_mean([
				depth,
				depth_density,
				lerpf(0.20, 1.0, terrain_support),
				lerpf(0.12, 1.0, prey_support),
				biome_support,
			])

		_:
			return 0.0


static func _depth_density(depth_below_surface: float) -> float:
	if depth_below_surface < 0.0:
		return 0.0

	if depth_below_surface <= 20.0:
		return 1.0

	if depth_below_surface <= 150.0:
		return 0.55

	if depth_below_surface <= 250.0:
		return 0.18

	return 0.0


func _candidate_position(
	species: FaunaSpeciesSnapshot,
	cell: Vector2i
) -> Vector2:
	var spacing := species.candidate_spacing

	var center := Vector2(
		(float(cell.x) + 0.5) * spacing,
		(float(cell.y) + 0.5) * spacing
	)

	var jitter_x := (
		_unit_value(
			FaunaChannels.for_species(
				FaunaChannels.CANDIDATE_JITTER_X_BASE,
				species.species_id
			),
			cell
		) * 2.0 - 1.0
	)

	var jitter_z := (
		_unit_value(
			FaunaChannels.for_species(
				FaunaChannels.CANDIDATE_JITTER_Z_BASE,
				species.species_id
			),
			cell
		) * 2.0 - 1.0
	)

	var maximum_jitter := (
		spacing
		* species.jitter_fraction
		* 0.5
	)

	return center + Vector2(
		jitter_x * maximum_jitter,
		jitter_z * maximum_jitter
	)


func _sample_patch(
	species: FaunaSpeciesSnapshot,
	world_xz: Vector2
) -> float:
	var noise := (
		_patch_noises.get(species.species_id)
		as FastNoiseLite
	)

	if noise == null:
		return 1.0

	var value := clampf(
		noise.get_noise_2d(
			world_xz.x,
			world_xz.y
		) * 0.5 + 0.5,
		0.0,
		1.0
	)

	return _smoothstep(0.25, 0.78, value)


func _unit_value(
	channel_id: int,
	coordinate: Vector2i
) -> float:
	return StableSeed.seed_to_unit_float(
		StableSeed.derive_spatial_seed(
			_fauna_seed,
			channel_id,
			coordinate
		)
	)


static func _band(
	value: float,
	minimum: float,
	ideal_minimum: float,
	ideal_maximum: float,
	maximum: float
) -> float:
	if value < minimum or value > maximum:
		return 0.0

	if value < ideal_minimum:
		return _smoothstep(
			minimum,
			ideal_minimum,
			value
		)

	if value <= ideal_maximum:
		return 1.0

	return (
		1.0
		- _smoothstep(
			ideal_maximum,
			maximum,
			value
		)
	)


static func _geometric_mean(
	values: Array
) -> float:
	if values.is_empty():
		return 0.0

	var log_sum := 0.0

	for value in values:
		var number := float(value)

		if number <= EPSILON:
			return 0.0

		log_sum += log(number)

	return clampf(
		exp(log_sum / float(values.size())),
		0.0,
		1.0
	)


static func _smoothstep(
	edge_zero: float,
	edge_one: float,
	value: float
) -> float:
	if is_equal_approx(edge_zero, edge_one):
		return 1.0

	var factor := clampf(
		(value - edge_zero)
			/ (edge_one - edge_zero),
		0.0,
		1.0
	)

	return (
		factor
		* factor
		* (3.0 - 2.0 * factor)
	)


static func _descriptor_less_than(
	left: FaunaPopulationDescriptor,
	right: FaunaPopulationDescriptor
) -> bool:
	if left.species_id != right.species_id:
		return left.species_id < right.species_id

	if left.candidate_cell.y != right.candidate_cell.y:
		return (
			left.candidate_cell.y
			< right.candidate_cell.y
		)

	if left.candidate_cell.x != right.candidate_cell.x:
		return (
			left.candidate_cell.x
			< right.candidate_cell.x
		)

	return left.stable_id < right.stable_id
