extends Control

enum Mode {
	PLATE_ID = 0,
	CONTINENTAL_AFFINITY = 1,
	BOUNDARY_CLASS = 2,
	BOUNDARY_PROXIMITY = 3,
	COMPRESSION = 4,
	EXTENSION = 5,
	SHEAR = 6,
	RIDGE_INFLUENCE = 7,
	RIFT_INFLUENCE = 8,
	RIDGE_POTENTIAL = 9,
	RIFT_POTENTIAL = 10,
	RIDGE_ELEVATION = 11,
	RIFT_ELEVATION = 12,
	TRENCH_POTENTIAL = 13,
	VOLCANIC_POTENTIAL = 14,
	SEDIMENT_POTENTIAL = 15,
	MACRO_ELEVATION = 16,
	MICRO_ELEVATION = 17,
	COUNT = 18,
}

const FEATURE_EPSILON: float = 0.000001
const MARKER_RADIUS_PIXELS: int = 5

const MINIMUM_MAP_SPAN: float = 4096.0
const MAXIMUM_MAP_SPAN: float = 262144.0
const NORMAL_PAN_FRACTION: float = 0.25
const FAST_PAN_FRACTION: float = 0.75
const ZOOM_FACTOR: float = 2.0

const BACKGROUND_COLOR: Color = Color(
	0.018,
	0.025,
	0.035,
	1.0
)

const INTERIOR_COLOR: Color = Color(
	0.08,
	0.09,
	0.11,
	1.0
)

const DIVERGENT_COLOR: Color = Color(
	1.0,
	0.34,
	0.08,
	1.0
)

const CONVERGENT_COLOR: Color = Color(
	0.35,
	0.28,
	1.0,
	1.0
)

const TRANSFORM_COLOR: Color = Color(
	1.0,
	0.82,
	0.12,
	1.0
)

const MARKER_COLOR: Color = Color(
	1.0,
	1.0,
	1.0,
	1.0
)

const MICRO_NEGATIVE_COLOR: Color = Color(
	0.08,
	0.30,
	0.95,
	1.0
)

const MICRO_NEUTRAL_COLOR: Color = Color(
	0.12,
	0.13,
	0.15,
	1.0
)

const MICRO_POSITIVE_COLOR: Color = Color(
	1.0,
	0.42,
	0.06,
	1.0
)

@export var geology_settings: GeologySettings
@export var terrain_settings: TerrainSettings

@export var world_seed: int = 1337
@export var generation_version: int = 7

@export var map_center: Vector2 = Vector2.ZERO

@export_range(4096.0, 262144.0, 1024.0)
var map_span: float = 32768.0

@export_range(33, 513, 1)
var map_resolution: int = 129

var _mode: int = Mode.PLATE_ID

var _terrain_data: TerrainChunkData
var _data: GeologyChunkData

var _show_feature_marker: bool = true

var _minimum_macro_elevation: float = 0.0
var _maximum_macro_elevation: float = 0.0

var _minimum_micro_elevation: float = 0.0
var _maximum_micro_elevation: float = 0.0
var _maximum_absolute_micro_elevation: float = 1.0

var _strongest_ridge_index: int = -1
var _strongest_ridge_potential: float = 0.0
var _strongest_ridge_elevation: float = 0.0

var _strongest_rift_index: int = -1
var _strongest_rift_potential: float = 0.0
var _strongest_rift_elevation: float = 0.0

var _ridge_sample_count: int = 0
var _rift_sample_count: int = 0
var _divergent_sample_count: int = 0
var _convergent_sample_count: int = 0
var _transform_sample_count: int = 0

@onready var _mode_label: Label = %ModeLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _map_texture: TextureRect = %MapTexture
@onready var _help_label: Label = %HelpLabel


func _ready() -> void:
	if geology_settings == null:
		push_error(
			"GeologyDebugMap requires GeologySettings."
		)
		return

	if terrain_settings == null:
		push_error(
			"GeologyDebugMap requires TerrainSettings."
		)
		return

	var geology_errors := geology_settings.validate()

	if not geology_errors.is_empty():
		for message in geology_errors:
			push_error(
				"Invalid debug geology settings: %s"
				% message
			)
		return

	var terrain_errors := terrain_settings.validate()

	if not terrain_errors.is_empty():
		for message in terrain_errors:
			push_error(
				"Invalid debug terrain settings: %s"
				% message
			)
		return

	_help_label.text = (
		"WASD: pan | Shift+WASD: fast pan | "
		+ "Q/E or wheel: zoom | Home: origin | "
		+ "Left/Right/Tab: mode | G: macro | T: micro | "
		+ "R: regenerate | M: marker | C: strongest ridge"
	)

	_generate_map()


func _input(
	input_event: InputEvent
) -> void:
	if input_event is InputEventMouseButton:
		var mouse_event := (
			input_event as InputEventMouseButton
		)

		if not mouse_event.pressed:
			return

		if (
			mouse_event.button_index
			== MOUSE_BUTTON_WHEEL_UP
		):
			_zoom_map(true)
			get_viewport().set_input_as_handled()
			return

		if (
			mouse_event.button_index
			== MOUSE_BUTTON_WHEEL_DOWN
		):
			_zoom_map(false)
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

	if key_event.keycode == KEY_G:
		_mode = Mode.MACRO_ELEVATION
		_render_current_mode()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_T:
		_mode = Mode.MICRO_ELEVATION
		_render_current_mode()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_R:
		_generate_map()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_M:
		_show_feature_marker = not _show_feature_marker
		_render_current_mode()
		get_viewport().set_input_as_handled()
		return

	if key_event.keycode == KEY_C:
		_center_on_strongest_ridge()
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
	_mode_label.text = "Generating terrain and geology..."
	_stats_label.text = ""

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

	var geology_snapshot := (
		GeologyGenerationSnapshot.from_settings(
			geology_seed,
			geology_settings
		)
	)

	var geology_validation_error := (
		geology_snapshot.get_validation_error()
	)

	if not geology_validation_error.is_empty():
		push_error(
			"Invalid debug geology snapshot: %s"
				% geology_validation_error
		)
		_mode_label.text = "Invalid geology snapshot."
		return

	var cells_per_axis := map_resolution - 1

	var sample_spacing := (
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

	var terrain_validation_error := (
		terrain_snapshot.get_validation_error()
	)

	if not terrain_validation_error.is_empty():
		push_error(
			"Invalid debug terrain snapshot: %s"
				% terrain_validation_error
		)
		_mode_label.text = "Invalid terrain snapshot."
		return

	_terrain_data = (
		TerrainSampler.generate_region_from_snapshot(
			terrain_snapshot,
			world_origin,
			cells_per_axis,
			sample_spacing
		)
	)

	if _terrain_data == null:
		push_error(
			"GeologyDebugMap terrain generation failed."
		)
		_mode_label.text = "Terrain generation failed."
		return

	_data = _terrain_data.geology_data

	if _data == null:
		push_error(
			"GeologyDebugMap did not receive geology data."
		)
		_mode_label.text = "Geology data missing."
		return

	_analyze_generated_data()
	_render_current_mode()


func _analyze_generated_data() -> void:
	_minimum_macro_elevation = INF
	_maximum_macro_elevation = -INF

	_minimum_micro_elevation = INF
	_maximum_micro_elevation = -INF
	_maximum_absolute_micro_elevation = 1.0

	_strongest_ridge_index = -1
	_strongest_ridge_potential = 0.0
	_strongest_ridge_elevation = 0.0

	_strongest_rift_index = -1
	_strongest_rift_potential = 0.0
	_strongest_rift_elevation = 0.0

	_ridge_sample_count = 0
	_rift_sample_count = 0

	_divergent_sample_count = 0
	_convergent_sample_count = 0
	_transform_sample_count = 0

	for index in range(
		_data.macro_elevation.size()
	):
		var macro_elevation := (
			_data.macro_elevation[index]
		)

		var micro_elevation := (
			_get_micro_elevation(index)
		)

		_minimum_macro_elevation = minf(
			_minimum_macro_elevation,
			macro_elevation
		)

		_maximum_macro_elevation = maxf(
			_maximum_macro_elevation,
			macro_elevation
		)

		_minimum_micro_elevation = minf(
			_minimum_micro_elevation,
			micro_elevation
		)

		_maximum_micro_elevation = maxf(
			_maximum_micro_elevation,
			micro_elevation
		)

		_maximum_absolute_micro_elevation = maxf(
			_maximum_absolute_micro_elevation,
			absf(micro_elevation)
		)

		var boundary_class := int(
			_data.boundary_classes[index]
		)

		match boundary_class:
			GeologyChunkData.BOUNDARY_CLASS_DIVERGENT:
				_divergent_sample_count += 1

			GeologyChunkData.BOUNDARY_CLASS_CONVERGENT:
				_convergent_sample_count += 1

			GeologyChunkData.BOUNDARY_CLASS_TRANSFORM:
				_transform_sample_count += 1

		var ridge_potential := (
			_data.ridge_potential[index]
		)

		if ridge_potential > FEATURE_EPSILON:
			_ridge_sample_count += 1

			if (
				_strongest_ridge_index < 0
				or ridge_potential
				> _strongest_ridge_potential
			):
				_strongest_ridge_index = index
				_strongest_ridge_potential = (
					ridge_potential
				)

				_strongest_ridge_elevation = (
					_data
					.ridge_elevation_contribution[index]
				)

		var rift_potential := (
			_data.rift_potential[index]
		)

		if rift_potential > FEATURE_EPSILON:
			_rift_sample_count += 1

			if (
				_strongest_rift_index < 0
				or rift_potential
				> _strongest_rift_potential
			):
				_strongest_rift_index = index
				_strongest_rift_potential = (
					rift_potential
				)

				_strongest_rift_elevation = (
					_data
					.rift_elevation_contribution[index]
				)

	_update_stats_label()


func _update_stats_label() -> void:
	var sample_spacing := (
		map_span
		/ float(map_resolution - 1)
	)

	var lines: Array[String] = []

	lines.append(
		(
			"Seed %d | generation v%d | center %s | "
			+ "span %.0f m | sample spacing %.1f m | "
			+ "resolution %d × %d"
		)
		% [
			world_seed,
			generation_version,
			_format_world_position(map_center),
			map_span,
			sample_spacing,
			map_resolution,
			map_resolution
		]
	)

	lines.append(
		"Macro elevation: %.1f m to %.1f m"
		% [
			_minimum_macro_elevation,
			_maximum_macro_elevation
		]
	)

	lines.append(
		(
			"Micro elevation: %.2f m to %.2f m | "
			+ "final terrain minus macro geology"
		)
		% [
			_minimum_micro_elevation,
			_maximum_micro_elevation
		]
	)

	lines.append(
		"Boundary samples: divergent %d | convergent %d | transform %d"
		% [
			_divergent_sample_count,
			_convergent_sample_count,
			_transform_sample_count
		]
	)

	if _strongest_ridge_index >= 0:
		var ridge_world_point := (
			_world_position_for_index(
				_strongest_ridge_index
			)
		)

		lines.append(
			(
				"Strongest ridge: %s | potential %.3f | "
				+ "uplift +%.1f m | active samples %d"
			)
			% [
				_format_world_position(
					ridge_world_point
				),
				_strongest_ridge_potential,
				_strongest_ridge_elevation,
				_ridge_sample_count
			]
		)
	else:
		lines.append(
			"Strongest ridge: none in current map span"
		)

	if _strongest_rift_index >= 0:
		var rift_world_point := (
			_world_position_for_index(
				_strongest_rift_index
			)
		)

		lines.append(
			(
				"Strongest rift: %s | potential %.3f | "
				+ "contribution %.1f m | active samples %d"
			)
			% [
				_format_world_position(
					rift_world_point
				),
				_strongest_rift_potential,
				_strongest_rift_elevation,
				_rift_sample_count
			]
		)
	else:
		lines.append(
			"Strongest rift: none in current map span"
		)

	_stats_label.text = "\n".join(lines)


func _render_current_mode() -> void:
	if _data == null or _terrain_data == null:
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

			image.set_pixel(
				pixel_x,
				pixel_z,
				_get_color_for_mode(
					index,
					_mode
				)
			)

	if _show_feature_marker:
		var marker_index := (
			_get_marker_index_for_mode()
		)

		if marker_index >= 0:
			_draw_feature_marker(
				image,
				marker_index
			)

	_map_texture.texture = (
		ImageTexture.create_from_image(
			image
		)
	)

	var marker_state := "shown"

	if not _show_feature_marker:
		marker_state = "hidden"

	_mode_label.text = (
		"%s | %s | span %.0f m | center %s | marker %s"
		% [
			_get_mode_name(_mode),
			_get_mode_scale_description(_mode),
			map_span,
			_format_world_position(map_center),
			marker_state
		]
	)


func _get_color_for_mode(
	index: int,
	mode: int
) -> Color:
	match mode:
		Mode.PLATE_ID:
			return _get_plate_color(
				_data.primary_plate_ids[index]
			)

		Mode.CONTINENTAL_AFFINITY:
			return _three_color_gradient(
				Color(0.015, 0.05, 0.15, 1.0),
				Color(0.05, 0.42, 0.52, 1.0),
				Color(0.72, 0.66, 0.40, 1.0),
				_data.continental_affinity[index]
			)

		Mode.BOUNDARY_CLASS:
			return _get_boundary_class_color(index)

		Mode.BOUNDARY_PROXIMITY:
			return _positive_field_color(
				_data.boundary_proximity[index],
				Color(0.16, 0.83, 1.0, 1.0)
			)

		Mode.COMPRESSION:
			return _positive_field_color(
				_data.compression_strength[index],
				Color(1.0, 0.18, 0.16, 1.0)
			)

		Mode.EXTENSION:
			return _positive_field_color(
				_data.extension_strength[index],
				Color(0.25, 0.64, 1.0, 1.0)
			)

		Mode.SHEAR:
			return _positive_field_color(
				_data.shear_strength[index],
				Color(1.0, 0.84, 0.12, 1.0)
			)

		Mode.RIDGE_INFLUENCE:
			return _positive_field_color(
				_data.ridge_influence[index],
				Color(1.0, 0.42, 0.06, 1.0)
			)

		Mode.RIFT_INFLUENCE:
			return _positive_field_color(
				_data.rift_influence[index],
				Color(0.10, 0.82, 1.0, 1.0)
			)

		Mode.RIDGE_POTENTIAL:
			return _positive_field_color(
				_data.ridge_potential[index],
				Color(1.0, 0.24, 0.04, 1.0)
			)

		Mode.RIFT_POTENTIAL:
			return _positive_field_color(
				_data.rift_potential[index],
				Color(0.08, 0.48, 1.0, 1.0)
			)

		Mode.RIDGE_ELEVATION:
			var ridge_denominator := maxf(
				1.0,
				geology_settings.ridge_uplift
			)

			var ridge_normalized := clampf(
				_data
					.ridge_elevation_contribution[index]
				/ ridge_denominator,
				0.0,
				1.0
			)

			return _positive_field_color(
				ridge_normalized,
				Color(1.0, 0.50, 0.05, 1.0)
			)

		Mode.RIFT_ELEVATION:
			var rift_denominator := maxf(
				1.0,
				geology_settings.rift_depth
			)

			var rift_normalized := clampf(
				absf(
					_data
						.rift_elevation_contribution[index]
				) / rift_denominator,
				0.0,
				1.0
			)

			return _positive_field_color(
				rift_normalized,
				Color(0.05, 0.38, 1.0, 1.0)
			)

		Mode.TRENCH_POTENTIAL:
			return _positive_field_color(
				_data.trench_potential[index],
				Color(0.58, 0.18, 1.0, 1.0)
			)

		Mode.VOLCANIC_POTENTIAL:
			return _three_color_gradient(
				BACKGROUND_COLOR,
				Color(0.88, 0.12, 0.04, 1.0),
				Color(1.0, 0.92, 0.18, 1.0),
				_data.volcanic_potential[index]
			)

		Mode.SEDIMENT_POTENTIAL:
			return _three_color_gradient(
				BACKGROUND_COLOR,
				Color(0.28, 0.38, 0.20, 1.0),
				Color(0.78, 0.68, 0.40, 1.0),
				_data.sediment_potential[index]
			)

		Mode.MACRO_ELEVATION:
			return _get_macro_elevation_color(
				_data.macro_elevation[index]
			)

		Mode.MICRO_ELEVATION:
			return _get_micro_elevation_color(
				_get_micro_elevation(index)
			)

		_:
			return Color.MAGENTA


func _get_micro_elevation(
	index: int
) -> float:
	return (
		_terrain_data.height_values[index]
		- _data.macro_elevation[index]
	)


func _get_micro_elevation_color(
	elevation_meters: float
) -> Color:
	var configured_scale := maxf(
		1.0,
		terrain_settings.test_elevation_amplitude
	)

	var display_scale := maxf(
		configured_scale,
		_maximum_absolute_micro_elevation
	)

	var normalized := clampf(
		elevation_meters / display_scale,
		-1.0,
		1.0
	)

	if normalized < 0.0:
		return MICRO_NEUTRAL_COLOR.lerp(
			MICRO_NEGATIVE_COLOR,
			-normalized
		)

	return MICRO_NEUTRAL_COLOR.lerp(
		MICRO_POSITIVE_COLOR,
		normalized
	)


func _get_boundary_class_color(
	index: int
) -> Color:
	var boundary_class := int(
		_data.boundary_classes[index]
	)

	var target_color := INTERIOR_COLOR
	var influence := _data.boundary_proximity[index]

	match boundary_class:
		GeologyChunkData.BOUNDARY_CLASS_DIVERGENT:
			target_color = DIVERGENT_COLOR

			influence = maxf(
				influence,
				_data.ridge_influence[index]
			)

		GeologyChunkData.BOUNDARY_CLASS_CONVERGENT:
			target_color = CONVERGENT_COLOR

		GeologyChunkData.BOUNDARY_CLASS_TRANSFORM:
			target_color = TRANSFORM_COLOR

		_:
			return INTERIOR_COLOR

	if influence <= FEATURE_EPSILON:
		return INTERIOR_COLOR

	var visible_influence := clampf(
		0.20 + influence * 0.80,
		0.0,
		1.0
	)

	return INTERIOR_COLOR.lerp(
		target_color,
		visible_influence
	)


func _positive_field_color(
	value: float,
	target_color: Color
) -> Color:
	var normalized := clampf(
		value,
		0.0,
		1.0
	)

	return BACKGROUND_COLOR.lerp(
		target_color,
		normalized
	)


func _get_macro_elevation_color(
	elevation_meters: float
) -> Color:
	var elevation_range := (
		_maximum_macro_elevation
		- _minimum_macro_elevation
	)

	if elevation_range <= FEATURE_EPSILON:
		return Color(
			0.05,
			0.20,
			0.28,
			1.0
		)

	var normalized := clampf(
		(
			elevation_meters
			- _minimum_macro_elevation
		) / elevation_range,
		0.0,
		1.0
	)

	return _three_color_gradient(
		Color(0.008, 0.025, 0.10, 1.0),
		Color(0.02, 0.34, 0.48, 1.0),
		Color(0.72, 0.64, 0.30, 1.0),
		normalized
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


func _get_plate_color(
	plate_id: int
) -> Color:
	var folded_id := int(
		(
			plate_id
			^ (plate_id >> 32)
		) & 0x7FFFFFFF
	)

	var hue := (
		float(folded_id % 3600)
		/ 3600.0
	)

	var saturation := (
		0.52
		+ float(
			(folded_id >> 8) & 0xFF
		) / 255.0
		* 0.28
	)

	var value := (
		0.62
		+ float(
			(folded_id >> 16) & 0xFF
		) / 255.0
		* 0.30
	)

	return Color.from_hsv(
		hue,
		saturation,
		value,
		1.0
	)


func _get_marker_index_for_mode() -> int:
	match _mode:
		Mode.RIFT_INFLUENCE:
			return _strongest_rift_index

		Mode.RIFT_POTENTIAL:
			return _strongest_rift_index

		Mode.RIFT_ELEVATION:
			return _strongest_rift_index

		Mode.MACRO_ELEVATION:
			return -1

		Mode.MICRO_ELEVATION:
			return -1

		_:
			return _strongest_ridge_index


func _draw_feature_marker(
	image: Image,
	marker_index: int
) -> void:
	if marker_index < 0:
		return

	var pixel_x := (
		marker_index % map_resolution
	)

	var pixel_z := floori(
		float(marker_index)
		/ float(map_resolution)
	)

	for marker_offset in range(
		-MARKER_RADIUS_PIXELS,
		MARKER_RADIUS_PIXELS + 1
	):
		if abs(marker_offset) < 2:
			continue

		var horizontal_x := pixel_x + marker_offset
		var vertical_z := pixel_z + marker_offset

		if (
			horizontal_x >= 0
			and horizontal_x < map_resolution
		):
			image.set_pixel(
				horizontal_x,
				pixel_z,
				MARKER_COLOR
			)

		if (
			vertical_z >= 0
			and vertical_z < map_resolution
		):
			image.set_pixel(
				pixel_x,
				vertical_z,
				MARKER_COLOR
			)


func _center_on_strongest_ridge() -> void:
	if (
		_data == null
		or _strongest_ridge_index < 0
	):
		return

	map_center = _world_position_for_index(
		_strongest_ridge_index
	)

	_generate_map()


func _world_position_for_index(
	index: int
) -> Vector2:
	var pixel_x := (
		index % map_resolution
	)

	var pixel_z := floori(
		float(index)
		/ float(map_resolution)
	)

	return (
		_data.world_origin
		+ Vector2(
			float(pixel_x) * _data.cell_size,
			float(pixel_z) * _data.cell_size
		)
	)


func _format_world_position(
	world_point: Vector2
) -> String:
	return "(%.0f, %.0f) m" % [
		world_point.x,
		world_point.y
	]


func _get_mode_name(
	mode: int
) -> String:
	match mode:
		Mode.PLATE_ID:
			return "Plate ownership"

		Mode.CONTINENTAL_AFFINITY:
			return "Continental affinity"

		Mode.BOUNDARY_CLASS:
			return "Boundary class"

		Mode.BOUNDARY_PROXIMITY:
			return "Boundary proximity"

		Mode.COMPRESSION:
			return "Compression strength"

		Mode.EXTENSION:
			return "Extension strength"

		Mode.SHEAR:
			return "Shear strength"

		Mode.RIDGE_INFLUENCE:
			return "Ridge influence"

		Mode.RIFT_INFLUENCE:
			return "Rift influence"

		Mode.RIDGE_POTENTIAL:
			return "Ridge potential"

		Mode.RIFT_POTENTIAL:
			return "Rift potential"

		Mode.RIDGE_ELEVATION:
			return "Ridge elevation contribution"

		Mode.RIFT_ELEVATION:
			return "Rift elevation contribution"

		Mode.TRENCH_POTENTIAL:
			return "Trench potential"

		Mode.VOLCANIC_POTENTIAL:
			return "Volcanic potential"

		Mode.SEDIMENT_POTENTIAL:
			return "Sediment potential"

		Mode.MACRO_ELEVATION:
			return "Final macro elevation"

		Mode.MICRO_ELEVATION:
			return "Micro elevation contribution"

		_:
			return "Unknown mode"


func _get_mode_scale_description(
	mode: int
) -> String:
	match mode:
		Mode.PLATE_ID:
			return "categorical"

		Mode.BOUNDARY_CLASS:
			return (
				"orange divergent | violet convergent "
				+ "| yellow transform"
			)

		Mode.RIDGE_ELEVATION:
			return "positive meters"

		Mode.RIFT_ELEVATION:
			return "negative meters"

		Mode.MACRO_ELEVATION:
			return "%.1f to %.1f m" % [
				_minimum_macro_elevation,
				_maximum_macro_elevation
			]

		Mode.MICRO_ELEVATION:
			return (
				"blue negative | gray zero | orange positive "
				+ "| %.2f to %.2f m"
			) % [
				_minimum_micro_elevation,
				_maximum_micro_elevation
			]

		_:
			return "normalized 0–1"
