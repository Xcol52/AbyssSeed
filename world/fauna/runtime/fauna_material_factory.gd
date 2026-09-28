class_name FaunaMaterialFactory
extends RefCounted

const FISH_SHADER: Shader = preload(
	"res://world/fauna/runtime/shaders/fauna_fish.gdshader"
)

## species_id -> ShaderMaterial
static var _material_cache: Dictionary = {}


static func get_material(
	species: FaunaSpeciesSnapshot
) -> ShaderMaterial:
	if species == null:
		return null

	if _material_cache.has(species.species_id):
		return (
			_material_cache[species.species_id]
			as ShaderMaterial
		)

	var material := ShaderMaterial.new()

	material.resource_name = (
		"%s Shared Fauna Material"
		% species.display_name
	)

	material.shader = FISH_SHADER

	material.set_shader_parameter(
		"cold_color",
		species.cold_color
	)

	material.set_shader_parameter(
		"warm_color",
		species.warm_color
	)

	var amplitude := species.body_length * 0.11

	material.set_shader_parameter(
		"tail_amplitude",
		amplitude
	)

	var speed := 7.0

	match species.species_id:
		FaunaIds.SHELF_BAITFISH:
			speed = 11.0

		FaunaIds.KELP_GRAZER:
			speed = 5.5

		FaunaIds.REEF_HUNTER:
			speed = 6.8

	material.set_shader_parameter(
		"tail_speed",
		speed
	)

	material.set_shader_parameter(
		"roughness",
		0.72
	)

	material.set_shader_parameter(
		"specular_level",
		0.28
	)

	_material_cache[species.species_id] = material
	return material


static func clear_cache() -> void:
	_material_cache.clear()
