extends Node

const EPSILON: float = 0.001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_test_descriptor_and_profiles()
	_test_integrated_channels()
	_test_determinism_and_boundaries()

	print("")
	print(
		"Session 8 Stage 3A: %d passed, %d failed"
		% [_passed, _failed]
	)

	if _failed == 0:
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func _test_descriptor_and_profiles() -> void:
	var settings := GeologySettings.new()

	var relief_snapshot := (
		PlateInteriorReliefSnapshot.from_settings(
			settings
		)
	)

	var site := GeologyPlateSite.new(
		Vector2i(-3, 5),
		1234567,
		Vector2(-10240.0, 22528.0),
		Vector2(0.4, -0.7),
		0.35,
		0.0
	)

	var first := (
		PlateInteriorReliefProfile.create_descriptor(
			987654,
			site,
			settings.plate_cell_size,
			relief_snapshot
		)
	)

	var second := (
		PlateInteriorReliefProfile.create_descriptor(
			987654,
			site,
			settings.plate_cell_size,
			relief_snapshot
		)
	)

	_expect(
		first.hill_centers == second.hill_centers,
		"Plate hill anchors are deterministic."
	)

	_expect(
		first.hill_radii == second.hill_radii,
		"Plate hill dimensions are deterministic."
	)

	_expect(
		first.hill_heights == second.hill_heights,
		"Plate hill relief is deterministic."
	)

	var hill_center_sample := (
		PlateInteriorReliefProfile.sample(
			first,
			first.hill_centers[0],
			1.0
		)
	)

	_expect(
		hill_center_sample.x > 0.0,
		"A hill anchor produces positive relief."
	)

	var terrace_center_sample := (
		PlateInteriorReliefProfile.sample(
			first,
			first.terrace_centers[0],
			1.0
		)
	)

	_expect(
		absf(terrace_center_sample.y) > 0.0,
		"A terrace anchor produces signed relief."
	)

	var boundary_sample := (
		PlateInteriorReliefProfile.sample(
			first,
			first.hill_centers[0],
			0.0
		)
	)

	_expect(
		_vector4_near_zero(boundary_sample),
		"Interior relief is zero at a plate boundary."
	)

	var distant_sample := (
		PlateInteriorReliefProfile.sample(
			first,
			site.position
				+ Vector2(100000.0, 100000.0),
			1.0
		)
	)

	_expect(
		_vector4_near_zero(distant_sample),
		"Plate features have finite geographic support."
	)


func _test_integrated_channels() -> void:
	var snapshot := _make_geology_snapshot()

	var region := GeologySampler.new(
		snapshot
	).generate_region(
		Vector2(-8192.0, -8192.0),
		128,
		128.0
	)

	_expect(
		region != null,
		"Stage 3A survey region generates."
	)

	if region == null:
		return

	var sample_count := region.macro_elevation.size()

	_expect(
		region.hill_elevation_contribution.size()
			== sample_count
		and region.terrace_elevation_contribution.size()
			== sample_count
		and region.massif_elevation_contribution.size()
			== sample_count
		and region
			.interior_depression_elevation_contribution
			.size()
			== sample_count
		and region
			.combined_interior_elevation_contribution
			.size()
			== sample_count,
		"All Stage 3A channels match the sample grid."
	)

	var found_hill := false
	var found_terrace := false
	var found_massif := false
	var found_depression := false

	var values_valid := true
	var combined_values_match := true
	var macro_is_submerged := true

	for index in range(sample_count):
		var influence := (
			region.plate_interior_influence[index]
		)

		var hill := (
			region.hill_elevation_contribution[index]
		)

		var terrace := (
			region.terrace_elevation_contribution[index]
		)

		var massif := (
			region.massif_elevation_contribution[index]
		)

		var depression := (
			region
			.interior_depression_elevation_contribution[
				index
			]
		)

		var combined := (
			region
			.combined_interior_elevation_contribution[
				index
			]
		)

		var headroom_scale := (
			region.surface_headroom_scale[index]
		)

		if hill > EPSILON:
			found_hill = true

		if absf(terrace) > EPSILON:
			found_terrace = true

		if massif > EPSILON:
			found_massif = true

		if depression < -EPSILON:
			found_depression = true

		if (
			not is_finite(influence)
			or not is_finite(hill)
			or not is_finite(terrace)
			or not is_finite(massif)
			or not is_finite(depression)
			or not is_finite(combined)
			or not is_finite(headroom_scale)
			or influence < 0.0
			or influence > 1.0
			or hill < -EPSILON
			or massif < -EPSILON
			or depression > EPSILON
			or headroom_scale < 0.0
			or headroom_scale > 1.0
		):
			values_valid = false

		var expected_combined := (
			hill
			+ terrace
			+ massif
			+ depression
		)

		if (
			absf(
				combined
				- expected_combined
			)
			> EPSILON
		):
			combined_values_match = false

		if (
			region.macro_elevation[index]
			> -snapshot.minimum_seabed_depth
				+ EPSILON
		):
			macro_is_submerged = false

	_expect(
		found_hill,
		"Survey region contains hills."
	)

	_expect(
		found_terrace,
		"Survey region contains terraces."
	)

	_expect(
		found_massif,
		"Survey region contains a massif."
	)

	_expect(
		found_depression,
		"Survey region contains an interior depression."
	)

	_expect(
		values_valid,
		"Stage 3A channels have valid signs and ranges."
	)

	_expect(
		combined_values_match,
		"Combined interior relief equals its components."
	)

	_expect(
		macro_is_submerged,
		"Macro terrain respects the two-meter surface boundary."
	)

	var terrain_snapshot := TerrainGenerationSnapshot.new(
		1,
		100,
		Vector2i(-4, 3),
		4,
		StableSeed.derive_subsystem_seed(
			1337,
			4,
			WorldSubsystemIds.TERRAIN
		),
		256.0,
		32,
		140.0,
		18.0,
		0.006,
		Time.get_ticks_usec(),
		snapshot
	)

	var terrain := (
		TerrainSampler.generate_from_snapshot(
			terrain_snapshot
		)
	)

	var final_terrain_is_submerged := (
		terrain != null
	)

	if terrain != null:
		for height in terrain.height_values:
			if (
				height
				> -snapshot.minimum_seabed_depth
					+ EPSILON
			):
				final_terrain_is_submerged = false
				break

	_expect(
		final_terrain_is_submerged,
		"Final terrain detail respects the two-meter boundary."
	)


func _test_determinism_and_boundaries() -> void:
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
		_new_channels_equal(first, second),
		"Stage 3A channels are deterministic."
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
		if not _new_sample_equal(
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
		"Stage 3A channels match across chunk borders."
	)

	var fine := GeologySampler.new(
		snapshot
	).generate_region(
		Vector2(-512.0, -512.0),
		8,
		128.0
	)

	var coarse := GeologySampler.new(
		snapshot
	).generate_region(
		Vector2(-1024.0, -1024.0),
		8,
		256.0
	)

	_expect(
		_new_sample_equal(
			fine,
			fine.get_index(4, 4),
			coarse,
			coarse.get_index(4, 4)
		),
		"Interior relief is independent of sampling resolution."
	)


func _make_geology_snapshot() -> GeologyGenerationSnapshot:
	var settings := GeologySettings.new()

	var geology_seed := StableSeed.derive_subsystem_seed(
		1337,
		4,
		WorldSubsystemIds.GEOLOGY
	)

	return GeologyGenerationSnapshot.from_settings(
		geology_seed,
		settings
	)


func _new_channels_equal(
	first: GeologyChunkData,
	second: GeologyChunkData
) -> bool:
	if first == null or second == null:
		return false

	return (
		first.plate_interior_influence
		== second.plate_interior_influence
		and first.hill_elevation_contribution
		== second.hill_elevation_contribution
		and first.terrace_elevation_contribution
		== second.terrace_elevation_contribution
		and first.massif_elevation_contribution
		== second.massif_elevation_contribution
		and first
			.interior_depression_elevation_contribution
		== second
			.interior_depression_elevation_contribution
		and first
			.combined_interior_elevation_contribution
		== second
			.combined_interior_elevation_contribution
		and first.surface_headroom_scale
		== second.surface_headroom_scale
		and first.macro_elevation
		== second.macro_elevation
	)


func _new_sample_equal(
	first: GeologyChunkData,
	first_index: int,
	second: GeologyChunkData,
	second_index: int
) -> bool:
	return (
		first.plate_interior_influence[first_index]
		== second.plate_interior_influence[second_index]
		and first.hill_elevation_contribution[first_index]
		== second.hill_elevation_contribution[second_index]
		and first.terrace_elevation_contribution[first_index]
		== second.terrace_elevation_contribution[second_index]
		and first.massif_elevation_contribution[first_index]
		== second.massif_elevation_contribution[second_index]
		and first
			.interior_depression_elevation_contribution[
				first_index
			]
		== second
			.interior_depression_elevation_contribution[
				second_index
			]
		and first
			.combined_interior_elevation_contribution[
				first_index
			]
		== second
			.combined_interior_elevation_contribution[
				second_index
			]
		and first.surface_headroom_scale[first_index]
		== second.surface_headroom_scale[second_index]
		and first.macro_elevation[first_index]
		== second.macro_elevation[second_index]
	)


func _vector4_near_zero(
	value: Vector4
) -> bool:
	return (
		absf(value.x) <= EPSILON
		and absf(value.y) <= EPSILON
		and absf(value.z) <= EPSILON
		and absf(value.w) <= EPSILON
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
