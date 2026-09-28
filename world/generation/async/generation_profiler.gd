class_name GenerationProfiler
extends RefCounted


class Metric:
	var sample_count: int = 0
	var total_usec: int = 0
	var maximum_usec: int = 0

	func record(duration_usec: int) -> void:
		sample_count += 1
		total_usec += duration_usec
		maximum_usec = maxi(
			maximum_usec,
			duration_usec
		)

	func reset() -> void:
		sample_count = 0
		total_usec = 0
		maximum_usec = 0

	func get_average_msec() -> float:
		if sample_count == 0:
			return 0.0

		return (
			float(total_usec)
			/ float(sample_count)
			/ 1000.0
		)

	func get_maximum_msec() -> float:
		return float(maximum_usec) / 1000.0


var _enabled: bool
var _mode_name: String

var _sampling := Metric.new()
var _worker_geometry_preparation := Metric.new()
var _accepted_worker_compute := Metric.new()
var _mesh_building := Metric.new()
var _presentation := Metric.new()
var _accepted_compute := Metric.new()
var _accepted_latency := Metric.new()
var _generation_frames := Metric.new()

## Worker geometry-preparation stages.
var _geometry_profile_total := Metric.new()
var _geometry_validation := Metric.new()
var _geometry_array_allocation := Metric.new()
var _geometry_population := Metric.new()
var _geometry_data_setup := Metric.new()
var _geometry_unattributed := Metric.new()

var _prepared_mesh_count: int = 0
var _prepared_cell_count: int = 0
var _prepared_triangle_count: int = 0
var _prepared_vertex_count: int = 0
var _prepared_index_count: int = 0

var _geometry_payload_count: int = 0
var _geometry_payload_total_bytes: int = 0
var _geometry_payload_maximum_bytes: int = 0

## Main-thread ArrayMesh stages.
var _mesh_profile_total := Metric.new()
var _mesh_validation := Metric.new()
var _mesh_surface_array_assembly := Metric.new()
var _mesh_resource_setup := Metric.new()
var _mesh_submission := Metric.new()
var _mesh_unattributed := Metric.new()

var _submitted_mesh_count: int = 0
var _submitted_triangle_count: int = 0
var _submitted_vertex_count: int = 0

var _maximum_pending: int = 0
var _maximum_running: int = 0
var _maximum_completed: int = 0
var _maximum_active: int = 0

var _presented_count: int = 0
var _stale_count: int = 0
var _failed_count: int = 0


func _init(
	enabled: bool,
	mode_name: String
) -> void:
	_enabled = enabled
	_mode_name = mode_name


func is_enabled() -> bool:
	return _enabled


func record_sampling(
	duration_usec: int
) -> void:
	if _enabled:
		_sampling.record(duration_usec)


## Records all consumed geometry results, including stale results.
func record_geometry_preparation(
	duration_usec: int,
	preparation_profile: TerrainMeshPreparationProfile = null,
	payload_bytes: int = 0
) -> void:
	if not _enabled:
		return

	if (
		duration_usec <= 0
		and preparation_profile == null
		and payload_bytes <= 0
	):
		return

	_worker_geometry_preparation.record(
		maxi(0, duration_usec)
	)

	if preparation_profile != null:
		_record_geometry_profile(
			preparation_profile
		)

	var effective_payload_bytes := payload_bytes

	if (
		effective_payload_bytes <= 0
		and preparation_profile != null
	):
		effective_payload_bytes = (
			preparation_profile.raw_payload_bytes
		)

	if effective_payload_bytes > 0:
		_geometry_payload_count += 1
		_geometry_payload_total_bytes += (
			effective_payload_bytes
		)
		_geometry_payload_maximum_bytes = maxi(
			_geometry_payload_maximum_bytes,
			effective_payload_bytes
		)


## Existing call sites remain valid because new arguments are appended.
func record_presented_chunk(
	sampling_usec: int,
	mesh_usec: int,
	presentation_usec: int,
	total_latency_usec: int,
	mesh_profile: TerrainMeshBuildProfile = null,
	geometry_preparation_usec: int = 0
) -> void:
	if not _enabled:
		return

	_accepted_worker_compute.record(
		sampling_usec
		+ geometry_preparation_usec
	)

	_mesh_building.record(mesh_usec)
	_presentation.record(presentation_usec)

	_accepted_compute.record(
		sampling_usec
		+ geometry_preparation_usec
		+ mesh_usec
		+ presentation_usec
	)

	_accepted_latency.record(total_latency_usec)
	_presented_count += 1

	if mesh_profile != null:
		_record_mesh_profile(mesh_profile)


func record_generation_frame(
	duration_usec: int
) -> void:
	if _enabled:
		_generation_frames.record(duration_usec)


func record_stale_result() -> void:
	if _enabled:
		_stale_count += 1


func record_failed_result() -> void:
	if _enabled:
		_failed_count += 1


func update_counts(
	pending_count: int,
	running_count: int,
	completed_count: int,
	active_count: int
) -> void:
	if not _enabled:
		return

	_maximum_pending = maxi(
		_maximum_pending,
		pending_count
	)
	_maximum_running = maxi(
		_maximum_running,
		running_count
	)
	_maximum_completed = maxi(
		_maximum_completed,
		completed_count
	)
	_maximum_active = maxi(
		_maximum_active,
		active_count
	)


func reset() -> void:
	_sampling.reset()
	_worker_geometry_preparation.reset()
	_accepted_worker_compute.reset()
	_mesh_building.reset()
	_presentation.reset()
	_accepted_compute.reset()
	_accepted_latency.reset()
	_generation_frames.reset()

	_geometry_profile_total.reset()
	_geometry_validation.reset()
	_geometry_array_allocation.reset()
	_geometry_population.reset()
	_geometry_data_setup.reset()
	_geometry_unattributed.reset()

	_prepared_mesh_count = 0
	_prepared_cell_count = 0
	_prepared_triangle_count = 0
	_prepared_vertex_count = 0
	_prepared_index_count = 0

	_geometry_payload_count = 0
	_geometry_payload_total_bytes = 0
	_geometry_payload_maximum_bytes = 0

	_mesh_profile_total.reset()
	_mesh_validation.reset()
	_mesh_surface_array_assembly.reset()
	_mesh_resource_setup.reset()
	_mesh_submission.reset()
	_mesh_unattributed.reset()

	_submitted_mesh_count = 0
	_submitted_triangle_count = 0
	_submitted_vertex_count = 0

	_maximum_pending = 0
	_maximum_running = 0
	_maximum_completed = 0
	_maximum_active = 0

	_presented_count = 0
	_stale_count = 0
	_failed_count = 0


func create_report() -> String:
	if not _enabled:
		return "Generation profiling is disabled."

	var lines := PackedStringArray()

	lines.append(
		"=== Terrain Generation Profile (%s) ==="
		% _mode_name
	)

	lines.append(
		_format_metric(
			"Sampling",
			_sampling
		)
	)
	lines.append(
		_format_metric(
			"Worker geometry preparation",
			_worker_geometry_preparation
		)
	)
	lines.append(
		_format_metric(
			"Accepted worker compute total",
			_accepted_worker_compute
		)
	)
	lines.append(
		_format_metric(
			"Mesh construction",
			_mesh_building
		)
	)
	lines.append(
		_format_metric(
			"WorldChunk presentation",
			_presentation
		)
	)
	lines.append(
		_format_metric(
			"Accepted compute total",
			_accepted_compute
		)
	)
	lines.append(
		_format_metric(
			"Accepted request latency",
			_accepted_latency
		)
	)
	lines.append(
		_format_metric(
			"Generation frame work",
			_generation_frames
		)
	)

	if _geometry_profile_total.sample_count > 0:
		lines.append("")
		lines.append(
			"Worker geometry preparation breakdown:"
		)

		lines.append(
			_format_stage(
				"  Profiled preparation total",
				_geometry_profile_total,
				_geometry_profile_total
			)
		)
		lines.append(
			_format_stage(
				"  Validation",
				_geometry_validation,
				_geometry_profile_total
			)
		)
		lines.append(
			_format_stage(
				"  Packed-array allocation",
				_geometry_array_allocation,
				_geometry_profile_total
			)
		)
		lines.append(
			_format_stage(
				(
					"  Geometry calculation and "
					+ "packed-array population"
				),
				_geometry_population,
				_geometry_profile_total
			)
		)
		lines.append(
			_format_stage(
				"  TerrainMeshData setup",
				_geometry_data_setup,
				_geometry_profile_total
			)
		)
		lines.append(
			_format_stage(
				"  Unattributed timing",
				_geometry_unattributed,
				_geometry_profile_total
			)
		)

		lines.append(
			(
				"Prepared topology totals: builds=%d cells=%d "
				+ "triangles=%d emitted_vertices=%d indices=%d"
			)
			% [
				_prepared_mesh_count,
				_prepared_cell_count,
				_prepared_triangle_count,
				_prepared_vertex_count,
				_prepared_index_count
			]
		)

	if _geometry_payload_count > 0:
		var average_payload_bytes := (
			float(_geometry_payload_total_bytes)
			/ float(_geometry_payload_count)
		)

		lines.append(
			(
				"Geometry payload: count=%d average=%.3f KiB "
				+ "maximum=%.3f KiB"
			)
			% [
				_geometry_payload_count,
				average_payload_bytes / 1024.0,
				float(
					_geometry_payload_maximum_bytes
				) / 1024.0
			]
		)

	if _mesh_profile_total.sample_count > 0:
		lines.append("")
		lines.append(
			"Main-thread mesh resource breakdown:"
		)

		lines.append(
			_format_stage(
				"  Profiled resource-build total",
				_mesh_profile_total,
				_mesh_profile_total
			)
		)
		lines.append(
			_format_stage(
				"  Validation",
				_mesh_validation,
				_mesh_profile_total
			)
		)
		lines.append(
			_format_stage(
				"  Surface array assembly",
				_mesh_surface_array_assembly,
				_mesh_profile_total
			)
		)
		lines.append(
			_format_stage(
				"  ArrayMesh resource setup",
				_mesh_resource_setup,
				_mesh_profile_total
			)
		)
		lines.append(
			_format_stage(
				(
					"  add_surface_from_arrays "
					+ "/ ArrayMesh API"
				),
				_mesh_submission,
				_mesh_profile_total
			)
		)
		lines.append(
			_format_stage(
				"  Unattributed timing",
				_mesh_unattributed,
				_mesh_profile_total
			)
		)

		lines.append(
			(
				"Submitted topology totals: builds=%d "
				+ "triangles=%d emitted_vertices=%d indices=0"
			)
			% [
				_submitted_mesh_count,
				_submitted_triangle_count,
				_submitted_vertex_count
			]
		)

	lines.append("")

	lines.append(
		(
			"High-water counts: pending=%d running=%d "
			+ "completed=%d active=%d"
		)
		% [
			_maximum_pending,
			_maximum_running,
			_maximum_completed,
			_maximum_active
		]
	)

	lines.append(
		"Outcomes: presented=%d stale=%d failed=%d"
		% [
			_presented_count,
			_stale_count,
			_failed_count
		]
	)

	return "\n".join(lines)


func _record_geometry_profile(
	profile: TerrainMeshPreparationProfile
) -> void:
	_geometry_profile_total.record(
		profile.total_usec
	)
	_geometry_validation.record(
		profile.validation_usec
	)
	_geometry_array_allocation.record(
		profile.packed_array_allocation_usec
	)
	_geometry_population.record(
		profile.geometry_population_usec
	)
	_geometry_data_setup.record(
		profile.data_object_setup_usec
	)
	_geometry_unattributed.record(
		profile.get_unattributed_usec()
	)

	_prepared_mesh_count += 1
	_prepared_cell_count += profile.cell_count
	_prepared_triangle_count += profile.triangle_count
	_prepared_vertex_count += (
		profile.emitted_vertex_count
	)
	_prepared_index_count += profile.index_count


func _record_mesh_profile(
	profile: TerrainMeshBuildProfile
) -> void:
	_mesh_profile_total.record(
		profile.total_usec
	)
	_mesh_validation.record(
		profile.validation_usec
	)
	_mesh_surface_array_assembly.record(
		profile.surface_array_assembly_usec
	)
	_mesh_resource_setup.record(
		profile.mesh_resource_setup_usec
	)
	_mesh_submission.record(
		profile.mesh_submission_usec
	)
	_mesh_unattributed.record(
		profile.get_unattributed_usec()
	)

	_submitted_mesh_count += 1
	_submitted_triangle_count += (
		profile.triangle_count
	)
	_submitted_vertex_count += (
		profile.emitted_vertex_count
	)


func _format_metric(
	label: String,
	metric: Metric
) -> String:
	return (
		"%s: count=%d average=%.3f ms maximum=%.3f ms"
		% [
			label,
			metric.sample_count,
			metric.get_average_msec(),
			metric.get_maximum_msec()
		]
	)


func _format_stage(
	label: String,
	metric: Metric,
	total_metric: Metric
) -> String:
	var total_share: float = 0.0

	if total_metric.total_usec > 0:
		total_share = (
			float(metric.total_usec)
			/ float(total_metric.total_usec)
			* 100.0
		)

	return (
		(
			"%s: count=%d average=%.3f ms "
			+ "maximum=%.3f ms total_share=%.2f%%"
		)
		% [
			label,
			metric.sample_count,
			metric.get_average_msec(),
			metric.get_maximum_msec(),
			total_share
		]
	)
