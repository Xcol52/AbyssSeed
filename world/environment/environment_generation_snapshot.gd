class_name EnvironmentGenerationSnapshot
extends RefCounted

## Immutable by convention after construction.
## Contains no Resource or Node references.

var environment_seed: int
var ocean_height: float

var light_attenuation: float

var surface_temperature_celsius: float
var regional_temperature_variation: float
var regional_temperature_frequency: float
var depth_cooling_per_meter: float
var minimum_deep_temperature_celsius: float
var geothermal_temperature_increase: float

var current_primary_frequency: float
var current_detail_frequency: float
var nutrient_variation_frequency: float

var full_rock_slope_degrees: float
var full_roughness_meters: float


func _init(
	new_environment_seed: int,
	new_ocean_height: float,
	new_light_attenuation: float,
	new_surface_temperature_celsius: float,
	new_regional_temperature_variation: float,
	new_regional_temperature_frequency: float,
	new_depth_cooling_per_meter: float,
	new_minimum_deep_temperature_celsius: float,
	new_geothermal_temperature_increase: float,
	new_current_primary_frequency: float,
	new_current_detail_frequency: float,
	new_nutrient_variation_frequency: float,
	new_full_rock_slope_degrees: float,
	new_full_roughness_meters: float
) -> void:
	environment_seed = new_environment_seed
	ocean_height = new_ocean_height

	light_attenuation = new_light_attenuation

	surface_temperature_celsius = (
		new_surface_temperature_celsius
	)

	regional_temperature_variation = (
		new_regional_temperature_variation
	)

	regional_temperature_frequency = (
		new_regional_temperature_frequency
	)

	depth_cooling_per_meter = (
		new_depth_cooling_per_meter
	)

	minimum_deep_temperature_celsius = (
		new_minimum_deep_temperature_celsius
	)

	geothermal_temperature_increase = (
		new_geothermal_temperature_increase
	)

	current_primary_frequency = (
		new_current_primary_frequency
	)

	current_detail_frequency = (
		new_current_detail_frequency
	)

	nutrient_variation_frequency = (
		new_nutrient_variation_frequency
	)

	full_rock_slope_degrees = (
		new_full_rock_slope_degrees
	)

	full_roughness_meters = (
		new_full_roughness_meters
	)


static func from_settings(
	new_environment_seed: int,
	ocean_settings: OceanSettings,
	environment_settings: EnvironmentSettings
) -> EnvironmentGenerationSnapshot:
	assert(ocean_settings != null)
	assert(environment_settings != null)

	return EnvironmentGenerationSnapshot.new(
		new_environment_seed,
		ocean_settings.ocean_height,
		environment_settings.light_attenuation,
		environment_settings.surface_temperature_celsius,
		environment_settings.regional_temperature_variation,
		environment_settings.regional_temperature_frequency,
		environment_settings.depth_cooling_per_meter,
		environment_settings
			.minimum_deep_temperature_celsius,
		environment_settings
			.geothermal_temperature_increase,
		environment_settings.current_primary_frequency,
		environment_settings.current_detail_frequency,
		environment_settings.nutrient_variation_frequency,
		environment_settings.full_rock_slope_degrees,
		environment_settings.full_roughness_meters
	)


func get_validation_error() -> String:
	if not is_finite(ocean_height):
		return "Invalid environment ocean_height."

	if (
		not is_finite(light_attenuation)
		or light_attenuation <= 0.0
	):
		return "Invalid environment light_attenuation."

	if not is_finite(surface_temperature_celsius):
		return "Invalid environment surface temperature."

	if (
		not is_finite(regional_temperature_variation)
		or regional_temperature_variation < 0.0
	):
		return "Invalid regional temperature variation."

	var frequencies: Array[float] = [
		regional_temperature_frequency,
		current_primary_frequency,
		current_detail_frequency,
		nutrient_variation_frequency
	]

	for frequency in frequencies:
		if (
			not is_finite(frequency)
			or frequency <= 0.0
		):
			return "Invalid environment frequency."

	if (
		not is_finite(depth_cooling_per_meter)
		or depth_cooling_per_meter < 0.0
	):
		return "Invalid environment depth cooling."

	if not is_finite(
		minimum_deep_temperature_celsius
	):
		return "Invalid minimum deep temperature."

	if (
		not is_finite(geothermal_temperature_increase)
		or geothermal_temperature_increase < 0.0
	):
		return "Invalid geothermal temperature increase."

	if (
		not is_finite(full_rock_slope_degrees)
		or full_rock_slope_degrees <= 0.0
		or full_rock_slope_degrees >= 90.0
	):
		return "Invalid full rock slope."

	if (
		not is_finite(full_roughness_meters)
		or full_roughness_meters <= 0.0
	):
		return "Invalid full roughness."

	return ""
