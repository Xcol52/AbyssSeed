class_name ChunkGenerationSettings
extends Resource

@export_category("Execution")

## Keep false for the initial synchronous baseline.
## Change to true after recording that baseline.
@export var background_workers_enabled: bool = false

@export_range(1, 128, 1)
var max_pending_requests: int = 64

@export_range(1, 16, 1)
var max_concurrent_jobs: int = 2

## Must be at least max_concurrent_jobs so every running worker has
## guaranteed capacity to publish one result.
@export_range(1, 64, 1)
var max_completed_results: int = 4

@export_range(1, 16, 1)
var dispatch_budget_per_frame: int = 1

@export_range(1, 16, 1)
var presentation_budget_per_frame: int = 1

@export_range(0, 8, 1)
var max_retries_per_coordinate: int = 1

@export_category("Profiling")

@export var profiling_enabled: bool = true
@export var print_profile_on_shutdown: bool = true


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if max_pending_requests < 1:
		errors.append("max_pending_requests must be at least 1.")

	if max_concurrent_jobs < 1:
		errors.append("max_concurrent_jobs must be at least 1.")

	if max_completed_results < max_concurrent_jobs:
		errors.append(
			"max_completed_results must be at least max_concurrent_jobs."
		)

	if dispatch_budget_per_frame < 1:
		errors.append(
			"dispatch_budget_per_frame must be at least 1."
		)

	if presentation_budget_per_frame < 1:
		errors.append(
			"presentation_budget_per_frame must be at least 1."
		)

	if max_retries_per_coordinate < 0:
		errors.append(
			"max_retries_per_coordinate must not be negative."
		)

	return errors
