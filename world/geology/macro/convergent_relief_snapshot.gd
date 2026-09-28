class_name ConvergentReliefSnapshot
extends RefCounted

## Immutable by convention after construction.
## Distances, depths, and elevations are measured in meters.

var influence_width: float = 3000.0
var broad_depression_depth: float = 90.0

## Ordinary/4 km trench widths.
var descending_trench_width: float = 1600.0
var overriding_trench_width: float = 1000.0

## Major and extreme profiles scale the ordinary widths.
var major_width_multiplier: float = 2.0
var extreme_width_multiplier: float = 4.5

## Fraction of each side width occupied by the flat floor.
var ordinary_floor_fraction: float = 0.08
var major_floor_fraction: float = 0.14
var extreme_floor_fraction: float = 0.28

## Literal total-depth targets.
var ordinary_target_depth: float = 4000.0
var major_target_depth: float = 5000.0
var extreme_target_depth: float = 6000.0

## Pair-level outcomes. The unallocated probability means no trench.
var ordinary_probability: float = 0.18
var major_probability: float = 0.07
var extreme_probability: float = 0.03

## Slow variation along the trench corridor.
var depth_variation_frequency: float = 0.000025
var depth_variation_strength: float = 0.10

var uplift_width: float = 3200.0
var uplift_peak_offset: float = 1000.0
var maximum_uplift: float = 420.0


func _init(
	new_influence_width: float = 3000.0,
	new_broad_depression_depth: float = 90.0,
	new_descending_trench_width: float = 1600.0,
	new_overriding_trench_width: float = 1000.0,
	new_ordinary_target_depth: float = 4000.0,
	new_major_target_depth: float = 5000.0,
	new_extreme_target_depth: float = 6000.0,
	new_major_probability: float = 0.07,
	new_extreme_probability: float = 0.03,
	new_depth_variation_frequency: float = 0.000025,
	new_depth_variation_strength: float = 0.10,
	new_uplift_width: float = 3200.0,
	new_uplift_peak_offset: float = 1000.0,
	new_maximum_uplift: float = 420.0,
	new_ordinary_probability: float = 0.18,
	new_major_width_multiplier: float = 2.0,
	new_extreme_width_multiplier: float = 4.5,
	new_ordinary_floor_fraction: float = 0.08,
	new_major_floor_fraction: float = 0.14,
	new_extreme_floor_fraction: float = 0.28
) -> void:
	influence_width = new_influence_width
	broad_depression_depth = new_broad_depression_depth

	descending_trench_width = (
		new_descending_trench_width
	)

	overriding_trench_width = (
		new_overriding_trench_width
	)

	major_width_multiplier = (
		new_major_width_multiplier
	)

	extreme_width_multiplier = (
		new_extreme_width_multiplier
	)

	ordinary_floor_fraction = (
		new_ordinary_floor_fraction
	)

	major_floor_fraction = (
		new_major_floor_fraction
	)

	extreme_floor_fraction = (
		new_extreme_floor_fraction
	)

	ordinary_target_depth = new_ordinary_target_depth
	major_target_depth = new_major_target_depth
	extreme_target_depth = new_extreme_target_depth

	ordinary_probability = new_ordinary_probability
	major_probability = new_major_probability
	extreme_probability = new_extreme_probability

	depth_variation_frequency = (
		new_depth_variation_frequency
	)

	depth_variation_strength = (
		new_depth_variation_strength
	)

	uplift_width = new_uplift_width
	uplift_peak_offset = new_uplift_peak_offset
	maximum_uplift = new_maximum_uplift


static func from_settings(
	settings: GeologySettings
) -> ConvergentReliefSnapshot:
	assert(settings != null)

	return ConvergentReliefSnapshot.new(
		settings.convergent_influence_width,
		settings.convergent_depression_depth,
		settings.trench_descending_width,
		settings.trench_overriding_width,
		settings.ordinary_trench_target_depth,
		settings.major_trench_target_depth,
		settings.extreme_trench_target_depth,
		settings.major_trench_probability,
		settings.extreme_trench_probability,
		settings.trench_depth_variation_frequency,
		settings.trench_depth_variation_strength,
		settings.overriding_uplift_width,
		settings.overriding_uplift_peak_offset,
		settings.maximum_overriding_uplift,
		settings.ordinary_trench_probability,
		settings.major_trench_width_multiplier,
		settings.extreme_trench_width_multiplier,
		settings.ordinary_trench_floor_fraction,
		settings.major_trench_floor_fraction,
		settings.extreme_trench_floor_fraction
	)


func validate(
	plate_cell_size: float,
	maximum_seabed_depth: float
) -> PackedStringArray:
	var errors := PackedStringArray()

	if (
		not is_finite(influence_width)
		or influence_width <= 0.0
		or influence_width >= plate_cell_size
	):
		errors.append(
			"convergent_influence_width must be positive "
			+ "and less than plate_cell_size."
		)

	if (
		not is_finite(broad_depression_depth)
		or broad_depression_depth < 0.0
	):
		errors.append(
			"convergent_depression_depth must be finite "
			+ "and non-negative."
		)

	if (
		not is_finite(descending_trench_width)
		or descending_trench_width <= 0.0
	):
		errors.append(
			"trench_descending_width must be positive."
		)

	if (
		not is_finite(overriding_trench_width)
		or overriding_trench_width <= 0.0
	):
		errors.append(
			"trench_overriding_width must be positive."
		)

	if overriding_trench_width >= descending_trench_width:
		errors.append(
			"trench_overriding_width must be less than "
			+ "trench_descending_width."
		)

	if (
		not is_finite(major_width_multiplier)
		or major_width_multiplier < 1.0
		or not is_finite(extreme_width_multiplier)
		or extreme_width_multiplier
		<= major_width_multiplier
	):
		errors.append(
			"Trench width multipliers must be ordered "
			+ "and at least one."
		)

	var maximum_profile_width := maxf(
		descending_trench_width,
		overriding_trench_width
	) * extreme_width_multiplier

	if maximum_profile_width >= plate_cell_size:
		errors.append(
			"The extreme trench side width must be less "
			+ "than plate_cell_size."
		)

	var floor_fractions: Array[float] = [
		ordinary_floor_fraction,
		major_floor_fraction,
		extreme_floor_fraction
	]

	for floor_fraction in floor_fractions:
		if (
			not is_finite(floor_fraction)
			or floor_fraction < 0.0
			or floor_fraction >= 0.75
		):
			errors.append(
				"Trench floor fractions must be between "
				+ "zero and 0.75."
			)
			break

	if (
		major_floor_fraction
		< ordinary_floor_fraction
		or extreme_floor_fraction
		< major_floor_fraction
	):
		errors.append(
			"Deeper trench tiers must not have narrower "
			+ "relative floors."
		)

	if (
		not is_finite(ordinary_target_depth)
		or not is_finite(major_target_depth)
		or not is_finite(extreme_target_depth)
		or ordinary_target_depth <= 0.0
		or major_target_depth <= ordinary_target_depth
		or extreme_target_depth <= major_target_depth
		or extreme_target_depth > maximum_seabed_depth
	):
		errors.append(
			"Trench targets must be positive, ordered, "
			+ "and inside maximum_seabed_depth."
		)

	var total_probability := (
		ordinary_probability
		+ major_probability
		+ extreme_probability
	)

	if (
		not is_finite(ordinary_probability)
		or not is_finite(major_probability)
		or not is_finite(extreme_probability)
		or ordinary_probability < 0.0
		or major_probability < 0.0
		or extreme_probability < 0.0
		or total_probability > 1.0
	):
		errors.append(
			"Trench probabilities must be non-negative "
			+ "and total no more than one."
		)

	if (
		not is_finite(depth_variation_frequency)
		or depth_variation_frequency <= 0.0
	):
		errors.append(
			"trench_depth_variation_frequency must be "
			+ "finite and positive."
		)

	if (
		not is_finite(depth_variation_strength)
		or depth_variation_strength < 0.0
		or depth_variation_strength > 0.25
	):
		errors.append(
			"trench_depth_variation_strength must be "
			+ "between zero and 0.25."
		)

	if (
		not is_finite(uplift_width)
		or uplift_width <= 0.0
		or uplift_width >= plate_cell_size
	):
		errors.append(
			"overriding_uplift_width must be positive "
			+ "and less than plate_cell_size."
		)

	if (
		not is_finite(uplift_peak_offset)
		or uplift_peak_offset <= 0.0
		or uplift_peak_offset >= uplift_width
	):
		errors.append(
			"overriding_uplift_peak_offset must be positive "
			+ "and less than overriding_uplift_width."
		)

	if (
		not is_finite(maximum_uplift)
		or maximum_uplift < 0.0
	):
		errors.append(
			"maximum_overriding_uplift must be finite "
			+ "and non-negative."
		)

	return errors
