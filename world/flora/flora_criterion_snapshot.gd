class_name FloraCriterionSnapshot
extends RefCounted

## Immutable by convention.
##
## Suitability uses a trapezoidal range:
##
## minimum -> 0
## ideal_minimum -> 1
## ideal_maximum -> 1
## maximum -> 0

var channel_id: int

var minimum: float
var ideal_minimum: float
var ideal_maximum: float
var maximum: float

var weight: float


func _init(
	new_channel_id: int,
	new_minimum: float,
	new_ideal_minimum: float,
	new_ideal_maximum: float,
	new_maximum: float,
	new_weight: float = 1.0
) -> void:
	channel_id = new_channel_id

	minimum = new_minimum
	ideal_minimum = new_ideal_minimum
	ideal_maximum = new_ideal_maximum
	maximum = new_maximum

	weight = new_weight


func get_validation_error() -> String:
	if (
		channel_id < 0
		or channel_id >= BiomeEvidenceChannels.COUNT
	):
		return "Flora criterion has an invalid evidence channel."

	if (
		not is_finite(minimum)
		or not is_finite(ideal_minimum)
		or not is_finite(ideal_maximum)
		or not is_finite(maximum)
	):
		return "Flora criterion bounds must be finite."

	if (
		minimum > ideal_minimum
		or ideal_minimum > ideal_maximum
		or ideal_maximum > maximum
	):
		return (
			"Flora criterion bounds must be ordered: "
			+ "minimum <= ideal minimum <= "
			+ "ideal maximum <= maximum."
		)

	if not is_finite(weight) or weight <= 0.0:
		return "Flora criterion weight must be positive."

	return ""
