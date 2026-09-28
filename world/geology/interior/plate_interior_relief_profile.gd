class_name PlateInteriorReliefProfile
extends RefCounted

## These channels are deliberately separate from the existing
## GeologyChannels values.
const HILL_BASE_ANGLE: int = 4101
const HILL_RADIAL_DISTANCE: int = 4121
const HILL_RADIUS: int = 4141
const HILL_ASPECT: int = 4161
const HILL_ORIENTATION: int = 4181
const HILL_HEIGHT: int = 4201
const HILL_SHAPE: int = 4221
const HILL_ANGLE_JITTER: int = 4241

const TERRACE_BASE_ANGLE: int = 4301
const TERRACE_RADIAL_DISTANCE: int = 4321
const TERRACE_LENGTH: int = 4341
const TERRACE_WIDTH: int = 4361
const TERRACE_ORIENTATION: int = 4381
const TERRACE_RELIEF: int = 4401
const TERRACE_POLARITY: int = 4421
const TERRACE_TILT: int = 4441

const MASSIF_ELIGIBILITY: int = 4501
const MASSIF_ANCHOR_ANGLE: int = 4502
const MASSIF_ANCHOR_DISTANCE: int = 4503
const MASSIF_RADIUS: int = 4504
const MASSIF_ASPECT: int = 4505
const MASSIF_ORIENTATION: int = 4506
const MASSIF_HEIGHT: int = 4507
const MASSIF_LOBE_ANGLE: int = 4508
const MASSIF_LOBE_DISTANCE: int = 4509

const DEPRESSION_ELIGIBILITY: int = 4601
const DEPRESSION_ANCHOR_ANGLE: int = 4602
const DEPRESSION_ANCHOR_DISTANCE: int = 4603
const DEPRESSION_RADIUS: int = 4604
const DEPRESSION_ASPECT: int = 4605
const DEPRESSION_ORIENTATION: int = 4606
const DEPRESSION_DEPTH: int = 4607

const GOLDEN_ANGLE_RADIANS: float = 2.399963229728653
const PROFILE_EPSILON: float = 0.000001


static func create_descriptor(
	geology_seed: int,
	plate_site: GeologyPlateSite,
	plate_cell_size: float,
	settings: PlateInteriorReliefSnapshot
) -> PlateInteriorReliefDescriptor:
	assert(plate_site != null)
	assert(settings != null)
	assert(plate_cell_size > 0.0)

	var descriptor := PlateInteriorReliefDescriptor.new()
	var cell := plate_site.cell_coordinate

	var hill_base_angle := (
		_unit_value(
			geology_seed,
			HILL_BASE_ANGLE,
			cell
		)
		* TAU
	)

	for hill_index in range(settings.hill_count):
		var angle_jitter := (
			_signed_value(
				geology_seed,
				HILL_ANGLE_JITTER + hill_index,
				cell
			)
			* 0.55
		)

		var anchor_angle := (
			hill_base_angle
			+ float(hill_index)
			* GOLDEN_ANGLE_RADIANS
			+ angle_jitter
		)

		var minimum_radial_fraction := 0.12
		var maximum_radial_fraction := 0.42

		if hill_index == 0:
			minimum_radial_fraction = 0.0
			maximum_radial_fraction = 0.14

		var radial_distance := lerpf(
			minimum_radial_fraction,
			maximum_radial_fraction,
			_unit_value(
				geology_seed,
				HILL_RADIAL_DISTANCE + hill_index,
				cell
			)
		) * plate_cell_size

		var hill_center := (
			plate_site.position
			+ Vector2(
				cos(anchor_angle),
				sin(anchor_angle)
			) * radial_distance
		)

		var primary_radius := lerpf(
			settings.hill_min_radius,
			settings.hill_max_radius,
			_unit_value(
				geology_seed,
				HILL_RADIUS + hill_index,
				cell
			)
		)

		var aspect := lerpf(
			0.55,
			1.20,
			_unit_value(
				geology_seed,
				HILL_ASPECT + hill_index,
				cell
			)
		)

		var hill_radii := Vector2(
			primary_radius,
			primary_radius * aspect
		)

		var hill_orientation := (
			_unit_value(
				geology_seed,
				HILL_ORIENTATION + hill_index,
				cell
			)
			* TAU
		)

		var hill_height := lerpf(
			settings.hill_min_height,
			settings.hill_max_height,
			_unit_value(
				geology_seed,
				HILL_HEIGHT + hill_index,
				cell
			)
		)

		var hill_shape_power := lerpf(
			0.75,
			1.55,
			_unit_value(
				geology_seed,
				HILL_SHAPE + hill_index,
				cell
			)
		)

		descriptor.hill_centers.append(hill_center)
		descriptor.hill_radii.append(hill_radii)
		descriptor.hill_angles.append(hill_orientation)
		descriptor.hill_heights.append(hill_height)
		descriptor.hill_shape_powers.append(
			hill_shape_power
		)

	descriptor.hill_relief_cap = (
		settings.hill_max_height * 1.65
	)

	var terrace_base_angle := (
		_unit_value(
			geology_seed,
			TERRACE_BASE_ANGLE,
			cell
		)
		* TAU
	)

	for terrace_index in range(settings.terrace_count):
		var anchor_angle := (
			terrace_base_angle
			+ float(terrace_index)
			* GOLDEN_ANGLE_RADIANS
			+ _signed_value(
				geology_seed,
				TERRACE_ORIENTATION + terrace_index,
				cell
			) * 0.45
		)

		var radial_distance := lerpf(
			plate_cell_size * 0.08,
			plate_cell_size * 0.38,
			_unit_value(
				geology_seed,
				TERRACE_RADIAL_DISTANCE
					+ terrace_index,
				cell
			)
		)

		var center := (
			plate_site.position
			+ Vector2(
				cos(anchor_angle),
				sin(anchor_angle)
			) * radial_distance
		)

		var full_length := lerpf(
			settings.terrace_min_length,
			settings.terrace_max_length,
			_unit_value(
				geology_seed,
				TERRACE_LENGTH + terrace_index,
				cell
			)
		)

		var full_width := lerpf(
			settings.terrace_min_width,
			settings.terrace_max_width,
			_unit_value(
				geology_seed,
				TERRACE_WIDTH + terrace_index,
				cell
			)
		)

		var half_width := full_width * 0.5

		var orientation := (
			_unit_value(
				geology_seed,
				TERRACE_ORIENTATION + terrace_index,
				cell
			)
			* TAU
		)

		var relief := lerpf(
			settings.terrace_min_relief,
			settings.terrace_max_relief,
			_unit_value(
				geology_seed,
				TERRACE_RELIEF + terrace_index,
				cell
			)
		)

		## Most terraces are raised benches. Some are lowered steps.
		if (
			_unit_value(
				geology_seed,
				TERRACE_POLARITY + terrace_index,
				cell
			)
			< 0.30
		):
			relief = -relief

		var tilt := (
			_signed_value(
				geology_seed,
				TERRACE_TILT + terrace_index,
				cell
			)
			* 0.22
		)

		descriptor.terrace_centers.append(center)
		descriptor.terrace_half_lengths.append(
			full_length * 0.5
		)
		descriptor.terrace_half_widths.append(
			half_width
		)
		descriptor.terrace_transition_widths.append(
			half_width
			* lerpf(
				0.18,
				0.34,
				_unit_value(
					geology_seed,
					TERRACE_WIDTH
						+ 8
						+ terrace_index,
					cell
				)
			)
		)
		descriptor.terrace_angles.append(orientation)
		descriptor.terrace_relief.append(relief)
		descriptor.terrace_tilts.append(tilt)

	descriptor.massif_enabled = (
		_unit_value(
			geology_seed,
			MASSIF_ELIGIBILITY,
			cell
		)
		< settings.massif_probability
	)

	if descriptor.massif_enabled:
		var anchor_angle := (
			_unit_value(
				geology_seed,
				MASSIF_ANCHOR_ANGLE,
				cell
			)
			* TAU
		)

		var anchor_distance := (
			_unit_value(
				geology_seed,
				MASSIF_ANCHOR_DISTANCE,
				cell
			)
			* plate_cell_size
			* 0.24
		)

		descriptor.massif_center = (
			plate_site.position
			+ Vector2(
				cos(anchor_angle),
				sin(anchor_angle)
			) * anchor_distance
		)

		var massif_radius := lerpf(
			settings.massif_min_radius,
			settings.massif_max_radius,
			_unit_value(
				geology_seed,
				MASSIF_RADIUS,
				cell
			)
		)

		var massif_aspect := lerpf(
			0.62,
			1.10,
			_unit_value(
				geology_seed,
				MASSIF_ASPECT,
				cell
			)
		)

		descriptor.massif_radii = Vector2(
			massif_radius,
			massif_radius * massif_aspect
		)

		descriptor.massif_angle = (
			_unit_value(
				geology_seed,
				MASSIF_ORIENTATION,
				cell
			)
			* TAU
		)

		descriptor.massif_height = lerpf(
			settings.massif_min_height,
			settings.massif_max_height,
			_unit_value(
				geology_seed,
				MASSIF_HEIGHT,
				cell
			)
		)

		var lobe_angle := (
			_unit_value(
				geology_seed,
				MASSIF_LOBE_ANGLE,
				cell
			)
			* TAU
		)

		var lobe_distance := (
			minf(
				descriptor.massif_radii.x,
				descriptor.massif_radii.y
			)
			* lerpf(
				0.18,
				0.42,
				_unit_value(
					geology_seed,
					MASSIF_LOBE_DISTANCE,
					cell
				)
			)
		)

		descriptor.massif_secondary_offset = Vector2(
			cos(lobe_angle),
			sin(lobe_angle)
		) * lobe_distance

	descriptor.depression_enabled = (
		_unit_value(
			geology_seed,
			DEPRESSION_ELIGIBILITY,
			cell
		)
		< settings.depression_probability
	)

	if descriptor.depression_enabled:
		var anchor_angle := (
			_unit_value(
				geology_seed,
				DEPRESSION_ANCHOR_ANGLE,
				cell
			)
			* TAU
		)

		var anchor_distance := lerpf(
			plate_cell_size * 0.08,
			plate_cell_size * 0.36,
			_unit_value(
				geology_seed,
				DEPRESSION_ANCHOR_DISTANCE,
				cell
			)
		)

		descriptor.depression_center = (
			plate_site.position
			+ Vector2(
				cos(anchor_angle),
				sin(anchor_angle)
			) * anchor_distance
		)

		var depression_radius := lerpf(
			settings.depression_min_radius,
			settings.depression_max_radius,
			_unit_value(
				geology_seed,
				DEPRESSION_RADIUS,
				cell
			)
		)

		var depression_aspect := lerpf(
			0.58,
			1.12,
			_unit_value(
				geology_seed,
				DEPRESSION_ASPECT,
				cell
			)
		)

		descriptor.depression_radii = Vector2(
			depression_radius,
			depression_radius * depression_aspect
		)

		descriptor.depression_angle = (
			_unit_value(
				geology_seed,
				DEPRESSION_ORIENTATION,
				cell
			)
			* TAU
		)

		descriptor.depression_depth = lerpf(
			settings.depression_min_depth,
			settings.depression_max_depth,
			_unit_value(
				geology_seed,
				DEPRESSION_DEPTH,
				cell
			)
		)

	return descriptor


## Returns:
##
## x = positive hill relief
## y = signed terrace relief
## z = positive massif relief
## w = negative interior-depression relief
static func sample(
	descriptor: PlateInteriorReliefDescriptor,
	world_xz: Vector2,
	interior_influence: float
) -> Vector4:
	if (
		descriptor == null
		or interior_influence <= 0.0
	):
		return Vector4(0.0, 0.0, 0.0, 0.0)

	var influence := clampf(
		interior_influence,
		0.0,
		1.0
	)

	var hill_relief: float = 0.0

	for index in range(
		descriptor.hill_centers.size()
	):
		var profile := _elliptical_profile(
			world_xz,
			descriptor.hill_centers[index],
			descriptor.hill_radii[index],
			descriptor.hill_angles[index],
			descriptor.hill_shape_powers[index]
		)

		hill_relief += (
			descriptor.hill_heights[index]
			* profile
		)

	hill_relief = minf(
		hill_relief,
		descriptor.hill_relief_cap
	)

	var terrace_relief: float = 0.0

	for index in range(
		descriptor.terrace_centers.size()
	):
		var local_point := _rotate_into_local(
			world_xz
				- descriptor.terrace_centers[index],
			descriptor.terrace_angles[index]
		)

		var half_length := (
			descriptor.terrace_half_lengths[index]
		)

		var half_width := (
			descriptor.terrace_half_widths[index]
		)

		var transition_width := (
			descriptor
			.terrace_transition_widths[index]
		)

		var along_profile := (
			1.0
			- _smoothstep(
				half_length * 0.72,
				half_length,
				absf(local_point.y)
			)
		)

		var rise_profile := _smoothstep(
			-half_width,
			-half_width + transition_width,
			local_point.x
		)

		var fall_profile := (
			1.0
			- _smoothstep(
				half_width * 0.10,
				half_width,
				local_point.x
			)
		)

		var tilted_profile := clampf(
			1.0
			+ descriptor.terrace_tilts[index]
			* (
				local_point.y
				/ maxf(
					half_length,
					PROFILE_EPSILON
				)
			),
			0.72,
			1.28
		)

		terrace_relief += (
			descriptor.terrace_relief[index]
			* rise_profile
			* fall_profile
			* along_profile
			* tilted_profile
		)

	var massif_relief: float = 0.0

	if descriptor.massif_enabled:
		var primary_profile := _elliptical_profile(
			world_xz,
			descriptor.massif_center,
			descriptor.massif_radii,
			descriptor.massif_angle,
			0.72
		)

		var secondary_profile := _elliptical_profile(
			world_xz,
			descriptor.massif_center
				+ descriptor.massif_secondary_offset,
			descriptor.massif_radii * 0.56,
			descriptor.massif_angle + 0.47,
			0.88
		)

		massif_relief = (
			descriptor.massif_height
			* minf(
				primary_profile * 0.76
				+ secondary_profile * 0.46,
				1.08
			)
		)

	var depression_relief: float = 0.0

	if descriptor.depression_enabled:
		var depression_profile := (
			_elliptical_profile(
				world_xz,
				descriptor.depression_center,
				descriptor.depression_radii,
				descriptor.depression_angle,
				0.82
			)
		)

		depression_relief = (
			-descriptor.depression_depth
			* depression_profile
		)

	return Vector4(
		hill_relief * influence,
		terrace_relief * influence,
		massif_relief * influence,
		depression_relief * influence
	)


static func _elliptical_profile(
	world_xz: Vector2,
	center: Vector2,
	radii: Vector2,
	angle: float,
	shape_power: float
) -> float:
	if (
		radii.x <= PROFILE_EPSILON
		or radii.y <= PROFILE_EPSILON
	):
		return 0.0

	var local_point := _rotate_into_local(
		world_xz - center,
		angle
	)

	var normalized_x := (
		local_point.x / radii.x
	)

	var normalized_y := (
		local_point.y / radii.y
	)

	var normalized_distance := sqrt(
		normalized_x * normalized_x
		+ normalized_y * normalized_y
	)

	if normalized_distance >= 1.0:
		return 0.0

	var remaining := (
		1.0 - normalized_distance
	)

	var smooth_profile := (
		remaining
		* remaining
		* (3.0 - 2.0 * remaining)
	)

	return pow(
		clampf(
			smooth_profile,
			0.0,
			1.0
		),
		maxf(
			shape_power,
			PROFILE_EPSILON
		)
	)


static func _rotate_into_local(
	value: Vector2,
	angle: float
) -> Vector2:
	var cosine := cos(angle)
	var sine := sin(angle)

	return Vector2(
		value.x * cosine
			+ value.y * sine,
		-value.x * sine
			+ value.y * cosine
	)


static func _unit_value(
	geology_seed: int,
	channel_id: int,
	coordinate: Vector2i
) -> float:
	return StableSeed.seed_to_unit_float(
		StableSeed.derive_spatial_seed(
			geology_seed,
			channel_id,
			coordinate
		)
	)


static func _signed_value(
	geology_seed: int,
	channel_id: int,
	coordinate: Vector2i
) -> float:
	return (
		_unit_value(
			geology_seed,
			channel_id,
			coordinate
		)
		* 2.0
		- 1.0
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
