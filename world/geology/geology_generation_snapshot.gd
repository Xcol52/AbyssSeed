class_name GeologyGenerationSnapshot
extends RefCounted

## Immutable by convention after construction.
## This object contains no Node or Resource references.

var geology_seed: int

var plate_cell_size: float
var plate_site_jitter: float
var plate_size_variation: float
var boundary_influence_width: float

var boundary_warp_amplitude: float
var boundary_warp_frequency: float

var continental_field_frequency: float
var basin_field_frequency: float
var basin_relief_amplitude: float
var regional_variation_frequency: float
var regional_variation_strength: float

var minimum_motion: float
var maximum_motion: float

var oceanic_depth: float
var continental_depth: float
var minimum_seabed_depth: float
var maximum_seabed_depth: float

var ridge_uplift: float
var ridge_influence_width: float
var rift_influence_width: float
var rift_depth: float

var trench_depth: float
var continental_collision_uplift: float
var shear_relief: float

var interior_relief: PlateInteriorReliefSnapshot
var convergent_relief: ConvergentReliefSnapshot
var depth_provinces: DepthProvinceSnapshot


func _init(
	new_geology_seed: int,
	new_plate_cell_size: float,
	new_plate_site_jitter: float,
	new_plate_size_variation: float,
	new_boundary_influence_width: float,
	new_boundary_warp_amplitude: float,
	new_boundary_warp_frequency: float,
	new_continental_field_frequency: float,
	new_basin_field_frequency: float,
	new_basin_relief_amplitude: float,
	new_regional_variation_frequency: float,
	new_regional_variation_strength: float,
	new_minimum_motion: float,
	new_maximum_motion: float,
	new_oceanic_depth: float,
	new_continental_depth: float,
	new_minimum_seabed_depth: float,
	new_ridge_uplift: float,
	new_trench_depth: float,
	new_continental_collision_uplift: float,
	new_shear_relief: float,
	new_ridge_influence_width: float = 1100.0,
	new_rift_influence_width: float = 240.0,
	new_rift_depth: float = 60.0,
	new_interior_relief: PlateInteriorReliefSnapshot = null,
	new_maximum_seabed_depth: float = 6000.0,
	new_convergent_relief: ConvergentReliefSnapshot = null,
	new_depth_provinces: DepthProvinceSnapshot = null
) -> void:
	geology_seed = new_geology_seed

	plate_cell_size = new_plate_cell_size
	plate_site_jitter = new_plate_site_jitter
	plate_size_variation = new_plate_size_variation
	boundary_influence_width = new_boundary_influence_width

	boundary_warp_amplitude = new_boundary_warp_amplitude
	boundary_warp_frequency = new_boundary_warp_frequency

	continental_field_frequency = (
		new_continental_field_frequency
	)

	basin_field_frequency = new_basin_field_frequency
	basin_relief_amplitude = new_basin_relief_amplitude

	regional_variation_frequency = (
		new_regional_variation_frequency
	)

	regional_variation_strength = (
		new_regional_variation_strength
	)

	minimum_motion = new_minimum_motion
	maximum_motion = new_maximum_motion

	oceanic_depth = new_oceanic_depth
	continental_depth = new_continental_depth
	minimum_seabed_depth = new_minimum_seabed_depth
	maximum_seabed_depth = new_maximum_seabed_depth

	ridge_uplift = new_ridge_uplift
	ridge_influence_width = new_ridge_influence_width
	rift_influence_width = new_rift_influence_width
	rift_depth = new_rift_depth

	trench_depth = new_trench_depth

	continental_collision_uplift = (
		new_continental_collision_uplift
	)

	shear_relief = new_shear_relief

	if new_interior_relief == null:
		interior_relief = PlateInteriorReliefSnapshot.new()
	else:
		interior_relief = new_interior_relief

	if new_convergent_relief == null:
		convergent_relief = ConvergentReliefSnapshot.new()
	else:
		convergent_relief = new_convergent_relief

	if new_depth_provinces == null:
		depth_provinces = DepthProvinceSnapshot.new()
	else:
		depth_provinces = new_depth_provinces


static func from_settings(
	geology_subsystem_seed: int,
	settings: GeologySettings
) -> GeologyGenerationSnapshot:
	assert(settings != null)

	return GeologyGenerationSnapshot.new(
		geology_subsystem_seed,
		settings.plate_cell_size,
		settings.plate_site_jitter,
		settings.plate_size_variation,
		settings.boundary_influence_width,
		settings.boundary_warp_amplitude,
		settings.boundary_warp_frequency,
		settings.continental_field_frequency,
		settings.basin_field_frequency,
		settings.basin_relief_amplitude,
		settings.regional_variation_frequency,
		settings.regional_variation_strength,
		settings.minimum_motion,
		settings.maximum_motion,
		settings.oceanic_depth,
		settings.continental_depth,
		settings.minimum_seabed_depth,
		settings.ridge_uplift,
		settings.trench_depth,
		settings.continental_collision_uplift,
		settings.shear_relief,
		settings.ridge_influence_width,
		settings.rift_influence_width,
		settings.rift_depth,
		PlateInteriorReliefSnapshot.from_settings(
			settings
		),
		settings.maximum_seabed_depth,
		ConvergentReliefSnapshot.from_settings(
			settings
		),
		DepthProvinceSnapshot.from_settings(
			settings
		)
	)


func get_validation_error() -> String:
	if (
		not is_finite(plate_cell_size)
		or plate_cell_size <= 0.0
	):
		return "Invalid geology plate_cell_size."

	if (
		not is_finite(plate_site_jitter)
		or plate_site_jitter < 0.0
		or plate_site_jitter > 0.8
	):
		return "Invalid geology plate_site_jitter."

	if (
		not is_finite(plate_size_variation)
		or plate_size_variation < 0.0
		or plate_size_variation > 0.75
	):
		return "Invalid geology plate_size_variation."

	if (
		not is_finite(boundary_influence_width)
		or boundary_influence_width <= 0.0
		or boundary_influence_width >= plate_cell_size
	):
		return "Invalid geology boundary_influence_width."

	if (
		not is_finite(ridge_influence_width)
		or ridge_influence_width <= 0.0
		or ridge_influence_width >= plate_cell_size
	):
		return "Invalid geology ridge_influence_width."

	if (
		not is_finite(rift_influence_width)
		or rift_influence_width <= 0.0
		or rift_influence_width >= ridge_influence_width
	):
		return "Invalid geology rift_influence_width."

	if (
		not is_finite(boundary_warp_amplitude)
		or boundary_warp_amplitude < 0.0
	):
		return "Invalid geology boundary_warp_amplitude."

	var positive_frequencies: Array[float] = [
		boundary_warp_frequency,
		continental_field_frequency,
		basin_field_frequency,
		regional_variation_frequency
	]

	for frequency in positive_frequencies:
		if (
			not is_finite(frequency)
			or frequency <= 0.0
		):
			return "Invalid geology frequency."

	if (
		not is_finite(regional_variation_strength)
		or regional_variation_strength < 0.0
		or regional_variation_strength > 0.75
	):
		return "Invalid geology regional_variation_strength."

	if (
		not is_finite(minimum_motion)
		or minimum_motion < 0.0
	):
		return "Invalid geology minimum_motion."

	if (
		not is_finite(maximum_motion)
		or maximum_motion <= minimum_motion
	):
		return "Invalid geology maximum_motion."

	if (
		not is_finite(oceanic_depth)
		or not is_finite(continental_depth)
		or oceanic_depth <= continental_depth
	):
		return "Invalid geology depth relationship."

	if (
		not is_finite(minimum_seabed_depth)
		or minimum_seabed_depth <= 0.0
		or minimum_seabed_depth > continental_depth
	):
		return "Invalid geology minimum_seabed_depth."

	if (
		not is_finite(maximum_seabed_depth)
		or maximum_seabed_depth <= oceanic_depth
		or maximum_seabed_depth <= minimum_seabed_depth
	):
		return "Invalid geology maximum_seabed_depth."

	var relief_values: Array[float] = [
		basin_relief_amplitude,
		ridge_uplift,
		rift_depth,
		trench_depth,
		continental_collision_uplift,
		shear_relief
	]

	for value in relief_values:
		if (
			not is_finite(value)
			or value < 0.0
		):
			return "Invalid geology relief value."

	if interior_relief == null:
		return "Missing plate-interior relief snapshot."

	var interior_errors := interior_relief.validate(
		plate_cell_size
	)

	if not interior_errors.is_empty():
		return interior_errors[0]

	if convergent_relief == null:
		return "Missing convergent relief snapshot."

	var convergent_errors := convergent_relief.validate(
		plate_cell_size,
		maximum_seabed_depth
	)

	if not convergent_errors.is_empty():
		return convergent_errors[0]

	if depth_provinces == null:
		return "Missing depth-province snapshot."

	var depth_province_errors := (
		depth_provinces.validate(
			maximum_seabed_depth
		)
	)

	if not depth_province_errors.is_empty():
		return depth_province_errors[0]

	return ""
