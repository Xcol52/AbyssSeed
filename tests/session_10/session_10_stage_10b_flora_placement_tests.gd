extends Node

const EPSILON: float = 0.0001

const TEST_CELLS_PER_AXIS: int = 16
const TEST_CELL_SIZE: float = 32.0
const TEST_CHUNK_SIZE: float = (
	float(TEST_CELLS_PER_AXIS)
	* TEST_CELL_SIZE
)

const TEST_SLOPE_X: float = 0.02
const TEST_SLOPE_Z: float = -0.01

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	var flora_catalog := (
		FloraCatalogSnapshot.create_default()
	)

	var flora_error: String = (
		flora_catalog.get_validation_error()
	)

	_expect(
		flora_error.is_empty(),
		"Default flora catalog validates."
	)

	if not flora_error.is_empty():
		printerr(flora_error)
		get_tree().quit(1)
		return

	var biome_catalog := (
		BiomeCatalogSnapshot.create_default()
	)

	var biome_sampler := BiomeSuitabilitySampler.new(
		biome_catalog
	)

	_expect(
		biome_sampler.get_validation_error().is_empty(),
		"Biome sampler validates."
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

	var environment_sampler := (
		_create_environment_sampler()
	)

	_test_flat_surface_normals(
		flora_sampler,
		environment_sampler,
		biome_sampler
	)

	_test_sloped_surface_normals(
		flora_sampler,
		environment_sampler,
		biome_sampler
	)

	_test_stable_ordering(
		flora_seed,
		flora_catalog,
		environment_sampler,
		biome_sampler
	)

	_test_negative_coordinate_chunk(
		flora_sampler,
		environment_sampler,
		biome_sampler
	)

	print("")
	print(
		"Session 10 Stage 10B flora placement tests: "
		+ "%d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_flat_surface_normals(
	flora_sampler: FloraPlacementSampler,
	environment_sampler: EnvironmentSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var terrain_data := _create_sandy_terrain(
		Vector2i.ZERO,
		Vector2.ZERO,
		0.0,
		0.0
	)

	var flora_data := flora_sampler.generate_chunk(
		terrain_data,
		environment_sampler,
		biome_sampler
	)

	_expect(
		flora_data != null,
		"Flat terrain produces flora chunk data."
	)

	if flora_data == null:
		return

	_expect(
		flora_data.get_candidate_count() > 0,
		"Flat suitable terrain produces candidates."
	)

	var normals_valid := true

	for candidate in flora_data.candidates:
		if (
			not candidate.surface_normal.is_equal_approx(
				Vector3.UP
			)
			or not candidate.get_validation_error().is_empty()
		):
			normals_valid = false
			break

	_expect(
		normals_valid,
		"Flat terrain produces upward unit normals."
	)

	_expect(
		flora_data.get_validation_error().is_empty(),
		"Flat flora chunk satisfies the data contract."
	)


func _test_sloped_surface_normals(
	flora_sampler: FloraPlacementSampler,
	environment_sampler: EnvironmentSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var terrain_data := _create_sandy_terrain(
		Vector2i.ZERO,
		Vector2.ZERO,
		TEST_SLOPE_X,
		TEST_SLOPE_Z
	)

	var flora_data := flora_sampler.generate_chunk(
		terrain_data,
		environment_sampler,
		biome_sampler
	)

	_expect(
		flora_data != null,
		"Sloped terrain produces flora chunk data."
	)

	if flora_data == null:
		return

	_expect(
		flora_data.get_candidate_count() > 0,
		"Gently sloped suitable terrain produces candidates."
	)

	var expected_normal := Vector3(
		-TEST_SLOPE_X,
		1.0,
		-TEST_SLOPE_Z
	).normalized()

	var normals_match := true

	for candidate in flora_data.candidates:
		if (
			candidate.surface_normal.dot(
				expected_normal
			) < 0.9999
		):
			normals_match = false
			break

	_expect(
		normals_match,
		"Candidate normals match the bilinear height slope."
	)

	_expect(
		flora_data.get_validation_error().is_empty(),
		"Sloped flora chunk satisfies the data contract."
	)


func _test_stable_ordering(
	flora_seed: int,
	flora_catalog: FloraCatalogSnapshot,
	environment_sampler: EnvironmentSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var reversed_species: Array[FloraSpeciesSnapshot] = (
		flora_catalog.species.duplicate()
	)

	reversed_species.reverse()

	var reversed_catalog := FloraCatalogSnapshot.new(
		reversed_species
	)

	_expect(
		reversed_catalog.get_validation_error().is_empty(),
		"Reordered flora catalog remains valid."
	)

	var normal_sampler := FloraPlacementSampler.new(
		flora_seed,
		flora_catalog
	)

	var reversed_sampler := FloraPlacementSampler.new(
		flora_seed,
		reversed_catalog
	)

	var terrain_data := _create_sandy_terrain(
		Vector2i.ZERO,
		Vector2.ZERO,
		0.0,
		0.0
	)

	var normal_result := normal_sampler.generate_chunk(
		terrain_data,
		environment_sampler,
		biome_sampler
	)

	var reversed_result := reversed_sampler.generate_chunk(
		terrain_data,
		environment_sampler,
		biome_sampler
	)

	_expect(
		normal_result != null
			and reversed_result != null,
		"Both catalog orders produce flora data."
	)

	if normal_result == null or reversed_result == null:
		return

	_expect(
		normal_result.get_candidate_count()
			== reversed_result.get_candidate_count(),
		"Catalog order does not change candidate count."
	)

	if (
		normal_result.get_candidate_count()
		!= reversed_result.get_candidate_count()
	):
		return

	var results_equal := true

	for index in range(normal_result.candidates.size()):
		var normal_candidate := (
			normal_result.candidates[index]
		)

		var reversed_candidate := (
			reversed_result.candidates[index]
		)

		if (
			normal_candidate.stable_id
				!= reversed_candidate.stable_id
			or normal_candidate.species_id
				!= reversed_candidate.species_id
			or normal_candidate.candidate_cell
				!= reversed_candidate.candidate_cell
			or normal_candidate.world_position
				!= reversed_candidate.world_position
			or normal_candidate.surface_normal
				!= reversed_candidate.surface_normal
			or normal_candidate.yaw_radians
				!= reversed_candidate.yaw_radians
			or normal_candidate.uniform_scale
				!= reversed_candidate.uniform_scale
		):
			results_equal = false
			break

	_expect(
		results_equal,
		"Candidate order is independent of catalog order."
	)

	_expect(
		_is_stably_ordered(normal_result),
		"Candidates follow the stable ordering contract."
	)


func _test_negative_coordinate_chunk(
	flora_sampler: FloraPlacementSampler,
	environment_sampler: EnvironmentSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> void:
	var chunk_coordinate := Vector2i(-1, -1)
	var world_origin := Vector2(
		-TEST_CHUNK_SIZE,
		-TEST_CHUNK_SIZE
	)

	var terrain_data := _create_sandy_terrain(
		chunk_coordinate,
		world_origin,
		TEST_SLOPE_X,
		TEST_SLOPE_Z
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
		"Negative-coordinate terrain produces flora data."
	)

	if first == null or second == null:
		return

	_expect(
		first.get_candidate_count() > 0,
		"Suitable negative-coordinate terrain has candidates."
	)

	var deterministic := (
		first.get_candidate_count()
		== second.get_candidate_count()
	)

	if deterministic:
		for index in range(first.candidates.size()):
			var left := first.candidates[index]
			var right := second.candidates[index]

			if (
				left.stable_id != right.stable_id
				or left.world_position
					!= right.world_position
				or left.surface_normal
					!= right.surface_normal
			):
				deterministic = false
				break

	_expect(
		deterministic,
		"Negative-coordinate normals and identities are deterministic."
	)

	_expect(
		first.get_validation_error().is_empty(),
		"Negative-coordinate flora chunk satisfies ownership."
	)


func _is_stably_ordered(
	data: FloraChunkData
) -> bool:
	for index in range(1, data.candidates.size()):
		var previous := data.candidates[index - 1]
		var current := data.candidates[index]

		if current.species_id < previous.species_id:
			return false

		if current.species_id > previous.species_id:
			continue

		if (
			current.candidate_cell.y
			< previous.candidate_cell.y
		):
			return false

		if (
			current.candidate_cell.y
			> previous.candidate_cell.y
		):
			continue

		if (
			current.candidate_cell.x
			< previous.candidate_cell.x
		):
			return false

		if (
			current.candidate_cell.x
			> previous.candidate_cell.x
		):
			continue

		if current.stable_id < previous.stable_id:
			return false

	return true


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


func _create_sandy_terrain(
	chunk_coordinate: Vector2i,
	world_origin: Vector2,
	slope_x: float,
	slope_z: float
) -> TerrainChunkData:
	var samples_per_axis := TEST_CELLS_PER_AXIS + 1

	var sample_count := (
		samples_per_axis
		* samples_per_axis
	)

	var geology := GeologyChunkData.new(
		chunk_coordinate,
		TEST_CELLS_PER_AXIS,
		TEST_CELL_SIZE,
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
				+ float(local_x) * TEST_CELL_SIZE
			)

			var world_z := (
				world_origin.y
				+ float(local_z) * TEST_CELL_SIZE
			)

			var elevation := (
				-60.0
				+ world_x * slope_x
				+ world_z * slope_z
			)

			heights[index] = elevation
			geology.macro_elevation[index] = elevation

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
		TEST_CELLS_PER_AXIS,
		TEST_CELL_SIZE,
		heights,
		geology
	)


func _expect(
	condition: bool,
	description: String
) -> void:
	if condition:
		_passed += 1
		return

	_failed += 1
	printerr("FAILED: %s" % description)
