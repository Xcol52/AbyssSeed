extends Node

const EPSILON: float = 0.0001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_test_arbitrary_world_position()
	_test_half_open_chunk_ownership()
	_test_negative_coordinates()

	print("")
	print(
		"Session 9 Stage 9B world queries: "
		+ "%d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_arbitrary_world_position() -> void:
	var sampler := _create_sampler()

	var terrain_data := _create_test_terrain(
		Vector2i.ZERO,
		Vector2.ZERO
	)

	var world_xz := Vector2(
		6.25,
		13.75
	)

	var first := sampler.sample_world(
		terrain_data,
		world_xz
	)

	var second := sampler.sample_world(
		terrain_data,
		world_xz
	)

	_expect(
		first != null,
		"An arbitrary point inside a chunk can be sampled."
	)

	if first == null or second == null:
		return

	_expect(
		first.world_xz == world_xz,
		"The sample preserves the exact requested position."
	)

	_expect(
		is_finite(first.seabed_elevation),
		"Interpolated seabed elevation is finite."
	)

	_expect(
		first.depth_below_surface > 0.0,
		"The interpolated seabed remains submerged."
	)

	_expect(
		first.slope_degrees > 0.0,
		"The test terrain produces a world-query slope."
	)

	_expect(
		first.roughness_meters >= 0.0,
		"World-query roughness is non-negative."
	)

	var substrate_total := (
		first.rock_substrate
		+ first.sand_substrate
		+ first.soft_sediment_substrate
	)

	_expect(
		absf(substrate_total - 1.0) <= EPSILON,
		"World-query substrate weights sum to one."
	)

	_expect(
		first.seabed_elevation
			== second.seabed_elevation
			and first.temperature_celsius
			== second.temperature_celsius
			and first.nutrient_potential
			== second.nutrient_potential,
		"Repeated world-position sampling is deterministic."
	)


func _test_half_open_chunk_ownership() -> void:
	var sampler := _create_sampler()

	var west := _create_test_terrain(
		Vector2i.ZERO,
		Vector2.ZERO
	)

	var east := _create_test_terrain(
		Vector2i(1, 0),
		Vector2(20.0, 0.0)
	)

	var shared_position := Vector2(
		20.0,
		10.0
	)

	var west_result := sampler.sample_world(
		west,
		shared_position
	)

	var east_result := sampler.sample_world(
		east,
		shared_position
	)

	_expect(
		west_result == null,
		"A chunk rejects its positive maximum boundary."
	)

	_expect(
		east_result != null,
		"The adjacent positive-axis chunk owns the boundary."
	)

	if east_result != null:
		_expect(
			east_result.world_xz == shared_position,
			"The canonical boundary query preserves position."
		)


func _test_negative_coordinates() -> void:
	var sampler := _create_sampler()

	var terrain_data := _create_test_terrain(
		Vector2i(-1, -1),
		Vector2(-20.0, -20.0)
	)

	var world_xz := Vector2(
		-12.5,
		-3.25
	)

	var sample := sampler.sample_world(
		terrain_data,
		world_xz
	)

	_expect(
		sample != null,
		"Environment queries support negative coordinates."
	)

	if sample != null:
		_expect(
			sample.world_xz == world_xz,
			"Negative world position is preserved exactly."
		)


func _create_sampler() -> EnvironmentSampler:
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


func _create_test_terrain(
	chunk_coordinate: Vector2i,
	world_origin: Vector2
) -> TerrainChunkData:
	var cells_per_axis := 2
	var samples_per_axis := 3
	var cell_size := 10.0
	var sample_count := 9

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
				-120.0
				+ world_x * 0.08
				+ world_z * 0.04
				+ float(local_x * local_z) * 0.75
			)

			heights[index] = elevation

			geology.macro_elevation[index] = (
				elevation - 1.5
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
				0.75
			)

			geology.deep_province_influence[index] = 0.25

			geology.abyssal_province_influence[index] = (
				0.0
			)

			geology.province_transition_influence[index] = (
				0.35
			)

	return TerrainChunkData.new(
		chunk_coordinate,
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
