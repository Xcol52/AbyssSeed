extends Control

enum Mode {
	DEPTH = 0,
	LIGHT = 1,
	TEMPERATURE = 2,
	PRESSURE = 3,
	NUTRIENTS = 4,
	CURRENT_EXPOSURE = 5,
	GEOLOGICAL_STABILITY = 6,
	SLOPE = 7,
	ROUGHNESS = 8,
	ROCK_SUBSTRATE = 9,
	SAND_SUBSTRATE = 10,
	SOFT_SEDIMENT_SUBSTRATE = 11,
	BIOLOGICAL_POTENTIAL = 12,
	COUNT = 13,
}

const MINIMUM_MAP_SPAN: float = 1024.0
const MAXIMUM_MAP_SPAN: float = 262144.0

const NORMAL_PAN_FRACTION: float = 0.50
const FAST_PAN_FRACTION: float = 1.50
const ZOOM_FACTOR: float = 2.0

const PRESSURE_DEPTH_METERS: float = 10.06
const VALUE_EPSILON: float = 0.000001

const BACKGROUND_COLOR: Color = Color(
	0.008,
	0.012,
	0.020,
	1.0
)

@export var geology_settings: GeologySettings
@export var terrain_settings: TerrainSettings
@export var environment_settings: EnvironmentSettings

## Optional. If this is not assigned, fallback_ocean_height is used.
@export var ocean_settings: OceanSettings

@export var fallback_ocean_height: float = 0.0

@export var world_seed: int = 1337
@export var generation_version: int = 9

@export var map_center: Vector2 = Vector2.ZERO

@export_range(1024.0, 262144.0, 1024.0)
var map_span: float = 32768.0

@export_range(33, 513, 1)
var map_resolution: int = 129

var _mode: int = Mode.DEPTH

var _terrain_data: TerrainChunkData
var _samples: Array[EnvironmentSample] = []

var _minimum_values := PackedFloat32Array()
var _maximum_values := PackedFloat32Array()

var _valid_sample_count: int = 0
var _invalid_sample_count: int = 0
var _selected_sample_index: int = -1

@onready var _mode_label: Label = %ModeLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _map_texture: TextureRect = %MapTexture
@onready var _inspection_label: Label = %InspectionLabel
@onready var _help_label: Label = %HelpLabel


func _ready() -> void:
	if not _validate_settings():
		return

	_help_label.text = (
		"WASD: pan | Shift+WASD: fast pan | "
		+ "Q/E or wheel: zoom | Home: origin | "
		+ "Left/Right/Tab: mode | R: regenerate | "
		+ "Left click: inspect"
	)

	_generate_map()


func _validate_settings() -> bool:
	if geology_settings == null:
		push_error(
			"EnvironmentDebugMap requires GeologySettings."
		)
		return false

	if terrain_settings == null:
		push_error(
			"EnvironmentDebugMap requires TerrainSettings."
		)
		return false

	if environment_settings == null:
		push_error(
			"EnvironmentDebugMap requires EnvironmentSettings."
		)
		return false

	var geology_errors := geology_settings.validate()

	if not geology_errors.is_empty():
		for message in geology_errors:
			push_error(
				"Invalid debug geology settings: %s"
				% message
			)
		return false

	var terrain_errors := terrain_settings.validate()

	if not terrain_errors.is_empty():
		for message in terrain_errors:
			push_error(
				"Invalid debug terrain settings: %s"
				% message
			)
		return false

	var environment_errors := (
		environment_settings.validate()
	)

	if not environment_errors.is_empty():
		for message in environment_errors:
			push_error(
				"Invalid debug environment settings: %s"
				% message
			)
		return false

	if ocean_settings != null:
		var ocean_errors := ocean_settings.validate()

		if not ocean_errors.is_empty():
			for message in ocean_errors:
				push_error(
					"Invalid debug ocean settings: %s"
						% message
				)
			return false

	if not is_finite(fallback_ocean_height):
		push_error(
			"fallback_ocean_height must be finite."
		)
		return false

	if map_resolution < 2:
		push_error(
			"map_resolution must be at least 2."
		)
		return false

	return true


func _input(
	input_event: InputEvent
) -> void:
	if input_event is InputEventMouseButton:
		var mouse_event := (
			input_event as InputEventMouseButton
		)

		if not mouse_event.pressed:
			return

		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_map(true)
				get_viewport().set_input_as_handled()
				return

			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_map(false)
				get_viewport().set_input_as_handled()
				return

			MOUSE_BUTTON_LEFT:
				if _inspect_at_viewport_position(
					mouse_event.position
				):
					get_viewport().set_input_as_handled()
				return

	if input_event is not InputEventKey:
		return

	var key_event := input_event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	var pan_direction := Vector2.ZERO

	match key_event.keycode:
		KEY_W:
			pan_direction = Vector2(0.0, -1.0)

		KEY_S:
			pan_direction = Vector2(0.0, 1.0)

		KEY_A:
			pan_direction = Vector2(-1.0, 0.0)

		KEY_D:
			pan_direction = Vector2(1.0, 0.0)

	if pan_direction != Vector2.ZERO:
		_pan_map(
			pan_direction,
			key_event.shift_pressed
		)

		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_RIGHT:
		_cycle_mode(1)
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_LEFT:
		_cycle_mode(-1)
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_TAB:
		var direction := 1

		if key_event.shift_pressed:
			direction = -1

		_cycle_mode(direction)
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_Q:
		_zoom_map(true)
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_E:
		_zoom_map(false)
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_HOME:
		map_center = Vector2.ZERO
		_generate_map()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_R:
		_generate_map()
		get_viewport().set_input_as_handled()


func _cycle_mode(
	direction: int
) -> void:
	_mode += direction

	while _mode >= Mode.COUNT:
		_mode -= Mode.COUNT

	while _mode < 0:
		_mode += Mode.COUNT

	_render_current_mode()


func _pan_map(
	direction: Vector2,
	fast: bool
) -> void:
	var pan_fraction := NORMAL_PAN_FRACTION

	if fast:
		pan_fraction = FAST_PAN_FRACTION

	map_center += (
		direction.normalized()
		* map_span
		* pan_fraction
	)

	_generate_map()


func _zoom_map(
	zoom_in: bool
) -> void:
	var new_span := map_span

	if zoom_in:
		new_span /= ZOOM_FACTOR
	else:
		new_span *= ZOOM_FACTOR

	new_span = clampf(
		new_span,
		MINIMUM_MAP_SPAN,
		MAXIMUM_MAP_SPAN
	)

	if is_equal_approx(new_span, map_span):
		return

	map_span = new_span
	_generate_map()


func _generate_map() -> void:
	_mode_label.text = (
		"Generating environmental samples..."
	)

	_stats_label.text = ""
	_inspection_label.text = (
		"Left click the map to inspect a sample."
	)

	_selected_sample_index = -1
	_samples.clear()
	_terrain_data = null

	var geology_seed := (
		StableSeed.derive_subsystem_seed(
			world_seed,
			generation_version,
			WorldSubsystemIds.GEOLOGY
		)
	)

	var terrain_seed := (
		StableSeed.derive_subsystem_seed(
			world_seed,
			generation_version,
			WorldSubsystemIds.TERRAIN
		)
	)

	var environment_seed := (
		StableSeed.derive_subsystem_seed(
			world_seed,
			generation_version,
			WorldSubsystemIds.ENVIRONMENT
		)
	)

	var geology_snapshot := (
		GeologyGenerationSnapshot.from_settings(
			geology_seed,
			geology_settings
		)
	)

	var geology_error := (
		geology_snapshot.get_validation_error()
	)

	if not geology_error.is_empty():
		push_error(
			"Invalid debug geology snapshot: %s"
				% geology_error
		)

		_mode_label.text = (
			"Invalid geology snapshot."
		)
		return

	## Each rendered pixel represents one generated terrain cell.
	## Terrain data therefore contains map_resolution + 1 vertices.
	var cells_per_axis := map_resolution

	var cell_size := (
		map_span
		/ float(cells_per_axis)
	)

	var world_origin := (
		map_center
		- Vector2.ONE
		* map_span
		* 0.5
	)

	var terrain_snapshot := TerrainGenerationSnapshot.new(
		1,
		1,
		Vector2i.ZERO,
		generation_version,
		terrain_seed,
		map_span,
		cells_per_axis,
		terrain_settings.base_seabed_depth,
		terrain_settings.test_elevation_amplitude,
		terrain_settings.test_noise_frequency,
		0,
		geology_snapshot
	)

	var terrain_error := (
		terrain_snapshot.get_validation_error()
	)

	if not terrain_error.is_empty():
		push_error(
			"Invalid debug terrain snapshot: %s"
				% terrain_error
		)

		_mode_label.text = (
			"Invalid terrain snapshot."
		)
		return

	_terrain_data = (
		TerrainSampler.generate_region_from_snapshot(
			terrain_snapshot,
			world_origin,
			cells_per_axis,
			cell_size
		)
	)

	if _terrain_data == null:
		push_error(
			"Environmental debug terrain generation failed."
		)

		_mode_label.text = (
			"Terrain generation failed."
		)
		return

	var ocean_height := fallback_ocean_height

	if ocean_settings != null:
		ocean_height = ocean_settings.ocean_height

	var environment_snapshot := (
		_create_environment_snapshot(
			environment_seed,
			ocean_height
		)
	)

	var environment_error := (
		environment_snapshot.get_validation_error()
	)

	if not environment_error.is_empty():
		push_error(
			"Invalid environment snapshot: %s"
				% environment_error
		)

		_mode_label.text = (
			"Invalid environment snapshot."
		)
		return

	var environment_sampler := EnvironmentSampler.new(
		environment_snapshot
	)

	_samples.resize(
		map_resolution
		* map_resolution
	)

	for pixel_z in range(map_resolution):
		for pixel_x in range(map_resolution):
			var index := (
				pixel_z * map_resolution
				+ pixel_x
			)

			var world_xz := (
				world_origin
				+ Vector2(
					(
						float(pixel_x)
						+ 0.5
					) * cell_size,
					(
						float(pixel_z)
						+ 0.5
					) * cell_size
				)
			)

			_samples[index] = (
				environment_sampler.sample_world(
					_terrain_data,
					world_xz
				)
			)

	_analyze_samples()
	_render_current_mode()


func _create_environment_snapshot(
	environment_seed: int,
	ocean_height: float
) -> EnvironmentGenerationSnapshot:
	return EnvironmentGenerationSnapshot.new(
		environment_seed,
		ocean_height,
		environment_settings.light_attenuation,
		environment_settings
			.surface_temperature_celsius,
		environment_settings
			.regional_temperature_variation,
		environment_settings
			.regional_temperature_frequency,
		environment_settings.depth_cooling_per_meter,
		environment_settings
			.minimum_deep_temperature_celsius,
		environment_settings
			.geothermal_temperature_increase,
		environment_settings.current_primary_frequency,
		environment_settings.current_detail_frequency,
		environment_settings
			.nutrient_variation_frequency,
		environment_settings.full_rock_slope_degrees,
		environment_settings.full_roughness_meters
	)


func _analyze_samples() -> void:
	_minimum_values.resize(Mode.COUNT)
	_maximum_values.resize(Mode.COUNT)

	for mode in range(Mode.COUNT):
		_minimum_values[mode] = INF
		_maximum_values[mode] = -INF

	_valid_sample_count = 0
	_invalid_sample_count = 0

	for sample in _samples:
		if sample == null:
			_invalid_sample_count += 1
			continue

		_valid_sample_count += 1

		for mode in range(Mode.COUNT):
			var value := _get_sample_value(
				sample,
				mode
			)

			_minimum_values[mode] = minf(
				_minimum_values[mode],
				value
			)

			_maximum_values[mode] = maxf(
				_maximum_values[mode],
				value
			)


func _render_current_mode() -> void:
	if _samples.is_empty():
		return

	var image := Image.create(
		map_resolution,
		map_resolution,
		false,
		Image.FORMAT_RGBA8
	)

	for pixel_z in range(map_resolution):
		for pixel_x in range(map_resolution):
			var index := (
				pixel_z * map_resolution
				+ pixel_x
			)

			var sample := _samples[index]
			var color := Color.MAGENTA

			if sample != null:
				color = _get_color_for_sample(
					sample,
					_mode
				)

			if index == _selected_sample_index:
				color = color.lerp(
					Color.WHITE,
					0.75
				)

			image.set_pixel(
				pixel_x,
				pixel_z,
				color
			)

	_map_texture.texture = (
		ImageTexture.create_from_image(
			image
		)
	)

	_update_labels()


func _update_labels() -> void:
	var observed_minimum := (
		_minimum_values[_mode]
	)

	var observed_maximum := (
		_maximum_values[_mode]
	)

	var unit := _get_mode_unit(_mode)

	_mode_label.text = (
		"%s | display %s | observed %.3f%s to %.3f%s"
		% [
			_get_mode_name(_mode),
			_get_display_scale_description(_mode),
			observed_minimum,
			unit,
			observed_maximum,
			unit
		]
	)

	var cell_size := (
		map_span
		/ float(map_resolution)
	)

	_stats_label.text = (
		"Seed %d | generation v%d | center %s | "
		+ "span %.0f m | diagnostic spacing %.2f m | "
		+ "resolution %d × %d | valid %d | unavailable %d"
	) % [
		world_seed,
		generation_version,
		_format_world_position(map_center),
		map_span,
		cell_size,
		map_resolution,
		map_resolution,
		_valid_sample_count,
		_invalid_sample_count
	]


func _inspect_at_viewport_position(
	viewport_position: Vector2
) -> bool:
	if _samples.is_empty():
		return false

	var map_rect := _map_texture.get_global_rect()

	if not map_rect.has_point(viewport_position):
		return false

	## The TextureRect uses keep-aspect-centered rendering.
	var square_extent := minf(
		map_rect.size.x,
		map_rect.size.y
	)

	if square_extent <= VALUE_EPSILON:
		return false

	var drawing_origin := (
		map_rect.position
		+ (
			map_rect.size
			- Vector2.ONE * square_extent
		) * 0.5
	)

	var image_position := (
		viewport_position
		- drawing_origin
	)

	if (
		image_position.x < 0.0
		or image_position.y < 0.0
		or image_position.x >= square_extent
		or image_position.y >= square_extent
	):
		return false

	var pixel_x := clampi(
		floori(
			image_position.x
			/ square_extent
			* float(map_resolution)
		),
		0,
		map_resolution - 1
	)

	var pixel_z := clampi(
		floori(
			image_position.y
			/ square_extent
			* float(map_resolution)
		),
		0,
		map_resolution - 1
	)

	var index := (
		pixel_z * map_resolution
		+ pixel_x
	)

	var sample := _samples[index]

	if sample == null:
		_inspection_label.text = (
			"Selected sample is unavailable."
		)
		return true

	_selected_sample_index = index
	_update_inspection_label(sample)
	_render_current_mode()

	return true


func _update_inspection_label(
	sample: EnvironmentSample
) -> void:
	_inspection_label.text = (
		"Selected %s\n"
		+ "Elevation %.2f m | depth %.2f m | "
		+ "macro %.2f m | micro %+.2f m\n"
		+ "Slope %.2f° | roughness %.2f m | "
		+ "light %.4f | temperature %.2f °C | "
		+ "pressure %.2f atm\n"
		+ "Nutrients %.3f | current %.3f | "
		+ "stability %.3f | biological %.3f\n"
		+ "Substrate: rock %.3f | sand %.3f | "
		+ "soft sediment %.3f\n"
		+ "Geology: ridge %.3f | trench %.3f | "
		+ "trench tier %d | volcanic %.3f | "
		+ "sediment %.3f\n"
		+ "Depth provinces: shallow %.3f | "
		+ "deep %.3f | abyssal %.3f | transition %.3f"
	) % [
		_format_world_position(sample.world_xz),
		sample.seabed_elevation,
		sample.depth_below_surface,
		sample.macro_elevation,
		sample.micro_elevation,
		sample.slope_degrees,
		sample.roughness_meters,
		sample.light_availability,
		sample.temperature_celsius,
		sample.pressure_atmospheres,
		sample.nutrient_potential,
		sample.current_exposure,
		sample.geological_stability,
		sample.biological_potential,
		sample.rock_substrate,
		sample.sand_substrate,
		sample.soft_sediment_substrate,
		sample.ridge_potential,
		sample.trench_potential,
		sample.trench_tier,
		sample.volcanic_potential,
		sample.sediment_potential,
		sample.shallow_province_influence,
		sample.deep_province_influence,
		sample.abyssal_province_influence,
		sample.province_transition_influence
	]


func _get_sample_value(
	sample: EnvironmentSample,
	mode: int
) -> float:
	match mode:
		Mode.DEPTH:
			return sample.depth_below_surface

		Mode.LIGHT:
			return sample.light_availability

		Mode.TEMPERATURE:
			return sample.temperature_celsius

		Mode.PRESSURE:
			return sample.pressure_atmospheres

		Mode.NUTRIENTS:
			return sample.nutrient_potential

		Mode.CURRENT_EXPOSURE:
			return sample.current_exposure

		Mode.GEOLOGICAL_STABILITY:
			return sample.geological_stability

		Mode.SLOPE:
			return sample.slope_degrees

		Mode.ROUGHNESS:
			return sample.roughness_meters

		Mode.ROCK_SUBSTRATE:
			return sample.rock_substrate

		Mode.SAND_SUBSTRATE:
			return sample.sand_substrate

		Mode.SOFT_SEDIMENT_SUBSTRATE:
			return sample.soft_sediment_substrate

		Mode.BIOLOGICAL_POTENTIAL:
			return sample.biological_potential

		_:
			return 0.0


func _get_color_for_sample(
	sample: EnvironmentSample,
	mode: int
) -> Color:
	var value := _get_sample_value(
		sample,
		mode
	)

	match mode:
		Mode.DEPTH:
			var depth_normalized := _normalize(
				value,
				0.0,
				geology_settings.maximum_seabed_depth
			)

			return _three_color_gradient(
				Color(0.42, 0.70, 0.72, 1.0),
				Color(0.02, 0.20, 0.48, 1.0),
				Color(0.015, 0.005, 0.08, 1.0),
				depth_normalized
			)

		Mode.LIGHT:
			return _three_color_gradient(
				Color(0.002, 0.004, 0.012, 1.0),
				Color(0.02, 0.30, 0.46, 1.0),
				Color(1.0, 0.94, 0.50, 1.0),
				value
			)

		Mode.TEMPERATURE:
			var temperature_normalized := _normalize(
				value,
				-2.0,
				25.0
			)

			return _three_color_gradient(
				Color(0.08, 0.18, 0.72, 1.0),
				Color(0.72, 0.88, 0.92, 1.0),
				Color(1.0, 0.24, 0.05, 1.0),
				temperature_normalized
			)

		Mode.PRESSURE:
			var maximum_pressure := (
				1.0
				+ geology_settings
					.maximum_seabed_depth
				/ PRESSURE_DEPTH_METERS
			)

			var pressure_normalized := _normalize(
				value,
				1.0,
				maximum_pressure
			)

			return _three_color_gradient(
				Color(0.05, 0.32, 0.52, 1.0),
				Color(0.18, 0.08, 0.48, 1.0),
				Color(0.48, 0.02, 0.20, 1.0),
				pressure_normalized
			)

		Mode.NUTRIENTS:
			return _positive_color(
				value,
				Color(0.30, 1.0, 0.20, 1.0)
			)

		Mode.CURRENT_EXPOSURE:
			return _positive_color(
				value,
				Color(0.12, 0.78, 1.0, 1.0)
			)

		Mode.GEOLOGICAL_STABILITY:
			return _three_color_gradient(
				Color(0.92, 0.08, 0.04, 1.0),
				Color(0.88, 0.70, 0.10, 1.0),
				Color(0.12, 0.82, 0.28, 1.0),
				value
			)

		Mode.SLOPE:
			var slope_normalized := _normalize(
				value,
				0.0,
				60.0
			)

			return _three_color_gradient(
				Color(0.025, 0.08, 0.12, 1.0),
				Color(0.68, 0.52, 0.18, 1.0),
				Color(1.0, 0.96, 0.82, 1.0),
				slope_normalized
			)

		Mode.ROUGHNESS:
			var roughness_normalized := _normalize(
				value,
				0.0,
				environment_settings
					.full_roughness_meters
			)

			return _three_color_gradient(
				Color(0.03, 0.04, 0.06, 1.0),
				Color(0.48, 0.30, 0.12, 1.0),
				Color(1.0, 0.72, 0.16, 1.0),
				roughness_normalized
			)

		Mode.ROCK_SUBSTRATE:
			return _positive_color(
				value,
				Color(0.74, 0.74, 0.78, 1.0)
			)

		Mode.SAND_SUBSTRATE:
			return _positive_color(
				value,
				Color(0.90, 0.72, 0.36, 1.0)
			)

		Mode.SOFT_SEDIMENT_SUBSTRATE:
			return _positive_color(
				value,
				Color(0.54, 0.38, 0.25, 1.0)
			)

		Mode.BIOLOGICAL_POTENTIAL:
			return _three_color_gradient(
				Color(0.012, 0.025, 0.018, 1.0),
				Color(0.08, 0.58, 0.24, 1.0),
				Color(0.92, 1.0, 0.30, 1.0),
				value
			)

		_:
			return Color.MAGENTA


func _positive_color(
	value: float,
	target_color: Color
) -> Color:
	return BACKGROUND_COLOR.lerp(
		target_color,
		clampf(value, 0.0, 1.0)
	)


func _three_color_gradient(
	low_color: Color,
	middle_color: Color,
	high_color: Color,
	value: float
) -> Color:
	var normalized := clampf(
		value,
		0.0,
		1.0
	)

	if normalized <= 0.5:
		return low_color.lerp(
			middle_color,
			normalized * 2.0
		)

	return middle_color.lerp(
		high_color,
		(normalized - 0.5) * 2.0
	)


func _get_mode_name(
	mode: int
) -> String:
	match mode:
		Mode.DEPTH:
			return "Water depth"

		Mode.LIGHT:
			return "Light availability"

		Mode.TEMPERATURE:
			return "Temperature"

		Mode.PRESSURE:
			return "Pressure"

		Mode.NUTRIENTS:
			return "Nutrient potential"

		Mode.CURRENT_EXPOSURE:
			return "Current exposure"

		Mode.GEOLOGICAL_STABILITY:
			return "Geological stability"

		Mode.SLOPE:
			return "Local slope"

		Mode.ROUGHNESS:
			return "Local roughness"

		Mode.ROCK_SUBSTRATE:
			return "Rock substrate"

		Mode.SAND_SUBSTRATE:
			return "Sand substrate"

		Mode.SOFT_SEDIMENT_SUBSTRATE:
			return "Soft-sediment substrate"

		Mode.BIOLOGICAL_POTENTIAL:
			return "Biological potential"

		_:
			return "Unknown mode"


func _get_display_scale_description(
	mode: int
) -> String:
	match mode:
		Mode.DEPTH:
			return "0–%.0f m" % (
				geology_settings.maximum_seabed_depth
			)

		Mode.LIGHT:
			return "normalized 0–1"

		Mode.TEMPERATURE:
			return "-2–25 °C"

		Mode.PRESSURE:
			var maximum_pressure := (
				1.0
				+ geology_settings
					.maximum_seabed_depth
				/ PRESSURE_DEPTH_METERS
			)

			return "1–%.1f atm" % maximum_pressure

		Mode.SLOPE:
			return "0–60°"

		Mode.ROUGHNESS:
			return "0–%.1f m" % (
				environment_settings
					.full_roughness_meters
			)

		_:
			return "normalized 0–1"


func _get_mode_unit(
	mode: int
) -> String:
	match mode:
		Mode.DEPTH:
			return " m"

		Mode.TEMPERATURE:
			return " °C"

		Mode.PRESSURE:
			return " atm"

		Mode.SLOPE:
			return "°"

		Mode.ROUGHNESS:
			return " m"

		_:
			return ""


func _format_world_position(
	world_point: Vector2
) -> String:
	return "(%.1f, %.1f) m" % [
		world_point.x,
		world_point.y
	]


static func _normalize(
	value: float,
	minimum: float,
	maximum: float
) -> float:
	if maximum - minimum <= VALUE_EPSILON:
		return 0.0

	return clampf(
		(value - minimum)
			/ (maximum - minimum),
		0.0,
		1.0
	)
