extends Node

var _assertion_count: int = 0
var _failure_count: int = 0

var _async_scheduler: ChunkGenerationScheduler
var _async_expected: Dictionary = {}
var _async_results: Dictionary = {}

var _async_phase: int = 0
var _async_started_usec: int = 0
var _maximum_running_seen: int = 0
var _maximum_completed_seen: int = 0


func _ready() -> void:
	_test_snapshot_isolation()
	_test_synchronous_scheduler_bounds()
	_test_stale_result_validation()
	_test_profiler()
	_begin_async_scheduler_test()


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

	if (
		Time.get_ticks_usec() - _async_started_usec
		> 10_000_000
	):
		_expect_true(
			false,
			"Async scheduler completed before timeout."
		)
		_finish_async_test()
		return

	if _async_phase == 0:
		# Wait until both reserved completion slots are occupied.
		if _async_scheduler.get_completed_count() < 2:
			return

		_expect_equal(
			_async_scheduler.dispatch(),
			0,
			"Completed-result backpressure prevents further dispatch."
		)

		_consume_one_async_result()
		_async_phase = 1

	if _async_phase == 1:
		while _async_scheduler.get_completed_count() > 0:
			_consume_one_async_result()

		_async_scheduler.dispatch()

		if (
			_async_results.size() == 3
			and _async_scheduler.get_pending_count() == 0
			and _async_scheduler.get_running_count() == 0
			and _async_scheduler.get_completed_count() == 0
		):
			_finish_async_test()


func _test_snapshot_isolation() -> void:
	var grid := WorldGridSettings.new()
	grid.chunk_size = 64.0
	grid.cells_per_axis = 8

	var terrain := TerrainSettings.new()
	terrain.base_seabed_depth = 120.0
	terrain.test_elevation_amplitude = 10.0
	terrain.test_noise_frequency = 0.01

	var snapshot := TerrainGenerationSnapshot.new(
		1,
		100,
		Vector2i(-2, 3),
		1,
		12345,
		grid.chunk_size,
		grid.cells_per_axis,
		terrain.base_seabed_depth,
		terrain.test_elevation_amplitude,
		terrain.test_noise_frequency,
		0
	)

	grid.chunk_size = 999.0
	grid.cells_per_axis = 2
	terrain.base_seabed_depth = 999.0

	_expect_equal(
		snapshot.chunk_size,
		64.0,
		"Snapshot copied chunk size."
	)
	_expect_equal(
		snapshot.cells_per_axis,
		8,
		"Snapshot copied cell count."
	)
	_expect_equal(
		snapshot.base_seabed_depth,
		120.0,
		"Snapshot copied terrain depth."
	)
	_expect_true(
		snapshot.get_validation_error().is_empty(),
		"Copied snapshot is valid."
	)


func _test_synchronous_scheduler_bounds() -> void:
	var settings := ChunkGenerationSettings.new()
	settings.background_workers_enabled = false
	settings.max_pending_requests = 2
	settings.max_concurrent_jobs = 1
	settings.max_completed_results = 1
	settings.dispatch_budget_per_frame = 1
	settings.presentation_budget_per_frame = 1

	var scheduler := ChunkGenerationScheduler.new(settings)

	var first := _make_snapshot(1, Vector2i(0, 0))
	var duplicate_snapshot := _make_snapshot(
	2,
	Vector2i(0, 0)
)
	var second := _make_snapshot(3, Vector2i(1, 0))
	var third := _make_snapshot(4, Vector2i(2, 0))

	_expect_true(
		scheduler.enqueue(first),
		"First request enters scheduler."
	)
	_expect_true(
	not scheduler.enqueue(duplicate_snapshot),
	"Duplicate coordinate is rejected."
)
	_expect_true(
		scheduler.enqueue(second),
		"Second unique request enters scheduler."
	)
	_expect_true(
		not scheduler.enqueue(third),
		"Pending queue bound is enforced."
	)
	_expect_equal(
		scheduler.get_pending_count(),
		2,
		"Pending count remains bounded."
	)

	_expect_equal(
		scheduler.dispatch(),
		1,
		"Sync scheduler obeys dispatch budget."
	)
	_expect_equal(
		scheduler.get_completed_count(),
		1,
		"Sync execution publishes one result."
	)
	_expect_equal(
		scheduler.dispatch(),
		0,
		"Completed-result capacity applies backpressure."
	)

	var first_result := scheduler.take_next_result()

	_expect_true(
		first_result != null,
		"First result is collected."
	)
	_expect_true(
		first_result.chunk_data != null,
		"First result contains terrain data."
	)
	_expect_true(
		scheduler.take_next_result() == null,
		"Result is collected exactly once."
	)

	scheduler.acknowledge_result(
		first_result,
		ChunkGenerationJob.STATE_PRESENTED
	)

	_expect_equal(
		scheduler.dispatch(),
		1,
		"Capacity is restored after acknowledgement."
	)

	var second_result := scheduler.take_next_result()

	_expect_true(
		second_result != null,
		"Second result is collected."
	)

	scheduler.acknowledge_result(
		second_result,
		ChunkGenerationJob.STATE_PRESENTED
	)

	_expect_equal(
		scheduler.get_mailbox_overflow_count(),
		0,
		"Bounded mailbox does not overflow."
	)

	scheduler.shutdown()


func _test_stale_result_validation() -> void:
	var old_snapshot := _make_snapshot(
		10,
		Vector2i(4, 2)
	)
	var new_snapshot := _make_snapshot(
		11,
		Vector2i(4, 2)
	)

	var old_data := (
		TerrainSampler.generate_from_snapshot(
			old_snapshot
		)
	)

	var old_result := (
		TerrainGenerationResult.create_success(
			old_snapshot,
			old_data,
			1
		)
	)

	_expect_true(
		not TerrainResultValidator.is_current(
			old_result,
			false,
			false,
			10,
			100,
			1
		),
		"Result is rejected after coordinate leaves desired set."
	)

	_expect_true(
		not TerrainResultValidator.is_current(
			old_result,
			true,
			false,
			new_snapshot.request_id,
			100,
			1
		),
		"Older request cannot replace newer request."
	)

	_expect_true(
		not TerrainResultValidator.is_current(
			old_result,
			true,
			true,
			old_snapshot.request_id,
			100,
			1
		),
		"Already active coordinate rejects another result."
	)

	_expect_true(
		not TerrainResultValidator.is_current(
			old_result,
			true,
			false,
			old_snapshot.request_id,
			101,
			1
		),
		"Wrong world session is rejected."
	)

	_expect_true(
		not TerrainResultValidator.is_current(
			old_result,
			true,
			false,
			old_snapshot.request_id,
			100,
			2
		),
		"Wrong generation version is rejected."
	)

	_expect_true(
		TerrainResultValidator.is_current(
			old_result,
			true,
			false,
			old_snapshot.request_id,
			100,
			1
		),
		"Matching current result is accepted."
	)


func _test_profiler() -> void:
	var profiler := GenerationProfiler.new(
		true,
		"test"
	)

	profiler.record_sampling(1000)
	profiler.record_presented_chunk(
		1000,
		2000,
		500,
		4000
	)
	profiler.record_generation_frame(3500)
	profiler.record_stale_result()
	profiler.update_counts(4, 2, 1, 25)

	var report := profiler.create_report()

	_expect_true(
		report.contains("Sampling"),
		"Profiler reports sampling metric."
	)
	_expect_true(
		report.contains("pending=4"),
		"Profiler reports pending high-water count."
	)
	_expect_true(
		report.contains("stale=1"),
		"Profiler reports stale results."
	)

	profiler.reset()

	_expect_true(
		profiler.create_report().contains("count=0"),
		"Profiler reset clears metrics."
	)


func _begin_async_scheduler_test() -> void:
	var settings := ChunkGenerationSettings.new()

	settings.background_workers_enabled = true
	settings.max_pending_requests = 4
	settings.max_concurrent_jobs = 2
	settings.max_completed_results = 2

	# The test expects the first dispatch call to admit two jobs.
	settings.dispatch_budget_per_frame = 2

	settings.presentation_budget_per_frame = 1

	_async_scheduler = ChunkGenerationScheduler.new(settings)

	_async_expected.clear()
	_async_results.clear()
	_async_phase = 0
	_maximum_running_seen = 0
	_maximum_completed_seen = 0

	var coordinates: Array[Vector2i] = [
		Vector2i(-1, 0),
		Vector2i(0, 0),
		Vector2i(1, 0)
	]

	var request_id := 100

	for coordinate in coordinates:
		var snapshot := _make_snapshot(
			request_id,
			coordinate
		)

		var expected := (
			TerrainSampler.generate_from_snapshot(
				snapshot
			)
		)

		_async_expected[coordinate] = expected

		_expect_true(
			_async_scheduler.enqueue(snapshot),
			"Async request enqueued for %s."
			% str(coordinate)
		)

		request_id += 1

	_expect_equal(
		_async_scheduler.dispatch(),
		2,
		"Async scheduler dispatches up to concurrency limit."
	)

	_async_started_usec = Time.get_ticks_usec()
	set_process(true)


func _consume_one_async_result() -> void:
	var result := _async_scheduler.take_next_result()

	_expect_true(
		result != null,
		"Async completed result is available."
	)

	if result == null:
		return

	var coordinate := result.snapshot.chunk_coordinate

	_expect_equal(
		result.status,
		TerrainGenerationResult.STATUS_SUCCEEDED,
		"Async terrain job succeeds."
	)

	var expected: TerrainChunkData = (
		_async_expected[coordinate]
	)

	_expect_true(
		_packed_float_arrays_equal(
			result.chunk_data.height_values,
			expected.height_values
		),
		"Async output exactly matches synchronous output."
	)

	_async_results[coordinate] = result.chunk_data

	_async_scheduler.acknowledge_result(
		result,
		ChunkGenerationJob.STATE_PRESENTED
	)


func _finish_async_test() -> void:
	_expect_true(
		_maximum_running_seen <= 2,
		"Concurrent running jobs never exceed limit."
	)
	_expect_true(
		_maximum_completed_seen <= 2,
		"Completed-result queue never exceeds limit."
	)
	_expect_equal(
		_async_scheduler.get_mailbox_overflow_count(),
		0,
		"Async completion mailbox never overflows."
	)
	_expect_true(
		_async_scheduler.take_next_result() == null,
		"All async results are collected exactly once."
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

		for local_z in range(
			origin.cells_per_axis + 1
		):
			_expect_equal(
				negative.get_height(
					negative.cells_per_axis,
					local_z
				),
				origin.get_height(0, local_z),
				"Concurrent negative/origin border at Z=%d."
				% local_z
			)

			_expect_equal(
				origin.get_height(
					origin.cells_per_axis,
					local_z
				),
				positive.get_height(0, local_z),
				"Concurrent origin/positive border at Z=%d."
				% local_z
			)
	else:
		_expect_true(
			false,
			"All async terrain chunks completed."
		)

	_async_scheduler.shutdown()
	_async_scheduler = null
	set_process(false)

	if _failure_count == 0:
		print(
			"Session 5 tests passed: %d assertions."
			% _assertion_count
		)
	else:
		push_error(
			"Session 5 tests failed: %d of %d assertions failed."
			% [_failure_count, _assertion_count]
		)

	get_tree().quit(_failure_count)


func _make_snapshot(
	request_id: int,
	coordinate: Vector2i
) -> TerrainGenerationSnapshot:
	return TerrainGenerationSnapshot.new(
		request_id,
		100,
		coordinate,
		1,
		12345,
		64.0,
		8,
		120.0,
		10.0,
		0.01,
		Time.get_ticks_usec()
	)


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
