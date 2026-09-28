class_name DepthProvinceSnapshot
extends RefCounted

## Immutable by convention after construction.
## All distances and depths are measured in meters.

var primary_frequency: float = 0.000012
var secondary_frequency: float = 0.000031
var depth_variation_frequency: float = 0.000020

## Transition from the shallow shelf to the deep province.
var shelf_transition_start: float = 0.38
var shelf_transition_end: float = 0.50

## Transition from the deep province to the abyssal province.
var abyssal_transition_start: float = 0.56
var abyssal_transition_end: float = 0.68

var deep_minimum_depth: float = 800.0
var deep_maximum_depth: float = 1800.0

var abyssal_minimum_depth: float = 2200.0
var abyssal_maximum_depth: float = 3200.0

## Keeps the initial world origin in a broad shallow province.
var starting_shelf_radius: float = 6000.0
var starting_shelf_fade_width: float = 10000.0


func _init(
	new_primary_frequency: float = 0.000012,
	new_secondary_frequency: float = 0.000031,
	new_depth_variation_frequency: float = 0.000020,
	new_shelf_transition_start: float = 0.38,
	new_shelf_transition_end: float = 0.50,
	new_abyssal_transition_start: float = 0.56,
	new_abyssal_transition_end: float = 0.68,
	new_deep_minimum_depth: float = 800.0,
	new_deep_maximum_depth: float = 1800.0,
	new_abyssal_minimum_depth: float = 2200.0,
	new_abyssal_maximum_depth: float = 3200.0,
	new_starting_shelf_radius: float = 6000.0,
	new_starting_shelf_fade_width: float = 10000.0
) -> void:
	primary_frequency = new_primary_frequency
	secondary_frequency = new_secondary_frequency

	depth_variation_frequency = (
		new_depth_variation_frequency
	)

	shelf_transition_start = new_shelf_transition_start
	shelf_transition_end = new_shelf_transition_end

	abyssal_transition_start = (
		new_abyssal_transition_start
	)

	abyssal_transition_end = (
		new_abyssal_transition_end
	)

	deep_minimum_depth = new_deep_minimum_depth
	deep_maximum_depth = new_deep_maximum_depth

	abyssal_minimum_depth = new_abyssal_minimum_depth
	abyssal_maximum_depth = new_abyssal_maximum_depth

	starting_shelf_radius = new_starting_shelf_radius

	starting_shelf_fade_width = (
		new_starting_shelf_fade_width
	)


static func from_settings(
	settings: GeologySettings
) -> DepthProvinceSnapshot:
	assert(settings != null)

	return DepthProvinceSnapshot.new(
		settings.depth_province_primary_frequency,
		settings.depth_province_secondary_frequency,
		settings.depth_province_variation_frequency,
		settings.shelf_transition_start,
		settings.shelf_transition_end,
		settings.abyssal_transition_start,
		settings.abyssal_transition_end,
		settings.deep_province_minimum_depth,
		settings.deep_province_maximum_depth,
		settings.abyssal_province_minimum_depth,
		settings.abyssal_province_maximum_depth,
		settings.starting_shelf_radius,
		settings.starting_shelf_fade_width
	)


func validate(
	maximum_seabed_depth: float
) -> PackedStringArray:
	var errors := PackedStringArray()

	var frequencies: Array[float] = [
		primary_frequency,
		secondary_frequency,
		depth_variation_frequency
	]

	for frequency in frequencies:
		if (
			not is_finite(frequency)
			or frequency <= 0.0
		):
			errors.append(
				"All depth-province frequencies must be "
				+ "finite and positive."
			)
			break

	if (
		not is_finite(shelf_transition_start)
		or not is_finite(shelf_transition_end)
		or shelf_transition_start < 0.0
		or shelf_transition_end
		<= shelf_transition_start
		or shelf_transition_end >= 1.0
	):
		errors.append(
			"The shelf transition thresholds are invalid."
		)

	if (
		not is_finite(abyssal_transition_start)
		or not is_finite(abyssal_transition_end)
		or abyssal_transition_start
		<= shelf_transition_end
		or abyssal_transition_end
		<= abyssal_transition_start
		or abyssal_transition_end > 1.0
	):
		errors.append(
			"The abyssal transition thresholds are invalid."
		)

	if (
		not is_finite(deep_minimum_depth)
		or not is_finite(deep_maximum_depth)
		or deep_minimum_depth <= 0.0
		or deep_maximum_depth
		<= deep_minimum_depth
	):
		errors.append(
			"The deep-province depth range is invalid."
		)

	if (
		not is_finite(abyssal_minimum_depth)
		or not is_finite(abyssal_maximum_depth)
		or abyssal_minimum_depth
		<= deep_minimum_depth
		or abyssal_maximum_depth
		<= abyssal_minimum_depth
		or abyssal_maximum_depth
		> maximum_seabed_depth
	):
		errors.append(
			"The abyssal-province depth range is invalid."
		)

	if (
		not is_finite(starting_shelf_radius)
		or starting_shelf_radius < 0.0
	):
		errors.append(
			"starting_shelf_radius must be finite "
			+ "and non-negative."
		)

	if (
		not is_finite(starting_shelf_fade_width)
		or starting_shelf_fade_width <= 0.0
	):
		errors.append(
			"starting_shelf_fade_width must be finite "
			+ "and positive."
		)

	return errors
