class_name DepthLightingController
extends Node

## Controls native Forward+ volumetric fog, background color, ambient light,
## and directional sunlight from the active camera's world-space depth.
##
## This is strictly a presentation system. It does not read from or modify
## EnvironmentSampler, terrain generation, geology, or global shaders.

const NUMERIC_EPSILON: float = 0.000001
const PROPERTY_COMPARISON_EPSILON: float = 0.00001


@export_category("Dependencies")

@export var world_environment: WorldEnvironment
@export var directional_light: DirectionalLight3D

## Used when use_active_viewport_camera is false, or when the viewport does
## not currently have an active Camera3D.
@export var target_node: Node3D

## Following the active camera makes surface breaching visually accurate and
## automatically supports the movable debug camera.
@export var use_active_viewport_camera: bool = true


@export_category("Ocean")

## Authoritative world-space sea-surface elevation.
@export var ocean_surface_y: float = 0.0

## Prevents rapid submerged/breached switching near sea level.
@export_range(0.0, 1.0, 0.01)
var surface_hysteresis: float = 0.05


@export_category("Depth Palette")

## Above-water background while the camera is breaching.
@export var breached_background_color: Color = Color(
	0.10,
	0.28,
	0.36,
	1.0
)

## Cold green-blue shallow-water state.
@export var surface_color: Color = Color(
	0.018,
	0.22,
	0.25,
	1.0
)

## Desaturated blue midwater state.
@export var twilight_color: Color = Color(
	0.006,
	0.055,
	0.095,
	1.0
)

## Near-black navy rather than exact black. This preserves a minimal amount
## of local-light scattering in the abyss.
@export var abyss_color: Color = Color(
	0.0005,
	0.0015,
	0.004,
	1.0
)


@export_category("Transition Depths")

## Depth at which the palette reaches the twilight state.
@export_range(1.0, 2000.0, 1.0)
var twilight_depth: float = 120.0

## Depth at which the background and fog albedo reach abyss_color.
@export_range(2.0, 6000.0, 1.0)
var background_darkness_depth: float = 600.0

## Depth at which fog reaches abyss_fog_density.
@export_range(2.0, 6000.0, 1.0)
var fog_maximum_depth: float = 800.0

## Depth at which directional sunlight reaches abyss_light_energy.
@export_range(1.0, 2000.0, 1.0)
var sunlight_extinction_depth: float = 300.0


@export_category("Volumetric Fog")

@export_range(0.0, 1.0, 0.001)
var surface_fog_density: float = 0.006

@export_range(0.0, 1.0, 0.001)
var twilight_fog_density: float = 0.025

@export_range(0.0, 1.0, 0.001)
var abyss_fog_density: float = 0.08

## Native volumetric-fog integration distance. The matching fog/background
## colors hide the end of this volume without requiring an enormous volume.
@export_range(16.0, 2048.0, 1.0)
var volumetric_fog_length: float = 256.0


@export_category("Directional Light")

@export var surface_light_color: Color = Color(
	0.72,
	0.86,
	1.0,
	1.0
)

@export var abyss_light_color: Color = Color(
	0.10,
	0.16,
	0.22,
	1.0
)

@export_range(0.0, 16.0, 0.01)
var surface_light_energy: float = 1.5

@export_range(0.0, 16.0, 0.01)
var abyss_light_energy: float = 0.0


@export_category("Ambient Light")

@export_range(0.0, 8.0, 0.01)
var surface_ambient_energy: float = 0.70

@export_range(0.0, 8.0, 0.01)
var twilight_ambient_energy: float = 0.24

@export_range(0.0, 8.0, 0.01)
var abyss_ambient_energy: float = 0.015


@export_category("Update Policy")

## Position changes smaller than this do not resend environment properties.
@export_range(0.001, 1.0, 0.001)
var position_update_threshold: float = 0.01


var _rendering_environment: Environment

var _updates_enabled: bool = true
var _is_submerged: bool = true
var _has_water_state: bool = false

var _last_sampled_y: float = 0.0
var _has_sampled_position: bool = false

## If another system changes the Environment after this controller applies
## its state, updates pause until that state is restored. This allows the
## existing fullbright command to override the environment cleanly.
var _external_override_active: bool = false
var _has_applied_state: bool = false

var _last_background_color: Color = Color.BLACK
var _last_volumetric_fog_enabled: bool = false
var _last_volumetric_fog_albedo: Color = Color.BLACK
var _last_volumetric_fog_density: float = 0.0
var _last_volumetric_fog_length: float = 0.0
var _last_ambient_light_source: int = 0
var _last_ambient_light_color: Color = Color.BLACK
var _last_ambient_light_energy: float = 0.0
var _last_ambient_sky_contribution: float = 0.0


func _ready() -> void:
	var validation_error: String = _get_validation_error()

	if not validation_error.is_empty():
		push_error(
			"DepthLightingController: %s"
			% validation_error
		)
		set_process(false)
		return

	_prepare_runtime_environment()
	_apply_current_state(true)


func _process(
	_delta: float
) -> void:
	if not _updates_enabled:
		return

	if not _dependencies_are_valid():
		return

	_refresh_environment_reference()

	if _rendering_environment == null:
		return

	if _has_applied_state:
		var environment_matches: bool = (
			_environment_matches_last_applied_state()
		)

		if _external_override_active:
			if environment_matches:
				_external_override_active = false
				_has_sampled_position = false
			else:
				return
		elif not environment_matches:
			_external_override_active = true
			return

	_apply_current_state(false)


func _prepare_runtime_environment() -> void:
	var source_environment: Environment = (
		world_environment.environment
	)

	if source_environment == null:
		source_environment = Environment.new()
		world_environment.environment = source_environment

	var duplicated_resource: Resource = (
		source_environment.duplicate(true)
	)

	var duplicated_environment: Environment = (
		duplicated_resource as Environment
	)

	if duplicated_environment != null:
		world_environment.environment = duplicated_environment
		_rendering_environment = duplicated_environment
	else:
		_rendering_environment = source_environment

	## The removed validation asset used standard distance fog. Keep that
	## separate path disabled so it cannot stack with volumetric fog.
	_rendering_environment.fog_enabled = false


func _refresh_environment_reference() -> void:
	var current_environment: Environment = (
		world_environment.environment
	)

	if current_environment == _rendering_environment:
		return

	_rendering_environment = current_environment
	_has_applied_state = false
	_external_override_active = false
	_has_sampled_position = false


func _apply_current_state(
	force_update: bool
) -> void:
	var depth_target: Node3D = _resolve_depth_target()

	if (
		depth_target == null
		or not is_instance_valid(depth_target)
	):
		return

	var target_y: float = depth_target.global_position.y

	if not is_finite(target_y):
		return

	_update_water_state(target_y)

	if (
		not force_update
		and _has_sampled_position
		and absf(target_y - _last_sampled_y)
			< position_update_threshold
	):
		return

	_last_sampled_y = target_y
	_has_sampled_position = true

	if _is_submerged:
		var depth_meters: float = maxf(
			ocean_surface_y - target_y,
			0.0
		)

		_apply_submerged_state(depth_meters)
	else:
		_apply_breached_state()

	_record_applied_environment_state()


func _resolve_depth_target() -> Node3D:
	if use_active_viewport_camera:
		var current_viewport: Viewport = get_viewport()

		if current_viewport != null:
			var active_camera: Camera3D = (
				current_viewport.get_camera_3d()
			)

			if (
				active_camera != null
				and is_instance_valid(active_camera)
			):
				return active_camera

	return target_node


func _update_water_state(
	target_y: float
) -> void:
	if not _has_water_state:
		_is_submerged = target_y <= ocean_surface_y
		_has_water_state = true
		return

	if _is_submerged:
		var breach_threshold: float = (
			ocean_surface_y
			+ surface_hysteresis
		)

		if target_y > breach_threshold:
			_is_submerged = false
	else:
		var submerge_threshold: float = (
			ocean_surface_y
			- surface_hysteresis
		)

		if target_y <= submerge_threshold:
			_is_submerged = true


func _apply_breached_state() -> void:
	_rendering_environment.background_mode = (
		Environment.BG_COLOR
	)

	_rendering_environment.background_color = (
		breached_background_color
	)

	_rendering_environment.background_energy_multiplier = 1.0

	_rendering_environment.fog_enabled = false
	_rendering_environment.volumetric_fog_enabled = false

	## Keep valid surface values stored while disabled so re-entry begins
	## from a known state.
	_rendering_environment.volumetric_fog_albedo = (
		surface_color
	)

	_rendering_environment.volumetric_fog_density = (
		surface_fog_density
	)

	_rendering_environment.volumetric_fog_length = (
		volumetric_fog_length
	)

	_rendering_environment.ambient_light_source = (
		Environment.AMBIENT_SOURCE_COLOR
	)

	_rendering_environment.ambient_light_color = (
		surface_color
	)

	_rendering_environment.ambient_light_energy = (
		surface_ambient_energy
	)

	_rendering_environment.ambient_light_sky_contribution = 0.0

	directional_light.light_color = surface_light_color
	directional_light.light_energy = surface_light_energy


func _apply_submerged_state(
	depth_meters: float
) -> void:
	var current_water_color: Color = (
		_sample_depth_color(depth_meters)
	)

	var current_fog_density: float = (
		_sample_three_state_float(
			depth_meters,
			twilight_depth,
			fog_maximum_depth,
			surface_fog_density,
			twilight_fog_density,
			abyss_fog_density
		)
	)

	var current_ambient_energy: float = (
		_sample_three_state_float(
			depth_meters,
			twilight_depth,
			background_darkness_depth,
			surface_ambient_energy,
			twilight_ambient_energy,
			abyss_ambient_energy
		)
	)

	var sunlight_extinction: float = (
		_smoothstep_range(
			0.0,
			sunlight_extinction_depth,
			depth_meters
		)
	)

	var current_light_energy: float = lerpf(
		surface_light_energy,
		abyss_light_energy,
		sunlight_extinction
	)

	var current_light_color: Color = (
		surface_light_color.lerp(
			abyss_light_color,
			sunlight_extinction
		)
	)

	_rendering_environment.background_mode = (
		Environment.BG_COLOR
	)

	## Matching these two colors prevents a visible boundary between
	## geometry extinguished by fog and the empty world background.
	_rendering_environment.background_color = (
		current_water_color
	)

	_rendering_environment.background_energy_multiplier = 1.0

	_rendering_environment.fog_enabled = false
	_rendering_environment.volumetric_fog_enabled = true

	_rendering_environment.volumetric_fog_albedo = (
		current_water_color
	)

	_rendering_environment.volumetric_fog_density = (
		current_fog_density
	)

	_rendering_environment.volumetric_fog_length = (
		volumetric_fog_length
	)

	_rendering_environment.ambient_light_source = (
		Environment.AMBIENT_SOURCE_COLOR
	)

	_rendering_environment.ambient_light_color = (
		current_water_color
	)

	_rendering_environment.ambient_light_energy = (
		current_ambient_energy
	)

	_rendering_environment.ambient_light_sky_contribution = 0.0

	directional_light.light_color = current_light_color
	directional_light.light_energy = current_light_energy


func _sample_depth_color(
	depth_meters: float
) -> Color:
	if depth_meters <= twilight_depth:
		var surface_factor: float = _smoothstep_range(
			0.0,
			twilight_depth,
			depth_meters
		)

		return surface_color.lerp(
			twilight_color,
			surface_factor
		)

	var abyss_factor: float = _smoothstep_range(
		twilight_depth,
		background_darkness_depth,
		depth_meters
	)

	return twilight_color.lerp(
		abyss_color,
		abyss_factor
	)


static func _sample_three_state_float(
	depth_meters: float,
	middle_depth: float,
	final_depth: float,
	surface_value: float,
	middle_value: float,
	final_value: float
) -> float:
	if depth_meters <= middle_depth:
		var surface_factor: float = _smoothstep_range(
			0.0,
			middle_depth,
			depth_meters
		)

		return lerpf(
			surface_value,
			middle_value,
			surface_factor
		)

	var final_factor: float = _smoothstep_range(
		middle_depth,
		final_depth,
		depth_meters
	)

	return lerpf(
		middle_value,
		final_value,
		final_factor
	)


static func _smoothstep_range(
	edge_zero: float,
	edge_one: float,
	value: float
) -> float:
	var range_length: float = edge_one - edge_zero

	if range_length <= NUMERIC_EPSILON:
		if value >= edge_one:
			return 1.0

		return 0.0

	var factor: float = clampf(
		(value - edge_zero) / range_length,
		0.0,
		1.0
	)

	return (
		factor
		* factor
		* (3.0 - 2.0 * factor)
	)


func _record_applied_environment_state() -> void:
	_last_background_color = (
		_rendering_environment.background_color
	)

	_last_volumetric_fog_enabled = (
		_rendering_environment.volumetric_fog_enabled
	)

	_last_volumetric_fog_albedo = (
		_rendering_environment.volumetric_fog_albedo
	)

	_last_volumetric_fog_density = (
		_rendering_environment.volumetric_fog_density
	)

	_last_volumetric_fog_length = (
		_rendering_environment.volumetric_fog_length
	)

	_last_ambient_light_source = (
		_rendering_environment.ambient_light_source
	)

	_last_ambient_light_color = (
		_rendering_environment.ambient_light_color
	)

	_last_ambient_light_energy = (
		_rendering_environment.ambient_light_energy
	)

	_last_ambient_sky_contribution = (
		_rendering_environment
			.ambient_light_sky_contribution
	)

	_has_applied_state = true


func _environment_matches_last_applied_state() -> bool:
	if not _has_applied_state:
		return true

	if (
		_rendering_environment.volumetric_fog_enabled
		!= _last_volumetric_fog_enabled
	):
		return false

	if (
		_rendering_environment.ambient_light_source
		!= _last_ambient_light_source
	):
		return false

	if not _colors_are_equal(
		_rendering_environment.background_color,
		_last_background_color
	):
		return false

	if not _colors_are_equal(
		_rendering_environment.volumetric_fog_albedo,
		_last_volumetric_fog_albedo
	):
		return false

	if not _colors_are_equal(
		_rendering_environment.ambient_light_color,
		_last_ambient_light_color
	):
		return false

	if not is_equal_approx(
		_rendering_environment.volumetric_fog_density,
		_last_volumetric_fog_density
	):
		return false

	if not is_equal_approx(
		_rendering_environment.volumetric_fog_length,
		_last_volumetric_fog_length
	):
		return false

	if not is_equal_approx(
		_rendering_environment.ambient_light_energy,
		_last_ambient_light_energy
	):
		return false

	if not is_equal_approx(
		_rendering_environment
			.ambient_light_sky_contribution,
		_last_ambient_sky_contribution
	):
		return false

	return true


static func _colors_are_equal(
	first_color: Color,
	second_color: Color
) -> bool:
	return (
		absf(first_color.r - second_color.r)
			<= PROPERTY_COMPARISON_EPSILON
		and absf(first_color.g - second_color.g)
			<= PROPERTY_COMPARISON_EPSILON
		and absf(first_color.b - second_color.b)
			<= PROPERTY_COMPARISON_EPSILON
		and absf(first_color.a - second_color.a)
			<= PROPERTY_COMPARISON_EPSILON
	)


func set_updates_enabled(
	is_enabled: bool
) -> void:
	_updates_enabled = is_enabled

	if not _updates_enabled:
		return

	_external_override_active = false
	_has_applied_state = false
	_has_sampled_position = false
	_apply_current_state(true)


func force_refresh() -> void:
	if not _updates_enabled:
		return

	_external_override_active = false
	_has_applied_state = false
	_has_sampled_position = false
	_apply_current_state(true)


func is_submerged() -> bool:
	return _is_submerged


func is_externally_overridden() -> bool:
	return _external_override_active


func _dependencies_are_valid() -> bool:
	return (
		world_environment != null
		and is_instance_valid(world_environment)
		and directional_light != null
		and is_instance_valid(directional_light)
		and (
			target_node != null
			or use_active_viewport_camera
		)
	)


func _get_validation_error() -> String:
	if (
		world_environment == null
		or not is_instance_valid(world_environment)
	):
		return "world_environment is required."

	if (
		directional_light == null
		or not is_instance_valid(directional_light)
	):
		return "directional_light is required."

	if (
		target_node == null
		and not use_active_viewport_camera
	):
		return (
			"target_node is required when "
			+ "use_active_viewport_camera is false."
		)

	if not is_finite(ocean_surface_y):
		return "ocean_surface_y must be finite."

	if (
		not is_finite(surface_hysteresis)
		or surface_hysteresis < 0.0
	):
		return (
			"surface_hysteresis must be finite "
			+ "and non-negative."
		)

	if (
		not is_finite(twilight_depth)
		or twilight_depth <= 0.0
	):
		return "twilight_depth must be finite and positive."

	if (
		not is_finite(background_darkness_depth)
		or background_darkness_depth <= twilight_depth
	):
		return (
			"background_darkness_depth must be finite "
			+ "and greater than twilight_depth."
		)

	if (
		not is_finite(fog_maximum_depth)
		or fog_maximum_depth <= twilight_depth
	):
		return (
			"fog_maximum_depth must be finite and "
			+ "greater than twilight_depth."
		)

	if (
		not is_finite(sunlight_extinction_depth)
		or sunlight_extinction_depth <= 0.0
	):
		return (
			"sunlight_extinction_depth must be finite "
			+ "and positive."
		)

	if not _fog_densities_are_valid():
		return "All fog densities must be finite and non-negative."

	if not _light_energies_are_valid():
		return "All light energies must be finite and non-negative."

	if (
		not is_finite(volumetric_fog_length)
		or volumetric_fog_length <= 0.0
	):
		return (
			"volumetric_fog_length must be finite "
			+ "and positive."
		)

	if (
		not is_finite(position_update_threshold)
		or position_update_threshold <= 0.0
	):
		return (
			"position_update_threshold must be finite "
			+ "and positive."
		)

	return ""


func _fog_densities_are_valid() -> bool:
	return (
		is_finite(surface_fog_density)
		and surface_fog_density >= 0.0
		and is_finite(twilight_fog_density)
		and twilight_fog_density >= 0.0
		and is_finite(abyss_fog_density)
		and abyss_fog_density >= 0.0
	)


func _light_energies_are_valid() -> bool:
	return (
		is_finite(surface_light_energy)
		and surface_light_energy >= 0.0
		and is_finite(abyss_light_energy)
		and abyss_light_energy >= 0.0
		and is_finite(surface_ambient_energy)
		and surface_ambient_energy >= 0.0
		and is_finite(twilight_ambient_energy)
		and twilight_ambient_energy >= 0.0
		and is_finite(abyss_ambient_energy)
		and abyss_ambient_energy >= 0.0
	)
