class_name FloraCoordinator
extends Node

class ChunkRecord:
	extends RefCounted

	var coordinate: Vector2i
	var terrain_data: TerrainChunkData

	var activation_token: int
	var request_revision: int = 1
	var request_sequence: int = 0

	var ring: int = 999999

	var active: bool = true
	var pending: bool = false
	var running: bool = false
	var generation_failed: bool = false

	var flora_data: FloraChunkData

	var presenter: FloraChunkPresenter
	var presented_divisor: int = 0
	var presentation_resolved: bool = false

	var build: PresentationBuild


	func _init(
		new_coordinate: Vector2i,
		new_terrain_data: TerrainChunkData,
		new_activation_token: int,
		new_request_sequence: int
	) -> void:
		coordinate = new_coordinate
		terrain_data = new_terrain_data
		activation_token = new_activation_token
		request_sequence = new_request_sequence


class RunningTask:
	extends RefCounted

	var task_id: int
	var coordinate: Vector2i
	var activation_token: int
	var request_revision: int


	func _init(
		new_task_id: int,
		new_coordinate: Vector2i,
		new_activation_token: int,
		new_request_revision: int
	) -> void:
		task_id = new_task_id
		coordinate = new_coordinate
		activation_token = new_activation_token
		request_revision = new_request_revision


class PresentationBuild:
	extends RefCounted

	var record: ChunkRecord
	var presenter: FloraChunkPresenter

	var activation_token: int
	var request_revision: int
	var thinning_divisor: int


	func _init(
		new_record: ChunkRecord,
		new_presenter: FloraChunkPresenter,
		new_thinning_divisor: int
	) -> void:
		record = new_record
		presenter = new_presenter

		activation_token = new_record.activation_token
		request_revision = new_record.request_revision
		thinning_divisor = new_thinning_divisor


@export_group("Background generation")

@export_range(1, 4, 1)
var maximum_concurrent_jobs: int = 1

@export_range(1, 128, 1)
var maximum_pending_requests: int = 32

@export_range(1, 32, 1)
var maximum_completed_results: int = 8


@export_group("Priority rings")

## Chebyshev chunk distance from the observer.
@export_range(0, 16, 1)
var maximum_generation_ring: int = 3

@export_range(0, 16, 1)
var maximum_presentation_ring: int = 3

@export_range(0, 16, 1)
var full_density_ring: int = 1

@export_range(1, 16, 1)
var middle_ring_divisor: int = 2

@export_range(1, 32, 1)
var outer_ring_divisor: int = 4


@export_group("Main-thread presentation")

@export_range(100, 10000, 100)
var presentation_budget_usec: int = 1500

@export_range(1, 4096, 1)
var maximum_presentation_work_items: int = 192

@export_range(0, 5, 1)
var maximum_multimesh_allocations: int = 1


@export_group("Visibility")

## Zero leaves visibility distance under ring control only.
## A later fog system can override this at runtime.
@export_range(0.0, 32.0, 0.25)
var visual_distance_chunks: float = 0.0

@export var print_chunk_counts: bool = false


var _initialized: bool = false

var _chunk_coordinator: ChunkCoordinator
var _flora_root: Node3D
var _observer: Node3D

var _chunk_size: float = 0.0
var _flora_seed: int = 0

var _environment_snapshot: EnvironmentGenerationSnapshot
var _mailbox: FloraResultMailbox

var _observer_chunk := Vector2i(
	2147483647,
	2147483647
)

var _next_activation_token: int = 1
var _next_request_sequence: int = 1

## Vector2i -> ChunkRecord
var _records: Dictionary = {}

var _pending: Array[ChunkRecord] = []
var _running: Array[RunningTask] = []
var _completed: Array[FloraGenerationResult] = []
var _builds: Array[PresentationBuild] = []

## Vector2i -> bool
##
## Future darkness, fog-volume, portal, sonar, and occlusion systems can
## suppress a flora chunk without deleting its deterministic data.
var _chunk_render_overrides: Dictionary = {}

var _effective_visibility_distance: float = 0.0


func _ready() -> void:
	set_process(false)


func initialize(
	chunk_coordinator: ChunkCoordinator,
	flora_root: Node3D,
	observer: Node3D,
	world_seed: int,
	generation_version: int,
	chunk_size: float,
	environment_settings: EnvironmentSettings,
	sea_level: float
) -> bool:
	if _initialized:
		printerr(
			"FloraCoordinator can only be initialized once."
		)
		return false

	if (
		chunk_coordinator == null
		or not is_instance_valid(chunk_coordinator)
	):
		printerr(
			"FloraCoordinator requires ChunkCoordinator."
		)
		return false

	if (
		flora_root == null
		or not is_instance_valid(flora_root)
	):
		printerr(
			"FloraCoordinator requires FloraRoot."
		)
		return false

	if (
		observer == null
		or not is_instance_valid(observer)
	):
		printerr(
			"FloraCoordinator requires an observer."
		)
		return false

	if environment_settings == null:
		printerr(
			"FloraCoordinator requires EnvironmentSettings."
		)
		return false

	if not is_finite(chunk_size) or chunk_size <= 0.0:
		printerr(
			"FloraCoordinator requires a positive chunk size."
		)
		return false

	_chunk_coordinator = chunk_coordinator
	_flora_root = flora_root
	_observer = observer
	_chunk_size = chunk_size

	var environment_seed: int = (
		StableSeed.derive_subsystem_seed(
			world_seed,
			generation_version,
			WorldSubsystemIds.ENVIRONMENT
		)
	)

	_flora_seed = StableSeed.derive_subsystem_seed(
		world_seed,
		generation_version,
		WorldSubsystemIds.FLORA
	)

	_environment_snapshot = (
		EnvironmentGenerationSnapshot.new(
			environment_seed,
			sea_level,
			environment_settings.light_attenuation,
			environment_settings.surface_temperature_celsius,
			environment_settings.regional_temperature_variation,
			environment_settings.regional_temperature_frequency,
			environment_settings.depth_cooling_per_meter,
			environment_settings.minimum_deep_temperature_celsius,
			environment_settings.geothermal_temperature_increase,
			environment_settings.current_primary_frequency,
			environment_settings.current_detail_frequency,
			environment_settings.nutrient_variation_frequency,
			environment_settings.full_rock_slope_degrees,
			environment_settings.full_roughness_meters
		)
	)

	_mailbox = FloraResultMailbox.new(
		maximum_completed_results
	)

	if not _chunk_coordinator.chunk_activated.is_connected(
		_on_chunk_activated
	):
		_chunk_coordinator.chunk_activated.connect(
			_on_chunk_activated
		)

	if not _chunk_coordinator.chunk_deactivated.is_connected(
		_on_chunk_deactivated
	):
		_chunk_coordinator.chunk_deactivated.connect(
			_on_chunk_deactivated
		)

	_effective_visibility_distance = (
		visual_distance_chunks
		* _chunk_size
	)

	_update_observer_chunk(true)

	_initialized = true
	set_process(true)

	return true


func _process(_delta: float) -> void:
	if not _initialized:
		return

	_update_observer_chunk(false)
	_poll_completed_tasks()
	_consume_completed_results()
	_reconcile_all_records()
	_fill_pending_queue()
	_dispatch_background_jobs()
	_process_presentation_build()
	_update_presenter_visibility()


func _on_chunk_activated(
	chunk_coordinate: Vector2i,
	world_chunk: WorldChunk
) -> void:
	if not _initialized:
		return

	var terrain_data := _extract_terrain_data(
		world_chunk
	)

	if terrain_data == null:
		printerr(
			"Could not retrieve TerrainChunkData from %s."
			% str(chunk_coordinate)
		)
		return

	if _records.has(chunk_coordinate):
		_remove_record(chunk_coordinate)

	var record := ChunkRecord.new(
		chunk_coordinate,
		terrain_data,
		_next_activation_token,
		_next_request_sequence
	)

	_next_activation_token += 1
	_next_request_sequence += 1

	record.ring = _calculate_ring(
		chunk_coordinate
	)

	_records[chunk_coordinate] = record

	_reconcile_record(
		record,
		999999
	)


func _on_chunk_deactivated(
	chunk_coordinate: Vector2i
) -> void:
	if not _initialized:
		return

	_remove_record(chunk_coordinate)


func _update_observer_chunk(
	force: bool
) -> void:
	if (
		_observer == null
		or not is_instance_valid(_observer)
	):
		return

	var world_position: Vector3 = (
		_observer.global_position
	)

	var new_chunk := Vector2i(
		floori(world_position.x / _chunk_size),
		floori(world_position.z / _chunk_size)
	)

	if not force and new_chunk == _observer_chunk:
		return

	_observer_chunk = new_chunk

	for record_value in _records.values():
		var record := record_value as ChunkRecord

		if record == null:
			continue

		var previous_ring: int = record.ring

		record.ring = _calculate_ring(
			record.coordinate
		)

		_reconcile_record(
			record,
			previous_ring
		)


func _calculate_ring(
	chunk_coordinate: Vector2i
) -> int:
	var difference := (
		chunk_coordinate
		- _observer_chunk
	)

	return maxi(
		absi(difference.x),
		absi(difference.y)
	)


func _reconcile_all_records() -> void:
	for record_value in _records.values():
		var record := record_value as ChunkRecord

		if record == null or not record.active:
			continue

		_reconcile_record(
			record,
			record.ring
		)


func _reconcile_record(
	record: ChunkRecord,
	previous_ring: int
) -> void:
	if record == null or not record.active:
		return

	if record.ring > maximum_generation_ring:
		if previous_ring <= maximum_generation_ring:
			_invalidate_record_generation(record)

		_remove_record_presentation(record)
		return

	if (
		record.ring > maximum_presentation_ring
	):
		_cancel_record_build(record)
		_remove_record_presenter(record)
		record.presentation_resolved = false
		return

	if record.flora_data != null:
		_ensure_record_presentation(record)


func _invalidate_record_generation(
	record: ChunkRecord
) -> void:
	record.request_revision += 1
	record.pending = false
	record.generation_failed = false
	record.flora_data = null
	record.presentation_resolved = false

	_remove_record_from_pending(record)
	_cancel_record_build(record)
	_remove_record_presenter(record)


func _fill_pending_queue() -> void:
	if _pending.size() >= maximum_pending_requests:
		return

	var eligible: Array[ChunkRecord] = []

	for record_value in _records.values():
		var record := record_value as ChunkRecord

		if record == null:
			continue

		if (
			not record.active
			or record.ring > maximum_generation_ring
			or record.flora_data != null
			or record.pending
			or record.running
			or record.generation_failed
		):
			continue

		eligible.append(record)

	eligible.sort_custom(
		_record_has_higher_priority
	)

	for record in eligible:
		if _pending.size() >= maximum_pending_requests:
			break

		record.pending = true
		_pending.append(record)


func _dispatch_background_jobs() -> void:
	while (
		_running.size() < maximum_concurrent_jobs
		and not _pending.is_empty()
	):
		var best_index: int = (
			_find_best_pending_index()
		)

		if best_index < 0:
			return

		var record: ChunkRecord = (
			_pending[best_index]
		)

		_pending.remove_at(best_index)
		record.pending = false

		if (
			not record.active
			or record.ring > maximum_generation_ring
			or record.flora_data != null
			or record.running
		):
			continue

		var job_callable: Callable = (
			FloraGenerationJob.execute_and_publish.bind(
				record.coordinate,
				record.activation_token,
				record.request_revision,
				record.terrain_data,
				_environment_snapshot,
				_flora_seed,
				_mailbox
			)
		)

		var task_id: int = (
			WorkerThreadPool.add_task(
				job_callable,
				false,
				"Flora chunk %s"
				% str(record.coordinate)
			)
		)

		record.running = true

		_running.append(
			RunningTask.new(
				task_id,
				record.coordinate,
				record.activation_token,
				record.request_revision
			)
		)


func _poll_completed_tasks() -> void:
	for index in range(
		_running.size() - 1,
		-1,
		-1
	):
		var task: RunningTask = _running[index]

		if not WorkerThreadPool.is_task_completed(
			task.task_id
		):
			continue

		var completion_error: Error = (
			WorkerThreadPool.wait_for_task_completion(
				task.task_id
			)
		)

		var result: FloraGenerationResult = null
		if completion_error == OK:
			result = _mailbox.take_matching(
				task.coordinate,
				task.activation_token,
				task.request_revision
			)

		_running.remove_at(index)

		var current_record := (
			_records.get(task.coordinate)
			as ChunkRecord
		)

		if (
			current_record != null
			and current_record.activation_token
				== task.activation_token
		):
			current_record.running = false

		if result == null:
			continue

		if (
			_completed.size()
			>= maximum_completed_results
		):
			## The queue is bounded. A deterministic result can be
			## regenerated later if it is still needed.
			continue

		_completed.append(result)


func _consume_completed_results() -> void:
	while not _completed.is_empty():
		var result: FloraGenerationResult = (
			_completed[0]
		)

		_completed.remove_at(0)

		var record := (
			_records.get(result.chunk_coordinate)
			as ChunkRecord
		)

		if record == null or not record.active:
			continue

		if (
			record.activation_token
				!= result.activation_token
			or record.request_revision
				!= result.request_revision
		):
			continue

		if record.ring > maximum_generation_ring:
			continue

		if not result.succeeded():
			record.generation_failed = true

			printerr(
				"Flora generation failed for %s: %s"
				% [
					str(result.chunk_coordinate),
					result.error_message,
				]
			)
			continue

		record.flora_data = result.flora_data
		record.generation_failed = false
		record.presentation_resolved = false

		_ensure_record_presentation(record)


func _ensure_record_presentation(
	record: ChunkRecord
) -> void:
	if (
		record.flora_data == null
		or record.ring > maximum_presentation_ring
	):
		return

	var divisor: int = _get_ring_divisor(
		record.ring
	)

	if (
		record.presentation_resolved
		and record.presented_divisor == divisor
	):
		return

	if (
		record.build != null
		and record.build.thinning_divisor == divisor
	):
		return

	_cancel_record_build(record)

	if (
		record.flora_data.get_candidate_count()
		== 0
	):
		record.presented_divisor = divisor
		record.presentation_resolved = true
		return

	var presenter := FloraChunkPresenter.new()

	if not presenter.initialize(record.flora_data):
		presenter.free()
		return

	presenter.set_visibility_distance(
		_effective_visibility_distance
	)

	var build := PresentationBuild.new(
		record,
		presenter,
		divisor
	)

	record.build = build
	_builds.append(build)


func _process_presentation_build() -> void:
	if _builds.is_empty():
		return

	var best_index: int = (
		_find_best_build_index()
	)

	if best_index < 0:
		return

	var build: PresentationBuild = (
		_builds[best_index]
	)

	var record: ChunkRecord = build.record

	if not _is_build_current(build):
		_remove_build_at(best_index, true)
		return

	_builds.remove_at(best_index)
	record.build = null

	var old_presenter: FloraChunkPresenter = (
		record.presenter
	)

	_flora_root.add_child(
		build.presenter
	)

	record.presenter = build.presenter
	record.presented_divisor = (
		build.thinning_divisor
	)

	record.presentation_resolved = true

	if (
		old_presenter != null
		and is_instance_valid(old_presenter)
	):
		old_presenter.queue_free()

	_update_record_visibility(record)

	if print_chunk_counts:
		print(
			"Flora %s: authoritative=%d rendered=%d "
			+ "ring=%d divisor=%d"
			% [
				str(record.coordinate),
				record.flora_data.get_candidate_count(),
				record.presenter
					.get_total_instance_count(),
				record.ring,
				record.presented_divisor,
			]
		)


func _is_build_current(
	build: PresentationBuild
) -> bool:
	if build == null or build.record == null:
		return false

	var record: ChunkRecord = build.record

	return (
		record.active
		and _records.get(record.coordinate) == record
		and record.activation_token
			== build.activation_token
		and record.request_revision
			== build.request_revision
		and record.ring
			<= maximum_presentation_ring
		and _get_ring_divisor(record.ring)
			== build.thinning_divisor
	)


func _get_ring_divisor(
	ring: int
) -> int:
	if ring <= full_density_ring:
		return 1

	if ring <= full_density_ring + 1:
		return maxi(
			middle_ring_divisor,
			1
		)

	return maxi(
		outer_ring_divisor,
		1
	)


func _find_best_pending_index() -> int:
	var best_index: int = -1

	for index in range(_pending.size()):
		var record: ChunkRecord = _pending[index]

		if not record.active or not record.pending:
			continue

		if best_index < 0:
			best_index = index
			continue

		if _record_has_higher_priority(
			record,
			_pending[best_index]
		):
			best_index = index

	return best_index


func _find_best_build_index() -> int:
	var best_index: int = -1

	for index in range(_builds.size()):
		var build: PresentationBuild = _builds[index]

		if not _is_build_current(build):
			if best_index < 0:
				best_index = index
			continue

		if best_index < 0:
			best_index = index
			continue

		var current_best: PresentationBuild = (
			_builds[best_index]
		)

		if (
			not _is_build_current(current_best)
			or build.record.ring
				< current_best.record.ring
			or (
				build.record.ring
					== current_best.record.ring
				and build.record.request_sequence
					< current_best.record.request_sequence
			)
		):
			best_index = index

	return best_index


static func _record_has_higher_priority(
	left: ChunkRecord,
	right: ChunkRecord
) -> bool:
	if left.ring != right.ring:
		return left.ring < right.ring

	return (
		left.request_sequence
		< right.request_sequence
	)


func _update_presenter_visibility() -> void:
	for record_value in _records.values():
		var record := record_value as ChunkRecord

		if record != null:
			_update_record_visibility(record)


func _update_record_visibility(
	record: ChunkRecord
) -> void:
	if (
		record.presenter == null
		or not is_instance_valid(record.presenter)
	):
		return

	var allowed: bool = (
		record.ring <= maximum_presentation_ring
	)

	if _chunk_render_overrides.has(
		record.coordinate
	):
		var override_value: Variant = (
			_chunk_render_overrides[
				record.coordinate
			]
		)

		allowed = (
			allowed
			and bool(override_value)
		)

	record.presenter.set_render_allowed(
		allowed
	)

	record.presenter.set_visibility_distance(
		_effective_visibility_distance
	)


## Allows future fog, darkness, occlusion, portal, or gameplay systems to
## suppress a chunk without deleting its generation data.
func set_chunk_render_allowed(
	chunk_coordinate: Vector2i,
	allowed: bool
) -> void:
	_chunk_render_overrides[
		chunk_coordinate
	] = allowed

	var record := (
		_records.get(chunk_coordinate)
		as ChunkRecord
	)

	if record != null:
		_update_record_visibility(record)


func clear_chunk_render_override(
	chunk_coordinate: Vector2i
) -> void:
	_chunk_render_overrides.erase(
		chunk_coordinate
	)

	var record := (
		_records.get(chunk_coordinate)
		as ChunkRecord
	)

	if record != null:
		_update_record_visibility(record)


## A future fog or light system can set the effective render distance.
## Zero disables distance-range culling and leaves ring/frustum culling.
func set_effective_visibility_distance(
	distance: float
) -> void:
	_effective_visibility_distance = maxf(
		distance,
		0.0
	)

	_update_presenter_visibility()


func get_effective_visibility_distance() -> float:
	return _effective_visibility_distance


func _extract_terrain_data(
	world_chunk: WorldChunk
) -> TerrainChunkData:
	if (
		world_chunk == null
		or not is_instance_valid(world_chunk)
	):
		return null

	## First check metadata. This supports coordinators that attach the
	## retained generation data directly to the runtime chunk.
	var metadata_names: Array[StringName] = [
		&"terrain_chunk_data",
		&"terrain_data",
		&"retained_terrain_data",
	]

	for metadata_name in metadata_names:
		if not world_chunk.has_meta(metadata_name):
			continue

		var metadata_value: Variant = (
			world_chunk.get_meta(metadata_name)
		)

		var metadata_data: TerrainChunkData = (
			metadata_value as TerrainChunkData
		)

		if metadata_data != null:
			return metadata_data

	## Prefer an explicit public getter when one exists.
	var getter_names: Array[StringName] = [
		&"get_terrain_data",
		&"get_retained_terrain_data",
		&"get_terrain_chunk_data",
		&"get_chunk_data",
		&"get_source_data",
	]

	for getter_name in getter_names:
		if not world_chunk.has_method(getter_name):
			continue

		var getter_value: Variant = (
			world_chunk.call(getter_name)
		)

		var getter_data: TerrainChunkData = (
			getter_value as TerrainChunkData
		)

		if getter_data != null:
			return getter_data

	## WorldChunk implementations may use a different private field name.
	## Inspect every script variable instead of guessing its name.
	var property_list: Array[Dictionary] = (
		world_chunk.get_property_list()
	)

	for property_info in property_list:
		var usage_value: Variant = property_info.get(
			"usage",
			0
		)

		var usage: int = int(usage_value)

		if (
			usage
			& PROPERTY_USAGE_SCRIPT_VARIABLE
		) == 0:
			continue

		var property_name_value: Variant = (
			property_info.get(
				"name",
				""
			)
		)

		var property_name := StringName(
			str(property_name_value)
		)

		if property_name.is_empty():
			continue

		var property_value: Variant = (
			world_chunk.get(property_name)
		)

		var terrain_data: TerrainChunkData = (
			property_value as TerrainChunkData
		)

		if terrain_data != null:
			return terrain_data

	return null

func _remove_record(
	chunk_coordinate: Vector2i
) -> void:
	var record := (
		_records.get(chunk_coordinate)
		as ChunkRecord
	)

	if record == null:
		return

	record.active = false
	record.request_revision += 1
	record.pending = false

	_remove_record_from_pending(record)
	_cancel_record_build(record)
	_remove_record_presenter(record)

	record.flora_data = null
	record.terrain_data = null

	_records.erase(chunk_coordinate)
	_chunk_render_overrides.erase(
		chunk_coordinate
	)


func _remove_record_from_pending(
	record: ChunkRecord
) -> void:
	if record == null:
		return

	for index in range(
		_pending.size() - 1,
		-1,
		-1
	):
		if _pending[index] == record:
			_pending.remove_at(index)


func _remove_record_presentation(
	record: ChunkRecord
) -> void:
	_cancel_record_build(record)
	_remove_record_presenter(record)
	record.presentation_resolved = false
	record.presented_divisor = 0


func _cancel_record_build(
	record: ChunkRecord
) -> void:
	if record == null or record.build == null:
		return

	var build: PresentationBuild = record.build

	record.build = null
	_builds.erase(build)

	if (
		build.presenter != null
		and is_instance_valid(build.presenter)
	):
		build.presenter.free()


func _remove_record_presenter(
	record: ChunkRecord
) -> void:
	if record == null or record.presenter == null:
		return

	if is_instance_valid(record.presenter):
		record.presenter.queue_free()

	record.presenter = null
	record.presented_divisor = 0


func _remove_build_at(
	index: int,
	free_presenter: bool
) -> void:
	if index < 0 or index >= _builds.size():
		return

	var build: PresentationBuild = _builds[index]

	_builds.remove_at(index)

	if (
		build.record != null
		and build.record.build == build
	):
		build.record.build = null

	if (
		free_presenter
		and build.presenter != null
		and is_instance_valid(build.presenter)
	):
		build.presenter.free()


func get_pending_chunk_count() -> int:
	var count: int = 0

	for record in _pending:
		if record.active and record.pending:
			count += 1

	return count


func get_running_chunk_count() -> int:
	return _running.size()


func get_completed_result_count() -> int:
	return _completed.size()


func get_cached_chunk_count() -> int:
	var count: int = 0

	for record_value in _records.values():
		var record := record_value as ChunkRecord

		if (
			record != null
			and record.flora_data != null
		):
			count += 1

	return count


func get_presented_chunk_count() -> int:
	var count: int = 0

	for record_value in _records.values():
		var record := record_value as ChunkRecord

		if (
			record != null
			and record.presenter != null
			and is_instance_valid(record.presenter)
		):
			count += 1

	return count


func get_total_presented_instance_count() -> int:
	var total: int = 0

	for record_value in _records.values():
		var record := record_value as ChunkRecord

		if (
			record != null
			and record.presenter != null
			and is_instance_valid(record.presenter)
		):
			total += (
				record.presenter
				.get_total_instance_count()
			)

	return total


func get_chunk_data(
	chunk_coordinate: Vector2i
) -> FloraChunkData:
	var record := (
		_records.get(chunk_coordinate)
		as ChunkRecord
	)

	if record == null:
		return null

	return record.flora_data


func get_chunk_presenter(
	chunk_coordinate: Vector2i
) -> FloraChunkPresenter:
	var record := (
		_records.get(chunk_coordinate)
		as ChunkRecord
	)

	if record == null:
		return null

	return record.presenter


func clear_all() -> void:
	for record_value in _records.values():
		var record := record_value as ChunkRecord

		if record == null:
			continue

		record.active = false
		_cancel_record_build(record)
		_remove_record_presenter(record)

	_records.clear()
	_pending.clear()
	_completed.clear()
	_builds.clear()
	_chunk_render_overrides.clear()

	## Running WorkerThreadPool tasks cannot be forcefully interrupted.
	## Their results become stale because all activation records are gone.
	_running.clear()


func _exit_tree() -> void:
	set_process(false)

	if (
		_chunk_coordinator != null
		and is_instance_valid(_chunk_coordinator)
	):
		if _chunk_coordinator.chunk_activated.is_connected(
			_on_chunk_activated
		):
			_chunk_coordinator.chunk_activated.disconnect(
				_on_chunk_activated
			)

		if _chunk_coordinator.chunk_deactivated.is_connected(
			_on_chunk_deactivated
		):
			_chunk_coordinator.chunk_deactivated.disconnect(
				_on_chunk_deactivated
			)

	clear_all()
