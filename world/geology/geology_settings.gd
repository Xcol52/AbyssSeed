class_name GeologySettings
extends Resource


@export_category("Plate Topology")

@export_range(512.0, 100000.0, 1.0)
var plate_cell_size: float = 4096.0

@export_range(0.0, 0.8, 0.01)
var plate_site_jitter: float = 0.70

@export_range(0.0, 0.75, 0.01)
var plate_size_variation: float = 0.45

@export_range(16.0, 10000.0, 1.0)
var boundary_influence_width: float = 700.0


@export_category("Boundary Irregularity")

@export_range(0.0, 10000.0, 1.0)
var boundary_warp_amplitude: float = 600.0

@export_range(0.000001, 0.01, 0.000001)
var boundary_warp_frequency: float = 0.00018


@export_category("Regional Fields")

@export_range(0.000001, 0.01, 0.000001)
var continental_field_frequency: float = 0.00006

@export_range(0.000001, 0.01, 0.000001)
var basin_field_frequency: float = 0.00012

@export_range(0.0, 1000.0, 1.0)
var basin_relief_amplitude: float = 28.0

@export_range(0.000001, 0.01, 0.000001)
var regional_variation_frequency: float = 0.00035

@export_range(0.0, 0.75, 0.01)
var regional_variation_strength: float = 0.25


@export_category("Plate Motion")

@export_range(0.0, 10.0, 0.01)
var minimum_motion: float = 0.35

@export_range(0.01, 10.0, 0.01)
var maximum_motion: float = 1.0


@export_category("Macro Depth")

## The normal depth of strongly oceanic plate interiors.
@export_range(1.0, 10000.0, 1.0)
var oceanic_depth: float = 240.0

## The normal depth of strongly continental plate interiors.
@export_range(1.0, 10000.0, 1.0)
var continental_depth: float = 85.0

## The shallowest permitted seabed is two meters below sea level.
@export_range(0.5, 1000.0, 0.5)
var minimum_seabed_depth: float = 2.0

## Authoritative lower world envelope.
##
## Stage 3C records the new literal depth benchmark here. Existing
## Stage 3B trenches are not yet stretched to this depth because they
## still need boundary rarity and broad depth-province support.
@export_range(100.0, 10000.0, 1.0)
var maximum_seabed_depth: float = 6000.0

@export_category("Depth Provinces")

## Very broad fields select depth provinces. They do not directly
## generate small terrain noise.
@export_range(0.000001, 0.001, 0.000001)
var depth_province_primary_frequency: float = 0.000012

@export_range(0.000001, 0.001, 0.000001)
var depth_province_secondary_frequency: float = 0.000031

@export_range(0.000001, 0.001, 0.000001)
var depth_province_variation_frequency: float = 0.000020

@export_range(0.0, 1.0, 0.01)
var shelf_transition_start: float = 0.38

@export_range(0.0, 1.0, 0.01)
var shelf_transition_end: float = 0.50

@export_range(0.0, 1.0, 0.01)
var abyssal_transition_start: float = 0.56

@export_range(0.0, 1.0, 0.01)
var abyssal_transition_end: float = 0.68

@export_range(100.0, 6000.0, 1.0)
var deep_province_minimum_depth: float = 800.0

@export_range(100.0, 6000.0, 1.0)
var deep_province_maximum_depth: float = 1800.0

@export_range(100.0, 6000.0, 1.0)
var abyssal_province_minimum_depth: float = 2200.0

@export_range(100.0, 6000.0, 1.0)
var abyssal_province_maximum_depth: float = 3200.0

## This is a world-starting constraint, not a biome assignment.
@export_range(0.0, 100000.0, 100.0)
var starting_shelf_radius: float = 6000.0

@export_range(100.0, 100000.0, 100.0)
var starting_shelf_fade_width: float = 10000.0

@export_category("Divergent Relief")

@export_range(0.0, 2000.0, 1.0)
var ridge_uplift: float = 150.0

@export_range(16.0, 10000.0, 1.0)
var ridge_influence_width: float = 1100.0

@export_range(1.0, 5000.0, 1.0)
var rift_influence_width: float = 240.0

@export_range(0.0, 2000.0, 1.0)
var rift_depth: float = 60.0


@export_category("Plate Interior Relief")

## Interior formations fade near plate boundaries so independently
## generated plate descriptors cannot create direct discontinuities.
@export_range(16.0, 4000.0, 1.0)
var interior_boundary_fade_width: float = 260.0

@export_range(1, 8, 1)
var interior_hill_count: int = 5

@export_range(32.0, 4000.0, 1.0)
var hill_min_radius: float = 220.0

@export_range(32.0, 4000.0, 1.0)
var hill_max_radius: float = 720.0

@export_range(1.0, 1000.0, 1.0)
var hill_min_height: float = 14.0

@export_range(1.0, 1000.0, 1.0)
var hill_max_height: float = 68.0

@export_range(0, 4, 1)
var interior_terrace_count: int = 2

@export_range(32.0, 5000.0, 1.0)
var terrace_min_length: float = 600.0

@export_range(32.0, 5000.0, 1.0)
var terrace_max_length: float = 1700.0

@export_range(32.0, 2000.0, 1.0)
var terrace_min_width: float = 160.0

@export_range(32.0, 2000.0, 1.0)
var terrace_max_width: float = 420.0

@export_range(1.0, 500.0, 1.0)
var terrace_min_relief: float = 8.0

@export_range(1.0, 500.0, 1.0)
var terrace_max_relief: float = 38.0

@export_range(0.0, 1.0, 0.01)
var massif_probability: float = 0.45

@export_range(64.0, 5000.0, 1.0)
var massif_min_radius: float = 600.0

@export_range(64.0, 5000.0, 1.0)
var massif_max_radius: float = 1300.0

@export_range(1.0, 2000.0, 1.0)
var massif_min_height: float = 90.0

@export_range(1.0, 2000.0, 1.0)
var massif_max_height: float = 280.0

@export_range(0.0, 1.0, 0.01)
var interior_depression_probability: float = 0.55

@export_range(64.0, 5000.0, 1.0)
var depression_min_radius: float = 500.0

@export_range(64.0, 5000.0, 1.0)
var depression_max_radius: float = 1200.0

@export_range(1.0, 2000.0, 1.0)
var depression_min_depth: float = 35.0

@export_range(1.0, 2000.0, 1.0)
var depression_max_depth: float = 140.0


@export_category("Convergent Relief")

@export_range(64.0, 16000.0, 1.0)
var convergent_influence_width: float = 3000.0

@export_range(0.0, 2000.0, 1.0)
var convergent_depression_depth: float = 90.0

@export_range(32.0, 16000.0, 1.0)
var trench_descending_width: float = 1600.0

@export_range(32.0, 16000.0, 1.0)
var trench_overriding_width: float = 1000.0

@export_range(1.0, 8.0, 0.1)
var major_trench_width_multiplier: float = 2.0

@export_range(1.0, 8.0, 0.1)
var extreme_trench_width_multiplier: float = 4.5

@export_range(0.0, 0.75, 0.01)
var ordinary_trench_floor_fraction: float = 0.08

@export_range(0.0, 0.75, 0.01)
var major_trench_floor_fraction: float = 0.14

@export_range(0.0, 0.75, 0.01)
var extreme_trench_floor_fraction: float = 0.28

@export_range(100.0, 6000.0, 1.0)
var ordinary_trench_target_depth: float = 4000.0

@export_range(100.0, 6000.0, 1.0)
var major_trench_target_depth: float = 5000.0

@export_range(100.0, 6000.0, 1.0)
var extreme_trench_target_depth: float = 6000.0

@export_range(0.0, 1.0, 0.01)
var ordinary_trench_probability: float = 0.18

@export_range(0.0, 1.0, 0.01)
var major_trench_probability: float = 0.07

@export_range(0.0, 1.0, 0.01)
var extreme_trench_probability: float = 0.03

@export_range(0.000001, 0.01, 0.000001)
var trench_depth_variation_frequency: float = 0.000025

@export_range(0.0, 0.25, 0.01)
var trench_depth_variation_strength: float = 0.10

@export_range(64.0, 16000.0, 1.0)
var overriding_uplift_width: float = 3200.0

@export_range(1.0, 16000.0, 1.0)
var overriding_uplift_peak_offset: float = 1000.0

@export_range(0.0, 2000.0, 1.0)
var maximum_overriding_uplift: float = 420.0


@export_category("Legacy and Transform Relief")

## Retained for constructor and older-resource compatibility.
## Stage 3B uses total trench target depths for the axial trench.
@export_range(0.0, 2000.0, 1.0)
var trench_depth: float = 130.0

## Retained as the low end of convergent uplift calculations.
@export_range(0.0, 2000.0, 1.0)
var continental_collision_uplift: float = 45.0

@export_range(0.0, 1000.0, 1.0)
var shear_relief: float = 12.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if (
		not is_finite(plate_cell_size)
		or plate_cell_size <= 0.0
	):
		errors.append(
			"plate_cell_size must be finite and greater than zero."
		)

	if (
		not is_finite(plate_site_jitter)
		or plate_site_jitter < 0.0
		or plate_site_jitter > 0.8
	):
		errors.append(
			"plate_site_jitter must be between 0 and 0.8."
		)

	if (
		not is_finite(plate_size_variation)
		or plate_size_variation < 0.0
		or plate_size_variation > 0.75
	):
		errors.append(
			"plate_size_variation must be between 0 and 0.75."
		)

	if (
		not is_finite(boundary_influence_width)
		or boundary_influence_width <= 0.0
		or boundary_influence_width >= plate_cell_size
	):
		errors.append(
			"boundary_influence_width must be positive "
			+ "and less than plate_cell_size."
		)

	if (
		not is_finite(boundary_warp_amplitude)
		or boundary_warp_amplitude < 0.0
	):
		errors.append(
			"boundary_warp_amplitude must be finite and non-negative."
		)

	var positive_frequencies: Array[float] = [
		boundary_warp_frequency,
		continental_field_frequency,
		basin_field_frequency,
		regional_variation_frequency,
		trench_depth_variation_frequency
	]

	for frequency in positive_frequencies:
		if (
			not is_finite(frequency)
			or frequency <= 0.0
		):
			errors.append(
				"All geology frequencies must be finite and positive."
			)
			break

	if (
		not is_finite(regional_variation_strength)
		or regional_variation_strength < 0.0
		or regional_variation_strength > 0.75
	):
		errors.append(
			"regional_variation_strength must be between 0 and 0.75."
		)

	if (
		not is_finite(minimum_motion)
		or minimum_motion < 0.0
	):
		errors.append(
			"minimum_motion must be finite and non-negative."
		)

	if (
		not is_finite(maximum_motion)
		or maximum_motion <= minimum_motion
	):
		errors.append(
			"maximum_motion must be finite and greater "
			+ "than minimum_motion."
		)

	if (
		not is_finite(oceanic_depth)
		or not is_finite(continental_depth)
		or oceanic_depth <= continental_depth
	):
		errors.append(
			"oceanic_depth must be greater than continental_depth."
		)

	if (
		not is_finite(minimum_seabed_depth)
		or minimum_seabed_depth <= 0.0
		or minimum_seabed_depth > continental_depth
	):
		errors.append(
			"minimum_seabed_depth must be positive and no greater "
			+ "than continental_depth."
		)

	if (
		not is_finite(maximum_seabed_depth)
		or maximum_seabed_depth <= oceanic_depth
		or maximum_seabed_depth <= minimum_seabed_depth
	):
		errors.append(
			"maximum_seabed_depth must be greater than the normal "
			+ "oceanic depth and minimum_seabed_depth."
		)

	if (
		not is_finite(ridge_influence_width)
		or ridge_influence_width <= 0.0
		or ridge_influence_width >= plate_cell_size
	):
		errors.append(
			"ridge_influence_width must be positive "
			+ "and less than plate_cell_size."
		)

	if (
		not is_finite(rift_influence_width)
		or rift_influence_width <= 0.0
		or rift_influence_width >= ridge_influence_width
	):
		errors.append(
			"rift_influence_width must be positive "
			+ "and less than ridge_influence_width."
		)

	var non_negative_values: Array[float] = [
		basin_relief_amplitude,
		ridge_uplift,
		rift_depth,
		trench_depth,
		continental_collision_uplift,
		shear_relief
	]

	for value in non_negative_values:
		if (
			not is_finite(value)
			or value < 0.0
		):
			errors.append(
				"Geological relief values must be finite "
				+ "and non-negative."
			)
			break

	var interior_snapshot := (
		PlateInteriorReliefSnapshot.from_settings(self)
	)

	var interior_errors := interior_snapshot.validate(
		plate_cell_size
	)

	for message in interior_errors:
		errors.append(message)

	var convergent_snapshot := (
		ConvergentReliefSnapshot.from_settings(self)
	)

	var convergent_errors := convergent_snapshot.validate(
		plate_cell_size,
		maximum_seabed_depth
	)

	for message in convergent_errors:
		errors.append(message)

	return errors
