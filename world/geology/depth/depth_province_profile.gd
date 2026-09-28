class_name DepthProvinceProfile
extends RefCounted

const PROFILE_EPSILON: float = 0.000001

var _settings: DepthProvinceSnapshot

var _primary_noise: FastNoiseLite
var _secondary_noise: FastNoiseLite
var _variation_noise: FastNoiseLite


func _init(
	geology_seed: int,
	settings: DepthProvinceSnapshot
) -> void:
	assert(settings != null)

	_settings = settings

	_primary_noise = _create_noise(
		geology_seed,
		GeologyChannels.DEPTH_PROVINCE_PRIMARY,
		settings.primary_frequency
	)

	_secondary_noise = _create_noise(
		geology_seed,
		GeologyChannels.DEPTH_PROVINCE_SECONDARY,
		settings.secondary_frequency
	)

	_variation_noise = _create_noise(
		geology_seed,
		GeologyChannels.DEPTH_PROVINCE_VARIATION,
		settings.depth_variation_frequency
	)


## Returns:
## x = shallow-province influence
## y = deep-province influence
## z = abyssal-province influence
## w = province-transition influence
func sample_influences(
	world_xz: Vector2
) -> Vector4:
	var primary_value := (
		_primary_noise.get_noise_2d(
			world_xz.x,
			world_xz.y
		)
		* 0.5
		+ 0.5
	)

	var secondary_value := (
		_secondary_noise.get_noise_2d(
			world_xz.x,
			world_xz.y
		)
		* 0.5
		+ 0.5
	)

	var selector := clampf(
		primary_value * 0.72
		+ secondary_value * 0.28,
		0.0,
		1.0
	)

	## Keep the initial world origin inside a broad shallow province.
	var shelf_release := _smoothstep(
		_settings.starting_shelf_radius,
		_settings.starting_shelf_radius
			+ _settings.starting_shelf_fade_width,
		world_xz.length()
	)

	selector *= shelf_release

	return calculate_influences_from_selector(
		selector,
		_settings
	)


static func calculate_influences_from_selector(
	selector: float,
	settings: DepthProvinceSnapshot
) -> Vector4:
	assert(settings != null)

	var normalized_selector := clampf(
		selector,
		0.0,
		1.0
	)

	var deep_gate := _smoothstep(
		settings.shelf_transition_start,
		settings.shelf_transition_end,
		normalized_selector
	)

	var abyssal_gate := _smoothstep(
		settings.abyssal_transition_start,
		settings.abyssal_transition_end,
		normalized_selector
	)

	var shallow_influence := 1.0 - deep_gate

	var deep_influence := (
		deep_gate
		* (1.0 - abyssal_gate)
	)

	var abyssal_influence := abyssal_gate

	var shelf_transition := (
		4.0
		* deep_gate
		* (1.0 - deep_gate)
	)

	var abyssal_transition := (
		4.0
		* abyssal_gate
		* (1.0 - abyssal_gate)
	)

	var transition_influence := clampf(
		maxf(
			shelf_transition,
			abyssal_transition
		),
		0.0,
		1.0
	)

	return Vector4(
		shallow_influence,
		deep_influence,
		abyssal_influence,
		transition_influence
	)


func calculate_target_depth(
	world_xz: Vector2,
	shallow_base_depth: float,
	influences: Vector4
) -> float:
	var variation := clampf(
		_variation_noise.get_noise_2d(
			world_xz.x,
			world_xz.y
		)
		* 0.5
		+ 0.5,
		0.0,
		1.0
	)

	var deep_target := lerpf(
		_settings.deep_minimum_depth,
		_settings.deep_maximum_depth,
		variation
	)

	var abyssal_target := lerpf(
		_settings.abyssal_minimum_depth,
		_settings.abyssal_maximum_depth,
		variation
	)

	return (
		maxf(shallow_base_depth, 0.0)
		* influences.x
		+ deep_target
		* influences.y
		+ abyssal_target
		* influences.z
	)


static func calculate_elevation_contribution(
	shallow_base_depth: float,
	province_target_depth: float
) -> float:
	return minf(
		shallow_base_depth
		- province_target_depth,
		0.0
	)


static func _create_noise(
	geology_seed: int,
	channel_id: int,
	frequency: float
) -> FastNoiseLite:
	var noise := FastNoiseLite.new()

	noise.seed = StableSeed.derive_channel_seed(
		geology_seed,
		channel_id
	)

	noise.frequency = frequency
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_NONE

	return noise


static func _smoothstep(
	edge_zero: float,
	edge_one: float,
	value: float
) -> float:
	if (
		absf(edge_one - edge_zero)
		<= PROFILE_EPSILON
	):
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
