class_name ChunkCoordinator
extends Node

signal chunk_activated(
	chunk_coordinate: Vector2i,
	world_chunk: WorldChunk
)

signal chunk_deactivated(
	chunk_coordinate: Vector2i
)

@export var world_chunk_scene: PackedScene

var _initialized: bool = false

var _observer: Node3D
var _view_reference: Node3D
var _chunk_parent: Node3D

var _world_session_id: int
var _generation_version: int
var _terrain_subsystem_seed: int
var _geology_subsystem_seed: int

var _environment_subsystem_seed: int
var _flora_subsystem_seed: int

var _environment_sampler: EnvironmentSampler
var _biome_sampler: BiomeSuitabilitySampler
var _flora_sampler: FloraPlacementSampler

var _grid_settings: WorldGridSettings
var _terrain_settings: TerrainSettings
var _streaming_settings: ChunkStreamingSettings
var _geology_settings: GeologySettings

var _presentation_budget_per_frame: int
var _max_retries_per_coordinate: int
var _print_profile_on_shutdown: bool

var _scheduler: ChunkGenerationScheduler
var _profiler: GenerationProfiler

## Vector2i -> WorldChunk
var _active_chunks: Dictionary = {}

## Current load-radius coordinates.
var _desired_coordinate_set: Dictionary = {}

## Complete deterministic priority order for missing desired coordinates.
var _priority_coordinates: Array[Vector2i] = []

## Vector2i -> number of failures.
var _failure_counts: Dictionary = {}

var _current_observer_chunk: Vector2i = Vector2i.ZERO
var _last_priority_forward: Vector2 = Vector2(0.0, -1.0)
var _has_priority_forward: bool = false

var _next_request_id: int = 1


func _ready() -> void:
	set_process(false)


func initialize(
	observer: Node3D,
	view_reference: Node3D,
	chunk_parent: Node3D,
	world_seed: int,
	generation_version: int,
	grid_settings: WorldGridSettings,
	terrain_settings: TerrainSettings,
	geology_settings: GeologySettings,
	ocean_settings: OceanSettings,
	environment_settings: EnvironmentSettings,
	streaming_settings: ChunkStreamingSettings,
	generation_settings: ChunkGenerationSettings
) -> bool:
	if _initialized:
		push_error(
			"ChunkCoordinator can only be initialized once."
		)
		return false

	if not is_node_ready():
		push_error(
			"ChunkCoordinator must be inside the SceneTree "
			+ "before initialization."
		)
		return false

	if observer == null or not is_instance_valid(observer):
		push_error(
			"ChunkCoordinator requires a valid observer."
		)
		return false

	if (
		view_reference == null
		or not is_instance_valid(view_reference)
	):
		push_error(
			"ChunkCoordinator requires a valid view reference."
		)
		return false

	if (
		chunk_parent == null
		or not is_instance_valid(chunk_parent)
	):
		push_error(
			"ChunkCoordinator requires a valid chunk parent."
		)
		return false

	if world_chunk_scene == null:
		push_error(
			"ChunkCoordinator requires a world_chunk_scene."
		)
		return false

	if ocean_settings == null:
		push_error(
			"ChunkCoordinator requires OceanSettings."
		)
		return false

	if environment_settings == null:
		push_error(
			"ChunkCoordinator requires EnvironmentSettings."
		)
		return false

	var ocean_errors := ocean_settings.validate()

	if not ocean_errors.is_empty():
		for message in ocean_errors:
			push_error(
				"Invalid OceanSettings: %s" % message
			)
		return false

	var environment_errors := environment_settings.validate()

	if not environment_errors.is_empty():
		for message in environment_errors:
			push_error(
				"Invalid EnvironmentSettings: %s" % message
			)
		return false

	if generation_version < 1:
		push_error(
			"generation_version must be at least 1."
		)
		return false

	if grid_settings == null:
		push_error(
			"ChunkCoordinator requires WorldGridSettings."
		)
		return false

	if terrain_settings == null:
		push_error(
			"ChunkCoordinator requires TerrainSettings."
		)
		return false

	if streaming_settings == null:
		push_error(
			"ChunkCoordinator requires ChunkStreamingSettings."
		)
		return false

	if generation_settings == null:
		push_error(
			"ChunkCoordinator requires ChunkGenerationSettings."
		)
		return false

	if geology_settings == null:
		push_error(
			"ChunkCoordinator requires GeologySettings."
		)
		return false

	var grid_errors := grid_settings.validate()
	if not grid_errors.is_empty():
		for message in grid_errors:
			push_error(
				"Invalid WorldGridSettings: %s" % message
			)
		return false

	var terrain_errors := terrain_settings.validate()
	if not terrain_errors.is_empty():
		for message in terrain_errors:
			push_error(
				"Invalid TerrainSettings: %s" % message
			)
		return false

	var streaming_errors := streaming_settings.validate()
	if not streaming_errors.is_empty():
		for message in streaming_errors:
			push_error(
				"Invalid ChunkStreamingSettings: %s"
				% message
			)
		return false

	var generation_errors := generation_settings.validate()
	if not generation_errors.is_empty():
		for message in generation_errors:
			push_error(
				"Invalid ChunkGenerationSettings: %s"
				% message
			)
		return false
	var geology_errors := geology_settings.validate()

	if not geology_errors.is_empty():
		for message in geology_errors:
			push_error(
				"Invalid GeologySettings: %s" % message
			)
		return false
	_geology_settings = geology_settings

	_observer = observer
	_view_reference = view_reference
	_chunk_parent = chunk_parent

	_world_session_id = int(get_instance_id())
	_generation_version = generation_version

	_grid_settings = grid_settings
	_terrain_settings = terrain_settings
	_streaming_settings = streaming_settings

	_presentation_budget_per_frame = (
		generation_settings.presentation_budget_per_frame
	)
	_max_retries_per_coordinate = (
		generation_settings.max_retries_per_coordinate
	)
	_print_profile_on_shutdown = (
		generation_settings.print_profile_on_shutdown
	)

	_terrain_subsystem_seed = (
		StableSeed.derive_subsystem_seed(
			world_seed,
			generation_version,
			WorldSubsystemIds.TERRAIN
		)
	)
	_geology_subsystem_seed = (
		StableSeed.derive_subsystem_seed(
			world_seed,
			generation_version,
			WorldSubsystemIds.GEOLOGY
		)
	)

	_environment_subsystem_seed = (
		StableSeed.derive_subsystem_seed(
			world_seed,
			generation_version,
			WorldSubsystemIds.ENVIRONMENT
		)
	)

	_flora_subsystem_seed = (
		StableSeed.derive_subsystem_seed(
			world_seed,
			generation_version,
			WorldSubsystemIds.FLORA
		)
	)

	var environment_snapshot := (
		EnvironmentGenerationSnapshot.from_settings(
			_environment_subsystem_seed,
			ocean_settings,
			environment_settings
		)
	)

	var environment_snapshot_error: String = (
		environment_snapshot.get_validation_error()
	)

	if not environment_snapshot_error.is_empty():
		push_error(
			"Invalid environment snapshot: %s"
			% environment_snapshot_error
		)
		return false

	_environment_sampler = EnvironmentSampler.new(
		environment_snapshot
	)

	var biome_catalog := (
		BiomeCatalogSnapshot.create_default()
	)

	_biome_sampler = BiomeSuitabilitySampler.new(
		biome_catalog
	)

	var biome_error: String = (
		_biome_sampler.get_validation_error()
	)

	if not biome_error.is_empty():
		push_error(
			"Invalid biome catalog: %s"
			% biome_error
		)
		return false

	var flora_catalog := (
		FloraCatalogSnapshot.create_default()
	)

	_flora_sampler = FloraPlacementSampler.new(
		_flora_subsystem_seed,
		flora_catalog
	)

	var flora_error: String = (
		_flora_sampler.get_validation_error()
	)

	if not flora_error.is_empty():
		push_error(
			"Invalid flora catalog: %s"
			% flora_error
		)
		return false

	_scheduler = ChunkGenerationScheduler.new(
		generation_settings
	)

	var mode_name := "synchronous baseline"
	if generation_settings.background_workers_enabled:
		mode_name = "bounded asynchronous"

	_profiler = GenerationProfiler.new(
		generation_settings.profiling_enabled,
		mode_name
	)

	_current_observer_chunk = _calculate_observer_chunk()
	_last_priority_forward = (
		_calculate_horizontal_view_forward()
	)
	_has_priority_forward = true

	_initialized = true

	_refresh_residency(_last_priority_forward)
	set_process(true)

	return true


func _process(_delta: float) -> void:
	if not _initialized:
		return

	if (
		not is_instance_valid(_observer)
		or not is_instance_valid(_view_reference)
		or not is_instance_valid(_chunk_parent)
	):
		push_error(
			"ChunkCoordinator lost a required runtime dependency."
		)
		set_process(false)
		return

	var frame_work_started := Time.get_ticks_usec()

	var observer_chunk := _calculate_observer_chunk()
	var current_forward := (
		_calculate_horizontal_view_forward()
	)

	if observer_chunk != _current_observer_chunk:
		_current_observer_chunk = observer_chunk
		_refresh_residency(current_forward)
	else:
		_reprioritize_if_needed(current_forward)

	_scheduler.poll()

	var first_consumption := _consume_completed_results(
		_presentation_budget_per_frame
	)

	var processed_results := first_consumption.x
	var presented_results := first_consumption.y

	_fill_pending_requests()

	var dispatched := _scheduler.dispatch()

	# Synchronous mode can produce a result immediately. Async jobs may
	# also finish quickly, so use any presentation budget still available.
	var remaining_presentation_budget := (
		_presentation_budget_per_frame
		- presented_results
	)

	if remaining_presentation_budget > 0:
		var second_consumption := (
			_consume_completed_results(
				remaining_presentation_budget
			)
		)

		processed_results += second_consumption.x
		presented_results += second_consumption.y

	_profiler.update_counts(
		_scheduler.get_pending_count(),
		_scheduler.get_running_count(),
		_scheduler.get_completed_count(),
		_active_chunks.size()
	)

	if dispatched > 0 or processed_results > 0:
		_profiler.record_generation_frame(
			Time.get_ticks_usec()
			- frame_work_started
		)


## Returns Vector2i(results processed, chunks presented).
## Returns Vector2i(results processed, chunks presented).
func _consume_completed_results(
	max_presentations: int
) -> Vector2i:
	var processed := 0
	var presented := 0

	while presented < max_presentations:
		var result := _scheduler.take_next_result()

		if result == null:
			break

		processed += 1

		_profiler.record_sampling(
			result.sampling_usec
		)

		var geometry_payload_bytes: int = 0

		if result.mesh_data != null:
			geometry_payload_bytes = (
				result.mesh_data
				.get_raw_payload_size_bytes()
			)

		_profiler.record_geometry_preparation(
			result.geometry_preparation_usec,
			result.mesh_preparation_profile,
			geometry_payload_bytes
		)

		var coordinate := (
			result.snapshot.chunk_coordinate
		)

		var expected_request_id := (
			_scheduler.get_current_request_id(
				coordinate
			)
		)

		var result_is_current := (
			TerrainResultValidator.is_current(
				result,
				_desired_coordinate_set.has(coordinate),
				_active_chunks.has(coordinate),
				expected_request_id,
				_world_session_id,
				_generation_version
			)
		)

		if not result_is_current:
			_profiler.record_stale_result()

			_scheduler.acknowledge_result(
				result,
				ChunkGenerationJob.STATE_STALE
			)
			continue

		if (
			result.status
			== TerrainGenerationResult.STATUS_FAILED
			or result.chunk_data == null
			or result.mesh_data == null
		):
			var failure_message := result.error_message

			if failure_message.is_empty():
				failure_message = (
					"Generation result is missing "
					+ "required chunk or mesh data."
				)

			_record_generation_failure(
				coordinate,
				failure_message
			)

			_scheduler.acknowledge_result(
				result,
				ChunkGenerationJob.STATE_FAILED
			)
			continue

		var mesh_profile: TerrainMeshBuildProfile = null

		if _profiler.is_enabled():
			mesh_profile = (
				TerrainMeshBuildProfile.new()
			)

		var mesh_started := Time.get_ticks_usec()

		## ArrayMesh creation remains on the main thread and occurs only
		## after result freshness has been validated.
		var mesh := TerrainMeshBuilder.build_from_data(
			result.mesh_data,
			mesh_profile
		)

		var mesh_usec := (
			Time.get_ticks_usec()
			- mesh_started
		)

		if mesh == null:
			_record_generation_failure(
				coordinate,
				"TerrainMeshBuilder returned no mesh."
			)

			_scheduler.acknowledge_result(
				result,
				ChunkGenerationJob.STATE_FAILED
			)
			continue

		var presentation_started := (
			Time.get_ticks_usec()
		)

		var world_chunk := _create_world_chunk(
			result.chunk_data,
			mesh
		)

		var presentation_usec := (
			Time.get_ticks_usec()
			- presentation_started
		)

		if world_chunk == null:
			_record_generation_failure(
				coordinate,
				"WorldChunk presentation failed."
			)

			_scheduler.acknowledge_result(
				result,
				ChunkGenerationJob.STATE_FAILED
			)
			continue

		_active_chunks[coordinate] = world_chunk
		_failure_counts.erase(coordinate)

		## Emitted only after the chunk is available through active-chunk
		## query methods.
		chunk_activated.emit(
			coordinate,
			world_chunk
		)

		var total_latency_usec := (
			Time.get_ticks_usec()
			- result.snapshot.enqueued_at_usec
		)

		_profiler.record_presented_chunk(
			result.sampling_usec,
			mesh_usec,
			presentation_usec,
			total_latency_usec,
			mesh_profile,
			result.geometry_preparation_usec
		)

		_scheduler.acknowledge_result(
			result,
			ChunkGenerationJob.STATE_PRESENTED
		)

		presented += 1

	return Vector2i(processed, presented)

func _fill_pending_requests() -> void:
	for coordinate in _priority_coordinates:
		if not _scheduler.can_accept_more_pending():
			break

		if not _desired_coordinate_set.has(coordinate):
			continue

		if _active_chunks.has(coordinate):
			continue

		if _scheduler.has_request_for_coordinate(
			coordinate
		):
			continue

		var failure_count := int(
			_failure_counts.get(coordinate, 0)
		)

		if failure_count > _max_retries_per_coordinate:
			continue

		var geology_snapshot := (
			GeologyGenerationSnapshot.from_settings(
				_geology_subsystem_seed,
				_geology_settings
			)
		)

		var snapshot := TerrainGenerationSnapshot.new(
			_next_request_id,
			_world_session_id,
			coordinate,
			_generation_version,
			_terrain_subsystem_seed,
			_grid_settings.chunk_size,
			_grid_settings.cells_per_axis,
			_terrain_settings.base_seabed_depth,
			_terrain_settings.test_elevation_amplitude,
			_terrain_settings.test_noise_frequency,
			Time.get_ticks_usec(),
			geology_snapshot
		)

		if _scheduler.enqueue(snapshot):
			_next_request_id += 1


func _create_world_chunk(
	chunk_data: TerrainChunkData,
	mesh: ArrayMesh
) -> WorldChunk:
	var candidate := world_chunk_scene.instantiate()
	var world_chunk := candidate as WorldChunk

	if world_chunk == null:
		candidate.free()
		push_error(
			"world_chunk_scene root must inherit WorldChunk."
		)
		return null

	world_chunk.name = "Chunk_%d_%d" % [
		chunk_data.chunk_coordinate.x,
		chunk_data.chunk_coordinate.y
	]

	_chunk_parent.add_child(world_chunk)

	if not world_chunk.initialize(chunk_data, mesh):
		world_chunk.queue_free()
		return null

	return world_chunk


func _record_generation_failure(
	coordinate: Vector2i,
	error_message: String
) -> void:
	var failure_count := int(
		_failure_counts.get(coordinate, 0)
	) + 1

	_failure_counts[coordinate] = failure_count
	_profiler.record_failed_result()

	push_error(
		"Chunk %s generation failed (%d): %s"
		% [
			str(coordinate),
			failure_count,
			error_message
		]
	)


func _refresh_residency(
	current_forward: Vector2
) -> void:
	var plan := ChunkStreamPolicy.create_plan(
		_current_observer_chunk,
		_get_active_coordinates(),
		_streaming_settings,
		current_forward
	)

	for coordinate in plan.unload_coordinates:
		_unload_chunk(coordinate)

	_desired_coordinate_set.clear()

	for coordinate in plan.desired_coordinates:
		_desired_coordinate_set[coordinate] = true

	# Forget failure history after coordinates leave the desired region.
	var failed_coordinates := _failure_counts.keys()

	for coordinate_value in failed_coordinates:
		var coordinate: Vector2i = coordinate_value

		if not _desired_coordinate_set.has(coordinate):
			_failure_counts.erase(coordinate)

	_scheduler.cancel_requests_not_in(
		_desired_coordinate_set
	)

	_priority_coordinates = plan.generation_queue
	_scheduler.reorder_pending(
		_priority_coordinates
	)

	_last_priority_forward = current_forward
	_has_priority_forward = true


func _reprioritize_if_needed(
	current_forward: Vector2
) -> void:
	if not _has_priority_forward:
		_last_priority_forward = current_forward
		_has_priority_forward = true
		return

	var threshold_radians := deg_to_rad(
		_streaming_settings
		.camera_reprioritize_angle_degrees
	)

	var threshold_dot := cos(threshold_radians)

	var forward_dot := clampf(
		_last_priority_forward.dot(current_forward),
		-1.0,
		1.0
	)

	if forward_dot > threshold_dot:
		return

	_priority_coordinates = (
		ChunkStreamPolicy.order_for_generation(
			_priority_coordinates,
			_current_observer_chunk,
			current_forward,
			_streaming_settings.forward_priority_bias
		)
	)

	_scheduler.reorder_pending(
		_priority_coordinates
	)

	_last_priority_forward = current_forward


func _unload_chunk(
	chunk_coordinate: Vector2i
) -> void:
	if not _active_chunks.has(chunk_coordinate):
		return

	var world_chunk := (
		_active_chunks.get(chunk_coordinate)
		as WorldChunk
	)

	_active_chunks.erase(chunk_coordinate)

	## Flora and other dependent presentation systems must remove their
	## chunk data before the terrain Node is released.
	chunk_deactivated.emit(
		chunk_coordinate
	)

	if (
		world_chunk != null
		and is_instance_valid(world_chunk)
	):
		world_chunk.queue_free()


func _get_active_coordinates() -> Array[Vector2i]:
	var coordinates: Array[Vector2i] = []

	for coordinate_value in _active_chunks.keys():
		var coordinate: Vector2i = coordinate_value
		coordinates.append(coordinate)

	return coordinates


func _calculate_observer_chunk() -> Vector2i:
	var local_position := _chunk_parent.to_local(
		_observer.global_position
	)

	return WorldCoordinates.world_to_chunk(
		Vector2(local_position.x, local_position.z),
		_grid_settings
	)


func _calculate_horizontal_view_forward() -> Vector2:
	var global_forward := (
		-_view_reference.global_transform.basis.z
	)

	var local_forward := (
		_chunk_parent.global_transform.basis.inverse()
		* global_forward
	)

	var horizontal_forward := Vector2(
		local_forward.x,
		local_forward.z
	)

	if horizontal_forward.is_zero_approx():
		if _has_priority_forward:
			return _last_priority_forward

		return Vector2(0.0, -1.0)

	return horizontal_forward.normalized()


func get_active_chunk_count() -> int:
	return _active_chunks.size()


func get_pending_chunk_count() -> int:
	if _scheduler == null:
		return 0

	return _scheduler.get_pending_count()


func get_running_chunk_count() -> int:
	if _scheduler == null:
		return 0

	return _scheduler.get_running_count()


func get_completed_chunk_count() -> int:
	if _scheduler == null:
		return 0

	return _scheduler.get_completed_count()

## Reads an already-active chunk only.
##
## This method never enqueues, dispatches, samples, or regenerates
## terrain.
func query_active_surface_in_chunk(
	chunk_coordinate: Vector2i,
	world_position: Vector3
) -> TerrainSurfaceQueryResult:
	if not _active_chunks.has(chunk_coordinate):
		return (
			TerrainSurfaceQueryResult
			.create_unavailable(
				world_position,
				chunk_coordinate
			)
		)

	var world_chunk := (
		_active_chunks[chunk_coordinate]
		as WorldChunk
	)

	if (
		world_chunk == null
		or not is_instance_valid(world_chunk)
	):
		return (
			TerrainSurfaceQueryResult
			.create_unavailable(
				world_position,
				chunk_coordinate
			)
		)

	return TerrainSurfaceQuery.sample_world_chunk(
		world_chunk,
		world_position
	)

## Samples the environment from an already-active terrain chunk.
##
## world_position is a global SceneTree position. The returned sample's
## world_xz uses the procedural coordinate space local to _chunk_parent.
##
## This method never generates terrain, loads chunks, or dispatches work.
## It returns null if the canonical owning chunk is not active.
func query_active_environment(
	world_position: Vector3,
	environment_sampler: EnvironmentSampler
) -> EnvironmentSample:
	if not _initialized:
		return null

	if environment_sampler == null:
		return null

	if (
		_chunk_parent == null
		or not is_instance_valid(_chunk_parent)
	):
		return null

	if (
		not is_finite(world_position.x)
		or not is_finite(world_position.y)
		or not is_finite(world_position.z)
	):
		return null

	var local_position := _chunk_parent.to_local(
		world_position
	)

	var world_xz := Vector2(
		local_position.x,
		local_position.z
	)

	var chunk_coordinate := (
		WorldCoordinates.world_to_chunk(
			world_xz,
			_grid_settings
		)
	)

	if not _active_chunks.has(chunk_coordinate):
		return null

	var world_chunk := (
		_active_chunks.get(chunk_coordinate)
		as WorldChunk
	)

	if (
		world_chunk == null
		or not is_instance_valid(world_chunk)
	):
		return null

	var terrain_data := world_chunk.get_chunk_data()

	if terrain_data == null:
		return null

	return environment_sampler.sample_world(
		terrain_data,
		world_xz
	)

## Produces deterministic flora placement data for an already-active
## terrain chunk.
##
## This method does not generate terrain or instantiate flora Nodes.
## Runtime presentation code should cache the returned FloraChunkData
## for the lifetime of the active chunk.
func query_active_flora_chunk(
	chunk_coordinate: Vector2i,
	flora_sampler: FloraPlacementSampler,
	environment_sampler: EnvironmentSampler,
	biome_sampler: BiomeSuitabilitySampler
) -> FloraChunkData:
	if not _initialized:
		return null

	if (
		flora_sampler == null
		or environment_sampler == null
		or biome_sampler == null
	):
		return null

	if not _active_chunks.has(chunk_coordinate):
		return null

	var world_chunk := (
		_active_chunks.get(chunk_coordinate)
		as WorldChunk
	)

	if (
		world_chunk == null
		or not is_instance_valid(world_chunk)
	):
		return null

	var terrain_data := world_chunk.get_chunk_data()

	if terrain_data == null:
		return null

	return flora_sampler.generate_chunk(
		terrain_data,
		environment_sampler,
		biome_sampler
	)
	
## Uses the persistent Session 9 runtime samplers owned by this
## ChunkCoordinator.
func query_active_flora(
	chunk_coordinate: Vector2i
) -> FloraChunkData:
	if (
		_environment_sampler == null
		or _biome_sampler == null
		or _flora_sampler == null
	):
		return null

	return query_active_flora_chunk(
		chunk_coordinate,
		_flora_sampler,
		_environment_sampler,
		_biome_sampler
	)
func reset_profile() -> void:
	if _profiler != null:
		_profiler.reset()


func get_profile_report() -> String:
	if _profiler == null:
		return "Generation profiler is unavailable."

	return _profiler.create_report()


func print_profile_report() -> void:
	print(get_profile_report())


## Press F9 while the running game window has focus to print the
## current aggregate generation report.
func _input(input_event: InputEvent) -> void:
	if input_event is not InputEventKey:
		return

	var key_event := input_event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode != KEY_F9:
		return

	print_profile_report()


func _exit_tree() -> void:
	set_process(false)

	if _scheduler != null:
		_scheduler.shutdown()

	if (
		_profiler != null
		and _print_profile_on_shutdown
	):
		print_profile_report()
