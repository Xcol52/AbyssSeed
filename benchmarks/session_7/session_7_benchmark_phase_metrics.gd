class_name Session7BenchmarkPhaseMetrics
extends RefCounted

const SIXTY_FPS_THRESHOLD_MSEC: float = 16.67
const THIRTY_FPS_THRESHOLD_MSEC: float = 33.33
const BYTES_PER_MEBIBYTE: float = 1048576.0

var phase_name: String

var started_at_usec: int
var ended_at_usec: int = 0

var frame_times_msec: Array[float] = []

var maximum_pending: int = 0
var maximum_running: int = 0
var maximum_completed: int = 0
var maximum_active: int = 0

var ending_pending: int = 0
var ending_running: int = 0
var ending_completed: int = 0
var ending_active: int = 0

var starting_memory_bytes: int = 0
var peak_sampled_memory_bytes: int = 0
var ending_memory_bytes: int = 0

var generation_report: String = ""
var timed_out: bool = false


func _init(new_phase_name: String) -> void:
	phase_name = new_phase_name
	started_at_usec = Time.get_ticks_usec()

	starting_memory_bytes = OS.get_static_memory_usage()
	peak_sampled_memory_bytes = starting_memory_bytes
	ending_memory_bytes = starting_memory_bytes


func record_frame(duration_usec: int) -> void:
	if duration_usec <= 0:
		return

	frame_times_msec.append(
		float(duration_usec) / 1000.0
	)


func observe(
	coordinator: ChunkCoordinator
) -> void:
	if coordinator == null:
		return

	var pending_count: int = (
		coordinator.get_pending_chunk_count()
	)

	var running_count: int = (
		coordinator.get_running_chunk_count()
	)

	var completed_count: int = (
		coordinator.get_completed_chunk_count()
	)

	var active_count: int = (
		coordinator.get_active_chunk_count()
	)

	maximum_pending = maxi(
		maximum_pending,
		pending_count
	)

	maximum_running = maxi(
		maximum_running,
		running_count
	)

	maximum_completed = maxi(
		maximum_completed,
		completed_count
	)

	maximum_active = maxi(
		maximum_active,
		active_count
	)

	ending_pending = pending_count
	ending_running = running_count
	ending_completed = completed_count
	ending_active = active_count

	var current_memory_bytes: int = (
		OS.get_static_memory_usage()
	)

	peak_sampled_memory_bytes = maxi(
		peak_sampled_memory_bytes,
		current_memory_bytes
	)

	ending_memory_bytes = current_memory_bytes


func finish(
	new_generation_report: String,
	did_time_out: bool
) -> void:
	ended_at_usec = Time.get_ticks_usec()
	generation_report = new_generation_report
	timed_out = did_time_out

	ending_memory_bytes = OS.get_static_memory_usage()

	peak_sampled_memory_bytes = maxi(
		peak_sampled_memory_bytes,
		ending_memory_bytes
	)


func create_report() -> String:
	var lines := PackedStringArray()

	lines.append(
		"## Phase: %s" % phase_name
	)

	var timeout_text := ""

	if timed_out:
		timeout_text = " — TIMED OUT"

	lines.append(
		"Duration: %.3f seconds%s"
		% [
			get_duration_seconds(),
			timeout_text
		]
	)

	lines.append(
		(
			"Frame time: count=%d average=%.3f ms "
			+ "p50=%.3f ms p95=%.3f ms "
			+ "p99=%.3f ms maximum=%.3f ms"
		)
		% [
			frame_times_msec.size(),
			_get_average_frame_msec(),
			_get_percentile(0.50),
			_get_percentile(0.95),
			_get_percentile(0.99),
			_get_maximum_frame_msec()
		]
	)

	var frames_over_sixty: int = (
		_get_count_over(SIXTY_FPS_THRESHOLD_MSEC)
	)

	var frames_over_thirty: int = (
		_get_count_over(THIRTY_FPS_THRESHOLD_MSEC)
	)

	lines.append(
		(
			"Frame thresholds: over 16.67 ms=%d (%.2f%%) "
			+ "over 33.33 ms=%d (%.2f%%)"
		)
		% [
			frames_over_sixty,
			_get_percentage(frames_over_sixty),
			frames_over_thirty,
			_get_percentage(frames_over_thirty)
		]
	)

	lines.append(
		(
			"Queue high-water: pending=%d running=%d "
			+ "completed=%d active=%d"
		)
		% [
			maximum_pending,
			maximum_running,
			maximum_completed,
			maximum_active
		]
	)

	lines.append(
		(
			"Queue at phase end: pending=%d running=%d "
			+ "completed=%d active=%d"
		)
		% [
			ending_pending,
			ending_running,
			ending_completed,
			ending_active
		]
	)

	lines.append(
		(
			"Sampled process memory: start=%.3f MiB "
			+ "peak=%.3f MiB end=%.3f MiB"
		)
		% [
			_bytes_to_mebibytes(
				starting_memory_bytes
			),
			_bytes_to_mebibytes(
				peak_sampled_memory_bytes
			),
			_bytes_to_mebibytes(
				ending_memory_bytes
			)
		]
	)

	lines.append("")
	lines.append("Generation profile:")
	lines.append(generation_report)

	return "\n".join(lines)


func get_duration_seconds() -> float:
	var end_usec := ended_at_usec

	if end_usec <= 0:
		end_usec = Time.get_ticks_usec()

	return (
		float(end_usec - started_at_usec)
		/ 1000000.0
	)


func _get_average_frame_msec() -> float:
	if frame_times_msec.is_empty():
		return 0.0

	var total_msec: float = 0.0

	for frame_msec in frame_times_msec:
		total_msec += frame_msec

	return (
		total_msec
		/ float(frame_times_msec.size())
	)


func _get_maximum_frame_msec() -> float:
	var maximum_msec: float = 0.0

	for frame_msec in frame_times_msec:
		maximum_msec = maxf(
			maximum_msec,
			frame_msec
		)

	return maximum_msec


func _get_percentile(
	fraction: float
) -> float:
	if frame_times_msec.is_empty():
		return 0.0

	var sorted_samples: Array[float] = (
		frame_times_msec.duplicate()
	)

	sorted_samples.sort()

	var rank: int = (
		int(
			ceil(
				fraction
				* float(sorted_samples.size())
			)
		)
		- 1
	)

	rank = clampi(
		rank,
		0,
		sorted_samples.size() - 1
	)

	return sorted_samples[rank]


func _get_count_over(
	threshold_msec: float
) -> int:
	var count: int = 0

	for frame_msec in frame_times_msec:
		if frame_msec > threshold_msec:
			count += 1

	return count


func _get_percentage(count: int) -> float:
	if frame_times_msec.is_empty():
		return 0.0

	return (
		float(count)
		/ float(frame_times_msec.size())
		* 100.0
	)


static func _bytes_to_mebibytes(
	byte_count: int
) -> float:
	return (
		float(byte_count)
		/ BYTES_PER_MEBIBYTE
	)
