class_name GiantSquidMaterialFactory
extends RefCounted

const BODY_SHADER: Shader = preload(
	"res://world/fauna/apex/shaders/giant_squid_body.gdshader"
) as Shader

const TENTACLE_SHADER: Shader = preload(
	"res://world/fauna/apex/shaders/giant_squid_tentacles.gdshader"
) as Shader

static var _body_material: ShaderMaterial
static var _tentacle_material: ShaderMaterial
static var _eye_material: StandardMaterial3D
static var _beak_material: StandardMaterial3D


static func get_body_material() -> ShaderMaterial:
	if _body_material != null:
		return _body_material

	var material: ShaderMaterial = ShaderMaterial.new()

	material.resource_name = "Giant Squid Body Material"
	material.shader = BODY_SHADER

	material.set_shader_parameter(
		"base_color",
		Color(
			0.78,
			0.76,
			0.78,
			1.0
		)
	)

	material.set_shader_parameter(
		"shadow_color",
		Color(
			0.45,
			0.47,
			0.52,
			1.0
		)
	)

	material.set_shader_parameter(
		"scar_color",
		Color(
			0.28,
			0.14,
			0.18,
			1.0
		)
	)

	material.set_shader_parameter(
		"variation_strength",
		0.16
	)

	material.set_shader_parameter(
		"scar_strength",
		0.07
	)

	material.set_shader_parameter(
		"roughness",
		0.78
	)

	material.set_shader_parameter(
		"specular_level",
		0.18
	)

	_body_material = material
	return _body_material


static func get_tentacle_material() -> ShaderMaterial:
	if _tentacle_material != null:
		return _tentacle_material

	var material: ShaderMaterial = ShaderMaterial.new()

	material.resource_name = "Giant Squid Tentacle Material"
	material.shader = TENTACLE_SHADER

	material.set_shader_parameter(
		"base_color",
		Color(
			0.78,
			0.75,
			0.77,
			1.0
		)
	)

	material.set_shader_parameter(
		"tip_color",
		Color(
			0.47,
			0.43,
			0.49,
			1.0
		)
	)

	material.set_shader_parameter(
		"movement_amplitude",
		1.35
	)

	material.set_shader_parameter(
		"movement_speed",
		0.28
	)

	material.set_shader_parameter(
		"activity",
		0.24
	)

	material.set_shader_parameter(
		"coordination",
		0.18
	)

	material.set_shader_parameter(
		"curl_strength",
		0.30
	)

	material.set_shader_parameter(
		"contraction",
		0.12
	)

	material.set_shader_parameter(
		"color_variation",
		0.12
	)

	_tentacle_material = material
	return _tentacle_material


static func create_instance_tentacle_material() -> ShaderMaterial:
	var shared_material: ShaderMaterial = (
		get_tentacle_material()
	)

	var duplicated_material: ShaderMaterial = (
		shared_material.duplicate()
		as ShaderMaterial
	)

	return duplicated_material


static func get_eye_material() -> StandardMaterial3D:
	if _eye_material != null:
		return _eye_material

	var material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	material.resource_name = "Giant Squid Eye Material"

	material.albedo_color = Color(
		0.055,
		0.022,
		0.028,
		1.0
	)

	material.emission_enabled = true

	material.emission = Color(
		0.16,
		0.025,
		0.035,
		1.0
	)

	material.emission_energy_multiplier = 0.35
	material.roughness = 0.28

	material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)

	_eye_material = material
	return _eye_material


static func get_beak_material() -> StandardMaterial3D:
	if _beak_material != null:
		return _beak_material

	var material: StandardMaterial3D = (
		StandardMaterial3D.new()
	)

	material.resource_name = "Giant Squid Beige Beak Material"

	material.albedo_color = Color(
		0.72,
		0.58,
		0.38,
		1.0
	)

	material.metallic = 0.0
	material.roughness = 0.72

	material.cull_mode = (
		BaseMaterial3D.CULL_DISABLED
	)

	_beak_material = material
	return _beak_material


static func clear_cache() -> void:
	_body_material = null
	_tentacle_material = null
	_eye_material = null
	_beak_material = null
