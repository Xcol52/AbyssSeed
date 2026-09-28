class_name TerrainSettings
extends Resource

@export_category("Seabed Prototype")

## Positive distance below ocean Y=0.
@export_range(1.0, 10000.0, 1.0)
var base_seabed_depth: float = 140.0

## Maximum test elevation above or below the base depth.
@export_range(0.0, 1000.0, 0.1)
var test_elevation_amplitude: float = 18.0

## FastNoiseLite frequency in inverse world meters.
@export_range(0.00001, 1.0, 0.00001)
var test_noise_frequency: float = 0.006


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if (
		not is_finite(base_seabed_depth)
		or base_seabed_depth <= 0.0
	):
		errors.append(
			"base_seabed_depth must be finite and greater than zero."
		)

	if (
		not is_finite(test_elevation_amplitude)
		or test_elevation_amplitude < 0.0
	):
		errors.append(
			"test_elevation_amplitude must be finite and non-negative."
		)

	if (
		not is_finite(test_noise_frequency)
		or test_noise_frequency <= 0.0
	):
		errors.append(
			"test_noise_frequency must be finite and greater than zero."
		)

	return errors
