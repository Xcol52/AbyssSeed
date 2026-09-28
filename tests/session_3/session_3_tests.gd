extends Node

var _assertion_count: int = 0
var _failure_count: int = 0


func _ready() -> void:
	_test_coordinate_conversions()
	_test_border_sample_addresses()
	_test_seed_derivation()
	_test_terrain_borders()

	if _failure_count == 0:
		print(
			"Session 3 tests passed: %d assertions."
			% _assertion_count
		)
	else:
		push_error(
			"Session 3 tests failed: %d of %d assertions failed."
			% [_failure_count, _assertion_count]
		)

	get_tree().quit(_failure_count)


func _test_coordinate_conversions() -> void:
	var grid := WorldGridSettings.new()
	grid.chunk_size = 64.0
	grid.cells_per_axis = 8

	_expect_equal(
		WorldCoordinates.world_to_chunk(Vector2.ZERO, grid),
		Vector2i.ZERO,
		"Origin belongs to chunk (0, 0)."
	)
	_expect_equal(
		WorldCoordinates.world_to_chunk(Vector2(63, 63), grid),
		Vector2i(0, 0),
		"One unit before positive boundary."
	)
	_expect_equal(
		WorldCoordinates.world_to_chunk(Vector2(64, 64), grid),
		Vector2i(1, 1),
		"Exact positive boundary."
	)
	_expect_equal(
		WorldCoordinates.world_to_chunk(Vector2(65, 65), grid),
		Vector2i(1, 1),
		"One unit after positive boundary."
	)
	_expect_equal(
		WorldCoordinates.world_to_chunk(Vector2(-1, -1), grid),
		Vector2i(-1, -1),
		"Negative position uses floor behavior."
	)
	_expect_equal(
		WorldCoordinates.world_to_chunk(Vector2(-64, -64), grid),
		Vector2i(-1, -1),
		"Exact negative boundary."
	)
	_expect_equal(
		WorldCoordinates.world_to_chunk(Vector2(-65, -65), grid),
		Vector2i(-2, -2),
		"One unit beyond negative boundary."
	)

	_expect_equal(
		WorldCoordinates.chunk_to_world_origin(
			Vector2i(-1, 2),
			grid
		),
		Vector2(-64, 128),
		"Chunk-to-world origin conversion."
	)

	var original_position := Vector2(-1, 65)
	var owner_chunk := WorldCoordinates.world_to_chunk(
	original_position,
	grid
)
	var local_position := (
		WorldCoordinates.world_to_chunk_local(
			original_position,
			grid
		)
	)
	var reconstructed := (
		WorldCoordinates.chunk_local_to_world(
			owner_chunk,
			local_position,
			grid
		)
	)

	_expect_true(
		reconstructed.is_equal_approx(original_position),
		"World/chunk-local reconstruction."
	)

	_expect_equal(
		WorldCoordinates.global_sample_to_chunk(
			Vector2i(-1, -9),
			8
		),
		Vector2i(-1, -2),
		"Negative global sample owner."
	)
	_expect_equal(
		WorldCoordinates.global_sample_to_local(
			Vector2i(-1, -9),
			8
		),
		Vector2i(7, 7),
		"Negative global sample local coordinate."
	)


func _test_border_sample_addresses() -> void:
	var cells := 8

	for local_z in range(cells + 1):
		var center_east := (
			WorldCoordinates.chunk_local_sample_to_global(
				Vector2i(0, 0),
				Vector2i(cells, local_z),
				cells
			)
		)
		var east_west := (
			WorldCoordinates.chunk_local_sample_to_global(
				Vector2i(1, 0),
				Vector2i(0, local_z),
				cells
			)
		)

		_expect_equal(
			center_east,
			east_west,
			"Positive X shared sample at Z=%d." % local_z
		)

		var negative_east := (
			WorldCoordinates.chunk_local_sample_to_global(
				Vector2i(-1, 0),
				Vector2i(cells, local_z),
				cells
			)
		)
		var center_west := (
			WorldCoordinates.chunk_local_sample_to_global(
				Vector2i(0, 0),
				Vector2i(0, local_z),
				cells
			)
		)

		_expect_equal(
			negative_east,
			center_west,
			"Negative X shared sample at Z=%d." % local_z
		)

	for local_x in range(cells + 1):
		var center_positive_z := (
			WorldCoordinates.chunk_local_sample_to_global(
				Vector2i(0, 0),
				Vector2i(local_x, cells),
				cells
			)
		)
		var neighbor_negative_z := (
			WorldCoordinates.chunk_local_sample_to_global(
				Vector2i(0, 1),
				Vector2i(local_x, 0),
				cells
			)
		)

		_expect_equal(
			center_positive_z,
			neighbor_negative_z,
			"Positive Z shared sample at X=%d." % local_x
		)

		var negative_positive_z := (
			WorldCoordinates.chunk_local_sample_to_global(
				Vector2i(0, -1),
				Vector2i(local_x, cells),
				cells
			)
		)
		var center_negative_z := (
			WorldCoordinates.chunk_local_sample_to_global(
				Vector2i(0, 0),
				Vector2i(local_x, 0),
				cells
			)
		)

		_expect_equal(
			negative_positive_z,
			center_negative_z,
			"Negative Z shared sample at X=%d." % local_x
		)


func _test_seed_derivation() -> void:
	var first := StableSeed.derive_subsystem_seed(
		1337,
		1,
		WorldSubsystemIds.TERRAIN
	)
	var repeated := StableSeed.derive_subsystem_seed(
		1337,
		1,
		WorldSubsystemIds.TERRAIN
	)
	var biome_value := StableSeed.derive_subsystem_seed(
		1337,
		1,
		WorldSubsystemIds.BIOMES
	)

	_expect_equal(
		first,
		repeated,
		"Identical seed inputs produce identical output."
	)
	_expect_true(
		first != biome_value,
		"Different subsystem IDs produce different output."
	)

	var negative_coordinate := Vector2i(-25, -9)
	var coordinate_first := StableSeed.derive_coordinate_seed(
		1337,
		1,
		WorldSubsystemIds.PLACEMENT,
		negative_coordinate
	)
	var coordinate_repeated := StableSeed.derive_coordinate_seed(
		1337,
		1,
		WorldSubsystemIds.PLACEMENT,
		negative_coordinate
	)

	_expect_equal(
		coordinate_first,
		coordinate_repeated,
		"Negative coordinate seeds remain stable."
	)


func _test_terrain_borders() -> void:
	var grid := WorldGridSettings.new()
	grid.chunk_size = 64.0
	grid.cells_per_axis = 8

	var terrain := TerrainSettings.new()
	terrain.base_seabed_depth = 120.0
	terrain.test_elevation_amplitude = 10.0
	terrain.test_noise_frequency = 0.01

	var terrain_subsystem_seed := (
		StableSeed.derive_subsystem_seed(
			1337,
			1,
			WorldSubsystemIds.TERRAIN
		)
	)

	var center := _generate_test_chunk(
		Vector2i(0, 0),
		terrain_subsystem_seed,
		grid,
		terrain
	)
	var east := _generate_test_chunk(
		Vector2i(1, 0),
		terrain_subsystem_seed,
		grid,
		terrain
	)
	var positive_z := _generate_test_chunk(
		Vector2i(0, 1),
		terrain_subsystem_seed,
		grid,
		terrain
	)
	var negative_x := _generate_test_chunk(
		Vector2i(-1, 0),
		terrain_subsystem_seed,
		grid,
		terrain
	)
	var negative_z := _generate_test_chunk(
		Vector2i(0, -1),
		terrain_subsystem_seed,
		grid,
		terrain
	)

	if (
		center == null
		or east == null
		or positive_z == null
		or negative_x == null
		or negative_z == null
	):
		_expect_true(false, "Terrain test chunks generated.")
		return

	var cells := grid.cells_per_axis

	for sample_index in range(cells + 1):
		_expect_equal(
			center.get_height(cells, sample_index),
			east.get_height(0, sample_index),
			"Center/east terrain edge at %d."
			% sample_index
		)

		_expect_equal(
			negative_x.get_height(cells, sample_index),
			center.get_height(0, sample_index),
			"Negative-X/center terrain edge at %d."
			% sample_index
		)

		_expect_equal(
			center.get_height(sample_index, cells),
			positive_z.get_height(sample_index, 0),
			"Center/positive-Z terrain edge at %d."
			% sample_index
		)

		_expect_equal(
			negative_z.get_height(sample_index, cells),
			center.get_height(sample_index, 0),
			"Negative-Z/center terrain edge at %d."
			% sample_index
		)


func _generate_test_chunk(
	chunk_coordinate: Vector2i,
	terrain_subsystem_seed: int,
	grid: WorldGridSettings,
	terrain: TerrainSettings
) -> TerrainChunkData:
	var request := TerrainGenerationRequest.new(
		chunk_coordinate,
		terrain_subsystem_seed,
		1,
		grid,
		terrain
	)

	return TerrainSampler.new().generate(request)


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
