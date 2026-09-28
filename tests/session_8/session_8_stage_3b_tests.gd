extends Node

const EPSILON: float = 0.001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_test_profile_math()
	_test_integrated_convergent_channels()
	_test_determinism_and_borders()
	_test_final_depth_envelope()

	print("")
	print(
		"Session 8 Stage 3B: %d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_profile_math() -> void:
	var settings := GeologySettings.new()

	var relief := (
		ConvergentReliefSnapshot.from_settings(
			settings
		)
	)

	_expect(
		is_equal_approx(
			ConvergentProfile.calculate_influence(
				0.0,
				relief.influence_width
			),
			1.0
		),
		"Broad convergent influence is one on the axis."
	)

	_expect(
		ConvergentProfile.calculate_influence(
			relief.influence_width,
			relief.influence_width
		) <= EPSILON,
		"Broad convergent influence reaches zero at its edge."
	)

	var descending_influence := (
		ConvergentProfile.calculate_trench_influence(
			-400.0,
			relief.descending_trench_width,
			relief.overriding_trench_width
		)
	)

	var overriding_influence := (
		ConvergentProfile.calculate_trench_influence(
			400.0,
			relief.descending_trench_width,
			relief.overriding_trench_width
		)
	)

	_expect(
		descending_influence > overriding_influence,
		"The trench profile is broader on the descending side."
	)

	_expect(
		ConvergentProfile.calculate_uplift_influence(
			-100.0,
			relief.uplift_peak_offset,
			relief.uplift_width
		) <= EPSILON,
		"Uplift is zero on the descending side."
	)

	_expect(
		is_equal_approx(
			ConvergentProfile
				.calculate_uplift_influence(
					relief.uplift_peak_offset,
					relief.uplift_peak_offset,
					relief.uplift_width
				),
			1.0
		),
		"Uplift reaches one at its configured peak."
	)

	var low_affinity_site := GeologyPlateSite.new(
		Vector2i(-2, 3),
		-100,
		Vector2(-5000.0, 8000.0),
		Vector2(0.5, 0.0),
		0.10,
		0.0
	)

	var high_affinity_site := GeologyPlateSite.new(
		Vector2i(4, -1),
		200,
		Vector2(5000.0, -2000.0),
		Vector2(-0.5, 0.0),
		0.85,
		0.0
	)

	var first_descriptor := (
		ConvergentProfile.create_descriptor(
			98765,
			low_affinity_site,
			high_affinity_site,
			relief
		)
	)

	var reversed_descriptor := (
		ConvergentProfile.create_descriptor(
			98765,
			high_affinity_site,
			low_affinity_site,
			relief
		)
	)

	_expect(
		first_descriptor.overriding_plate_id
			== high_affinity_site.plate_id,
		"The more continental plate overrides when affinity differs."
	)

	_expect(
		first_descriptor.overriding_plate_id
			== reversed_descriptor.overriding_plate_id
		and first_descriptor.trench_tier
			== reversed_descriptor.trench_tier,
		"Convergent pair decisions are independent of argument order."
	)

	var extreme_target := (
		ConvergentProfile.calculate_target_depth(
			ConvergentProfile.TRENCH_TIER_EXTREME,
			relief,
			1.0
		)
	)

	_expect(
		extreme_target
			<= settings.maximum_seabed_depth,
		"Extreme target depth respects the global depth envelope."
	)

	var trench_contribution := (
		ConvergentProfile
			.calculate_trench_contribution(
				-300.0,
				1000.0,
				1.0
			)
	)

	_expect(
		absf(
			trench_contribution
			- -700.0
		) <= EPSILON,
		"Trench contribution targets total depth rather than "
		+ "blindly subtracting it."
	)


func _test_integrated_convergent_channels() -> void:
	var snapshot := _make_geology_snapshot()

	var region := GeologySampler.new(
		snapshot
	).generate_region(
		Vector2(-32768.0, -32768.0),
		128,
		512.0
	)

	_expect(
		region != null,
		"Stage 3B survey region generates."
	)

	if region == null:
		return

	var sample_count := region.macro_elevation.size()

	_expect(
		region.convergent_influence.size()
			== sample_count
		and region.convergent_potential.size()
			== sample_count
		and region.trench_influence.size()
			== sample_count
		and region.trench_target_depth.size()
			== sample_count
		and region.trench_elevation_contribution.size()
			== sample_count
		and region.overriding_uplift_potential.size()
			== sample_count
		and region
			.overriding_uplift_elevation_contribution
			.size()
			== sample_count,
		"All Stage 3B channels match the geology grid."
	)

	var found_broad_depression := false
	var found_axial_trench := false
	var found_overriding_uplift := false

	var values_valid := true
	var relationships_valid := true
	var depths_valid := true

	for index in range(sample_count):
		var boundary_class := int(
			region.boundary_classes[index]
		)

		var influence := (
			region.convergent_influence[index]
		)

		var potential := (
			region.convergent_potential[index]
		)

		var broad_contribution := (
			region
			.convergent_depression_elevation_contribution[
				index
			]
		)

		var trench_influence := (
			region.trench_influence[index]
		)

		var trench_potential := (
			region.trench_potential[index]
		)

		var trench_target := (
			region.trench_target_depth[index]
		)

		var trench_contribution := (
			region
			.trench_elevation_contribution[index]
		)

		var uplift_influence := (
			region
			.overriding_uplift_influence[index]
		)

		var uplift_potential := (
			region
			.overriding_uplift_potential[index]
		)

		var uplift_contribution := (
			region
			.overriding_uplift_elevation_contribution[
				index
			]
		)

		if broad_contribution < -EPSILON:
			found_broad_depression = true

		if trench_contribution < -EPSILON:
			found_axial_trench = true

		if uplift_contribution > EPSILON:
			found_overriding_uplift = true

		var normalized_values: Array[float] = [
			influence,
			potential,
			trench_influence,
			trench_potential,
			uplift_influence,
			uplift_potential
		]

		for value in normalized_values:
			if (
				not is_finite(value)
				or value < 0.0
				or value > 1.0
			):
				values_valid = false

		if (
			not is_finite(broad_contribution)
			or not is_finite(trench_target)
			or not is_finite(trench_contribution)
			or not is_finite(uplift_contribution)
			or broad_contribution > EPSILON
			or trench_contribution > EPSILON
			or uplift_contribution < -EPSILON
		):
			values_valid = false

		if (
			potential > EPSILON
			and boundary_class
			!= GeologyChunkData
				.BOUNDARY_CLASS_CONVERGENT
		):
			relationships_valid = false

		if (
			trench_potential > EPSILON
			and region.compression_strength[index]
			<= 0.0
		):
			relationships_valid = false

		if (
			uplift_contribution > EPSILON
			and region
				.sample_is_on_overriding_plate[index]
			== 0
		):
			relationships_valid = false

		if (
			trench_target
			> snapshot.maximum_seabed_depth
			+ EPSILON
		):
			depths_valid = false

		if (
			region.macro_elevation[index]
			> -snapshot.minimum_seabed_depth
			+ EPSILON
			or region.macro_elevation[index]
			< -snapshot.maximum_seabed_depth
			- EPSILON
		):
			depths_valid = false

	_expect(
		found_broad_depression,
		"Survey region contains a broad convergent depression."
	)

	_expect(
		found_axial_trench,
		"Survey region contains an axial trench."
	)

	_expect(
		found_overriding_uplift,
		"Survey region contains overriding-side uplift."
	)

	_expect(
		values_valid,
		"Stage 3B channels have valid signs and ranges."
	)

	_expect(
		relationships_valid,
		"Stage 3B relief retains its geological causes."
	)

	_expect(
		depths_valid,
		"Stage 3B macro terrain remains inside both depth limits."
	)


func _test_determinism_and_borders() -> void:
	var snapshot := _make_geology_snapshot()

	var first := GeologySampler.new(
		snapshot
	).generate_chunk(
		Vector2i(-7, 4),
		256.0,
		32
	)

	var second := GeologySampler.new(
		snapshot
	).generate_chunk(
		Vector2i(-7, 4),
		256.0,
		32
	)

	_expect(
		_convergent_channels_equal(
			first,
			second
		),
		"Stage 3B channels are deterministic."
	)

	var west := GeologySampler.new(
		snapshot
	).generate_chunk(
		Vector2i(-1, 0),
		256.0,
		32
	)

	var east := GeologySampler.new(
		snapshot
	).generate_chunk(
		Vector2i.ZERO,
		256.0,
		32
	)

	var border_matches := true

	for local_z in range(
		west.cells_per_axis + 1
	):
		if not _convergent_sample_equal(
			west,
			west.get_index(
				west.cells_per_axis,
				local_z
			),
			east,
			east.get_index(
				0,
				local_z
			)
		):
			border_matches = false
			break

	_expect(
		border_matches,
		"Stage 3B channels match across chunk borders."
	)


func _test_final_depth_envelope() -> void:
	var geology_snapshot := _make_geology_snapshot()

	var terrain_seed := StableSeed.derive_subsystem_seed(
		1337,
		5,
		WorldSubsystemIds.TERRAIN
	)

	var terrain_snapshot := TerrainGenerationSnapshot.new(
		1,
		100,
		Vector2i(-4, 3),
		5,
		terrain_seed,
		256.0,
		32,
		140.0,
		18.0,
		0.006,
		Time.get_ticks_usec(),
		geology_snapshot
	)

	var terrain := (
		TerrainSampler.generate_from_snapshot(
			terrain_snapshot
		)
	)

	var valid := terrain != null

	if terrain != null:
		for height in terrain.height_values:
			if (
				height
				> -geology_snapshot
					.minimum_seabed_depth
				+ EPSILON
				or height
				< -geology_snapshot
					.maximum_seabed_depth
				- EPSILON
			):
				valid = false
				break

	_expect(
		valid,
		"Final terrain detail respects the 2–1500 m depth envelope."
	)


func _make_geology_snapshot() -> GeologyGenerationSnapshot:
	var settings := GeologySettings.new()

	var geology_seed := StableSeed.derive_subsystem_seed(
		1337,
		5,
		WorldSubsystemIds.GEOLOGY
	)

	return GeologyGenerationSnapshot.from_settings(
		geology_seed,
		settings
	)


func _convergent_channels_equal(
	first: GeologyChunkData,
	second: GeologyChunkData
) -> bool:
	if first == null or second == null:
		return false

	return (
		first.convergent_influence
		== second.convergent_influence
		and first.convergent_potential
		== second.convergent_potential
		and first
			.convergent_depression_elevation_contribution
		== second
			.convergent_depression_elevation_contribution
		and first.trench_influence
		== second.trench_influence
		and first.trench_potential
		== second.trench_potential
		and first.trench_tiers
		== second.trench_tiers
		and first.trench_target_depth
		== second.trench_target_depth
		and first.trench_elevation_contribution
		== second.trench_elevation_contribution
		and first.overriding_plate_ids
		== second.overriding_plate_ids
		and first.sample_is_on_overriding_plate
		== second.sample_is_on_overriding_plate
		and first.overriding_uplift_influence
		== second.overriding_uplift_influence
		and first.overriding_uplift_potential
		== second.overriding_uplift_potential
		and first
			.overriding_uplift_elevation_contribution
		== second
			.overriding_uplift_elevation_contribution
		and first.macro_elevation
		== second.macro_elevation
	)


func _convergent_sample_equal(
	first: GeologyChunkData,
	first_index: int,
	second: GeologyChunkData,
	second_index: int
) -> bool:
	return (
		first.convergent_influence[first_index]
		== second.convergent_influence[second_index]
		and first.convergent_potential[first_index]
		== second.convergent_potential[second_index]
		and first
			.convergent_depression_elevation_contribution[
				first_index
			]
		== second
			.convergent_depression_elevation_contribution[
				second_index
			]
		and first.trench_influence[first_index]
		== second.trench_influence[second_index]
		and first.trench_potential[first_index]
		== second.trench_potential[second_index]
		and first.trench_tiers[first_index]
		== second.trench_tiers[second_index]
		and first.trench_target_depth[first_index]
		== second.trench_target_depth[second_index]
		and first.trench_elevation_contribution[first_index]
		== second.trench_elevation_contribution[second_index]
		and first.overriding_plate_ids[first_index]
		== second.overriding_plate_ids[second_index]
		and first.sample_is_on_overriding_plate[first_index]
		== second.sample_is_on_overriding_plate[
			second_index
		]
		and first.overriding_uplift_influence[first_index]
		== second.overriding_uplift_influence[
			second_index
		]
		and first.overriding_uplift_potential[first_index]
		== second.overriding_uplift_potential[
			second_index
		]
		and first
			.overriding_uplift_elevation_contribution[
				first_index
			]
		== second
			.overriding_uplift_elevation_contribution[
				second_index
			]
		and first.macro_elevation[first_index]
		== second.macro_elevation[second_index]
	)


func _expect(
	condition: bool,
	description: String
) -> void:
	if condition:
		_passed += 1
		return

	_failed += 1
	push_error(
		"FAILED: %s"
		% description
	)
