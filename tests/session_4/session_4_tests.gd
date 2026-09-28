extends Node

var _assertion_count: int = 0
var _failure_count: int = 0


func _ready() -> void:
	_test_desired_coordinates()
	_test_residency_plan_and_hysteresis()
	_test_queue_reconciliation()
	_test_generation_priority()
	_test_deterministic_regeneration()
	_test_negative_neighbor_border()

	if _failure_count == 0:
		print(
			"Session 4 tests passed: %d assertions."
			% _assertion_count
		)
	else:
		push_error(
			"Session 4 tests failed: %d of %d assertions failed."
			% [_failure_count, _assertion_count]
		)

	get_tree().quit(_failure_count)


func _test_desired_coordinates() -> void:
	var center := Vector2i(3, -4)
	var coordinates := (
		ChunkStreamPolicy.get_desired_coordinates(
			center,
			2
		)
	)

	_expect_equal(
		coordinates.size(),
		25,
		"Radius two produces 25 coordinates."
	)

	var unique_coordinates: Dictionary = {}

	for coordinate in coordinates:
		unique_coordinates[coordinate] = true

		_expect_true(
			ChunkStreamPolicy.is_within_radius(
				coordinate,
				center,
				2
			),
			"Every desired coordinate is inside load radius."
		)

	_expect_equal(
		unique_coordinates.size(),
		25,
		"Desired coordinates contain no duplicates."
	)

	_expect_true(
		coordinates.has(center),
		"Desired set contains observer chunk."
	)
	_expect_true(
		coordinates.has(Vector2i(1, -6)),
		"Desired set contains negative corner."
	)
	_expect_true(
		coordinates.has(Vector2i(5, -2)),
		"Desired set contains positive corner."
	)

	var negative_center_coordinates := (
		ChunkStreamPolicy.get_desired_coordinates(
			Vector2i(-5, -7),
			1
		)
	)

	_expect_equal(
		negative_center_coordinates.size(),
		9,
		"Negative-center radius one produces nine coordinates."
	)
	_expect_true(
		negative_center_coordinates.has(
			Vector2i(-6, -8)
		),
		"Negative-center neighborhood has correct minimum."
	)
	_expect_true(
		negative_center_coordinates.has(
			Vector2i(-4, -6)
		),
		"Negative-center neighborhood has correct maximum."
	)


func _test_residency_plan_and_hysteresis() -> void:
	var settings := _create_streaming_settings()

	var active_coordinates: Array[Vector2i] = [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(3, 0),
		Vector2i(-3, 3),
		Vector2i(4, 0),
		Vector2i(0, -4)
	]

	var plan := ChunkStreamPolicy.create_plan(
		Vector2i.ZERO,
		active_coordinates,
		settings,
		Vector2(0.0, -1.0)
	)

	_expect_equal(
		plan.desired_coordinates.size(),
		25,
		"Plan contains complete load neighborhood."
	)
	_expect_equal(
		plan.generation_queue.size(),
		23,
		"Already active desired chunks are not regenerated."
	)
	_expect_equal(
		plan.unload_coordinates.size(),
		2,
		"Only chunks beyond unload radius are removed."
	)
	_expect_true(
		plan.unload_coordinates.has(Vector2i(4, 0)),
		"Positive distant chunk is unloaded."
	)
	_expect_true(
		plan.unload_coordinates.has(Vector2i(0, -4)),
		"Negative distant chunk is unloaded."
	)
	_expect_true(
		not plan.unload_coordinates.has(Vector2i(3, 0)),
		"Chunk on unload boundary is retained."
	)
	_expect_true(
		not plan.unload_coordinates.has(Vector2i(-3, 3)),
		"Corner on unload boundary is retained."
	)
	_expect_true(
		not plan.desired_coordinates.has(Vector2i(3, 0)),
		"Retained hysteresis chunk is not newly desired."
	)
	_expect_true(
		not plan.generation_queue.has(Vector2i.ZERO),
		"Active observer chunk is not queued."
	)
	_expect_true(
		not plan.generation_queue.has(Vector2i(1, 0)),
		"Other active desired chunk is not queued."
	)

	var queue_set: Dictionary = {}

	for coordinate in plan.generation_queue:
		_expect_true(
			not queue_set.has(coordinate),
			"Generation queue contains no duplicates."
		)
		queue_set[coordinate] = true

		_expect_true(
			plan.desired_coordinates.has(coordinate),
			"Every queued coordinate is desired."
		)


func _test_queue_reconciliation() -> void:
	var settings := _create_streaming_settings()
	var no_active_chunks: Array[Vector2i] = []

	var initial_plan := ChunkStreamPolicy.create_plan(
		Vector2i.ZERO,
		no_active_chunks,
		settings,
		Vector2(1.0, 0.0)
	)

	_expect_equal(
		initial_plan.generation_queue[0],
		Vector2i.ZERO,
		"Observer chunk receives first priority."
	)

	var simulated_active: Array[Vector2i] = [
		initial_plan.generation_queue[0]
	]

	var updated_plan := ChunkStreamPolicy.create_plan(
		Vector2i.ZERO,
		simulated_active,
		settings,
		Vector2(1.0, 0.0)
	)

	_expect_true(
		not updated_plan.generation_queue.has(Vector2i.ZERO),
		"Generated coordinate is not queued a second time."
	)
	_expect_equal(
		updated_plan.generation_queue.size(),
		24,
		"Exactly one active desired chunk is removed from queue."
	)

	var moved_center := Vector2i(10, -5)
	var moved_plan := ChunkStreamPolicy.create_plan(
		moved_center,
		simulated_active,
		settings,
		Vector2(1.0, 0.0)
	)

	_expect_true(
		moved_plan.unload_coordinates.has(Vector2i.ZERO),
		"Old active chunk is unloaded after a large move."
	)
	_expect_true(
		not moved_plan.generation_queue.has(
			Vector2i(-2, -2)
		),
		"Old pending coordinate is absent from rebuilt queue."
	)

	for coordinate in moved_plan.generation_queue:
		_expect_true(
			ChunkStreamPolicy.is_within_radius(
				coordinate,
				moved_center,
				settings.load_radius
			),
			"Rebuilt queue contains only newly desired coordinates."
		)


func _test_generation_priority() -> void:
	var candidates: Array[Vector2i] = [
		Vector2i(-1, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(0, 0),
		Vector2i(1, 1)
	]

	var forward_order := (
		ChunkStreamPolicy.order_for_generation(
			candidates,
			Vector2i.ZERO,
			Vector2(1.0, 0.0),
			0.25
		)
	)

	_expect_equal(
		forward_order[0],
		Vector2i.ZERO,
		"Observer chunk remains highest priority."
	)
	_expect_true(
		forward_order.find(Vector2i(1, 0))
		< forward_order.find(Vector2i(-1, 0)),
		"Forward chunk wins an equal-distance tie."
	)
	_expect_true(
		forward_order.find(Vector2i(-1, 0))
		< forward_order.find(Vector2i(1, 1)),
		"Near rear chunk beats farther forward-diagonal chunk."
	)
	_expect_true(
		forward_order.find(Vector2i(1, 1))
		< forward_order.find(Vector2i(2, 0)),
		"Distance remains dominant over forward alignment."
	)

	var repeated_order := (
		ChunkStreamPolicy.order_for_generation(
			candidates,
			Vector2i.ZERO,
			Vector2(1.0, 0.0),
			0.25
		)
	)

	_expect_equal(
		forward_order,
		repeated_order,
		"Priority ordering is deterministic."
	)

	var reverse_order := (
		ChunkStreamPolicy.order_for_generation(
			candidates,
			Vector2i.ZERO,
			Vector2(-1.0, 0.0),
			0.25
		)
	)

	_expect_true(
		reverse_order.find(Vector2i(-1, 0))
		< reverse_order.find(Vector2i(1, 0)),
		"Changing heading changes equal-distance priority."
	)


func _test_deterministic_regeneration() -> void:
	var grid := WorldGridSettings.new()
	grid.chunk_size = 64.0
	grid.cells_per_axis = 8

	var terrain := TerrainSettings.new()
	terrain.base_seabed_depth = 120.0
	terrain.test_elevation_amplitude = 10.0
	terrain.test_noise_frequency = 0.01

	var terrain_seed := StableSeed.derive_subsystem_seed(
		1337,
		1,
		WorldSubsystemIds.TERRAIN
	)

	var first := _generate_test_chunk(
		Vector2i(-2, 3),
		terrain_seed,
		grid,
		terrain
	)
	var second := _generate_test_chunk(
		Vector2i(-2, 3),
		terrain_seed,
		grid,
		terrain
	)

	_expect_true(
		first != null and second != null,
		"Repeated terrain chunks generate successfully."
	)

	if first == null or second == null:
		return

	_expect_true(
		_packed_float_arrays_equal(
			first.height_values,
			second.height_values
		),
		"Returning to a coordinate regenerates identical terrain."
	)


func _test_negative_neighbor_border() -> void:
	var grid := WorldGridSettings.new()
	grid.chunk_size = 64.0
	grid.cells_per_axis = 8

	var terrain := TerrainSettings.new()
	terrain.base_seabed_depth = 120.0
	terrain.test_elevation_amplitude = 10.0
	terrain.test_noise_frequency = 0.01

	var terrain_seed := StableSeed.derive_subsystem_seed(
		1337,
		1,
		WorldSubsystemIds.TERRAIN
	)

	var negative_chunk := _generate_test_chunk(
		Vector2i(-1, 0),
		terrain_seed,
		grid,
		terrain
	)
	var origin_chunk := _generate_test_chunk(
		Vector2i(0, 0),
		terrain_seed,
		grid,
		terrain
	)

	_expect_true(
		negative_chunk != null and origin_chunk != null,
		"Negative neighboring chunks generate successfully."
	)

	if negative_chunk == null or origin_chunk == null:
		return

	for local_z in range(grid.cells_per_axis + 1):
		_expect_equal(
			negative_chunk.get_height(
				grid.cells_per_axis,
				local_z
			),
			origin_chunk.get_height(0, local_z),
			"Negative/origin shared terrain edge at Z=%d."
			% local_z
		)


func _create_streaming_settings() -> ChunkStreamingSettings:
	var settings := ChunkStreamingSettings.new()
	settings.load_radius = 2
	settings.unload_radius = 3
	settings.camera_reprioritize_angle_degrees = 15.0
	settings.forward_priority_bias = 0.25
	return settings


func _generate_test_chunk(
	chunk_coordinate: Vector2i,
	terrain_seed: int,
	grid: WorldGridSettings,
	terrain: TerrainSettings
) -> TerrainChunkData:
	var request := TerrainGenerationRequest.new(
		chunk_coordinate,
		terrain_seed,
		1,
		grid,
		terrain
	)

	return TerrainSampler.new().generate(request)


func _packed_float_arrays_equal(
	first: PackedFloat32Array,
	second: PackedFloat32Array
) -> bool:
	if first.size() != second.size():
		return false

	for index in range(first.size()):
		if first[index] != second[index]:
			return false

	return true


func _expect_equal(
	actual: Variant,
	expected: Variant,
	description: String
) -> void:
	_assertion_count += 1

	if actual != expected:
		_failure_count += 1
		push_error(
			"FAIL: %s Expected %s, received %s."
			% [description, str(expected), str(actual)]
		)


func _expect_true(
	condition: bool,
	description: String
) -> void:
	_assertion_count += 1

	if not condition:
		_failure_count += 1
		push_error("FAIL: %s" % description)
