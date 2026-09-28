extends Node

const EPSILON: float = 0.0001
const TEST_CELLS_PER_AXIS: int = 16
const TEST_CELL_SIZE: float = 32.0
const TEST_CHUNK_SIZE: float = 512.0

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	var flora_catalog := FloraCatalogSnapshot.create_default()
	var flora_error := flora_catalog.get_validation_error()

	_expect(
		flora_error.is_empty(),
		"Default flora catalog validates."
	)

	if not flora_error.is_empty():
		push_error(flora_error)
		get_tree().quit(1)
		return

	var biome_catalog := (
		BiomeCatalogSnapshot.create_default()
	)

	var biome_sampler := BiomeSuitabilitySampler.new(
		biome_catalog
	)

	var flora_seed := (
		StableSeed.derive_subsystem_seed(
			1337,
			9,
			WorldSubsystemIds.FLORA
		)
	)

	var flora_sampler := FloraPlacementSampler.new(
		flora_seed,
		flora_catalog
	)

	_expect(
		flora_sampler.get_validation_error().is_empty(),
		"Flora placement sampler validates."
	)

	_test_species_suitability(
		flora_sampler,
		biome_sampler
	)

	_test_deterministic_chunk_placement(
		flora_sampler,
		biome_sampler
	)

	_test_neighbor_chunk_ownership(
		flora_sampler,
		biome_sampler
	)

	print("")
	print(
		"Session 9 Stage 9E flora tests: "
		+ "%d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_species_suitability(
	flora_sampler: FloraPlacementSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var kelp_environment := _environment_sample(
		60.0,
		0.48,
		0.72,
		0.45,
		0.82,
		12.0,
		0.35,
		0.62,
		0.22,
		0.16,
		0.05,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.85,
		0.15,
		0.0,
		0.20,
		0.66,
		0.24,
		0.10,
		0.68
	)

	var kelp_biomes := biome_sampler.evaluate(
		kelp_environment
	)

	var kelp_suitability := flora_sampler.evaluate_species(
		FloraIds.GIANT_KELP,
		kelp_environment,
		kelp_biomes
	)

	_expect(
		kelp_suitability > 0.20,
		"Sunlit rocky shelf supports giant kelp."
	)

	var vent_environment := _environment_sample(
		2500.0,
		0.0,
		0.86,
		0.55,
		0.12,
		18.0,
		0.55,
		0.88,
		0.08,
		0.92,
		0.82,
		0.0,
		GeologyChunkData.TRENCH_TIER_NONE,
		0.0,
		0.50,
		0.50,
		0.35,
		0.82,
		0.08,
		0.10,
		0.86
	)

	var vent_biomes := biome_sampler.evaluate(
		vent_environment
	)

	var vent_suitability := flora_sampler.evaluate_species(
		FloraIds.VENT_TUBE_WORMS,
		vent_environment,
		vent_biomes
	)

	_expect(
		vent_suitability > 0.30,
		"Deep volcanic habitat supports vent tube worms."
	)

	var incompatible_kelp := flora_sampler.evaluate_species(
		FloraIds.GIANT_KELP,
		vent_environment,
		vent_biomes
	)

	_expect(
		incompatible_kelp <= EPSILON,
		"Lightless deep habitat rejects giant kelp."
	)

	var abyssal_environment := _environment_sample(
		3000.0, # Depth
		0.0,    # Light
		0.52,   # Nutrients
		0.38,   # Current
		0.90,   # Stability
		2.0,    # Slope
		0.08,   # Roughness strength
		0.10,   # Rock substrate
		0.15,   # Sand substrate
		0.75,   # Soft-sediment substrate
		0.0,    # Volcanic potential
		0.0,    # Trench potential
		GeologyChunkData.TRENCH_TIER_NONE,
		0.0,    # Shallow province
		0.10,   # Deep province
		0.90,   # Abyssal province
		0.12,   # Province transition
		0.02,   # Ridge potential
		0.82,   # Sediment potential
		0.04,   # Extension strength
		0.32    # Biological potential
	)
	var abyssal_biomes := biome_sampler.evaluate(
		abyssal_environment
	)

	var abyssal_suitability := (
		flora_sampler.evaluate_species(
			FloraIds.ABYSSAL_COLONY,
			abyssal_environment,
			abyssal_biomes
		)
	)

	_expect(
		abyssal_suitability > 0.20,
		"Abyssal sediment habitat supports abyssal colonies."
	)


func _test_deterministic_chunk_placement(
	flora_sampler: FloraPlacementSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var environment_sampler := _create_environment_sampler()

	var terrain_data := _create_shallow_sandy_terrain(
		Vector2i.ZERO,
		Vector2.ZERO
	)

	var first := flora_sampler.generate_chunk(
		terrain_data,
		environment_sampler,
		biome_sampler
	)

	var second := flora_sampler.generate_chunk(
		terrain_data,
		environment_sampler,
		biome_sampler
	)

	_expect(
		first != null and second != null,
		"Flora placement produces chunk data."
	)

	if first == null or second == null:
		return

	_expect(
		first.get_candidate_count() > 0,
		"Suitable terrain produces flora candidates."
	)

	_expect(
		first.get_species_count(
			FloraIds.SEAGRASS
		) > 0,
		"Shallow sandy terrain produces seagrass."
	)

	_expect(
		first.get_candidate_count()
			== second.get_candidate_count(),
		"Repeated placement produces the same count."
	)

	if (
		first.get_candidate_count()
		!= second.get_candidate_count()
	):
		return

	var all_equal := true

	for index in range(first.candidates.size()):
		var first_candidate := first.candidates[index]
		var second_candidate := second.candidates[index]

		if (
			first_candidate.stable_id
				!= second_candidate.stable_id
			or first_candidate.species_id
				!= second_candidate.species_id
			or first_candidate.world_position
				!= second_candidate.world_position
			or first_candidate.yaw_radians
				!= second_candidate.yaw_radians
			or first_candidate.uniform_scale
				!= second_candidate.uniform_scale
		):
			all_equal = false
			break

	_expect(
		all_equal,
		"Flora identities and transforms are deterministic."
	)


func _test_neighbor_chunk_ownership(
	flora_sampler: FloraPlacementSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var environment_sampler := _create_environment_sampler()

	var chunk_size := TEST_CHUNK_SIZE

	var west_terrain := _create_shallow_sandy_terrain(
		Vector2i.ZERO,
		Vector2.ZERO
	)

	var east_terrain := _create_shallow_sandy_terrain(
		Vector2i(1, 0),
		Vector2(chunk_size, 0.0)
	)

	## Generate east first to prove generation order is irrelevant.
	var east := flora_sampler.generate_chunk(
		east_terrain,
		environment_sampler,
		biome_sampler
	)

	var west := flora_sampler.generate_chunk(
		west_terrain,
		environment_sampler,
		biome_sampler
	)

	_expect(
		west != null and east != null,
		"Neighboring chunks produce flora data."
	)

	if west == null or east == null:
		return

	var west_ids: Dictionary = {}

	for candidate in west.candidates:
		west_ids[candidate.stable_id] = true

	var has_duplicate := false
	var ownership_valid := true

	for candidate in east.candidates:
		if west_ids.has(candidate.stable_id):
			has_duplicate = true

		if candidate.world_position.x < chunk_size:
			ownership_valid = false

	for candidate in west.candidates:
		if candidate.world_position.x >= chunk_size:
			ownership_valid = false

	_expect(
		not has_duplicate,
		"Neighboring chunks do not duplicate flora identities."
	)

	_expect(
		ownership_valid,
		"Flora candidates obey half-open chunk ownership."
	)


func _create_environment_sampler() -> EnvironmentSampler:
	var settings := EnvironmentSettings.new()

	var environment_seed := (
		StableSeed.derive_subsystem_seed(
			1337,
			9,
			WorldSubsystemIds.ENVIRONMENT
		)
	)

	var snapshot := EnvironmentGenerationSnapshot.new(
		environment_seed,
		0.0,
		settings.light_attenuation,
		settings.surface_temperature_celsius,
		settings.regional_temperature_variation,
		settings.regional_temperature_frequency,
		settings.depth_cooling_per_meter,
		settings.minimum_deep_temperature_celsius,
		settings.geothermal_temperature_increase,
		settings.current_primary_frequency,
		settings.current_detail_frequency,
		settings.nutrient_variation_frequency,
		settings.full_rock_slope_degrees,
		settings.full_roughness_meters
	)

	return EnvironmentSampler.new(snapshot)


func _create_shallow_sandy_terrain(
	chunk_coordinate: Vector2i,
	world_origin: Vector2
) -> TerrainChunkData:
	var cells_per_axis := TEST_CELLS_PER_AXIS
	var samples_per_axis := cells_per_axis + 1
	var cell_size := TEST_CELL_SIZE

	var sample_count := (
		samples_per_axis
		* samples_per_axis
	)

	var geology := GeologyChunkData.new(
		chunk_coordinate,
		cells_per_axis,
		cell_size,
		world_origin
	)

	geology.resize(sample_count)

	var heights := PackedFloat32Array()
	heights.resize(sample_count)

	for local_z in range(samples_per_axis):
		for local_x in range(samples_per_axis):
			var index := (
				local_z * samples_per_axis
				+ local_x
			)

			var world_x := (
				world_origin.x
				+ float(local_x) * cell_size
			)

			var world_z := (
				world_origin.y
				+ float(local_z) * cell_size
			)

			var elevation := (
				-60.0
				+ sin(world_x * 0.002) * 0.35
				+ cos(world_z * 0.002) * 0.35
			)

			heights[index] = elevation

			geology.macro_elevation[index] = (
				elevation - 0.25
			)

			geology.volcanic_potential[index] = 0.02
			geology.sediment_potential[index] = 0.90
			geology.ridge_potential[index] = 0.0
			geology.trench_potential[index] = 0.0

			geology.trench_tiers[index] = (
				GeologyChunkData.TRENCH_TIER_NONE
			)

			geology.compression_strength[index] = 0.02
			geology.extension_strength[index] = 0.02
			geology.shear_strength[index] = 0.02
			geology.convergent_potential[index] = 0.0

			geology.shallow_province_influence[index] = 1.0
			geology.deep_province_influence[index] = 0.0
			geology.abyssal_province_influence[index] = 0.0

			geology.province_transition_influence[index] = (
				0.05
			)

	return TerrainChunkData.new(
		chunk_coordinate,
		cells_per_axis,
		cell_size,
		heights,
		geology
	)


func _environment_sample(
	depth: float,
	light: float,
	nutrients: float,
	current: float,
	stability: float,
	slope_degrees: float,
	roughness_strength: float,
	rock: float,
	sand: float,
	soft_sediment: float,
	volcanic: float,
	trench: float,
	trench_tier: int,
	shallow: float,
	deep: float,
	abyssal: float,
	transition: float,
	ridge: float,
	sediment: float,
	extension: float,
	biological: float
) -> EnvironmentSample:
	var seabed_elevation := -depth

	return EnvironmentSample.new(
		Vector2(100.0, 200.0),
		seabed_elevation,
		depth,
		seabed_elevation,
		0.0,
		slope_degrees,
		clampf(slope_degrees / 35.0, 0.0, 1.0),
		roughness_strength * 30.0,
		roughness_strength,
		light,
		4.0,
		1.0 + depth / 10.06,
		nutrients,
		current,
		stability,
		volcanic,
		sediment,
		ridge,
		trench,
		trench_tier,
		0.10,
		extension,
		0.10,
		shallow,
		deep,
		abyssal,
		transition,
		rock,
		sand,
		soft_sediment,
		biological
	)


func _expect(
	condition: bool,
	description: String
) -> void:
	if condition:
		_passed += 1
		return

	_failed += 1
	push_error("FAILED: %s" % description)
