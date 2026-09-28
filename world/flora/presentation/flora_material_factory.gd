class_name FloraMaterialFactory
extends RefCounted

const FLORA_SHADER: Shader = preload(
	"res://world/flora/presentation/shaders/flora_sway.gdshader"
)

## Vector2i(species_id, morphology_tier) -> ShaderMaterial
static var _material_cache: Dictionary = {}

static var _sway_enabled: bool = true

static var _current_direction: Vector2 = Vector2(
	1.0,
	0.25
).normalized()


static func get_material(
	species_id: int,
	morphology_tier: int = 0
) -> ShaderMaterial:
	if species_id < 0 or species_id >= FloraIds.COUNT:
		return null

	var tier := 0

	if species_id == FloraIds.GIANT_KELP:
		tier = clampi(
			morphology_tier,
			0,
			FloraPlacementCandidate
				.KELP_MORPHOLOGY_TIER_COUNT - 1
		)

	var cache_key := Vector2i(
		species_id,
		tier
	)

	if _material_cache.has(cache_key):
		return (
			_material_cache[cache_key]
			as ShaderMaterial
		)

	var material := ShaderMaterial.new()

	if species_id == FloraIds.GIANT_KELP:
		material.resource_name = (
			"Giant Kelp Tier %d Shared Flora Material"
			% tier
		)
	else:
		material.resource_name = (
			"%s Shared Flora Material"
			% FloraIds.get_display_name(species_id)
		)

	material.shader = FLORA_SHADER

	_apply_common_parameters(material)
	_apply_species_parameters(
		material,
		species_id,
		tier
	)

	_material_cache[cache_key] = material
	return material


static func clear_cache() -> void:
	_material_cache.clear()


static func set_sway_enabled(
	enabled: bool
) -> void:
	_sway_enabled = enabled

	for material_value in _material_cache.values():
		var material := material_value as ShaderMaterial

		if material != null:
			material.set_shader_parameter(
				"sway_enabled",
				1.0 if enabled else 0.0
			)


static func is_sway_enabled() -> bool:
	return _sway_enabled


static func set_current_direction(
	direction: Vector2
) -> void:
	if direction.is_zero_approx():
		_current_direction = Vector2.RIGHT
	else:
		_current_direction = direction.normalized()

	for material_value in _material_cache.values():
		var material := material_value as ShaderMaterial

		if material != null:
			material.set_shader_parameter(
				"current_direction",
				_current_direction
			)


static func get_current_direction() -> Vector2:
	return _current_direction


static func get_sway_strength(
	species_id: int
) -> float:
	match species_id:
		FloraIds.GIANT_KELP:
			return 0.24

		FloraIds.SEAGRASS:
			return 0.14

		FloraIds.REEF_MACROALGAE:
			return 0.12

		FloraIds.RED_FAN_ALGAE:
			return 0.10

		FloraIds.CORALLINE_ALGAE:
			return 0.004

		_:
			return 0.0


static func _apply_common_parameters(
	material: ShaderMaterial
) -> void:
	material.set_shader_parameter(
		"current_direction",
		_current_direction
	)

	material.set_shader_parameter(
		"sway_enabled",
		1.0 if _sway_enabled else 0.0
	)

	material.set_shader_parameter(
		"sway_spatial_frequency",
		0.35
	)

	material.set_shader_parameter(
		"secondary_wave_strength",
		0.30
	)

	material.set_shader_parameter(
		"instance_phase_scale",
		1.0
	)

	material.set_shader_parameter(
		"temperature_color_strength",
		0.0
	)


static func _apply_species_parameters(
	material: ShaderMaterial,
	species_id: int,
	morphology_tier: int
) -> void:
	match species_id:
		FloraIds.GIANT_KELP:
			_apply_parameters(
				material,
				Color(0.94, 1.00, 0.78, 1.0),
				0.82,
				0.22,
				0.025,
				get_sway_strength(species_id),
				0.64,
				KelpProceduralMeshFactory
					.get_nominal_height(
						morphology_tier
					),
				0.08
			)

			## Cold kelp is dark blue-green. Warm kelp shifts toward a
			## brighter yellow-green. INSTANCE_CUSTOM.g selects between
			## these colors from deterministic environmental temperature.
			material.set_shader_parameter(
				"cold_temperature_color",
				Color(0.08, 0.32, 0.24, 1.0)
			)

			material.set_shader_parameter(
				"warm_temperature_color",
				Color(0.78, 1.00, 0.16, 1.0)
			)

			material.set_shader_parameter(
				"temperature_color_strength",
				0.86
			)

		FloraIds.SEAGRASS:
			_apply_parameters(
				material,
				Color(
					0.82,
					1.00,
					0.88,
					1.0
				),
				0.88,
				0.20,
				0.012,
				get_sway_strength(species_id),
				1.05,
				FloraProceduralMeshFactory
					.get_nominal_height(species_id),
				0.025
			)

		FloraIds.REEF_MACROALGAE:
			_apply_parameters(
				material,
				Color(
					1.00,
					0.91,
					0.72,
					1.0
				),
				0.86,
				0.22,
				0.012,
				get_sway_strength(species_id),
				0.78,
				FloraProceduralMeshFactory
					.get_nominal_height(species_id),
				0.06
			)

		FloraIds.RED_FAN_ALGAE:
			_apply_parameters(
				material,
				Color(
					1.00,
					0.80,
					0.88,
					1.0
				),
				0.80,
				0.27,
				0.022,
				get_sway_strength(species_id),
				0.72,
				FloraProceduralMeshFactory
					.get_nominal_height(species_id),
				0.05
			)

		FloraIds.CORALLINE_ALGAE:
			_apply_parameters(
				material,
				Color(
					1.00,
					0.88,
					1.00,
					1.0
				),
				0.94,
				0.18,
				0.018,
				get_sway_strength(species_id),
				0.30,
				FloraProceduralMeshFactory
					.get_nominal_height(species_id),
				0.02
			)


static func _apply_parameters(
	material: ShaderMaterial,
	albedo_tint: Color,
	roughness: float,
	specular_level: float,
	emission_strength: float,
	sway_strength: float,
	sway_speed: float,
	model_height: float,
	bend_start: float
) -> void:
	material.set_shader_parameter(
		"albedo_tint",
		albedo_tint
	)

	material.set_shader_parameter(
		"roughness",
		roughness
	)

	material.set_shader_parameter(
		"specular_level",
		specular_level
	)

	material.set_shader_parameter(
		"emission_strength",
		emission_strength
	)

	material.set_shader_parameter(
		"sway_strength",
		sway_strength
	)

	material.set_shader_parameter(
		"sway_speed",
		sway_speed
	)

	material.set_shader_parameter(
		"model_height",
		maxf(model_height, 0.01)
	)

	material.set_shader_parameter(
		"bend_start",
		maxf(bend_start, 0.0)
	)
