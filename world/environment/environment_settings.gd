class_name EnvironmentSettings
extends Resource

@export_category("Light")

## Exponential attenuation coefficient in inverse meters.
@export_range(0.0001, 0.1, 0.0001)
var light_attenuation: float = 0.012

@export_category("Temperature")

## Mean surface-water temperature in degrees Celsius.
@export_range(-10.0, 50.0, 0.1)
var surface_temperature_celsius: float = 18.0

## Regional temperature variation in degrees Celsius.
@export_range(0.0, 20.0, 0.1)
var regional_temperature_variation: float = 3.0

## Broad temperature-field frequency in inverse meters.
@export_range(0.000001, 0.01, 0.000001)
var regional_temperature_frequency: float = 0.000012

## Temperature decrease in degrees Celsius per meter.
@export_range(0.0, 0.05, 0.0001)
var depth_cooling_per_meter: float = 0.004

## Lower bound before geothermal heating is applied.
@export_range(-10.0, 20.0, 0.1)
var minimum_deep_temperature_celsius: float = 2.0

## Maximum geothermal increase from active geology.
@export_range(0.0, 30.0, 0.1)
var geothermal_temperature_increase: float = 5.0

@export_category("Currents")

@export_range(0.000001, 0.01, 0.000001)
var current_primary_frequency: float = 0.000030

@export_range(0.000001, 0.01, 0.000001)
var current_detail_frequency: float = 0.000150

@export_category("Nutrients")

@export_range(0.000001, 0.01, 0.000001)
var nutrient_variation_frequency: float = 0.000050

@export_category("Terrain Interpretation")

## Slope at which exposed-rock suitability reaches full strength.
@export_range(1.0, 89.0, 0.1)
var full_rock_slope_degrees: float = 35.0

## Roughness in meters that maps to normalized strength one.
@export_range(0.1, 1000.0, 0.1)
var full_roughness_meters: float = 30.0


func validate() -> PackedStringArray:
	var errors := PackedStringArray()

	if (
		not is_finite(light_attenuation)
		or light_attenuation <= 0.0
	):
		errors.append(
			"light_attenuation must be finite and positive."
		)

	if not is_finite(surface_temperature_celsius):
		errors.append(
			"surface_temperature_celsius must be finite."
		)

	if (
		not is_finite(regional_temperature_variation)
		or regional_temperature_variation < 0.0
	):
		errors.append(
			"regional_temperature_variation must be "
			+ "finite and non-negative."
		)

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
			errors.append(
				"All environment frequencies must be "
				+ "finite and positive."
			)
			break

	if (
		not is_finite(depth_cooling_per_meter)
		or depth_cooling_per_meter < 0.0
	):
		errors.append(
			"depth_cooling_per_meter must be finite "
			+ "and non-negative."
		)

	if not is_finite(
		minimum_deep_temperature_celsius
	):
		errors.append(
			"minimum_deep_temperature_celsius must be finite."
		)

	if (
		not is_finite(geothermal_temperature_increase)
		or geothermal_temperature_increase < 0.0
	):
		errors.append(
			"geothermal_temperature_increase must be "
			+ "finite and non-negative."
		)

	if (
		not is_finite(full_rock_slope_degrees)
		or full_rock_slope_degrees <= 0.0
		or full_rock_slope_degrees >= 90.0
	):
		errors.append(
			"full_rock_slope_degrees must be between "
			+ "zero and 90 degrees."
		)

	if (
		not is_finite(full_roughness_meters)
		or full_roughness_meters <= 0.0
	):
		errors.append(
			"full_roughness_meters must be finite "
			+ "and positive."
		)

	return errors
