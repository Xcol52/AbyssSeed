extends Node

var _assertion_count: int = 0
var _failure_count: int = 0

var _async_scheduler: ChunkGenerationScheduler
var _async_expected: Dictionary = {}
var _async_results: Dictionary = {}

var _async_started_usec: int = 0
var _maximum_running_seen: int = 0
var _maximum_completed_seen: int = 0


func _ready() -> void:
	_test_geology_determinism()
	_test_chunk_borders()
	_test_scale_independence()
	_test_geological_relationships()
	_begin_async_test()


func _process(_delta: float) -> void:
	if _async_scheduler == null:
		return

	_async_scheduler.poll()

	_maximum_running_seen = maxi(
		_maximum_running_seen,
		_async_scheduler.get_running_count()
	)

	_maximum_completed_seen = maxi(
		_maximum_completed_seen,
		_async_scheduler.get_completed_count()
	)

	while _async_scheduler.get_completed_count() > 0:
		_consume_async_result()

	_async_scheduler.dispatch()

	if (
		Time.get_ticks_usec() - _async_started_usec
		> 10_000_000
	):
		_expect_true(
			false,
			"Geological async test completed before timeout."
		)
		_finish_async_test()
		return

	if (
		_async_results.size() == 3
		and _async_scheduler.get_pending_count() == 0
		and _async_scheduler.get_running_count() == 0
		and _async_scheduler.get_completed_count() == 0
	):
		_finish_async_test()


func _test_geology_determinism() -> void:
	var snapshot := _make_geology_snapshot()
	var sampler := GeologySampler.new(snapshot)

	var first := sampler.generate_chunk(
		Vector2i(-2, 3),
		64.0,
		8
	)

	var second := GeologySampler.new(
		snapshot
	).generate_chunk(
		Vector2i(-2, 3),
		64.0,
		8
	)

	_expect_true(
		_geology_equal(first, second),
		"Same negative chunk produces identical geology."
	)

	## Generate unrelated data between repeated requests.
	GeologySampler.new(snapshot).generate_chunk(
		Vector2i(9, -11),
		64.0,
		8
	)

	var repeated := GeologySampler.new(
		snapshot
	).generate_chunk(
		Vector2i(-2, 3),
		64.0,
		8
	)

	_expect_true(
		_geology_equal(first, repeated),
		"Geology is independent of generation order."
	)


func _test_chunk_borders() -> void:
	var geology_snapshot := _make_geology_snapshot()

	var negative_x := GeologySampler.new(
		geology_snapshot
	).generate_chunk(
		Vector2i(-1, 0),
		64.0,
		8
	)

	var origin := GeologySampler.new(
		geology_snapshot
	).generate_chunk(
		Vector2i.ZERO,
		64.0,
		8
	)

	var positive_x := GeologySampler.new(
		geology_snapshot
	).generate_chunk(
		Vector2i(1, 0),
		64.0,
		8
	)

	var positive_z := GeologySampler.new(
		geology_snapshot
	).generate_chunk(
		Vector2i(0, 1),
		64.0,
		8
	)

	_expect_true(
		_vertical_geology_edge_equal(
			negative_x,
			origin
		),
		"Negative-X/origin geological border matches."
	)

	_expect_true(
		_vertical_geology_edge_equal(
			origin,
			positive_x
		),
		"Origin/positive-X geological border matches."
	)

	_expect_true(
		_horizontal_geology_edge_equal(
			origin,
			positive_z
		),
		"Origin/positive-Z geological border matches."
	)

	var origin_terrain := TerrainSampler.generate_from_snapshot(
		_make_terrain_snapshot(1, Vector2i.ZERO)
	)

	var east_terrain := TerrainSampler.generate_from_snapshot(
		_make_terrain_snapshot(2, Vector2i(1, 0))
	)

	var terrain_edges_match := true

	for local_z in range(
		origin_terrain.cells_per_axis + 1
	):
		if (
			origin_terrain.get_height(
				origin_terrain.cells_per_axis,
				local_z
			)
			!= east_terrain.get_height(0, local_z)
		):
			terrain_edges_match = false
			break

	_expect_true(
		terrain_edges_match,
		"Final geological terrain border matches."
	)


func _test_scale_independence() -> void:
	var snapshot := _make_geology_snapshot()

	var fine_region := GeologySampler.new(
		snapshot
	).generate_region(
		Vector2(-512.0, -512.0),
		8,
		128.0
	)

	var coarse_region := GeologySampler.new(
		snapshot
	).generate_region(
		Vector2(-1024.0, -1024.0),
		8,
		256.0
	)

	var fine_index := fine_region.get_index(4, 4)
	var coarse_index := coarse_region.get_index(4, 4)

	_expect_true(
		_geology_sample_equal(
			fine_region,
			fine_index,
			coarse_region,
			coarse_index
		),
		"Same world point is independent of sample resolution."
	)

	var small_chunk := GeologySampler.new(
		snapshot
	).generate_chunk(
		Vector2i.ZERO,
		64.0,
		8
	)

	var large_chunk := GeologySampler.new(
		snapshot
	).generate_chunk(
		Vector2i.ZERO,
		128.0,
		16
	)

	_expect_true(
		_geology_sample_equal(
			small_chunk,
			small_chunk.get_index(8, 8),
			large_chunk,
			large_chunk.get_index(8, 8)
		),
		"Same world point is independent of chunk dimensions."
	)


func _test_geological_relationships() -> void:
	var snapshot := _make_geology_snapshot()

	var region := GeologySampler.new(
		snapshot
	).generate_region(
		Vector2(-16384.0, -16384.0),
		64,
		512.0
	)

	var invalid_range_count := 0
	var trench_without_compression := 0
	var divergent_relief_without_divergent_class := 0
	var volcanism_without_cause := 0

	var minimum_continental := 1.0
	var maximum_continental := 0.0
	var minimum_elevation := INF
	var maximum_elevation := -INF

	var maximum_ridge := 0.0
	var maximum_trench := 0.0

	for index in range(
		region.macro_elevation.size()
	):
		var continental := (
			region.continental_affinity[index]
		)

		var boundary := (
			region.boundary_proximity[index]
		)

		var compression := (
			region.compression_strength[index]
		)

		var extension := (
			region.extension_strength[index]
		)

		var shear := (
			region.shear_strength[index]
		)

		var ridge_influence := (
			region.ridge_influence[index]
		)

		var rift_influence := (
			region.rift_influence[index]
		)

		var ridge := (
			region.ridge_potential[index]
		)

		var rift := (
			region.rift_potential[index]
		)

		var trench := (
			region.trench_potential[index]
		)

		var volcanic := (
			region.volcanic_potential[index]
		)

		var sediment := (
			region.sediment_potential[index]
		)

		var boundary_class := (
			int(region.boundary_classes[index])
		)

		var values: Array[float] = [
			continental,
			boundary,
			compression,
			extension,
			shear,
			ridge_influence,
			rift_influence,
			ridge,
			rift,
			trench,
			volcanic,
			sediment
		]

		for value in values:
			if value < 0.0 or value > 1.0:
				invalid_range_count += 1

		if (
			trench > 0.000001
			and compression <= 0.0
		):
			trench_without_compression += 1

		## Stage 2B intentionally allows the broad ridge profile to
		## extend beyond the original narrow extension-strength band.
		##
		## The correct invariant is that ridge and rift potential only
		## occur for motion-classified divergent relationships.
		if (
			(
				ridge > 0.000001
				or rift > 0.000001
			)
			and boundary_class
			!= GeologyChunkData.BOUNDARY_CLASS_DIVERGENT
		):
			divergent_relief_without_divergent_class += 1

		if (
			volcanic > 0.000001
			and ridge <= 0.0
			and trench <= 0.0
		):
			volcanism_without_cause += 1

		minimum_continental = minf(
			minimum_continental,
			continental
		)

		maximum_continental = maxf(
			maximum_continental,
			continental
		)

		minimum_elevation = minf(
			minimum_elevation,
			region.macro_elevation[index]
		)

		maximum_elevation = maxf(
			maximum_elevation,
			region.macro_elevation[index]
		)

		maximum_ridge = maxf(
			maximum_ridge,
			ridge
		)

		maximum_trench = maxf(
			maximum_trench,
			trench
		)

	_expect_equal(
		invalid_range_count,
		0,
		"All normalized geology channels stay in range."
	)

	_expect_equal(
		trench_without_compression,
		0,
		"Trench potential always has compression."
	)

	_expect_equal(
		divergent_relief_without_divergent_class,
		0,
		"Divergent relief only occurs at divergent boundaries."
	)

	_expect_equal(
		volcanism_without_cause,
		0,
		"Volcanic potential always has a geological cause."
	)

	_expect_true(
		maximum_continental - minimum_continental > 0.20,
		"Survey region contains continental variation."
	)

	_expect_true(
		maximum_elevation - minimum_elevation > 40.0,
		"Survey region contains meaningful macro relief."
	)

	_expect_true(
		maximum_ridge > 0.01,
		"Survey region contains ridge potential."
	)

	_expect_true(
		maximum_trench > 0.01,
		"Survey region contains trench potential."
	)


func _begin_async_test() -> void:
	var settings := ChunkGenerationSettings.new()
	settings.background_workers_enabled = true
	settings.max_pending_requests = 4
	settings.max_concurrent_jobs = 2
	settings.max_completed_results = 3
	settings.dispatch_budget_per_frame = 2
	settings.presentation_budget_per_frame = 1

	_async_scheduler = ChunkGenerationScheduler.new(settings)

	var coordinates: Array[Vector2i] = [
		Vector2i(-1, 0),
		Vector2i(0, 0),
		Vector2i(1, 0)
	]

	var request_id := 100

	for coordinate in coordinates:
		var snapshot := _make_terrain_snapshot(
			request_id,
			coordinate
		)

		_async_expected[coordinate] = (
			TerrainSampler.generate_from_snapshot(
				snapshot
			)
		)

		_expect_true(
			_async_scheduler.enqueue(snapshot),
			"Geological async request enqueued."
		)

		request_id += 1

	_expect_equal(
		_async_scheduler.dispatch(),
		2,
		"Geological jobs respect concurrency limit."
	)

	_async_started_usec = Time.get_ticks_usec()


func _consume_async_result() -> void:
	var result := _async_scheduler.take_next_result()

	_expect_true(
		result != null,
		"Geological async result is available."
	)

	if result == null:
		return

	var coordinate := result.snapshot.chunk_coordinate

	_expect_equal(
		result.status,
		TerrainGenerationResult.STATUS_SUCCEEDED,
		"Geological async job succeeds."
	)

	var expected: TerrainChunkData = (
		_async_expected[coordinate]
	)

	_expect_true(
		_float_arrays_equal(
			result.chunk_data.height_values,
			expected.height_values
		),
		"Async geological terrain matches synchronous terrain."
	)

	_expect_true(
		_geology_equal(
			result.chunk_data.geology_data,
			expected.geology_data
		),
		"Async geological channels match synchronous channels."
	)

	_async_results[coordinate] = (
		result.chunk_data
	)

	_async_scheduler.acknowledge_result(
		result,
		ChunkGenerationJob.STATE_PRESENTED
	)


func _finish_async_test() -> void:
	_expect_true(
		_maximum_running_seen <= 2,
		"Geological workers remain bounded."
	)

	_expect_true(
		_maximum_completed_seen <= 3,
		"Geological completion queue remains bounded."
	)

	_expect_equal(
		_async_scheduler.get_mailbox_overflow_count(),
		0,
		"Geological completion mailbox does not overflow."
	)

	if (
		_async_results.has(Vector2i(-1, 0))
		and _async_results.has(Vector2i(0, 0))
		and _async_results.has(Vector2i(1, 0))
	):
		var negative: TerrainChunkData = (
			_async_results[Vector2i(-1, 0)]
		)

		var origin: TerrainChunkData = (
			_async_results[Vector2i(0, 0)]
		)

		var positive: TerrainChunkData = (
			_async_results[Vector2i(1, 0)]
		)

		var async_borders_match := true

		for local_z in range(
			origin.cells_per_axis + 1
		):
			if (
				negative.get_height(
					negative.cells_per_axis,
					local_z
				)
				!= origin.get_height(0, local_z)
				or origin.get_height(
					origin.cells_per_axis,
					local_z
				)
				!= positive.get_height(0, local_z)
			):
				async_borders_match = false
				break

		_expect_true(
			async_borders_match,
			"Concurrent geological terrain borders match."
		)
	else:
		_expect_true(
			false,
			"All geological async chunks completed."
		)

	_async_scheduler.shutdown()
	_async_scheduler = null

	if _failure_count == 0:
		print(
			"Session 6 tests passed: %d assertions."
			% _assertion_count
		)
	else:
		push_error(
			"Session 6 tests failed: %d of %d assertions failed."
			% [
				_failure_count,
				_assertion_count
			]
		)

	get_tree().quit(
		_failure_count
	)


func _make_geology_snapshot() -> GeologyGenerationSnapshot:
	var settings := GeologySettings.new()

	var geology_seed := StableSeed.derive_subsystem_seed(
		1337,
		2,
		WorldSubsystemIds.GEOLOGY
	)

	return GeologyGenerationSnapshot.from_settings(
		geology_seed,
		settings
	)


func _make_terrain_snapshot(
	request_id: int,
	coordinate: Vector2i
) -> TerrainGenerationSnapshot:
	var terrain_seed := StableSeed.derive_subsystem_seed(
		1337,
		2,
		WorldSubsystemIds.TERRAIN
	)

	return TerrainGenerationSnapshot.new(
		request_id,
		100,
		coordinate,
		2,
		terrain_seed,
		64.0,
		8,
		140.0,
		18.0,
		0.006,
		Time.get_ticks_usec(),
		_make_geology_snapshot()
	)


func _vertical_geology_edge_equal(
	west: GeologyChunkData,
	east: GeologyChunkData
) -> bool:
	for local_z in range(
		west.cells_per_axis + 1
	):
		if not _geology_sample_equal(
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
			return false

	return true


func _horizontal_geology_edge_equal(
	north: GeologyChunkData,
	south: GeologyChunkData
) -> bool:
	for local_x in range(
		north.cells_per_axis + 1
	):
		if not _geology_sample_equal(
			north,
			north.get_index(
				local_x,
				north.cells_per_axis
			),
			south,
			south.get_index(
				local_x,
				0
			)
		):
			return false

	return true


func _geology_equal(
	first: GeologyChunkData,
	second: GeologyChunkData
) -> bool:
	if first == null or second == null:
		return false

	return (
		first.primary_plate_ids
		== second.primary_plate_ids
		and first.neighboring_plate_ids
		== second.neighboring_plate_ids
		and first.boundary_classes
		== second.boundary_classes
		and first.continental_affinity
		== second.continental_affinity
		and first.boundary_proximity
		== second.boundary_proximity
		and first.compression_strength
		== second.compression_strength
		and first.extension_strength
		== second.extension_strength
		and first.shear_strength
		== second.shear_strength
		and first.ridge_influence
		== second.ridge_influence
		and first.rift_influence
		== second.rift_influence
		and first.ridge_potential
		== second.ridge_potential
		and first.rift_potential
		== second.rift_potential
		and first.ridge_elevation_contribution
		== second.ridge_elevation_contribution
		and first.rift_elevation_contribution
		== second.rift_elevation_contribution
		and first.trench_potential
		== second.trench_potential
		and first.volcanic_potential
		== second.volcanic_potential
		and first.sediment_potential
		== second.sediment_potential
		and first.macro_elevation
		== second.macro_elevation
	)


func _geology_sample_equal(
	first: GeologyChunkData,
	first_index: int,
	second: GeologyChunkData,
	second_index: int
) -> bool:
	return (
		first.primary_plate_ids[first_index]
		== second.primary_plate_ids[second_index]
		and first.neighboring_plate_ids[first_index]
		== second.neighboring_plate_ids[second_index]
		and first.boundary_classes[first_index]
		== second.boundary_classes[second_index]
		and first.continental_affinity[first_index]
		== second.continental_affinity[second_index]
		and first.boundary_proximity[first_index]
		== second.boundary_proximity[second_index]
		and first.compression_strength[first_index]
		== second.compression_strength[second_index]
		and first.extension_strength[first_index]
		== second.extension_strength[second_index]
		and first.shear_strength[first_index]
		== second.shear_strength[second_index]
		and first.ridge_influence[first_index]
		== second.ridge_influence[second_index]
		and first.rift_influence[first_index]
		== second.rift_influence[second_index]
		and first.ridge_potential[first_index]
		== second.ridge_potential[second_index]
		and first.rift_potential[first_index]
		== second.rift_potential[second_index]
		and first.ridge_elevation_contribution[first_index]
		== second.ridge_elevation_contribution[second_index]
		and first.rift_elevation_contribution[first_index]
		== second.rift_elevation_contribution[second_index]
		and first.trench_potential[first_index]
		== second.trench_potential[second_index]
		and first.volcanic_potential[first_index]
		== second.volcanic_potential[second_index]
		and first.sediment_potential[first_index]
		== second.sediment_potential[second_index]
		and first.macro_elevation[first_index]
		== second.macro_elevation[second_index]
	)


func _float_arrays_equal(
	first: PackedFloat32Array,
	second: PackedFloat32Array
) -> bool:
	if first.size() != second.size():
		return false

	for index in range(
		first.size()
	):
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
			% [
				description,
				str(expected),
				str(actual)
			]
		)


func _expect_true(
	condition: bool,
	description: String
) -> void:
	_assertion_count += 1

	if not condition:
		_failure_count += 1

		push_error(
			"FAIL: %s"
			% description
		)
