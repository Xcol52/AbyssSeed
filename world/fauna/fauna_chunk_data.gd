class_name FaunaChunkData
extends RefCounted

## Immutable by convention.

var chunk_coordinate: Vector2i
var world_origin: Vector2
var chunk_size: float

var populations: Array[FaunaPopulationDescriptor]


func _init(
	new_chunk_coordinate: Vector2i,
	new_world_origin: Vector2,
	new_chunk_size: float,
	new_populations: Array[FaunaPopulationDescriptor]
) -> void:
	chunk_coordinate = new_chunk_coordinate
	world_origin = new_world_origin
	chunk_size = new_chunk_size
	populations = new_populations


func get_population_count() -> int:
	return populations.size()


func get_validation_error() -> String:
	if chunk_size <= 0.0:
		return "Fauna chunk size must be positive."

	var encountered_ids: Dictionary = {}

	for descriptor in populations:
		if descriptor == null:
			return "Fauna chunk contains a null descriptor."

		var error := descriptor.get_validation_error()

		if not error.is_empty():
			return error

		if descriptor.owning_chunk != chunk_coordinate:
			return (
				"Fauna descriptor owning chunk does not match "
				+ "FaunaChunkData."
			)

		if encountered_ids.has(descriptor.stable_id):
			return (
				"Fauna chunk contains duplicate stable ID %d."
				% descriptor.stable_id
			)

		encountered_ids[descriptor.stable_id] = true

		if (
			descriptor.home_position.x < world_origin.x
			or descriptor.home_position.z < world_origin.y
			or descriptor.home_position.x
				>= world_origin.x + chunk_size
			or descriptor.home_position.z
				>= world_origin.y + chunk_size
		):
			return (
				"Fauna population home lies outside its "
				+ "half-open owning chunk."
			)

	return ""
