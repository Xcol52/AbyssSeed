class_name ChunkGenerationScheduler
extends RefCounted

var _background_workers_enabled: bool
var _max_pending_requests: int
var _max_concurrent_jobs: int
var _max_completed_results: int
var _dispatch_budget_per_frame: int

var _accepting_requests: bool = true
var _shutdown_complete: bool = false

var _mailbox: TerrainResultMailbox

var _pending_jobs: Array[ChunkGenerationJob] = []

## request_id -> ChunkGenerationJob
var _jobs_by_request_id: Dictionary = {}

## chunk coordinate -> current request_id
var _current_request_by_coordinate: Dictionary = {}

## WorkerThreadPool task_id -> ChunkGenerationJob
var _running_by_task_id: Dictionary = {}

## Every dispatched job reserves exactly one future completion slot.
##
## This avoids double-counting a fast job that is simultaneously:
## - still present in _running_by_task_id, and
## - already represented by a result in the mailbox.
##
## A reservation is released only when the main thread takes that result.
var _reserved_completion_slots: int = 0


func _init(
	settings: ChunkGenerationSettings
) -> void:
	assert(settings != null)
	assert(settings.validate().is_empty())

	_background_workers_enabled = (
		settings.background_workers_enabled
	)
	_max_pending_requests = settings.max_pending_requests
	_max_concurrent_jobs = settings.max_concurrent_jobs
	_max_completed_results = (
		settings.max_completed_results
	)
	_dispatch_budget_per_frame = (
		settings.dispatch_budget_per_frame
	)

	_mailbox = TerrainResultMailbox.new(
		_max_completed_results
	)


func enqueue(
	snapshot: TerrainGenerationSnapshot
) -> bool:
	if not _accepting_requests:
		return false

	if snapshot == null:
		return false

	if not snapshot.get_validation_error().is_empty():
		return false

	if _pending_jobs.size() >= _max_pending_requests:
		return false

	if has_request_for_coordinate(
		snapshot.chunk_coordinate
	):
		return false

	var job := ChunkGenerationJob.new(snapshot)

	_pending_jobs.append(job)
	_jobs_by_request_id[snapshot.request_id] = job
	_current_request_by_coordinate[
		snapshot.chunk_coordinate
	] = snapshot.request_id

	return true


func has_request_for_coordinate(
	chunk_coordinate: Vector2i
) -> bool:
	return _current_request_by_coordinate.has(
		chunk_coordinate
	)


func get_current_request_id(
	chunk_coordinate: Vector2i
) -> int:
	return int(
		_current_request_by_coordinate.get(
			chunk_coordinate,
			-1
		)
	)


func can_accept_more_pending() -> bool:
	return (
		_accepting_requests
		and _pending_jobs.size()
		< _max_pending_requests
	)


func cancel_requests_not_in(
	desired_coordinate_set: Dictionary
) -> void:
	# Pending jobs can be removed before execution.
	for index in range(
		_pending_jobs.size() - 1,
		-1,
		-1
	):
		var pending_job: ChunkGenerationJob = (
			_pending_jobs[index]
		)
		var coordinate := (
			pending_job.snapshot.chunk_coordinate
		)

		if desired_coordinate_set.has(coordinate):
			continue

		pending_job.state = (
			ChunkGenerationJob.STATE_CANCELLED
		)

		_pending_jobs.remove_at(index)
		_release_current_request(pending_job)
		_jobs_by_request_id.erase(
			pending_job.snapshot.request_id
		)

	# Running or ready jobs are logically cancelled. Their worker is not
	# forcibly terminated. Any eventual result will fail freshness checks.
	var remaining_jobs: Array = (
		_jobs_by_request_id.values()
	)

	for job_value in remaining_jobs:
		var job: ChunkGenerationJob = (
			job_value as ChunkGenerationJob
		)

		if job == null:
			continue

		var coordinate := job.snapshot.chunk_coordinate

		if desired_coordinate_set.has(coordinate):
			continue

		job.obsolete = true
		_release_current_request(job)


func reorder_pending(
	prioritized_coordinates: Array[Vector2i]
) -> void:
	var job_by_coordinate: Dictionary = {}

	for job in _pending_jobs:
		job_by_coordinate[
			job.snapshot.chunk_coordinate
		] = job

	var reordered: Array[ChunkGenerationJob] = []

	for coordinate in prioritized_coordinates:
		if not job_by_coordinate.has(coordinate):
			continue

		var job: ChunkGenerationJob = (
			job_by_coordinate[coordinate]
			as ChunkGenerationJob
		)

		if job == null:
			continue

		reordered.append(job)
		job_by_coordinate.erase(coordinate)

	# Preserve the existing order for jobs absent from the supplied
	# priority list.
	for job in _pending_jobs:
		var coordinate := job.snapshot.chunk_coordinate

		if job_by_coordinate.has(coordinate):
			reordered.append(job)
			job_by_coordinate.erase(coordinate)

	_pending_jobs = reordered


func dispatch() -> int:
	if not _accepting_requests:
		return 0

	poll()

	var available_running_slots := _pending_jobs.size()

	if _background_workers_enabled:
		available_running_slots = maxi(
			0,
			_max_concurrent_jobs
			- _running_by_task_id.size()
		)

	var available_completion_slots := maxi(
		0,
		_max_completed_results
		- _reserved_completion_slots
	)

	# Admission is calculated once so worker timing cannot change how
	# many jobs this dispatch pass accepts.
	var jobs_to_dispatch := mini(
		_dispatch_budget_per_frame,
		_pending_jobs.size()
	)

	jobs_to_dispatch = mini(
		jobs_to_dispatch,
		available_running_slots
	)

	jobs_to_dispatch = mini(
		jobs_to_dispatch,
		available_completion_slots
	)

	var dispatched := 0

	for _dispatch_index in range(jobs_to_dispatch):
		var job: ChunkGenerationJob = _pending_jobs[0]
		_pending_jobs.remove_at(0)

		_reserved_completion_slots += 1

		job.state = ChunkGenerationJob.STATE_RUNNING
		job.worker = TerrainGenerationWorker.new()

		if _background_workers_enabled:
			var description := "Terrain %d,%d" % [
				job.snapshot.chunk_coordinate.x,
				job.snapshot.chunk_coordinate.y
			]

			var task_id: int = WorkerThreadPool.add_task(
				job.worker.execute.bind(
					job.snapshot,
					_mailbox
				),
				false,
				description
			)

			if task_id < 0:
				_mailbox.publish(
					TerrainGenerationResult.create_failure(
						job.snapshot,
						"WorkerThreadPool rejected the task.",
						0
					)
				)

				job.worker = null
			else:
				job.task_id = task_id
				_running_by_task_id[task_id] = job
		else:
			job.worker.execute(
				job.snapshot,
				_mailbox
			)

			job.worker = null

		dispatched += 1

	return dispatched


## Main-thread maintenance for WorkerThreadPool task handles.
func poll() -> void:
	if not _background_workers_enabled:
		return

	var task_ids: Array = _running_by_task_id.keys()

	for task_value in task_ids:
		var task_id := int(task_value)

		if not WorkerThreadPool.is_task_completed(
			task_id
		):
			continue

		var job: ChunkGenerationJob = (
			_running_by_task_id[task_id]
			as ChunkGenerationJob
		)

		var completion_error: Error = (
			WorkerThreadPool.wait_for_task_completion(
				task_id
			)
		)

		_running_by_task_id.erase(task_id)

		if job == null:
			continue

		job.worker = null

		# A result can be removed before this task handle is retired.
		# result_received accounts for that valid ordering.
		var result_exists := (
			job.result_received
			or _mailbox.contains_request_id(
				job.snapshot.request_id
			)
		)

		if completion_error != OK or not result_exists:
			# This uses the existing reservation for the job. It does
			# not create a second reserved slot.
			_mailbox.publish(
				TerrainGenerationResult.create_failure(
					job.snapshot,
					(
						"Worker task completed without "
						+ "a valid result."
					),
					0
				)
			)


func take_next_result() -> TerrainGenerationResult:
	var result: TerrainGenerationResult = (
		_mailbox.take_next()
	)

	if result == null:
		return null

	# The result now belongs to the main thread, so the scheduler may
	# reserve this capacity for another dispatched job.
	_reserved_completion_slots = maxi(
		0,
		_reserved_completion_slots - 1
	)

	var request_id := result.snapshot.request_id

	if _jobs_by_request_id.has(request_id):
		var job: ChunkGenerationJob = (
			_jobs_by_request_id[request_id]
			as ChunkGenerationJob
		)

		if job != null:
			job.result_received = true

			if job.obsolete:
				job.state = (
					ChunkGenerationJob.STATE_STALE
				)
			elif (
				result.status
				== TerrainGenerationResult.STATUS_FAILED
			):
				job.state = (
					ChunkGenerationJob.STATE_FAILED
				)
			else:
				job.state = (
					ChunkGenerationJob.STATE_READY
				)

	return result


func acknowledge_result(
	result: TerrainGenerationResult,
	final_state: int
) -> void:
	if result == null or result.snapshot == null:
		return

	var request_id := result.snapshot.request_id

	if _jobs_by_request_id.has(request_id):
		var job: ChunkGenerationJob = (
			_jobs_by_request_id[request_id]
			as ChunkGenerationJob
		)

		if job != null:
			job.state = final_state
			_release_current_request(job)

		_jobs_by_request_id.erase(request_id)


func get_pending_coordinates() -> Array[Vector2i]:
	var coordinates: Array[Vector2i] = []

	for job in _pending_jobs:
		coordinates.append(
			job.snapshot.chunk_coordinate
		)

	return coordinates


func get_pending_count() -> int:
	return _pending_jobs.size()


func get_running_count() -> int:
	return _running_by_task_id.size()


func get_completed_count() -> int:
	return _mailbox.get_count()


func get_reserved_completion_count() -> int:
	return _reserved_completion_slots


func get_mailbox_overflow_count() -> int:
	return _mailbox.get_overflow_count()


func get_job_state(request_id: int) -> int:
	if not _jobs_by_request_id.has(request_id):
		return -1

	var job: ChunkGenerationJob = (
		_jobs_by_request_id[request_id]
		as ChunkGenerationJob
	)

	if job == null:
		return -1

	return job.state


func is_background_mode() -> bool:
	return _background_workers_enabled


func shutdown() -> void:
	if _shutdown_complete:
		return

	_accepting_requests = false

	for job in _pending_jobs:
		job.state = ChunkGenerationJob.STATE_CANCELLED
		_release_current_request(job)

	_pending_jobs.clear()

	for job_value in _running_by_task_id.values():
		var running_job: ChunkGenerationJob = (
			job_value as ChunkGenerationJob
		)

		if running_job == null:
			continue

		running_job.obsolete = true
		_release_current_request(running_job)

	# Teardown may briefly block, but the running set is finite and
	# bounded by max_concurrent_jobs.
	var task_ids: Array = _running_by_task_id.keys()

	for task_value in task_ids:
		var task_id := int(task_value)

		WorkerThreadPool.wait_for_task_completion(
			task_id
		)

	_running_by_task_id.clear()
	_current_request_by_coordinate.clear()
	_jobs_by_request_id.clear()
	_mailbox.clear()

	_reserved_completion_slots = 0
	_shutdown_complete = true


func _release_current_request(
	job: ChunkGenerationJob
) -> void:
	var coordinate := job.snapshot.chunk_coordinate
	var current_id := get_current_request_id(coordinate)

	if current_id == job.snapshot.request_id:
		_current_request_by_coordinate.erase(
			coordinate
		)
