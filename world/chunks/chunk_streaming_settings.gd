class_name ChunkStreamingSettings
extends Resource

@export_category("Residency")

@export_range(0, 16, 1)
var load_radius: int = 2

@export_range(1, 32, 1)
var unload_radius: int = 3

@export_category("View Priority")

@export_range(1.0, 180.0, 1.0)
var camera_reprioritize_angle_degrees: float = 15.0

@export_range(0.0, 0.49, 0.01)
var forward_priority_bias: float = 0.25


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if load_radius < 0:
		errors.append(
			"load_radius must not be negative."
		)

	if unload_radius <= load_radius:
		errors.append(
			"unload_radius must be greater than load_radius."
		)

	if (
		not is_finite(
			camera_reprioritize_angle_degrees
		)
		or camera_reprioritize_angle_degrees <= 0.0
		or camera_reprioritize_angle_degrees > 180.0
	):
		errors.append(
			"camera_reprioritize_angle_degrees must be "
			+ "greater than 0 and no greater than 180."
		)

	if (
		not is_finite(forward_priority_bias)
		or forward_priority_bias < 0.0
		or forward_priority_bias >= 0.5
	):
		errors.append(
			"forward_priority_bias must be at least 0 "
			+ "and less than 0.5."
		)

	return errors
