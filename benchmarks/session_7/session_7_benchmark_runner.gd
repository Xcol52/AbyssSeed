extends Node

enum BenchmarkPhase {
	NOT_STARTED,
	INITIAL_SETTLEMENT,
	SUSTAINED_MOVEMENT,
	RAPID_DIRECTION_CHANGE,
	RECOVERY,
	COMPLETE
}

@export_category("Settlement")

## The pipeline must remain idle for this duration before it is
## considered settled.
@export_range(0.25, 10.0, 0.25)
var stable_idle_seconds: float = 1.5

## Maximum wait for initial loading or final recovery.
@export_range(5.0, 300.0, 1.0)
var settlement_timeout_seconds: float = 90.0

@export_category("Sustained Movement")

## X maps to world X. Y maps to world Z.
@export var sustained_route_chunks := Vector2(
	5.0,
	-10.0
)

@export_range(1.0, 120.0, 0.5)
var sustained_duration_seconds: float = 24.0

@export_category("Rapid Direction Change")

## Relative route after the sustained-movement endpoint.
## X maps to world X. Y maps to world Z.
@export var direction_change_route_chunks := Vector2(
	-4.0,
	6.0
)

@export_range(1.0, 60.0, 0.5)
var direction_change_duration_seconds: float = 6.0

@export_category("Output")

@export var automatically_quit: bool = true

@onready var _runtime: Node = $Runtime

var _world: OceanWorld
var _observer: Node3D
var _coordinator: ChunkCoordinator
var _definition: WorldDefinition

var _phase: int = BenchmarkPhase.NOT_STARTED
var _current_metrics: Session7BenchmarkPhaseMetrics
var _overall_metrics: Session7BenchmarkPhaseMetrics

var _completed_phase_reports: Array[String] = []

var _run_started_usec: int = 0
var _run_ended_usec: int = 0
var _phase_started_usec: int = 0
var _last_frame_usec: int = 0

var _skip_next_frame_sample: bool = true
var _benchmark_had_timeout: bool = false

var _idle_started_usec: int = -1
var _last_active_count: int = -1

var _movement_start: Vector3
var _movement_end: Vector3
var _direction_change_end: Vector3


func _ready() -> void:
	## Run after the coordinator's default process priority.
	process_priority = 100

	set_process(false)
	call_deferred("_begin_benchmark")


func _begin_benchmark() -> void:
	if _runtime == null:
		_fail_startup(
			"Benchmark runtime scene is missing."
		)
		return

	if not _runtime.has_method("get_world"):
		_fail_startup(
			"Runtime Main does not expose get_world()."
		)
		return

	if not _runtime.has_method("get_observer"):
		_fail_startup(
			"Runtime Main does not expose get_observer()."
		)
		return

	if not _runtime.has_method(
		"get_world_definition"
	):
		_fail_startup(
			(
				"Runtime Main does not expose "
				+ "get_world_definition()."
			)
		)
		return

	var world_value: Variant = (
		_runtime.call("get_world")
	)

	var observer_value: Variant = (
		_runtime.call("get_observer")
	)

	var definition_value: Variant = (
		_runtime.call("get_world_definition")
	)

	_world = world_value as OceanWorld
	_observer = observer_value as Node3D
	_definition = definition_value as WorldDefinition

	if _world == null:
		_fail_startup(
			"Benchmark could not obtain OceanWorld."
		)
		return

	if _observer == null:
		_fail_startup(
			"Benchmark could not obtain DebugObserver."
		)
		return

	if _definition == null:
		_fail_startup(
			"Benchmark could not obtain WorldDefinition."
		)
		return

	_coordinator = _world.get_chunk_coordinator()

	if _coordinator == null:
		_fail_startup(
			"Benchmark could not obtain ChunkCoordinator."
		)
		return

	var profiler_probe: String = (
		_coordinator.get_profile_report()
	)

	if profiler_probe == "Generation profiling is disabled.":
		_fail_startup(
			(
				"Generation profiling must be enabled "
				+ "for the Session 7 benchmark."
			)
		)
		return

	_disable_manual_observer_control()
	_prepare_route()

	_run_started_usec = Time.get_ticks_usec()

	_overall_metrics = (
		Session7BenchmarkPhaseMetrics.new(
			"Whole benchmark"
		)
	)

	_begin_phase(
		BenchmarkPhase.INITIAL_SETTLEMENT,
		"Initial settlement"
	)

	print(
		"Session 7 benchmark started. "
		+ "Do not provide manual movement input."
	)

	set_process(true)


func _process(_delta: float) -> void:
	if (
		_phase == BenchmarkPhase.NOT_STARTED
		or _phase == BenchmarkPhase.COMPLETE
	):
		return

	var now_usec: int = Time.get_ticks_usec()

	if _skip_next_frame_sample:
		_skip_next_frame_sample = false
	else:
		var frame_duration_usec: int = (
			now_usec - _last_frame_usec
		)

		_current_metrics.record_frame(
			frame_duration_usec
		)

		_overall_metrics.record_frame(
			frame_duration_usec
		)

	_last_frame_usec = now_usec

	_current_metrics.observe(_coordinator)
	_overall_metrics.observe(_coordinator)

	match _phase:
		BenchmarkPhase.INITIAL_SETTLEMENT:
			_update_initial_settlement(now_usec)

		BenchmarkPhase.SUSTAINED_MOVEMENT:
			_update_sustained_movement(now_usec)

		BenchmarkPhase.RAPID_DIRECTION_CHANGE:
			_update_direction_change(now_usec)

		BenchmarkPhase.RECOVERY:
			_update_recovery(now_usec)


func _update_initial_settlement(
	now_usec: int
) -> void:
	if _is_stably_idle(now_usec):
		_finish_current_phase(false)
		_begin_sustained_movement()
		return

	if (
		_get_phase_elapsed_seconds(now_usec)
		>= settlement_timeout_seconds
	):
		_benchmark_had_timeout = true
		_finish_current_phase(true)
		_complete_benchmark()
		return


func _begin_sustained_movement() -> void:
	_face_horizontal_direction(
		_movement_end - _movement_start
	)

	_begin_phase(
		BenchmarkPhase.SUSTAINED_MOVEMENT,
		"Sustained movement"
	)


func _update_sustained_movement(
	now_usec: int
) -> void:
	var elapsed_seconds: float = (
		_get_phase_elapsed_seconds(now_usec)
	)

	var progress: float = clampf(
		elapsed_seconds
		/ sustained_duration_seconds,
		0.0,
		1.0
	)

	_observer.global_position = (
		_movement_start.lerp(
			_movement_end,
			progress
		)
	)

	if progress < 1.0:
		return

	_observer.global_position = _movement_end

	_finish_current_phase(false)
	_begin_direction_change()


func _begin_direction_change() -> void:
	_face_horizontal_direction(
		_direction_change_end - _movement_end
	)

	_begin_phase(
		BenchmarkPhase.RAPID_DIRECTION_CHANGE,
		"Rapid direction change"
	)


func _update_direction_change(
	now_usec: int
) -> void:
	var elapsed_seconds: float = (
		_get_phase_elapsed_seconds(now_usec)
	)

	var progress: float = clampf(
		elapsed_seconds
		/ direction_change_duration_seconds,
		0.0,
		1.0
	)

	_observer.global_position = (
		_movement_end.lerp(
			_direction_change_end,
			progress
		)
	)

	if progress < 1.0:
		return

	_observer.global_position = (
		_direction_change_end
	)

	_finish_current_phase(false)
	_begin_recovery()


func _begin_recovery() -> void:
	_begin_phase(
		BenchmarkPhase.RECOVERY,
		"Recovery"
	)


func _update_recovery(
	now_usec: int
) -> void:
	if _is_stably_idle(now_usec):
		_finish_current_phase(false)
		_complete_benchmark()
		return

	if (
		_get_phase_elapsed_seconds(now_usec)
		>= settlement_timeout_seconds
	):
		_benchmark_had_timeout = true
		_finish_current_phase(true)
		_complete_benchmark()


func _begin_phase(
	new_phase: int,
	phase_name: String
) -> void:
	_phase = new_phase

	_coordinator.reset_profile()

	_current_metrics = (
		Session7BenchmarkPhaseMetrics.new(
			phase_name
		)
	)

	_phase_started_usec = Time.get_ticks_usec()
	_last_frame_usec = _phase_started_usec
	_skip_next_frame_sample = true

	_idle_started_usec = -1
	_last_active_count = (
		_coordinator.get_active_chunk_count()
	)


func _finish_current_phase(
	timed_out: bool
) -> void:
	if _current_metrics == null:
		return

	_current_metrics.observe(_coordinator)

	var generation_report: String = (
		_coordinator.get_profile_report()
	)

	_current_metrics.finish(
		generation_report,
		timed_out
	)

	_completed_phase_reports.append(
		_current_metrics.create_report()
	)


func _is_stably_idle(
	now_usec: int
) -> bool:
	var pending_count: int = (
		_coordinator.get_pending_chunk_count()
	)

	var running_count: int = (
		_coordinator.get_running_chunk_count()
	)

	var completed_count: int = (
		_coordinator.get_completed_chunk_count()
	)

	var active_count: int = (
		_coordinator.get_active_chunk_count()
	)

	var pipeline_is_idle := (
		pending_count == 0
		and running_count == 0
		and completed_count == 0
		and active_count > 0
	)

	if not pipeline_is_idle:
		_idle_started_usec = -1
		_last_active_count = active_count
		return false

	if active_count != _last_active_count:
		_idle_started_usec = now_usec
		_last_active_count = active_count
		return false

	if _idle_started_usec < 0:
		_idle_started_usec = now_usec
		return false

	return (
		float(now_usec - _idle_started_usec)
		/ 1000000.0
		>= stable_idle_seconds
	)


func _prepare_route() -> void:
	var chunk_size: float = (
		_definition.grid_settings.chunk_size
	)

	_movement_start = _observer.global_position

	_movement_end = (
		_movement_start
		+ Vector3(
			sustained_route_chunks.x
			* chunk_size,
			0.0,
			sustained_route_chunks.y
			* chunk_size
		)
	)

	_direction_change_end = (
		_movement_end
		+ Vector3(
			direction_change_route_chunks.x
			* chunk_size,
			0.0,
			direction_change_route_chunks.y
			* chunk_size
		)
	)


func _disable_manual_observer_control() -> void:
	_observer.set_process(false)
	_observer.set_physics_process(false)
	_observer.set_process_input(false)
	_observer.set_process_unhandled_input(false)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _face_horizontal_direction(
	direction: Vector3
) -> void:
	var horizontal_direction := Vector2(
		direction.x,
		direction.z
	)

	if horizontal_direction.is_zero_approx():
		return

	horizontal_direction = (
		horizontal_direction.normalized()
	)

	## The observer's local forward direction is -Z.
	_observer.rotation.y = atan2(
		-horizontal_direction.x,
		-horizontal_direction.y
	)


func _get_phase_elapsed_seconds(
	now_usec: int
) -> float:
	return (
		float(now_usec - _phase_started_usec)
		/ 1000000.0
	)


func _complete_benchmark() -> void:
	if _phase == BenchmarkPhase.COMPLETE:
		return

	_phase = BenchmarkPhase.COMPLETE
	set_process(false)

	_run_ended_usec = Time.get_ticks_usec()

	_overall_metrics.observe(_coordinator)

	_overall_metrics.finish(
		(
			"Generation profiling was reset at phase "
			+ "boundaries. See individual phase reports."
		),
		_benchmark_had_timeout
	)

	var report: String = _create_complete_report()
	var report_path: String = _save_report(report)

	print("")
	print(report)

	if report_path.is_empty():
		push_error(
			"Session 7 benchmark report was not saved."
		)
	else:
		print("")
		print(
			"Session 7 benchmark report saved to:"
		)
		print(
			ProjectSettings.globalize_path(
				report_path
			)
		)

	if automatically_quit:
		call_deferred("_quit_successfully")


func _create_complete_report() -> String:
	var lines := PackedStringArray()

	lines.append(
		"# Session 7 Performance Benchmark"
	)

	lines.append(
		"Generated: %s"
		% Time.get_datetime_string_from_system()
	)

	lines.append(
		"Total duration: %.3f seconds"
		% (
			float(
				_run_ended_usec
				- _run_started_usec
			)
			/ 1000000.0
		)
	)

	if _benchmark_had_timeout:
		lines.append(
			"Status: INVALID — one or more phases timed out."
		)
	else:
		lines.append("Status: completed")

	lines.append("")
	lines.append("## Runtime configuration")

	_append_runtime_configuration(lines)

	lines.append("")
	lines.append(
		"Cancellation count: unavailable in the "
		+ "current scheduler instrumentation."
	)

	lines.append(
		"Stale completed results are still reported "
		+ "by each generation profile."
	)

	lines.append("")
	lines.append(
		"Generation results are attributed to the phase "
		+ "in which the main thread consumed them."
	)

	lines.append(
		"A worker job may begin in one phase and be consumed "
		+ "in the following phase."
	)

	lines.append("")
	lines.append(_overall_metrics.create_report())

	for phase_report in _completed_phase_reports:
		lines.append("")
		lines.append(phase_report)

	return "\n".join(lines)


func _append_runtime_configuration(
	lines: PackedStringArray
) -> void:
	var version_info: Dictionary = (
		Engine.get_version_info()
	)

	var version_text: String = str(
		version_info.get(
			"string",
			"unknown"
		)
	)

	var renderer_method: String = str(
		ProjectSettings.get_setting(
			"rendering/renderer/rendering_method",
			"unknown"
		)
	)

	var execution_context := "standalone"

	if OS.has_feature("editor"):
		execution_context = "editor executable"

	var build_type := "release"

	if OS.is_debug_build():
		build_type = "debug"

	var window_size: Vector2i = get_window().size

	var generation_settings: ChunkGenerationSettings = (
		_definition.chunk_generation_settings
	)

	var streaming_settings: ChunkStreamingSettings = (
		_definition.chunk_streaming_settings
	)

	var grid_settings: WorldGridSettings = (
		_definition.grid_settings
	)

	var geology_settings: GeologySettings = (
		_definition.geology_settings
	)

	lines.append(
		"Godot version: %s" % version_text
	)

	lines.append(
		"Execution context: %s" % execution_context
	)

	lines.append(
		"Build type: %s" % build_type
	)

	lines.append(
		"Operating system: %s" % OS.get_name()
	)

	lines.append(
		"Processor: %s (%d logical processors)"
		% [
			OS.get_processor_name(),
			OS.get_processor_count()
		]
	)

	lines.append(
		"Video adapter: %s"
		% RenderingServer.get_video_adapter_name()
	)

	lines.append(
		"Renderer setting: %s" % renderer_method
	)

	lines.append(
		"Window size: %d x %d"
		% [
			window_size.x,
			window_size.y
		]
	)

	lines.append(
		"VSync mode: %d"
		% DisplayServer.window_get_vsync_mode()
	)

	lines.append(
		"Frame cap: %d" % Engine.max_fps
	)

	lines.append(
		"World seed: %d"
		% _definition.world_seed
	)

	lines.append(
		"Generation version: %d"
		% _definition.generation_version
	)

	lines.append(
		"Chunk size: %.3f"
		% grid_settings.chunk_size
	)

	lines.append(
		"Cells per axis: %d"
		% grid_settings.cells_per_axis
	)

	lines.append(
		"Load radius: %d"
		% streaming_settings.load_radius
	)

	lines.append(
		"Unload radius: %d"
		% streaming_settings.unload_radius
	)

	lines.append(
		"Background workers: %s"
		% str(
			generation_settings
			.background_workers_enabled
		)
	)

	lines.append(
		"Maximum pending requests: %d"
		% generation_settings.max_pending_requests
	)

	lines.append(
		"Maximum concurrent jobs: %d"
		% generation_settings.max_concurrent_jobs
	)

	lines.append(
		"Maximum completed results: %d"
		% generation_settings.max_completed_results
	)

	lines.append(
		"Dispatch budget per frame: %d"
		% generation_settings.dispatch_budget_per_frame
	)

	lines.append(
		"Presentation budget per frame: %d"
		% (
			generation_settings
			.presentation_budget_per_frame
		)
	)

	lines.append(
		"Plate cell size: %.3f"
		% geology_settings.plate_cell_size
	)

	lines.append(
		"Plate size variation: %.3f"
		% geology_settings.plate_size_variation
	)

	lines.append(
		(
			"Sustained route: X=%.2f chunks "
			+ "Z=%.2f chunks duration=%.2f seconds"
		)
		% [
			sustained_route_chunks.x,
			sustained_route_chunks.y,
			sustained_duration_seconds
		]
	)

	lines.append(
		(
			"Direction-change route: X=%.2f chunks "
			+ "Z=%.2f chunks duration=%.2f seconds"
		)
		% [
			direction_change_route_chunks.x,
			direction_change_route_chunks.y,
			direction_change_duration_seconds
		]
	)

	lines.append(
		"Required stable idle duration: %.2f seconds"
		% stable_idle_seconds
	)


func _save_report(report: String) -> String:
	var timestamp: String = (
		Time.get_datetime_string_from_system()
	)

	timestamp = timestamp.replace(":", "-")
	timestamp = timestamp.replace("T", "_")
	timestamp = timestamp.replace(" ", "_")

	var report_path := (
		"user://session_7_benchmark_%s.txt"
		% timestamp
	)

	var report_file: FileAccess = FileAccess.open(
		report_path,
		FileAccess.WRITE
	)

	if report_file == null:
		push_error(
			"Could not open benchmark report file: %s"
			% str(FileAccess.get_open_error())
		)
		return ""

	report_file.store_string(report)
	report_file.close()

	return report_path


func _fail_startup(message: String) -> void:
	push_error(
		"Session 7 benchmark startup failed: %s"
		% message
	)

	set_process(false)
	get_tree().quit(1)


func _quit_successfully() -> void:
	get_tree().quit(0)
