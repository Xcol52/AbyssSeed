class_name EnvironmentSample
extends RefCounted

## Immutable by convention after construction.
## This class contains copied values only.

## Horizontal world position in meters.
var world_xz: Vector2

## Elevations and distances in meters.
var seabed_elevation: float
var depth_below_surface: float
var macro_elevation: float
var micro_elevation: float

## Local terrain shape.
var slope_degrees: float
var slope_strength: float
var roughness_meters: float
var roughness_strength: float

## Environmental conditions.
var light_availability: float
var temperature_celsius: float
var pressure_atmospheres: float
var nutrient_potential: float
var current_exposure: float
var geological_stability: float

## Geological evidence.
var volcanic_potential: float
var sediment_potential: float
var ridge_potential: float
var trench_potential: float
var trench_tier: int

var compression_strength: float
var extension_strength: float
var shear_strength: float

## Broad depth-province membership.
var shallow_province_influence: float
var deep_province_influence: float
var abyssal_province_influence: float
var province_transition_influence: float

## Normalized substrate weights. These sum to one.
var rock_substrate: float
var sand_substrate: float
var soft_sediment_substrate: float

## Combined photic and chemosynthetic productivity estimate.
var biological_potential: float


func _init(
	new_world_xz: Vector2,
	new_seabed_elevation: float,
	new_depth_below_surface: float,
	new_macro_elevation: float,
	new_micro_elevation: float,
	new_slope_degrees: float,
	new_slope_strength: float,
	new_roughness_meters: float,
	new_roughness_strength: float,
	new_light_availability: float,
	new_temperature_celsius: float,
	new_pressure_atmospheres: float,
	new_nutrient_potential: float,
	new_current_exposure: float,
	new_geological_stability: float,
	new_volcanic_potential: float,
	new_sediment_potential: float,
	new_ridge_potential: float,
	new_trench_potential: float,
	new_trench_tier: int,
	new_compression_strength: float,
	new_extension_strength: float,
	new_shear_strength: float,
	new_shallow_province_influence: float,
	new_deep_province_influence: float,
	new_abyssal_province_influence: float,
	new_province_transition_influence: float,
	new_rock_substrate: float,
	new_sand_substrate: float,
	new_soft_sediment_substrate: float,
	new_biological_potential: float
) -> void:
	world_xz = new_world_xz

	seabed_elevation = new_seabed_elevation
	depth_below_surface = new_depth_below_surface
	macro_elevation = new_macro_elevation
	micro_elevation = new_micro_elevation

	slope_degrees = new_slope_degrees
	slope_strength = new_slope_strength
	roughness_meters = new_roughness_meters
	roughness_strength = new_roughness_strength

	light_availability = new_light_availability
	temperature_celsius = new_temperature_celsius
	pressure_atmospheres = new_pressure_atmospheres
	nutrient_potential = new_nutrient_potential
	current_exposure = new_current_exposure
	geological_stability = new_geological_stability

	volcanic_potential = new_volcanic_potential
	sediment_potential = new_sediment_potential
	ridge_potential = new_ridge_potential
	trench_potential = new_trench_potential
	trench_tier = new_trench_tier

	compression_strength = new_compression_strength
	extension_strength = new_extension_strength
	shear_strength = new_shear_strength

	shallow_province_influence = (
		new_shallow_province_influence
	)

	deep_province_influence = (
		new_deep_province_influence
	)

	abyssal_province_influence = (
		new_abyssal_province_influence
	)

	province_transition_influence = (
		new_province_transition_influence
	)

	rock_substrate = new_rock_substrate
	sand_substrate = new_sand_substrate

	soft_sediment_substrate = (
		new_soft_sediment_substrate
	)

	biological_potential = new_biological_potential
