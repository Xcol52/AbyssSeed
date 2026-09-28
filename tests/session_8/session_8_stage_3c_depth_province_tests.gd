extends Node

const EPSILON: float = 0.001

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	_test_profile_weights()
	_test_starting_shelf()
	_test_integrated_channels()
	_test_shared_border()

	print("")
	print(
		"Session 8 Stage 3C depth provinces: "
		+ "%d passed, %d failed"
		% [_passed, _failed]
	)

	get_tree().quit(_failed)


func _test_profile_weights() -> void:
	var settings := DepthProvinceSnapshot.new()

	var shallow := (
		DepthProvinceProfile
		.calculate_influences_from_selector(
			0.0,
			settings
		)
	)

	var deep := (
		DepthProvinceProfile
		.calculate_influences_from_selector(
			0.53,
			settings
		)
	)

	var abyssal := (
		DepthProvinceProfile
		.calculate_influences_from_selector(
			1.0,
			settings
		)
	)

	_expect(
		shallow.x >= 1.0 - EPSILON
			and shallow.y <= EPSILON
			and shallow.z <= EPSILON,
		"Low selectors produce a shallow province."
	)

	_expect(
		deep.y >= 1.0 - EPSILON,
		"Intermediate selectors produce a deep province."
	)

	_expect(
		abyssal.z >= 1.0 - EPSILON,
		"High selectors produce an abyssal province."
	)

	var samples: Array[Vector4] = [
		shallow,
		deep,
		abyssal
	]

	var normalized := true

	for sample in samples:
		var total := sample.x + sample.y + sample.z

		if absf(total - 1.0) > EPSILON:
			normalized = false

	_expect(
		normalized,
		"Province membership weights sum to one."
	)


func _test_starting_shelf() -> void:
	var snapshot := _make_snapshot()

	var profile := DepthProvinceProfile.new(
		snapshot.geology_seed,
		snapshot.depth_provinces
	)

	var influences := profile.sample_influences(
		Vector2.ZERO
	)

	var target_depth := profile.calculate_target_depth(
		Vector2.ZERO,
		120.0,
		influences
	)

	_expect(
		influences.x >= 1.0 - EPSILON,
		"The world origin is inside the starting shelf."
	)

	_expect(
		absf(target_depth - 120.0) <= EPSILON,
		"The starting shelf preserves its shallow datum."
	)


func _test_integrated_channels() -> void:
	var snapshot := _make_snapshot()

	var region := GeologySampler.new(
		snapshot
	).generate_region(
		Vector2(65536.0, 65536.0),
		64,
		1024.0
	)

	_expect(
		region != null,
		"The depth-province survey region generates."
	)

	if region == null:
		return

	var sample_count := region.macro_elevation.size()

	var sizes_valid := (
		region.shallow_province_influence.size()
			== sample_count
		and region.deep_province_influence.size()
			== sample_count
		and region.abyssal_province_influence.size()
			== sample_count
		and region.province_transition_influence.size()
			== sample_count
		and region.province_target_depth.size()
			== sample_count
		and region.province_elevation_contribution.size()
			== sample_count
	)

	_expect(
		sizes_valid,
		"All depth-province channels match the geology grid."
	)

	var values_valid := true
	var found_non_shallow := false
	var found_large_depth := false

	for index in range(sample_count):
		var shallow := (
			region.shallow_province_influence[index]
		)

		var deep := (
			region.deep_province_influence[index]
		)

		var abyssal := (
			region.abyssal_province_influence[index]
		)

		var transition := (
			region.province_transition_influence[index]
		)

		var total := shallow + deep + abyssal

		if (
			not is_finite(total)
			or absf(total - 1.0) > 0.002
			or transition < 0.0
			or transition > 1.0
		):
			values_valid = false

		if deep > 0.05 or abyssal > 0.05:
			found_non_shallow = true

		if region.province_target_depth[index] > 800.0:
			found_large_depth = true

		if (
			region.province_elevation_contribution[index]
			> EPSILON
		):
			values_valid = false

		if (
			region.macro_elevation[index]
			< -snapshot.maximum_seabed_depth
			- EPSILON
			or region.macro_elevation[index]
			> -snapshot.minimum_seabed_depth
			+ EPSILON
		):
			values_valid = false

	_expect(
		values_valid,
		"Depth-province channels have valid ranges and signs."
	)

	_expect(
		found_non_shallow,
		"The survey includes terrain outside the shallow province."
	)

	_expect(
		found_large_depth,
		"The survey reaches the new large-scale depth range."
	)


func _test_shared_border() -> void:
	var snapshot := _make_snapshot()

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

	var matches := (
		west != null
		and east != null
	)

	if matches:
		for local_z in range(
			west.cells_per_axis + 1
		):
			var west_index := west.get_index(
				west.cells_per_axis,
				local_z
			)

			var east_index := east.get_index(
				0,
				local_z
			)

			if (
				west.shallow_province_influence[
					west_index
				]
				!= east.shallow_province_influence[
					east_index
				]
				or west.deep_province_influence[
					west_index
				]
				!= east.deep_province_influence[
					east_index
				]
				or west.abyssal_province_influence[
					west_index
				]
				!= east.abyssal_province_influence[
					east_index
				]
				or west.province_target_depth[
					west_index
				]
				!= east.province_target_depth[
					east_index
				]
				or west.province_elevation_contribution[
					west_index
				]
				!= east.province_elevation_contribution[
					east_index
				]
			):
				matches = false
				break

	_expect(
		matches,
		"Depth provinces match exactly across chunk borders."
	)


func _make_snapshot() -> GeologyGenerationSnapshot:
	var settings := GeologySettings.new()

	var geology_seed := StableSeed.derive_subsystem_seed(
		1337,
		7,
		WorldSubsystemIds.GEOLOGY
	)

	return GeologyGenerationSnapshot.from_settings(
		geology_seed,
		settings
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
