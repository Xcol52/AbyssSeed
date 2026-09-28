class_name ConvergentProfile
extends RefCounted

const TRENCH_TIER_NONE: int = 0
const TRENCH_TIER_ORDINARY: int = 1
const TRENCH_TIER_MAJOR: int = 2
const TRENCH_TIER_EXTREME: int = 3

const PROFILE_EPSILON: float = 0.000001

const OVERRIDING_AFFINITY_EPSILON: float = 0.08

const OVERRIDING_SIDE_CHANNEL: int = 4701
const TRENCH_TIER_CHANNEL: int = 4703
const TRENCH_VARIATION_NOISE_CHANNEL: int = 4711


static func create_descriptor(
	geology_seed: int,
	first_site: GeologyPlateSite,
	second_site: GeologyPlateSite,
	settings: ConvergentReliefSnapshot
) -> ConvergentBoundaryDescriptor:
	assert(first_site != null)
	assert(second_site != null)
	assert(settings != null)
	assert(first_site.plate_id != second_site.plate_id)

	var lower_site: GeologyPlateSite
	var higher_site: GeologyPlateSite

	if first_site.plate_id < second_site.plate_id:
		lower_site = first_site
		higher_site = second_site
	else:
		lower_site = second_site
		higher_site = first_site

	var overriding_plate_id: int

	var affinity_difference := (
		first_site.continental_affinity
		- second_site.continental_affinity
	)

	if (
		affinity_difference
		> OVERRIDING_AFFINITY_EPSILON
	):
		overriding_plate_id = first_site.plate_id
	elif (
		affinity_difference
		< -OVERRIDING_AFFINITY_EPSILON
	):
		overriding_plate_id = second_site.plate_id
	else:
		var side_roll := _pair_unit_value(
			geology_seed,
			OVERRIDING_SIDE_CHANNEL,
			lower_site,
			higher_site
		)

		if side_roll < 0.5:
			overriding_plate_id = lower_site.plate_id
		else:
			overriding_plate_id = higher_site.plate_id

	var tier_roll := _pair_unit_value(
		geology_seed,
		TRENCH_TIER_CHANNEL,
		lower_site,
		higher_site
	)

	var extreme_end := settings.extreme_probability

	var major_end := (
		extreme_end
		+ settings.major_probability
	)

	var ordinary_end := (
		major_end
		+ settings.ordinary_probability
	)

	var trench_tier := TRENCH_TIER_NONE

	if tier_roll < extreme_end:
		trench_tier = TRENCH_TIER_EXTREME
	elif tier_roll < major_end:
		trench_tier = TRENCH_TIER_MAJOR
	elif tier_roll < ordinary_end:
		trench_tier = TRENCH_TIER_ORDINARY

	return ConvergentBoundaryDescriptor.new(
		lower_site.plate_id,
		higher_site.plate_id,
		overriding_plate_id,
		trench_tier
	)


static func calculate_influence(
	distance_from_boundary: float,
	influence_width: float
) -> float:
	if influence_width <= PROFILE_EPSILON:
		return 0.0

	return (
		1.0
		- _smoothstep(
			0.0,
			influence_width,
			absf(distance_from_boundary)
		)
	)


static func calculate_convergence_activity(
	compression_rate: float
) -> float:
	return _smoothstep(
		0.015,
		0.32,
		clampf(
			compression_rate,
			0.0,
			1.0
		)
	)


static func get_width_multiplier(
	trench_tier: int,
	settings: ConvergentReliefSnapshot
) -> float:
	match trench_tier:
		TRENCH_TIER_ORDINARY:
			return 1.0

		TRENCH_TIER_MAJOR:
			return settings.major_width_multiplier

		TRENCH_TIER_EXTREME:
			return settings.extreme_width_multiplier

		_:
			return 0.0


static func get_descending_width(
	trench_tier: int,
	settings: ConvergentReliefSnapshot
) -> float:
	return (
		settings.descending_trench_width
		* get_width_multiplier(
			trench_tier,
			settings
		)
	)


static func get_overriding_width(
	trench_tier: int,
	settings: ConvergentReliefSnapshot
) -> float:
	return (
		settings.overriding_trench_width
		* get_width_multiplier(
			trench_tier,
			settings
		)
	)


static func get_floor_fraction(
	trench_tier: int,
	settings: ConvergentReliefSnapshot
) -> float:
	match trench_tier:
		TRENCH_TIER_ORDINARY:
			return settings.ordinary_floor_fraction

		TRENCH_TIER_MAJOR:
			return settings.major_floor_fraction

		TRENCH_TIER_EXTREME:
			return settings.extreme_floor_fraction

		_:
			return 0.0


## Positive distance is on the overriding plate.
## Negative distance is on the descending plate.
static func calculate_trench_influence(
	signed_distance: float,
	descending_width: float,
	overriding_width: float,
	floor_fraction: float = 0.0
) -> float:
	var width := descending_width

	if signed_distance >= 0.0:
		width = overriding_width

	if width <= PROFILE_EPSILON:
		return 0.0

	var distance := absf(signed_distance)

	var floor_width := (
		width
		* clampf(
			floor_fraction,
			0.0,
			0.75
		)
	)

	if distance <= floor_width:
		return 1.0

	return (
		1.0
		- _smoothstep(
			floor_width,
			width,
			distance
		)
	)


## Restricts trench tiers to appropriate lower-depth provinces.
static func calculate_depth_eligibility(
	trench_tier: int,
	province_target_depth: float,
	deep_province_influence: float,
	abyssal_province_influence: float
) -> float:
	var deep := clampf(
		deep_province_influence,
		0.0,
		1.0
	)

	var abyssal := clampf(
		abyssal_province_influence,
		0.0,
		1.0
	)

	match trench_tier:
		TRENCH_TIER_ORDINARY:
			var province_gate := clampf(
				deep + abyssal,
				0.0,
				1.0
			)

			var depth_gate := _smoothstep(
				1200.0,
				1800.0,
				province_target_depth
			)

			return province_gate * depth_gate

		TRENCH_TIER_MAJOR:
			var province_gate := clampf(
				deep * 0.25 + abyssal,
				0.0,
				1.0
			)

			var depth_gate := _smoothstep(
				1800.0,
				2400.0,
				province_target_depth
			)

			return province_gate * depth_gate

		TRENCH_TIER_EXTREME:
			var depth_gate := _smoothstep(
				2400.0,
				2900.0,
				province_target_depth
			)

			return abyssal * depth_gate

		_:
			return 0.0


static func calculate_uplift_influence(
	signed_distance: float,
	peak_offset: float,
	uplift_width: float
) -> float:
	if (
		signed_distance <= 0.0
		or peak_offset <= PROFILE_EPSILON
		or uplift_width <= peak_offset
	):
		return 0.0

	if signed_distance <= peak_offset:
		return _smoothstep(
			0.0,
			peak_offset,
			signed_distance
		)

	return (
		1.0
		- _smoothstep(
			peak_offset,
			uplift_width,
			signed_distance
		)
	)


static func calculate_subduction_eligibility(
	first_continental_affinity: float,
	second_continental_affinity: float
) -> float:
	var first := clampf(
		first_continental_affinity,
		0.0,
		1.0
	)

	var second := clampf(
		second_continental_affinity,
		0.0,
		1.0
	)

	return clampf(
		1.0 - first * second,
		0.0,
		1.0
	)


static func calculate_target_depth(
	trench_tier: int,
	settings: ConvergentReliefSnapshot,
	variation_noise_value: float
) -> float:
	assert(settings != null)

	var base_target: float

	match trench_tier:
		TRENCH_TIER_ORDINARY:
			base_target = settings.ordinary_target_depth

		TRENCH_TIER_MAJOR:
			base_target = settings.major_target_depth

		TRENCH_TIER_EXTREME:
			base_target = settings.extreme_target_depth

		_:
			return 0.0

	var normalized_variation := clampf(
		variation_noise_value * 0.5 + 0.5,
		0.0,
		1.0
	)

	var depth_multiplier := lerpf(
		1.0 - settings.depth_variation_strength,
		1.0,
		normalized_variation
	)

	return base_target * depth_multiplier


static func calculate_broad_depression_contribution(
	convergent_potential: float,
	maximum_depth: float
) -> float:
	return (
		-clampf(
			convergent_potential,
			0.0,
			1.0
		)
		* maxf(maximum_depth, 0.0)
	)


static func calculate_trench_contribution(
	pre_trench_elevation: float,
	target_total_depth: float,
	trench_potential: float
) -> float:
	if (
		target_total_depth <= 0.0
		or trench_potential <= 0.0
	):
		return 0.0

	var target_elevation := -target_total_depth

	var full_contribution := minf(
		target_elevation - pre_trench_elevation,
		0.0
	)

	return (
		full_contribution
		* clampf(
			trench_potential,
			0.0,
			1.0
		)
	)


static func calculate_uplift_contribution(
	uplift_potential: float,
	maximum_uplift: float
) -> float:
	return (
		clampf(
			uplift_potential,
			0.0,
			1.0
		)
		* maxf(maximum_uplift, 0.0)
	)


static func _pair_unit_value(
	geology_seed: int,
	channel_id: int,
	lower_site: GeologyPlateSite,
	higher_site: GeologyPlateSite
) -> float:
	var lower_seed := StableSeed.derive_spatial_seed(
		geology_seed,
		channel_id,
		lower_site.cell_coordinate
	)

	var pair_seed := StableSeed.derive_spatial_seed(
		lower_seed,
		channel_id + 1,
		higher_site.cell_coordinate
	)

	return StableSeed.seed_to_unit_float(
		pair_seed
	)


static func _smoothstep(
	edge_zero: float,
	edge_one: float,
	value: float
) -> float:
	if is_equal_approx(edge_zero, edge_one):
		return 0.0

	var factor := clampf(
		(value - edge_zero)
		/ (edge_one - edge_zero),
		0.0,
		1.0
	)

	return (
		factor
		* factor
		* (3.0 - 2.0 * factor)
	)
