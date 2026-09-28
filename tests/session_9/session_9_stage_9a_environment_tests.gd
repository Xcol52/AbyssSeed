extends Node

const EPSILON: float = 0.0001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_test_environment_sample()
	_test_edge_rejection()

	print("")
	print(
		"Session 9 Stage 9A environment tests: "
		+ "%d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_environment_sample() -> void:
	var terrain_data := _create_test_terrain()

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

	var sampler := EnvironmentSampler.new(snapshot)

	var first := sampler.sample_interior(
		terrain_data,
		1,
		1
	)

	var second := sampler.sample_interior(
		terrain_data,
		1,
		1
	)

	_expect(
		first != null,
		"Interior terrain produces an environment sample."
	)

	if first == null or second == null:
		return

	_expect(
		first.world_xz == Vector2(10.0, 10.0),
		"Environment sample preserves world position."
	)

	_expect(
		first.depth_below_surface > 0.0,
		"Submerged terrain has positive water depth."
	)

	_expect(
		first.pressure_atmospheres > 1.0,
		"Underwater pressure exceeds one atmosphere."
	)

	_expect(
		first.light_availability >= 0.0
			and first.light_availability <= 1.0,
		"Light availability is normalized."
	)

	_expect(
		first.nutrient_potential >= 0.0
			and first.nutrient_potential <= 1.0,
		"Nutrient potential is normalized."
	)

	_expect(
		first.current_exposure >= 0.0
			and first.current_exposure <= 1.0,
		"Current exposure is normalized."
	)

	_expect(
		first.slope_degrees > 0.0,
		"The test surface produces a nonzero slope."
	)

	_expect(
		first.roughness_meters > 0.0,
		"The center disturbance produces roughness."
	)

	var substrate_total := (
		first.rock_substrate
		+ first.sand_substrate
		+ first.soft_sediment_substrate
	)

	_expect(
		absf(substrate_total - 1.0) <= EPSILON,
		"Substrate weights sum to one."
	)

	_expect(
		first.biological_potential >= 0.0
			and first.biological_potential <= 1.0,
		"Biological potential is normalized."
	)

	_expect(
		first.temperature_celsius
			== second.temperature_celsius
			and first.current_exposure
			== second.current_exposure
			and first.nutrient_potential
			== second.nutrient_potential,
		"Repeated environment sampling is deterministic."
	)


func _test_edge_rejection() -> void:
	var terrain_data := _create_test_terrain()
	var settings := EnvironmentSettings.new()

	var snapshot := EnvironmentGenerationSnapshot.new(
		12345,
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

	var sampler := EnvironmentSampler.new(snapshot)

	_expect(
		sampler.sample_interior(
			terrain_data,
			0,
			1
		) == null,
		"Chunk-edge sampling requires a neighboring halo."
	)


func _create_test_terrain() -> TerrainChunkData:
	var cells_per_axis := 2
	var samples_per_axis := 3
	var cell_size := 10.0
	var sample_count := 9

	var geology := GeologyChunkData.new(
		Vector2i.ZERO,
		cells_per_axis,
		cell_size,
		Vector2.ZERO
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

			var elevation := (
				-100.0
				+ float(local_x) * 2.0
				+ float(local_z)
			)

			if local_x == 1 and local_z == 1:
				elevation += 4.0

			heights[index] = elevation

			geology.macro_elevation[index] = (
				elevation - 2.0
			)

			geology.volcanic_potential[index] = 0.20
			geology.sediment_potential[index] = 0.65
			geology.ridge_potential[index] = 0.10
			geology.trench_potential[index] = 0.0

			geology.trench_tiers[index] = (
				GeologyChunkData.TRENCH_TIER_NONE
			)

			geology.compression_strength[index] = 0.10
			geology.extension_strength[index] = 0.05
			geology.shear_strength[index] = 0.08
			geology.convergent_potential[index] = 0.12

			geology.shallow_province_influence[index] = (
				1.0
			)

			geology.deep_province_influence[index] = 0.0

			geology.abyssal_province_influence[index] = (
				0.0
			)

			geology.province_transition_influence[index] = (
				0.0
			)

	return TerrainChunkData.new(
		Vector2i.ZERO,
		cells_per_axis,
		cell_size,
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
	push_error("FAILED: %s" % description)
