class_name PlateInteriorReliefSnapshot
extends RefCounted

## Immutable by convention after construction.
## All dimensions and relief values are measured in world meters.

var boundary_fade_width: float = 260.0

var hill_count: int = 5
var hill_min_radius: float = 220.0
var hill_max_radius: float = 720.0
var hill_min_height: float = 14.0
var hill_max_height: float = 68.0

var terrace_count: int = 2
var terrace_min_length: float = 600.0
var terrace_max_length: float = 1700.0
var terrace_min_width: float = 160.0
var terrace_max_width: float = 420.0
var terrace_min_relief: float = 8.0
var terrace_max_relief: float = 38.0

var massif_probability: float = 0.45
var massif_min_radius: float = 600.0
var massif_max_radius: float = 1300.0
var massif_min_height: float = 90.0
var massif_max_height: float = 280.0

var depression_probability: float = 0.55
var depression_min_radius: float = 500.0
var depression_max_radius: float = 1200.0
var depression_min_depth: float = 35.0
var depression_max_depth: float = 140.0


func _init(
	new_boundary_fade_width: float = 260.0,
	new_hill_count: int = 5,
	new_hill_min_radius: float = 220.0,
	new_hill_max_radius: float = 720.0,
	new_hill_min_height: float = 14.0,
	new_hill_max_height: float = 68.0,
	new_terrace_count: int = 2,
	new_terrace_min_length: float = 600.0,
	new_terrace_max_length: float = 1700.0,
	new_terrace_min_width: float = 160.0,
	new_terrace_max_width: float = 420.0,
	new_terrace_min_relief: float = 8.0,
	new_terrace_max_relief: float = 38.0,
	new_massif_probability: float = 0.45,
	new_massif_min_radius: float = 600.0,
	new_massif_max_radius: float = 1300.0,
	new_massif_min_height: float = 90.0,
	new_massif_max_height: float = 280.0,
	new_depression_probability: float = 0.55,
	new_depression_min_radius: float = 500.0,
	new_depression_max_radius: float = 1200.0,
	new_depression_min_depth: float = 35.0,
	new_depression_max_depth: float = 140.0
) -> void:
	boundary_fade_width = new_boundary_fade_width

	hill_count = new_hill_count
	hill_min_radius = new_hill_min_radius
	hill_max_radius = new_hill_max_radius
	hill_min_height = new_hill_min_height
	hill_max_height = new_hill_max_height

	terrace_count = new_terrace_count
	terrace_min_length = new_terrace_min_length
	terrace_max_length = new_terrace_max_length
	terrace_min_width = new_terrace_min_width
	terrace_max_width = new_terrace_max_width
	terrace_min_relief = new_terrace_min_relief
	terrace_max_relief = new_terrace_max_relief

	massif_probability = new_massif_probability
	massif_min_radius = new_massif_min_radius
	massif_max_radius = new_massif_max_radius
	massif_min_height = new_massif_min_height
	massif_max_height = new_massif_max_height

	depression_probability = new_depression_probability
	depression_min_radius = new_depression_min_radius
	depression_max_radius = new_depression_max_radius
	depression_min_depth = new_depression_min_depth
	depression_max_depth = new_depression_max_depth


static func from_settings(
	settings: GeologySettings
) -> PlateInteriorReliefSnapshot:
	assert(settings != null)

	return PlateInteriorReliefSnapshot.new(
		settings.interior_boundary_fade_width,
		settings.interior_hill_count,
		settings.hill_min_radius,
		settings.hill_max_radius,
		settings.hill_min_height,
		settings.hill_max_height,
		settings.interior_terrace_count,
		settings.terrace_min_length,
		settings.terrace_max_length,
		settings.terrace_min_width,
		settings.terrace_max_width,
		settings.terrace_min_relief,
		settings.terrace_max_relief,
		settings.massif_probability,
		settings.massif_min_radius,
		settings.massif_max_radius,
		settings.massif_min_height,
		settings.massif_max_height,
		settings.interior_depression_probability,
		settings.depression_min_radius,
		settings.depression_max_radius,
		settings.depression_min_depth,
		settings.depression_max_depth
	)


func validate(
	plate_cell_size: float
) -> PackedStringArray:
	var errors := PackedStringArray()

	if (
		not is_finite(boundary_fade_width)
		or boundary_fade_width <= 0.0
		or boundary_fade_width >= plate_cell_size
	):
		errors.append(
			"interior_boundary_fade_width must be positive "
			+ "and less than plate_cell_size."
		)

	if hill_count < 1 or hill_count > 8:
		errors.append(
			"interior_hill_count must be between 1 and 8."
		)

	_validate_positive_interval(
		hill_min_radius,
		hill_max_radius,
		"hill radius",
		errors
	)

	_validate_positive_interval(
		hill_min_height,
		hill_max_height,
		"hill height",
		errors
	)

	if terrace_count < 0 or terrace_count > 4:
		errors.append(
			"interior_terrace_count must be between 0 and 4."
		)

	_validate_positive_interval(
		terrace_min_length,
		terrace_max_length,
		"terrace length",
		errors
	)

	_validate_positive_interval(
		terrace_min_width,
		terrace_max_width,
		"terrace width",
		errors
	)

	_validate_positive_interval(
		terrace_min_relief,
		terrace_max_relief,
		"terrace relief",
		errors
	)

	if (
		not is_finite(massif_probability)
		or massif_probability < 0.0
		or massif_probability > 1.0
	):
		errors.append(
			"massif_probability must be between 0 and 1."
		)

	_validate_positive_interval(
		massif_min_radius,
		massif_max_radius,
		"massif radius",
		errors
	)

	_validate_positive_interval(
		massif_min_height,
		massif_max_height,
		"massif height",
		errors
	)

	if (
		not is_finite(depression_probability)
		or depression_probability < 0.0
		or depression_probability > 1.0
	):
		errors.append(
			"interior_depression_probability must be "
			+ "between 0 and 1."
		)

	_validate_positive_interval(
		depression_min_radius,
		depression_max_radius,
		"depression radius",
		errors
	)

	_validate_positive_interval(
		depression_min_depth,
		depression_max_depth,
		"depression depth",
		errors
	)

	return errors


static func _validate_positive_interval(
	minimum_value: float,
	maximum_value: float,
	description: String,
	errors: PackedStringArray
) -> void:
	if (
		not is_finite(minimum_value)
		or not is_finite(maximum_value)
		or minimum_value <= 0.0
		or maximum_value < minimum_value
	):
		errors.append(
			"%s range must be finite, positive, and ordered."
			% description
		)
